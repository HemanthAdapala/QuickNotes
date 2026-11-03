// backend/test/d1_workflow_test.ts
// In-Memory D1 Mock Workflow Tests for Concurrency, CAS, and Tombstones

import { describe, it } from 'node:test';
import assert from 'node:assert';
import {
  claimCandidateRows,
  insertCancellationTombstone,
  insertPurchase,
  rereadPurchase,
  updatePurchaseCas
} from '../src/db';
import { PurchaseRow, PurchaseStatus } from '../src/types';

// Minimal in-memory mock of Cloudflare D1Database for unit testing
class MockD1Database {
  rows: Map<string, PurchaseRow> = new Map();

  prepare(query: string) {
    const db = this;
    return {
      _query: query,
      _bindings: [] as any[],
      bind(...args: any[]) {
        this._bindings = args;
        return this;
      },
      async first<T>(): Promise<T | null> {
        if (this._query.includes('SELECT * FROM purchases WHERE token_hash = ?')) {
          const hash = this._bindings[0];
          const row = db.rows.get(hash);
          return (row ? { ...row } : null) as T | null;
        }
        return null;
      },
      async all<T>(): Promise<{ results: T[] }> {
        if (this._query.includes('SELECT * FROM purchases')) {
          const nowMs = this._bindings[0];
          const limit = this._bindings[2] ?? 3;
          const filtered: PurchaseRow[] = [];
          for (const row of db.rows.values()) {
            if (
              row.status === 'ACTIVE' &&
              row.acknowledgement_state === 'PENDING' &&
              row.encrypted_token !== null &&
              row.next_ack_attempt_at !== null &&
              row.next_ack_attempt_at <= nowMs &&
              (row.ack_claim_expires_at === null || row.ack_claim_expires_at <= nowMs)
            ) {
              filtered.push({ ...row });
            }
          }
          // Sort by next_ack_attempt_at ASC, created_at_ms ASC, token_hash ASC
          filtered.sort((a, b) => {
            if (a.next_ack_attempt_at! !== b.next_ack_attempt_at!) {
              return a.next_ack_attempt_at! - b.next_ack_attempt_at!;
            }
            if (a.created_at_ms !== b.created_at_ms) {
              return a.created_at_ms - b.created_at_ms;
            }
            return a.token_hash.localeCompare(b.token_hash);
          });
          return { results: filtered.slice(0, limit) as unknown as T[] };
        }
        return { results: [] };
      },
      async run(): Promise<{ meta: { changes: number } }> {
        // Handle INSERT
        if (this._query.startsWith('INSERT INTO purchases')) {
          let token_hash: string;
          let encrypted_token: string | null = null;
          let key_version: string;
          let product_id: string;
          let package_name: string;
          let status: PurchaseStatus;
          let revocation_reason: string | null = null;
          let ack_state: any;
          let next_ack_attempt_at: number | null = null;
          let purchase_time_ms: number | null = null;
          let created_at_ms: number;
          let updated_at_ms: number;

          if (this._query.includes("'REVOKED'")) {
            // Tombstone insert
            token_hash = this._bindings[0];
            key_version = this._bindings[1];
            product_id = this._bindings[2];
            package_name = this._bindings[3];
            status = 'REVOKED';
            revocation_reason = 'GOOGLE_PLAY_CANCELLED';
            ack_state = this._bindings[4];
            purchase_time_ms = this._bindings[5];
            created_at_ms = this._bindings[6];
            updated_at_ms = this._bindings[7];
          } else {
            // Active purchase insert
            token_hash = this._bindings[0];
            encrypted_token = this._bindings[1];
            key_version = this._bindings[2];
            product_id = this._bindings[3];
            package_name = this._bindings[4];
            status = this._bindings[5];
            ack_state = this._bindings[6];
            next_ack_attempt_at = this._bindings[7];
            purchase_time_ms = this._bindings[8];
            created_at_ms = this._bindings[9];
            updated_at_ms = this._bindings[10];
          }

          if (db.rows.has(token_hash)) {
            const err: any = new Error('UNIQUE constraint failed: purchases.token_hash');
            throw err;
          }

          db.rows.set(token_hash, {
            token_hash,
            encrypted_token,
            key_version,
            product_id,
            package_name,
            status,
            revocation_reason,
            acknowledgement_state: ack_state,
            ack_attempt_count: 0,
            next_ack_attempt_at,
            ack_claim_expires_at: null,
            last_ack_failure_reason: status === 'REVOKED' ? 'PURCHASE_CANCELLED_UPSTREAM' : null,
            last_check_status: status === 'REVOKED' ? 'REVOKED' : 'SUCCESS',
            purchase_time_ms,
            state_version: 1,
            created_at_ms,
            updated_at_ms
          });

          return { meta: { changes: 1 } };
        }

        // Handle Claim UPDATE
        if (this._query.includes('SET ack_claim_expires_at = ?')) {
          const [leaseExpiry, nowMs, token_hash, expected_version] = this._bindings;
          const row = db.rows.get(token_hash);
          if (
            row &&
            row.state_version === expected_version &&
            row.status === 'ACTIVE' &&
            row.acknowledgement_state === 'PENDING' &&
            row.next_ack_attempt_at !== null &&
            row.next_ack_attempt_at <= nowMs &&
            (row.ack_claim_expires_at === null || row.ack_claim_expires_at <= nowMs)
          ) {
            row.ack_claim_expires_at = leaseExpiry;
            row.state_version++;
            row.updated_at_ms = nowMs;
            return { meta: { changes: 1 } };
          }
          return { meta: { changes: 0 } };
        }

        // Handle CAS UPDATE
        if (this._query.startsWith('UPDATE purchases')) {
          const [
            status, revocation_reason, ack_state, encrypted_token,
            ack_attempt_count, next_ack_attempt_at, ack_claim_expires_at,
            last_ack_failure_reason, last_check_status, purchase_time_ms,
            now_ms, token_hash, expected_state_version
          ] = this._bindings;

          const row = db.rows.get(token_hash);
          if (!row) return { meta: { changes: 0 } };

          // Enforce CAS version match and terminal revocation protection
          if (row.state_version !== expected_state_version || row.status === 'REVOKED') {
            return { meta: { changes: 0 } };
          }

          row.status = status;
          row.revocation_reason = revocation_reason;
          row.acknowledgement_state = ack_state;
          row.encrypted_token = encrypted_token;
          row.ack_attempt_count = ack_attempt_count;
          row.next_ack_attempt_at = next_ack_attempt_at;
          row.ack_claim_expires_at = ack_claim_expires_at;
          row.last_ack_failure_reason = last_ack_failure_reason;
          row.last_check_status = last_check_status;
          if (purchase_time_ms !== null) row.purchase_time_ms = purchase_time_ms;
          row.state_version++;
          row.updated_at_ms = now_ms;

          return { meta: { changes: 1 } };
        }

        return { meta: { changes: 0 } };
      }
    };
  }
}

