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
import 'package:quick_notes/views/widgets/app_header_bar.dart';
import 'package:quick_notes/views/widgets/fidelity_lab_diagnostic_button.dart';
import 'package:quick_notes/views/widgets/header_expanded_interaction.dart';
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

  Widget buildTestApp({Widget? child, NotesProvider? notesProvider, TasksProvider? tasksProvider}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: entitlementManager),
        ProxyProvider<PremiumEntitlementManager, FeatureAccess>(
          update: (_, manager, __) => DefaultFeatureAccess(manager),
        ),
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider(create: (_) => notesProvider ?? NotesProvider()),
        ChangeNotifierProvider(
          create: (_) => tasksProvider ?? TasksProvider(
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

  group('Structural Refactor: QuickNotesGlassActionMorph & Settings Separation', () {
    testWidgets('1 & 2. Settings More Options renders and expands to display actions', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final headerFinder = find.byType(AppHeaderBar);
      expect(headerFinder, findsOneWidget);

      final glassFinder = find.descendant(
        of: find.byType(QuickNotesGlassActionMorph<SettingsMoreOptionsAction>),
        matching: find.byType(BottomBarGlassSurface),
      );
      expect(glassFinder, findsOneWidget);

      // Collapsed: actions not visible
      expect(find.text('Delete Data'), findsNothing);
      expect(find.text('Refresh'), findsNothing);

      // Tap to expand
      await tester.tap(glassFinder);
      await tester.pumpAndSettle();

      // Expanded: QuickNotesGlassActionMorph renders actions
      expect(find.text('Delete Data'), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);
    });

    testWidgets('3, 5 & 6. Selecting an action reports to parent and triggers Settings callback (Refresh)', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final glassFinder = find.descendant(
        of: find.byType(QuickNotesGlassActionMorph<SettingsMoreOptionsAction>),
        matching: find.byType(BottomBarGlassSurface),
      );
      await tester.tap(glassFinder);
      await tester.pumpAndSettle();

      // Tap 'Refresh' action item
      await tester.tap(find.text('Refresh'));
      await tester.pumpAndSettle();

      // Verifies popup closed and Settings callback executed (SnackBar shown)
      expect(find.text('Data refreshed.'), findsOneWidget);
      expect(tester.getSize(glassFinder), const Size(44.0, 44.0));
    });

    testWidgets('3, 5 & 6. Selecting an action triggers Settings callback (Delete Data confirmation dialog)', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final glassFinder = find.descendant(
        of: find.byType(QuickNotesGlassActionMorph<SettingsMoreOptionsAction>),
        matching: find.byType(BottomBarGlassSurface),
      );
      await tester.tap(glassFinder);
      await tester.pumpAndSettle();

      // Tap 'Delete Data' action item
      await tester.tap(find.text('Delete Data'));
      await tester.pumpAndSettle();

      // Verifies popup closed and Settings confirmation dialog opened
      expect(find.text('Delete Data'), findsOneWidget); // Dialog title
      expect(find.text('Are you sure you want to delete\nall notes and tasks? This action\ncannot be undone'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(tester.getSize(glassFinder), const Size(44.0, 44.0));
    });

    testWidgets('4. QuickNotesGlassActionMorph is pure visual presentation with zero Settings dependencies', (tester) async {
      int? selectedId;
      final testActions = [
        const QuickNotesGlassAction<int>(
          id: 1,
          label: 'Custom Action 1',
          iconData: Icons.star,
        ),
        const QuickNotesGlassAction<int>(
          id: 2,
          label: 'Custom Action 2',
          iconData: Icons.favorite,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickNotesGlassActionMorph<int>(
              isExpanded: true,
              actions: testActions,
              onActionSelected: (id) => selectedId = id,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Custom Action 1'), findsOneWidget);
      expect(find.text('Custom Action 2'), findsOneWidget);

      await tester.tap(find.text('Custom Action 1'));
      await tester.pump();
      expect(selectedId, equals(1));

      await tester.tap(find.text('Custom Action 2'));
      await tester.pump();
      expect(selectedId, equals(2));
    });

    testWidgets('7 & 8. Outside-tap dismissal closes More Options via Settings-owned state', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final glassFinder = find.descendant(
        of: find.byType(QuickNotesGlassActionMorph<SettingsMoreOptionsAction>),
        matching: find.byType(BottomBarGlassSurface),
      );
      await tester.tap(glassFinder);
      await tester.pumpAndSettle();

      expect(find.text('Delete Data'), findsOneWidget);

      // Tap outside
      final barrierFinder = find.byType(HeaderExpandedInteraction);
      expect(barrierFinder, findsOneWidget);
      await tester.tapAt(const Offset(200, 500));
      await tester.pumpAndSettle();

      expect(find.text('Delete Data'), findsNothing);
      expect(tester.getSize(glassFinder), const Size(44.0, 44.0));
    });

    testWidgets('9. Back button dismissal closes More Options before navigating', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final glassFinder = find.descendant(
        of: find.byType(QuickNotesGlassActionMorph<SettingsMoreOptionsAction>),
        matching: find.byType(BottomBarGlassSurface),
      );
      await tester.tap(glassFinder);
      await tester.pumpAndSettle();

      expect(find.text('Delete Data'), findsOneWidget);

      final leftButtonFinder = find.descendant(
        of: find.byType(AppHeaderBar),
        matching: find.byType(BottomBarGlassSurface),
      ).first;

      await tester.tap(leftButtonFinder);
      await tester.pumpAndSettle();

      expect(find.text('Delete Data'), findsNothing);
      expect(tester.getSize(glassFinder), const Size(44.0, 44.0));
    });

    testWidgets('10 & 11. Diagnostic button is NOT merged into production Settings header', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // AppHeaderBar right component must NOT be FidelityLabDiagnosticMorphButton
      final headerFinder = find.byType(AppHeaderBar);
      final diagnosticInHeader = find.descendant(
        of: headerFinder,
        matching: find.byType(FidelityLabDiagnosticMorphButton),
      );
      expect(diagnosticInHeader, findsNothing);
    });

    testWidgets('12. Visual presentation matches 192x100 geometry and 50px items', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final glassFinder = find.descendant(
        of: find.byType(QuickNotesGlassActionMorph<SettingsMoreOptionsAction>),
        matching: find.byType(BottomBarGlassSurface),
      );
      await tester.tap(glassFinder);
      await tester.pumpAndSettle();

      final morphFinder = find.byType(QuickNotesGlassActionMorph<SettingsMoreOptionsAction>);
      expect(morphFinder, findsOneWidget);
      final Size morphSize = tester.getSize(glassFinder);
      expect(morphSize.width, 192.0);
      expect(morphSize.height, 100.0);
    });
  });
}
