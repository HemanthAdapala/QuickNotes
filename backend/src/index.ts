// backend/src/index.ts
// Cloudflare Workers Entrypoint for QuickNotes Premium Entitlement Service (BUG-001)

import {
  Env,
  LeaseClaims,
  VerifyPurchaseRequest,
  VerifyPurchaseResponse
} from './types';
import { encryptToken, sha256Hex, signJwsLease } from './crypto';
import {
  acknowledgePurchase,
  evaluateGooglePlayResponse,
  fetchProductPurchaseV2,
  getGoogleAccessToken
} from './google-play';
import {
  insertCancellationTombstone,
  insertPurchase,
  rereadPurchase,
  updatePurchaseCas
} from './db';
import { processAckQueue } from './cron';

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);

    // Health check endpoint
    if (request.method === 'GET' && url.pathname === '/health') {
      return new Response(JSON.stringify({ status: 'ok' }), {
        headers: { 'Content-Type': 'application/json' }
      });
    }

    // Purchase verification endpoint
    if (request.method === 'POST' && url.pathname === '/verify-purchase') {
      return handleVerifyPurchase(request, env);
    }

    return new Response(JSON.stringify({ error: 'Not Found' }), {
      status: 404,
      headers: { 'Content-Type': 'application/json' }
    });
  },

  async scheduled(event: ScheduledEvent, env: Env, ctx: ExecutionContext): Promise<void> {
    ctx.waitUntil(processAckQueue(env));
  }
};

