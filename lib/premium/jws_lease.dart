// lib/premium/jws_lease.dart
// Immutable representation of a verified cryptographic entitlement lease

import 'package:flutter/foundation.dart';

@immutable
class JwsLease {
  final String kid;
  final String issuer;
  final String audience;
  final String subject; // token_hash
  final String entitlement; // 'premium'
  final String productId; // 'quicknotes_premium_lifetime'
  final String status; // 'ACTIVE'
  final DateTime issuedAt;
  final DateTime notBefore;
  final DateTime expiresAt;
  final String jti;
  final String rawCompactToken;

  const JwsLease({
    this.kid = '',
    required this.issuer,
    required this.audience,
    required this.subject,
    required this.entitlement,
    required this.productId,
    required this.status,
    required this.issuedAt,
    required this.notBefore,
    required this.expiresAt,
    required this.jti,
    required this.rawCompactToken,
  });

  /// Whether the lease has expired relative to [now].
  bool isExpired([DateTime? now]) {
    final current = now ?? DateTime.now().toUtc();
    return current.isAfter(expiresAt);
  }

  /// Remaining duration before expiration. Returns [Duration.zero] if already expired.
  Duration remainingDuration([DateTime? now]) {
    final current = now ?? DateTime.now().toUtc();
    final remaining = expiresAt.difference(current);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Map<String, dynamic> toJson() {
    return {
      'kid': kid,
      'iss': issuer,
      'aud': audience,
      'sub': subject,
      'entitlement': entitlement,
      'product_id': productId,
      'status': status,
      'iat': issuedAt.millisecondsSinceEpoch ~/ 1000,
      'nbf': notBefore.millisecondsSinceEpoch ~/ 1000,
      'exp': expiresAt.millisecondsSinceEpoch ~/ 1000,
      'jti': jti,
      'rawCompactToken': rawCompactToken,
    };
  }

  factory JwsLease.fromJson(Map<String, dynamic> json) {
    return JwsLease(
      kid: json['kid'] as String? ?? '',
      issuer: json['iss'] as String? ?? '',
      audience: json['aud'] as String? ?? '',
      subject: json['sub'] as String? ?? '',
      entitlement: json['entitlement'] as String? ?? '',
      productId: json['product_id'] as String? ?? '',
      status: json['status'] as String? ?? '',
      issuedAt: DateTime.fromMillisecondsSinceEpoch(
        ((json['iat'] as num? ?? 0) * 1000).toInt(),
        isUtc: true,
      ),
      notBefore: DateTime.fromMillisecondsSinceEpoch(
        ((json['nbf'] as num? ?? 0) * 1000).toInt(),
        isUtc: true,
      ),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        ((json['exp'] as num? ?? 0) * 1000).toInt(),
        isUtc: true,
      ),
      jti: json['jti'] as String? ?? '',
      rawCompactToken: json['rawCompactToken'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is JwsLease &&
        other.rawCompactToken == rawCompactToken &&
        other.expiresAt == expiresAt &&
        other.status == status;
  }

  @override
  int get hashCode => Object.hash(rawCompactToken, expiresAt, status);
}
