import 'premium_feature.dart';
import 'premium_entitlement.dart';
import 'premium_entitlement_manager.dart';

/// FeatureAccess — Centralized abstraction for checking capability access.
///
/// UI and presentation layers query this contract rather than directly inspecting
/// entitlement or billing internals:
/// ```dart
/// if (featureAccess.canAccess(PremiumFeature.folderCustomization)) {
///   // proceed
/// }
/// ```
abstract class FeatureAccess {
  /// Returns whether the requested [feature] is accessible given the current entitlement.
  bool canAccess(PremiumFeature feature);

  /// Returns whether a given [feature] is classified as a Premium capability.
  bool isPremiumFeature(PremiumFeature feature);

  /// The operational status of the current entitlement.
  EntitlementStatus get status;

  /// Whether active Premium access is present.
  bool get isPremiumActive;
}

/// Default implementation of [FeatureAccess] backed by [PremiumEntitlementManager].
class DefaultFeatureAccess implements FeatureAccess {
  final PremiumEntitlementManager _manager;

  const DefaultFeatureAccess(this._manager);

  @override
  bool canAccess(PremiumFeature feature) {
    if (!isPremiumFeature(feature)) {
      return true; // Non-premium / free features are universally accessible
    }
    return _manager.isPremiumActive;
  }

  @override
  bool isPremiumFeature(PremiumFeature feature) {
    switch (feature) {
      case PremiumFeature.folderCustomization:
      case PremiumFeature.darkMode:
      case PremiumFeature.widgets:
        return true;
    }
  }

  @override
  EntitlementStatus get status => _manager.status;

  @override
  bool get isPremiumActive => _manager.isPremiumActive;
}
