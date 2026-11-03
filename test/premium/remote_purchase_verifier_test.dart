import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quick_notes/premium/crypto/ed25519.dart';
import 'package:quick_notes/premium/jws_lease_verifier.dart';
import 'package:quick_notes/premium/premium_entitlement.dart';
import 'package:quick_notes/premium/premium_entitlement_manager.dart';
import 'package:quick_notes/premium/remote_purchase_verifier.dart';

class MockHttpTransport implements HttpTransport {
  int statusCode;
  String responseBody;
  bool shouldThrow;

  MockHttpTransport({
    this.statusCode = 200,
    this.responseBody = '{}',
    this.shouldThrow = false,
  });

  @override
  Future<HttpResponseData> post({
    required Uri url,
    required Map<String, String> headers,
    required String body,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (shouldThrow) {
      throw Exception('Connection timed out / Network unreachable');
    }
    return HttpResponseData(
      statusCode: statusCode,
      body: responseBody,
    );
  }
}

class FakePurchaseDetails extends PurchaseDetails {
  FakePurchaseDetails({
    required super.productID,
    required super.purchaseID,
    required super.verificationData,
    required super.transactionDate,
    required super.status,
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RemotePurchaseVerifier Tests', () {
    late FlutterSecureStorage mockStorage;
    late PremiumEntitlementManager manager;
    final testSeed = Uint8List.fromList(List.generate(32, (i) => i * 3 + 1));
    final testPublicKey = Ed25519.publicKeyFromSeed(testSeed);
    final testTrustedKeys = {'test-kid-1': base64Encode(testPublicKey)};

    String base64UrlEncode(List<int> bytes) {
      return base64Url.encode(bytes).replaceAll('=', '');
    }

    String createTestJws({
      required String subject,
      required String issuer,
      String kid = 'test-kid-1',
    }) {
      final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final header = {'alg': 'EdDSA', 'typ': 'JWT', 'kid': kid};
      final payload = {
        'iss': issuer,
        'aud': 'com.quicknotes.byhmnth',
        'sub': subject,
        'entitlement': 'premium',
        'product_id': 'quicknotes_premium_lifetime',
        'status': 'ACTIVE',
        'iat': nowSec,
        'nbf': nowSec,
        'exp': nowSec + 604800,
        'jti': 'jti-12345',
      };

      final headerB64 = base64UrlEncode(utf8.encode(jsonEncode(header)));
      final payloadB64 = base64UrlEncode(utf8.encode(jsonEncode(payload)));
      final signingInput = ascii.encode('$headerB64.$payloadB64');

      final sig = Ed25519.sign(
        seed: testSeed,
        message: Uint8List.fromList(signingInput),
      );
      final sigB64 = base64UrlEncode(sig);

      return '$headerB64.$payloadB64.$sigB64';
    }

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      mockStorage = const FlutterSecureStorage();
      manager = PremiumEntitlementManager(
        secureStorage: mockStorage,
        isDebug: false,
        requireLease: false,
      );
      await manager.initialize();
    });

    const testIssuerUrl = 'https://backend.quicknotes.test';

    test('1. HTTP 200 with valid JWS lease activates entitlement and updates lease', () async {
      const purchaseToken = 'google_play_purchase_token_abc123';
      final tokenHash = JwsLeaseVerifier.sha256Hex(purchaseToken);
      final jws = createTestJws(
        subject: tokenHash,
        issuer: testIssuerUrl,
      );

      final mockTransport = MockHttpTransport(
        statusCode: 200,
        responseBody: jsonEncode({
          'token': jws,
          'status': 'ACTIVE',
          'product_id': 'quicknotes_premium_lifetime',
        }),
      );

      final verifier = RemotePurchaseVerifier(
        entitlementManager: manager,
        transport: mockTransport,
        issuerUrl: testIssuerUrl,
        leaseVerifier: JwsLeaseVerifier(testTrustedKeys),
      );

      final details = FakePurchaseDetails(
        productID: 'quicknotes_premium_lifetime',
        purchaseID: 'GPA.1234-5678-9012',
        transactionDate: '1700000000000',
        status: PurchaseStatus.purchased,
        verificationData: PurchaseVerificationData(
          localVerificationData: purchaseToken,
          serverVerificationData: purchaseToken,
          source: 'google_play',
        ),
      );

      final entitlement = await verifier.verifyPurchase(details);
      expect(entitlement, isNotNull);
      expect(entitlement!.isActive, isTrue);
      expect(manager.currentLease, isNotNull);
    });

