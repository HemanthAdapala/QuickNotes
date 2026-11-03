// lib/premium/jws_lease_verifier.dart
// Strict client-side verification for Ed25519 compact JWS entitlement leases

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'crypto/ed25519.dart';
import 'jws_lease.dart';
import 'premium_config.dart';

class JwsLeaseVerifier {
  final Map<String, String>? _trustedPublicKeys;

  const JwsLeaseVerifier([this._trustedPublicKeys]);

  /// Computes SHA-256 hex digest of a string.
  static String sha256Hex(String input) {
    return sha256.convert(utf8.encode(input)).toString();
  }

  /// Alias for [verifyLease] with named parameters.
  JwsLease? verify({
    required String jwsToken,
    String? expectedSubject,
    DateTime? currentTime,
    Map<String, String>? customPublicKeys,
    String? expectedIssuer,
  }) {
    return verifyLease(
      jwsToken,
      expectedTokenHash: expectedSubject,
      currentTime: currentTime,
      customPublicKeys: customPublicKeys ?? _trustedPublicKeys,
      expectedIssuer: expectedIssuer,
    );
  }

  /// Decodes a base64url string into bytes.
  static Uint8List _base64UrlDecode(String source) {
    var normalized = source.replaceAll('-', '+').replaceAll('_', '/');
    while (normalized.length % 4 != 0) {
      normalized += '=';
    }
    return Uint8List.fromList(base64Decode(normalized));
  }

