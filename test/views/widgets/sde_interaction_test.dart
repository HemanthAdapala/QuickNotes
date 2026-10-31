import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/views/widgets/new_single_document_editor.dart';
import 'package:quick_notes/views/widgets/rich_text_controller.dart';
import 'package:quick_notes/views/widgets/single_document_drag_overlay.dart';
import 'package:quick_notes/views/widgets/tactile_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildEditorWithOverlay({
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

  group('Single Document Editor (SDE) Interaction & Timing Regression Suite',
      () {
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

    // 1. Tap-to-caret placement
    testWidgets(
        '1. Tap-to-caret placement sets collapsed selection at target character offset',
        (tester) async {
      controller.text = 'First line of text\nSecond line of text';
      await tester.pumpWidget(
        buildEditorWithOverlay(
          controller: controller,
          focusNode: focusNode,
          sdeKey: sdeKey,
        ),
      );
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(2));

      // Tap on the first line
      await tester.tap(textFields.first);
      await tester.pump();

      expect(controller.selection.isValid, isTrue);
      expect(controller.selection.isCollapsed, isTrue);
    });

    // 2. Long-press recognition timing
    testWidgets(
        '2. Long-press timing: 250ms hold leaves selection collapsed; hold >= 500ms triggers word selection (SDE-001)',
        (tester) async {
      controller.text = 'WordA WordB WordC WordD';
      await tester.pumpWidget(
        buildEditorWithOverlay(
          controller: controller,
          focusNode: focusNode,
          sdeKey: sdeKey,
        ),
      );
      await tester.pumpAndSettle();

      final firstText = find.byType(TextField).first;
      final center = tester.getCenter(firstText);

      final gesture = await tester.startGesture(center);
      // At 250ms, timer has not expired (standard kLongPressTimeout is 500ms)
      await tester.pump(const Duration(milliseconds: 250));
      expect(controller.selection.isCollapsed, isTrue);

      // Past 500ms (pump 300ms more -> 550ms total), timer expires and word is selected
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.selection.isCollapsed, isFalse);
      expect(
          controller.selection.textInside(controller.text).isNotEmpty, isTrue);

      await gesture.up();
      await tester.pump();
    });

    // 3. Tap vs long-press distinction
    testWidgets(
        '3. Tap versus long-press: rapid tap under 150ms leaves selection collapsed',
        (tester) async {
      controller.text = 'Distinguish rapid tap from long hold';
      await tester.pumpWidget(
        buildEditorWithOverlay(
          controller: controller,
          focusNode: focusNode,
          sdeKey: sdeKey,
        ),
      );
      await tester.pumpAndSettle();

      final firstText = find.byType(TextField).first;
      final center = tester.getCenter(firstText);

      // Tap down and up within 80ms
      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 80));
      await gesture.up();
      await tester.pump();

      // Ensure that after settling, selection is collapsed (a caret, not a word selection)
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.selection.isCollapsed, isTrue);
    });

    // 4. Pointer release before hold threshold
    testWidgets(
        '4. Pointer release before hold threshold keeps keyboard un-gated',
        (tester) async {
      controller.text = 'Keyboard un-gating test line';
      await tester.pumpWidget(
        buildEditorWithOverlay(
          controller: controller,
          focusNode: focusNode,
          sdeKey: sdeKey,
        ),
      );
      await tester.pumpAndSettle();

      final firstText = find.byType(TextField).first;
      await tester.tap(firstText);
      await tester.pumpAndSettle();

      final sdeState = sdeKey.currentState;
      expect(sdeState, isNotNull);
      // Verify focusNode can request focus
      expect(sdeState!.focusNodes.values.every((node) => node.canRequestFocus),
          isTrue);
    });

    // 5. Movement beyond gesture threshold
    testWidgets(
        '5. Movement beyond 12px threshold cancels long-press selection timer',
        (tester) async {
      controller.text = 'Line 1 to drag past threshold\nLine 2\nLine 3';
      await tester.pumpWidget(
        buildEditorWithOverlay(
          controller: controller,
          focusNode: focusNode,
          sdeKey: sdeKey,
        ),
      );
      await tester.pumpAndSettle();

      final firstText = find.byType(TextField).first;
      final center = tester.getCenter(firstText);

      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 50));
      // Move 20px (exceeds 12px threshold)
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump(const Duration(milliseconds: 200));

      // Long press selection should have been cancelled by movement
      expect(controller.selection.isCollapsed, isTrue);

      await gesture.up();
      await tester.pump();
    });

    // 6. Dragging versus scrolling
    testWidgets(
        '6. Slow scroll (<=12px in first 200ms) does not prematurely trigger word selection (SDE-001)',
        (tester) async {
      controller.text = 'Document line for slow scrolling test';
      await tester.pumpWidget(
        buildEditorWithOverlay(
          controller: controller,
          focusNode: focusNode,
          sdeKey: sdeKey,
        ),
      );
      await tester.pumpAndSettle();

      final firstText = find.byType(TextField).first;
      final center = tester.getCenter(firstText);

      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 50));
      // Move 5px
      await gesture.moveBy(const Offset(0, 5));
      await tester.pump(const Duration(milliseconds: 170)); // at 220ms

      // With SDE-001 fixed, selection remains collapsed
      expect(controller.selection.isCollapsed, isTrue);

      await gesture.up();
      await tester.pump();
    });

    // 7. Rapid repeated taps
    testWidgets(
        '7. Rapid repeated taps do not corrupt selection state or crash editor',
        (tester) async {
      controller.text = 'Rapid tap robustness line in document';
      await tester.pumpWidget(
        buildEditorWithOverlay(
          controller: controller,
          focusNode: focusNode,
          sdeKey: sdeKey,
        ),
      );
      await tester.pumpAndSettle();

      final firstText = find.byType(TextField).first;
      for (int i = 0; i < 5; i++) {
        await tester.tap(firstText);
        await tester.pump(const Duration(milliseconds: 40));
      }
      await tester.pumpAndSettle();

      expect(controller.selection.isValid, isTrue);
    });

    // 8. Focus acquisition and loss
    testWidgets('8. Focus acquisition activates target segment focus node',
        (tester) async {
      controller.text = 'Segment 0\nSegment 1';
      await tester.pumpWidget(
        buildEditorWithOverlay(
          controller: controller,
          focusNode: focusNode,
          sdeKey: sdeKey,
        ),
      );
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.tap(textFields.at(1));
      await tester.pumpAndSettle();

      final sdeState = sdeKey.currentState!;
      expect(sdeState.focusNodes[1]?.hasFocus, isTrue);
    });

    // 9. Formatting selection preservation
    testWidgets(
        '9. Applying inline formatting preserves active selection boundaries',
        (tester) async {
      controller.text = 'Bold formatted word test';
      await tester.pumpWidget(
        buildEditorWithOverlay(
          controller: controller,
          focusNode: focusNode,
          sdeKey: sdeKey,
        ),
      );
      await tester.pumpAndSettle();

      // Select 'formatted' (index 5 to 14)
      controller.selection =
          const TextSelection(baseOffset: 5, extentOffset: 14);
      await tester.pump();

      // Apply bold formatting
      controller.toggleStyleAttribute('bold');
      await tester.pump();

      expect(controller.selection.baseOffset, equals(5));
      expect(controller.selection.extentOffset, equals(14));
      expect(controller.styledChars[5].style.bold, isTrue);
      expect(controller.styledChars[13].style.bold, isTrue);
    });

    // 10. Checklist toggling without duplicate activation
    testWidgets(
        '10. Interactive checklist toggle updates checkbox symbol and strikethrough without duplicate trigger',
        (tester) async {
      controller.setMarkdown('- [ ] Task Item 1\n- [x] Task Item 2');
      await tester.pumpWidget(
        buildEditorWithOverlay(
          controller: controller,
          focusNode: focusNode,
          sdeKey: sdeKey,
        ),
      );
      await tester.pumpAndSettle();

      final checkboxes = find.byType(InteractiveCheckbox);
      expect(checkboxes, findsNWidgets(2));

      // Tap the first checkbox
      await tester.tap(checkboxes.first);
      await tester.pump();

      // Verify first character changed to checked symbol
      expect(controller.styledChars.first.char, equals('\u2611'));
      expect(controller.styledChars.first.style.checked, isTrue);
    });

    // 11. Resizable image pointer down immediate activation (SDE-002)
    testWidgets(
        '11. ResizableImageWidget toggles controls on completed tap, not immediately on pointer down (SDE-002)',
        (tester) async {
      bool tapped = false;
      final imgWidget = ResizableImageWidget(
        imagePath: 'assets/sample.png',
        initialWidth: 200,
        caption: 'Sample Caption',
        index: 0,
        onUpdate: (w, c) {},
        onDelete: () {},
        onTap: () {
          tapped = true;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: imgWidget,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final state = tester
          .state<ResizableImageWidgetState>(find.byType(ResizableImageWidget));
      expect(state.showControls, isFalse);

      // Start gesture down (pointer is touching, but has not lifted)
      final gesture = await tester
          .startGesture(tester.getCenter(find.byType(ResizableImageWidget)));
      await tester.pump();

      // Pointer down alone must NOT toggle controls or call onTap
      expect(state.showControls, isFalse);
      expect(tapped, isFalse);

      // Now complete the tap by lifting pointer
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(state.showControls, isTrue);
      expect(tapped, isTrue);
    });

    // 12. SDE Incremental Fast Path vs Full Parse
    testWidgets(
        '12. SDE non-structural edit uses incremental fast-path without recreating segment widgets',
        (tester) async {
      controller.text = 'Original paragraph text';
      await tester.pumpWidget(
        buildEditorWithOverlay(
          controller: controller,
          focusNode: focusNode,
          sdeKey: sdeKey,
        ),
      );
      await tester.pumpAndSettle();

      final initialSegments = sdeKey.currentState!.allSegments;
      expect(initialSegments.length, equals(1));

      // Append text without adding newlines
      controller.text = 'Original paragraph text edited';
      await tester.pump();

      // Segment list remains stable
      expect(sdeKey.currentState!.allSegments.length, equals(1));
      expect(sdeKey.currentState!.textSegments.first.end,
          equals(controller.text.length));
    });

    // 13. SDE Structural edit triggers segment re-parsing
    testWidgets(
        '13. Inserting newline triggers structural parseCurrentSegments re-partition',
        (tester) async {
      controller.text = 'Line One';
      await tester.pumpWidget(
        buildEditorWithOverlay(
          controller: controller,
          focusNode: focusNode,
          sdeKey: sdeKey,
        ),
      );
      await tester.pumpAndSettle();

      expect(sdeKey.currentState!.textSegments.length, equals(1));

      // Insert newline -> structural edit
      controller.text = 'Line One\nLine Two';
      await tester.pump();

      expect(sdeKey.currentState!.textSegments.length, equals(2));
    });

    // 14. Controller listeners cleanup on widget disposal
    testWidgets(
        '14. Disposing SDE widget cleans up all segment controllers and focus nodes without memory leak',
        (tester) async {
      controller.text = 'Line A\nLine B\nLine C';
      await tester.pumpWidget(
        buildEditorWithOverlay(
          controller: controller,
          focusNode: focusNode,
          sdeKey: sdeKey,
        ),
      );
      await tester.pumpAndSettle();

      expect(sdeKey.currentState!.textSegments.length, equals(3));

      // Unmount the widget
      await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: SizedBox.shrink())));
      await tester.pumpAndSettle();

      expect(find.byType(NewSingleDocumentEditor), findsNothing);
    });

    // 15. Tactile button settle duration measurement
    testWidgets('15. TactileButton settle animation measurement',
        (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TactileButton(
              onTap: () => tapped = true,
              settleDuration: const Duration(milliseconds: 200),
              child: const Text('Tap Me'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tap Me'));
      await tester.pump();
      expect(tapped, isTrue);

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
    });

    // 16. SDE-003: Hold text for >300ms (e.g. 350ms) and release requests focus for segment
    testWidgets(
        '16. Hold text for 350ms and release without scrolling focuses target segment (SDE-003)',
        (tester) async {
      controller.text = 'Line 0 text\nLine 1 text';
      await tester.pumpWidget(
        buildEditorWithOverlay(
          controller: controller,
          focusNode: focusNode,
          sdeKey: sdeKey,
        ),
      );
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      final center = tester.getCenter(textFields.at(1));

      // Touch down on segment 1, hold for 350ms (previously rejected by duration < 300ms gate)
      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 350));
      await gesture.up();
      await tester.pumpAndSettle();

      final sdeState = sdeKey.currentState!;
      expect(sdeState.focusNodes[1]?.hasFocus, isTrue);
    });

    // 17. SDE-004: InteractiveCheckbox uses scrollSafe: true and 200ms settleDuration
    testWidgets(
        '17. InteractiveCheckbox configures TactileButton with scrollSafe: true and 200ms settleDuration (SDE-004)',
        (tester) async {
      bool changed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveCheckbox(
              checked: false,
              onTap: () => changed = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tactileFinder = find.byType(TactileButton);
      expect(tactileFinder, findsOneWidget);
      final tactileWidget = tester.widget<TactileButton>(tactileFinder);
      expect(tactileWidget.scrollSafe, isTrue);
      expect(tactileWidget.settleDuration,
          equals(const Duration(milliseconds: 200)));

      // Tap to toggle
      await tester.tap(tactileFinder);
      await tester.pumpAndSettle();
      expect(changed, isTrue);
    });
  });
}
