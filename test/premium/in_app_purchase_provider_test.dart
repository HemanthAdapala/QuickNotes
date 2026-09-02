import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:quick_notes/premium/premium.dart';

/// Test double for [InAppPurchase] plugin
class FakeInAppPurchase implements InAppPurchase {
  bool isAvailableResult = true;
  bool queryProductDetailsError = false;
  List<ProductDetails> productsToReturn = [];
  bool buyNonConsumableResult = true;
  bool restorePurchasesCalled = false;
  List<PurchaseDetails> completedPurchases = [];

  final StreamController<List<PurchaseDetails>> _purchaseStreamController =
      StreamController<List<PurchaseDetails>>.broadcast();

  @override
  Stream<List<PurchaseDetails>> get purchaseStream =>
      _purchaseStreamController.stream;

  void emitPurchases(List<PurchaseDetails> purchases) {
    _purchaseStreamController.add(purchases);
  }

  @override
  Future<bool> isAvailable() async => isAvailableResult;

  @override
  Future<String> countryCode() async => 'US';

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) async {
    if (queryProductDetailsError) {
      return ProductDetailsResponse(
        productDetails: [],
        notFoundIDs: identifiers.toList(),
        error: IAPError(
          source: 'test',
          code: 'query_error',
          message: 'Failed to query store products',
        ),
      );
    }
    return ProductDetailsResponse(
      productDetails: productsToReturn,
      notFoundIDs: [],
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    return buyNonConsumableResult;
  }

  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) async {
    return false;
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restorePurchasesCalled = true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completedPurchases.add(purchase);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Helper to create fake [PurchaseDetails]
PurchaseDetails createTestPurchaseDetails({
  required String productID,
  required PurchaseStatus status,
  String purchaseID = 'test_tx_123',
  String transactionDate = '2026-09-02T12:00:00Z',
  bool pendingCompletePurchase = true,
  IAPError? error,
}) {
  final purchase = PurchaseDetails(
    purchaseID: purchaseID,
    productID: productID,
    verificationData: PurchaseVerificationData(
      localVerificationData: 'test_local',
      serverVerificationData: 'test_server',
      source: 'test',
    ),
    transactionDate: transactionDate,
    status: status,
  );
  purchase.pendingCompletePurchase = pendingCompletePurchase;
  purchase.error = error;
  return purchase;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Product Constant & Configuration Tests', () {
    test('1. Authoritative lifetime product ID is quicknotes_premium_lifetime', () {
      expect(premiumLifetimeProductId, equals('quicknotes_premium_lifetime'));
      expect(kAllProductIds, contains(premiumLifetimeProductId));
    });
  });

  group('PurchaseVerifier Unit Tests', () {
    const verifier = DefaultPurchaseVerifier();

    test('2. Verifies valid lifetime purchase successfully', () async {
      final purchase = createTestPurchaseDetails(
        productID: premiumLifetimeProductId,
        status: PurchaseStatus.purchased,
        purchaseID: 'GPA.1234-5678',
      );

      final entitlement = await verifier.verifyPurchase(purchase);

      expect(entitlement, isNotNull);
      expect(entitlement!.isActive, isTrue);
      expect(entitlement.productId, equals(premiumLifetimeProductId));
      expect(entitlement.transactionReference, equals('GPA.1234-5678'));
      expect(entitlement.status, equals(EntitlementStatus.active));
    });

    test('3. Verifies restored lifetime purchase successfully', () async {
      final purchase = createTestPurchaseDetails(
        productID: premiumLifetimeProductId,
        status: PurchaseStatus.restored,
        purchaseID: 'apple_tx_9999',
      );

      final entitlement = await verifier.verifyPurchase(purchase);

      expect(entitlement, isNotNull);
      expect(entitlement!.isActive, isTrue);
      expect(entitlement.productId, equals(premiumLifetimeProductId));
    });

    test('4. Rejects purchase with unexpected product ID', () async {
      final purchase = createTestPurchaseDetails(
        productID: 'unknown_consumable_coins',
        status: PurchaseStatus.purchased,
      );

      final entitlement = await verifier.verifyPurchase(purchase);
      expect(entitlement, isNull);
    });

    test('5. Rejects purchase with invalid status', () async {
      final purchase = createTestPurchaseDetails(
        productID: premiumLifetimeProductId,
        status: PurchaseStatus.error,
      );

      final entitlement = await verifier.verifyPurchase(purchase);
      expect(entitlement, isNull);
    });
  });

  group('InAppPurchaseProvider Unit & Lifecycle Tests', () {
    late FakeInAppPurchase fakeIap;
    late PremiumEntitlementManager entitlementManager;
    late InAppPurchaseProvider provider;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      fakeIap = FakeInAppPurchase();
      entitlementManager = PremiumEntitlementManager();
      provider = InAppPurchaseProvider(
        inAppPurchase: fakeIap,
        verifier: const DefaultPurchaseVerifier(),
        entitlementManager: entitlementManager,
      );
    });

    tearDown(() {
      provider.dispose();
    });

    test('6. Initialization checks store availability and loads products', () async {
      await entitlementManager.initialize();

      fakeIap.productsToReturn = [
        ProductDetails(
          id: premiumLifetimeProductId,
          title: 'QuickNotes Premium Lifetime',
          description: 'Unlock all features forever',
          price: '\$4.99',
          rawPrice: 4.99,
          currencyCode: 'USD',
        ),
      ];

      await provider.initialize();

      expect(provider.isAvailable, isTrue);
      expect(provider.productDetails, isNotNull);
      expect(provider.productDetails!.id, equals(premiumLifetimeProductId));
      expect(provider.formattedPrice, equals('\$4.99'));
    });

    test('7. purchasePremium dispatches non-consumable purchase to store', () async {
      await entitlementManager.initialize();
      fakeIap.productsToReturn = [
        ProductDetails(
          id: premiumLifetimeProductId,
          title: 'QuickNotes Premium Lifetime',
          description: 'Unlock all features forever',
          price: '\$4.99',
          rawPrice: 4.99,
          currencyCode: 'USD',
        ),
      ];
      await provider.initialize();

      final result = await provider.purchasePremium();
      expect(result, isTrue);
      expect(provider.currentState.status, equals(PurchaseActionStatus.purchasing));
    });

    test('8. restorePurchases calls platform store restore', () async {
      await entitlementManager.initialize();
      await provider.initialize();

      final result = await provider.restorePurchases();
      expect(result, isTrue);
      expect(fakeIap.restorePurchasesCalled, isTrue);
      expect(provider.currentState.status, equals(PurchaseActionStatus.restoring));
    });

    test('9. Stream update with purchased status activates PremiumEntitlementManager', () async {
      await entitlementManager.initialize();
      await provider.initialize();

      expect(entitlementManager.isPremiumActive, isFalse);

      // Emit purchased event
      final purchase = createTestPurchaseDetails(
        productID: premiumLifetimeProductId,
        status: PurchaseStatus.purchased,
        purchaseID: 'tx_verified_1',
      );
      fakeIap.emitPurchases([purchase]);

      // Wait for stream event loop
      await pumpEventQueue();

      expect(entitlementManager.isPremiumActive, isTrue);
      expect(entitlementManager.currentEntitlement.productId, equals(premiumLifetimeProductId));
      expect(fakeIap.completedPurchases, contains(purchase));
      expect(provider.currentState.status, equals(PurchaseActionStatus.success));
    });

    test('10. Stream update with canceled status does NOT destroy existing entitlement', () async {
      await entitlementManager.initialize();
      // Pre-grant active entitlement
      await entitlementManager.updateEntitlement(
        PremiumEntitlement.active(productId: premiumLifetimeProductId),
      );
      expect(entitlementManager.isPremiumActive, isTrue);

      await provider.initialize();

      // Emit canceled purchase
      final purchase = createTestPurchaseDetails(
        productID: premiumLifetimeProductId,
        status: PurchaseStatus.canceled,
      );
      fakeIap.emitPurchases([purchase]);

      await pumpEventQueue();

      // Crucial: Active entitlement MUST remain active
      expect(entitlementManager.isPremiumActive, isTrue);
      expect(provider.currentState.status, equals(PurchaseActionStatus.cancelled));
      expect(fakeIap.completedPurchases, contains(purchase));
    });

    test('11. Stream update with error status does NOT destroy existing entitlement', () async {
      await entitlementManager.initialize();
      await entitlementManager.updateEntitlement(
        PremiumEntitlement.active(productId: premiumLifetimeProductId),
      );
      expect(entitlementManager.isPremiumActive, isTrue);

      await provider.initialize();

      final purchase = createTestPurchaseDetails(
        productID: premiumLifetimeProductId,
        status: PurchaseStatus.error,
        error: IAPError(
          source: 'test',
          code: 'payment_declined',
          message: 'Payment was declined by card issuer',
        ),
      );
      fakeIap.emitPurchases([purchase]);

      await pumpEventQueue();

      expect(entitlementManager.isPremiumActive, isTrue);
      expect(provider.currentState.status, equals(PurchaseActionStatus.error));
      expect(provider.currentState.errorMessage, contains('declined'));
    });

    test('12. Stream update with unexpected product ID does not unlock Premium', () async {
      await entitlementManager.initialize();
      expect(entitlementManager.isPremiumActive, isFalse);

      await provider.initialize();

      final purchase = createTestPurchaseDetails(
        productID: 'fake_fraudulent_product_id',
        status: PurchaseStatus.purchased,
      );
      fakeIap.emitPurchases([purchase]);

      await pumpEventQueue();

      expect(entitlementManager.isPremiumActive, isFalse);
      expect(provider.currentState.status, equals(PurchaseActionStatus.error));
    });
  });
}
