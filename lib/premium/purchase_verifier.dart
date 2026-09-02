import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'premium_entitlement.dart';
import 'premium_product.dart';

/// PurchaseVerifier — Abstraction for validating in-app purchase transactions
/// before an active entitlement is granted.
///
/// Boundary Note:
/// In the current client-side implementation, this validates transaction state,
/// expected product identifier, and platform source. In future server-backed
/// architectures, this interface allows plugging in remote receipt verification
/// (e.g. App Store Server API / Google Play Developer API) without altering the
/// purchase provider or UI layer.
abstract class PurchaseVerifier {
  /// Validates a [PurchaseDetails] transaction and constructs a verified [PremiumEntitlement].
  /// Returns `null` if the transaction is invalid, unexpected, or unverified.
  Future<PremiumEntitlement?> verifyPurchase(PurchaseDetails purchaseDetails);
}

/// Default client-side purchase verifier.
class DefaultPurchaseVerifier implements PurchaseVerifier {
  const DefaultPurchaseVerifier();

  @override
  Future<PremiumEntitlement?> verifyPurchase(PurchaseDetails purchaseDetails) async {
    // 1. Strict Product Identifier Verification
    if (purchaseDetails.productID != premiumLifetimeProductId) {
      if (kDebugMode) {
        print(
          'PURCHASE VERIFIER [Rejected]: Unexpected product ID "${purchaseDetails.productID}". Expected "$premiumLifetimeProductId".',
        );
      }
      return null;
    }

    // 2. Transaction Status Verification
    if (purchaseDetails.status != PurchaseStatus.purchased &&
        purchaseDetails.status != PurchaseStatus.restored) {
      if (kDebugMode) {
        print(
          'PURCHASE VERIFIER [Rejected]: Purchase status "${purchaseDetails.status}" is not valid for entitlement activation.',
        );
      }
      return null;
    }

    // 3. Resolve Store Source
    final StoreSource storeSource;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      storeSource = StoreSource.google;
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      storeSource = StoreSource.apple;
    } else {
      storeSource = StoreSource.unknown;
    }

    // 4. Construct Verified Entitlement
    final verifiedEntitlement = PremiumEntitlement.active(
      productId: purchaseDetails.productID,
      storeSource: storeSource,
      verifiedAt: DateTime.now().toUtc(),
      transactionReference: purchaseDetails.purchaseID,
      originalPurchaseDate: purchaseDetails.transactionDate,
      rawMetadata: {
        'status': purchaseDetails.status.name,
        'verificationSource': 'client_default',
      },
    );

    if (kDebugMode) {
      print(
        'PURCHASE VERIFIER [Verified]: Entitlement verified for ${purchaseDetails.productID} (${storeSource.name}).',
      );
    }

    return verifiedEntitlement;
  }
}
