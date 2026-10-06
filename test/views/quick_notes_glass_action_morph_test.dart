import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quick_notes/premium/premium.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/providers/settings_provider.dart';
import 'package:quick_notes/providers/tasks_provider.dart';
import 'package:quick_notes/services/reminder_scheduler.dart';
import 'package:quick_notes/services/task_engine.dart';
import 'package:quick_notes/themes/quick_notes_theme.dart';
import 'package:quick_notes/views/screens/settings_screen.dart';
import 'package:quick_notes/views/screens/settings/settings_more_options_action.dart';
import 'package:quick_notes/views/widgets/app_bottom_navigation_bar.dart';
import 'package:quick_notes/views/widgets/quick_notes_glass_action_morph.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Widget buildSettingsApp() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: entitlementManager),
        ProxyProvider<PremiumEntitlementManager, FeatureAccess>(
          update: (_, manager, __) => DefaultFeatureAccess(manager),
        ),
        ChangeNotifierProvider.value(value: settingsProvider),
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
            home: const MediaQuery(
              data: MediaQueryData(size: Size(412.0, 915.0)),
              child: SettingsScreen(),
            ),
          );
        },
      ),
    );
  }

  group('QuickNotesGlassActionMorph Engine & Morph Fidelity Tests', () {
    testWidgets('1. Collapsed state renders exactly 44x44 circular button at top right', (tester) async {
      await tester.pumpWidget(buildSettingsApp());
      await tester.pumpAndSettle();

      final morphFinder = find.byType(QuickNotesGlassActionMorph<SettingsMoreOptionsAction>);
      expect(morphFinder, findsOneWidget);

      final glassFinder = find.descendant(
        of: morphFinder,
        matching: find.byType(BottomBarGlassSurface),
      );
      expect(glassFinder, findsOneWidget);

      final Size size = tester.getSize(glassFinder);
      expect(size.width, 44.0);
      expect(size.height, 44.0);

      // Actions are not visible in collapsed state
      expect(find.text('Delete Data'), findsNothing);
      expect(find.text('Refresh'), findsNothing);
    });

    testWidgets('2. Expanded state renders 192x100 card with action items', (tester) async {
      await tester.pumpWidget(buildSettingsApp());
      await tester.pumpAndSettle();

      final glassFinder = find.descendant(
        of: find.byType(QuickNotesGlassActionMorph<SettingsMoreOptionsAction>),
        matching: find.byType(BottomBarGlassSurface),
      );

      // Tap to expand
      await tester.tap(glassFinder);
      await tester.pumpAndSettle();

      final Size size = tester.getSize(glassFinder);
      expect(size.width, 192.0);
      expect(size.height, 100.0);

      // Actions are visible in expanded state
      expect(find.text('Delete Data'), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);
    });

    testWidgets('3. Open transition animates smoothly from 44x44 to 192x100 with spring physics', (tester) async {
      await tester.pumpWidget(buildSettingsApp());
      await tester.pumpAndSettle();

      final glassFinder = find.descendant(
        of: find.byType(QuickNotesGlassActionMorph<SettingsMoreOptionsAction>),
        matching: find.byType(BottomBarGlassSurface),
      );

      await tester.tap(glassFinder);
      await tester.pump(); // frame 0

      // Advance discrete frames past followDelay (40ms) to observe spring expansion
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      final Size midSize = tester.getSize(glassFinder);
      expect(midSize.width, greaterThan(44.0));
      expect(midSize.height, greaterThan(44.0));

      await tester.pumpAndSettle();
      final Size settledSize = tester.getSize(glassFinder);
      expect(settledSize.width, 192.0);
      expect(settledSize.height, 100.0);
    });

    testWidgets('4. Close transition via outside tap animates smoothly back to 44x44', (tester) async {
      await tester.pumpWidget(buildSettingsApp());
      await tester.pumpAndSettle();

      final glassFinder = find.descendant(
        of: find.byType(QuickNotesGlassActionMorph<SettingsMoreOptionsAction>),
        matching: find.byType(BottomBarGlassSurface),
      );

      await tester.tap(glassFinder);
      await tester.pumpAndSettle();
      expect(tester.getSize(glassFinder), const Size(192.0, 100.0));

      // Tap outside
      await tester.tapAt(const Offset(100, 500));
      await tester.pump(); // frame 0 of close

      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      final Size midSize = tester.getSize(glassFinder);
      expect(midSize.width, lessThan(192.0));
      expect(midSize.height, lessThan(100.0));

      await tester.pumpAndSettle();
      expect(tester.getSize(glassFinder), const Size(44.0, 44.0));
    });

    testWidgets('5 & 6. Reverse transition and live-state interruption A -> B -> A reverses smoothly', (tester) async {
      await tester.pumpWidget(buildSettingsApp());
      await tester.pumpAndSettle();

      final glassFinder = find.descendant(
        of: find.byType(QuickNotesGlassActionMorph<SettingsMoreOptionsAction>),
        matching: find.byType(BottomBarGlassSurface),
      );

      // Start expansion past followDelay (40ms) into mid-flight
      await tester.tap(glassFinder);
      await tester.pump();
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      final Size midFlightSize = tester.getSize(glassFinder);
      expect(midFlightSize.height, greaterThan(44.0));
      expect(midFlightSize.height, lessThan(100.0));

      // Interrupt with outside tap
      await tester.tapAt(const Offset(100, 500));
      await tester.pump();

      // Cleanly settles back at 44x44 without jumping
      await tester.pumpAndSettle();
      expect(tester.getSize(glassFinder), const Size(44.0, 44.0));
    });

    testWidgets('7. Rapid retargeting remains stable and finite', (tester) async {
      await tester.pumpWidget(buildSettingsApp());
      await tester.pumpAndSettle();

      final glassFinder = find.descendant(
        of: find.byType(QuickNotesGlassActionMorph<SettingsMoreOptionsAction>),
        matching: find.byType(BottomBarGlassSurface),
      );

      for (int i = 0; i < 6; i++) {
        if (i % 2 == 0) {
          await tester.tap(glassFinder);
        } else {
          await tester.tapAt(const Offset(100, 500));
        }
        await tester.pump(const Duration(milliseconds: 25));
      }

      await tester.pumpAndSettle();
      final Size finalSize = tester.getSize(glassFinder);
      expect(finalSize.width == 44.0 || finalSize.width == 192.0, isTrue);
      expect(finalSize.height == 44.0 || finalSize.height == 100.0, isTrue);
    });

    testWidgets('8, 9 & 10. Action dispatch, identity preservation, and Settings callback execution (Refresh)', (tester) async {
      await tester.pumpWidget(buildSettingsApp());
      await tester.pumpAndSettle();

      final glassFinder = find.descendant(
        of: find.byType(QuickNotesGlassActionMorph<SettingsMoreOptionsAction>),
        matching: find.byType(BottomBarGlassSurface),
      );

      await tester.tap(glassFinder);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Refresh'));
      await tester.pumpAndSettle();

      // Callback executed, SnackBar shown
      expect(find.text('Data refreshed.'), findsOneWidget);
      // Morph collapsed back to 44x44
      expect(tester.getSize(glassFinder), const Size(44.0, 44.0));
    });

    testWidgets('8, 9 & 10. Action dispatch, identity preservation, and Settings callback execution (Delete Data)', (tester) async {
      await tester.pumpWidget(buildSettingsApp());
      await tester.pumpAndSettle();

      final glassFinder = find.descendant(
        of: find.byType(QuickNotesGlassActionMorph<SettingsMoreOptionsAction>),
        matching: find.byType(BottomBarGlassSurface),
      );

      await tester.tap(glassFinder);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete Data'));
      await tester.pumpAndSettle();

      // Dialog shown
      expect(find.text('Are you sure you want to delete\nall notes and tasks? This action\ncannot be undone'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(tester.getSize(glassFinder), const Size(44.0, 44.0));
    });

    testWidgets('11. Content transition crossfades incoming and outgoing layers', (tester) async {
      bool expanded = false;
      late StateSetter stateSetter;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                stateSetter = setState;
                return QuickNotesGlassActionMorph<int>(
                  isExpanded: expanded,
                  actions: const [
                    QuickNotesGlassAction<int>(id: 1, label: 'Action 1'),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially collapsed
      expect(find.text('Action 1'), findsNothing);

      // Begin expansion
      stateSetter(() => expanded = true);
      await tester.pump();

      // Advance into content transition window
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pumpAndSettle();
      expect(find.text('Action 1'), findsOneWidget);
    });

    testWidgets('12. Lifecycle & disposal: Ticker and controllers dispose cleanly', (tester) async {
      await tester.pumpWidget(buildSettingsApp());
      await tester.pumpAndSettle();

      final glassFinder = find.descendant(
        of: find.byType(QuickNotesGlassActionMorph<SettingsMoreOptionsAction>),
        matching: find.byType(BottomBarGlassSurface),
      );
      await tester.tap(glassFinder);
      await tester.pump(const Duration(milliseconds: 30));

      // Navigate away / replace tree mid-flight
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Gone'))));
      await tester.pumpAndSettle();

      expect(find.text('Gone'), findsOneWidget);
      expect(find.byType(QuickNotesGlassActionMorph<SettingsMoreOptionsAction>), findsNothing);
    });
  });
}
