import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:quick_notes/premium/premium.dart';

/// Test double for [InAppPurchase] plugin
class Bug002FakeInAppPurchase implements InAppPurchase {
  bool isAvailableResult = true;
  List<ProductDetails> productsToReturn = [];
  bool completePurchaseThrows = false;
  List<PurchaseDetails> completedPurchases = [];
  bool restorePurchasesCalled = false;

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
    return ProductDetailsResponse(
      productDetails: productsToReturn,
      notFoundIDs: [],
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async => true;

  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) async => false;

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restorePurchasesCalled = true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    if (completePurchaseThrows) {
      throw Exception('Store network timeout during transaction acknowledgement');
    }
    completedPurchases.add(purchase);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Controllable in-memory storage double supporting simulated failures
class ControllableSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _data = {};
  bool failNextWrite = false;
  bool failAllWrites = false;
  final Set<String> failKeys = <String>{};

  ControllableSecureStorage([Map<String, String>? initial]) {
    if (initial != null) {
      _data.addAll(initial);
    }
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (failNextWrite || failAllWrites || failKeys.contains(key)) {
      failNextWrite = false;
      throw Exception('Simulated secure storage write failure (disk full / permission denied)');
    }
    if (value != null) {
      _data[key] = value;
    } else {
      _data.remove(key);
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _data[key];

  @override
  Future<bool> containsKey({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _data.containsKey(key);

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.remove(key);
  }

  @override
  Future<void> deleteAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.clear();
  }

  @override
  Future<Map<String, String>> readAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => Map.unmodifiable(_data);
}

/// Helper to create fake [PurchaseDetails]
PurchaseDetails testPurchase({
  required String productID,
  required PurchaseStatus status,
  String purchaseID = 'tx_default_123',
  String transactionDate = '2026-10-27T12:00:00Z',
  bool pendingCompletePurchase = true,
  IAPError? error,
}) {
  final purchase = PurchaseDetails(
    purchaseID: purchaseID,
    productID: productID,
    verificationData: PurchaseVerificationData(
      localVerificationData: 'local_$purchaseID',
      serverVerificationData: 'server_$purchaseID',
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

  group('BUG-002 Phase 1: Purchase-Flow Correctness & Reliability Tests', () {
    late Bug002FakeInAppPurchase fakeIap;
    late ControllableSecureStorage storage;
    late PremiumEntitlementManager entitlementManager;
    late InAppPurchaseProvider provider;

    setUp(() async {
      fakeIap = Bug002FakeInAppPurchase();
      storage = ControllableSecureStorage();
      SharedPreferences.setMockInitialValues({});

      fakeIap.productsToReturn = [
        ProductDetails(
          id: premiumLifetimeProductId,
          title: 'QuickNotes Premium Lifetime',
          description: 'Lifetime access to all premium features',
          price: r'$4.99',
          rawPrice: 4.99,
          currencyCode: 'USD',
        ),
      ];

      entitlementManager = PremiumEntitlementManager(secureStorage: storage);
      await entitlementManager.initialize();

      provider = InAppPurchaseProvider(
        inAppPurchase: fakeIap,
        entitlementManager: entitlementManager,
        secureStorage: storage,
        restoreTimeoutDuration: const Duration(milliseconds: 50),
      );
      await provider.initialize();
    });

    tearDown(() {
      provider.dispose();
      entitlementManager.dispose();
    });

    test('1. Verified purchase + successful persistence → Premium active and one success event', () async {
      final stateUpdates = <PurchaseStateUpdate>[];
      final sub = provider.stateStream.listen(stateUpdates.add);

      expect(entitlementManager.isPremiumActive, isFalse);

      final purchase = testPurchase(
        productID: premiumLifetimeProductId,
        status: PurchaseStatus.purchased,
        purchaseID: 'tx_success_001',
      );

      fakeIap.emitPurchases([purchase]);
      await pumpEventQueue();

      // Entitlement must be active and correctly configured
      expect(entitlementManager.isPremiumActive, isTrue);
      expect(entitlementManager.currentEntitlement.transactionReference, equals('tx_success_001'));

      // Provider current state must be success
      expect(provider.currentState.status, equals(PurchaseActionStatus.success));

      // Exactly ONE success event emitted
      final successEvents = stateUpdates.where((s) => s.status == PurchaseActionStatus.success).toList();
      expect(successEvents.length, equals(1));

      // Transaction must be acknowledged/completed in store
      expect(fakeIap.completedPurchases, contains(purchase));

      await sub.cancel();
    });

    test('2. Definitively rejected verification → no new entitlement and no success event', () async {
      final stateUpdates = <PurchaseStateUpdate>[];
      final sub = provider.stateStream.listen(stateUpdates.add);

      final invalidPurchase = testPurchase(
        productID: 'unauthorized_hacked_product_id',
        status: PurchaseStatus.purchased,
        purchaseID: 'tx_rejected_002',
      );

      fakeIap.emitPurchases([invalidPurchase]);
      await pumpEventQueue();

      expect(entitlementManager.isPremiumActive, isFalse);
      expect(provider.currentState.status, equals(PurchaseActionStatus.error));
      expect(stateUpdates.any((s) => s.status == PurchaseActionStatus.success), isFalse);

      await sub.cancel();
    });

    test('3. Temporary verification failure → recoverable state, no success event, uncompleted transaction', () async {
      provider.dispose();

      final stateUpdates = <PurchaseStateUpdate>[];
      final mockFailingVerifier = _TemporaryFailingPurchaseVerifier();
      final failingProvider = InAppPurchaseProvider(
        inAppPurchase: fakeIap,
        verifier: mockFailingVerifier,
        entitlementManager: entitlementManager,
        secureStorage: storage,
      );
      final sub = failingProvider.stateStream.listen(stateUpdates.add);
      await failingProvider.initialize();

      final purchase = testPurchase(
        productID: premiumLifetimeProductId,
        status: PurchaseStatus.purchased,
        purchaseID: 'tx_network_fail_003',
        pendingCompletePurchase: true,
      );

      fakeIap.emitPurchases([purchase]);
      await pumpEventQueue();

      // Must NOT grant entitlement
      expect(entitlementManager.isPremiumActive, isFalse);
      // Must NOT emit success
      expect(failingProvider.currentState.status, equals(PurchaseActionStatus.error));
      expect(stateUpdates.any((s) => s.status == PurchaseActionStatus.success), isFalse);

      // CRITICAL: Must NOT complete the transaction prematurely so Google Play can redeliver it on retry!
      expect(fakeIap.completedPurchases.contains(purchase), isFalse);

      failingProvider.dispose();
      await sub.cancel();
    });

    test('4. Entitlement persistence failure → no success event and safe retry behavior', () async {
      final stateUpdates = <PurchaseStateUpdate>[];
      final sub = provider.stateStream.listen(stateUpdates.add);

      // Inject simulated storage failure
      storage.failAllWrites = true;

      final purchase = testPurchase(
        productID: premiumLifetimeProductId,
        status: PurchaseStatus.purchased,
        purchaseID: 'tx_persist_fail_004',
      );

      fakeIap.emitPurchases([purchase]);
      await pumpEventQueue();

      // Persistence failed: Premium must NOT be active
      expect(entitlementManager.isPremiumActive, isFalse);
      expect(provider.currentState.status, equals(PurchaseActionStatus.error));
      expect(provider.currentState.errorMessage, contains('Failed to safely record Premium'));
      expect(stateUpdates.any((s) => s.status == PurchaseActionStatus.success), isFalse);

      // Must NOT acknowledge in store while local persistence is failed
      expect(fakeIap.completedPurchases.contains(purchase), isFalse);

      // Now simulate storage recovery
      storage.failAllWrites = false;

      // Safe retry with same transaction
      fakeIap.emitPurchases([purchase]);
      await pumpEventQueue();

      // Retry succeeds cleanly
      expect(entitlementManager.isPremiumActive, isTrue);
      expect(provider.currentState.status, equals(PurchaseActionStatus.success));
      expect(fakeIap.completedPurchases, contains(purchase));

      await sub.cancel();
    });

    test('5. Duplicate callback during in-flight processing → one processing outcome', () async {
      provider.dispose();

      final stateUpdates = <PurchaseStateUpdate>[];
      final delayedVerifier = _DelayedPurchaseVerifier();
      final inFlightProvider = InAppPurchaseProvider(
        inAppPurchase: fakeIap,
        verifier: delayedVerifier,
        entitlementManager: entitlementManager,
        secureStorage: storage,
      );
      final sub = inFlightProvider.stateStream.listen(stateUpdates.add);
      await inFlightProvider.initialize();

      final purchase = testPurchase(
        productID: premiumLifetimeProductId,
        status: PurchaseStatus.purchased,
        purchaseID: 'tx_inflight_005',
      );

      // First emission starts async verification
      fakeIap.emitPurchases([purchase]);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Duplicate second emission arrives while first is still in-flight
      fakeIap.emitPurchases([purchase]);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Complete the pending verifier
      delayedVerifier.completer.complete(
        PremiumEntitlement.active(
          productId: premiumLifetimeProductId,
          transactionReference: 'tx_inflight_005',
        ),
      );
      await pumpEventQueue();

      // Entitlement is active
      expect(entitlementManager.isPremiumActive, isTrue);
      expect(inFlightProvider.currentState.status, equals(PurchaseActionStatus.success));

      // Verifier was called only once despite duplicate concurrent callbacks
      expect(delayedVerifier.callCount, equals(1));

      // Only one success state emitted
      final successEvents = stateUpdates.where((s) => s.status == PurchaseActionStatus.success).toList();
      expect(successEvents.length, equals(1));

      inFlightProvider.dispose();
      await sub.cancel();
    });

    test('6. Replayed callback after successful processing → no duplicate entitlement or success event', () async {
      final stateUpdates = <PurchaseStateUpdate>[];
      final sub = provider.stateStream.listen(stateUpdates.add);

      final purchase = testPurchase(
        productID: premiumLifetimeProductId,
        status: PurchaseStatus.purchased,
        purchaseID: 'tx_replay_006',
      );

      // Initial processing
      fakeIap.emitPurchases([purchase]);
      await pumpEventQueue();
      expect(entitlementManager.isPremiumActive, isTrue);
      expect(stateUpdates.where((s) => s.status == PurchaseActionStatus.success).length, equals(1));

      // Replay the exact same purchase callback
      fakeIap.emitPurchases([purchase]);
      await pumpEventQueue();

      // Must remain active
      expect(entitlementManager.isPremiumActive, isTrue);
      // Must NOT emit a second success celebration event
      expect(stateUpdates.where((s) => s.status == PurchaseActionStatus.success).length, equals(1));

      await sub.cancel();
    });

    test('7. Two distinct legitimate transactions for the same product → not incorrectly deduplicated solely by product ID', () async {
      final stateUpdates = <PurchaseStateUpdate>[];
      final sub = provider.stateStream.listen(stateUpdates.add);

      final purchaseA = testPurchase(
        productID: premiumLifetimeProductId,
        status: PurchaseStatus.purchased,
        purchaseID: 'order_A_007',
      );

      fakeIap.emitPurchases([purchaseA]);
      await pumpEventQueue();
      expect(entitlementManager.currentEntitlement.transactionReference, equals('order_A_007'));

      // A distinct legitimate transaction for the same product arrives later
      final purchaseB = testPurchase(
        productID: premiumLifetimeProductId,
        status: PurchaseStatus.purchased,
        purchaseID: 'order_B_007',
      );

      fakeIap.emitPurchases([purchaseB]);
      await pumpEventQueue();

      // Must process transaction B because transaction ID is distinct from A
      expect(entitlementManager.currentEntitlement.transactionReference, equals('order_B_007'));
      expect(fakeIap.completedPurchases, contains(purchaseB));

      await sub.cancel();
    });

    test('8. Pending purchase → no success event and entitlement remains inactive', () async {
      final stateUpdates = <PurchaseStateUpdate>[];
      final sub = provider.stateStream.listen(stateUpdates.add);

      final pendingPurchase = testPurchase(
        productID: premiumLifetimeProductId,
        status: PurchaseStatus.pending,
        purchaseID: 'tx_pending_008',
      );

      fakeIap.emitPurchases([pendingPurchase]);
      await pumpEventQueue();

      expect(entitlementManager.isPremiumActive, isFalse);
      expect(provider.currentState.status, equals(PurchaseActionStatus.pending));
      expect(stateUpdates.any((s) => s.status == PurchaseActionStatus.success), isFalse);

      await sub.cancel();
    });

    test('9. Cancelled purchase → no success event and entitlement remains inactive', () async {
      final stateUpdates = <PurchaseStateUpdate>[];
      final sub = provider.stateStream.listen(stateUpdates.add);

      final canceledPurchase = testPurchase(
        productID: premiumLifetimeProductId,
        status: PurchaseStatus.canceled,
        purchaseID: 'tx_canceled_009',
      );

      fakeIap.emitPurchases([canceledPurchase]);
      await pumpEventQueue();

      expect(entitlementManager.isPremiumActive, isFalse);
      expect(provider.currentState.status, equals(PurchaseActionStatus.cancelled));
      expect(stateUpdates.any((s) => s.status == PurchaseActionStatus.success), isFalse);

      await sub.cancel();
    });

    test('10. Billing error → no success event and entitlement remains inactive', () async {
      final stateUpdates = <PurchaseStateUpdate>[];
      final sub = provider.stateStream.listen(stateUpdates.add);

      final errorPurchase = testPurchase(
        productID: premiumLifetimeProductId,
        status: PurchaseStatus.error,
        purchaseID: 'tx_error_010',
        error: IAPError(source: 'google_play', code: 'billing_unavailable', message: 'Network error'),
      );

      fakeIap.emitPurchases([errorPurchase]);
      await pumpEventQueue();

      expect(entitlementManager.isPremiumActive, isFalse);
      expect(provider.currentState.status, equals(PurchaseActionStatus.error));
      expect(stateUpdates.any((s) => s.status == PurchaseActionStatus.success), isFalse);

      await sub.cancel();
    });

    test('11. Restore of an existing entitlement → correct Premium state without duplicate celebration', () async {
      // Pre-activate entitlement
      await entitlementManager.updateEntitlement(
        PremiumEntitlement.active(
          productId: premiumLifetimeProductId,
          transactionReference: 'existing_tx_011',
        ),
      );
      expect(entitlementManager.isPremiumActive, isTrue);

      final stateUpdates = <PurchaseStateUpdate>[];
      final sub = provider.stateStream.listen(stateUpdates.add);

      // Now restore occurs for existing active entitlement
      final restoredPurchase = testPurchase(
        productID: premiumLifetimeProductId,
        status: PurchaseStatus.restored,
        purchaseID: 'existing_tx_011',
      );

      fakeIap.emitPurchases([restoredPurchase]);
      await pumpEventQueue();

      // Entitlement remains active
      expect(entitlementManager.isPremiumActive, isTrue);
      // Must NOT emit a new purchase celebration success event
      expect(stateUpdates.any((s) => s.status == PurchaseActionStatus.success), isFalse);
      expect(provider.currentState.status, isNot(equals(PurchaseActionStatus.success)));

      await sub.cancel();
    });

    test('12. App restart after successful activation → entitlement remains active without replaying a stale success event', () async {
      // Persist active entitlement in secure storage (simulating previous app session)
      final existingEntitlement = PremiumEntitlement.active(
        productId: premiumLifetimeProductId,
        transactionReference: 'active_session_012',
      );
      await storage.write(
        key: PremiumEntitlementManager.keyCachedEntitlement,
        value: jsonEncode(existingEntitlement.toJson()),
      );
      await storage.write(
        key: InAppPurchaseProvider.keyProcessedTransactions,
        value: jsonEncode(['active_session_012']),
      );

      // Restart: Instantiate brand new manager and provider
      final restartedManager = PremiumEntitlementManager(secureStorage: storage);
      await restartedManager.initialize();
      expect(restartedManager.isPremiumActive, isTrue);

      final restartedProvider = InAppPurchaseProvider(
        inAppPurchase: fakeIap,
        entitlementManager: restartedManager,
        secureStorage: storage,
      );

      final stateUpdates = <PurchaseStateUpdate>[];
      final sub = restartedProvider.stateStream.listen(stateUpdates.add);

      await restartedProvider.initialize();

      // Initial state must be idle (transient UI event not replayed)
      expect(restartedProvider.currentState.status, equals(PurchaseActionStatus.idle));
      expect(stateUpdates.any((s) => s.status == PurchaseActionStatus.success), isFalse);

      // If store replays purchase on startup, deduplication suppresses success
      fakeIap.emitPurchases([
        testPurchase(
          productID: premiumLifetimeProductId,
          status: PurchaseStatus.purchased,
          purchaseID: 'active_session_012',
        ),
      ]);
      await pumpEventQueue();

      expect(restartedManager.isPremiumActive, isTrue);
      expect(stateUpdates.any((s) => s.status == PurchaseActionStatus.success), isFalse);

      restartedProvider.dispose();
      restartedManager.dispose();
      await sub.cancel();
    });

    test('13. Transaction completion/acknowledgement failure → safe, retryable handling consistent with plugin', () async {
      fakeIap.completePurchaseThrows = true;

      final purchase = testPurchase(
        productID: premiumLifetimeProductId,
        status: PurchaseStatus.purchased,
        purchaseID: 'tx_ack_fail_013',
      );

      // Must not throw an unhandled exception
      fakeIap.emitPurchases([purchase]);
      await pumpEventQueue();

      // Entitlement is safely active locally despite store acknowledgement failure
      expect(entitlementManager.isPremiumActive, isTrue);
      expect(provider.currentState.status, equals(PurchaseActionStatus.success));

      // Reset failure for retry
      fakeIap.completePurchaseThrows = false;

      // Re-delivery of uncompleted transaction should acknowledge cleanly
      fakeIap.emitPurchases([purchase]);
      await pumpEventQueue();

      expect(fakeIap.completedPurchases, contains(purchase));
    });

    test('14. Existing Premium feature-gating behavior → unchanged and correct', () async {
      final freeAccess = DefaultFeatureAccess(entitlementManager);
      expect(freeAccess.canAccess(PremiumFeature.darkMode), isFalse);
      expect(freeAccess.canAccess(PremiumFeature.folderCustomization), isFalse);
      expect(freeAccess.canAccess(PremiumFeature.widgets), isFalse);

      // Purchase unlock
      final purchase = testPurchase(
        productID: premiumLifetimeProductId,
        status: PurchaseStatus.purchased,
        purchaseID: 'tx_gating_014',
      );
      fakeIap.emitPurchases([purchase]);
      await pumpEventQueue();

      // Gating reflects active state immediately
      final premiumAccess = DefaultFeatureAccess(entitlementManager);
      expect(premiumAccess.canAccess(PremiumFeature.darkMode), isTrue);
      expect(premiumAccess.canAccess(PremiumFeature.folderCustomization), isTrue);
      expect(premiumAccess.canAccess(PremiumFeature.widgets), isTrue);
    });

    test('15. Store completion succeeds but durable transaction history persistence fails → entitlement remains active and success is emitted', () async {
      final stateUpdates = <PurchaseStateUpdate>[];
      final sub = provider.stateStream.listen(stateUpdates.add);

      // Fail writing the transaction history key
      storage.failKeys.add(InAppPurchaseProvider.keyProcessedTransactions);

      final purchase = testPurchase(
        productID: premiumLifetimeProductId,
        status: PurchaseStatus.purchased,
        purchaseID: 'tx_history_fail_015',
      );

      fakeIap.emitPurchases([purchase]);
      await pumpEventQueue();

      // Entitlement must be active
      expect(entitlementManager.isPremiumActive, isTrue);
      // Store completion must have succeeded
      expect(fakeIap.completedPurchases, contains(purchase));
      // Success must be emitted to the user
      expect(provider.currentState.status, equals(PurchaseActionStatus.success));

      await sub.cancel();
    });

    test('16. Unidentified transaction fallback produces stable identity and avoids duplicate processing', () async {
      final stateUpdates = <PurchaseStateUpdate>[];
      final sub = provider.stateStream.listen(stateUpdates.add);

      // Create purchase with missing ID, date, and verification tokens
      final missingIdPurchase = PurchaseDetails(
        purchaseID: '',
        productID: premiumLifetimeProductId,
        verificationData: PurchaseVerificationData(
          localVerificationData: '',
          serverVerificationData: '',
          source: 'test',
        ),
        transactionDate: '',
        status: PurchaseStatus.purchased,
      );
      missingIdPurchase.pendingCompletePurchase = true;

      fakeIap.emitPurchases([missingIdPurchase]);
      await pumpEventQueue();

      expect(entitlementManager.isPremiumActive, isTrue);
      expect(provider.currentState.status, equals(PurchaseActionStatus.success));
      final assignedTxId = provider.currentState.transactionId;
      expect(assignedTxId, isNotNull);
      expect(assignedTxId!.startsWith('tx_unresolved_'), isTrue);

      // Re-emitting the same PurchaseDetails instance uses the stable cached identity
      fakeIap.emitPurchases([missingIdPurchase]);
      await pumpEventQueue();

      // Exactly 1 success event emitted (deduplicated by stable identity)
      final successEvents = stateUpdates.where((s) => s.status == PurchaseActionStatus.success).toList();
      expect(successEvents.length, equals(1));

      await sub.cancel();
    });
  });
}

class _TemporaryFailingPurchaseVerifier implements PurchaseVerifier {
  @override
  Future<PremiumEntitlement?> verifyPurchase(PurchaseDetails purchaseDetails) async {
    // Return null simulating network timeout / temporary server failure
    return null;
  }
}

class _DelayedPurchaseVerifier implements PurchaseVerifier {
  final Completer<PremiumEntitlement?> completer = Completer<PremiumEntitlement?>();
  int callCount = 0;

  @override
  Future<PremiumEntitlement?> verifyPurchase(PurchaseDetails purchaseDetails) async {
    callCount++;
    return completer.future;
  }
}
