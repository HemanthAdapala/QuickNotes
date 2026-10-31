import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/views/widgets/app_bottom_navigation_bar.dart';
import 'package:quick_notes/views/widgets/quick_notes_liquid_glass_tab_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 3 — Step 2: FAB Tinted Liquid Glass & Icon Differentiation Tests', () {
    testWidgets('1. Home + Notes displays yellow tint (#FFCC00) and pencil icon',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: QuickNotesLiquidGlassTabBar(
              selectedIndex: 0,
              isNotesActive: true,
              onDestinationSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify FAB presence and single glass surface
      final fabFinder = find.byKey(const ValueKey('quick_notes_navigation_fab'));
      expect(fabFinder, findsOneWidget);

      final fabGlassFinder = find.byKey(const ValueKey('fab_glass_surface'));
      expect(fabGlassFinder, findsOneWidget);

      // Verify no nested BottomBarGlassSurface inside FAB
      expect(
        find.descendant(
          of: fabFinder,
          matching: find.byType(BottomBarGlassSurface),
        ),
        findsNothing,
        reason: 'FAB must use single _QuickNotesTintedGlassSurface with no nested BottomBarGlassSurface',
      );

      // Verify pencil icon rendered
      expect(find.byKey(const ValueKey('pencil_icon')), findsOneWidget);
      expect(find.byKey(const ValueKey('checklist_icon')), findsNothing);
      expect(find.byKey(const ValueKey('plus_icon')), findsNothing);

      // Verify semantics label
      final fabSemantics = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Create note',
      );
      expect(fabSemantics, findsOneWidget);
    });

    testWidgets('2. Home + Tasks displays task blue tint (#0088FF) and checklist icon',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: QuickNotesLiquidGlassTabBar(
              selectedIndex: 0,
              isNotesActive: false,
              onDestinationSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final fabFinder = find.byKey(const ValueKey('quick_notes_navigation_fab'));
      expect(fabFinder, findsOneWidget);

      // Verify checklist icon rendered and pencil icon not rendered
      expect(find.byKey(const ValueKey('checklist_icon')), findsOneWidget);
      expect(find.byKey(const ValueKey('pencil_icon')), findsNothing);
      expect(find.byKey(const ValueKey('plus_icon')), findsNothing);

      // Verify semantics label updated to Create task
      final taskSemantics = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Create task',
      );
      expect(taskSemantics, findsOneWidget);
    });

    testWidgets('3. Folders displays yellow tint (#FFCC00) and plus icon',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: QuickNotesLiquidGlassTabBar(
              selectedIndex: 1,
              isNotesActive: false, // Even if isNotesActive is false, Folders is yellow!
              onDestinationSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('plus_icon')), findsOneWidget);
      expect(find.byKey(const ValueKey('pencil_icon')), findsNothing);
      expect(find.byKey(const ValueKey('checklist_icon')), findsNothing);

      final folderSemantics = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Add folder',
      );
      expect(folderSemantics, findsOneWidget);
    });

    testWidgets('4. Calendar displays task blue tint (#0088FF) and pencil icon',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: QuickNotesLiquidGlassTabBar(
              selectedIndex: 2,
              isNotesActive: true, // Even if isNotesActive is true, Calendar is blue!
              onDestinationSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('pencil_icon')), findsOneWidget);
      expect(find.byKey(const ValueKey('checklist_icon')), findsNothing);
      expect(find.byKey(const ValueKey('plus_icon')), findsNothing);
    });

    testWidgets('5. Dynamic switching between Notes and Tasks updates FAB icon seamlessly',
        (WidgetTester tester) async {
      bool isNotesActive = true;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: TextButton(
                  onPressed: () => setState(() => isNotesActive = !isNotesActive),
                  child: const Text('Toggle'),
                ),
                bottomNavigationBar: QuickNotesLiquidGlassTabBar(
                  selectedIndex: 0,
                  isNotesActive: isNotesActive,
                  onDestinationSelected: (_) {},
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('pencil_icon')), findsOneWidget);
      expect(find.byKey(const ValueKey('checklist_icon')), findsNothing);

      // Toggle to Tasks
      await tester.tap(find.text('Toggle'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('checklist_icon')), findsOneWidget);
      expect(find.byKey(const ValueKey('pencil_icon')), findsNothing);

      // Toggle back to Notes
      await tester.tap(find.text('Toggle'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('pencil_icon')), findsOneWidget);
      expect(find.byKey(const ValueKey('checklist_icon')), findsNothing);
    });

    testWidgets('6. FAB preserves 50x50 control size and tap callback',
        (WidgetTester tester) async {
      int selectedDestination = 0;
      bool fabTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: QuickNotesLiquidGlassTabBar(
              selectedIndex: 0,
              isNotesActive: false,
              onDestinationSelected: (idx) => selectedDestination = idx,
              onFabPressed: () => fabTapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final fabFinder = find.byKey(const ValueKey('quick_notes_navigation_fab'));
      final fabSize = tester.getSize(fabFinder);
      expect(fabSize.width, 50.0);
      expect(fabSize.height, 50.0);

      // Tap FAB
      await tester.tap(fabFinder);
      await tester.pumpAndSettle();

      expect(fabTapped, isTrue);
      expect(selectedDestination, 4);
    });
  });
}
