import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

  group('PHASE S4 — Settings Visual Polish & UX Tests', () {
    testWidgets('S4.1: Responsive content container & uppercase section headers',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump();

      // Verify ConstrainedBox with maxWidth: 480.0 exists for responsive card layout
      final constrainedBoxFinder = find.byWidgetPredicate(
        (widget) =>
            widget is ConstrainedBox &&
            widget.constraints.maxWidth == 480.0,
      );
      expect(constrainedBoxFinder, findsOneWidget);

      // Verify uppercase section headers
      expect(find.text('ACCOUNT & BACKUP'), findsOneWidget);
      expect(find.text('PREFERENCES'), findsOneWidget);
      expect(find.text('SUPPORT & ABOUT'), findsOneWidget);

      // Verify DEVELOPER header in debug mode
      if (kDebugMode) {
        expect(find.text('DEVELOPER'), findsOneWidget);
      }

      // Verify section header styling (12px, w700, 0.8 letter spacing)
      final Text accountHeaderText = tester.widget(find.text('ACCOUNT & BACKUP'));
      expect(accountHeaderText.style?.fontSize, equals(12.0));
      expect(accountHeaderText.style?.fontWeight, equals(FontWeight.w700));
      expect(accountHeaderText.style?.letterSpacing, equals(0.8));
    });

    testWidgets('S4.2: Typography hierarchy & iconography standardization',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump();

      // Header title: 20px, w700, height: 1.2
      final Text settingsTitle = tester.widget(find.text('Settings'));
      expect(settingsTitle.style?.fontSize, equals(20.0));
      expect(settingsTitle.style?.fontWeight, equals(FontWeight.w700));
      expect(settingsTitle.style?.height, equals(1.2));

      // Row casing: "Terms of Service" rather than "Terms of service"
      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('Terms of service'), findsNothing);

      // Verify no raw emojis in developer tools
      expect(find.textContaining('🧪'), findsNothing);

      // Verify Widgets row uses category.svg asset
      final widgetsSvgFinder = find.byWidgetPredicate((w) {
        if (w is SvgPicture) {
          final loader = w.bytesLoader;
          return loader.toString().contains('category.svg');
        }
        return false;
      });
      expect(widgetsSvgFinder, findsOneWidget);

      // Version footer
      expect(find.text('QuickNotes v1.0.0'), findsOneWidget);
    });

    testWidgets('S4.3: Camera badge geometry & single unambiguous gesture path',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump();

      // Verify 28x28 visual camera badge exists
      final cameraVisualBadge = find.byWidgetPredicate((widget) =>
          widget is Container &&
          widget.constraints?.maxWidth == 28.0 &&
          widget.constraints?.maxHeight == 28.0);
      expect(cameraVisualBadge, findsOneWidget);

      // Verify 44x44 hit container wraps the 28x28 visual badge
      final cameraHitTarget = find.ancestor(
        of: cameraVisualBadge,
        matching: find.byWidgetPredicate((widget) =>
            widget is Container &&
            widget.constraints?.maxWidth == 44.0 &&
            widget.constraints?.maxHeight == 44.0),
      );
      expect(cameraHitTarget, findsOneWidget);

      // Verify no nested GestureDetector or TactileButton inside avatar Stack
      final avatarTactileButton = find.ancestor(
        of: cameraVisualBadge,
        matching: find.byType(TactileButton),
      );
      expect(avatarTactileButton, findsOneWidget);
    });

    testWidgets('S4.4: Dark mode visual treatment (banner opacity & card borders)',
        (WidgetTester tester) async {
      // Set to Dark Mode
      await settingsProvider.setThemeMode(ThemeMode.dark);
      await tester.pumpWidget(buildTestApp());
      await tester.pump();

      // Verify Opacity(0.38) wraps the floral background banner in dark mode
      final opacityFinder = find.byWidgetPredicate((widget) =>
          widget is Opacity && widget.opacity == 0.38);
      expect(opacityFinder, findsOneWidget);

      // Verify dark border on GroupedListContainer (0xFF2C2C2E)
      final darkContainers = tester.widgetList<GroupedListContainer>(
        find.byType(GroupedListContainer),
      );
      expect(darkContainers, isNotEmpty);
      for (final container in darkContainers) {
        expect(container.border, isNotNull);
        final border = container.border as Border;
        expect(border.top.color, equals(const Color(0xFF2C2C2E)));
      }

      // Switch to Light Mode
      await settingsProvider.setThemeMode(ThemeMode.light);
      await tester.pumpWidget(buildTestApp());
      await tester.pump();

      // Verify light border on GroupedListContainer (0xFFEFEFF2)
      final lightContainers = tester.widgetList<GroupedListContainer>(
        find.byType(GroupedListContainer),
      );
      expect(lightContainers, isNotEmpty);
      for (final container in lightContainers) {
        expect(container.border, isNotNull);
        final border = container.border as Border;
        expect(border.top.color, equals(const Color(0xFFEFEFF2)));
      }
    });

    testWidgets('S4.5: GroupedTile dynamic type resilience without overflow',
        (WidgetTester tester) async {
      // Test at 1.0x text scale factor
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.0)),
              child: GroupedTile.navigation(
                title: 'Standard Row',
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final RenderBox box1 = tester.renderObject(find.byType(TactileButton));
      expect(box1.size.height, closeTo(50.0, 1.0));

      // Test at 2.0x text scale factor with long text
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
              child: GroupedTile.navigation(
                title: 'Accessibility Scaled Row With Long Multiline Explanation Label',
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Should naturally grow beyond 50px without any overflow exception
      final RenderBox box2 = tester.renderObject(find.byType(TactileButton));
      expect(box2.size.height, greaterThan(50.0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('S4.6: GroupedTile preserves S2 scrollSafe property by default',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupedTile.navigation(
              title: 'Scroll-Safe Check',
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      final TactileButton button = tester.widget(find.byType(TactileButton));
      expect(button.scrollSafe, isTrue);
    });
  });
}
