import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/providers/tasks_provider.dart';
import 'package:quick_notes/providers/settings_provider.dart';
import 'package:quick_notes/premium/premium.dart';
import 'package:quick_notes/views/screens/home_screen.dart';
import 'package:quick_notes/views/screens/calendar_screen.dart';
import 'package:quick_notes/views/screens/create_task_screen.dart';
import 'package:quick_notes/views/screens/note_editor_screen.dart';
import 'package:quick_notes/views/widgets/quick_notes_liquid_glass_tab_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestApp({int initialNavIndex = 0}) {
    SharedPreferences.setMockInitialValues({});
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => PremiumEntitlementManager()),
        Provider<FeatureAccess>(
          create: (c) => DefaultFeatureAccess(
            Provider.of<PremiumEntitlementManager>(c, listen: false),
          ),
        ),
        ChangeNotifierProvider(create: (_) => NotesProvider()),
        ChangeNotifierProvider(create: (_) => TasksProvider()),
      ],
      child: const MaterialApp(
        home: HomeScreen(),
      ),
    );
  }

  group('Phase 3 — Step 3: Context-Aware FAB Actions & Settings Visibility', () {
    testWidgets('1. Calendar FAB has blue tint (#0088FF) and "Create task" semantics',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: QuickNotesLiquidGlassTabBar(
              selectedIndex: 2,
              onDestinationSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final fabGlassFinder = find.byKey(const ValueKey('fab_glass_surface'));
      expect(fabGlassFinder, findsOneWidget);

      final dynamic glassWidget = tester.widget(fabGlassFinder);
      expect(glassWidget.activeColor, equals(const Color(0xFF0088FF)));

      final taskSemantics = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Create task',
      );
      expect(taskSemantics, findsOneWidget);
    });

    testWidgets('2. Settings hides FAB with Visibility(visible: false) and maintains size',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: QuickNotesLiquidGlassTabBar(
              selectedIndex: 3,
              onDestinationSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final visibilityFinder = find.byKey(const ValueKey('fab_visibility'));
      expect(visibilityFinder, findsOneWidget);

      final Visibility visibilityWidget = tester.widget<Visibility>(visibilityFinder);
      expect(visibilityWidget.visible, isFalse);
      expect(visibilityWidget.maintainSize, isTrue);
      expect(visibilityWidget.maintainAnimation, isTrue);
      expect(visibilityWidget.maintainState, isTrue);
      expect(visibilityWidget.maintainInteractivity, isFalse);
      expect(visibilityWidget.maintainSemantics, isFalse);

      // Verify FAB semantics are completely excluded
      final fabSemantics = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            (w.properties.label == 'Create note' ||
                w.properties.label == 'Create task' ||
                w.properties.label == 'Add folder'),
      );
      expect(fabSemantics, findsNothing);
    });

    testWidgets('3. Settings tab maintains identical navigation capsule geometry (no shift)',
        (WidgetTester tester) async {
      int activeIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                bottomNavigationBar: QuickNotesLiquidGlassTabBar(
                  selectedIndex: activeIndex,
                  onDestinationSelected: (idx) {
                    setState(() => activeIndex = idx);
                  },
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final capsuleFinder =
          find.byKey(const ValueKey('quick_notes_main_navigation_bar'));
      final Rect homeCapsuleRect = tester.getRect(capsuleFinder);

      // Switch to Settings (tab 3)
      await tester.tap(find.bySemanticsLabel('Settings'));
      await tester.pumpAndSettle();

      final Rect settingsCapsuleRect = tester.getRect(capsuleFinder);

      // Capsule rect must be identical down to the sub-pixel
      expect(settingsCapsuleRect.left, equals(homeCapsuleRect.left));
      expect(settingsCapsuleRect.top, equals(homeCapsuleRect.top));
      expect(settingsCapsuleRect.width, equals(homeCapsuleRect.width));
      expect(settingsCapsuleRect.height, equals(homeCapsuleRect.height));
    });

    testWidgets('4. Hidden FAB in Settings cannot be tapped',
        (WidgetTester tester) async {
      bool fabTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: QuickNotesLiquidGlassTabBar(
              selectedIndex: 3,
              onDestinationSelected: (_) {},
              onFabPressed: () => fabTriggered = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final fabFinder = find.byKey(const ValueKey('quick_notes_navigation_fab'));
      expect(fabFinder, findsOneWidget);

      await tester.tap(fabFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(fabTriggered, isFalse);
    });

    testWidgets('5. Switching from Settings back to Home restores visible FAB and action',
        (WidgetTester tester) async {
      int activeIndex = 3; // Start on Settings
      bool fabTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                bottomNavigationBar: QuickNotesLiquidGlassTabBar(
                  selectedIndex: activeIndex,
                  isNotesActive: true,
                  onDestinationSelected: (idx) {
                    if (idx == 4) {
                      fabTriggered = true;
                    } else {
                      setState(() => activeIndex = idx);
                    }
                  },
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // In Settings, Visibility is false
      expect(
        tester.widget<Visibility>(find.byKey(const ValueKey('fab_visibility'))).visible,
        isFalse,
      );

      // Switch to Home (tab 0)
      await tester.tap(find.bySemanticsLabel('Home'));
      await tester.pumpAndSettle();

      // Visibility is true, FAB is yellow, and tap works
      expect(
        tester.widget<Visibility>(find.byKey(const ValueKey('fab_visibility'))).visible,
        isTrue,
      );

      final fabFinder = find.byKey(const ValueKey('quick_notes_navigation_fab'));
      await tester.tap(fabFinder);
      await tester.pumpAndSettle();

      expect(fabTriggered, isTrue);
    });

    testWidgets('6. Calendar FAB opens TaskEditorScreen with selected calendar date',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Switch to Calendar tab (index 2)
      await tester.tap(find.bySemanticsLabel('Calendar'));
      await tester.pump();
      tester.takeException();
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.byType(CalendarScreen), findsOneWidget);

      // Select a specific day (day 15) on the calendar grid
      final day15Finder = find.text('15');
      expect(day15Finder, findsOneWidget);
      await tester.tap(day15Finder);
      await tester.pumpAndSettle();

      // Tap the FAB
      final fabFinder = find.byKey(const ValueKey('quick_notes_navigation_fab'));
      expect(fabFinder, findsOneWidget);
      await tester.tap(fabFinder);
      await tester.pumpAndSettle();

      // TaskEditorScreen must be opened
      final editorFinder = find.byType(TaskEditorScreen);
      expect(editorFinder, findsOneWidget);

      // Verify the task editor received the selected day 15
      final TaskEditorScreen editor = tester.widget<TaskEditorScreen>(editorFinder);
      expect(editor.initialDate?.day, equals(15));

      // NoteEditorScreen must NOT be opened
      expect(find.byType(NoteEditorScreen), findsNothing);
    });
  });
}

