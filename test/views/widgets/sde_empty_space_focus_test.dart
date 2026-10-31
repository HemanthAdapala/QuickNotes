import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/views/widgets/new_single_document_editor.dart';
import 'package:quick_notes/views/widgets/rich_text_controller.dart';
import 'package:quick_notes/views/widgets/single_document_drag_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildEditorWithTitle({
    required RichTextEditingController contentController,
    required FocusNode contentFocusNode,
    required TextEditingController titleController,
    required FocusNode titleFocusNode,
    required GlobalKey<NewSingleDocumentEditorState> sdeKey,
    ScrollController? scrollController,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleDocumentDragOverlay(
          controller: contentController,
          sdeKey: sdeKey,
          scrollController: scrollController,
          isSelectionMode: true,
          child: NewSingleDocumentEditor(
            key: sdeKey,
            controller: contentController,
            focusNode: contentFocusNode,
            scrollController: scrollController,
            textColor: Colors.black,
            paperGuideHeight: 1.0,
            formattingToolbarHeight: 0.0,
            header: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: FocusScope(
                child: TextField(
                  key: const ValueKey('title_field'),
                  controller: titleController,
                  focusNode: titleFocusNode,
                  decoration: const InputDecoration(hintText: 'Title'),
                ),
              ),
            ),
            contextMenuBuilder: (context, editableTextState) =>
                const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  group('Phase 11 — SDE Empty-Space Focus Regression Suite', () {
    late RichTextEditingController contentController;
    late FocusNode contentFocusNode;
    late TextEditingController titleController;
    late FocusNode titleFocusNode;
    late GlobalKey<NewSingleDocumentEditorState> sdeKey;
    late ScrollController scrollController;

    setUp(() {
      contentController = RichTextEditingController();
      contentFocusNode = FocusNode();
      titleController = TextEditingController();
      titleFocusNode = FocusNode();
      sdeKey = GlobalKey<NewSingleDocumentEditorState>();
      scrollController = ScrollController();
    });

    tearDown(() {
      contentController.dispose();
      contentFocusNode.dispose();
      titleController.dispose();
      titleFocusNode.dispose();
      scrollController.dispose();
    });

    // 1. Empty body + tap directly on "Start writing..." hint
    testWidgets(
        '1. Empty body: Tap directly on "Start writing..." hint requests focus on Segment 0 and sets caret at offset 0',
        (tester) async {
      await tester.pumpWidget(
        buildEditorWithTitle(
          contentController: contentController,
          contentFocusNode: contentFocusNode,
          titleController: titleController,
          titleFocusNode: titleFocusNode,
          sdeKey: sdeKey,
          scrollController: scrollController,
        ),
      );
      await tester.pumpAndSettle();

      final sdeState = sdeKey.currentState!;
      expect(sdeState.textSegments.length, 1);
      final seg0Focus = sdeState.focusNodes[0]!;
      expect(seg0Focus.hasFocus, isFalse);

      // Tap directly on the Segment 0 TextField (rendering "Start writing...")
      final bodyField = find.byType(TextField).last;
      await tester.tap(bodyField);
      await tester.pumpAndSettle();

      expect(seg0Focus.hasFocus, isTrue);
      expect(contentController.selection.isCollapsed, isTrue);
      expect(contentController.selection.baseOffset, 0);
    });

    // 2. Empty body + tap far below the hint in distant blank space
    testWidgets(
        '2. Empty body: Tap in distant blank space far below the hint does NOT focus Segment 0',
        (tester) async {
      await tester.pumpWidget(
        buildEditorWithTitle(
          contentController: contentController,
          contentFocusNode: contentFocusNode,
          titleController: titleController,
          titleFocusNode: titleFocusNode,
          sdeKey: sdeKey,
          scrollController: scrollController,
        ),
      );
      await tester.pumpAndSettle();

      final sdeState = sdeKey.currentState!;
      final seg0Focus = sdeState.focusNodes[0]!;
      expect(seg0Focus.hasFocus, isFalse);

      // Find the hint line rect
      final bodyField = find.byType(TextField).last;
      final bodyRect = tester.getRect(bodyField);

      // Tap 200px below the bottom of the hint line (distant empty space)
      final distantEmptyPos =
          Offset(bodyRect.center.dx, bodyRect.bottom + 200.0);
      await tester.tapAt(distantEmptyPos);
      await tester.pumpAndSettle();

      // Body segment must NOT receive focus
      expect(seg0Focus.hasFocus, isFalse);
      expect(contentFocusNode.hasFocus, isFalse);
    });

    // 3. Title focused + tap distant blank body space preserves title focus
    testWidgets(
        '3. Title focused: Tap in distant blank body space does not trigger SDE focus or steal title focus',
        (tester) async {
      await tester.pumpWidget(
        buildEditorWithTitle(
          contentController: contentController,
          contentFocusNode: contentFocusNode,
          titleController: titleController,
          titleFocusNode: titleFocusNode,
          sdeKey: sdeKey,
          scrollController: scrollController,
        ),
      );
      await tester.pumpAndSettle();

      final sdeState = sdeKey.currentState!;
      final seg0Focus = sdeState.focusNodes[0]!;

      // Focus the title field and enter text
      final titleField = find.byType(TextField).first;
      await tester.tap(titleField);
      await tester.pumpAndSettle();
      await tester.enterText(titleField, 'My Great Note Title');
      await tester.pumpAndSettle();

      expect(titleFocusNode.hasFocus, isTrue);
      expect(seg0Focus.hasFocus, isFalse);

      // Tap 250px below the hint in distant blank space
      final bodyField = find.byType(TextField).last;
      final bodyRect = tester.getRect(bodyField);
      final distantEmptyPos =
          Offset(bodyRect.center.dx, bodyRect.bottom + 250.0);

      await tester.tapAt(distantEmptyPos);
      await tester.pumpAndSettle();

      // SDE must NOT gain focus or change selection
      expect(seg0Focus.hasFocus, isFalse);
      expect(contentFocusNode.hasPrimaryFocus, isFalse);
      expect(titleFocusNode.hasPrimaryFocus, isTrue);
      expect(contentController.selection.isValid, isFalse);
      expect(titleController.text, 'My Great Note Title');
    });

    // 4. Existing body text + tap within rendered text places caret and focuses segment
    testWidgets(
        '4. Existing body text: Tap within rendered text places caret and focuses segment',
        (tester) async {
      contentController.text = 'First line of content\nSecond line of content';
      await tester.pumpWidget(
        buildEditorWithTitle(
          contentController: contentController,
          contentFocusNode: contentFocusNode,
          titleController: titleController,
          titleFocusNode: titleFocusNode,
          sdeKey: sdeKey,
          scrollController: scrollController,
        ),
      );
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      // textFields has title + 2 segments
      expect(textFields, findsNWidgets(3));

      // Tap the second line
      final secondLineField = textFields.at(2);
      await tester.tap(secondLineField);
      await tester.pumpAndSettle();

      final sdeState = sdeKey.currentState!;
      expect(sdeState.focusNodes[1]?.hasFocus, isTrue);
      expect(contentController.selection.isValid, isTrue);
      expect(contentController.selection.isCollapsed, isTrue);
    });

    // 5. Existing body text + tap immediately below content continues at end without offset 0 jump
    testWidgets(
        '5. Existing body text: Tap immediately below content places caret at document end, never at offset 0',
        (tester) async {
      contentController.text = 'Hello Quick Notes';
      await tester.pumpWidget(
        buildEditorWithTitle(
          contentController: contentController,
          contentFocusNode: contentFocusNode,
          titleController: titleController,
          titleFocusNode: titleFocusNode,
          sdeKey: sdeKey,
          scrollController: scrollController,
        ),
      );
      await tester.pumpAndSettle();

      final bodyField = find.byType(TextField).last;
      final bodyRect = tester.getRect(bodyField);

      // Tap 15px below the last line (within the adjacent 48px hit target)
      final nearEndPos = Offset(bodyRect.center.dx, bodyRect.bottom + 15.0);
      await tester.tapAt(nearEndPos);
      await tester.pumpAndSettle();

      final sdeState = sdeKey.currentState!;
      expect(sdeState.focusNodes[0]?.hasFocus, isTrue);
      expect(contentController.selection.baseOffset,
          contentController.text.length);
      expect(contentController.selection.baseOffset, 17);
    });

    // 6. Already-focused body + tap to reposition caret preserves focus
    testWidgets(
        '6. Already-focused body: Tap repositions caret while preserving existing focus without flicker',
        (tester) async {
      contentController.text = 'Quick Brown Fox Jumps Over The Lazy Dog';
      await tester.pumpWidget(
        buildEditorWithTitle(
          contentController: contentController,
          contentFocusNode: contentFocusNode,
          titleController: titleController,
          titleFocusNode: titleFocusNode,
          sdeKey: sdeKey,
          scrollController: scrollController,
        ),
      );
      await tester.pumpAndSettle();

      final bodyField = find.byType(TextField).last;
      await tester.tap(bodyField);
      await tester.pumpAndSettle();

      final sdeState = sdeKey.currentState!;
      expect(sdeState.focusNodes[0]?.hasFocus, isTrue);

      // Tap at a different position in the same body field
      final bodyRect = tester.getRect(bodyField);
      await tester.tapAt(Offset(bodyRect.left + 50.0, bodyRect.center.dy));
      await tester.pumpAndSettle();

      // Focus must remain on the segment
      expect(sdeState.focusNodes[0]?.hasFocus, isTrue);
      expect(contentController.selection.isCollapsed, isTrue);
    });

    // 7. Deliberate long press triggers word selection
    testWidgets(
        '7. Deliberate long press: Holding for >= 500ms triggers word selection',
        (tester) async {
      contentController.text = 'Alpha Beta Gamma';
      await tester.pumpWidget(
        buildEditorWithTitle(
          contentController: contentController,
          contentFocusNode: contentFocusNode,
          titleController: titleController,
          titleFocusNode: titleFocusNode,
          sdeKey: sdeKey,
          scrollController: scrollController,
        ),
      );
      await tester.pumpAndSettle();

      final bodyField = find.byType(TextField).last;
      final center = tester.getCenter(bodyField);

      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 550));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(contentController.selection.isCollapsed, isFalse);
      expect(contentController.selection.textInside(contentController.text),
          isNotEmpty);
    });

    // 8. Slow scroll over empty body does not trigger focus
    testWidgets(
        '8. Scrolling: Dragging across the empty body does not trigger focus or keyboard',
        (tester) async {
      await tester.pumpWidget(
        buildEditorWithTitle(
          contentController: contentController,
          contentFocusNode: contentFocusNode,
          titleController: titleController,
          titleFocusNode: titleFocusNode,
          sdeKey: sdeKey,
          scrollController: scrollController,
        ),
      );
      await tester.pumpAndSettle();

      final sdeState = sdeKey.currentState!;
      final seg0Focus = sdeState.focusNodes[0]!;

      final bodyField = find.byType(TextField).last;
      final startPos = tester.getCenter(bodyField);

      // Drag downwards by 50px
      final gesture = await tester.startGesture(startPos);
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveBy(const Offset(0, 50));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(seg0Focus.hasFocus, isFalse);
    });

    // 9. Pointer cancellation does not trigger delayed focus request
    testWidgets(
        '9. Pointer cancellation: Cancelled pointer does not leave focus gated or fire delayed focus',
        (tester) async {
      await tester.pumpWidget(
        buildEditorWithTitle(
          contentController: contentController,
          contentFocusNode: contentFocusNode,
          titleController: titleController,
          titleFocusNode: titleFocusNode,
          sdeKey: sdeKey,
          scrollController: scrollController,
        ),
      );
      await tester.pumpAndSettle();

      final sdeState = sdeKey.currentState!;
      final seg0Focus = sdeState.focusNodes[0]!;

      final bodyField = find.byType(TextField).last;
      final gesture = await tester.startGesture(tester.getCenter(bodyField));
      await tester.pump(const Duration(milliseconds: 50));

      // Cancel the gesture pointer
      await gesture.cancel();
      await tester.pumpAndSettle();

      expect(seg0Focus.hasFocus, isFalse);
    });

    // 10. Continue typing at the end of a non-empty note
    testWidgets(
        '10. Continue typing: Tap at the end of a non-empty note enables appending text',
        (tester) async {
      contentController.text = 'Line 1\nLine 2';
      await tester.pumpWidget(
        buildEditorWithTitle(
          contentController: contentController,
          contentFocusNode: contentFocusNode,
          titleController: titleController,
          titleFocusNode: titleFocusNode,
          sdeKey: sdeKey,
          scrollController: scrollController,
        ),
      );
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      final lastLineField = textFields.last;
      final lastLineRect = tester.getRect(lastLineField);

      // Tap 10px below the last line
      await tester
          .tapAt(Offset(lastLineRect.center.dx, lastLineRect.bottom + 10.0));
      await tester.pumpAndSettle();

      final sdeState = sdeKey.currentState!;
      expect(sdeState.focusNodes[1]?.hasFocus, isTrue);
      expect(contentController.selection.baseOffset, 13);

      // Enter additional text
      await tester.enterText(lastLineField, 'Line 2 updated');
      await tester.pumpAndSettle();

      expect(contentController.text, 'Line 1\nLine 2updated');
    });
  });
}