    test('2. Explicit authoritative HTTP 403 REVOKED revokes entitlement authoritatively', () async {
      const purchaseToken = 'google_play_purchase_token_revoked';

      // Pre-seed an active entitlement in manager
      await manager.updateEntitlement(
        PremiumEntitlement.active(
          productId: 'quicknotes_premium_lifetime',
          storeSource: StoreSource.google,
        ),
      );
      expect(manager.currentEntitlement.isActive, isTrue);

      final mockTransport = MockHttpTransport(
        statusCode: 403,
        responseBody: jsonEncode({
          'status': 'REVOKED',
          'reason': 'GOOGLE_PLAY_CANCELLED',
        }),
      );

      final verifier = RemotePurchaseVerifier(
        entitlementManager: manager,
        transport: mockTransport,
        issuerUrl: testIssuerUrl,
      );

      final details = FakePurchaseDetails(
        productID: 'quicknotes_premium_lifetime',
        purchaseID: 'GPA.9999-9999-9999',
        transactionDate: '1700000000000',
        status: PurchaseStatus.purchased,
        verificationData: PurchaseVerificationData(
          localVerificationData: purchaseToken,
          serverVerificationData: purchaseToken,
          source: 'google_play',
        ),
      );

      final result = await verifier.verifyPurchase(details);
      expect(result, isNotNull);
      expect(result!.status, equals(EntitlementStatus.revoked));
      expect(manager.currentEntitlement.status, equals(EntitlementStatus.revoked));
    });

    test('3. Generic HTTP 403 Forbidden does NOT revoke active entitlement', () async {
      const purchaseToken = 'google_play_purchase_token_waf';

      // Pre-seed an active entitlement
      await manager.updateEntitlement(
        PremiumEntitlement.active(
          productId: 'quicknotes_premium_lifetime',
          storeSource: StoreSource.google,
        ),
      );
      expect(manager.currentEntitlement.isActive, isTrue);

      // Generic Cloudflare WAF / proxy 403 error
      final mockTransport = MockHttpTransport(
        statusCode: 403,
        responseBody: jsonEncode({
          'error': 'Forbidden',
          'message': 'Access denied by security policy',
        }),
      );

      final verifier = RemotePurchaseVerifier(
        entitlementManager: manager,
        transport: mockTransport,
        issuerUrl: testIssuerUrl,
      );

      final details = FakePurchaseDetails(
        productID: 'quicknotes_premium_lifetime',
        purchaseID: 'GPA.1111-2222-3333',
        transactionDate: '1700000000000',
        status: PurchaseStatus.purchased,
        verificationData: PurchaseVerificationData(
          localVerificationData: purchaseToken,
          serverVerificationData: purchaseToken,
          source: 'google_play',
        ),
      );

      final result = await verifier.verifyPurchase(details);
      // Non-authoritative 403 returns null without revoking
      expect(result, isNull);
      expect(manager.currentEntitlement.isActive, isTrue);
    });

    test('4. Malformed JSON on HTTP 403 does NOT revoke active entitlement', () async {
      const purchaseToken = 'google_play_purchase_token_malformed';

      await manager.updateEntitlement(
        PremiumEntitlement.active(
          productId: 'quicknotes_premium_lifetime',
          storeSource: StoreSource.google,
        ),
      );

      final mockTransport = MockHttpTransport(
        statusCode: 403,
        responseBody: '<html><body>403 WAF Block</body></html>',
      );

      final verifier = RemotePurchaseVerifier(
        entitlementManager: manager,
        transport: mockTransport,
        issuerUrl: testIssuerUrl,
      );

      final details = FakePurchaseDetails(
        productID: 'quicknotes_premium_lifetime',
        purchaseID: 'GPA.4444',
        transactionDate: '1700000000000',
        status: PurchaseStatus.purchased,
        verificationData: PurchaseVerificationData(
          localVerificationData: purchaseToken,
          serverVerificationData: purchaseToken,
          source: 'google_play',
        ),
      );

      final result = await verifier.verifyPurchase(details);
      expect(result, isNull);
      expect(manager.currentEntitlement.isActive, isTrue);
    });