describe('D1 Database Ledger, Tombstones, and CAS Concurrency', () => {
  const pkg = 'com.quicknotes.byhmnth';
  const sku = 'quicknotes_premium_lifetime';
  const now = 1700000000000;

  it('inserts active purchase cleanly on first observation', async () => {
    const mockDb = new MockD1Database() as unknown as D1Database;
    const res = await insertPurchase(mockDb, {
      token_hash: 'hash_123',
      encrypted_token: 'v1:iv:ciphertext',
      key_version: 'v1',
      product_id: sku,
      package_name: pkg,
      status: 'ACTIVE',
      acknowledgement_state: 'PENDING',
      next_ack_attempt_at: now + 300000,
      purchase_time_ms: now,
      now_ms: now
    });

    assert.strictEqual(res.success, true);
    assert.strictEqual(res.conflict, false);

    const row = await rereadPurchase(mockDb, 'hash_123');
    assert.ok(row);
    assert.strictEqual(row.status, 'ACTIVE');
    assert.strictEqual(row.state_version, 1);
  });

  it('inserts cancellation tombstone when no prior row exists', async () => {
    const mockDb = new MockD1Database() as unknown as D1Database;
    const res = await insertCancellationTombstone(mockDb, {
      token_hash: 'canceled_hash_456',
      key_version: 'v1',
      product_id: sku,
      package_name: pkg,
      acknowledgement_state: 'NOT_APPLICABLE',
      purchase_time_ms: null,
      now_ms: now
    });

    assert.strictEqual(res.success, true);
    assert.strictEqual(res.conflict, false);

    const row = await rereadPurchase(mockDb, 'canceled_hash_456');
    assert.ok(row);
    assert.strictEqual(row.status, 'REVOKED');
    assert.strictEqual(row.encrypted_token, null);
    assert.strictEqual(row.next_ack_attempt_at, null);
  });

  it('blocks stale active insert on existing cancellation tombstone (anti-resurrection)', async () => {
    const mockDb = new MockD1Database() as unknown as D1Database;

    // 1. Tombstone is committed first
    await insertCancellationTombstone(mockDb, {
      token_hash: 'race_token_789',
      key_version: 'v1',
      product_id: sku,
      package_name: pkg,
      acknowledgement_state: 'NOT_APPLICABLE',
      purchase_time_ms: now,
      now_ms: now
    });

    // 2. Delayed request attempts stale insert of ACTIVE
    const staleInsert = await insertPurchase(mockDb, {
      token_hash: 'race_token_789',
      encrypted_token: 'v1:iv:secret',
      key_version: 'v1',
      product_id: sku,
      package_name: pkg,
      status: 'ACTIVE',
      acknowledgement_state: 'PENDING',
      next_ack_attempt_at: now + 300000,
      purchase_time_ms: now,
      now_ms: now + 1000
    });

    // Insertion must fail with conflict
    assert.strictEqual(staleInsert.success, false);
    assert.strictEqual(staleInsert.conflict, true);

    // Reread confirms row remains terminally REVOKED
    const row = await rereadPurchase(mockDb, 'race_token_789');
    assert.ok(row);
    assert.strictEqual(row.status, 'REVOKED');
    assert.strictEqual(row.encrypted_token, null);
  });

  it('CAS updates state and increments state_version correctly', async () => {
    const mockDb = new MockD1Database() as unknown as D1Database;
    await insertPurchase(mockDb, {
      token_hash: 'cas_test_1',
      encrypted_token: 'v1:iv:c1',
      key_version: 'v1',
      product_id: sku,
      package_name: pkg,
      status: 'ACTIVE',
      acknowledgement_state: 'PENDING',
      next_ack_attempt_at: now,
      purchase_time_ms: now,
      now_ms: now
    });

    // Attempt CAS update with correct state_version (1)
    const success = await updatePurchaseCas(mockDb, {
      token_hash: 'cas_test_1',
      expected_state_version: 1,
      status: 'ACTIVE',
      revocation_reason: null,
      acknowledgement_state: 'ACKNOWLEDGED',
      encrypted_token: null, // Purged upon acknowledgement
      ack_attempt_count: 1,
      next_ack_attempt_at: null,
      ack_claim_expires_at: null,
      last_ack_failure_reason: null,
      last_check_status: 'SUCCESS',
      now_ms: now + 500
    });

    assert.strictEqual(success, true);
    const row = await rereadPurchase(mockDb, 'cas_test_1');
    assert.strictEqual(row!.state_version, 2);
    assert.strictEqual(row!.acknowledgement_state, 'ACKNOWLEDGED');
    assert.strictEqual(row!.encrypted_token, null);

    // Attempt CAS update with stale state_version (1) -> Must fail
    const staleAttempt = await updatePurchaseCas(mockDb, {
      token_hash: 'cas_test_1',
      expected_state_version: 1,
      status: 'ACTIVE',
      revocation_reason: null,
      acknowledgement_state: 'ACKNOWLEDGED',
      encrypted_token: null,
      ack_attempt_count: 2,
      next_ack_attempt_at: null,
      ack_claim_expires_at: null,
      last_ack_failure_reason: null,
      last_check_status: 'SUCCESS',
      now_ms: now + 1000
    });

    assert.strictEqual(staleAttempt, false);
  });

  it('claims candidate rows atomically with in-flight lease and excludes non-eligible rows', async () => {
    const mockDb = new MockD1Database() as unknown as D1Database;

    // Row 1: Eligible (ACTIVE, PENDING, next_ack_attempt_at in past)
    await insertPurchase(mockDb, {
      token_hash: 'eligible_1',
      encrypted_token: 'v1:iv:e1',
      key_version: 'v1',
      product_id: sku,
      package_name: pkg,
      status: 'ACTIVE',
      acknowledgement_state: 'PENDING',
      next_ack_attempt_at: now - 10000,
      purchase_time_ms: now - 50000,
      now_ms: now - 50000
    });

    // Row 2: Future attempt (not due yet)
    await insertPurchase(mockDb, {
      token_hash: 'future_2',
      encrypted_token: 'v1:iv:e2',
      key_version: 'v1',
      product_id: sku,
      package_name: pkg,
      status: 'ACTIVE',
      acknowledgement_state: 'PENDING',
      next_ack_attempt_at: now + 100000,
      purchase_time_ms: now,
      now_ms: now
    });

    // Row 3: Tombstone (REVOKED) -> Excluded
    await insertCancellationTombstone(mockDb, {
      token_hash: 'revoked_3',
      key_version: 'v1',
      product_id: sku,
      package_name: pkg,
      acknowledgement_state: 'NOT_APPLICABLE',
      purchase_time_ms: null,
      now_ms: now
    });

    const claimed = await claimCandidateRows(mockDb, now, 3);
    assert.strictEqual(claimed.length, 1);
    assert.strictEqual(claimed[0].token_hash, 'eligible_1');
    assert.strictEqual(claimed[0].state_version, 2); // Incremented on claim
    assert.ok(claimed[0].ack_claim_expires_at! > now);

    // Second worker attempting to claim within the 5m lease window gets 0 rows
    const secondClaim = await claimCandidateRows(mockDb, now + 1000, 3);
    assert.strictEqual(secondClaim.length, 0);
  });

  describe('D1 Snapshot Restore & Anti-Resurrection Security Invariants', () => {
    it('restored stale ACTIVE snapshot transitions to REVOKED when Google Play confirms cancellation', async () => {
      const mockDb = new MockD1Database() as unknown as D1Database;

      // 1. Simulate an old database snapshot restored to D1, where purchase was ACTIVE before being cancelled upstream
      await insertPurchase(mockDb, {
        token_hash: 'restored_active_hash',
        encrypted_token: 'v1:iv:stale_active_token',
        key_version: 'v1',
        product_id: sku,
        package_name: pkg,
        status: 'ACTIVE',
        acknowledgement_state: 'ACKNOWLEDGED',
        next_ack_attempt_at: null,
        purchase_time_ms: now - 100000,
        now_ms: now - 100000
      });

      const restoredRow = await rereadPurchase(mockDb, 'restored_active_hash');
      assert.ok(restoredRow);
      assert.strictEqual(restoredRow.status, 'ACTIVE');
      assert.strictEqual(restoredRow.state_version, 1);

      // 2. Client / Cron triggers verification: Google Play confirms purchaseState: 'CANCELLED'
      // The worker must update the restored ACTIVE row to terminally REVOKED and purge the token
      const commitSuccess = await updatePurchaseCas(mockDb, {
        token_hash: 'restored_active_hash',
        expected_state_version: restoredRow.state_version,
        status: 'REVOKED',
        revocation_reason: 'GOOGLE_PLAY_CANCELLED',
        acknowledgement_state: 'ACKNOWLEDGED',
        encrypted_token: null, // Purged
        ack_attempt_count: restoredRow.ack_attempt_count,
        next_ack_attempt_at: null,
        ack_claim_expires_at: null,
        last_ack_failure_reason: 'PURCHASE_CANCELLED_UPSTREAM',
        last_check_status: 'REVOKED',
        purchase_time_ms: restoredRow.purchase_time_ms,
        now_ms: now
      });

      assert.strictEqual(commitSuccess, true);

      // 3. Confirm D1 is now terminally REVOKED with encrypted_token purged
      const reconciled = await rereadPurchase(mockDb, 'restored_active_hash');
      assert.ok(reconciled);
      assert.strictEqual(reconciled.status, 'REVOKED');
      assert.strictEqual(reconciled.revocation_reason, 'GOOGLE_PLAY_CANCELLED');
      assert.strictEqual(reconciled.encrypted_token, null);
      assert.strictEqual(reconciled.state_version, 2);
    });

    it('anti-resurrection: committed REVOKED row strictly rejects CAS resurrection to ACTIVE', async () => {
      const mockDb = new MockD1Database() as unknown as D1Database;

      // 1. Seed a committed REVOKED row
      await insertCancellationTombstone(mockDb, {
        token_hash: 'terminally_revoked_hash',
        key_version: 'v1',
        product_id: sku,
        package_name: pkg,
        acknowledgement_state: 'NOT_APPLICABLE',
        purchase_time_ms: now - 50000,
        now_ms: now - 50000
      });

      const tombstone = await rereadPurchase(mockDb, 'terminally_revoked_hash');
      assert.ok(tombstone);
      assert.strictEqual(tombstone.status, 'REVOKED');

      // 2. An unauthorized or stale request attempts to CAS-update status to ACTIVE
      const resurrectionSuccess = await updatePurchaseCas(mockDb, {
        token_hash: 'terminally_revoked_hash',
        expected_state_version: tombstone.state_version,
        status: 'ACTIVE',
        revocation_reason: null,
        acknowledgement_state: 'ACKNOWLEDGED',
        encrypted_token: 'v1:iv:resurrected_token',
        ack_attempt_count: 0,
        next_ack_attempt_at: null,
        ack_claim_expires_at: null,
        last_ack_failure_reason: null,
        last_check_status: 'SUCCESS',
        purchase_time_ms: now,
        now_ms: now
      });

      // CAS update MUST fail due to SQL 'AND status != REVOKED' constraint
      assert.strictEqual(resurrectionSuccess, false);

      // Verify row remains REVOKED and token remains null
      const preserved = await rereadPurchase(mockDb, 'terminally_revoked_hash');
      assert.ok(preserved);
      assert.strictEqual(preserved.status, 'REVOKED');
      assert.strictEqual(preserved.encrypted_token, null);
    });

    it('concurrency CAS version mismatch during cancellation fails closed', async () => {
      const mockDb = new MockD1Database() as unknown as D1Database;

      await insertPurchase(mockDb, {
        token_hash: 'conflict_cancel_hash',
        encrypted_token: 'v1:iv:token',
        key_version: 'v1',
        product_id: sku,
        package_name: pkg,
        status: 'ACTIVE',
        acknowledgement_state: 'PENDING',
        next_ack_attempt_at: now,
        purchase_time_ms: now,
        now_ms: now
      });

      // Attempt CAS update with stale state_version (999 instead of 1)
      const commitSuccess = await updatePurchaseCas(mockDb, {
        token_hash: 'conflict_cancel_hash',
        expected_state_version: 999, // Stale version
        status: 'REVOKED',
        revocation_reason: 'GOOGLE_PLAY_CANCELLED',
        acknowledgement_state: 'NOT_APPLICABLE',
        encrypted_token: null,
        ack_attempt_count: 0,
        next_ack_attempt_at: null,
        ack_claim_expires_at: null,
        last_ack_failure_reason: 'PURCHASE_CANCELLED_UPSTREAM',
        last_check_status: 'REVOKED',
        purchase_time_ms: now,
        now_ms: now
      });

      // CAS update fails; caller must fail closed (HTTP 500) and never issue a lease
      assert.strictEqual(commitSuccess, false);
    });
  });
});

