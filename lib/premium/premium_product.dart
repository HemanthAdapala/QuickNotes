/// Authoritative identifier for the Quick Notes lifetime non-consumable Premium product.
///
/// Must match the In-App Purchase product ID configured in:
/// - Apple App Store Connect (In-App Purchases -> Non-Consumable)
/// - Google Play Console (In-App Products -> Non-Consumable / One-time)
const String premiumLifetimeProductId = 'quicknotes_premium_lifetime';

/// Set of all supported in-app purchase product identifiers.
const Set<String> kAllProductIds = {
  premiumLifetimeProductId,
};