    test('5. Unrelated error payload on HTTP 403 does NOT revoke active entitlement', () async {
      const purchaseToken = 'google_play_purchase_token_other';

      await manager.updateEntitlement(
        PremiumEntitlement.active(
          productId: 'quicknotes_premium_lifetime',
          storeSource: StoreSource.google,
        ),
      );

      final mockTransport = MockHttpTransport(
        statusCode: 403,
        responseBody: jsonEncode({
          'status': 'UNKNOWN',
          'error': 'SOME_OTHER_ERROR',
        }),
      );

      final verifier = RemotePurchaseVerifier(
        entitlementManager: manager,
        transport: mockTransport,
        issuerUrl: testIssuerUrl,
      );

      final details = FakePurchaseDetails(
        productID: 'quicknotes_premium_lifetime',
        purchaseID: 'GPA.5555',
        transactionDate: '1700000000000',
        status: PurchaseStatus.purchased,
        verificationData: PurchaseVerificationData(
          localVerificationData: purchaseToken,
          serverVerificationData: purchaseToken,
          source: 'google_play',
        ),
      );

      final result = await verifier.verifyPurchase(details);
      expect(result, isNull);
      expect(manager.currentEntitlement.isActive, isTrue);
    });

    test('5b. HTTP 403 with status: REVOKED but missing reason does NOT revoke active entitlement', () async {
      const purchaseToken = 'google_play_purchase_token_no_reason';

      await manager.updateEntitlement(
        PremiumEntitlement.active(
          productId: 'quicknotes_premium_lifetime',
          storeSource: StoreSource.google,
        ),
      );

      final mockTransport = MockHttpTransport(
        statusCode: 403,
        responseBody: jsonEncode({
          'status': 'REVOKED',
        }),
      );

      final verifier = RemotePurchaseVerifier(
        entitlementManager: manager,
        transport: mockTransport,
        issuerUrl: testIssuerUrl,
      );

      final details = FakePurchaseDetails(
        productID: 'quicknotes_premium_lifetime',
        purchaseID: 'GPA.5001',
        transactionDate: '1700000000000',
        status: PurchaseStatus.purchased,
        verificationData: PurchaseVerificationData(
          localVerificationData: purchaseToken,
          serverVerificationData: purchaseToken,
          source: 'google_play',
        ),
      );

      final result = await verifier.verifyPurchase(details);
      expect(result, isNull);
      expect(manager.currentEntitlement.isActive, isTrue);
    });

    test('5c. HTTP 403 with status: REVOKED and null reason does NOT revoke active entitlement', () async {
      const purchaseToken = 'google_play_purchase_token_null_reason';

      await manager.updateEntitlement(
        PremiumEntitlement.active(
          productId: 'quicknotes_premium_lifetime',
          storeSource: StoreSource.google,
        ),
      );

      final mockTransport = MockHttpTransport(
        statusCode: 403,
        responseBody: jsonEncode({
          'status': 'REVOKED',
          'reason': null,
        }),
      );

      final verifier = RemotePurchaseVerifier(
        entitlementManager: manager,
        transport: mockTransport,
        issuerUrl: testIssuerUrl,
      );

      final details = FakePurchaseDetails(
        productID: 'quicknotes_premium_lifetime',
        purchaseID: 'GPA.5002',
        transactionDate: '1700000000000',
        status: PurchaseStatus.purchased,
        verificationData: PurchaseVerificationData(
          localVerificationData: purchaseToken,
          serverVerificationData: purchaseToken,
          source: 'google_play',
        ),
      );

      final result = await verifier.verifyPurchase(details);
      expect(result, isNull);
      expect(manager.currentEntitlement.isActive, isTrue);
    });

