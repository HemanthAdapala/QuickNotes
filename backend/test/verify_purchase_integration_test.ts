// backend/test/verify_purchase_integration_test.ts
// Worker HTTP Integration Tests exercising the production request pipeline in backend/src/index.ts

import { describe, it, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert';
import worker from '../src/index';
import { Env, ProductPurchaseV2, PurchaseRow, PurchaseStatus } from '../src/types';
import {
  base64UrlToBytes,
  bytesToBase64,
  bytesToBase64Url,
  bytesToString,
  sha256Hex,
  stringToBytes
} from '../src/crypto';

// In-Memory D1 Mock supporting controlled failure injection for integration testing
class ControllableMockD1Database {
  rows: Map<string, PurchaseRow> = new Map();
  simulateInsertFailure: boolean = false;
  simulateCasFailure: boolean = false;

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
        return { results: [] };
      },
      async run(): Promise<{ meta: { changes: number } }> {
        // Handle INSERT
        if (this._query.startsWith('INSERT INTO purchases')) {
          if (db.simulateInsertFailure) {
            throw new Error('Simulated D1 disk I/O write error during insert');
          }

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

        // Handle CAS UPDATE
        if (this._query.startsWith('UPDATE purchases')) {
          if (db.simulateCasFailure) {
            return { meta: { changes: 0 } };
          }

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
          row.purchase_time_ms = purchase_time_ms ?? row.purchase_time_ms;
          row.state_version++;
          row.updated_at_ms = now_ms;

          return { meta: { changes: 1 } };
        }

        return { meta: { changes: 0 } };
      }
    };
  }
}

