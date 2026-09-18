import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quick_notes/views/widgets/new_single_document_editor.dart';
import 'package:quick_notes/views/widgets/rich_text_controller.dart';
import 'package:quick_notes/views/widgets/rich_text_formatting_pill.dart';
import 'package:quick_notes/views/widgets/rich_text_selection_toolbar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('D6-C Note Editor SDE & Controls Dark Mode Contract Tests', () {
    testWidgets('SDE body text and caret color in Dark Mode',
        (WidgetTester tester) async {
      final controller = RichTextEditingController();
      controller.text = 'Hello Dark Mode';
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: Scaffold(
            body: NewSingleDocumentEditor(
              controller: controller,
              focusNode: focusNode,
              textColor: const Color(0xFFFFFFFF),
              paperGuideHeight: 1.0,
              contextMenuBuilder: (context, state) => const SizedBox(),
              formattingToolbarHeight: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Caret Color in TextSelectionTheme
      final themeFinder = find.byType(TextSelectionTheme);
      expect(themeFinder, findsWidgets);
      final selectionTheme =
          tester.widget<TextSelectionTheme>(themeFinder.first);
      expect(selectionTheme.data.cursorColor, const Color(0xFF0088FF));

      // Verify Body Text Color in TextField
      final textField = tester.widget<TextField>(find.byType(TextField).first);
      expect(textField.style?.color, const Color(0xFFFFFFFF));
    });

    testWidgets('SDE body text and caret color in Light Mode',
        (WidgetTester tester) async {
      final controller = RichTextEditingController();
      controller.text = 'Hello Light Mode';
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: NewSingleDocumentEditor(
              controller: controller,
              focusNode: focusNode,
              textColor: const Color(0xFF1C1C1E),
              paperGuideHeight: 1.0,
              contextMenuBuilder: (context, state) => const SizedBox(),
              formattingToolbarHeight: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Caret Color in TextSelectionTheme
      final themeFinder = find.byType(TextSelectionTheme);
      expect(themeFinder, findsWidgets);
      final selectionTheme =
          tester.widget<TextSelectionTheme>(themeFinder.first);
      expect(selectionTheme.data.cursorColor, const Color(0xFF0088FF));

      // Verify Body Text Color in TextField
      final textField = tester.widget<TextField>(find.byType(TextField).first);
      expect(textField.style?.color, const Color(0xFF1C1C1E));
    });

    testWidgets('SDE Headings use #FFFFFF in Dark Mode',
        (WidgetTester tester) async {
      final controller = RichTextEditingController(
        markdown: '# Heading 1\n## Heading 2\n### Heading 3',
      );
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: Scaffold(
            body: NewSingleDocumentEditor(
              controller: controller,
              focusNode: focusNode,
              textColor: const Color(0xFFFFFFFF),
              paperGuideHeight: 1.0,
              contextMenuBuilder: (context, state) => const SizedBox(),
              formattingToolbarHeight: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(3));

      for (int i = 0; i < 3; i++) {
        final tf = tester.widget<TextField>(textFields.at(i));
        expect(tf.style?.color, const Color(0xFFFFFFFF));
        expect(tf.style?.fontWeight, FontWeight.bold);
      }
    });

    testWidgets('InteractiveCheckbox styling in Dark Mode vs Light Mode',
        (WidgetTester tester) async {
      // Dark Mode Unchecked
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: Scaffold(
            body: Center(
              child: InteractiveCheckbox(
                checked: false,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final darkUncheckedContainer = tester
          .widget<AnimatedContainer>(find.byType(AnimatedContainer).first);
      final darkUncheckedDeco =
          darkUncheckedContainer.decoration as BoxDecoration;
      expect(darkUncheckedDeco.border?.top.color,
          Colors.white.withValues(alpha: 0.4));

      // Dark Mode Checked
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: Scaffold(
            body: Center(
              child: InteractiveCheckbox(
                checked: true,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final darkCheckedContainer = tester
          .widget<AnimatedContainer>(find.byType(AnimatedContainer).first);
      final darkCheckedDeco = darkCheckedContainer.decoration as BoxDecoration;
      expect(darkCheckedDeco.color, const Color(0xFFFFCC00));

      // Light Mode Unchecked
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: Center(
              child: InteractiveCheckbox(
                checked: false,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final lightUncheckedContainer = tester
          .widget<AnimatedContainer>(find.byType(AnimatedContainer).first);
      final lightUncheckedDeco =
          lightUncheckedContainer.decoration as BoxDecoration;
      expect(lightUncheckedDeco.border?.top.color,
          const Color(0xFF333333).withValues(alpha: 0.3));
    });

    testWidgets('Lists (bullets & numbers) and Quotes styling in Dark Mode',
        (WidgetTester tester) async {
      final controller = RichTextEditingController(
        markdown: '- Bullet item\n1. Numbered item\n> Quote item',
      );
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: Scaffold(
            body: NewSingleDocumentEditor(
              controller: controller,
              focusNode: focusNode,
              textColor: const Color(0xFFFFFFFF),
              paperGuideHeight: 1.0,
              contextMenuBuilder: (context, state) => const SizedBox(),
              formattingToolbarHeight: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Bullet dot Container has white at 0.5 alpha
      final bulletDot = find.byWidgetPredicate((widget) {
        if (widget is Container && widget.decoration is BoxDecoration) {
          final deco = widget.decoration as BoxDecoration;
          return deco.shape == BoxShape.circle &&
              deco.color == const Color(0xFFFFFFFF).withValues(alpha: 0.5);
        }
        return false;
      });
      expect(bulletDot, findsOneWidget);

      // 2. Numbered prefix Text has white at 0.5 alpha
      final numberPrefix = find.byWidgetPredicate((widget) {
        if (widget is Text && widget.data == '1.') {
          return widget.style?.color ==
              const Color(0xFFFFFFFF).withValues(alpha: 0.5);
        }
        return false;
      });
      expect(numberPrefix, findsOneWidget);

      // 3. Quote border has left border with white at 0.2 alpha
      final quoteContainer = find.byWidgetPredicate((widget) {
        if (widget is Container && widget.decoration is BoxDecoration) {
          final deco = widget.decoration as BoxDecoration;
          final border = deco.border;
          if (border is Border) {
            return border.left.color ==
                const Color(0xFFFFFFFF).withValues(alpha: 0.2);
          }
        }
        return false;
      });
      expect(quoteContainer, findsOneWidget);
    });

    testWidgets('Explicit user-selected text color is preserved in Dark Mode',
        (WidgetTester tester) async {
      final controller = RichTextEditingController();
      controller.text = 'Custom Red Text';
      // Apply explicit user color (red) to the text
      controller.selection =
          const TextSelection(baseOffset: 0, extentOffset: 15);
      controller.toggleStyleAttribute('color', value: Colors.red);

      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: Scaffold(
            body: NewSingleDocumentEditor(
              controller: controller,
              focusNode: focusNode,
              textColor: const Color(0xFFFFFFFF),
              paperGuideHeight: 1.0,
              contextMenuBuilder: (context, state) => const SizedBox(),
              formattingToolbarHeight: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sdeFinder = find.byType(NewSingleDocumentEditor);
      final rangeController = tester
          .widget<TextField>(find.byType(TextField).first)
          .controller as RangeTextEditingController;

      final span = rangeController.buildTextSpan(
        context: tester.element(sdeFinder),
        withComposing: false,
      );

      // Verify that the explicit red color was NOT overwritten with #FFFFFF
      final childSpan = span.children?.first as TextSpan?;
      expect(childSpan?.style?.color, Colors.red);
    });

    testWidgets('Floating selection toolbar styling in Dark Mode vs Light Mode',
        (WidgetTester tester) async {
      final controller = TextEditingController(text: 'Selected Text');
      final focusNode = FocusNode();
      final darkHostKey = GlobalKey<_ToolbarTestHostState>();
      final lightHostKey = GlobalKey<_ToolbarTestHostState>();

      // 1. Dark Mode
      await tester.pumpWidget(
        _ToolbarTestHost(
          key: darkHostKey,
          theme: ThemeData(brightness: Brightness.dark),
          controller: controller,
          focusNode: focusNode,
        ),
      );
      focusNode.requestFocus();
      controller.selection =
          const TextSelection(baseOffset: 0, extentOffset: 8);
      await tester.pump();
      darkHostKey.currentState!.showToolbar();
      await tester.pumpAndSettle();

      final darkToolbarFinder = find.byType(RichTextSelectionToolbar);
      expect(darkToolbarFinder, findsOneWidget);

      final darkToolbarContainer = find.descendant(
        of: darkToolbarFinder,
        matching: find.byWidgetPredicate((w) {
          if (w is Container && w.decoration is BoxDecoration) {
            final deco = w.decoration as BoxDecoration;
            return deco.color == const Color(0xEC3A3A3C);
          }
          return false;
        }),
      );
      expect(darkToolbarContainer, findsOneWidget);

      // Verify actions text color is #FFFFFF
      final selectAllText = tester.widget<Text>(find.text('Select All'));
      expect(selectAllText.style?.color, Colors.white);

      // 2. Light Mode
      await tester.pumpWidget(
        _ToolbarTestHost(
          key: lightHostKey,
          theme: ThemeData.light(),
          controller: controller,
          focusNode: focusNode,
        ),
      );
      focusNode.requestFocus();
      controller.selection =
          const TextSelection(baseOffset: 0, extentOffset: 8);
      await tester.pump();
      lightHostKey.currentState!.showToolbar();
      await tester.pumpAndSettle();

      final lightToolbarContainer = find.descendant(
        of: find.byType(RichTextSelectionToolbar),
        matching: find.byWidgetPredicate((w) {
          if (w is Container && w.decoration is BoxDecoration) {
            final deco = w.decoration as BoxDecoration;
            return deco.color == const Color(0xEC222226);
          }
          return false;
        }),
      );
      expect(lightToolbarContainer, findsOneWidget);
    });

    testWidgets(
        'FINDING-D6-D5-02: RichTextFormattingPillContainer inactive icon theme adapts to dark/light mode',
        (WidgetTester tester) async {
      Color? resolvedColorDark;
      Color? resolvedColorLight;

      // 1. Dark Mode
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: Scaffold(
            body: RichTextFormattingPillContainer(
              width: 100,
              height: 40,
              child: Builder(
                builder: (context) {
                  resolvedColorDark = IconTheme.of(context).color;
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(resolvedColorDark, const Color(0xFF8E8E93));

      // 2. Light Mode
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.light),
          home: Scaffold(
            body: RichTextFormattingPillContainer(
              width: 100,
              height: 40,
              child: Builder(
                builder: (context) {
                  resolvedColorLight = IconTheme.of(context).color;
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(resolvedColorLight, const Color(0xFF333333));
    });
  });
}

class _ToolbarTestHost extends StatefulWidget {
  final ThemeData theme;
  final TextEditingController controller;
  final FocusNode focusNode;

  const _ToolbarTestHost({
    super.key,
    required this.theme,
    required this.controller,
    required this.focusNode,
  });

  @override
  State<_ToolbarTestHost> createState() => _ToolbarTestHostState();
}

class _ToolbarTestHostState extends State<_ToolbarTestHost> {
  final editableKey = GlobalKey<EditableTextState>();
  bool _showToolbar = false;

  void showToolbar() {
    setState(() => _showToolbar = true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: widget.theme,
      home: Scaffold(
        body: Stack(
          children: [
            EditableText(
              key: editableKey,
              controller: widget.controller,
              focusNode: widget.focusNode,
              style: const TextStyle(fontSize: 16, color: Colors.white),
              cursorColor: Colors.blue,
              backgroundCursorColor: Colors.grey,
            ),
            if (_showToolbar && editableKey.currentState != null)
              RichTextSelectionToolbar(
                editableTextState: editableKey.currentState!,
              ),
          ],
        ),
      ),
    );
  }
}