  /// Verifies and decodes an Ed25519 compact JWS lease token.
  ///
  /// Returns a valid [JwsLease] if the signature, key pinning, and all required
  /// claims pass verification. Returns `null` if the token is invalid, forged,
  /// expired, or unexpected.
  JwsLease? verifyLease(
    String compactJws, {
    String? expectedTokenHash,
    DateTime? currentTime,
    Map<String, String>? customPublicKeys,
    String? expectedIssuer,
  }) {
    try {
      final parts = compactJws.trim().split('.');
      if (parts.length != 3) {
        if (kDebugMode) print('JWS LEASE [Rejected]: Compact JWS must have exactly 3 parts');
        return null;
      }

      final headerStr = utf8.decode(_base64UrlDecode(parts[0]));
      final payloadStr = utf8.decode(_base64UrlDecode(parts[1]));
      final signatureBytes = _base64UrlDecode(parts[2]);

      final Map<String, dynamic> header = jsonDecode(headerStr);
      final Map<String, dynamic> payload = jsonDecode(payloadStr);

      // 1. Strict Algorithm and Type Allowlisting
      if (header['alg'] != 'EdDSA') {
        if (kDebugMode) print('JWS LEASE [Rejected]: Unsupported algorithm "${header['alg']}". Expected "EdDSA".');
        return null;
      }
      if (header['typ'] != 'JWT') {
        if (kDebugMode) print('JWS LEASE [Rejected]: Unsupported typ "${header['typ']}". Expected "JWT".');
        return null;
      }

      // 2. Resolve Pinned Public Key by Key ID (`kid`)
      final kid = header['kid'] as String?;
      if (kid == null || kid.isEmpty) {
        if (kDebugMode) print('JWS LEASE [Rejected]: Missing "kid" in JWS protected header');
        return null;
      }

      final keysMap = customPublicKeys ?? PremiumBackendConfig.trustedPublicKeys;
      final publicKeyBase64 = keysMap[kid];
      if (publicKeyBase64 == null) {
        if (kDebugMode) print('JWS LEASE [Rejected]: Key ID "$kid" not found in pinned public keys');
        return null;
      }

      final publicKeyBytes = base64Decode(publicKeyBase64);

      // 3. Verify Ed25519 Cryptographic Signature over `ASCII(header) + '.' + ASCII(payload)`
      final signingInputBytes = Uint8List.fromList(ascii.encode('${parts[0]}.${parts[1]}'));
      final isValidSig = Ed25519.verify(
        publicKey: Uint8List.fromList(publicKeyBytes),
        message: signingInputBytes,
        signature: signatureBytes,
      );

      if (!isValidSig) {
        if (kDebugMode) print('JWS LEASE [Rejected]: Cryptographic Ed25519 signature verification failed');
        return null;
      }

      // 4. Validate Required Claims
      final issuer = payload['iss'] as String? ?? '';
      final targetIssuer = expectedIssuer ?? PremiumBackendConfig.issuerUrl;
      if (targetIssuer.isNotEmpty && issuer != targetIssuer) {
        if (kDebugMode) print('JWS LEASE [Rejected]: Issuer mismatch. Got "$issuer", expected "$targetIssuer".');
        return null;
      }

      final audience = payload['aud'] as String? ?? '';
      if (audience != PremiumBackendConfig.expectedAudience) {
        if (kDebugMode) print('JWS LEASE [Rejected]: Audience mismatch. Got "$audience".');
        return null;
      }

      final subject = payload['sub'] as String? ?? '';
      if (expectedTokenHash != null && subject != expectedTokenHash) {
        if (kDebugMode) print('JWS LEASE [Rejected]: Subject token hash mismatch.');
        return null;
      }

      if (payload['entitlement'] != 'premium') {
        if (kDebugMode) print('JWS LEASE [Rejected]: Entitlement claim is not "premium".');
        return null;
      }

      if (payload['product_id'] != PremiumBackendConfig.expectedProductId) {
        if (kDebugMode) print('JWS LEASE [Rejected]: Product ID mismatch.');
        return null;
      }

      if (payload['status'] != 'ACTIVE') {
        if (kDebugMode) print('JWS LEASE [Rejected]: Lease status is not "ACTIVE".');
        return null;
      }

      // 5. Temporal Claims Validation
      final now = (currentTime ?? DateTime.now().toUtc());
      final nowSec = now.millisecondsSinceEpoch ~/ 1000;
      final skewSec = PremiumBackendConfig.clockSkewTolerance.inSeconds;

      final iat = (payload['iat'] as num? ?? 0).toInt();
      final nbf = (payload['nbf'] as num? ?? 0).toInt();
      final exp = (payload['exp'] as num? ?? 0).toInt();

      if (iat <= 0 || nbf <= 0 || exp <= 0) {
        if (kDebugMode) print('JWS LEASE [Rejected]: Missing or non-positive temporal claims.');
        return null;
      }

      // Reject invalid or inconsistent temporal claims
      if (exp <= iat) {
        if (kDebugMode) print('JWS LEASE [Rejected]: Invalid temporal interval (exp <= iat).');
        return null;
      }

      if (nbf > exp) {
        if (kDebugMode) print('JWS LEASE [Rejected]: Invalid temporal interval (nbf > exp).');
        return null;
      }

      // Validate relationship between iat and exp against approved 7-day maximum (604,800 seconds).
      // Clock skew must not become a loophole for accepting materially overlong leases.
      final maxLifetimeSec = PremiumBackendConfig.leaseLifetime.inSeconds;
      if ((exp - iat) > maxLifetimeSec) {
        if (kDebugMode) {
          print('JWS LEASE [Rejected]: Declared lease duration (${exp - iat}s) exceeds 7-day maximum (${maxLifetimeSec}s).');
        }
        return null;
      }

      if (iat > nowSec + skewSec) {
        if (kDebugMode) print('JWS LEASE [Rejected]: Token iat is in the future.');
        return null;
      }
      if (nbf > nowSec + skewSec) {
        if (kDebugMode) print('JWS LEASE [Rejected]: Token is not yet valid (nbf).');
        return null;
      }
      if (exp <= nowSec) {
        if (kDebugMode) print('JWS LEASE [Rejected]: Token has expired.');
        return null;
      }

      // Construct verified lease
      return JwsLease(
        kid: kid,
        issuer: issuer,
        audience: audience,
        subject: subject,
        entitlement: payload['entitlement'] as String,
        productId: payload['product_id'] as String,
        status: payload['status'] as String,
        issuedAt: DateTime.fromMillisecondsSinceEpoch(iat * 1000, isUtc: true),
        notBefore: DateTime.fromMillisecondsSinceEpoch(nbf * 1000, isUtc: true),
        expiresAt: DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true),
        jti: payload['jti'] as String? ?? '',
        rawCompactToken: compactJws,
      );
    } catch (e) {
      if (kDebugMode) print('JWS LEASE [Exception]: Failed to verify lease: $e');
      return null;
    }
  }
}