    test('5d. HTTP 403 with status: REVOKED and mismatched reason does NOT revoke active entitlement', () async {
      const purchaseToken = 'google_play_purchase_token_mismatched_reason';

      await manager.updateEntitlement(
        PremiumEntitlement.active(
          productId: 'quicknotes_premium_lifetime',
          storeSource: StoreSource.google,
        ),
      );

      final mockTransport = MockHttpTransport(
        statusCode: 403,
        responseBody: jsonEncode({
          'status': 'REVOKED',
          'reason': 'UNEXPECTED_REASON',
        }),
      );

      final verifier = RemotePurchaseVerifier(
        entitlementManager: manager,
        transport: mockTransport,
        issuerUrl: testIssuerUrl,
      );

      final details = FakePurchaseDetails(
        productID: 'quicknotes_premium_lifetime',
        purchaseID: 'GPA.5003',
        transactionDate: '1700000000000',
        status: PurchaseStatus.purchased,
        verificationData: PurchaseVerificationData(
          localVerificationData: purchaseToken,
          serverVerificationData: purchaseToken,
          source: 'google_play',
        ),
      );

      final result = await verifier.verifyPurchase(details);
      expect(result, isNull);
      expect(manager.currentEntitlement.isActive, isTrue);
    });

    test('6. Fail closed when backend is unconfigured in release mode (legacy fallback never invoked)', () async {
      const purchaseToken = 'google_play_purchase_token_unconfigured';

      final verifier = RemotePurchaseVerifier(
        entitlementManager: manager,
        issuerUrl: '', // Unconfigured backend
        isReleaseMode: true, // Production release mode
        allowUnconfiguredFallback: true, // Even if requested, release mode forbids fallback
      );

      final details = FakePurchaseDetails(
        productID: 'quicknotes_premium_lifetime',
        purchaseID: 'GPA.6666',
        transactionDate: '1700000000000',
        status: PurchaseStatus.purchased,
        verificationData: PurchaseVerificationData(
          localVerificationData: purchaseToken,
          serverVerificationData: purchaseToken,
          source: 'google_play',
        ),
      );

      final result = await verifier.verifyPurchase(details);
      expect(result, isNull); // Must fail closed!
    });

    test('7. Fail closed when backend is unconfigured and allowUnconfiguredFallback is false', () async {
      const purchaseToken = 'google_play_purchase_token_unconfigured_debug';

      final verifier = RemotePurchaseVerifier(
        entitlementManager: manager,
        issuerUrl: '', // Unconfigured
        isReleaseMode: false,
        allowUnconfiguredFallback: false, // Explicitly disabled
      );

      final details = FakePurchaseDetails(
        productID: 'quicknotes_premium_lifetime',
        purchaseID: 'GPA.7777',
        transactionDate: '1700000000000',
        status: PurchaseStatus.purchased,
        verificationData: PurchaseVerificationData(
          localVerificationData: purchaseToken,
          serverVerificationData: purchaseToken,
          source: 'google_play',
        ),
      );

      final result = await verifier.verifyPurchase(details);
      expect(result, isNull);
    });

    test('8. Rejects unexpected product ID without network dispatch', () async {
      final mockTransport = MockHttpTransport(
        statusCode: 200,
        responseBody: '{}',
      );

      final verifier = RemotePurchaseVerifier(
        entitlementManager: manager,
        transport: mockTransport,
        issuerUrl: testIssuerUrl,
      );

      final details = FakePurchaseDetails(
        productID: 'wrong_subscription_id',
        purchaseID: 'GPA.0000',
        transactionDate: '1700000000000',
        status: PurchaseStatus.purchased,
        verificationData: PurchaseVerificationData(
          localVerificationData: 'token',
          serverVerificationData: 'token',
          source: 'google_play',
        ),
      );

      final result = await verifier.verifyPurchase(details);
      expect(result, isNull);
    });

