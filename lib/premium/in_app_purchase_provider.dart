import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'premium_entitlement.dart';
import 'premium_entitlement_manager.dart';
import 'premium_product.dart';
import 'purchase_provider_interface.dart';
import 'purchase_verifier.dart';
import 'remote_purchase_verifier.dart';

/// InAppPurchaseProvider — Production implementation of [PurchaseProvider] bridging
/// Flutter's `in_app_purchase` platform plugin with Quick Notes entitlement architecture.
///
/// Responsibilities:
/// - Connects to platform store (Google Play Billing / Apple StoreKit)
/// - Queries authoritative non-consumable product details and localized pricing
/// - Dispatches non-consumable purchase requests
/// - Dispatches purchase restoration requests
/// - Verifies incoming transactions via [PurchaseVerifier]
/// - Authoritatively updates [PremiumEntitlementManager] upon verified completion
/// - Handles cancellations, pending states, and store errors cleanly without
///   disturbing pre-existing entitlements
class InAppPurchaseProvider with WidgetsBindingObserver implements PurchaseProvider {
  static const String keyProcessedTransactions = 'premium_processed_transactions';

  final InAppPurchase _iap;
  final PurchaseVerifier _verifier;
  final PremiumEntitlementManager? _entitlementManager;
  final FlutterSecureStorage _secureStorage;

  final Duration _restoreTimeoutDuration;

  bool _isAvailable = false;
  bool _isUserRestoring = false;
  bool _isBackgroundReconciling = false;
  bool _isObserverRegistered = false;
  bool _isDisposed = false;
  ProductDetails? _productDetails;
  PurchaseStateUpdate _currentState = const PurchaseStateUpdate.idle();

  final Set<String> _inFlightTransactionIds = <String>{};
  final Set<String> _processedTransactionIds = <String>{};
  final Expando<String> _unidentifiedTransactionIds = Expando<String>();

  final StreamController<PurchaseStateUpdate> _stateController =
      StreamController<PurchaseStateUpdate>.broadcast();
  final StreamController<PremiumEntitlement> _entitlementController =
      StreamController<PremiumEntitlement>.broadcast();

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  Timer? _restoreTimeoutTimer;
  int _restoreOperationCounter = 0;

  InAppPurchaseProvider({
    InAppPurchase? inAppPurchase,
    PurchaseVerifier? verifier,
    PremiumEntitlementManager? entitlementManager,
    FlutterSecureStorage? secureStorage,
    Duration restoreTimeoutDuration = const Duration(seconds: 5),
  })  : _iap = inAppPurchase ?? InAppPurchase.instance,
        _verifier = verifier ??
            (entitlementManager != null
                ? RemotePurchaseVerifier(entitlementManager: entitlementManager)
                : const DefaultPurchaseVerifier()),
        _entitlementManager = entitlementManager,
        _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _restoreTimeoutDuration = restoreTimeoutDuration;

