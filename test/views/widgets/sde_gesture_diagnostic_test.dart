import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/views/widgets/new_single_document_editor.dart';
import 'package:quick_notes/views/widgets/rich_text_controller.dart';
import 'package:quick_notes/views/widgets/single_document_drag_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestableEditorWithOverlay({
    required RichTextEditingController controller,
    required FocusNode focusNode,
    required GlobalKey<NewSingleDocumentEditorState> sdeKey,
    ScrollController? scrollController,
    bool isSelectionMode = true,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleDocumentDragOverlay(
          controller: controller,
          sdeKey: sdeKey,
          scrollController: scrollController,
          isSelectionMode: isSelectionMode,
          child: NewSingleDocumentEditor(
            key: sdeKey,
            controller: controller,
            focusNode: focusNode,
            textColor: Colors.black,
            paperGuideHeight: 1.0,
            formattingToolbarHeight: 0.0,
            contextMenuBuilder: (context, editableTextState) {
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }

  group('SDE Interaction & Timing Diagnostics', () {
    late RichTextEditingController controller;
    late FocusNode focusNode;
    late GlobalKey<NewSingleDocumentEditorState> sdeKey;

    setUp(() {
      controller = RichTextEditingController();
      focusNode = FocusNode();
      sdeKey = GlobalKey<NewSingleDocumentEditorState>();
    });

    tearDown(() {
      controller.dispose();
      focusNode.dispose();
    });

    testWidgets(
        'EXPERIMENT 1: Short tap (finger lifted at 100ms) - observing selection and timer behavior',
        (tester) async {
      controller.text =
          'QuickNotes SDE gesture disambiguation and selection testing';
      await tester.pumpWidget(
        buildTestableEditorWithOverlay(
          controller: controller,
          focusNode: focusNode,
          sdeKey: sdeKey,
        ),
      );
      await tester.pumpAndSettle();

      final firstText = find.byType(TextField).first;
      expect(firstText, findsOneWidget);

      final center = tester.getCenter(firstText);

      // Perform a pointer down, wait 80ms, then pointer up
      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 80));
      await gesture.up();
      await tester.pump();

      // Check selection immediately after tap
      final selAfterUp = controller.selection;
      debugPrint(
          '[TEST LOG] Selection immediately after pointer up: $selAfterUp');

      // Now pump across the 200ms boundary (another 150ms -> total 230ms since down)
      await tester.pump(const Duration(milliseconds: 150));
      final selAfter230ms = controller.selection;
      debugPrint(
          '[TEST LOG] Selection after 230ms (past 200ms threshold): $selAfter230ms');

      // Now pump another 200ms
      await tester.pump(const Duration(milliseconds: 200));
      final selAfter430ms = controller.selection;
      debugPrint('[TEST LOG] Selection after 430ms: $selAfter430ms');
    });

    testWidgets(
        'EXPERIMENT 2: Hold between 200ms and 500ms (e.g. 250ms press) - does not trigger long press prematurely (SDE-001)',
        (tester) async {
      controller.text = 'QuickNotes SDE premature long-press testing';
      await tester.pumpWidget(
        buildTestableEditorWithOverlay(
          controller: controller,
          focusNode: focusNode,
          sdeKey: sdeKey,
        ),
      );
      await tester.pumpAndSettle();

      final firstText = find.byType(TextField).first;
      final center = tester.getCenter(firstText);

      // Press down at 0ms, hold for 220ms (well under standard 500ms kLongPressTimeout)
      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 220));

      final selAt220ms = controller.selection;
      debugPrint('[TEST LOG] Selection during 220ms hold: $selAt220ms');

      expect(selAt220ms.isCollapsed, isTrue,
          reason:
              'At 220ms, selection remains collapsed since threshold is kLongPressTimeout (500ms)');

      // Hold past 500ms to verify deliberate long-press still triggers selection
      await tester.pump(const Duration(milliseconds: 330));
      final selAt550ms = controller.selection;
      expect(selAt550ms.isCollapsed, isFalse,
          reason: 'At 550ms (>500ms), word selection triggers as intended');

      await gesture.up();
      await tester.pump();
    });

    testWidgets(
        'EXPERIMENT 3: Drag / Scroll vs LongPress - movement within 12px threshold',
        (tester) async {
      controller.text = 'Line 1\nLine 2\nLine 3\nLine 4\nLine 5\nLine 6';
      await tester.pumpWidget(
        buildTestableEditorWithOverlay(
          controller: controller,
          focusNode: focusNode,
          sdeKey: sdeKey,
        ),
      );
      await tester.pumpAndSettle();

      final firstText = find.byType(TextField).first;
      final center = tester.getCenter(firstText);

      // Slow scroll drag: pointer moves only 5 pixels in first 200ms
      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveBy(
          const Offset(0, 5)); // 5px movement (less than 12px threshold)
      await tester.pump(const Duration(milliseconds: 160)); // at 210ms

      final selDuringSlowDrag = controller.selection;
      debugPrint(
          '[TEST LOG] Selection during slow drag at 210ms: $selDuringSlowDrag');

      expect(selDuringSlowDrag.isCollapsed, isTrue,
          reason:
              'Slow scroll drag does not trigger word selection at 200ms with SDE-001 fixed');

      await gesture.up();
      await tester.pump();
    });
  });
}
