import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/premium/crypto/ed25519.dart';
import 'package:quick_notes/premium/jws_lease_verifier.dart';
import 'package:quick_notes/premium/premium_config.dart';

void main() {
  group('JwsLeaseVerifier Strict Security Tests', () {
    const verifier = JwsLeaseVerifier();
    final testSeed = Uint8List.fromList(List.generate(32, (i) => i * 3 + 1));
    final testPublicKey = Ed25519.publicKeyFromSeed(testSeed);
    final testPublicKeyBase64 = base64Encode(testPublicKey);

    final trustedKeys = {
      'test-kid-1': testPublicKeyBase64,
    };

    String base64UrlEncode(List<int> bytes) {
      return base64Url.encode(bytes).replaceAll('=', '');
    }

    String createSignedJws({
      required Map<String, dynamic> header,
      required Map<String, dynamic> payload,
      Uint8List? signingSeed,
    }) {
      final headerB64 = base64UrlEncode(utf8.encode(jsonEncode(header)));
      final payloadB64 = base64UrlEncode(utf8.encode(jsonEncode(payload)));
      final signingInput = ascii.encode('$headerB64.$payloadB64');

      final sig = Ed25519.sign(
        seed: signingSeed ?? testSeed,
        message: Uint8List.fromList(signingInput),
      );
      final sigB64 = base64UrlEncode(sig);

      return '$headerB64.$payloadB64.$sigB64';
    }

    test('1. Verifies valid compact JWS lease and constructs JwsLease model', () {
      final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final header = {
        'alg': 'EdDSA',
        'typ': 'JWT',
        'kid': 'test-kid-1',
      };
      final payload = {
        'iss': 'https://auth.quicknotes.app',
        'aud': 'com.quicknotes.byhmnth',
        'sub': 'sha256_mock_token_hash_123',
        'entitlement': 'premium',
        'product_id': 'quicknotes_premium_lifetime',
        'status': 'ACTIVE',
        'iat': nowSec,
        'nbf': nowSec,
        'exp': nowSec + 604800,
        'jti': 'uuid-lease-1234',
      };

      final jws = createSignedJws(header: header, payload: payload);

      final lease = verifier.verify(
        jwsToken: jws,
        expectedSubject: 'sha256_mock_token_hash_123',
        expectedIssuer: 'https://auth.quicknotes.app',
        customPublicKeys: trustedKeys,
      );

      expect(lease, isNotNull);
      expect(lease!.kid, equals('test-kid-1'));
      expect(lease.issuer, equals('https://auth.quicknotes.app'));
      expect(lease.audience, equals('com.quicknotes.byhmnth'));
      expect(lease.subject, equals('sha256_mock_token_hash_123'));
      expect(lease.entitlement, equals('premium'));
      expect(lease.productId, equals('quicknotes_premium_lifetime'));
      expect(lease.status, equals('ACTIVE'));
      expect(lease.jti, equals('uuid-lease-1234'));
      expect(lease.isExpired(), isFalse);
    });

    test('2. Rejects forged or tampered JWS signature', () {
      final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final header = {'alg': 'EdDSA', 'typ': 'JWT', 'kid': 'test-kid-1'};
      final payload = {
        'iss': 'https://auth.quicknotes.app',
        'aud': 'com.quicknotes.byhmnth',
        'sub': 'sha256_mock_token_hash_123',
        'entitlement': 'premium',
        'product_id': 'quicknotes_premium_lifetime',
        'status': 'ACTIVE',
        'iat': nowSec,
        'nbf': nowSec,
        'exp': nowSec + 604800,
      };

      final differentSeed = Uint8List.fromList(List.generate(32, (i) => i * 5 + 9));
      final forgedJws = createSignedJws(
        header: header,
        payload: payload,
        signingSeed: differentSeed,
      );

      final lease = verifier.verify(
        jwsToken: forgedJws,
        customPublicKeys: trustedKeys,
      );
      expect(lease, isNull);
    });

    test('3. Rejects expired lease token (exp <= now)', () {
      final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final header = {'alg': 'EdDSA', 'typ': 'JWT', 'kid': 'test-kid-1'};
      final payload = {
        'iss': 'https://auth.quicknotes.app',
        'aud': 'com.quicknotes.byhmnth',
        'sub': 'sha256_mock_token_hash_123',
        'entitlement': 'premium',
        'product_id': 'quicknotes_premium_lifetime',
        'status': 'ACTIVE',
        'iat': nowSec - 700000,
        'nbf': nowSec - 700000,
        'exp': nowSec - 100, // Expired
      };

      final jws = createSignedJws(header: header, payload: payload);
      final lease = verifier.verify(
        jwsToken: jws,
        customPublicKeys: trustedKeys,
      );
      expect(lease, isNull);
    });

    test('4. Rejects not-yet-valid lease token (nbf > now + skew)', () {
      final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final header = {'alg': 'EdDSA', 'typ': 'JWT', 'kid': 'test-kid-1'};
      final payload = {
        'iss': 'https://auth.quicknotes.app',
        'aud': 'com.quicknotes.byhmnth',
        'sub': 'sha256_mock_token_hash_123',
        'entitlement': 'premium',
        'product_id': 'quicknotes_premium_lifetime',
        'status': 'ACTIVE',
        'iat': nowSec + 3600, // 1 hour in future
        'nbf': nowSec + 3600,
        'exp': nowSec + 604800,
      };

      final jws = createSignedJws(header: header, payload: payload);
      final lease = verifier.verify(
        jwsToken: jws,
        customPublicKeys: trustedKeys,
      );
      expect(lease, isNull);
    });

    test('5. Rejects subject hash mismatch', () {
      final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final header = {'alg': 'EdDSA', 'typ': 'JWT', 'kid': 'test-kid-1'};
      final payload = {
        'iss': 'https://auth.quicknotes.app',
        'aud': 'com.quicknotes.byhmnth',
        'sub': 'sha256_expected_hash',
        'entitlement': 'premium',
        'product_id': 'quicknotes_premium_lifetime',
        'status': 'ACTIVE',
        'iat': nowSec,
        'nbf': nowSec,
        'exp': nowSec + 604800,
      };

      final jws = createSignedJws(header: header, payload: payload);
      final lease = verifier.verify(
        jwsToken: jws,
        expectedSubject: 'sha256_different_hash',
        customPublicKeys: trustedKeys,
      );
      expect(lease, isNull);
    });

    test('6. Rejects unknown or untrusted key ID', () {
      final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final header = {'alg': 'EdDSA', 'typ': 'JWT', 'kid': 'unknown-key-999'};
      final payload = {
        'iss': 'https://auth.quicknotes.app',
        'aud': 'com.quicknotes.byhmnth',
        'sub': 'sha256_token_hash',
        'entitlement': 'premium',
        'product_id': 'quicknotes_premium_lifetime',
        'status': 'ACTIVE',
        'iat': nowSec,
        'nbf': nowSec,
        'exp': nowSec + 604800,
      };

      final jws = createSignedJws(header: header, payload: payload);
      final lease = verifier.verify(
        jwsToken: jws,
        customPublicKeys: trustedKeys,
      );
      expect(lease, isNull);
    });

    test('7. Supports planned key rotation with dual pinned keys', () {
      final v2Seed = Uint8List.fromList(List.generate(32, (i) => i * 11 + 2));
      final v2PubKey = Ed25519.publicKeyFromSeed(v2Seed);

      final rotationKeys = {
        'v1': testPublicKeyBase64,
        'v2': base64Encode(v2PubKey),
      };

      final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final v2Header = {'alg': 'EdDSA', 'typ': 'JWT', 'kid': 'v2'};
      final payload = {
        'iss': 'https://auth.quicknotes.app',
        'aud': 'com.quicknotes.byhmnth',
        'sub': 'sha256_hash',
        'entitlement': 'premium',
        'product_id': 'quicknotes_premium_lifetime',
        'status': 'ACTIVE',
        'iat': nowSec,
        'nbf': nowSec,
        'exp': nowSec + 604800,
      };

      final v2Jws = createSignedJws(
        header: v2Header,
        payload: payload,
        signingSeed: v2Seed,
      );

      final lease = verifier.verify(
        jwsToken: v2Jws,
        customPublicKeys: rotationKeys,
      );
      expect(lease, isNotNull);
      expect(lease!.kid, equals('v2'));
    });

    test('8. Rejects overlong lease exceeding 7 days by 1 second (exp - iat = 604801)', () {
      final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final header = {'alg': 'EdDSA', 'typ': 'JWT', 'kid': 'test-kid-1'};
      final payload = {
        'iss': 'https://auth.quicknotes.app',
        'aud': 'com.quicknotes.byhmnth',
        'sub': 'sha256_hash',
        'entitlement': 'premium',
        'product_id': 'quicknotes_premium_lifetime',
        'status': 'ACTIVE',
        'iat': nowSec,
        'nbf': nowSec,
        'exp': nowSec + 604801, // 7 days + 1 second
      };

      final jws = createSignedJws(header: header, payload: payload);
      final lease = verifier.verify(jwsToken: jws, customPublicKeys: trustedKeys);
      expect(lease, isNull);
    });

    test('9. Rejects severely overlong lease (10 years duration)', () {
      final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final header = {'alg': 'EdDSA', 'typ': 'JWT', 'kid': 'test-kid-1'};
      final payload = {
        'iss': 'https://auth.quicknotes.app',
        'aud': 'com.quicknotes.byhmnth',
        'sub': 'sha256_hash',
        'entitlement': 'premium',
        'product_id': 'quicknotes_premium_lifetime',
        'status': 'ACTIVE',
        'iat': nowSec,
        'nbf': nowSec,
        'exp': nowSec + (10 * 365 * 86400),
      };

      final jws = createSignedJws(header: header, payload: payload);
      final lease = verifier.verify(jwsToken: jws, customPublicKeys: trustedKeys);
      expect(lease, isNull);
    });

    test('10. Rejects invalid temporal interval (exp <= iat)', () {
      final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final header = {'alg': 'EdDSA', 'typ': 'JWT', 'kid': 'test-kid-1'};
      final payload = {
        'iss': 'https://auth.quicknotes.app',
        'aud': 'com.quicknotes.byhmnth',
        'sub': 'sha256_hash',
        'entitlement': 'premium',
        'product_id': 'quicknotes_premium_lifetime',
        'status': 'ACTIVE',
        'iat': nowSec,
        'nbf': nowSec,
        'exp': nowSec, // exp == iat
      };

      final jws = createSignedJws(header: header, payload: payload);
      final lease = verifier.verify(jwsToken: jws, customPublicKeys: trustedKeys);
      expect(lease, isNull);
    });

    test('11. Rejects invalid temporal interval (nbf > exp)', () {
      final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final header = {'alg': 'EdDSA', 'typ': 'JWT', 'kid': 'test-kid-1'};
      final payload = {
        'iss': 'https://auth.quicknotes.app',
        'aud': 'com.quicknotes.byhmnth',
        'sub': 'sha256_hash',
        'entitlement': 'premium',
        'product_id': 'quicknotes_premium_lifetime',
        'status': 'ACTIVE',
        'iat': nowSec,
        'nbf': nowSec + 700000,
        'exp': nowSec + 604800,
      };

      final jws = createSignedJws(header: header, payload: payload);
      final lease = verifier.verify(jwsToken: jws, customPublicKeys: trustedKeys);
      expect(lease, isNull);
    });

    test('12. Respects clock skew boundary (iat at now + 60s is accepted; at now + 61s is rejected)', () {
      final now = DateTime.utc(2026, 10, 24, 12, 0, 0);
      final nowSec = now.millisecondsSinceEpoch ~/ 1000;
      final header = {'alg': 'EdDSA', 'typ': 'JWT', 'kid': 'test-kid-1'};

      // 12a: iat at now + 60s (within 60s skew tolerance)
      final payloadValidSkew = {
        'iss': 'https://auth.quicknotes.app',
        'aud': 'com.quicknotes.byhmnth',
        'sub': 'sha256_hash',
        'entitlement': 'premium',
        'product_id': 'quicknotes_premium_lifetime',
        'status': 'ACTIVE',
        'iat': nowSec + 60,
        'nbf': nowSec + 60,
        'exp': nowSec + 60 + 604800,
      };
      final jwsValidSkew = createSignedJws(header: header, payload: payloadValidSkew);
      final leaseValidSkew = verifier.verify(
        jwsToken: jwsValidSkew,
        customPublicKeys: trustedKeys,
        currentTime: now,
      );
      expect(leaseValidSkew, isNotNull);

      // 12b: iat at now + 61s (exceeds 60s skew tolerance)
      final payloadExceedsSkew = {
        'iss': 'https://auth.quicknotes.app',
        'aud': 'com.quicknotes.byhmnth',
        'sub': 'sha256_hash',
        'entitlement': 'premium',
        'product_id': 'quicknotes_premium_lifetime',
        'status': 'ACTIVE',
        'iat': nowSec + 61,
        'nbf': nowSec + 61,
        'exp': nowSec + 61 + 604800,
      };
      final jwsExceedsSkew = createSignedJws(header: header, payload: payloadExceedsSkew);
      final leaseExceedsSkew = verifier.verify(
        jwsToken: jwsExceedsSkew,
        customPublicKeys: trustedKeys,
        currentTime: now,
      );
      expect(leaseExceedsSkew, isNull);
    });

    test('13. Rejects missing or non-positive temporal claims', () {
      final header = {'alg': 'EdDSA', 'typ': 'JWT', 'kid': 'test-kid-1'};
      final payload = {
        'iss': 'https://auth.quicknotes.app',
        'aud': 'com.quicknotes.byhmnth',
        'sub': 'sha256_hash',
        'entitlement': 'premium',
        'product_id': 'quicknotes_premium_lifetime',
        'status': 'ACTIVE',
        'iat': 0,
        'nbf': 0,
        'exp': 0,
      };

      final jws = createSignedJws(header: header, payload: payload);
      final lease = verifier.verify(jwsToken: jws, customPublicKeys: trustedKeys);
      expect(lease, isNull);
    });

    test('14. Validates staging public key pinning in PremiumBackendConfig', () {
      expect(
        PremiumBackendConfig.trustedPublicKeys['v1'],
        equals('E3XUIUC7AqNxLreAd0EnnNb7xyDlC6RZGGvPVE+Q3TU='),
      );
      expect(
        PremiumBackendConfig.trustedPublicKeys['v1'],
        isNot(equals('11qYAYKxCrfVS/7TyWQHOg7hcvPapiMlrwIaaPcHURo=')),
      );
    });

    test('15. Cryptographic distinction: placeholder key cannot validate staging key signed lease', () {
      final keyASeed = Uint8List.fromList(List.generate(32, (i) => i * 7 + 3));
      final keyAPublic = Ed25519.publicKeyFromSeed(keyASeed);
      final keyAPublicB64 = base64Encode(keyAPublic);

      const placeholderKeyB64 = '11qYAYKxCrfVS/7TyWQHOg7hcvPapiMlrwIaaPcHURo=';

      final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final header = {'alg': 'EdDSA', 'typ': 'JWT', 'kid': 'v1'};
      final payload = {
        'iss': 'https://quicknotes-entitlements-staging.hemanth1-adapala.workers.dev',
        'aud': 'com.quicknotes.byhmnth',
        'sub': 'test_token_hash',
        'entitlement': 'premium',
        'product_id': 'quicknotes_premium_lifetime',
        'status': 'ACTIVE',
        'iat': nowSec,
        'nbf': nowSec,
        'exp': nowSec + 604800,
        'jti': 'staging-jti-1',
      };

      final jws = createSignedJws(
        header: header,
        payload: payload,
        signingSeed: keyASeed,
      );

      // Verifier using valid key A accepts the lease
      final leaseValid = verifier.verify(
        jwsToken: jws,
        customPublicKeys: {'v1': keyAPublicB64},
        expectedIssuer: 'https://quicknotes-entitlements-staging.hemanth1-adapala.workers.dev',
        expectedSubject: 'test_token_hash',
      );
      expect(leaseValid, isNotNull);

      // Verifier using placeholder key rejects the lease
      final leaseRejected = verifier.verify(
        jwsToken: jws,
        customPublicKeys: {'v1': placeholderKeyB64},
        expectedIssuer: 'https://quicknotes-entitlements-staging.hemanth1-adapala.workers.dev',
        expectedSubject: 'test_token_hash',
      );
      expect(leaseRejected, isNull);
    });
  });
}
