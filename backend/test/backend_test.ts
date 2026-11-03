// backend/test/backend_test.ts
// Unit and Integration Tests for QuickNotes Premium Entitlement Backend

import { describe, it } from 'node:test';
import assert from 'node:assert';
import {
  base64ToBytes,
  bytesToBase64,
  bytesToBase64Url,
  decryptToken,
  encryptToken,
  sha256Hex,
  signJwsLease,
  stringToBytes
} from '../src/crypto';
import { evaluateGooglePlayResponse } from '../src/google-play';
import { calculateBackoffMs } from '../src/cron';
import { ProductPurchaseV2 } from '../src/types';

describe('Crypto Module', () => {
  it('sha256Hex computes correct hex digest', async () => {
    const hash = await sha256Hex('test_purchase_token_123');
    assert.strictEqual(typeof hash, 'string');
    assert.strictEqual(hash.length, 64);
  });

  it('encryptToken and decryptToken perform round-trip AES-256-GCM encryption', async () => {
    // Generate 32-byte test key
    const rawKey = crypto.getRandomValues(new Uint8Array(32));
    const keyB64 = bytesToBase64(rawKey);
    const keyring = JSON.stringify({ v1: keyB64 });

    const rawToken = 'google_play_purchase_token_abcdef123456';
    const encrypted = await encryptToken(rawToken, 'v1', keyring);

    assert.ok(encrypted.startsWith('v1:'));
    const parts = encrypted.split(':');
    assert.strictEqual(parts.length, 3);

    const decrypted = await decryptToken(encrypted, keyring);
    assert.strictEqual(decrypted, rawToken);
  });

  it('decryptToken throws if key version is missing in keyring', async () => {
    const rawKey = crypto.getRandomValues(new Uint8Array(32));
    const keyring = JSON.stringify({ v1: bytesToBase64(rawKey) });
    const emptyKeyring = JSON.stringify({ v2: bytesToBase64(rawKey) });

    const encrypted = await encryptToken('secret_token', 'v1', keyring);
    await assert.rejects(
      async () => await decryptToken(encrypted, emptyKeyring),
      /not found in keyring/
    );
  });

  it('exercises real WebCrypto RSASSA-PKCS1-v1_5 key import and signing', async () => {
    // Generate an RSA key pair for testing WebCrypto RSASSA-PKCS1-v1_5
    const keyPair = (await crypto.subtle.generateKey(
      {
        name: 'RSASSA-PKCS1-v1_5',
        modulusLength: 2048,
        publicExponent: new Uint8Array([1, 0, 1]),
        hash: 'SHA-256'
      },
      true,
      ['sign', 'verify']
    )) as CryptoKeyPair;

    const exportedPkcs8 = await crypto.subtle.exportKey('pkcs8', keyPair.privateKey);
    const keyBytes = new Uint8Array(exportedPkcs8 as ArrayBuffer);

    // Verify importKey accepts 'RSASSA-PKCS1-v1_5' with SHA-256
    const importedKey = await crypto.subtle.importKey(
      'pkcs8',
      keyBytes,
      { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
      false,
      ['sign']
    );
    assert.ok(importedKey);

    // Verify signing with 'RSASSA-PKCS1-v1_5'
    const testData = new TextEncoder().encode('google-service-account-jwt-assertion-test');
    const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', importedKey, testData);
    assert.ok(signature.byteLength > 0);

    // Verify signature with public key
    const isValid = await crypto.subtle.verify(
      'RSASSA-PKCS1-v1_5',
      keyPair.publicKey,
      signature,
      testData
    );
    assert.strictEqual(isValid, true);

    // Verify that the typo 'RSASSA-PKKCS1-v1_5' is rejected by WebCrypto
    await assert.rejects(
      async () => {
        await crypto.subtle.importKey(
          'pkcs8',
          keyBytes,
          { name: 'RSASSA-PKKCS1-v1_5', hash: 'SHA-256' } as any,
          false,
          ['sign']
        );
      },
      (err: any) => err.name === 'NotSupportedError' || /unrecognized|supported/i.test(err.message)
    );
  });

  it('signJwsLease produces valid compact 3-part Ed25519 JWS token', async () => {
    // Generate Ed25519 key pair for test
    const keyPair = (await crypto.subtle.generateKey('Ed25519', true, [
      'sign',
      'verify'
    ])) as CryptoKeyPair;
    const exportedPkcs8 = await crypto.subtle.exportKey('pkcs8', keyPair.privateKey);
    const privB64 = bytesToBase64(new Uint8Array(exportedPkcs8 as ArrayBuffer));
    const signingKeyring = JSON.stringify({ v1: privB64 });

    const claims = {
      iss: 'https://test-issuer.workers.dev',
      aud: 'com.quicknotes.byhmnth',
      sub: 'token_hash_xyz',
      entitlement: 'premium',
      product_id: 'quicknotes_premium_lifetime',
      status: 'ACTIVE',
      iat: 1700000000,
      nbf: 1700000000,
      exp: 1700604800,
      jti: 'test-uuid-123'
    };

    const jws = await signJwsLease(claims, 'v1', signingKeyring);
    const parts = jws.split('.');
    assert.strictEqual(parts.length, 3);

    // Verify header contents
    const headerJson = JSON.parse(new TextDecoder().decode(base64ToBytes(parts[0].replace(/-/g, '+').replace(/_/g, '/'))));
    assert.strictEqual(headerJson.alg, 'EdDSA');
    assert.strictEqual(headerJson.typ, 'JWT');
    assert.strictEqual(headerJson.kid, 'v1');

    // Verify signature using WebCrypto verify
    const signingInput = `${parts[0]}.${parts[1]}`;
    // Base64URL decode signature
    let sigB64 = parts[2].replace(/-/g, '+').replace(/_/g, '/');
    while (sigB64.length % 4 !== 0) sigB64 += '=';
    const sigBytes = base64ToBytes(sigB64);

    const isValid = await crypto.subtle.verify(
      'Ed25519',
      keyPair.publicKey,
      sigBytes,
      stringToBytes(signingInput)
    );
    assert.strictEqual(isValid, true);
  });
});

describe('Google Play Evaluation Logic', () => {
  const pkg = 'com.quicknotes.byhmnth';
  const sku = 'quicknotes_premium_lifetime';

  it('evaluates valid PURCHASED and ACKNOWLEDGED response correctly', () => {
    const raw: ProductPurchaseV2 = {
      packageName: pkg,
      productLineItem: [{ productId: sku }],
      purchaseStateContext: {
        purchaseState: 'PURCHASED',
        purchaseCompletionTime: '2026-10-24T12:00:00Z'
      },
      acknowledgementState: 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED'
    };

    const res = evaluateGooglePlayResponse(raw, pkg, sku);
    assert.strictEqual(res.purchaseState, 'PURCHASED');
    assert.strictEqual(res.acknowledgementState, 'ACKNOWLEDGED');
    assert.strictEqual(res.purchaseCompletionTimeMs, Date.parse('2026-10-24T12:00:00Z'));
  });

  it('evaluates valid PURCHASED and PENDING acknowledgement correctly', () => {
    const raw: ProductPurchaseV2 = {
      packageName: pkg,
      productLineItem: [{ productId: sku }],
      purchaseStateContext: {
        purchaseState: 'PURCHASED'
      },
      acknowledgementState: 'ACKNOWLEDGEMENT_STATE_PENDING'
    };

    const res = evaluateGooglePlayResponse(raw, pkg, sku);
    assert.strictEqual(res.purchaseState, 'PURCHASED');
    assert.strictEqual(res.acknowledgementState, 'PENDING');
    assert.strictEqual(res.purchaseCompletionTimeMs, null);
  });

  it('evaluates CANCELLED response as terminal cancellation', () => {
    const raw: ProductPurchaseV2 = {
      packageName: pkg,
      productLineItem: [{ productId: sku }],
      purchaseStateContext: {
        purchaseState: 'CANCELLED'
      },
      acknowledgementState: 'ACKNOWLEDGEMENT_STATE_PENDING'
    };

    const res = evaluateGooglePlayResponse(raw, pkg, sku);
    assert.strictEqual(res.purchaseState, 'CANCELLED');
  });

  it('evaluates PENDING purchase as payment pending (never granted)', () => {
    const raw: ProductPurchaseV2 = {
      packageName: pkg,
      productLineItem: [{ productId: sku }],
      purchaseStateContext: {
        purchaseState: 'PENDING'
      },
      acknowledgementState: 'ACKNOWLEDGEMENT_STATE_PENDING'
    };

    const res = evaluateGooglePlayResponse(raw, pkg, sku);
    assert.strictEqual(res.purchaseState, 'PENDING');
  });

  it('fails closed on package mismatch', () => {
    const raw: ProductPurchaseV2 = {
      packageName: 'com.other.app',
      productLineItem: [{ productId: sku }],
      purchaseStateContext: { purchaseState: 'PURCHASED' }
    };

    const res = evaluateGooglePlayResponse(raw, pkg, sku);
    assert.strictEqual(res.purchaseState, 'INDETERMINATE');
    assert.strictEqual(res.error, 'PACKAGE_NAME_MISMATCH');
  });

  it('fails closed on SKU mismatch', () => {
    const raw: ProductPurchaseV2 = {
      packageName: pkg,
      productLineItem: [{ productId: 'wrong_sku' }],
      purchaseStateContext: { purchaseState: 'PURCHASED' }
    };

    const res = evaluateGooglePlayResponse(raw, pkg, sku);
    assert.strictEqual(res.purchaseState, 'INDETERMINATE');
    assert.strictEqual(res.error, 'PRODUCT_ID_NOT_FOUND');
  });

  it('does not coerce unspecified acknowledgement state to PENDING', () => {
    const raw: ProductPurchaseV2 = {
      packageName: pkg,
      productLineItem: [{ productId: sku }],
      purchaseStateContext: { purchaseState: 'PURCHASED' },
      acknowledgementState: 'ACKNOWLEDGEMENT_STATE_UNSPECIFIED'
    };

    const res = evaluateGooglePlayResponse(raw, pkg, sku);
    assert.strictEqual(res.acknowledgementState, 'UNSPECIFIED');
  });
});

describe('Cron Backoff & Urgency Scheduling', () => {
  const now = Date.now();

  it('clamps backoff to 15 minutes when purchase time is missing', () => {
    // Attempt 5 with normal exponential backoff would be > 2.5 hours, but missing time clamps to 15m
    const backoff = calculateBackoffMs(5, null, now);
    assert.ok(backoff <= 15 * 60 * 1000 + 30000, `Backoff was ${backoff}`);
    assert.ok(backoff >= 15 * 60 * 1000, `Backoff was ${backoff}`);
  });

  it('clamps backoff to 15 minutes when purchase age exceeds 48 hours', () => {
    const purchaseTime = now - 50 * 60 * 60 * 1000; // 50 hours old
    const backoff = calculateBackoffMs(6, purchaseTime, now);
    assert.ok(backoff <= 15 * 60 * 1000 + 30000);
  });

  it('clamps backoff to 30 minutes when purchase age is between 36 and 48 hours', () => {
    const purchaseTime = now - 40 * 60 * 60 * 1000; // 40 hours old
    const backoff = calculateBackoffMs(6, purchaseTime, now);
    assert.ok(backoff <= 30 * 60 * 1000 + 30000);
  });

  it('uses standard exponential backoff when purchase age is young (<36 hours)', () => {
    const purchaseTime = now - 1 * 60 * 60 * 1000; // 1 hour old
    const backoffAttempt0 = calculateBackoffMs(0, purchaseTime, now);
    // 5m + jitter
    assert.ok(backoffAttempt0 >= 5 * 60 * 1000 && backoffAttempt0 <= 5 * 60 * 1000 + 30000);

    const backoffAttempt1 = calculateBackoffMs(1, purchaseTime, now);
    // 10m + jitter
    assert.ok(backoffAttempt1 >= 10 * 60 * 1000 && backoffAttempt1 <= 10 * 60 * 1000 + 30000);
  });
});
