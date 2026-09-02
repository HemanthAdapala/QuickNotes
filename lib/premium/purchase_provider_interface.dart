import 'package:in_app_purchase/in_app_purchase.dart';
import 'premium_entitlement.dart';

/// Operational status of an in-app purchase or restoration action.
enum PurchaseActionStatus {
  idle,
  loadingProduct,
  purchasing,
  restoring,
  success,
  cancelled,
  error,
}

/// State update emitted by the purchase provider during user actions.
class PurchaseStateUpdate {
  final PurchaseActionStatus status;
  final String? errorMessage;
  final ProductDetails? productDetails;

  const PurchaseStateUpdate({
    required this.status,
    this.errorMessage,
    this.productDetails,
  });

  const PurchaseStateUpdate.idle()
      : status = PurchaseActionStatus.idle,
        errorMessage = null,
        productDetails = null;

  @override
  String toString() =>
      'PurchaseStateUpdate(status: ${status.name}, error: $errorMessage, product: ${productDetails?.id})';
}

/// PurchaseProvider — Abstract boundary for platform store purchase adapters.
///
/// Isolates the Flutter presentation and entitlement layers from StoreKit / Google Play
/// Billing platform APIs.
abstract class PurchaseProvider {
  /// The platform store source associated with this provider.
  StoreSource get storeSource;

  /// Whether the platform store is currently available on this device.
  bool get isAvailable;

  /// The cached [ProductDetails] for the lifetime Premium product, if loaded.
  ProductDetails? get productDetails;

  /// Localized price string formatted by the platform store (e.g. '$4.99' or '₹499').
  String? get formattedPrice;

  /// Current state of the purchase provider.
  PurchaseStateUpdate get currentState;

  /// Stream of state updates for UI reactivity.
  Stream<PurchaseStateUpdate> get stateStream;

  /// Stream of entitlement updates emitted during purchase lifecycle events.
  Stream<PremiumEntitlement> get entitlementStream;

  /// Checks if the platform billing service is currently available on the device.
  Future<bool> isBillingAvailable();

  /// Initializes the store connection, listens to the purchase stream, and queries product details.
  Future<void> initialize();

  /// Queries and returns the [ProductDetails] for the lifetime Premium product.
  Future<ProductDetails?> loadProductDetails();

  /// Initiates a non-consumable lifetime purchase with the platform store.
  Future<bool> purchasePremium();

  /// Restores previous purchases directly from the platform store.
  Future<bool> restorePurchases();

  /// Cleans up active stream subscriptions and controllers.
  void dispose();
}
