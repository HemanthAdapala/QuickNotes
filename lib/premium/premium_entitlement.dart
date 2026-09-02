import 'package:flutter/foundation.dart';

/// Status classification of an entitlement.
enum EntitlementStatus {
  /// No entitlement exists.
  none,

  /// Active, verified lifetime or subscription entitlement.
  active,

  /// Entitlement was revoked, refunded, or chargebacked.
  revoked,

  /// Entitlement has expired (for time-limited grants).
  expired,

  /// Purchase transaction is pending external confirmation (e.g. Ask to Buy).
  pending,

  /// Local state requires online store re-verification.
  verificationRequired,
}

/// The platform or store source that granted the entitlement.
enum StoreSource {
  /// Apple App Store (StoreKit 2 / App Store Receipt).
  apple,

  /// Google Play Store (Google Play Billing).
  google,

  /// Manual grant or promotion code.
  manual,

  /// Unknown or unspecified source.
  unknown,
}

/// PremiumEntitlement — Immutable domain representation of a user's entitlement state.
///
/// Holds the necessary metadata for feature gating, audit logging, and future
/// purchase verification while remaining decoupled from platform store SDKs.
@immutable
class PremiumEntitlement {
  /// The operational status of the entitlement.
  final EntitlementStatus status;

  /// The store product identifier (e.g., 'quicknotes_premium_lifetime').
  final String? productId;

  /// The originating store or source for the entitlement.
  final StoreSource storeSource;

  /// The timestamp when this entitlement was last verified by the store/service.
  final DateTime? verifiedAt;

  /// The non-sensitive platform transaction identifier or order ID.
  final String? transactionReference;

  /// Optional original purchase date string (ISO-8601).
  final String? originalPurchaseDate;

  /// Optional additional non-sensitive platform metadata.
  final Map<String, dynamic>? rawMetadata;

  const PremiumEntitlement({
    required this.status,
    this.productId,
    this.storeSource = StoreSource.unknown,
    this.verifiedAt,
    this.transactionReference,
    this.originalPurchaseDate,
    this.rawMetadata,
  });

  /// Factory constructor representing a clean, un-entitled state.
  const PremiumEntitlement.none()
      : status = EntitlementStatus.none,
        productId = null,
        storeSource = StoreSource.unknown,
        verifiedAt = null,
        transactionReference = null,
        originalPurchaseDate = null,
        rawMetadata = null;

  /// Factory constructor representing an active, verified entitlement.
  factory PremiumEntitlement.active({
    String? productId,
    StoreSource storeSource = StoreSource.unknown,
    DateTime? verifiedAt,
    String? transactionReference,
    String? originalPurchaseDate,
    Map<String, dynamic>? rawMetadata,
  }) {
    return PremiumEntitlement(
      status: EntitlementStatus.active,
      productId: productId,
      storeSource: storeSource,
      verifiedAt: verifiedAt ?? DateTime.now().toUtc(),
      transactionReference: transactionReference,
      originalPurchaseDate: originalPurchaseDate,
      rawMetadata: rawMetadata,
    );
  }

  /// Helper getter indicating whether this entitlement currently grants active Premium access.
  bool get isActive => status == EntitlementStatus.active;

  /// Creates a copy of this entitlement with the given fields replaced.
  PremiumEntitlement copyWith({
    EntitlementStatus? status,
    String? productId,
    StoreSource? storeSource,
    DateTime? verifiedAt,
    String? transactionReference,
    String? originalPurchaseDate,
    Map<String, dynamic>? rawMetadata,
  }) {
    return PremiumEntitlement(
      status: status ?? this.status,
      productId: productId ?? this.productId,
      storeSource: storeSource ?? this.storeSource,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      transactionReference: transactionReference ?? this.transactionReference,
      originalPurchaseDate: originalPurchaseDate ?? this.originalPurchaseDate,
      rawMetadata: rawMetadata ?? this.rawMetadata,
    );
  }

  /// Serializes the entitlement into a JSON map suitable for secure local caching.
  Map<String, dynamic> toJson() {
    return {
      'status': status.name,
      'productId': productId,
      'storeSource': storeSource.name,
      'verifiedAt': verifiedAt?.toIso8601String(),
      'transactionReference': transactionReference,
      'originalPurchaseDate': originalPurchaseDate,
      'rawMetadata': rawMetadata,
    };
  }

  /// Deserializes a [PremiumEntitlement] from a JSON map.
  factory PremiumEntitlement.fromJson(Map<String, dynamic> json) {
    EntitlementStatus status = EntitlementStatus.none;
    if (json['status'] != null) {
      status = EntitlementStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => EntitlementStatus.none,
      );
    }

    StoreSource storeSource = StoreSource.unknown;
    if (json['storeSource'] != null) {
      storeSource = StoreSource.values.firstWhere(
        (e) => e.name == json['storeSource'],
        orElse: () => StoreSource.unknown,
      );
    }

    DateTime? verifiedAt;
    if (json['verifiedAt'] != null && json['verifiedAt'] is String) {
      verifiedAt = DateTime.tryParse(json['verifiedAt'] as String);
    }

    return PremiumEntitlement(
      status: status,
      productId: json['productId'] as String?,
      storeSource: storeSource,
      verifiedAt: verifiedAt,
      transactionReference: json['transactionReference'] as String?,
      originalPurchaseDate: json['originalPurchaseDate'] as String?,
      rawMetadata: json['rawMetadata'] != null && json['rawMetadata'] is Map
          ? Map<String, dynamic>.from(json['rawMetadata'] as Map)
          : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PremiumEntitlement &&
        other.status == status &&
        other.productId == productId &&
        other.storeSource == storeSource &&
        other.verifiedAt == verifiedAt &&
        other.transactionReference == transactionReference &&
        other.originalPurchaseDate == originalPurchaseDate;
  }

  @override
  int get hashCode => Object.hash(
        status,
        productId,
        storeSource,
        verifiedAt,
        transactionReference,
        originalPurchaseDate,
      );

  @override
  String toString() {
    return 'PremiumEntitlement(status: ${status.name}, productId: $productId, storeSource: ${storeSource.name}, verifiedAt: $verifiedAt)';
  }
}
