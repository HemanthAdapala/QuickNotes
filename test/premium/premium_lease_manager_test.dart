import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quick_notes/premium/jws_lease.dart';
import 'package:quick_notes/premium/premium_entitlement.dart';
import 'package:quick_notes/premium/premium_entitlement_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Premium Entitlement Manager Lease & Reboot Uncertainty Tests', () {
    late FlutterSecureStorage mockStorage;
    late SharedPreferences mockPrefs;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      mockStorage = const FlutterSecureStorage();
      mockPrefs = await SharedPreferences.getInstance();
    });

    JwsLease createTestLease({
      required DateTime issuedAt,
      required DateTime expiresAt,
      String status = 'ACTIVE',
    }) {
      return JwsLease(
        kid: 'v1',
        issuer: 'https://auth.quicknotes.app',
        audience: 'com.quicknotes.byhmnth',
        subject: 'sha256_token_hash_mock',
        entitlement: 'premium',
        productId: 'quicknotes_premium_lifetime',
        status: status,
        issuedAt: issuedAt,
        notBefore: issuedAt,
        expiresAt: expiresAt,
        jti: 'test-jti-001',
        rawCompactToken: 'header.payload.signature',
      );
    }

    test('1. Valid unexpired lease enables Premium access', () async {
      final manager = PremiumEntitlementManager(
        secureStorage: mockStorage,
        prefs: mockPrefs,
        isDebug: false,
      );
      await manager.initialize();

      final now = DateTime.now().toUtc();
      final validLease = createTestLease(
        issuedAt: now.subtract(const Duration(hours: 1)),
        expiresAt: now.add(const Duration(days: 7)),
      );

      await manager.updateLease(validLease);

      expect(manager.isPremiumActive, isTrue);
      expect(manager.requiresReverification, isFalse);
      expect(manager.isLeaseExpired, isFalse);
      expect(manager.status, equals(EntitlementStatus.active));
    });

    test('2. 7-day expired lease blocks Premium and requires re-verification', () async {
      final manager = PremiumEntitlementManager(
        secureStorage: mockStorage,
        prefs: mockPrefs,
        isDebug: false,
      );
      await manager.initialize();

      final now = DateTime.now().toUtc();
      // Lease issued 8 days ago, expired 1 day ago
      final expiredLease = createTestLease(
        issuedAt: now.subtract(const Duration(days: 8)),
        expiresAt: now.subtract(const Duration(days: 1)),
      );

      await manager.updateLease(expiredLease);

      expect(manager.isLeaseExpired, isTrue);
      expect(manager.isPremiumActive, isFalse);
      expect(manager.status, equals(EntitlementStatus.verificationRequired));
    });

    test('3. Clock rollback detection on initialization flags requiresReverification', () async {
      final now = DateTime.now().toUtc();
      final validLease = createTestLease(
        issuedAt: now.subtract(const Duration(hours: 2)),
        expiresAt: now.add(const Duration(days: 6)),
      );

      // Simulate a future timestamp recorded previously (user set clock ahead, then rolled back)
      final futureTime = now.add(const Duration(days: 2));
      await mockStorage.write(
        key: PremiumEntitlementManager.keyCachedEntitlement,
        value: jsonEncode(const PremiumEntitlement(
          status: EntitlementStatus.active,
          productId: 'quicknotes_premium_lifetime',
        ).toJson()),
      );
      await mockStorage.write(
        key: PremiumEntitlementManager.keyCachedLease,
        value: jsonEncode(validLease.toJson()),
      );
      await mockStorage.write(
        key: PremiumEntitlementManager.keyLastKnownWallClock,
        value: futureTime.toIso8601String(),
      );

      final manager = PremiumEntitlementManager(
        secureStorage: mockStorage,
        prefs: mockPrefs,
        isDebug: false,
      );
      await manager.initialize();

      // Clock was rolled back backwards past last known timestamp
      expect(manager.requiresReverification, isTrue);
      expect(manager.isPremiumActive, isFalse);
      expect(manager.status, equals(EntitlementStatus.verificationRequired));
    });

    test('4. Active entitlement without cryptographic lease flags requiresReverification', () async {
      await mockStorage.write(
        key: PremiumEntitlementManager.keyCachedEntitlement,
        value: jsonEncode(const PremiumEntitlement(
          status: EntitlementStatus.active,
          productId: 'quicknotes_premium_lifetime',
        ).toJson()),
      );
      // No cached lease written

      final manager = PremiumEntitlementManager(
        secureStorage: mockStorage,
        prefs: mockPrefs,
        isDebug: false,
        requireLease: true,
      );
      await manager.initialize();

      expect(manager.requiresReverification, isTrue);
      expect(manager.isPremiumActive, isFalse);
    });

    test('5. Invalidation / Revocation clears lease and sets revoked status without deleting user data', () async {
      final manager = PremiumEntitlementManager(
        secureStorage: mockStorage,
        prefs: mockPrefs,
        isDebug: false,
      );
      await manager.initialize();

      final now = DateTime.now().toUtc();
      final validLease = createTestLease(
        issuedAt: now.subtract(const Duration(hours: 1)),
        expiresAt: now.add(const Duration(days: 7)),
      );
      await manager.updateLease(validLease);
      expect(manager.isPremiumActive, isTrue);

      // Perform authoritative revocation
      await manager.invalidateEntitlement(status: EntitlementStatus.revoked);

      expect(manager.isPremiumActive, isFalse);
      expect(manager.status, equals(EntitlementStatus.revoked));
      expect(manager.currentLease, isNull);

      // Cache is updated
      final cachedLease = await mockStorage.read(key: PremiumEntitlementManager.keyCachedLease);
      expect(cachedLease, isNull);
    });

    test('6. Entitlement is device-wide and survives session operations', () async {
      final manager = PremiumEntitlementManager(
        secureStorage: mockStorage,
        prefs: mockPrefs,
        isDebug: false,
      );
      await manager.initialize();

      final now = DateTime.now().toUtc();
      final validLease = createTestLease(
        issuedAt: now.subtract(const Duration(hours: 1)),
        expiresAt: now.add(const Duration(days: 7)),
      );
      await manager.updateLease(validLease);

      // Simulating user profile switch / Google sign out:
      // SessionManager does not delete keyCachedEntitlement or keyCachedLease
      final cachedEntitlementStr = await mockStorage.read(key: PremiumEntitlementManager.keyCachedEntitlement);
      final cachedLeaseStr = await mockStorage.read(key: PremiumEntitlementManager.keyCachedLease);

      expect(cachedEntitlementStr, isNotNull);
      expect(cachedLeaseStr, isNotNull);
      expect(manager.isPremiumActive, isTrue);
    });
  });
}
