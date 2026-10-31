// backend/src/db.ts
// Database operations for Cloudflare D1 with CAS concurrency and tombstone protection

import { AcknowledgementState, PurchaseRow, PurchaseStatus } from './types';

export async function rereadPurchase(
  db: D1Database,
  tokenHash: string
): Promise<PurchaseRow | null> {
  const row = await db
    .prepare('SELECT * FROM purchases WHERE token_hash = ?')
    .bind(tokenHash)
    .first<PurchaseRow>();
  return row ?? null;
}

export async function insertPurchase(
  db: D1Database,
  data: {
    token_hash: string;
    encrypted_token: string | null;
    key_version: string;
    product_id: string;
    package_name: string;
    status: PurchaseStatus;
    acknowledgement_state: AcknowledgementState;
    next_ack_attempt_at: number | null;
    purchase_time_ms: number | null;
    now_ms: number;
  }
): Promise<{ success: boolean; conflict: boolean }> {
  try {
    const res = await db
      .prepare(
        `INSERT INTO purchases (
          token_hash, encrypted_token, key_version, product_id, package_name,
          status, revocation_reason, acknowledgement_state, ack_attempt_count,
          next_ack_attempt_at, ack_claim_expires_at, last_ack_failure_reason,
          last_check_status, purchase_time_ms, state_version, created_at_ms, updated_at_ms
        ) VALUES (?, ?, ?, ?, ?, ?, NULL, ?, 0, ?, NULL, NULL, 'SUCCESS', ?, 1, ?, ?)`
      )
      .bind(
        data.token_hash,
        data.encrypted_token,
        data.key_version,
        data.product_id,
        data.package_name,
        data.status,
        data.acknowledgement_state,
        data.next_ack_attempt_at,
        data.purchase_time_ms,
        data.now_ms,
        data.now_ms
      )
      .run();

    return { success: (res.meta.changes ?? 0) > 0, conflict: false };
  } catch (err: any) {
    const msg = String(err?.message ?? err);
    if (msg.includes('UNIQUE constraint failed') || msg.includes('PRIMARY KEY')) {
      return { success: false, conflict: true };
    }
    throw err;
  }
}

export async function insertCancellationTombstone(
  db: D1Database,
  data: {
    token_hash: string;
    key_version: string;
    product_id: string;
    package_name: string;
    acknowledgement_state: AcknowledgementState;
    purchase_time_ms: number | null;
    now_ms: number;
  }
): Promise<{ success: boolean; conflict: boolean }> {
  try {
    const res = await db
      .prepare(
        `INSERT INTO purchases (
          token_hash, encrypted_token, key_version, product_id, package_name,
          status, revocation_reason, acknowledgement_state, ack_attempt_count,
          next_ack_attempt_at, ack_claim_expires_at, last_ack_failure_reason,
          last_check_status, purchase_time_ms, state_version, created_at_ms, updated_at_ms
        ) VALUES (?, NULL, ?, ?, ?, 'REVOKED', 'GOOGLE_PLAY_CANCELLED', ?, 0, NULL, NULL, 'PURCHASE_CANCELLED_UPSTREAM', 'REVOKED', ?, 1, ?, ?)`
      )
      .bind(
        data.token_hash,
        data.key_version,
        data.product_id,
        data.package_name,
        data.acknowledgement_state,
        data.purchase_time_ms,
        data.now_ms,
        data.now_ms
      )
      .run();

    return { success: (res.meta.changes ?? 0) > 0, conflict: false };
  } catch (err: any) {
    const msg = String(err?.message ?? err);
    if (msg.includes('UNIQUE constraint failed') || msg.includes('PRIMARY KEY')) {
      return { success: false, conflict: true };
    }
    throw err;
  }
}

export async function updatePurchaseCas(
  db: D1Database,
  params: {
    token_hash: string;
    expected_state_version: number;
    status: PurchaseStatus;
    revocation_reason: string | null;
    acknowledgement_state: AcknowledgementState;
    encrypted_token: string | null;
    ack_attempt_count: number;
    next_ack_attempt_at: number | null;
    ack_claim_expires_at: number | null;
    last_ack_failure_reason: string | null;
    last_check_status: string;
    purchase_time_ms?: number | null;
    now_ms: number;
  }
): Promise<boolean> {
  const res = await db
    .prepare(
      `UPDATE purchases 
      SET status = ?,
          revocation_reason = ?,
          acknowledgement_state = ?,
          encrypted_token = ?,
          ack_attempt_count = ?,
          next_ack_attempt_at = ?,
          ack_claim_expires_at = ?,
          last_ack_failure_reason = ?,
          last_check_status = ?,
          purchase_time_ms = COALESCE(?, purchase_time_ms),
          state_version = state_version + 1,
          updated_at_ms = ?
      WHERE token_hash = ?
        AND state_version = ?
        AND status != 'REVOKED'`
    )
    .bind(
      params.status,
      params.revocation_reason,
      params.acknowledgement_state,
      params.encrypted_token,
      params.ack_attempt_count,
      params.next_ack_attempt_at,
      params.ack_claim_expires_at,
      params.last_ack_failure_reason,
      params.last_check_status,
      params.purchase_time_ms ?? null,
      params.now_ms,
      params.token_hash,
      params.expected_state_version
    )
    .run();

  return (res.meta.changes ?? 0) > 0;
}

export async function claimCandidateRows(
  db: D1Database,
  nowMs: number,
  limit: number = 3
): Promise<PurchaseRow[]> {
  // 1. Query eligible rows using the partial index
  const candidatesResult = await db
    .prepare(
      `SELECT * FROM purchases
      WHERE status = 'ACTIVE'
        AND acknowledgement_state = 'PENDING'
        AND encrypted_token IS NOT NULL
        AND next_ack_attempt_at IS NOT NULL
        AND next_ack_attempt_at <= ?
        AND (ack_claim_expires_at IS NULL OR ack_claim_expires_at <= ?)
      ORDER BY next_ack_attempt_at ASC, created_at_ms ASC, token_hash ASC
      LIMIT ?`
    )
    .bind(nowMs, nowMs, limit)
    .all<PurchaseRow>();

  const candidates = candidatesResult.results ?? [];
  const claimedRows: PurchaseRow[] = [];

  // 2. Atomically claim each candidate row with a 5-minute lease (300,000 ms)
  const leaseDurationMs = 300000;
  for (const candidate of candidates) {
    const claimRes = await db
      .prepare(
        `UPDATE purchases
        SET ack_claim_expires_at = ?,
            state_version = state_version + 1,
            updated_at_ms = ?
        WHERE token_hash = ?
          AND state_version = ?
          AND status = 'ACTIVE'
          AND acknowledgement_state = 'PENDING'
          AND next_ack_attempt_at IS NOT NULL
          AND next_ack_attempt_at <= ?
          AND (ack_claim_expires_at IS NULL OR ack_claim_expires_at <= ?)`
      )
      .bind(
        nowMs + leaseDurationMs,
        nowMs,
        candidate.token_hash,
        candidate.state_version,
        nowMs,
        nowMs
      )
      .run();

    if ((claimRes.meta.changes ?? 0) > 0) {
      // Row claimed successfully; increment held state_version
      claimedRows.push({
        ...candidate,
        ack_claim_expires_at: nowMs + leaseDurationMs,
        state_version: candidate.state_version + 1
      });
    }
  }

  return claimedRows;
}
