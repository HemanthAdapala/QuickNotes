import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quick_notes/core/motion/quick_notes_visual_preset.dart';
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
import 'package:quick_notes/views/widgets/header_expanded_interaction.dart';
import 'package:quick_notes/views/widgets/liquid_glass_morph_container.dart';
import 'package:quick_notes/views/widgets/quick_notes_glass_action_morph.dart';
import 'package:quick_notes/views/screens/settings/settings_more_options_action.dart';
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

  Widget buildTestApp({Widget? child, double width = 412.0, double height = 915.0}) {
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
            home: MediaQuery(
              data: MediaQueryData(size: Size(width, height)),
              child: child ?? const SettingsScreen(),
            ),
          );
        },
      ),
    );
  }

  group('Settings Top-Right Button: QuickNotesVisualTransition Replacement Tests', () {
    testWidgets('1. Collapsed state renders exactly 44x44 circular button using QuickNotesVisualTransition + Baseline, LiquidGlassMorphContainer is absent', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Old visual transition mechanism must be completely absent from Settings
      expect(find.byType(LiquidGlassMorphContainer), findsNothing,
          reason: 'LiquidGlassMorphContainer must be removed from the Settings visual path');

      // The new reusable visual transition must be present
      final transitionFinder = find.byType(QuickNotesVisualTransition);
      expect(transitionFinder, findsOneWidget);

      final transitionWidget = tester.widget<QuickNotesVisualTransition>(transitionFinder);
      expect(transitionWidget.preset, QuickNotesVisualPreset.baseline,
          reason: 'Must consume locked QuickNotesVisualPreset.baseline');
      expect(transitionWidget.collapsedSize, const Size(44.0, 44.0));
      expect(transitionWidget.expandedSize, const Size(192.0, 100.0));
      expect(transitionWidget.collapsedBorderRadius, BorderRadius.circular(22.0));
      expect(transitionWidget.expandedBorderRadius, BorderRadius.circular(20.0));
      expect(transitionWidget.anchor, Alignment.topRight);
      expect(transitionWidget.state, isFalse);

      final glassFinder = find.descendant(
        of: transitionFinder,
        matching: find.byType(BottomBarGlassSurface),
      );
      expect(glassFinder, findsOneWidget);

      final Size initialGlassSize = tester.getSize(glassFinder);
      expect(initialGlassSize.width, 44.0);
      expect(initialGlassSize.height, 44.0);

      // Verify 3-dots icon row is present and QuickNotesGlassActionMorph is not visible
      expect(find.byType(QuickNotesGlassActionMorph<SettingsMoreOptionsAction>), findsNothing);
    });

    testWidgets('2. Tapping 3-dots triggers morph expansion to 192x100 card anchored at top-right', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final transitionFinder = find.byType(QuickNotesVisualTransition);
      final double initialRight = tester.getTopRight(transitionFinder).dx;

      // Tap trailing button to open more options
      final glassFinder = find.descendant(
        of: transitionFinder,
        matching: find.byType(BottomBarGlassSurface),
      );
      await tester.tap(glassFinder);
      await tester.pump(); // Start transition

      final transitionWidget = tester.widget<QuickNotesVisualTransition>(transitionFinder);
      expect(transitionWidget.state, isTrue);

      // Settle animation
      await tester.pumpAndSettle();

      final Size expandedGlassSize = tester.getSize(glassFinder);
      expect(expandedGlassSize.width, 192.0);
      expect(expandedGlassSize.height, 100.0);

      // Verify top-right anchor preservation: right edge must not drift
      final double expandedRight = tester.getTopRight(transitionFinder).dx;
      expect(expandedRight, equals(initialRight));

      // Verify QuickNotesGlassActionMorph content is rendered and visible
      expect(find.byType(QuickNotesGlassActionMorph<SettingsMoreOptionsAction>), findsOneWidget);
      expect(find.text('Delete Data'), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);
    });

    testWidgets('3. Outside tap dismisses expanded card back to 44x44 circle', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final transitionFinder = find.byType(QuickNotesVisualTransition);
      final glassFinder = find.descendant(
        of: transitionFinder,
        matching: find.byType(BottomBarGlassSurface),
      );

      // Tap to open
      await tester.tap(glassFinder);
      await tester.pumpAndSettle();
      expect(tester.getSize(glassFinder), const Size(192.0, 100.0));

      // Tap outside on HeaderExpandedInteraction barrier
      final barrierFinder = find.byType(HeaderExpandedInteraction);
      expect(barrierFinder, findsOneWidget);

      // Tap outside the popup (e.g. at center of screen)
      await tester.tapAt(const Offset(200, 500));
      await tester.pump(); // Begin collapse

      final transitionWidget = tester.widget<QuickNotesVisualTransition>(transitionFinder);
      expect(transitionWidget.state, isFalse);

      await tester.pumpAndSettle();

      expect(tester.getSize(glassFinder), const Size(44.0, 44.0));
      expect(find.byType(QuickNotesGlassActionMorph<SettingsMoreOptionsAction>), findsNothing);
    });

    testWidgets('4. Mid-flight interruption A -> B -> A reverses smoothly without pop', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final transitionFinder = find.byType(QuickNotesVisualTransition);
      final glassFinder = find.descendant(
        of: transitionFinder,
        matching: find.byType(BottomBarGlassSurface),
      );

      // Start expansion
      await tester.tap(glassFinder);
      await tester.pump();
      expect(tester.widget<QuickNotesVisualTransition>(transitionFinder).state, isTrue);

      // Advance discrete frames past follow delay (40ms) into mid-flight
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      final Size midFlightSize = tester.getSize(glassFinder);
      expect(midFlightSize.height, greaterThan(44.0));
      expect(midFlightSize.height, lessThan(100.0));

      // Interrupt by triggering collapse via outside tap
      await tester.tapAt(const Offset(100, 500));
      await tester.pump();

      // Ensure transition reverses from current point and cleanly settles at 44x44
      await tester.pumpAndSettle();
      expect(tester.getSize(glassFinder), const Size(44.0, 44.0));
    });

    testWidgets('5. Rapid toggling remains stable and finite without competing controllers', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final transitionFinder = find.byType(QuickNotesVisualTransition);
      final glassFinder = find.descendant(
        of: transitionFinder,
        matching: find.byType(BottomBarGlassSurface),
      );

      // Rapidly toggle 6 times
      for (int i = 0; i < 6; i++) {
        if (i % 2 == 0) {
          await tester.tap(glassFinder);
        } else {
          await tester.tapAt(const Offset(100, 500));
        }
        await tester.pump(const Duration(milliseconds: 30));
      }

      await tester.pumpAndSettle();

      final Size settledSize = tester.getSize(glassFinder);
      expect(settledSize.height == 44.0 || settledSize.height == 100.0, isTrue);
      expect(settledSize.width == 44.0 || settledSize.width == 192.0, isTrue);
    });

    testWidgets('6. SettingsScreen back button dismisses popup if open before popping screen', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final transitionFinder = find.byType(QuickNotesVisualTransition);
      final glassFinder = find.descendant(
        of: transitionFinder,
        matching: find.byType(BottomBarGlassSurface),
      );

      // Open popup
      await tester.tap(glassFinder);
      await tester.pumpAndSettle();
      expect(tester.getSize(glassFinder), const Size(192.0, 100.0));

      // Tap left back button in AppHeaderBar
      final leftButtonFinder = find.descendant(
        of: find.byType(AppHeaderBar),
        matching: find.byType(BottomBarGlassSurface),
      ).first;

      await tester.tap(leftButtonFinder);
      await tester.pumpAndSettle();

      // Popup is dismissed, morph returned to 44x44
      expect(tester.getSize(glassFinder), const Size(44.0, 44.0));
      expect(find.byType(QuickNotesGlassActionMorph<SettingsMoreOptionsAction>), findsNothing);
    });

    testWidgets('7. Interrupted collapse reverses smoothly to expanded state when state retargets', (tester) async {
      bool isExpanded = true;
      late StateSetter stateSetter;

      await tester.pumpWidget(
        MaterialApp(
          theme: QuickNotesTheme.darkTheme,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                stateSetter = setState;
                return Stack(
                  children: [
                    Positioned(
                      top: 0,
                      right: 0,
                      child: QuickNotesVisualTransition.liquidGlass(
                        state: isExpanded,
                        preset: QuickNotesVisualPreset.baseline,
                        collapsedSize: const Size(44.0, 44.0),
                        expandedSize: const Size(192.0, 100.0),
                        collapsedBorderRadius: BorderRadius.circular(22.0),
                        expandedBorderRadius: BorderRadius.circular(20.0),
                        anchor: Alignment.topRight,
                        useFrost: true,
                        collapsedChild: const SizedBox(
                          width: 44.0,
                          height: 44.0,
                          child: Icon(Icons.more_horiz),
                        ),
                        expandedChild: const SizedBox(
                          width: 192.0,
                          height: 100.0,
                          child: Text('Options'),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(BottomBarGlassSurface)), const Size(192.0, 100.0));

      // Trigger collapse
      stateSetter(() => isExpanded = false);
      await tester.pump();

      // Advance into mid-collapse
      for (int i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      final Size midCollapseSize = tester.getSize(find.byType(BottomBarGlassSurface));
      expect(midCollapseSize.height, lessThan(100.0));

      // Re-trigger expansion mid-flight before settling
      stateSetter(() => isExpanded = true);
      await tester.pump();

      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(BottomBarGlassSurface)), const Size(192.0, 100.0));
    });

    testWidgets('8. Rapid A -> B -> A toggling settles accurately at target', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final transitionFinder = find.byType(QuickNotesVisualTransition);
      final glassFinder = find.descendant(
        of: transitionFinder,
        matching: find.byType(BottomBarGlassSurface),
      );

      // Open (A -> B)
      await tester.tap(glassFinder);
      await tester.pumpAndSettle();
      expect(tester.getSize(glassFinder), const Size(192.0, 100.0));

      // Close via outside tap (B -> A)
      await tester.tapAt(const Offset(100, 500));
      await tester.pumpAndSettle();
      expect(tester.getSize(glassFinder), const Size(44.0, 44.0));

      // Re-open (A -> B)
      await tester.tap(glassFinder);
      await tester.pumpAndSettle();
      expect(tester.getSize(glassFinder), const Size(192.0, 100.0));
    });

    testWidgets('9. Content transition crossfades cleanly between 3-dots and MoreOptionsPopup', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final transitionFinder = find.byType(QuickNotesVisualTransition);
      final glassFinder = find.descendant(
        of: transitionFinder,
        matching: find.byType(BottomBarGlassSurface),
      );

      // Collapsed: TactileButton with 3-dot circles is present, popup hidden
      expect(find.descendant(of: transitionFinder, matching: find.byType(TactileButton)), findsOneWidget);
      expect(find.byType(QuickNotesGlassActionMorph<SettingsMoreOptionsAction>), findsNothing);

      // Expand
      await tester.tap(glassFinder);
      await tester.pumpAndSettle();

      // Expanded: QuickNotesGlassActionMorph visible, items accessible
      expect(find.byType(QuickNotesGlassActionMorph<SettingsMoreOptionsAction>), findsOneWidget);
      expect(find.text('Delete Data'), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);
    });

    testWidgets('10. State ownership remains strictly in SettingsScreen', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final transitionFinder = find.byType(QuickNotesVisualTransition);
      final transitionWidget = tester.widget<QuickNotesVisualTransition>(transitionFinder);

      // Container only receives state from parent; it does not own domain state
      expect(transitionWidget.state, isFalse);

      final glassFinder = find.descendant(
        of: transitionFinder,
        matching: find.byType(BottomBarGlassSurface),
      );
      await tester.tap(glassFinder);
      await tester.pump();

      final updatedTransition = tester.widget<QuickNotesVisualTransition>(transitionFinder);
      expect(updatedTransition.state, isTrue);
    });

    testWidgets('11. Glass surface is authentic BottomBarGlassSurface with single BackdropFilter', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final transitionFinder = find.byType(QuickNotesVisualTransition);
      final glassFinder = find.descendant(
        of: transitionFinder,
        matching: find.byType(BottomBarGlassSurface),
      );

      expect(glassFinder, findsOneWidget);
      final glassWidget = tester.widget<BottomBarGlassSurface>(glassFinder);
      expect(glassWidget.useFrost, isTrue);

      // Exactly 1 BackdropFilter within the transition surface (no dual-surface compositing)
      final backdropFinder = find.descendant(
        of: transitionFinder,
        matching: find.byType(BackdropFilter),
      );
      expect(backdropFinder, findsOneWidget);
    });

    testWidgets('12. No magic offsets: Positioned anchor in AppHeaderBar is strictly top: 0, right: 0', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final transitionFinder = find.byType(QuickNotesVisualTransition);
      final positionedFinder = find.ancestor(
        of: transitionFinder,
        matching: find.byType(Positioned),
      ).first;

      final Positioned positioned = tester.widget<Positioned>(positionedFinder);
      expect(positioned.right, 0.0);
      expect(positioned.top, 0.0);
      expect(positioned.left, isNull);
      expect(positioned.bottom, isNull);
    });
  });
}