describe('Worker HTTP Integration Tests (Production Pipeline)', () => {
  let originalFetch: typeof globalThis.fetch;
  let mockDb: ControllableMockD1Database;
  let testEnv: Env;
  let testSigningKeyB64: string;
  let testPublicKey: CryptoKey;
  let testRsaPem: string;

  async function verifyJwsCompact(
    token: string,
    publicKey: CryptoKey
  ): Promise<{ isValid: boolean; header: any; payload: any }> {
    const parts = token.split('.');
    if (parts.length !== 3) {
      return { isValid: false, header: null, payload: null };
    }
    try {
      const [headerB64, payloadB64, sigB64] = parts;
      const header = JSON.parse(bytesToString(base64UrlToBytes(headerB64)));
      const payload = JSON.parse(bytesToString(base64UrlToBytes(payloadB64)));
      const signingInput = `${headerB64}.${payloadB64}`;
      const sigBytes = base64UrlToBytes(sigB64);
      const isValid = await crypto.subtle.verify(
        'Ed25519',
        publicKey,
        sigBytes,
        stringToBytes(signingInput)
      );
      return { isValid, header, payload };
    } catch (_) {
      return { isValid: false, header: null, payload: null };
    }
  }

  beforeEach(async () => {
    originalFetch = globalThis.fetch;
    mockDb = new ControllableMockD1Database();

    // Generate in-memory Ed25519 signing key for test
    const edKey = (await crypto.subtle.generateKey('Ed25519', true, ['sign', 'verify'])) as CryptoKeyPair;
    testPublicKey = edKey.publicKey;
    const pkcs8 = await crypto.subtle.exportKey('pkcs8', edKey.privateKey);
    testSigningKeyB64 = bytesToBase64(new Uint8Array(pkcs8 as ArrayBuffer));

    // Generate in-memory RSA key for test service account
    const rsaKey = (await crypto.subtle.generateKey(
      {
        name: 'RSASSA-PKCS1-v1_5',
        modulusLength: 2048,
        publicExponent: new Uint8Array([1, 0, 1]),
        hash: 'SHA-256'
      },
      true,
      ['sign']
    )) as CryptoKeyPair;
    const rsaPkcs8 = await crypto.subtle.exportKey('pkcs8', rsaKey.privateKey);
    const rsaB64 = bytesToBase64(new Uint8Array(rsaPkcs8 as ArrayBuffer));
    testRsaPem = `-----BEGIN PRIVATE KEY-----\n${rsaB64}\n-----END PRIVATE KEY-----`;

    testEnv = {
      DB: mockDb as any,
      PACKAGE_NAME: 'com.quicknotes.byhmnth',
      PRODUCT_ID: 'quicknotes_premium_lifetime',
      ISSUER_URL: 'https://entitlements.quicknotes.app',
      PRIMARY_SIGNING_KEY_ID: 'v1',
      SERVER_ALLOWED_SIGNING_KEYS: 'v1',
      TOKEN_ENCRYPTION_KEYRING: JSON.stringify({ v1: bytesToBase64(new Uint8Array(32)) }),
      SIGNING_KEYRING: JSON.stringify({ v1: testSigningKeyB64 }),
      GOOGLE_SERVICE_ACCOUNT_JSON: JSON.stringify({
        client_email: 'test-sa@quicknotes-project.iam.gserviceaccount.com',
        private_key: testRsaPem
      })
    };
  });

  afterEach(() => {
    globalThis.fetch = originalFetch;
  });

  it('Test A: D1 persistence failure fails closed with HTTP 500 and no lease', async () => {
    // Upstream Google Play reports PURCHASED and ACKNOWLEDGED
    globalThis.fetch = async (input: RequestInfo | URL, init?: RequestInit): Promise<Response> => {
      const urlStr = String(input);
      if (urlStr.includes('oauth2.googleapis.com/token')) {
        return new Response(JSON.stringify({ access_token: 'mock_sa_token', expires_in: 3600 }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' }
        });
      }
      if (urlStr.includes('/purchases/productsv2/tokens/')) {
        const payload: ProductPurchaseV2 = {
          packageName: 'com.quicknotes.byhmnth',
          productLineItem: [{ productId: 'quicknotes_premium_lifetime' }],
          purchaseStateContext: {
            purchaseState: 'PURCHASED',
            purchaseCompletionTime: '2026-10-24T12:00:00Z'
          },
          acknowledgementState: 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED'
        };
        return new Response(JSON.stringify(payload), {
          status: 200,
          headers: { 'Content-Type': 'application/json' }
        });
      }
      return new Response('Not Found', { status: 404 });
    };

    const purchaseToken = 'valid_purchase_token_persistence_fail';
    const tokenHash = await sha256Hex(purchaseToken);

    // Pre-seed an existing row in DB so the handler takes the updatePurchaseCas path
    mockDb.rows.set(tokenHash, {
      token_hash: tokenHash,
      encrypted_token: null,
      key_version: 'v1',
      product_id: 'quicknotes_premium_lifetime',
      package_name: 'com.quicknotes.byhmnth',
      status: 'ACTIVE',
      revocation_reason: null,
      acknowledgement_state: 'ACKNOWLEDGED',
      ack_attempt_count: 0,
      next_ack_attempt_at: null,
      ack_claim_expires_at: null,
      last_ack_failure_reason: null,
      last_check_status: 'SUCCESS',
      purchase_time_ms: 1700000000000,
      state_version: 1,
      created_at_ms: 1700000000000,
      updated_at_ms: 1700000000000
    });

    // Induce CAS failure on update
    mockDb.simulateCasFailure = true;

    const req = new Request('https://worker.local/verify-purchase', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        purchase_token: purchaseToken,
        package_name: 'com.quicknotes.byhmnth',
        product_id: 'quicknotes_premium_lifetime',
        client_version: 1,
        supported_key_versions: ['v1']
      })
    });

    // Execute through production worker.fetch pipeline
    const resp = await worker.fetch(req, testEnv, {} as any);

    assert.strictEqual(resp.status, 500);
    const body = (await resp.json()) as any;
    assert.strictEqual(body.error, 'Failed to commit purchase entitlement state');
    assert.strictEqual(body.lease_token, undefined, 'No lease token must be returned on DB failure');
  });

  it('Test B: Google Play timeout or network transport failure fails closed with HTTP 502', async () => {
    // Simulate upstream transport failure / timeout when contacting Google Play API
    globalThis.fetch = async (input: RequestInfo | URL): Promise<Response> => {
      const urlStr = String(input);
      if (urlStr.includes('oauth2.googleapis.com/token')) {
        return new Response(JSON.stringify({ access_token: 'mock_sa_token', expires_in: 3600 }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' }
        });
      }
      if (urlStr.includes('/purchases/productsv2/tokens/')) {
        // Transport error / timeout simulation (AbortError)
        throw new Error('Network timeout: Upstream Google Play API unreachable (AbortError)');
      }
      return new Response('Not Found', { status: 404 });
    };

    const req = new Request('https://worker.local/verify-purchase', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        purchase_token: 'valid_purchase_token_network_fail',
        package_name: 'com.quicknotes.byhmnth',
        product_id: 'quicknotes_premium_lifetime',
        client_version: 1,
        supported_key_versions: ['v1']
      })
    });

    const resp = await worker.fetch(req, testEnv, {} as any);

    assert.strictEqual(resp.status, 502);
    const body = (await resp.json()) as any;
    assert.strictEqual(body.error, 'UPSTREAM_LOOKUP_FAILED');
    assert.strictEqual(body.status, 502);
    assert.strictEqual(body.lease_token, undefined, 'No lease token must be returned on upstream failure');
  });

  it('Test C1: Cancellation detected during pre-issuance recheck records revocation and returns HTTP 403', async () => {
    let callCount = 0;
    globalThis.fetch = async (input: RequestInfo | URL): Promise<Response> => {
      const urlStr = String(input);
      if (urlStr.includes('oauth2.googleapis.com/token')) {
        return new Response(JSON.stringify({ access_token: 'mock_sa_token', expires_in: 3600 }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' }
        });
      }
      if (urlStr.includes('/purchases/productsv2/tokens/')) {
        callCount++;
        if (callCount === 1) {
          // Initial lookup: Eligible purchase
          const activePayload: ProductPurchaseV2 = {
            packageName: 'com.quicknotes.byhmnth',
            productLineItem: [{ productId: 'quicknotes_premium_lifetime' }],
            purchaseStateContext: {
              purchaseState: 'PURCHASED',
              purchaseCompletionTime: '2026-10-24T12:00:00Z'
            },
            acknowledgementState: 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED'
          };
          return new Response(JSON.stringify(activePayload), {
            status: 200,
            headers: { 'Content-Type': 'application/json' }
          });
        } else {
          // Pre-issuance recheck: Purchase was cancelled between check 1 and check 2
          const cancelledPayload: ProductPurchaseV2 = {
            packageName: 'com.quicknotes.byhmnth',
            productLineItem: [{ productId: 'quicknotes_premium_lifetime' }],
            purchaseStateContext: {
              purchaseState: 'CANCELLED',
              purchaseCompletionTime: '2026-10-24T12:00:00Z'
            },
            acknowledgementState: 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED'
          };
          return new Response(JSON.stringify(cancelledPayload), {
            status: 200,
            headers: { 'Content-Type': 'application/json' }
          });
        }
      }
      return new Response('Not Found', { status: 404 });
    };

    const req = new Request('https://worker.local/verify-purchase', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        purchase_token: 'rapid_cancelled_purchase_token',
        package_name: 'com.quicknotes.byhmnth',
        product_id: 'quicknotes_premium_lifetime',
        client_version: 1,
        supported_key_versions: ['v1']
      })
    });

    const resp = await worker.fetch(req, testEnv, {} as any);

    // Must return HTTP 403 with exact revocation payload
    assert.strictEqual(resp.status, 403);
    const body = (await resp.json()) as any;
    assert.strictEqual(body.status, 'REVOKED');
    assert.strictEqual(body.reason, 'GOOGLE_PLAY_CANCELLED');
    assert.strictEqual(body.lease_token, undefined, 'No lease must be returned');

    // Confirm that D1 row is durable and terminally REVOKED with token purged
    const rows = Array.from(mockDb.rows.values());
    assert.strictEqual(rows.length, 1);
    const row = rows[0];
    assert.strictEqual(row.status, 'REVOKED');
    assert.strictEqual(row.revocation_reason, 'GOOGLE_PLAY_CANCELLED');
    assert.strictEqual(row.encrypted_token, null, 'Encrypted token must be purged on revocation');
  });

  it('Test C2: Failed cancellation persistence during pre-check returns HTTP 500 and prevents lease issuance', async () => {
    let callCount = 0;
    globalThis.fetch = async (input: RequestInfo | URL): Promise<Response> => {
      const urlStr = String(input);
      if (urlStr.includes('oauth2.googleapis.com/token')) {
        return new Response(JSON.stringify({ access_token: 'mock_sa_token', expires_in: 3600 }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' }
        });
      }
      if (urlStr.includes('/purchases/productsv2/tokens/')) {
        callCount++;
        if (callCount === 1) {
          const activePayload: ProductPurchaseV2 = {
            packageName: 'com.quicknotes.byhmnth',
            productLineItem: [{ productId: 'quicknotes_premium_lifetime' }],
            purchaseStateContext: {
              purchaseState: 'PURCHASED',
              purchaseCompletionTime: '2026-10-24T12:00:00Z'
            },
            acknowledgementState: 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED'
          };
          return new Response(JSON.stringify(activePayload), {
            status: 200,
            headers: { 'Content-Type': 'application/json' }
          });
        } else {
          // Pre-check recheck detects cancellation
          const cancelledPayload: ProductPurchaseV2 = {
            packageName: 'com.quicknotes.byhmnth',
            productLineItem: [{ productId: 'quicknotes_premium_lifetime' }],
            purchaseStateContext: {
              purchaseState: 'CANCELLED',
              purchaseCompletionTime: '2026-10-24T12:00:00Z'
            },
            acknowledgementState: 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED'
          };
          return new Response(JSON.stringify(cancelledPayload), {
            status: 200,
            headers: { 'Content-Type': 'application/json' }
          });
        }
      }
      return new Response('Not Found', { status: 404 });
    };

    const purchaseToken = 'precheck_token_persistence_fail';

    // Intercept mockDb to make any update setting status to 'REVOKED' fail (e.g. CAS conflict or disk failure)
    const originalPrepare = mockDb.prepare.bind(mockDb);
    mockDb.prepare = (query: string) => {
      const stmt = originalPrepare(query);
      if (query.startsWith('UPDATE purchases')) {
        const origRun = stmt.run.bind(stmt);
        stmt.run = async () => {
          // Binding 0 is status. If status is 'REVOKED', simulate write failure (0 changes)
          if (stmt._bindings[0] === 'REVOKED') {
            return { meta: { changes: 0 } };
          }
          return origRun();
        };
      }
      return stmt;
    };

    const req = new Request('https://worker.local/verify-purchase', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        purchase_token: purchaseToken,
        package_name: 'com.quicknotes.byhmnth',
        product_id: 'quicknotes_premium_lifetime',
        client_version: 1,
        supported_key_versions: ['v1']
      })
    });

    const resp = await worker.fetch(req, testEnv, {} as any);

    // Must return HTTP 500 when cancellation persistence fails, and MUST NOT return a lease
    assert.strictEqual(resp.status, 500);
    const body = (await resp.json()) as any;
    assert.strictEqual(body.error, 'Failed to persist cancellation state');
    assert.strictEqual(body.lease_token, undefined, 'No lease must ever be issued');
  });

  it('Test D: Happy path verification issues valid 7-day Ed25519 JWS lease token', async () => {
    globalThis.fetch = async (input: RequestInfo | URL): Promise<Response> => {
      const urlStr = String(input);
      if (urlStr.includes('oauth2.googleapis.com/token')) {
        return new Response(JSON.stringify({ access_token: 'mock_sa_token', expires_in: 3600 }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' }
        });
      }
      if (urlStr.includes('/purchases/productsv2/tokens/')) {
        const payload: ProductPurchaseV2 = {
          packageName: 'com.quicknotes.byhmnth',
          productLineItem: [{ productId: 'quicknotes_premium_lifetime' }],
          purchaseStateContext: {
            purchaseState: 'PURCHASED',
            purchaseCompletionTime: '2026-10-24T12:00:00Z'
          },
          acknowledgementState: 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED'
        };
        return new Response(JSON.stringify(payload), {
          status: 200,
          headers: { 'Content-Type': 'application/json' }
        });
      }
      return new Response('Not Found', { status: 404 });
    };

    const purchaseToken = 'happy_path_token';
    const expectedSub = await sha256Hex(purchaseToken);

    const req = new Request('https://worker.local/verify-purchase', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        purchase_token: purchaseToken,
        package_name: 'com.quicknotes.byhmnth',
        product_id: 'quicknotes_premium_lifetime',
        client_version: 1,
        supported_key_versions: ['v1']
      })
    });

    const resp = await worker.fetch(req, testEnv, {} as any);

    // 1. Assert HTTP 200 and expected active-entitlement response
    assert.strictEqual(resp.status, 200);
    const body = (await resp.json()) as any;
    assert.strictEqual(body.status, 'ACTIVE');
    assert.ok(body.lease_token, 'Lease token must be present on successful purchase verification');
    assert.ok(body.expires_at, 'Expiration timestamp must be present');
    assert.strictEqual(typeof body.lease_token, 'string');

    // 2. Parse compact JWS into its three components
    const parts = body.lease_token.split('.');
    assert.strictEqual(parts.length, 3, 'Lease token must be a valid 3-part compact JWS');
    const [headerPart, payloadPart, sigPart] = parts;

    // 3 & 4 & 5. Decode header/payload and cryptographically verify signature with test public key
    const verification = await verifyJwsCompact(body.lease_token, testPublicKey);
    assert.strictEqual(verification.isValid, true, 'Cryptographic Ed25519 signature verification must succeed');

    const header = verification.header;
    const payload = verification.payload;

    // 4. Assert expected algorithm, typ, and key ID
    assert.strictEqual(header.alg, 'EdDSA', 'Header algorithm must be EdDSA');
    assert.strictEqual(header.typ, 'JWT', 'Header typ must be JWT');
    assert.strictEqual(header.kid, 'v1', 'Header kid must match primary signing key ID v1');

    // 6. Assert required claims match configured test expectations
    assert.strictEqual(payload.iss, testEnv.ISSUER_URL, 'iss claim must match configured issuer URL');
    assert.strictEqual(payload.aud, testEnv.PACKAGE_NAME, 'aud claim must match expected package name');
    assert.strictEqual(payload.sub, expectedSub, 'sub claim must match SHA-256 hash of purchase token');
    assert.strictEqual(payload.entitlement, 'premium', 'entitlement claim must be premium');
    assert.strictEqual(payload.product_id, testEnv.PRODUCT_ID, 'product_id claim must match expected product ID');
    assert.strictEqual(payload.status, 'ACTIVE', 'status claim must be ACTIVE');
    assert.strictEqual(typeof payload.iat, 'number', 'iat claim must be numeric Unix epoch timestamp');
    assert.strictEqual(typeof payload.nbf, 'number', 'nbf claim must be numeric Unix epoch timestamp');
    assert.strictEqual(payload.nbf, payload.iat, 'nbf must equal iat');
    assert.strictEqual(typeof payload.exp, 'number', 'exp claim must be numeric Unix epoch timestamp');
    assert.strictEqual(body.expires_at, payload.exp, 'Response body expires_at must match payload exp claim');
    assert.ok(payload.jti && typeof payload.jti === 'string' && payload.jti.length > 0, 'jti claim must be non-empty string UUID');

    // 7. Assert expiry interval is exactly the approved lease duration of 604,800 seconds (7 days)
    const leaseDurationSeconds = payload.exp - payload.iat;
    assert.strictEqual(leaseDurationSeconds, 604800, 'Lease duration must be exactly 604,800 seconds (7 days)');

    // 8. Assert malformed payloads, modified payload, or invalid signature fail verification
    // 8a. Tampered payload
    const tamperedPayloadObj = { ...payload, status: 'REVOKED' };
    const tamperedPayloadB64 = bytesToBase64Url(stringToBytes(JSON.stringify(tamperedPayloadObj)));
    const tamperedToken = `${headerPart}.${tamperedPayloadB64}.${sigPart}`;
    const tamperedRes = await verifyJwsCompact(tamperedToken, testPublicKey);
    assert.strictEqual(tamperedRes.isValid, false, 'Tampered payload must fail cryptographic signature verification');

    // 8b. Invalid signature
    const corruptSigPart = sigPart.slice(0, -2) + (sigPart.endsWith('AA') ? 'BB' : 'AA');
    const corruptSigToken = `${headerPart}.${payloadPart}.${corruptSigPart}`;
    const corruptSigRes = await verifyJwsCompact(corruptSigToken, testPublicKey);
    assert.strictEqual(corruptSigRes.isValid, false, 'Corrupted signature must fail verification');

    // 8c. Malformed token structure
    assert.strictEqual((await verifyJwsCompact('invalid.jwt.token.extra', testPublicKey)).isValid, false);
    assert.strictEqual((await verifyJwsCompact('only-one-part', testPublicKey)).isValid, false);
    assert.strictEqual((await verifyJwsCompact('', testPublicKey)).isValid, false);
  });
});
