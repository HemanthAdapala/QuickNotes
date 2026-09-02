import 'premium_entitlement.dart';

/// PurchaseProvider — Abstract boundary for platform store purchase adapters.
///
/// Implementations (e.g. Apple StoreKit 2 adapter, Google Play Billing adapter)
/// will plug into this interface in Phase P4 to provide real purchase flows,
/// receipt restoration, and online purchase verification without coupling
/// the core application to platform-specific billing APIs.
abstract class PurchaseProvider {
  /// The platform store source associated with this provider.
  StoreSource get storeSource;

  /// Checks if the platform billing service is currently available on the device.
  Future<bool> isBillingAvailable();

  /// Restores previous purchases directly from the platform store.
  Future<PremiumEntitlement?> restorePurchases();

  /// Stream of entitlement updates emitted during purchase lifecycle events.
  Stream<PremiumEntitlement> get entitlementStream;
}
