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
import 'package:quick_notes/views/widgets/app_bottom_navigation_bar.dart';
import 'package:quick_notes/views/widgets/app_header_bar.dart';
import 'package:quick_notes/views/widgets/fidelity_lab_diagnostic_button.dart';
import 'package:quick_notes/views/widgets/liquid_glass_morph_container.dart';
import 'package:quick_notes/views/widgets/more_options_popup.dart';
import 'package:quick_notes/views/widgets/quick_notes_visual_transition.dart';
import 'package:quick_notes/views/widgets/tactile_button.dart';
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

  Widget buildTestApp({double width = 412.0, double height = 915.0}) {
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
      child: MaterialApp(
        theme: QuickNotesTheme.lightTheme,
        darkTheme: QuickNotesTheme.darkTheme,
        home: MediaQuery(
          data: MediaQueryData(size: Size(width, height)),
          child: const SettingsScreen(),
        ),
      ),
    );
  }

  group('Fidelity Lab Diagnostic Morph Button in Settings — Grouped Two Options', () {
    testWidgets('1. Collapsed state renders exact 56x56 circle geometry with 3-dots icon',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byType(FidelityLabDiagnosticMorphButton), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('fidelity_lab_diagnostic_container')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('fidelity_lab_diagnostic_glass_surface')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('lab_diag_state_circle_content')),
        findsOneWidget,
      );

      final RenderBox glassBox = tester.renderObject(
        find.byKey(
          const ValueKey<String>('fidelity_lab_diagnostic_glass_surface'),
        ),
      );
      expect(glassBox.size.width, closeTo(56.0, 1.0));
      expect(glassBox.size.height, closeTo(56.0, 1.0));
    });

    testWidgets('2. Tapping Lab button morphs to 224x184 square state containing Option A and Option B in a grouped container',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Tap the diagnostic button
      await tester.tap(
        find.byKey(const ValueKey<String>('fidelity_lab_diagnostic_gesture')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Should now display square content with grouped options container
      expect(
        find.byKey(const ValueKey<String>('lab_diag_state_square_content')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('lab_diag_options_grouped_column')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('lab_diag_options_container')),
        findsOneWidget,
      );

      // Verify Option A is present
      expect(
        find.byKey(const ValueKey<String>('lab_diag_option_a')),
        findsOneWidget,
      );
      expect(find.text('Option A'), findsOneWidget);

      // Verify Option B is present
      expect(
        find.byKey(const ValueKey<String>('lab_diag_option_b')),
        findsOneWidget,
      );
      expect(find.text('Option B'), findsOneWidget);

      // Assert Option A and Option B are descendants of the grouped options container
      final Finder containerFinder =
          find.byKey(const ValueKey<String>('lab_diag_options_container'));
      expect(
        find.descendant(
          of: containerFinder,
          matching: find.byKey(const ValueKey<String>('lab_diag_option_a')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: containerFinder,
          matching: find.byKey(const ValueKey<String>('lab_diag_option_b')),
        ),
        findsOneWidget,
      );

      // Verify geometry unchanged (224x184)
      final RenderBox glassBox = tester.renderObject(
        find.byKey(
          const ValueKey<String>('fidelity_lab_diagnostic_glass_surface'),
        ),
      );
      expect(glassBox.size.width, closeTo(224.0, 1.0));
      expect(glassBox.size.height, closeTo(184.0, 1.0));
    });

    testWidgets('3. Collapsing still works and restores 56x56 circle',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Expand to square
      await tester.tap(
        find.byKey(const ValueKey<String>('fidelity_lab_diagnostic_gesture')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Option A'), findsOneWidget);

      // Tap to collapse
      await tester.tap(
        find.byKey(const ValueKey<String>('fidelity_lab_diagnostic_gesture')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Should be back to circle
      expect(
        find.byKey(const ValueKey<String>('lab_diag_state_circle_content')),
        findsOneWidget,
      );
      final RenderBox glassBox = tester.renderObject(
        find.byKey(
          const ValueKey<String>('fidelity_lab_diagnostic_glass_surface'),
        ),
      );
      expect(glassBox.size.width, closeTo(56.0, 1.0));
      expect(glassBox.size.height, closeTo(56.0, 1.0));
    });

    testWidgets('4. Reopening still works after collapsing',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // 1. Expand
      await tester.tap(
        find.byKey(const ValueKey<String>('fidelity_lab_diagnostic_gesture')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Option A'), findsOneWidget);

      // 2. Collapse
      await tester.tap(
        find.byKey(const ValueKey<String>('fidelity_lab_diagnostic_gesture')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('lab_diag_state_circle_content')),
        findsOneWidget,
      );

      // 3. Reopen
      await tester.tap(
        find.byKey(const ValueKey<String>('fidelity_lab_diagnostic_gesture')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Option A'), findsOneWidget);
      expect(find.text('Option B'), findsOneWidget);
    });

    testWidgets('5. Rapid reversal mid-flight does not snap or crash',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final Finder gesture =
          find.byKey(const ValueKey<String>('fidelity_lab_diagnostic_gesture'));

      // Start expanding
      await tester.tap(gesture);
      await tester.pump(const Duration(milliseconds: 60));

      // Reverse mid-flight
      await tester.tap(gesture);
      await tester.pump(const Duration(milliseconds: 60));

      // Reverse again mid-flight
      await tester.tap(gesture);
      await tester.pumpAndSettle();

      // Settle cleanly in square state
      expect(find.text('Option A'), findsOneWidget);
      expect(find.text('Option B'), findsOneWidget);
    });

    testWidgets('6. Diagnostic button does not affect real Settings More Options state',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Real Settings More Options popup is initially closed
      expect(find.byType(MoreOptionsPopup), findsNothing);

      // Expand diagnostic button
      await tester.tap(
        find.byKey(const ValueKey<String>('fidelity_lab_diagnostic_gesture')),
      );
      await tester.pumpAndSettle();

      // Real Settings More Options popup must remain closed
      expect(find.byType(MoreOptionsPopup), findsNothing);

      // Now tap real Settings More Options button in AppHeaderBar
      final Finder realMoreBtn = find.descendant(
        of: find.byType(AppHeaderBar),
        matching: find.byType(TactileButton),
      ).last;
      await tester.tap(realMoreBtn);
      await tester.pumpAndSettle();

      // Real More Options popup opens
      expect(find.byType(MoreOptionsPopup), findsOneWidget);
    });

    testWidgets('7. Diagnostic button does NOT use QuickNotesVisualTransition or LiquidGlassMorphContainer',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final Finder diagButton = find.byType(FidelityLabDiagnosticMorphButton);
      expect(diagButton, findsOneWidget);

      // Assert QuickNotesVisualTransition is NOT a descendant of the diagnostic button
      expect(
        find.descendant(
          of: diagButton,
          matching: find.byType(QuickNotesVisualTransition),
        ),
        findsNothing,
      );

      // Assert LiquidGlassMorphContainer is NOT a descendant of the diagnostic button
      expect(
        find.descendant(
          of: diagButton,
          matching: find.byType(LiquidGlassMorphContainer),
        ),
        findsNothing,
      );

      // Assert BottomBarGlassSurface is directly used
      expect(
        find.descendant(
          of: diagButton,
          matching: find.byType(BottomBarGlassSurface),
        ),
        findsOneWidget,
      );
    });
  });
}
