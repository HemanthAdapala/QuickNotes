// backend/src/cron.ts
// Scheduled acknowledgement queue retry processor and operational telemetry

import { Env, PurchaseRow } from './types';
import { decryptToken } from './crypto';
import {
  acknowledgePurchase,
  evaluateGooglePlayResponse,
  fetchProductPurchaseV2,
  getGoogleAccessToken
} from './google-play';
import { claimCandidateRows, rereadPurchase, updatePurchaseCas } from './db';

export interface AckQueueStats {
  claimedCount: number;
  successCount: number;
  failureCount: number;
  revokedCount: number;
  queueDepth: number;
  maxAuthoritativeAgeMs: number | null;
  maxServerObservationAgeMs: number | null;
  missingPurchaseTimeCount: number;
}

export function calculateBackoffMs(
  attemptCount: number,
  purchaseTimeMs: number | null,
  nowMs: number
): number {
  // If purchase time is missing, apply conservative escalation immediately (max 15 minutes)
  if (purchaseTimeMs === null) {
    const base = Math.min(15 * 60 * 1000, 5 * 60 * 1000 * Math.pow(2, attemptCount));
    const jitter = Math.floor(Math.random() * 30000);
    return base + jitter;
  }

  const ageMs = nowMs - purchaseTimeMs;
  let maxCapMs = 12 * 60 * 60 * 1000; // 12 hours

  if (ageMs > 48 * 60 * 60 * 1000) {
    // Critical urgency (48h - 72h): clamp backoff to 15 minutes
    maxCapMs = 15 * 60 * 1000;
  } else if (ageMs > 36 * 60 * 60 * 1000) {
    // Elevated urgency (36h - 48h): clamp backoff to 30 minutes
    maxCapMs = 30 * 60 * 1000;
  }

  const base = Math.min(maxCapMs, 5 * 60 * 1000 * Math.pow(2, attemptCount));
  const jitter = Math.floor(Math.random() * 30000);
  return base + jitter;
}