export async function handleVerifyPurchase(request: Request, env: Env): Promise<Response> {
  const nowMs = Date.now();
  let body: VerifyPurchaseRequest;

  try {
    body = await request.json();
  } catch (_) {
    return new Response(JSON.stringify({ error: 'Invalid JSON payload' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' }
    });
  }

  const {
    purchase_token,
    package_name,
    product_id,
    client_version,
    supported_key_versions
  } = body;

  if (!purchase_token || !package_name || !product_id) {
    return new Response(JSON.stringify({ error: 'Missing required fields' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' }
    });
  }

  // 1. Strict Server-Side Validation of Package Name and Product ID
  if (package_name !== env.PACKAGE_NAME || product_id !== env.PRODUCT_ID) {
    return new Response(
      JSON.stringify({ error: 'Package name or Product ID mismatch' }),
      { status: 400, headers: { 'Content-Type': 'application/json' } }
    );
  }

  // 2. Minimum Supported App Version Check
  if (env.MINIMUM_SUPPORTED_APP_VERSION) {
    const minVersion = parseInt(env.MINIMUM_SUPPORTED_APP_VERSION, 10);
    if (client_version !== undefined && client_version < minVersion) {
      return new Response(
        JSON.stringify({
          error: 'UPGRADE_REQUIRED',
          message: 'Please update Quick Notes to restore your Premium purchase.'
        }),
        { status: 426, headers: { 'Content-Type': 'application/json' } }
      );
    }
  }

  // 3. Server-Controlled Signing Key Selection (Downgrade-Resistant)
  const allowedServerKeys = env.SERVER_ALLOWED_SIGNING_KEYS.split(',').map(k => k.trim());
  let selectedSigningKeyId = env.PRIMARY_SIGNING_KEY_ID;

  if (supported_key_versions && Array.isArray(supported_key_versions)) {
    // Intersect client-supported keys with server-allowed keys
    const validKeys = supported_key_versions.filter(k => allowedServerKeys.includes(k));
    if (validKeys.length > 0) {
      // Pick highest version in intersection (or default primary if present)
      selectedSigningKeyId = validKeys.includes(env.PRIMARY_SIGNING_KEY_ID)
        ? env.PRIMARY_SIGNING_KEY_ID
        : validKeys[validKeys.length - 1];
    }
  }

  const tokenHash = await sha256Hex(purchase_token);

  // 4. Query Google Play Developer API
  if (!env.GOOGLE_SERVICE_ACCOUNT_JSON) {
    return new Response(
      JSON.stringify({ error: 'Google Service Account credentials not configured' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }

  let accessToken: string;
  try {
    accessToken = await getGoogleAccessToken(env.GOOGLE_SERVICE_ACCOUNT_JSON);
  } catch (err: any) {
    console.error('[AUTH_ERROR] Google Service Account token exchange failed:', err);
    return new Response(
      JSON.stringify({ error: 'Upstream authentication failed' }),
      { status: 502, headers: { 'Content-Type': 'application/json' } }
    );
  }

  const googleResp = await fetchProductPurchaseV2(package_name, purchase_token, accessToken);
  if (googleResp.status !== 200 || !googleResp.data) {
    return new Response(
      JSON.stringify({
        error: 'UPSTREAM_LOOKUP_FAILED',
        status: googleResp.status,
        details: googleResp.errorText
      }),
      { status: 502, headers: { 'Content-Type': 'application/json' } }
    );
  }

  const evalResult = evaluateGooglePlayResponse(googleResp.data, env.PACKAGE_NAME, env.PRODUCT_ID);

  // ── BRANCH 1: AUTHORITATIVE CANCELLATION ────────────────────────────────────
  if (evalResult.purchaseState === 'CANCELLED') {
    // Persist terminal tombstone / revocation state
    const existing = await rereadPurchase(env.DB, tokenHash);
    let commitSuccess = false;

    if (!existing) {
      const tombstoneRes = await insertCancellationTombstone(env.DB, {
        token_hash: tokenHash,
        key_version: selectedSigningKeyId,
        product_id: env.PRODUCT_ID,
        package_name: env.PACKAGE_NAME,
        acknowledgement_state: evalResult.acknowledgementState === 'ACKNOWLEDGED'
          ? 'ACKNOWLEDGED'
          : 'NOT_APPLICABLE',
        purchase_time_ms: evalResult.purchaseCompletionTimeMs,
        now_ms: nowMs
      });
      commitSuccess = tombstoneRes.success;
    } else if (existing.status !== 'REVOKED') {
      commitSuccess = await updatePurchaseCas(env.DB, {
        token_hash: tokenHash,
        expected_state_version: existing.state_version,
        status: 'REVOKED',
        revocation_reason: 'GOOGLE_PLAY_CANCELLED',
        acknowledgement_state: evalResult.acknowledgementState === 'ACKNOWLEDGED'
          ? 'ACKNOWLEDGED'
          : 'NOT_APPLICABLE',
        encrypted_token: null, // Purged: Authoritatively CANCELLED
        ack_attempt_count: existing.ack_attempt_count,
        next_ack_attempt_at: null,
        ack_claim_expires_at: null,
        last_ack_failure_reason: 'PURCHASE_CANCELLED_UPSTREAM',
        last_check_status: 'REVOKED',
        purchase_time_ms: evalResult.purchaseCompletionTimeMs ?? existing.purchase_time_ms,
        now_ms: nowMs
      });
    } else {
      commitSuccess = true; // Already terminally revoked
    }

    if (!commitSuccess) {
      // Fail closed on persistence failure
      return new Response(
        JSON.stringify({ error: 'Failed to persist cancellation state' }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      );
    }

    const respPayload: VerifyPurchaseResponse = {
      status: 'REVOKED',
      reason: 'GOOGLE_PLAY_CANCELLED'
    };
    return new Response(JSON.stringify(respPayload), {
      status: 403,
      headers: { 'Content-Type': 'application/json' }
    });
  }

  // ── BRANCH 2: PAYMENT PENDING ──────────────────────────────────────────────
  if (evalResult.purchaseState === 'PENDING') {
    // Payment deferred/pending; entitlement cannot be granted yet
    const respPayload: VerifyPurchaseResponse = {
      status: 'PENDING',
      reason: 'PAYMENT_PENDING'
    };
    return new Response(JSON.stringify(respPayload), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    });
  }

  // ── BRANCH 3: INDETERMINATE OR UNRECOGNIZED STATE ──────────────────────────
  if (evalResult.purchaseState !== 'PURCHASED') {
    return new Response(
      JSON.stringify({ error: 'Indeterminate purchase state' }),
      { status: 502, headers: { 'Content-Type': 'application/json' } }
    );
  }

  // ── BRANCH 4: PURCHASED (ACTIVE) ───────────────────────────────────────────
  let ackState = evalResult.acknowledgementState;

  // Attempt inline acknowledgement if pending
  if (ackState === 'PENDING') {
    const inlineAck = await acknowledgePurchase(env.PACKAGE_NAME, env.PRODUCT_ID, purchase_token, accessToken);
    if (inlineAck.status === 200 || inlineAck.status === 204) {
      ackState = 'ACKNOWLEDGED';
    }
  }

  // Encrypt token only if still pending acknowledgement
  let encryptedToken: string | null = null;
  let nextAckAttemptAt: number | null = null;
  if (ackState === 'PENDING') {
    encryptedToken = await encryptToken(purchase_token, selectedSigningKeyId, env.TOKEN_ENCRYPTION_KEYRING);
    nextAckAttemptAt = nowMs + 5 * 60 * 1000; // First retry in 5 minutes
  }

  // Persist or update D1
  const existing = await rereadPurchase(env.DB, tokenHash);
  let commitSuccess = false;

  if (!existing) {
    const insertRes = await insertPurchase(env.DB, {
      token_hash: tokenHash,
      encrypted_token: encryptedToken,
      key_version: selectedSigningKeyId,
      product_id: env.PRODUCT_ID,
      package_name: env.PACKAGE_NAME,
      status: 'ACTIVE',
      acknowledgement_state: ackState,
      next_ack_attempt_at: nextAckAttemptAt,
      purchase_time_ms: evalResult.purchaseCompletionTimeMs,
      now_ms: nowMs
    });

    if (insertRes.conflict) {
      // Primary-key collision: reread and reconcile
      const re = await rereadPurchase(env.DB, tokenHash);
      if (re && re.status === 'REVOKED') {
        // Terminal revocation protection
        return new Response(
          JSON.stringify({ status: 'REVOKED', reason: 'GOOGLE_PLAY_CANCELLED' }),
          { status: 403, headers: { 'Content-Type': 'application/json' } }
        );
      }
      commitSuccess = true;
    } else {
      commitSuccess = insertRes.success;
    }
  } else {
    if (existing.status === 'REVOKED') {
      // Terminal revocation protection: A revoked record cannot be resurrected
      return new Response(
        JSON.stringify({ status: 'REVOKED', reason: 'GOOGLE_PLAY_CANCELLED' }),
        { status: 403, headers: { 'Content-Type': 'application/json' } }
      );
    }

    commitSuccess = await updatePurchaseCas(env.DB, {
      token_hash: tokenHash,
      expected_state_version: existing.state_version,
      status: 'ACTIVE',
      revocation_reason: null,
      acknowledgement_state: ackState,
      encrypted_token: ackState === 'ACKNOWLEDGED' ? null : (encryptedToken ?? existing.encrypted_token),
      ack_attempt_count: existing.ack_attempt_count,
      next_ack_attempt_at: ackState === 'ACKNOWLEDGED' ? null : existing.next_ack_attempt_at,
      ack_claim_expires_at: null,
      last_ack_failure_reason: null,
      last_check_status: 'SUCCESS',
      purchase_time_ms: evalResult.purchaseCompletionTimeMs ?? existing.purchase_time_ms,
      now_ms: nowMs
    });
  }

  if (!commitSuccess) {
    return new Response(
      JSON.stringify({ error: 'Failed to commit purchase entitlement state' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }

  // 5. Pre-Issuance Re-Check (Defense-in-Depth against rapid cancellation)
  const preCheckResp = await fetchProductPurchaseV2(package_name, purchase_token, accessToken);
  if (preCheckResp.status === 200 && preCheckResp.data) {
    const preEval = evaluateGooglePlayResponse(preCheckResp.data, env.PACKAGE_NAME, env.PRODUCT_ID);
    if (preEval.purchaseState === 'CANCELLED') {
      const current = await rereadPurchase(env.DB, tokenHash);
      let commitSuccess = false;

      if (current && current.status !== 'REVOKED') {
        commitSuccess = await updatePurchaseCas(env.DB, {
          token_hash: tokenHash,
          expected_state_version: current.state_version,
          status: 'REVOKED',
          revocation_reason: 'GOOGLE_PLAY_CANCELLED',
          acknowledgement_state: 'NOT_APPLICABLE',
          encrypted_token: null,
          ack_attempt_count: current.ack_attempt_count,
          next_ack_attempt_at: null,
          ack_claim_expires_at: null,
          last_ack_failure_reason: 'PURCHASE_CANCELLED_UPSTREAM',
          last_check_status: 'REVOKED',
          purchase_time_ms: preEval.purchaseCompletionTimeMs ?? current.purchase_time_ms,
          now_ms: nowMs
        });
      } else if (current && current.status === 'REVOKED') {
        commitSuccess = true;
      }

      if (!commitSuccess) {
        return new Response(
          JSON.stringify({ error: 'Failed to persist cancellation state' }),
          { status: 500, headers: { 'Content-Type': 'application/json' } }
        );
      }

      return new Response(
        JSON.stringify({ status: 'REVOKED', reason: 'GOOGLE_PLAY_CANCELLED' }),
        { status: 403, headers: { 'Content-Type': 'application/json' } }
      );
    }
  }

  // 6. Sign 7-Day Ed25519 JWS Lease
  const iatSec = Math.floor(nowMs / 1000);
  const expSec = iatSec + 604800; // Exactly 7 days (604,800 seconds)

  const claims: LeaseClaims = {
    iss: env.ISSUER_URL,
    aud: env.PACKAGE_NAME,
    sub: tokenHash,
    entitlement: 'premium',
    product_id: env.PRODUCT_ID,
    status: 'ACTIVE',
    iat: iatSec,
    nbf: iatSec,
    exp: expSec,
    jti: crypto.randomUUID()
  };

  let leaseToken: string;
  try {
    leaseToken = await signJwsLease(claims, selectedSigningKeyId, env.SIGNING_KEYRING);
  } catch (err: any) {
    console.error('[CRYPTO_SIGN_ERROR] Failed to sign JWS lease:', err);
    return new Response(
      JSON.stringify({ error: 'Failed to generate cryptographic entitlement lease' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }

  const responsePayload: VerifyPurchaseResponse = {
    status: 'ACTIVE',
    lease_token: leaseToken,
    expires_at: expSec
  };

  return new Response(JSON.stringify(responsePayload), {
    status: 200,
    headers: { 'Content-Type': 'application/json' }
  });
}
