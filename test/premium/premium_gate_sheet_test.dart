import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quick_notes/premium/premium.dart';
import 'package:quick_notes/themes/quick_notes_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PremiumFeaturePresentation Metadata Unit Tests', () {
    test('1. Resolves presentation metadata for folderCustomization', () {
      final p = PremiumFeaturePresentation.forFeature(PremiumFeature.folderCustomization);
      expect(p.categoryTag, equals('FOLDER CUSTOMIZATION'));
      expect(p.headline, contains('Folder'));
      expect(p.description, contains('hex colors'));
      expect(p.icon, equals(Icons.folder_special_rounded));
      expect(p.benefits.length, greaterThanOrEqualTo(3));
    });

    test('2. Resolves presentation metadata for darkMode', () {
      final p = PremiumFeaturePresentation.forFeature(PremiumFeature.darkMode);
      expect(p.categoryTag, equals('OBSIDIAN DARK MODE'));
      expect(p.headline, contains('Night'));
      expect(p.description, contains('aluminum'));
      expect(p.icon, equals(Icons.dark_mode_rounded));
      expect(p.benefits.length, greaterThanOrEqualTo(3));
    });

    test('3. Resolves presentation metadata for widgets', () {
      final p = PremiumFeaturePresentation.forFeature(PremiumFeature.widgets);
      expect(p.categoryTag, equals('HOME SCREEN WIDGETS'));
      expect(p.headline, contains('Glance'));
      expect(p.description, contains('Quick Capture'));
      expect(p.icon, equals(Icons.widgets_rounded));
      expect(p.benefits.length, greaterThanOrEqualTo(3));
    });

    test('4. Resolves default metadata when feature is null', () {
      final p = PremiumFeaturePresentation.forFeature(null);
      expect(p.categoryTag, equals('QUICK NOTES PREMIUM'));
      expect(p.headline, contains('Full Experience'));
      expect(p.benefits.length, greaterThanOrEqualTo(3));
    });
  });

  group('PremiumGateSheet Widget & Presentation Tests', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
    });

    testWidgets('5. Renders PremiumGateSheet for folderCustomization with all elements',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));

      await tester.pumpWidget(
        MaterialApp(
          theme: QuickNotesTheme.lightTheme,
          home: const Scaffold(
            body: PremiumGateSheet(
              feature: PremiumFeature.folderCustomization,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('FOLDER CUSTOMIZATION'), findsOneWidget);
      expect(find.text('Make Every Folder Yours'), findsOneWidget);
      expect(find.text('Unlock Premium'), findsOneWidget);
      expect(find.text('Restore Purchases'), findsOneWidget);
      expect(find.text('Maybe Later'), findsOneWidget);
      expect(find.byIcon(Icons.folder_special_rounded), findsOneWidget);
    });

    testWidgets('6. Renders PremiumGateSheet for darkMode in Dark Theme',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));

      await tester.pumpWidget(
        MaterialApp(
          theme: QuickNotesTheme.darkTheme,
          home: const Scaffold(
            body: PremiumGateSheet(
              feature: PremiumFeature.darkMode,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('OBSIDIAN DARK MODE'), findsOneWidget);
      expect(find.text('A Calmer Workspace for Night'), findsOneWidget);
      expect(find.text('Unlock Premium'), findsOneWidget);
      expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
    });

    testWidgets('7. Renders PremiumGateSheet for widgets with custom price subtitle',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));

      await tester.pumpWidget(
        MaterialApp(
          theme: QuickNotesTheme.lightTheme,
          home: const Scaffold(
            body: PremiumGateSheet(
              feature: PremiumFeature.widgets,
              customPriceSubtitle: 'Special Introductory Offer',
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('HOME SCREEN WIDGETS'), findsOneWidget);
      expect(find.text('Your Thoughts, Right at a Glance'), findsOneWidget);
      expect(find.text('Special Introductory Offer'), findsOneWidget);
      expect(find.byIcon(Icons.widgets_rounded), findsOneWidget);
    });

    testWidgets('8. Tapping Unlock Premium invokes callback and does NOT mutate entitlement',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));

      final manager = PremiumEntitlementManager();
      await manager.initialize();

      bool unlockInvoked = false;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: manager),
            Provider<FeatureAccess>(create: (_) => DefaultFeatureAccess(manager)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PremiumGateSheet(
                feature: PremiumFeature.folderCustomization,
                onUnlockPressed: () => unlockInvoked = true,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      // Initial state: free/inactive
      expect(manager.isPremiumActive, isFalse);

      // Tap Unlock Premium
      await tester.tap(find.text('Unlock Premium'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(unlockInvoked, isTrue);
      // Verify NO fake purchasing occurred: entitlement MUST still be inactive
      expect(manager.isPremiumActive, isFalse);
    });

    testWidgets('9. Tapping Restore Purchases invokes restore callback',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));

      bool restoreInvoked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PremiumGateSheet(
              feature: PremiumFeature.folderCustomization,
              onRestorePressed: () => restoreInvoked = true,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      final restoreFinder = find.text('Restore Purchases');
      await tester.ensureVisible(restoreFinder);
      await tester.tap(restoreFinder);
      await tester.pump(const Duration(milliseconds: 300));

      expect(restoreInvoked, isTrue);
    });

    testWidgets('10. Responsive layout on compact screen without overflow',
        (WidgetTester tester) async {
      // iPhone SE / small screen size
      await tester.binding.setSurfaceSize(const Size(320, 568));

      await tester.pumpWidget(
        MaterialApp(
          theme: QuickNotesTheme.lightTheme,
          home: const Scaffold(
            body: PremiumGateSheet(
              feature: PremiumFeature.darkMode,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Unlock Premium'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('11. showPremiumGate skips presentation if user is already Premium',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));

      final manager = PremiumEntitlementManager();
      await manager.initialize();
      await manager.updateEntitlement(
        PremiumEntitlement.active(productId: 'quicknotes_premium_lifetime'),
      );

      BuildContext? testContext;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: manager),
            Provider<FeatureAccess>(create: (_) => DefaultFeatureAccess(manager)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  testContext = context;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      expect(testContext, isNotNull);

      // Call showPremiumGate
      await showPremiumGate(
        context: testContext!,
        feature: PremiumFeature.darkMode,
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Sheet should NOT be presented since user is already premium
      expect(find.text('Unlock Premium'), findsNothing);
    });
  });
}