export async function processAckQueue(env: Env): Promise<AckQueueStats> {
  const nowMs = Date.now();
  let successCount = 0;
  let failureCount = 0;
  let revokedCount = 0;

  // 1. Claim up to 3 candidate rows atomically
  const claimedRows = await claimCandidateRows(env.DB, nowMs, 3);

  let accessToken: string | null = null;
  if (claimedRows.length > 0 && env.GOOGLE_SERVICE_ACCOUNT_JSON) {
    try {
      accessToken = await getGoogleAccessToken(env.GOOGLE_SERVICE_ACCOUNT_JSON);
    } catch (err) {
      console.error('[CRON_AUTH_ERROR] Failed to obtain Google OAuth2 token:', err);
    }
  }

  // 2. Process each claimed row
  for (const row of claimedRows) {
    if (!accessToken || !row.encrypted_token) {
      // Release claim with backoff if token or auth is unavailable
      const backoffMs = calculateBackoffMs(row.ack_attempt_count, row.purchase_time_ms, nowMs);
      await updatePurchaseCas(env.DB, {
        token_hash: row.token_hash,
        expected_state_version: row.state_version,
        status: 'ACTIVE',
        revocation_reason: null,
        acknowledgement_state: 'PENDING',
        encrypted_token: row.encrypted_token,
        ack_attempt_count: row.ack_attempt_count + 1,
        next_ack_attempt_at: nowMs + backoffMs,
        ack_claim_expires_at: null, // Release claim
        last_ack_failure_reason: accessToken ? 'ENCRYPTED_TOKEN_MISSING' : 'AUTH_TOKEN_FAILED',
        last_check_status: 'UPSTREAM_ERROR',
        purchase_time_ms: row.purchase_time_ms,
        now_ms: nowMs
      });
      failureCount++;
      continue;
    }

    // Decrypt the purchase token
    let rawToken: string;
    try {
      rawToken = await decryptToken(row.encrypted_token, env.TOKEN_ENCRYPTION_KEYRING);
    } catch (decryptErr) {
      console.error(`[CRYPTO_DECRYPT_FAIL] Failed to decrypt token for ${row.token_hash}:`, decryptErr);
      const backoffMs = calculateBackoffMs(row.ack_attempt_count, row.purchase_time_ms, nowMs);
      await updatePurchaseCas(env.DB, {
        token_hash: row.token_hash,
        expected_state_version: row.state_version,
        status: 'ACTIVE',
        revocation_reason: null,
        acknowledgement_state: 'PENDING',
        encrypted_token: row.encrypted_token, // Retain token despite decrypt error
        ack_attempt_count: row.ack_attempt_count + 1,
        next_ack_attempt_at: nowMs + backoffMs,
        ack_claim_expires_at: null,
        last_ack_failure_reason: 'DECRYPT_FAILED',
        last_check_status: 'CRYPTO_ERROR',
        purchase_time_ms: row.purchase_time_ms,
        now_ms: nowMs
      });
      failureCount++;
      continue;
    }

    // 3. Pre-check authoritative status via productsv2 before issuing acknowledge
    const lookupRes = await fetchProductPurchaseV2(row.package_name, rawToken, accessToken);
    if (lookupRes.status === 200 && lookupRes.data) {
      const evalResult = evaluateGooglePlayResponse(lookupRes.data, row.package_name, row.product_id);

      // Branch A: Authoritative Cancellation
      if (evalResult.purchaseState === 'CANCELLED') {
        const updated = await updatePurchaseCas(env.DB, {
          token_hash: row.token_hash,
          expected_state_version: row.state_version,
          status: 'REVOKED',
          revocation_reason: 'GOOGLE_PLAY_CANCELLED',
          acknowledgement_state: 'NOT_APPLICABLE',
          encrypted_token: null, // Purged: Confirmed CANCELLED
          ack_attempt_count: row.ack_attempt_count,
          next_ack_attempt_at: null,
          ack_claim_expires_at: null,
          last_ack_failure_reason: 'PURCHASE_CANCELLED_UPSTREAM',
          last_check_status: 'REVOKED',
          purchase_time_ms: evalResult.purchaseCompletionTimeMs ?? row.purchase_time_ms,
          now_ms: nowMs
        });
        if (updated) revokedCount++;
        continue;
      }

      // Branch B: Already Acknowledged
      if (evalResult.acknowledgementState === 'ACKNOWLEDGED') {
        const updated = await updatePurchaseCas(env.DB, {
          token_hash: row.token_hash,
          expected_state_version: row.state_version,
          status: 'ACTIVE',
          revocation_reason: null,
          acknowledgement_state: 'ACKNOWLEDGED',
          encrypted_token: null, // Purged: Confirmed ACKNOWLEDGED
          ack_attempt_count: row.ack_attempt_count,
          next_ack_attempt_at: null,
          ack_claim_expires_at: null,
          last_ack_failure_reason: null,
          last_check_status: 'SUCCESS',
          purchase_time_ms: evalResult.purchaseCompletionTimeMs ?? row.purchase_time_ms,
          now_ms: nowMs
        });
        if (updated) successCount++;
        continue;
      }
    }

    // 4. Attempt Acknowledgement
    const ackRes = await acknowledgePurchase(row.package_name, row.product_id, rawToken, accessToken);
    if (ackRes.status === 200 || ackRes.status === 204) {
      // Acknowledgement Succeeded!
      const updated = await updatePurchaseCas(env.DB, {
        token_hash: row.token_hash,
        expected_state_version: row.state_version,
        status: 'ACTIVE',
        revocation_reason: null,
        acknowledgement_state: 'ACKNOWLEDGED',
        encrypted_token: null, // Purged: Confirmed ACKNOWLEDGED
        ack_attempt_count: row.ack_attempt_count,
        next_ack_attempt_at: null,
        ack_claim_expires_at: null,
        last_ack_failure_reason: null,
        last_check_status: 'SUCCESS',
        purchase_time_ms: row.purchase_time_ms,
        now_ms: nowMs
      });
      if (updated) successCount++;
    } else {
      // Acknowledgement call failed or returned error (e.g. 400 or timeout)
      const backoffMs = calculateBackoffMs(row.ack_attempt_count + 1, row.purchase_time_ms, nowMs);
      await updatePurchaseCas(env.DB, {
        token_hash: row.token_hash,
        expected_state_version: row.state_version,
        status: 'ACTIVE',
        revocation_reason: null,
        acknowledgement_state: 'PENDING',
        encrypted_token: row.encrypted_token, // Retained: Never purge on ambiguous failure
        ack_attempt_count: row.ack_attempt_count + 1,
        next_ack_attempt_at: nowMs + backoffMs,
        ack_claim_expires_at: null,
        last_ack_failure_reason: `ACK_HTTP_${ackRes.status}: ${ackRes.errorText?.slice(0, 100) ?? 'unknown'}`,
        last_check_status: 'UPSTREAM_ERROR',
        purchase_time_ms: row.purchase_time_ms,
        now_ms: nowMs
      });
      failureCount++;
    }
  }

  // 5. Gather queue depth and age metrics for operational logging
  const depthRes = await env.DB.prepare(
    `SELECT 
      COUNT(*) as queue_depth,
      MIN(purchase_time_ms) as oldest_purchase_time,
      MIN(created_at_ms) as oldest_created_at,
      SUM(CASE WHEN purchase_time_ms IS NULL THEN 1 ELSE 0 END) as missing_time_count
    FROM purchases 
    WHERE status = 'ACTIVE' AND acknowledgement_state = 'PENDING'`
  ).first<{
    queue_depth: number;
    oldest_purchase_time: number | null;
    oldest_created_at: number | null;
    missing_time_count: number;
  }>();

  const queueDepth = depthRes?.queue_depth ?? 0;
  const maxAuthoritativeAgeMs = depthRes?.oldest_purchase_time ? nowMs - depthRes.oldest_purchase_time : null;
  const maxServerObservationAgeMs = depthRes?.oldest_created_at ? nowMs - depthRes.oldest_created_at : null;
  const missingPurchaseTimeCount = depthRes?.missing_time_count ?? 0;

  // Emit structured metrics
  console.log(
    JSON.stringify({
      level: 'INFO',
      event: 'CRON_ACK_QUEUE_PROCESSED',
      claimed: claimedRows.length,
      successes: successCount,
      failures: failureCount,
      revoked: revokedCount,
      queue_depth: queueDepth,
      max_authoritative_age_ms: maxAuthoritativeAgeMs,
      max_server_observation_age_ms: maxServerObservationAgeMs,
      missing_purchase_time_count: missingPurchaseTimeCount
    })
  );

  if (maxAuthoritativeAgeMs !== null && maxAuthoritativeAgeMs > 48 * 60 * 60 * 1000) {
    console.error(
      JSON.stringify({
        level: 'ERROR',
        event: 'CRITICAL_ACK_DEADLINE',
        max_authoritative_age_ms: maxAuthoritativeAgeMs,
        queue_depth: queueDepth
      })
    );
  }

  return {
    claimedCount: claimedRows.length,
    successCount,
    failureCount,
    revokedCount,
    queueDepth,
    maxAuthoritativeAgeMs,
    maxServerObservationAgeMs,
    missingPurchaseTimeCount
  };
}
