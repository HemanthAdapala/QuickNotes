import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'premium_entitlement.dart';
import 'premium_entitlement_manager.dart';
import 'premium_product.dart';
import 'purchase_provider_interface.dart';
import 'purchase_verifier.dart';

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
class InAppPurchaseProvider implements PurchaseProvider {
  final InAppPurchase _iap;
  final PurchaseVerifier _verifier;
  final PremiumEntitlementManager? _entitlementManager;

  bool _isAvailable = false;
  ProductDetails? _productDetails;
  PurchaseStateUpdate _currentState = const PurchaseStateUpdate.idle();

  final StreamController<PurchaseStateUpdate> _stateController =
      StreamController<PurchaseStateUpdate>.broadcast();
  final StreamController<PremiumEntitlement> _entitlementController =
      StreamController<PremiumEntitlement>.broadcast();

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  InAppPurchaseProvider({
    InAppPurchase? inAppPurchase,
    PurchaseVerifier? verifier,
    PremiumEntitlementManager? entitlementManager,
  })  : _iap = inAppPurchase ?? InAppPurchase.instance,
        _verifier = verifier ?? const DefaultPurchaseVerifier(),
        _entitlementManager = entitlementManager;

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

    // 2. Subscribe to platform purchase update stream
    _purchaseSubscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _purchaseSubscription?.cancel(),
      onError: _onPurchaseStreamError,
    );

    // 3. Load product details if store is available
    if (_isAvailable) {
      await loadProductDetails();
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
    if (!_isAvailable) {
      _isAvailable = await isBillingAvailable();
      if (!_isAvailable) {
        _updateState(
          const PurchaseStateUpdate(
            status: PurchaseActionStatus.error,
            errorMessage:
                'Store is currently unavailable. Please verify your connection.',
          ),
        );
        return false;
      }
    }

    _updateState(
      PurchaseStateUpdate(
        status: PurchaseActionStatus.restoring,
        productDetails: _productDetails,
      ),
    );

    try {
      await _iap.restorePurchases();
      // Restoration results arrive asynchronously over purchaseStream
      return true;
    } catch (e) {
      _updateState(
        PurchaseStateUpdate(
          status: PurchaseActionStatus.error,
          errorMessage: 'Failed to restore previous purchases from store.',
          productDetails: _productDetails,
        ),
      );
      return false;
    }
  }

  Future<void> _onPurchaseUpdate(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (kDebugMode) {
        print(
          'PURCHASE PROVIDER [Stream]: Received purchase: ID="${purchaseDetails.productID}", status=${purchaseDetails.status.name}',
        );
      }

      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          _updateState(
            PurchaseStateUpdate(
              status: PurchaseActionStatus.purchasing,
              productDetails: _productDetails,
            ),
          );
          break;

        case PurchaseStatus.canceled:
          _updateState(
            PurchaseStateUpdate(
              status: PurchaseActionStatus.cancelled,
              productDetails: _productDetails,
            ),
          );
          if (purchaseDetails.pendingCompletePurchase) {
            await _iap.completePurchase(purchaseDetails);
          }
          break;

        case PurchaseStatus.error:
          _updateState(
            PurchaseStateUpdate(
              status: PurchaseActionStatus.error,
              errorMessage: purchaseDetails.error?.message ??
                  'Purchase could not be completed by the store.',
              productDetails: _productDetails,
            ),
          );
          if (purchaseDetails.pendingCompletePurchase) {
            await _iap.completePurchase(purchaseDetails);
          }
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final verifiedEntitlement =
              await _verifier.verifyPurchase(purchaseDetails);

          if (verifiedEntitlement != null) {
            // Authoritatively update Entitlement Manager
            if (_entitlementManager != null) {
              await _entitlementManager!.updateEntitlement(verifiedEntitlement);
            }

            _entitlementController.add(verifiedEntitlement);

            _updateState(
              PurchaseStateUpdate(
                status: PurchaseActionStatus.success,
                productDetails: _productDetails,
              ),
            );
          } else {
            _updateState(
              PurchaseStateUpdate(
                status: PurchaseActionStatus.error,
                errorMessage:
                    'Transaction verification failed for product "${purchaseDetails.productID}".',
                productDetails: _productDetails,
              ),
            );
          }

          // Complete non-consumable transaction with platform store
          if (purchaseDetails.pendingCompletePurchase) {
            await _iap.completePurchase(purchaseDetails);
          }
          break;
      }
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
  void dispose() {
    _purchaseSubscription?.cancel();
    _stateController.close();
    _entitlementController.close();
  }
}
