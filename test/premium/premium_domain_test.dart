import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quick_notes/premium/premium.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PremiumFeature Tests', () {
    test('1. Verify all initial Premium features exist with valid metadata', () {
      expect(PremiumFeature.values.length, equals(3));
      expect(PremiumFeature.folderCustomization.id, equals('folder_customization'));
      expect(PremiumFeature.darkMode.id, equals('dark_mode'));
      expect(PremiumFeature.widgets.id, equals('widgets'));

      expect(PremiumFeature.folderCustomization.displayName, isNotEmpty);
      expect(PremiumFeature.darkMode.displayName, isNotEmpty);
      expect(PremiumFeature.widgets.displayName, isNotEmpty);
    });

    test('2. fromId resolves correct enum values and handles unknown ids', () {
      expect(PremiumFeature.fromId('folder_customization'),
          equals(PremiumFeature.folderCustomization));
      expect(PremiumFeature.fromId('dark_mode'), equals(PremiumFeature.darkMode));
      expect(PremiumFeature.fromId('widgets'), equals(PremiumFeature.widgets));
      expect(PremiumFeature.fromId('non_existent_feature'), isNull);
    });
  });

  group('PremiumEntitlement Model Tests', () {
    test('3. PremiumEntitlement.none() creates default un-entitled instance', () {
      const entitlement = PremiumEntitlement.none();
      expect(entitlement.status, equals(EntitlementStatus.none));
      expect(entitlement.isActive, isFalse);
      expect(entitlement.productId, isNull);
      expect(entitlement.storeSource, equals(StoreSource.unknown));
      expect(entitlement.verifiedAt, isNull);
      expect(entitlement.transactionReference, isNull);
    });

    test('4. PremiumEntitlement.active() creates active instance with correct metadata', () {
      final now = DateTime.utc(2026, 9, 2, 12, 0, 0);
      final entitlement = PremiumEntitlement.active(
        productId: 'quicknotes_premium_lifetime',
        storeSource: StoreSource.apple,
        verifiedAt: now,
        transactionReference: 'tx_123456789',
        originalPurchaseDate: '2026-09-02T12:00:00Z',
        rawMetadata: const {'environment': 'production'},
      );

      expect(entitlement.status, equals(EntitlementStatus.active));
      expect(entitlement.isActive, isTrue);
      expect(entitlement.productId, equals('quicknotes_premium_lifetime'));
      expect(entitlement.storeSource, equals(StoreSource.apple));
      expect(entitlement.verifiedAt, equals(now));
      expect(entitlement.transactionReference, equals('tx_123456789'));
      expect(entitlement.originalPurchaseDate, equals('2026-09-02T12:00:00Z'));
      expect(entitlement.rawMetadata?['environment'], equals('production'));
    });

    test('5. JSON serialization and deserialization roundtrip', () {
      final now = DateTime.utc(2026, 9, 2, 14, 30, 0);
      final original = PremiumEntitlement.active(
        productId: 'quicknotes_premium_lifetime',
        storeSource: StoreSource.google,
        verifiedAt: now,
        transactionReference: 'GPA.1234-5678-9012',
        originalPurchaseDate: '2026-09-02T14:30:00Z',
        rawMetadata: const {'orderId': 'GPA.1234-5678-9012'},
      );

      final jsonMap = original.toJson();
      final restored = PremiumEntitlement.fromJson(jsonMap);

      expect(restored, equals(original));
      expect(restored.isActive, isTrue);
      expect(restored.status, equals(EntitlementStatus.active));
      expect(restored.storeSource, equals(StoreSource.google));
      expect(restored.productId, equals('quicknotes_premium_lifetime'));
      expect(restored.verifiedAt, equals(now));
      expect(restored.transactionReference, equals('GPA.1234-5678-9012'));
    });

    test('6. fromJson gracefully handles empty or partial JSON', () {
      final emptyEntitlement = PremiumEntitlement.fromJson(const {});
      expect(emptyEntitlement.status, equals(EntitlementStatus.none));
      expect(emptyEntitlement.isActive, isFalse);
      expect(emptyEntitlement.storeSource, equals(StoreSource.unknown));
    });

    test('7. copyWith updates specified fields immutably', () {
      const original = PremiumEntitlement.none();
      final updated = original.copyWith(
        status: EntitlementStatus.active,
        productId: 'quicknotes_premium_lifetime',
        storeSource: StoreSource.apple,
      );

      expect(updated.status, equals(EntitlementStatus.active));
      expect(updated.isActive, isTrue);
      expect(updated.productId, equals('quicknotes_premium_lifetime'));
      expect(updated.storeSource, equals(StoreSource.apple));
      expect(original.status, equals(EntitlementStatus.none)); // Immutable
    });
  });

  group('PremiumEntitlementManager Tests', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('8. Fresh initialization with empty storage defaults to un-entitled', () async {
      final manager = PremiumEntitlementManager();
      expect(manager.isInitialized, isFalse);
      expect(manager.isPremiumActive, isFalse);

      await manager.initialize();

      expect(manager.isInitialized, isTrue);
      expect(manager.isPremiumActive, isFalse);
      expect(manager.currentEntitlement.status, equals(EntitlementStatus.none));
    });

    test('9. Initialization loads cached active entitlement from secure storage', () async {
      final now = DateTime.utc(2026, 9, 2, 10, 0, 0);
      final cachedEntitlement = PremiumEntitlement.active(
        productId: 'quicknotes_premium_lifetime',
        storeSource: StoreSource.apple,
        verifiedAt: now,
        transactionReference: 'tx_cached_999',
      );

      FlutterSecureStorage.setMockInitialValues({
        PremiumEntitlementManager.keyCachedEntitlement:
            jsonEncode(cachedEntitlement.toJson()),
      });

      final manager = PremiumEntitlementManager();
      await manager.initialize();

      expect(manager.isInitialized, isTrue);
      expect(manager.isPremiumActive, isTrue);
      expect(manager.currentEntitlement.productId, equals('quicknotes_premium_lifetime'));
      expect(manager.currentEntitlement.storeSource, equals(StoreSource.apple));
      expect(manager.currentEntitlement.transactionReference, equals('tx_cached_999'));
    });

    test('10. updateEntitlement updates state, notifies listeners, and persists to cache', () async {
      final manager = PremiumEntitlementManager();
      await manager.initialize();

      int notifications = 0;
      manager.addListener(() => notifications++);

      final newEntitlement = PremiumEntitlement.active(
        productId: 'quicknotes_premium_lifetime',
        storeSource: StoreSource.google,
        transactionReference: 'GPA.9999-8888',
      );

      await manager.updateEntitlement(newEntitlement);

      expect(manager.isPremiumActive, isTrue);
      expect(manager.currentEntitlement, equals(newEntitlement));
      expect(notifications, equals(1));

      // Re-hydrate from storage to verify persistence
      const storage = FlutterSecureStorage();
      final cachedStr = await storage.read(key: PremiumEntitlementManager.keyCachedEntitlement);
      expect(cachedStr, isNotNull);
      final parsed = PremiumEntitlement.fromJson(jsonDecode(cachedStr!));
      expect(parsed.productId, equals('quicknotes_premium_lifetime'));
      expect(parsed.storeSource, equals(StoreSource.google));
    });

    test('11. invalidateEntitlement marks entitlement revoked and notifies listeners', () async {
      final manager = PremiumEntitlementManager();
      await manager.initialize();

      await manager.updateEntitlement(
        PremiumEntitlement.active(productId: 'quicknotes_premium_lifetime'),
      );
      expect(manager.isPremiumActive, isTrue);

      int notifications = 0;
      manager.addListener(() => notifications++);

      await manager.invalidateEntitlement(status: EntitlementStatus.revoked);

      expect(manager.isPremiumActive, isFalse);
      expect(manager.currentEntitlement.status, equals(EntitlementStatus.revoked));
      expect(notifications, equals(1));
    });

    test('12. clearCache resets state to none and deletes storage key', () async {
      final manager = PremiumEntitlementManager();
      await manager.initialize();

      await manager.updateEntitlement(
        PremiumEntitlement.active(productId: 'quicknotes_premium_lifetime'),
      );
      expect(manager.isPremiumActive, isTrue);

      await manager.clearCache();

      expect(manager.isPremiumActive, isFalse);
      expect(manager.currentEntitlement.status, equals(EntitlementStatus.none));

      const storage = FlutterSecureStorage();
      final cachedStr = await storage.read(key: PremiumEntitlementManager.keyCachedEntitlement);
      expect(cachedStr, isNull);
    });

    test('13. Corrupt JSON in secure storage fails safely without crashing', () async {
      FlutterSecureStorage.setMockInitialValues({
        PremiumEntitlementManager.keyCachedEntitlement: 'invalid_malformed_{{{json',
      });

      final manager = PremiumEntitlementManager();
      await manager.initialize();

      expect(manager.isInitialized, isTrue);
      expect(manager.isPremiumActive, isFalse);
      expect(manager.currentEntitlement.status, equals(EntitlementStatus.none));
    });
  });

  group('FeatureAccess Abstraction Tests', () {
    test('14. FeatureAccess denies premium features when entitlement is inactive', () async {
      final manager = PremiumEntitlementManager();
      await manager.initialize();
      final access = DefaultFeatureAccess(manager);

      expect(access.isPremiumActive, isFalse);
      expect(access.status, equals(EntitlementStatus.none));

      // Premium features must be denied
      expect(access.canAccess(PremiumFeature.folderCustomization), isFalse);
      expect(access.canAccess(PremiumFeature.darkMode), isFalse);
      expect(access.canAccess(PremiumFeature.widgets), isFalse);
    });

    test('15. FeatureAccess allows premium features when entitlement is active', () async {
      final manager = PremiumEntitlementManager();
      await manager.initialize();
      final access = DefaultFeatureAccess(manager);

      await manager.updateEntitlement(
        PremiumEntitlement.active(productId: 'quicknotes_premium_lifetime'),
      );

      expect(access.isPremiumActive, isTrue);
      expect(access.status, equals(EntitlementStatus.active));

      // Premium features must be granted
      expect(access.canAccess(PremiumFeature.folderCustomization), isTrue);
      expect(access.canAccess(PremiumFeature.darkMode), isTrue);
      expect(access.canAccess(PremiumFeature.widgets), isTrue);
    });

    test('16. isPremiumFeature correctly identifies all premium capabilities', () {
      final manager = PremiumEntitlementManager();
      final access = DefaultFeatureAccess(manager);

      expect(access.isPremiumFeature(PremiumFeature.folderCustomization), isTrue);
      expect(access.isPremiumFeature(PremiumFeature.darkMode), isTrue);
      expect(access.isPremiumFeature(PremiumFeature.widgets), isTrue);
    });
  });
}
