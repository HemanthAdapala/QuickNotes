import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:quick_notes/premium/premium.dart';

/// Test double for [InAppPurchase] plugin
class FakeInAppPurchase implements InAppPurchase {
  bool isAvailableResult = true;
  bool queryProductDetailsError = false;
  List<ProductDetails> productsToReturn = [];
  bool buyNonConsumableResult = true;
  bool restorePurchasesCalled = false;
  bool restorePurchasesThrows = false;
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
    if (restorePurchasesThrows) {
      throw Exception('Store network timeout');
    }
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
      SharedPreferences.setMockInitialValues({});
      fakeIap = FakeInAppPurchase();
      entitlementManager = PremiumEntitlementManager();
      provider = InAppPurchaseProvider(
        inAppPurchase: fakeIap,
        verifier: const DefaultPurchaseVerifier(),
        entitlementManager: entitlementManager,
        restoreTimeoutDuration: const Duration(milliseconds: 50),
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

    test('13. Restore with no purchase events times out and exits restoring state with truthful message', () async {
      await entitlementManager.initialize();
      await provider.initialize();

      expect(provider.currentState.status, equals(PurchaseActionStatus.idle));

      final result = await provider.restorePurchases();
      expect(result, isTrue);
      expect(provider.currentState.status, equals(PurchaseActionStatus.restoring));

      // Wait for bounded timeout (50ms in test)
      await Future<void>.delayed(const Duration(milliseconds: 70));

      expect(provider.currentState.status, equals(PurchaseActionStatus.error));
      expect(provider.currentState.errorMessage, contains('Unable to confirm previous purchases'));
      expect(provider.currentState.errorMessage, contains('Google Play account'));
    });

    test('14. Restore timeout preserves existing valid Premium entitlement', () async {
      await entitlementManager.initialize();
      await entitlementManager.updateEntitlement(
        PremiumEntitlement.active(productId: premiumLifetimeProductId),
      );
      expect(entitlementManager.isPremiumActive, isTrue);

      await provider.initialize();

      await provider.restorePurchases();
      expect(provider.currentState.status, equals(PurchaseActionStatus.restoring));

      // Wait for timeout
      await Future<void>.delayed(const Duration(milliseconds: 70));

      // Entitlement must strictly remain active
      expect(entitlementManager.isPremiumActive, isTrue);
      expect(provider.currentState.status, equals(PurchaseActionStatus.error));
    });

    test('15. Restore timeout does NOT grant Premium to free user', () async {
      await entitlementManager.initialize();
      expect(entitlementManager.isPremiumActive, isFalse);

      await provider.initialize();
      await provider.restorePurchases();

      await Future<void>.delayed(const Duration(milliseconds: 70));

      expect(entitlementManager.isPremiumActive, isFalse);
    });

    test('16. Store failure during restore handles exception cleanly', () async {
      await entitlementManager.initialize();
      await provider.initialize();

      fakeIap.restorePurchasesThrows = true;

      final result = await provider.restorePurchases();
      expect(result, isFalse);
      expect(provider.currentState.status, equals(PurchaseActionStatus.error));
      expect(provider.currentState.errorMessage, contains('Failed to restore previous purchases'));
    });

    test('17. Concurrent restore requests while restoring are rejected', () async {
      await entitlementManager.initialize();
      await provider.initialize();

      final firstCall = await provider.restorePurchases();
      expect(firstCall, isTrue);
      expect(provider.currentState.status, equals(PurchaseActionStatus.restoring));

      // Immediate concurrent attempt must be rejected
      final secondCall = await provider.restorePurchases();
      expect(secondCall, isFalse);
      expect(provider.currentState.status, equals(PurchaseActionStatus.restoring));

      // Clean up timer
      await Future<void>.delayed(const Duration(milliseconds: 70));
    });

    test('18. Restored event arriving before timeout cancels timeout and activates Premium', () async {
      await entitlementManager.initialize();
      await provider.initialize();

      expect(entitlementManager.isPremiumActive, isFalse);

      await provider.restorePurchases();
      expect(provider.currentState.status, equals(PurchaseActionStatus.restoring));

      // Emit restored event immediately before timeout
      final purchase = createTestPurchaseDetails(
        productID: premiumLifetimeProductId,
        status: PurchaseStatus.restored,
        purchaseID: 'restore_tx_early',
      );
      fakeIap.emitPurchases([purchase]);

      await pumpEventQueue();

      expect(entitlementManager.isPremiumActive, isTrue);
      expect(provider.currentState.status, equals(PurchaseActionStatus.success));

      // Wait past timeout window to confirm timer was canceled and does not overwrite success
      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(provider.currentState.status, equals(PurchaseActionStatus.success));
      expect(entitlementManager.isPremiumActive, isTrue);
    });

    test('19. Valid restored event arriving AFTER timeout still processes and unlocks Premium', () async {
      await entitlementManager.initialize();
      await provider.initialize();

      expect(entitlementManager.isPremiumActive, isFalse);

      await provider.restorePurchases();
      // Let timeout expire
      await Future<void>.delayed(const Duration(milliseconds: 70));

      expect(provider.currentState.status, equals(PurchaseActionStatus.error));
      expect(entitlementManager.isPremiumActive, isFalse);

      // Late arriving valid restored event
      final latePurchase = createTestPurchaseDetails(
        productID: premiumLifetimeProductId,
        status: PurchaseStatus.restored,
        purchaseID: 'restore_tx_late',
      );
      fakeIap.emitPurchases([latePurchase]);

      await pumpEventQueue();

      // Late event must be processed and verified
      expect(entitlementManager.isPremiumActive, isTrue);
      expect(provider.currentState.status, equals(PurchaseActionStatus.success));
      expect(fakeIap.completedPurchases, contains(latePurchase));
    });

    test('20. Stream update with pending status sets PurchaseActionStatus.pending and does NOT unlock Premium', () async {
      await entitlementManager.initialize();
      await provider.initialize();

      expect(entitlementManager.isPremiumActive, isFalse);

      final pendingPurchase = createTestPurchaseDetails(
        productID: premiumLifetimeProductId,
        status: PurchaseStatus.pending,
      );
      fakeIap.emitPurchases([pendingPurchase]);

      await pumpEventQueue();

      expect(entitlementManager.isPremiumActive, isFalse);
      expect(provider.currentState.status, equals(PurchaseActionStatus.pending));
      expect(provider.currentState.errorMessage, contains('pending payment approval'));
    });

    test('21. Subsequent purchased update after pending unlocks Premium and transitions to success', () async {
      await entitlementManager.initialize();
      await provider.initialize();

      // Emit pending first
      final pendingPurchase = createTestPurchaseDetails(
        productID: premiumLifetimeProductId,
        status: PurchaseStatus.pending,
        purchaseID: 'pending_order_1',
      );
      fakeIap.emitPurchases([pendingPurchase]);
      await pumpEventQueue();

      expect(entitlementManager.isPremiumActive, isFalse);
      expect(provider.currentState.status, equals(PurchaseActionStatus.pending));

      // Now emit approved purchased event
      final approvedPurchase = createTestPurchaseDetails(
        productID: premiumLifetimeProductId,
        status: PurchaseStatus.purchased,
        purchaseID: 'approved_order_1',
      );
      fakeIap.emitPurchases([approvedPurchase]);
      await pumpEventQueue();

      expect(entitlementManager.isPremiumActive, isTrue);
      expect(provider.currentState.status, equals(PurchaseActionStatus.success));
      expect(fakeIap.completedPurchases, contains(approvedPurchase));
    });

    test('22. Cancellation and error statuses remain distinct from pending', () async {
      await entitlementManager.initialize();
      await provider.initialize();

      // Canceled
      fakeIap.emitPurchases([
        createTestPurchaseDetails(
          productID: premiumLifetimeProductId,
          status: PurchaseStatus.canceled,
        ),
      ]);
      await pumpEventQueue();
      expect(provider.currentState.status, equals(PurchaseActionStatus.cancelled));
      expect(provider.currentState.status, isNot(equals(PurchaseActionStatus.pending)));

      // Error
      fakeIap.emitPurchases([
        createTestPurchaseDetails(
          productID: premiumLifetimeProductId,
          status: PurchaseStatus.error,
          error: IAPError(source: 'test', code: 'err', message: 'failed'),
        ),
      ]);
      await pumpEventQueue();
      expect(provider.currentState.status, equals(PurchaseActionStatus.error));
      expect(provider.currentState.status, isNot(equals(PurchaseActionStatus.pending)));
    });
  });

  group('Phase 2 — Lifecycle Reliability & Failure-Path Hardening Tests', () {
    late FakeInAppPurchase fakeIap;
    late PremiumEntitlementManager entitlementManager;
    late InAppPurchaseProvider provider;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      fakeIap = FakeInAppPurchase();
      fakeIap.productsToReturn = [
        ProductDetails(
          id: premiumLifetimeProductId,
          title: 'Quick Notes Premium Lifetime',
          description: 'Lifetime access to all premium features',
          price: r'$4.99',
          rawPrice: 4.99,
          currencyCode: 'USD',
        ),
      ];
      entitlementManager = PremiumEntitlementManager();
      provider = InAppPurchaseProvider(
        inAppPurchase: fakeIap,
        entitlementManager: entitlementManager,
        restoreTimeoutDuration: const Duration(milliseconds: 50),
      );
    });

    tearDown(() {
      provider.dispose();
      entitlementManager.dispose();
    });

    test('23. Startup reconciliation recovers cleared cache when Play Store has existing purchase', () async {
      await entitlementManager.initialize();
      expect(entitlementManager.isPremiumActive, isFalse);

      await provider.initialize();
      expect(fakeIap.restorePurchasesCalled, isTrue);

      fakeIap.emitPurchases([
        createTestPurchaseDetails(
          productID: premiumLifetimeProductId,
          status: PurchaseStatus.restored,
          purchaseID: 'recovered_play_order_1',
        ),
      ]);
      await pumpEventQueue();

      expect(entitlementManager.isPremiumActive, isTrue);
      expect(provider.currentState.status, equals(PurchaseActionStatus.success));
      expect(fakeIap.completedPurchases.any((p) => p.purchaseID == 'recovered_play_order_1'), isTrue);
    });

    test('24. ITEM_ALREADY_OWNED error (code 7) triggers reconciliation and verifies purchase before granting Premium', () async {
      await entitlementManager.initialize();
      await provider.initialize();
      expect(entitlementManager.isPremiumActive, isFalse);

      fakeIap.restorePurchasesCalled = false;
      await provider.purchasePremium();

      // Play Store returns ITEM_ALREADY_OWNED error code 7
      fakeIap.emitPurchases([
        createTestPurchaseDetails(
          productID: premiumLifetimeProductId,
          status: PurchaseStatus.error,
          error: IAPError(
            source: 'google_play',
            code: '7',
            message: 'BillingResponse.itemAlreadyOwned',
          ),
        ),
      ]);
      await pumpEventQueue();

      // Rule 7 check: Entitlement MUST NOT be granted merely from error code 7
      expect(entitlementManager.isPremiumActive, isFalse);
      expect(fakeIap.restorePurchasesCalled, isTrue);
      expect(provider.currentState.status, equals(PurchaseActionStatus.restoring));

      // Authentic restored purchase arrives
      fakeIap.emitPurchases([
        createTestPurchaseDetails(
          productID: premiumLifetimeProductId,
          status: PurchaseStatus.restored,
          purchaseID: 'authoritative_verified_tx',
        ),
      ]);
      await pumpEventQueue();

      expect(entitlementManager.isPremiumActive, isTrue);
      expect(provider.currentState.status, equals(PurchaseActionStatus.success));
    });

    test('25. ITEM_ALREADY_OWNED followed by no ownership record does NOT grant Premium', () async {
      await entitlementManager.initialize();
      await provider.initialize();
      expect(entitlementManager.isPremiumActive, isFalse);

      await provider.purchasePremium();

      fakeIap.emitPurchases([
        createTestPurchaseDetails(
          productID: premiumLifetimeProductId,
          status: PurchaseStatus.error,
          error: IAPError(
            source: 'google_play',
            code: '7',
            message: 'item_already_owned',
          ),
        ),
      ]);
      await pumpEventQueue();

      // Wait for restore timeout
      await Future<void>.delayed(const Duration(milliseconds: 70));
      await pumpEventQueue();

      expect(entitlementManager.isPremiumActive, isFalse);
      expect(provider.currentState.status, equals(PurchaseActionStatus.error));
      expect(provider.currentState.errorMessage, contains('Unable to confirm previous purchases'));
    });

    test('26. App resume reconciles ownership if store is available and Premium is not active', () async {
      await entitlementManager.initialize();
      fakeIap.isAvailableResult = true;
      await provider.initialize();

      // Wait for startup background reconciliation to complete/timeout
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await pumpEventQueue();

      fakeIap.restorePurchasesCalled = false;

      // Simulate App Resume
      await provider.onAppResume();
      expect(fakeIap.restorePurchasesCalled, isTrue);

      // If user is already premium, resume does NOT trigger unnecessary reconciliation
      final premiumEntitlement = PremiumEntitlement.active(
        productId: premiumLifetimeProductId,
        storeSource: StoreSource.google,
        transactionReference: 'owned_id',
      );
      await entitlementManager.updateEntitlement(premiumEntitlement);
      expect(entitlementManager.isPremiumActive, isTrue);

      fakeIap.restorePurchasesCalled = false;
      await provider.onAppResume();
      expect(fakeIap.restorePurchasesCalled, isFalse);
    });

    test('27. Billing unavailable during startup and recovered on resume', () async {
      await entitlementManager.initialize();
      fakeIap.isAvailableResult = false;
      await provider.initialize();
      expect(provider.isAvailable, isFalse);
      expect(provider.productDetails, isNull);

      fakeIap.isAvailableResult = true;
      await provider.onAppResume();
      expect(provider.isAvailable, isTrue);
      expect(provider.productDetails, isNotNull);
    });

    test('28. Concurrent restore requests while restoring are rejected without resetting state', () async {
      await entitlementManager.initialize();
      await provider.initialize();

      final firstResult = await provider.restorePurchases();
      expect(firstResult, isTrue);
      expect(provider.currentState.status, equals(PurchaseActionStatus.restoring));

      final secondResult = await provider.restorePurchases();
      expect(secondResult, isFalse);
      expect(provider.currentState.status, equals(PurchaseActionStatus.restoring));
    });

    test('29. Duplicate and reordered purchase-stream events are idempotent and do not corrupt state', () async {
      await entitlementManager.initialize();
      await provider.initialize();

      final purchase1 = createTestPurchaseDetails(
        productID: premiumLifetimeProductId,
        status: PurchaseStatus.purchased,
        purchaseID: 'order_duplicate_test',
      );

      fakeIap.emitPurchases([purchase1]);
      await pumpEventQueue();
      expect(entitlementManager.isPremiumActive, isTrue);
      expect(provider.currentState.status, equals(PurchaseActionStatus.success));

      fakeIap.emitPurchases([purchase1]);
      await pumpEventQueue();
      expect(entitlementManager.isPremiumActive, isTrue);
      expect(provider.currentState.status, equals(PurchaseActionStatus.success));
    });

    test('30. Disposal during pending async reconciliation cleans up safely without leaks', () async {
      await entitlementManager.initialize();
      await provider.initialize();

      unawaited(provider.restorePurchases());
      expect(provider.currentState.status, equals(PurchaseActionStatus.restoring));

      expect(() => provider.dispose(), returnsNormally);

      expect(
        () => fakeIap.emitPurchases([
          createTestPurchaseDetails(
            productID: premiumLifetimeProductId,
            status: PurchaseStatus.restored,
          ),
        ]),
        returnsNormally,
      );
    });

    test('31. Completes pending purchase in Play Store on error or cancellation', () async {
      await entitlementManager.initialize();
      await provider.initialize();

      final canceledPurchase = createTestPurchaseDetails(
        productID: premiumLifetimeProductId,
        status: PurchaseStatus.canceled,
        purchaseID: 'canceled_tx_complete_test',
        pendingCompletePurchase: true,
      );
      fakeIap.emitPurchases([canceledPurchase]);
      await pumpEventQueue();

      expect(fakeIap.completedPurchases, contains(canceledPurchase));
    });

    test('32. Calling initialize() multiple times is idempotent and does not register duplicate observers', () async {
      await entitlementManager.initialize();
      await provider.initialize();
      await provider.initialize();
      await provider.initialize();

      await Future<void>.delayed(const Duration(milliseconds: 60));
      await pumpEventQueue();

      fakeIap.restorePurchasesCalled = false;

      // Dispatch lifecycle resume event via didChangeAppLifecycleState
      provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();

      expect(fakeIap.restorePurchasesCalled, isTrue);

      fakeIap.restorePurchasesCalled = false;
      fakeIap.emitPurchases([
        createTestPurchaseDetails(
          productID: premiumLifetimeProductId,
          status: PurchaseStatus.restored,
          purchaseID: 'tx_multi_init',
        ),
      ]);
      await pumpEventQueue();

      expect(entitlementManager.isPremiumActive, isTrue);
      expect(fakeIap.completedPurchases.where((p) => p.purchaseID == 'tx_multi_init').length, equals(1));
    });

    test('33. didChangeAppLifecycleState(AppLifecycleState.resumed) triggers ownership reconciliation when un-entitled', () async {
      await entitlementManager.initialize();
      await provider.initialize();

      await Future<void>.delayed(const Duration(milliseconds: 60));
      await pumpEventQueue();

      fakeIap.restorePurchasesCalled = false;

      // Send OS lifecycle resumed state
      provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();

      expect(fakeIap.restorePurchasesCalled, isTrue);

      // Non-resumed states (paused, inactive, hidden) must NOT trigger reconciliation
      fakeIap.restorePurchasesCalled = false;
      provider.didChangeAppLifecycleState(AppLifecycleState.paused);
      provider.didChangeAppLifecycleState(AppLifecycleState.inactive);
      provider.didChangeAppLifecycleState(AppLifecycleState.hidden);
      await pumpEventQueue();

      expect(fakeIap.restorePurchasesCalled, isFalse);
    });

    test('34. Disposal unregisters lifecycle observation and suppresses post-disposal lifecycle events', () async {
      await entitlementManager.initialize();
      await provider.initialize();

      await Future<void>.delayed(const Duration(milliseconds: 60));
      await pumpEventQueue();

      provider.dispose();
      fakeIap.restorePurchasesCalled = false;

      // Dispatch lifecycle resumed to disposed provider
      provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();

      // Disposed provider must ignore resume events
      expect(fakeIap.restorePurchasesCalled, isFalse);
    });

    test('35. Initialization failure followed by retry does not duplicate observers or purchase-stream subscriptions', () async {
      await entitlementManager.initialize();

      // First init fails due to store unavailable
      fakeIap.isAvailableResult = false;
      await provider.initialize();
      expect(provider.isAvailable, isFalse);

      // Second init succeeds after store recovery
      fakeIap.isAvailableResult = true;
      await provider.initialize();
      expect(provider.isAvailable, isTrue);

      fakeIap.emitPurchases([
        createTestPurchaseDetails(
          productID: premiumLifetimeProductId,
          status: PurchaseStatus.restored,
          purchaseID: 'retry_test_order',
        ),
      ]);
      await pumpEventQueue();

      expect(entitlementManager.isPremiumActive, isTrue);
      // Ensure completion was called exactly once, confirming no duplicate stream listeners
      expect(
        fakeIap.completedPurchases.where((p) => p.purchaseID == 'retry_test_order').length,
        equals(1),
      );
    });

    test('36. Startup with valid cached entitlement works offline when billing is unavailable', () async {
      const secureStorage = FlutterSecureStorage();
      final preExistingEntitlement = PremiumEntitlement.active(
        productId: premiumLifetimeProductId,
        storeSource: StoreSource.google,
        transactionReference: 'offline_order_123',
      );
      await secureStorage.write(
        key: PremiumEntitlementManager.keyCachedEntitlement,
        value: jsonEncode(preExistingEntitlement.toJson()),
      );

      await entitlementManager.initialize();
      expect(entitlementManager.isPremiumActive, isTrue);

      fakeIap.isAvailableResult = false;
      await provider.initialize();
      expect(provider.isAvailable, isFalse);

      expect(entitlementManager.isPremiumActive, isTrue);
      expect(fakeIap.restorePurchasesCalled, isFalse);
    });

    test('37. Device-wide entitlement policy: entitlement persists across simulated user session changes', () async {
      await entitlementManager.initialize();
      await provider.initialize();

      final purchase = createTestPurchaseDetails(
        productID: premiumLifetimeProductId,
        status: PurchaseStatus.purchased,
        purchaseID: 'session1_tx_456',
      );
      fakeIap.emitPurchases([purchase]);
      await pumpEventQueue();

      expect(entitlementManager.isPremiumActive, isTrue);

      // Simulate user sign-out and sign-in of another user session
      final session2EntitlementManager = PremiumEntitlementManager();
      await session2EntitlementManager.initialize();

      // Under the device-wide policy, Session 2 inherits the valid device-wide lifetime entitlement
      expect(session2EntitlementManager.isPremiumActive, isTrue);
      expect(
        session2EntitlementManager.authoritativeEntitlement.transactionReference,
        equals('session1_tx_456'),
      );
      session2EntitlementManager.dispose();
    });
  });
}
