import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/views/widgets/quick_notes_liquid_glass_tab_bar.dart';

void main() {
  group('QuickNotesLiquidGlassTabBar - Production Widget Tests', () {
    testWidgets('1. Builds successfully with default geometry and semantics',
        (WidgetTester tester) async {
      int selected = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: QuickNotesLiquidGlassTabBar(
                selectedIndex: selected,
                onDestinationSelected: (idx) => selected = idx,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check key element presence
      expect(find.byType(QuickNotesLiquidGlassTabBar), findsOneWidget);
      expect(find.byKey(const ValueKey('quick_notes_navigation_row')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('quick_notes_main_navigation_bar')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('quick_notes_navigation_fab')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('physical_active_indicator')),
          findsOneWidget);

      // Verify semantics for all four destinations
      final homeSemantics = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Home',
      );
      final foldersSemantics = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Folders',
      );
      final calendarSemantics = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Calendar',
      );
      final settingsSemantics = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Settings',
      );
      final fabSemantics = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Create note',
      );

      expect(homeSemantics, findsWidgets);
      expect(foldersSemantics, findsWidgets);
      expect(calendarSemantics, findsWidgets);
      expect(settingsSemantics, findsWidgets);
      expect(fabSemantics, findsOneWidget);

      // Verify initial selected state
      final selectedHome = tester.widget<Semantics>(homeSemantics.first);
      expect(selectedHome.properties.selected, isTrue);

      final unselectedFolders = tester.widget<Semantics>(foldersSemantics.first);
      expect(unselectedFolders.properties.selected, isFalse);
    });

    testWidgets('2. Tab selection triggers onDestinationSelected and updates state',
        (WidgetTester tester) async {
      int selected = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Center(
                  child: QuickNotesLiquidGlassTabBar(
                    selectedIndex: selected,
                    onDestinationSelected: (idx) {
                      setState(() => selected = idx);
                    },
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap calendar tab (index 2) via coordinates
      final barFinder =
          find.byKey(const ValueKey('quick_notes_main_navigation_bar'));
      final barRect = tester.getRect(barFinder);
      final scale = (barRect.width / 264.0);
      final tab2X = barRect.left + (40.0 + 2 * (184.0 / 3.0)) * scale;
      final tab2Y = barRect.center.dy;

      await tester.tapAt(Offset(tab2X, tab2Y));
      await tester.pumpAndSettle();

      expect(selected, 2);

      // Check that destination 2 is now marked selected
      final calendarSemantics = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Calendar',
      );
      final selectedCalendar = tester.widget<Semantics>(calendarSemantics.first);
      expect(selectedCalendar.properties.selected, isTrue);
    });

    testWidgets('3. FAB tap triggers onFabPressed and onDestinationSelected(4)',
        (WidgetTester tester) async {
      int selected = 0;
      bool fabTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: QuickNotesLiquidGlassTabBar(
                selectedIndex: selected,
                onDestinationSelected: (idx) => selected = idx,
                onFabPressed: () => fabTriggered = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final fabFinder =
          find.byKey(const ValueKey('quick_notes_navigation_fab'));
      expect(fabFinder, findsOneWidget);

      await tester.tap(fabFinder);
      await tester.pumpAndSettle();

      expect(fabTriggered, isTrue);
      expect(selected, 4);
    });

    testWidgets('4. Folder mode updates FAB icon and semantic label',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: QuickNotesLiquidGlassTabBar(
                selectedIndex: 0,
                folderModeActive: true,
                onDestinationSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Plus icon should be rendered instead of pencil
      expect(find.byKey(const ValueKey('plus_icon')), findsOneWidget);
      expect(find.byKey(const ValueKey('pencil_icon')), findsNothing);

      // Semantics label should be 'Add folder'
      final addFolderSemantics = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Add folder',
      );
      expect(addFolderSemantics, findsOneWidget);
    });

    testWidgets('5. Safe disposal without ticker or controller leaks',
        (WidgetTester tester) async {
      bool mounted = true;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: mounted
                    ? QuickNotesLiquidGlassTabBar(
                        selectedIndex: 0,
                        onDestinationSelected: (_) {},
                      )
                    : const SizedBox.shrink(),
                floatingActionButton: FloatingActionButton(
                  onPressed: () => setState(() => mounted = false),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger disposal
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.byType(QuickNotesLiquidGlassTabBar), findsNothing);
      // Pump extra frames to confirm no orphan tickers run
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
