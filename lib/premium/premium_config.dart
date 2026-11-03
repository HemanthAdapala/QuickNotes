// lib/premium/premium_config.dart
// Configuration and pinned cryptographic keys for QuickNotes Premium backend verification

class PremiumBackendConfig {
  /// The expected issuer URL for JWS entitlement leases.
  /// Configured at build time via --dart-define=PREMIUM_ISSUER_URL=https://...
  static const String issuerUrl = String.fromEnvironment(
    'PREMIUM_ISSUER_URL',
    defaultValue: '',
  );

  /// Pinned Ed25519 public keys indexed by key ID (`kid`).
  ///
  /// Operational Rule:
  /// During a planned key rotation, the new public key ('v2') is added here
  /// alongside the existing key ('v1') before the server cutover.
  static const Map<String, String> trustedPublicKeys = {
    // Staging pinned public key (32-byte Ed25519 raw public key base64)
    'v1': 'E3XUIUC7AqNxLreAd0EnnNb7xyDlC6RZGGvPVE+Q3TU=',
  };

  /// Expected bundle/package identifier for lease audience verification.
  static const String expectedAudience = 'com.quicknotes.byhmnth';

  /// Expected product identifier for lifetime Premium.
  static const String expectedProductId = 'quicknotes_premium_lifetime';

  /// Entitlement lease validity duration (exactly 7 days = 604,800 seconds).
  static const Duration leaseLifetime = Duration(days: 7);

  /// Maximum acceptable clock skew tolerance for iat/nbf claims.
  static const Duration clockSkewTolerance = Duration(seconds: 60);

  /// Maximum permitted backward wall-clock step before triggering clock rollback uncertainty.
  static const Duration maxClockRollbackTolerance = Duration(minutes: 15);

  /// Whether the remote verification backend is configured for this build.
  static bool get isConfigured => issuerUrl.isNotEmpty;
}
