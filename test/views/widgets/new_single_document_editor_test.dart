import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/views/widgets/new_single_document_editor.dart';
import 'package:quick_notes/views/widgets/rich_text_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestableEditor({
    required RichTextEditingController controller,
    required FocusNode focusNode,
    GlobalKey<NewSingleDocumentEditorState>? sdeKey,
    bool readOnly = false,
    Widget? header,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: NewSingleDocumentEditor(
          key: sdeKey,
          controller: controller,
          focusNode: focusNode,
          textColor: Colors.black,
          paperGuideHeight: 1.0,
          formattingToolbarHeight: 0.0,
          readOnly: readOnly,
          header: header,
          contextMenuBuilder: (context, editableTextState) {
            return AdaptiveTextSelectionToolbar.editableText(
              editableTextState: editableTextState,
            );
          },
        ),
      ),
    );
  }

  group('NewSingleDocumentEditor Component Tests', () {
    late RichTextEditingController controller;
    late FocusNode focusNode;

    setUp(() {
      controller = RichTextEditingController();
      focusNode = FocusNode();
    });

    tearDown(() {
      controller.dispose();
      focusNode.dispose();
    });

    testWidgets(
        '1. Mounts with empty text and creates initial paragraph text segment',
        (tester) async {
      final sdeKey = GlobalKey<NewSingleDocumentEditorState>();

      await tester.pumpWidget(
        buildTestableEditor(
          controller: controller,
          focusNode: focusNode,
          sdeKey: sdeKey,
        ),
      );
      await tester.pumpAndSettle();

      expect(sdeKey.currentState, isNotNull);
      final segments = sdeKey.currentState!.textSegments;
      expect(segments.length, equals(1));
      expect(segments.first.type, equals('paragraph'));
    });

    testWidgets('2. Parses multi-line document into distinct typed segments',
        (tester) async {
      final sdeKey = GlobalKey<NewSingleDocumentEditorState>();
      controller.setMarkdown(
          '# Document Header\n> Inverted quote\n- [ ] Buy groceries\nSimple prose line');

      await tester.pumpWidget(
        buildTestableEditor(
          controller: controller,
          focusNode: focusNode,
          sdeKey: sdeKey,
        ),
      );
      await tester.pumpAndSettle();

      expect(sdeKey.currentState, isNotNull);
      final segments = sdeKey.currentState!.textSegments;
      expect(segments.length, equals(4));
      expect(segments[0].type, equals('h1'));
      expect(segments[1].type, equals('quote'));
      expect(segments[2].type, equals('checkbox'));
      expect(segments[3].type, equals('paragraph'));
    });

    testWidgets('3. Renders custom header widget above document segments',
        (tester) async {
      await tester.pumpWidget(
        buildTestableEditor(
          controller: controller,
          focusNode: focusNode,
          header: const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('Note Title Header Widget'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Note Title Header Widget'), findsOneWidget);
    });

    testWidgets('4. Respects readOnly parameter in editable text tree',
        (tester) async {
      controller.setMarkdown('Immutable reference content');

      await tester.pumpWidget(
        buildTestableEditor(
          controller: controller,
          focusNode: focusNode,
          readOnly: true,
        ),
      );
      await tester.pumpAndSettle();

      final editableFinder = find.byType(EditableText);
      expect(editableFinder, findsWidgets);
      final editable = tester.widget<EditableText>(editableFinder.first);
      expect(editable.readOnly, isTrue);
    });

    testWidgets(
        '5. Handles dynamic content updates and segment re-parsing cleanly',
        (tester) async {
      final sdeKey = GlobalKey<NewSingleDocumentEditorState>();
      controller.setMarkdown('Simple starting sentence');

      await tester.pumpWidget(
        buildTestableEditor(
          controller: controller,
          focusNode: focusNode,
          sdeKey: sdeKey,
        ),
      );
      await tester.pumpAndSettle();

      expect(sdeKey.currentState!.textSegments.length, equals(1));

      // Dynamically update content via controller to multi-segment structure
      controller.setMarkdown(
          '# Dynamic Title\n- [ ] Task 1\n- [x] Task 2\nBody prose line');
      await tester.pumpAndSettle();

      expect(sdeKey.currentState!.textSegments.length, equals(4));
      expect(sdeKey.currentState!.textSegments[0].type, equals('h1'));
      expect(sdeKey.currentState!.textSegments[1].type, equals('checkbox'));
    });

    testWidgets(
        '6. Handles empty and malformed markdown without unmounting or crashing',
        (tester) async {
      final sdeKey = GlobalKey<NewSingleDocumentEditorState>();
      controller
          .setMarkdown('**broken markdown *without closing tags ~~or matches');

      await tester.pumpWidget(
        buildTestableEditor(
          controller: controller,
          focusNode: focusNode,
          sdeKey: sdeKey,
        ),
      );
      await tester.pumpAndSettle();

      expect(sdeKey.currentState, isNotNull);
      expect(find.byType(NewSingleDocumentEditor), findsOneWidget);

      // Reset to empty string
      controller.setMarkdown('');
      await tester.pumpAndSettle();

      expect(sdeKey.currentState, isNotNull);
      expect(sdeKey.currentState!.textSegments.isNotEmpty, isTrue);
    });
  });
}