    test('9. Network error returns null without revoking valid cached state', () async {
      final mockTransport = MockHttpTransport(shouldThrow: true);

      await manager.updateEntitlement(
        PremiumEntitlement.active(
          productId: 'quicknotes_premium_lifetime',
          storeSource: StoreSource.google,
        ),
      );

      final verifier = RemotePurchaseVerifier(
        entitlementManager: manager,
        transport: mockTransport,
        issuerUrl: testIssuerUrl,
      );

      final details = FakePurchaseDetails(
        productID: 'quicknotes_premium_lifetime',
        purchaseID: 'GPA.5555',
        transactionDate: '1700000000000',
        status: PurchaseStatus.purchased,
        verificationData: PurchaseVerificationData(
          localVerificationData: 'token',
          serverVerificationData: 'token',
          source: 'google_play',
        ),
      );

      final result = await verifier.verifyPurchase(details);
      expect(result, isNull);
      expect(manager.currentEntitlement.isActive, isTrue);
    });

    test('10. Rejects JWS signed with mismatched key against pinned trustedPublicKeys', () async {
      const stagingIssuerUrl = 'https://quicknotes-entitlements-staging.hemanth1-adapala.workers.dev';
      const purchaseToken = 'google_play_purchase_token_mismatched_key';
      final tokenHash = JwsLeaseVerifier.sha256Hex(purchaseToken);

      // Sign with testSeed (which does NOT match staging pinned key E3XUIUC7AqNxLreAd0EnnNb7xyDlC6RZGGvPVE+Q3TU=)
      final jwsSignedWithDifferentKey = createTestJws(
        subject: tokenHash,
        issuer: stagingIssuerUrl,
        kid: 'v1',
      );

      final mockTransport = MockHttpTransport(
        statusCode: 200,
        responseBody: jsonEncode({'token': jwsSignedWithDifferentKey}),
      );

      // RemotePurchaseVerifier with default JwsLeaseVerifier (using PremiumBackendConfig.trustedPublicKeys)
      final verifier = RemotePurchaseVerifier(
        entitlementManager: manager,
        transport: mockTransport,
        issuerUrl: stagingIssuerUrl,
      );

      final details = FakePurchaseDetails(
        productID: 'quicknotes_premium_lifetime',
        purchaseID: 'GPA.9999-mismatch',
        transactionDate: '1700000000000',
        status: PurchaseStatus.purchased,
        verificationData: PurchaseVerificationData(
          localVerificationData: purchaseToken,
          serverVerificationData: purchaseToken,
          source: 'google_play',
        ),
      );

      final result = await verifier.verifyPurchase(details);
      // Fails verification cryptographically because pinned key does not match signer
      expect(result, isNull);
      expect(manager.isPremiumActive, isFalse);
    });

    test('11. Accepts JWS signed with matching key and activates entitlement', () async {
      const stagingIssuerUrl = 'https://quicknotes-entitlements-staging.hemanth1-adapala.workers.dev';
      const purchaseToken = 'google_play_purchase_token_matching_key';
      final tokenHash = JwsLeaseVerifier.sha256Hex(purchaseToken);

      final jws = createTestJws(
        subject: tokenHash,
        issuer: stagingIssuerUrl,
        kid: 'test-kid-1',
      );

      final mockTransport = MockHttpTransport(
        statusCode: 200,
        responseBody: jsonEncode({'token': jws}),
      );

      final verifier = RemotePurchaseVerifier(
        entitlementManager: manager,
        transport: mockTransport,
        leaseVerifier: JwsLeaseVerifier(testTrustedKeys),
        issuerUrl: stagingIssuerUrl,
      );

      final details = FakePurchaseDetails(
        productID: 'quicknotes_premium_lifetime',
        purchaseID: 'GPA.1234-matching',
        transactionDate: '1700000000000',
        status: PurchaseStatus.purchased,
        verificationData: PurchaseVerificationData(
          localVerificationData: purchaseToken,
          serverVerificationData: purchaseToken,
          source: 'google_play',
        ),
      );

      final result = await verifier.verifyPurchase(details);
      expect(result, isNotNull);
      expect(result!.isActive, isTrue);
      expect(result.status, equals(EntitlementStatus.active));
      expect(manager.isPremiumActive, isTrue);
    });
  });
}
