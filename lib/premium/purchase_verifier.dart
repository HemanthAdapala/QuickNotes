import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'premium_entitlement.dart';
import 'premium_product.dart';

/// PurchaseVerifier — Abstraction for validating in-app purchase transactions
/// before an active entitlement is granted.
///
/// Boundary Note:
/// In the current client-side implementation, [DefaultPurchaseVerifier] performs
/// structural validation (verifying product ID match, non-error status, and runtime platform).
/// It does NOT perform cryptographic RSA signature verification or query the Google Play
/// Developer API (purchases.products.get). In future server-backed architectures, this
/// interface allows plugging in trusted remote receipt verification without altering the
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