  @override
  StoreSource get storeSource {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return StoreSource.google;
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return StoreSource.apple;
    }
    return StoreSource.unknown;
  }

  @override
  bool get isAvailable => _isAvailable;

  @override
  ProductDetails? get productDetails => _productDetails;

  @override
  String? get formattedPrice => _productDetails?.price;

  @override
  PurchaseStateUpdate get currentState => _currentState;

  @override
  Stream<PurchaseStateUpdate> get stateStream => _stateController.stream;

  @override
  Stream<PremiumEntitlement> get entitlementStream =>
      _entitlementController.stream;

  @override
  Future<bool> isBillingAvailable() async {
    try {
      _isAvailable = await _iap.isAvailable();
      return _isAvailable;
    } catch (e) {
      _isAvailable = false;
      return false;
    }
  }

  @override
  Future<void> initialize() async {
    // 1. Check store connection
    _isAvailable = await isBillingAvailable();
    if (kDebugMode) {
      print('PURCHASE PROVIDER [Init]: Store available: $_isAvailable (${storeSource.name})');
    }

    // Load persisted processed transactions for durable deduplication
    try {
      final rawProcessed = await _secureStorage.read(key: keyProcessedTransactions);
      if (rawProcessed != null && rawProcessed.isNotEmpty) {
        final dynamic decoded = jsonDecode(rawProcessed);
        if (decoded is List) {
          _processedTransactionIds.addAll(decoded.cast<String>());
        }
      }
    } catch (_) {}

    final activeTx = _entitlementManager?.authoritativeEntitlement.transactionReference;
    if (activeTx != null && activeTx.isNotEmpty) {
      _processedTransactionIds.add(activeTx);
    }

    // Register lifecycle observer for automatic resume reconciliation (idempotent)
    if (!_isObserverRegistered && !_isDisposed) {
      try {
        WidgetsBinding.instance.addObserver(this);
        _isObserverRegistered = true;
      } catch (_) {}
    }

    // Ensure any previous subscription is cancelled to prevent duplicate listeners
    await _purchaseSubscription?.cancel();
    _purchaseSubscription = null;

    // 2. Subscribe to platform purchase update stream
    _purchaseSubscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _purchaseSubscription?.cancel(),
      onError: _onPurchaseStreamError,
    );

    // 3. Load product details if store is available
    if (_isAvailable) {
      await loadProductDetails();

      // 4. Background Ownership Reconciliation:
      // If store is available and current entitlement is not active or requires re-verification or lease expired,
      // perform silent background reconciliation to recover any previously owned lifetime purchase.
      if (_entitlementManager != null &&
          (!_entitlementManager!.isPremiumActive ||
              _entitlementManager!.requiresReverification ||
              _entitlementManager!.isLeaseExpired)) {
        unawaited(reconcilePurchases(isUserTriggered: false));
      }
    }
  }

  @override
  Future<ProductDetails?> loadProductDetails() async {
    _updateState(
      PurchaseStateUpdate(
        status: PurchaseActionStatus.loadingProduct,
        productDetails: _productDetails,
      ),
    );

    try {
      final ProductDetailsResponse response =
          await _iap.queryProductDetails(kAllProductIds);

      if (response.error != null) {
        if (kDebugMode) {
          print(
            'PURCHASE PROVIDER [Error]: Query products failed: ${response.error!.message}',
          );
        }
        _updateState(
          PurchaseStateUpdate(
            status: PurchaseActionStatus.error,
            errorMessage: 'Unable to load store product details.',
            productDetails: _productDetails,
          ),
        );
        return null;
      }

      if (response.productDetails.isNotEmpty) {
        for (final product in response.productDetails) {
          if (product.id == premiumLifetimeProductId) {
            _productDetails = product;
            if (kDebugMode) {
              print(
                'PURCHASE PROVIDER [Loaded]: Product "${product.id}" loaded with price "${product.price}".',
              );
            }
            break;
          }
        }
      }

      _updateState(
        PurchaseStateUpdate(
          status: PurchaseActionStatus.idle,
          productDetails: _productDetails,
        ),
      );
      return _productDetails;
    } catch (e) {
      _updateState(
        PurchaseStateUpdate(
          status: PurchaseActionStatus.error,
          errorMessage: 'Store connection error while querying products.',
          productDetails: _productDetails,
        ),
      );
      return null;
    }
  }

  @override
  Future<bool> purchasePremium() async {
    // If user already owns verified active premium, avoid triggering duplicate purchase flows
    if (_entitlementManager?.isPremiumActive == true) {
      if (kDebugMode) {
        print('PURCHASE PROVIDER [Purchase]: Premium is already active.');
      }
      return true;
    }

    // Prevent concurrent user operations
    if (_currentState.status == PurchaseActionStatus.purchasing ||
        _currentState.status == PurchaseActionStatus.restoring ||
        _isUserRestoring) {
      if (kDebugMode) {
        print('PURCHASE PROVIDER [Purchase]: Operation already in progress.');
      }
      return false;
    }

    // If silent background reconciliation is running, cancel its timeout and yield to the user's purchase action
    if (_isBackgroundReconciling) {
      _isBackgroundReconciling = false;
      _cancelRestoreTimeout();
    }

    if (!_isAvailable) {
      _isAvailable = await isBillingAvailable();
      if (!_isAvailable) {
        _updateState(
          const PurchaseStateUpdate(
            status: PurchaseActionStatus.error,
            errorMessage:
                'Store is currently unavailable. Please check your network or app store sign-in.',
          ),
        );
        return false;
      }
    }

    // Ensure product details are available
    if (_productDetails == null) {
      await loadProductDetails();
      if (_productDetails == null) {
        _updateState(
          const PurchaseStateUpdate(
            status: PurchaseActionStatus.error,
            errorMessage:
                'Premium product is not configured in the platform store.',
          ),
        );
        return false;
      }
    }

    _updateState(
      PurchaseStateUpdate(
        status: PurchaseActionStatus.purchasing,
        productDetails: _productDetails,
      ),
    );

    final purchaseParam = PurchaseParam(productDetails: _productDetails!);

    try {
      final bool initiated = await _iap.buyNonConsumable(
        purchaseParam: purchaseParam,
      );
      if (!initiated) {
        _updateState(
          PurchaseStateUpdate(
            status: PurchaseActionStatus.error,
            errorMessage: 'Could not initiate purchase with the store.',
            productDetails: _productDetails,
          ),
        );
        return false;
      }
      return true;
    } catch (e) {
      _updateState(
        PurchaseStateUpdate(
          status: PurchaseActionStatus.error,
          errorMessage: 'An error occurred while launching store purchase.',
          productDetails: _productDetails,
        ),
      );
      return false;
    }
  }

  @override
  Future<bool> restorePurchases() async {
    return reconcilePurchases(isUserTriggered: true);
  }

  @override
  Future<bool> reconcilePurchases({bool isUserTriggered = false}) async {
    // If a purchase action is active and this is NOT user-triggered, do not interrupt
    if (!isUserTriggered && _currentState.status == PurchaseActionStatus.purchasing) {
      if (kDebugMode) {
        print(
          'PURCHASE PROVIDER [Reconcile]: Purchase action in progress, ignoring background call.',
        );
      }
      return false;
    }

    if (isUserTriggered) {
      // User tapped Restore or recovery from ITEM_ALREADY_OWNED:
      // If already user-restoring, do not allow duplicate concurrent user restore
      if (_isUserRestoring || _currentState.status == PurchaseActionStatus.restoring) {
        if (kDebugMode) {
          print(
            'PURCHASE PROVIDER [Restore]: Restore operation already in progress.',
          );
        }
        return false;
      }
      // If silent background reconciliation was running, promote/cancel it
      if (_isBackgroundReconciling) {
        _isBackgroundReconciling = false;
        _cancelRestoreTimeout();
      }
      _isUserRestoring = true;
    } else {
      // Silent background reconciliation:
      // If user is restoring or background reconciliation is already running, skip
      if (_isUserRestoring || _isBackgroundReconciling) {
        return false;
      }
      _isBackgroundReconciling = true;
    }

    if (!_isAvailable) {
      _isAvailable = await isBillingAvailable();
      if (!_isAvailable) {
        if (isUserTriggered) {
          _isUserRestoring = false;
          _updateState(
            const PurchaseStateUpdate(
              status: PurchaseActionStatus.error,
              errorMessage:
                  'Store is currently unavailable. Please verify your connection.',
            ),
          );
        } else {
          _isBackgroundReconciling = false;
        }
        return false;
      }
    }

    _cancelRestoreTimeout();
    final currentOpId = ++_restoreOperationCounter;

    if (isUserTriggered) {
      _updateState(
        PurchaseStateUpdate(
          status: PurchaseActionStatus.restoring,
          productDetails: _productDetails,
        ),
      );
    }

    // Bounded timeout for restoration confirmation
    _restoreTimeoutTimer = Timer(_restoreTimeoutDuration, () {
      _handleRestoreTimeout(currentOpId, isUserTriggered: isUserTriggered);
    });

    try {
      await _iap.restorePurchases();
      // Restoration results arrive asynchronously over purchaseStream
      return true;
    } catch (e) {
      if (isUserTriggered) {
        _isUserRestoring = false;
      } else {
        _isBackgroundReconciling = false;
      }
      _cancelRestoreTimeout();
      if (isUserTriggered) {
        _updateState(
          PurchaseStateUpdate(
            status: PurchaseActionStatus.error,
            errorMessage: 'Failed to restore previous purchases from store.',
            productDetails: _productDetails,
          ),
        );
      }
      return false;
    }
  }

  void _cancelRestoreTimeout() {
    _restoreTimeoutTimer?.cancel();
    _restoreTimeoutTimer = null;
  }

  void _handleRestoreTimeout(int operationId, {required bool isUserTriggered}) {
    if (_restoreOperationCounter != operationId) return;
    _cancelRestoreTimeout();

    if (isUserTriggered) {
      _isUserRestoring = false;
      if (kDebugMode) {
        print(
          'PURCHASE PROVIDER [Restore]: Restore operation timed out waiting for store confirmation.',
        );
      }
      if (_currentState.status == PurchaseActionStatus.restoring) {
        _updateState(
          PurchaseStateUpdate(
            status: PurchaseActionStatus.error,
            errorMessage:
                'Unable to confirm previous purchases from the store. If you previously purchased Premium, please check your network and Google Play account, then try again.',
            productDetails: _productDetails,
          ),
        );
      }
    } else {
      _isBackgroundReconciling = false;
      if (kDebugMode) {
        print(
          'PURCHASE PROVIDER [Reconcile]: Silent background reconciliation timed out with no purchases returned.',
        );
      }
      if (_currentState.status == PurchaseActionStatus.restoring) {
        _updateState(
          PurchaseStateUpdate(
            status: PurchaseActionStatus.idle,
            productDetails: _productDetails,
          ),
        );
      }
    }
  }

  bool _isAlreadyOwnedError(IAPError? error) {
    if (error == null) return false;
    final code = error.code.toLowerCase();
    final message = error.message.toLowerCase();
    final details = (error.details?.toString() ?? '').toLowerCase();

    return code == '7' ||
        code.contains('already_owned') ||
        code.contains('alreadyowned') ||
        code.contains('item_already_owned') ||
        message.contains('already owned') ||
        message.contains('already own') ||
        message.contains('itemalreadyowned') ||
        message.contains('item_already_owned') ||
        details.contains('already owned') ||
        details.contains('already own');
  }

  String _resolveTransactionId(PurchaseDetails purchaseDetails) {
    final id = purchaseDetails.purchaseID;
    if (id != null && id.isNotEmpty) return id;
    final serverData = purchaseDetails.verificationData.serverVerificationData;
    if (serverData.isNotEmpty) {
      if (serverData.startsWith('{')) {
        try {
          final Map<String, dynamic> parsed = jsonDecode(serverData);
          if (parsed.containsKey('purchaseToken')) {
            return parsed['purchaseToken'] as String;
          }
          if (parsed.containsKey('orderId')) {
            return parsed['orderId'] as String;
          }
        } catch (_) {}
      }
      return serverData;
    }
    final localData = purchaseDetails.verificationData.localVerificationData;
    if (localData.isNotEmpty) return localData;
    final txDate = purchaseDetails.transactionDate;
    if (txDate != null && txDate.isNotEmpty) {
      return 'tx_${purchaseDetails.productID}_$txDate';
    }
    final cached = _unidentifiedTransactionIds[purchaseDetails];
    if (cached != null) return cached;
    final fallback =
        'tx_unresolved_${purchaseDetails.productID}_${identityHashCode(purchaseDetails)}';
    _unidentifiedTransactionIds[purchaseDetails] = fallback;
    return fallback;
  }

  Future<void> _recordProcessedTransaction(String txId) async {
    _processedTransactionIds.add(txId);
    try {
      await _secureStorage.write(
        key: keyProcessedTransactions,
        value: jsonEncode(_processedTransactionIds.toList()),
      );
    } catch (_) {}
  }

  Future<void> _onPurchaseUpdate(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final purchaseDetails in purchaseDetailsList) {
      final txId = _resolveTransactionId(purchaseDetails);

      if (kDebugMode) {
        print(
          'PURCHASE PROVIDER [Stream]: Received purchase: ID="${purchaseDetails.productID}", txId="$txId", status=${purchaseDetails.status.name}',
        );
      }

      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          _updateState(
            PurchaseStateUpdate(
              status: PurchaseActionStatus.pending,
              errorMessage:
                  'Your purchase is pending payment approval. Premium features will unlock once the payment is completed and verified.',
              productDetails: _productDetails,
              transactionId: txId,
            ),
          );
          break;

        case PurchaseStatus.canceled:
          _updateState(
            PurchaseStateUpdate(
              status: PurchaseActionStatus.cancelled,
              productDetails: _productDetails,
              transactionId: txId,
            ),
          );
          if (purchaseDetails.pendingCompletePurchase) {
            try {
              await _iap.completePurchase(purchaseDetails);
            } catch (_) {}
          }
          break;

        case PurchaseStatus.error:
          // Check for ITEM_ALREADY_OWNED (Code 7)
          if (_isAlreadyOwnedError(purchaseDetails.error)) {
            if (kDebugMode) {
              print(
                'PURCHASE PROVIDER [Already Owned]: Store reported item already owned. Reconciling ownership to verify authentic receipt.',
              );
            }
            if (purchaseDetails.pendingCompletePurchase) {
              try {
                await _iap.completePurchase(purchaseDetails);
              } catch (_) {}
            }
            // Trigger user-visible reconciliation to fetch and verify the authoritative purchase record.
            // Never grant entitlement directly from error code.
            await reconcilePurchases(isUserTriggered: true);
            break;
          }

          _updateState(
            PurchaseStateUpdate(
              status: PurchaseActionStatus.error,
              errorMessage: purchaseDetails.error?.message ??
                  'Purchase could not be completed by the store.',
              productDetails: _productDetails,
              transactionId: txId,
            ),
          );
          if (purchaseDetails.pendingCompletePurchase) {
            try {
              await _iap.completePurchase(purchaseDetails);
            } catch (_) {}
          }
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _processVerifiedPurchase(purchaseDetails, txId);
          break;
      }
    }
  }

  Future<void> _processVerifiedPurchase(
    PurchaseDetails purchaseDetails,
    String txId,
  ) async {
    // 1. In-flight deduplication: prevent concurrent processing of the exact same purchase
    if (_inFlightTransactionIds.contains(txId)) {
      if (kDebugMode) {
        print(
          'PURCHASE PROVIDER [Deduplication]: Transaction "$txId" is already being processed in-flight. Skipping duplicate concurrent run.',
        );
      }
      return;
    }

    // 2. Replay deduplication: if this transaction was already processed
    if (_processedTransactionIds.contains(txId)) {
      if (kDebugMode) {
        print(
          'PURCHASE PROVIDER [Deduplication]: Transaction "$txId" was already processed. Acknowledging if pending, no duplicate success.',
        );
      }
      if (purchaseDetails.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(purchaseDetails);
        } catch (_) {}
      }
      return;
    }

    final bool isRestore = purchaseDetails.status == PurchaseStatus.restored;
    final bool wasAlreadyActive = _entitlementManager?.isPremiumActive == true;

    _isUserRestoring = false;
    _isBackgroundReconciling = false;
    _cancelRestoreTimeout();

    _inFlightTransactionIds.add(txId);

    try {
      // 3. Conceptual state: verifying
      _updateState(
        PurchaseStateUpdate(
          status: PurchaseActionStatus.verifying,
          productDetails: _productDetails,
          transactionId: txId,
        ),
      );

      final verifiedEntitlement =
          await _verifier.verifyPurchase(purchaseDetails);

      if (verifiedEntitlement == null) {
        // Verification failed (or network error / temporary verification failure)
        _updateState(
          PurchaseStateUpdate(
            status: PurchaseActionStatus.error,
            errorMessage:
                'Transaction verification failed for product "${purchaseDetails.productID}".',
            productDetails: _productDetails,
            transactionId: txId,
          ),
        );
        // Do NOT acknowledge / complete transaction if verification failed temporarily, so it can be retried
        return;
      }

      if (verifiedEntitlement.status == EntitlementStatus.revoked) {
        _entitlementController.add(verifiedEntitlement);
        _updateState(
          PurchaseStateUpdate(
            status: PurchaseActionStatus.error,
            errorMessage: 'Purchase has been refunded or revoked.',
            productDetails: _productDetails,
            transactionId: txId,
          ),
        );
        if (purchaseDetails.pendingCompletePurchase) {
          try {
            await _iap.completePurchase(purchaseDetails);
          } catch (_) {}
        }
        return;
      }

      if (!verifiedEntitlement.isActive) {
        _updateState(
          PurchaseStateUpdate(
            status: PurchaseActionStatus.error,
            errorMessage:
                'Transaction verification returned non-active entitlement.',
            productDetails: _productDetails,
            transactionId: txId,
          ),
        );
        return;
      }

      // 4. Conceptual state: activating
      _updateState(
        PurchaseStateUpdate(
          status: PurchaseActionStatus.activating,
          productDetails: _productDetails,
          transactionId: txId,
        ),
      );

      // 5. Entitlement persistence
      bool persisted = true;
      if (_entitlementManager != null) {
        persisted =
            await _entitlementManager!.updateEntitlement(verifiedEntitlement);
      }

      if (!persisted) {
        if (kDebugMode) {
          print(
            'PURCHASE PROVIDER [Persistence Failure]: Could not persist entitlement to secure storage.',
          );
        }
        _updateState(
          PurchaseStateUpdate(
            status: PurchaseActionStatus.error,
            errorMessage:
                'Failed to safely record Premium purchase locally. Please tap Restore to retry.',
            productDetails: _productDetails,
            transactionId: txId,
          ),
        );
        // Do NOT acknowledge transaction on persistence failure so it can be recovered/retried
        return;
      }

      // 6. Confirm application's authoritative entitlement state confirms Premium is active
      if (_entitlementManager != null && !_entitlementManager!.isPremiumActive) {
        if (kDebugMode) {
          print(
            'PURCHASE PROVIDER [Activation Incomplete]: Authoritative manager is not active after update.',
          );
        }
        _updateState(
          PurchaseStateUpdate(
            status: PurchaseActionStatus.error,
            errorMessage:
                'Premium purchase verified but activation could not be confirmed.',
            productDetails: _productDetails,
            transactionId: txId,
          ),
        );
        return;
      }

      // 7. Complete / acknowledge transaction with platform store
      if (purchaseDetails.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(purchaseDetails);
        } catch (e) {
          if (kDebugMode) {
            print('PURCHASE PROVIDER [Complete Error]: $e');
          }
          // Note: Entitlement is already safely active locally. Store completion can be retried on next stream event/reconcile.
        }
      }

      // 8. Record durable processed transaction to prevent repeated success
      try {
        await _recordProcessedTransaction(txId);
      } catch (e) {
        if (kDebugMode) {
          print('PURCHASE PROVIDER [Durable History Error]: $e');
        }
        // Failure to write to history does not revoke entitlement or crash flow
      }

      // 9. Emit entitlement stream
      _entitlementController.add(verifiedEntitlement);

      // 10. Emit confirmed success state:
      // If an existing entitlement was already active and this is a restore, do not emit duplicate success celebration.
      if (isRestore && wasAlreadyActive) {
        if (kDebugMode) {
          print(
            'PURCHASE PROVIDER [Restore]: Existing entitlement restored without repeating celebration.',
          );
        }
        _updateState(
          PurchaseStateUpdate(
            status: PurchaseActionStatus.idle,
            productDetails: _productDetails,
            transactionId: txId,
          ),
        );
      } else {
        _updateState(
          PurchaseStateUpdate(
            status: PurchaseActionStatus.success,
            productDetails: _productDetails,
            transactionId: txId,
          ),
        );
      }
    } finally {
      _inFlightTransactionIds.remove(txId);
    }
  }

  void _onPurchaseStreamError(dynamic error) {
    if (kDebugMode) {
      print('PURCHASE PROVIDER [Stream Error]: $error');
    }
    _updateState(
      PurchaseStateUpdate(
        status: PurchaseActionStatus.error,
        errorMessage: 'Store transaction stream encountered an error.',
        productDetails: _productDetails,
      ),
    );
  }

  void _updateState(PurchaseStateUpdate newState) {
    _currentState = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  @override
  Future<void> onAppResume() async {
    if (_isDisposed) return;
    if (!_isAvailable) {
      _isAvailable = await isBillingAvailable();
      if (_isAvailable && _productDetails == null) {
        await loadProductDetails();
      }
    }
    // If billing is available and user needs reconciliation (not active, lease expired, or reboot/reverification required)
    if (_isAvailable &&
        _entitlementManager != null &&
        (!_entitlementManager!.isPremiumActive ||
            _entitlementManager!.requiresReverification ||
            _entitlementManager!.isLeaseExpired)) {
      await reconcilePurchases(isUserTriggered: false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) return;
    if (state == AppLifecycleState.resumed) {
      onAppResume();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    if (_isObserverRegistered) {
      try {
        WidgetsBinding.instance.removeObserver(this);
      } catch (_) {}
      _isObserverRegistered = false;
    }
    _isUserRestoring = false;
    _isBackgroundReconciling = false;
    _cancelRestoreTimeout();
    _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
    _stateController.close();
    _entitlementController.close();
  }
}
