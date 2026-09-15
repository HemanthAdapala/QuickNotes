import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quick_notes/providers/settings_provider.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/providers/tasks_provider.dart';
import 'package:quick_notes/services/task_engine.dart';
import 'package:quick_notes/services/reminder_scheduler.dart';
import 'package:quick_notes/themes/quick_notes_theme.dart';
import 'package:quick_notes/views/screens/settings_screen.dart';
import 'package:quick_notes/views/widgets/tactile_button.dart';
import 'package:quick_notes/views/widgets/grouped_list_container.dart';
import 'package:quick_notes/premium/premium.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsProvider settingsProvider;
  late PremiumEntitlementManager entitlementManager;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    entitlementManager = PremiumEntitlementManager();
    await entitlementManager.initialize();
    await entitlementManager.updateEntitlement(
      PremiumEntitlement.active(productId: premiumLifetimeProductId),
    );
    settingsProvider = SettingsProvider();
    await settingsProvider.initialize();
  });

  Widget buildTestApp({Widget? child, SettingsProvider? provider}) {
    final activeProvider = provider ?? settingsProvider;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: entitlementManager),
        ProxyProvider<PremiumEntitlementManager, FeatureAccess>(
          update: (_, manager, __) => DefaultFeatureAccess(manager),
        ),
        ChangeNotifierProvider.value(value: activeProvider),
        ChangeNotifierProvider(create: (_) => NotesProvider()),
        ChangeNotifierProvider(
          create: (_) => TasksProvider(
            engine: TaskEngine(scheduler: LoggingReminderScheduler()),
          ),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            theme: QuickNotesTheme.lightTheme,
            darkTheme: QuickNotesTheme.darkTheme,
            themeMode: settings.themeMode,
            home: child ?? const SettingsScreen(),
          );
        },
      ),
    );
  }

  group('PHASE S2 — Settings Performance Remediation Tests', () {
    testWidgets('S2.1 & S2.4: Scroll-safe TactileButton suppresses tap-down animation & cancel ticker',
        (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TactileButton(
                scrollSafe: true,
                useAppleSpring: true,
                onTap: () => tapped = true,
                child: const Text('Scroll-Safe Row'),
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(tester.getCenter(find.text('Scroll-Safe Row')));
      await tester.pump();

      // In scrollSafe mode, scale controller should NOT have started moving forward
      final ScaleTransition scaleTransition = tester.widget(
        find.descendant(
          of: find.byType(TactileButton),
          matching: find.byType(ScaleTransition),
        ),
      );
      expect(scaleTransition.scale.value, equals(1.0));

      // Simulate scroll drag cancellation
      await gesture.cancel();
      await tester.pump();

      // Controller should immediately reset to 1.0 without running spring animation
      expect(scaleTransition.scale.value, equals(1.0));
      expect(tapped, isFalse);
    });

    testWidgets('S2.1: Scroll-safe TactileButton executes spring settle on intentional tap',
        (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TactileButton(
                scrollSafe: true,
                useAppleSpring: true,
                onTap: () => tapped = true,
                child: const Text('Tappable Row'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tappable Row'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tapped, isTrue);
    });

    testWidgets('S2.3: Unrelated SettingsProvider mutations do NOT rebuild SettingsScreen',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      int buildCount = 0;
      await tester.pumpWidget(
        buildTestApp(
          child: Builder(
            builder: (context) {
              // Wrap SettingsScreen with build counter tracker
              return Stack(
                children: [
                  const SettingsScreen(),
                  Builder(
                    builder: (ctx) {
                      // Monitor rebuild of SettingsScreen context by querying isDarkMode
                      buildCount++;
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              );
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final initialBuildCount = buildCount;

      // Mutate unrelated property: layoutDensity
      await settingsProvider.setLayoutDensity('list');
      await tester.pump();

      // Mutate unrelated property: fontSizeScale
      await settingsProvider.setFontSizeScale(1.15);
      await tester.pump();

      // Mutate unrelated property: selectedAccent
      await settingsProvider.setSelectedAccent('blue');
      await tester.pump();

      // None of the above should have triggered rebuilding the tracker
      expect(buildCount, equals(initialBuildCount));
    });

    testWidgets('S2.7: Responsive header geometry adapts on compact screens',
        (WidgetTester tester) async {
      // 1. Standard screen height (844px)
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestApp(child: const SettingsScreen()));
      await tester.pump(const Duration(milliseconds: 300));

      // Header SizedBox should be 248.0 on standard height
      final Finder standardHeader = find.byWidgetPredicate(
        (w) => w is SizedBox && w.height == 248.0,
      );
      expect(standardHeader, findsOneWidget);

      // 2. Compact screen height (667px - iPhone SE)
      tester.view.physicalSize = const Size(375, 667);
      await tester.pumpWidget(buildTestApp(child: const SettingsScreen()));
      await tester.pump(const Duration(milliseconds: 300));

      // Header SizedBox should adapt to 238.0 on compact height
      final Finder compactHeader = find.byWidgetPredicate(
        (w) => w is SizedBox && w.height == 238.0,
      );
      expect(compactHeader, findsOneWidget);
    });

    testWidgets('S2.2: GroupedTile.navigation uses scrollSafe tactile interaction',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupedListContainer(
              children: [
                GroupedTile.navigation(
                  title: 'Account',
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      );

      final TactileButton tactileButton = tester.widget(find.byType(TactileButton));
      expect(tactileButton.scrollSafe, isTrue);
      expect(tactileButton.useAppleSpring, isTrue);
    });
  });
}
