import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/views/widgets/app_bottom_navigation_bar.dart';
import 'package:quick_notes/views/widgets/liquid_glass_morph_container.dart';

void main() {
  Widget buildTestSubject({
    required bool isExpanded,
    Size collapsedSize = const Size(44.0, 44.0),
    Size expandedSize = const Size(192.0, 250.0),
    Alignment anchor = Alignment.topRight,
    VoidCallback? onTransitionEnd,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: LiquidGlassMorphContainer(
            isExpanded: isExpanded,
            collapsedSize: collapsedSize,
            expandedSize: expandedSize,
            anchor: anchor,
            onTransitionEnd: onTransitionEnd,
            collapsedChild: const SizedBox(
              key: ValueKey('collapsed_content'),
              child: Icon(Icons.more_horiz),
            ),
            expandedChild: const SizedBox(
              key: ValueKey('expanded_content'),
              child: Text('Menu Options'),
            ),
          ),
        ),
      ),
    );
  }

  group('LiquidGlassMorphContainer', () {
    testWidgets('1. Initial collapsed state renders at collapsedSize', (tester) async {
      await tester.pumpWidget(buildTestSubject(isExpanded: false));
      await tester.pumpAndSettle();

      final glassFinder = find.byType(BottomBarGlassSurface);
      expect(glassFinder, findsOneWidget);

      final Size glassSize = tester.getSize(glassFinder);
      expect(glassSize.width, closeTo(44.0, 0.5));
      expect(glassSize.height, closeTo(44.0, 0.5));

      expect(find.byKey(const ValueKey('collapsed_content')), findsOneWidget);
    });

    testWidgets('2. Target state can be resolved and morphs to expandedSize', (tester) async {
      bool isExpanded = false;
      bool transitionEnded = false;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return buildTestSubject(
              isExpanded: isExpanded,
              onTransitionEnd: () => transitionEnded = true,
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      // Trigger expansion
      isExpanded = true;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return buildTestSubject(
              isExpanded: isExpanded,
              onTransitionEnd: () => transitionEnded = true,
            );
          },
        ),
      );

      // Advance discrete frames past follow delay (40ms) into active expansion
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      final Size midSize = tester.getSize(find.byType(BottomBarGlassSurface));
      expect(midSize.width, greaterThan(44.0));

      // Settle completely
      await tester.pumpAndSettle();

      final Size finalSize = tester.getSize(find.byType(BottomBarGlassSurface));
      expect(finalSize.width, closeTo(192.0, 0.5));
      expect(finalSize.height, closeTo(250.0, 0.5));
      expect(find.byKey(const ValueKey('expanded_content')), findsOneWidget);
      expect(transitionEnded, isTrue);
    });

    testWidgets('3. Expanded -> compact transition collapses smoothly to collapsedSize', (tester) async {
      bool isExpanded = true;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return buildTestSubject(isExpanded: isExpanded);
          },
        ),
      );
      await tester.pumpAndSettle();

      final Size initialExpanded = tester.getSize(find.byType(BottomBarGlassSurface));
      expect(initialExpanded.width, closeTo(192.0, 0.5));

      // Trigger collapse
      isExpanded = false;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return buildTestSubject(isExpanded: isExpanded);
          },
        ),
      );

      // Advance mid-flight
      await tester.pump(const Duration(milliseconds: 60));
      final Size midSize = tester.getSize(find.byType(BottomBarGlassSurface));
      expect(midSize.width, lessThan(192.0));

      // Settle
      await tester.pumpAndSettle();
      final Size finalSize = tester.getSize(find.byType(BottomBarGlassSurface));
      expect(finalSize.width, closeTo(44.0, 0.5));
      expect(finalSize.height, closeTo(44.0, 0.5));
    });

    testWidgets('4. Adapts to arbitrary production layout dimensions with no hardcoded values', (tester) async {
      // Test arbitrary custom dimensions (e.g. 52x52 -> 210x180)
      const customCollapsed = Size(52.0, 52.0);
      const customExpanded = Size(210.0, 180.0);

      await tester.pumpWidget(
        buildTestSubject(
          isExpanded: false,
          collapsedSize: customCollapsed,
          expandedSize: customExpanded,
        ),
      );
      await tester.pumpAndSettle();

      final Size sizeCollapsed = tester.getSize(find.byType(BottomBarGlassSurface));
      expect(sizeCollapsed.width, closeTo(52.0, 0.5));
      expect(sizeCollapsed.height, closeTo(52.0, 0.5));

      // Expand with custom dimensions
      await tester.pumpWidget(
        buildTestSubject(
          isExpanded: true,
          collapsedSize: customCollapsed,
          expandedSize: customExpanded,
        ),
      );
      await tester.pumpAndSettle();

      final Size sizeExpanded = tester.getSize(find.byType(BottomBarGlassSurface));
      expect(sizeExpanded.width, closeTo(210.0, 0.5));
      expect(sizeExpanded.height, closeTo(180.0, 0.5));
    });

    testWidgets('5. Interruption mid-flight preserves continuity without teleporting', (tester) async {
      bool isExpanded = false;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return buildTestSubject(isExpanded: isExpanded);
          },
        ),
      );
      await tester.pumpAndSettle();

      // Start expansion
      isExpanded = true;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return buildTestSubject(isExpanded: isExpanded);
          },
        ),
      );

      // Advance ~80ms mid-flight
      await tester.pump(const Duration(milliseconds: 80));
      final Rect preInterruptRect = tester.getRect(find.byType(BottomBarGlassSurface));

      // Interrupt back to collapsed
      isExpanded = false;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return buildTestSubject(isExpanded: isExpanded);
          },
        ),
      );

      // One frame later: must NOT jump or teleport to 44.0 immediately
      await tester.pump(const Duration(milliseconds: 16));
      final Rect postInterruptRect = tester.getRect(find.byType(BottomBarGlassSurface));

      expect((postInterruptRect.width - preInterruptRect.width).abs(), lessThan(15.0));
      expect((postInterruptRect.height - preInterruptRect.height).abs(), lessThan(20.0));

      // Settle back to collapsed
      await tester.pumpAndSettle();
      final Size finalSize = tester.getSize(find.byType(BottomBarGlassSurface));
      expect(finalSize.width, closeTo(44.0, 0.5));
      expect(finalSize.height, closeTo(44.0, 0.5));
    });

    testWidgets('6. Ticker stops when settled (no persistent frame callbacks)', (tester) async {
      await tester.pumpWidget(buildTestSubject(isExpanded: false));
      await tester.pumpAndSettle();

      // When settled, no frames should be continuously scheduled
      expect(tester.binding.hasScheduledFrame, isFalse);

      await tester.pumpWidget(buildTestSubject(isExpanded: true));
      // Ticker is active during transition
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.binding.hasScheduledFrame, isTrue);

      // Settle
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('7. Disposal cleanly disposes ticker resources', (tester) async {
      await tester.pumpWidget(buildTestSubject(isExpanded: true));
      await tester.pump(const Duration(milliseconds: 50));

      // Unmount while animating
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });

    testWidgets('8. NoteEditorScreen full pill production morph (192x44 <-> 192x250, zero width delta)', (tester) async {
      const pillSize = Size(192.0, 44.0);
      const popupSize = Size(192.0, 250.0);

      bool isExpanded = false;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return buildTestSubject(
              isExpanded: isExpanded,
              collapsedSize: pillSize,
              expandedSize: popupSize,
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      final Size initialSize = tester.getSize(find.byType(BottomBarGlassSurface));
      expect(initialSize.width, closeTo(192.0, 0.5));
      expect(initialSize.height, closeTo(44.0, 0.5));

      // Expand to popup
      isExpanded = true;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return buildTestSubject(
              isExpanded: isExpanded,
              collapsedSize: pillSize,
              expandedSize: popupSize,
            );
          },
        ),
      );

      // Mid-flight: height expands while width stays locked at 192
      for (int i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      final Size midSize = tester.getSize(find.byType(BottomBarGlassSurface));
      expect(midSize.width, closeTo(192.0, 0.5));
      expect(midSize.height, greaterThan(50.0));

      // Settle at full popup
      await tester.pumpAndSettle();
      final Size expandedFinalSize = tester.getSize(find.byType(BottomBarGlassSurface));
      expect(expandedFinalSize.width, closeTo(192.0, 0.5));
      expect(expandedFinalSize.height, closeTo(250.0, 0.5));

      // Collapse back to full pill
      isExpanded = false;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return buildTestSubject(
              isExpanded: isExpanded,
              collapsedSize: pillSize,
              expandedSize: popupSize,
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      final Size collapsedFinalSize = tester.getSize(find.byType(BottomBarGlassSurface));
      expect(collapsedFinalSize.width, closeTo(192.0, 0.5));
      expect(collapsedFinalSize.height, closeTo(44.0, 0.5));
    });

    testWidgets('9. Continuous border-radius interpolation when width delta is zero', (tester) async {
      const pillSize = Size(192.0, 44.0);
      const popupSize = Size(192.0, 250.0);

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return buildTestSubject(
              isExpanded: false,
              collapsedSize: pillSize,
              expandedSize: popupSize,
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      // Collapsed radius is 22.0
      BottomBarGlassSurface glass = tester.widget<BottomBarGlassSurface>(find.byType(BottomBarGlassSurface));
      expect(glass.borderRadius, BorderRadius.circular(22.0));

      // Trigger expansion
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return buildTestSubject(
              isExpanded: true,
              collapsedSize: pillSize,
              expandedSize: popupSize,
            );
          },
        ),
      );

      // Step frames and observe smooth intermediate border radius values (no snap from 22 to 20!)
      final List<double> observedRadii = [];
      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        glass = tester.widget<BottomBarGlassSurface>(find.byType(BottomBarGlassSurface));
        final double r = glass.borderRadius.topLeft.x;
        observedRadii.add(r);
      }
      await tester.pumpAndSettle();

      // Settle radius is 20.0
      glass = tester.widget<BottomBarGlassSurface>(find.byType(BottomBarGlassSurface));
      expect(glass.borderRadius, BorderRadius.circular(20.0));

      // Verify that intermediate radii exist between 20.0 and 22.0
      final hasIntermediate = observedRadii.any((r) => r > 20.05 && r < 21.95);
      expect(hasIntermediate, isTrue, reason: 'Border radius must continuously interpolate, not snap');
    });

    testWidgets('10. Complete 5-element header row transitions cleanly without overflow', (tester) async {
      final fiveElementRow = Row(
        children: [
          const Expanded(child: Icon(Icons.undo_rounded, key: ValueKey('undo'))),
          const Expanded(child: Icon(Icons.redo_rounded, key: ValueKey('redo'))),
          Container(width: 1.0, height: 18.0, color: Colors.grey),
          const Expanded(child: Icon(Icons.folder_open, key: ValueKey('folder'))),
          const Expanded(child: Icon(Icons.more_horiz_rounded, key: ValueKey('options'))),
        ],
      );

      const optionsCard = Column(
        children: [
          Text('Pin Note'),
          Text('Add Favorite'),
          Text('Find in Note'),
          Text('Export & Share'),
          Text('Delete Note'),
        ],
      );

      bool isExpanded = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: StatefulBuilder(
                builder: (context, setState) {
                  return LiquidGlassMorphContainer(
                    isExpanded: isExpanded,
                    collapsedSize: const Size(192.0, 44.0),
                    expandedSize: const Size(192.0, 250.0),
                    collapsedBorderRadius: BorderRadius.circular(22.0),
                    expandedBorderRadius: BorderRadius.circular(20.0),
                    anchor: Alignment.topRight,
                    collapsedChild: fiveElementRow,
                    expandedChild: optionsCard,
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial: row is present
      expect(find.byKey(const ValueKey('undo')), findsOneWidget);
      expect(find.byKey(const ValueKey('options')), findsOneWidget);
      expect(find.text('Pin Note'), findsNothing);

      // Expand
      isExpanded = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: StatefulBuilder(
                builder: (context, setState) {
                  return LiquidGlassMorphContainer(
                    isExpanded: isExpanded,
                    collapsedSize: const Size(192.0, 44.0),
                    expandedSize: const Size(192.0, 250.0),
                    collapsedBorderRadius: BorderRadius.circular(22.0),
                    expandedBorderRadius: BorderRadius.circular(20.0),
                    anchor: Alignment.topRight,
                    collapsedChild: fiveElementRow,
                    expandedChild: optionsCard,
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Expanded: options card present, no overflow
      expect(find.text('Pin Note'), findsOneWidget);
      expect(find.text('Delete Note'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
