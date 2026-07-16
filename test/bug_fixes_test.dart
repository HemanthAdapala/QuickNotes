import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/models/note_summary.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/views/screens/home_screen.dart';
import 'package:quick_notes/views/screens/folder_management_screen.dart';
import 'package:quick_notes/views/screens/note_editor_screen.dart';
import 'package:quick_notes/views/screens/settings_screen.dart';
import 'package:quick_notes/views/widgets/note_card.dart';
import 'package:quick_notes/views/widgets/rich_text_controller.dart';
import 'package:quick_notes/views/widgets/new_single_document_editor.dart';
import 'package:quick_notes/views/widgets/home_prompt_view.dart';
import 'package:quick_notes/views/widgets/tactile_button.dart';
import 'package:quick_notes/views/widgets/new_image_widget.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quick_notes/models/folder.dart';
import 'package:quick_notes/models/task_item.dart';
import 'package:quick_notes/views/widgets/task_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    GoogleFonts.config.allowRuntimeFetching = false;
    NoteEditorScreen.useSingleDocumentEditor = false;

    late final MessageHandler handler;
    handler = (ByteData? message) async {
      if (message == null) return null;
      final Uint8List list = message.buffer.asUint8List(message.offsetInBytes, message.lengthInBytes);
      final String key = utf8.decode(list);
      if (key.startsWith('google_fonts/')) {
        return ByteData(16);
      }

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null);
      try {
        return await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .send('flutter/assets', message);
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler('flutter/assets', handler);
      }
    };

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', handler);

    const MethodChannel sqfliteChannel = MethodChannel('plugins.flutter.io/sqflite');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(sqfliteChannel, (MethodCall methodCall) async {
      if (methodCall.method == 'getDatabasesPath') {
        return '.';
      }
      if (methodCall.method == 'openDatabase') {
        return <String, dynamic>{'id': 1};
      }
      if (methodCall.method == 'query') {
        return <Map<String, dynamic>>[];
      }
      if (methodCall.method == 'execute') {
        return null;
      }
      return null;
    });

    const MethodChannel pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (MethodCall methodCall) async {
      if (methodCall.method == 'getApplicationDocumentsDirectory') {
        return '.';
      }
      return null;
    });

    const MethodChannel notificationsChannel = MethodChannel('dexterous.com/flutter_local_notifications');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, (MethodCall methodCall) async {
      return true;
    });

    const MethodChannel homeWidgetChannel = MethodChannel('class.yiss.home_widget');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(homeWidgetChannel, (MethodCall methodCall) async {
      return true;
    });
  });

  group('QuickNotes Bug Fixes Validation Tests', () {
    testWidgets('Issue 1: Note color transparent/filled: false check', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => NotesProvider()),
          ],
          child: MaterialApp(
            home: NoteEditorScreen(
              note: Note(
                id: 'test_active',
                title: 'Test Note',
                content: '',
                tags: [],
                attachments: [],
                category: 'Personal',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                colorValue: 0,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      final titleFinder = find.byWidgetPredicate(
        (widget) => widget is TextField && widget.decoration?.hintText == 'Title',
      );
      expect(titleFinder, findsOneWidget);

      final TextField titleField = tester.widget(titleFinder);
      expect(titleField.decoration?.filled, isFalse);

      final contentFinder = find.byWidgetPredicate(
        (widget) => widget is TextField && widget.decoration?.hintText == 'Start writing...',
      );
      expect(contentFinder, findsOneWidget);

      final TextField contentField = tester.widget(contentFinder);
      expect(contentField.decoration?.filled, isFalse);
      await tester.pump(const Duration(seconds: 11));
    });



    testWidgets('Issue 3: HomeScreen tab switching check', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => NotesProvider()),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      // Verify that we start on HomeScreen's Today block or input field
      expect(find.text('No notes yet'), findsNWidgets(2));

      // Tap on Folders tab (index 1) which shows FolderManagementScreen
      final folderIconFinder = find.bySemanticsLabel('Folders');
      expect(folderIconFinder, findsOneWidget);

      await tester.tap(folderIconFinder);
      await tester.pumpAndSettle();

      // Now we should be on FolderManagementScreen
      expect(find.byType(FolderManagementScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('Issue 4: Instant SnackBar trigger check', (WidgetTester tester) async {
      final note = Note(
        id: 'test_note_pin',
        title: 'Pin test title',
        content: 'Pin test body',
        tags: [],
        attachments: [],
        category: 'Personal',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        colorValue: 0,
      );

      final notesProvider = NotesProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: notesProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: NoteCard(
                note: NoteSummary.fromNote(note),
                onTap: () {},
                onPinToggle: () => notesProvider.togglePin(note.id),
                onFavoriteToggle: () {},
                onDelete: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      final pinButtonFinder = find.byIcon(Icons.push_pin_outlined);
      expect(pinButtonFinder, findsOneWidget);

      await tester.tap(pinButtonFinder);
      await tester.pump(); 

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Note pinned'), findsOneWidget);
      await tester.pump(const Duration(seconds: 11));
    });



    testWidgets('Rich formatting toolbar category and subsection navigation check', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => NotesProvider()),
          ],
          child: MaterialApp(
            home: NoteEditorScreen(
              note: Note(
                id: 'test_active',
                title: 'Test Note',
                content: '',
                tags: [],
                attachments: [],
                category: 'Personal',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                colorValue: 0,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      // Focus the content TextField to trigger the formatting toolbar
      final contentFinder = find.byWidgetPredicate(
        (widget) => widget is TextField && widget.decoration?.hintText == 'Start writing...',
      );
      expect(contentFinder, findsOneWidget);
      await tester.tap(contentFinder);
      await tester.pump();

      // Find Aa category button (it is a text button "Aa")
      final aaFinder = find.text('Aa');
      expect(aaFinder, findsOneWidget);
      await tester.tap(aaFinder);
      await tester.pumpAndSettle();

      // Verify that the Aa subsection options are present
      expect(find.byTooltip('Bold'), findsOneWidget);
      expect(find.byTooltip('Italic'), findsOneWidget);
      expect(find.byTooltip('Underline'), findsOneWidget);
      expect(find.byTooltip('Strikethrough'), findsOneWidget);

      // Slide to page 2 of categories by tapping right arrow (chevron_right)
      final rightArrowFinder = find.byIcon(Icons.chevron_right_rounded);
      expect(rightArrowFinder, findsOneWidget);
      await tester.tap(rightArrowFinder);
      await tester.pumpAndSettle();

      // Verify page 2 has Headings icon (Icons.title_rounded)
      final headingsCategoryFinder = find.byIcon(Icons.title_rounded);
      expect(headingsCategoryFinder, findsOneWidget);
      await tester.tap(headingsCategoryFinder);
      await tester.pumpAndSettle();

      // Verify Headings subsection is visible
      expect(find.byTooltip('Heading 1'), findsOneWidget);
      expect(find.byTooltip('Heading 2'), findsOneWidget);
      expect(find.byTooltip('Heading 3'), findsOneWidget);

      // Verify paper settings is present on page 2
      expect(find.byIcon(Icons.grid_on_rounded), findsOneWidget);

      // Go back to page 1 of categories
      final leftArrowFinder = find.byIcon(Icons.chevron_left_rounded);
      expect(leftArrowFinder, findsOneWidget);
      await tester.tap(leftArrowFinder);
      await tester.pumpAndSettle();

      // Tap Alignment category
      final alignCategoryFinder = find.byIcon(Icons.format_align_left_rounded);
      expect(alignCategoryFinder, findsOneWidget);
      await tester.tap(alignCategoryFinder);
      await tester.pumpAndSettle();

      // Verify Alignment subsection is visible
      expect(find.byTooltip('Align Left'), findsOneWidget);
      expect(find.byTooltip('Align Center'), findsOneWidget);
      expect(find.byTooltip('Align Right'), findsOneWidget);
      expect(find.byTooltip('Align Justify'), findsOneWidget);

      await tester.pump(const Duration(seconds: 11));
    });

    test('WYSIWYG: parseMarkdownToStyledChars and generateMarkdownFromStyledChars', () {
      const markdown = '**Hello** *World* <u>under</u> ~~strike~~';
      final chars = parseMarkdownToStyledChars(markdown);
      expect(chars.map((c) => c.char).join(), equals('Hello World under strike'));

      expect(chars[0].style.bold, isTrue);
      expect(chars[0].style.italic, isFalse);
      expect(chars[6].style.italic, isTrue);
      expect(chars[6].style.bold, isFalse);
      expect(chars[12].style.underline, isTrue);
      expect(chars[18].style.strikethrough, isTrue);

      final generated = generateMarkdownFromStyledChars(chars);
      expect(generated, equals(markdown));
    });

    test('WYSIWYG: RichTextEditingController style toggling', () {
      final controller = RichTextEditingController();
      controller.text = 'Hello World';
      
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
      controller.toggleStyleAttribute('bold');

      expect(controller.styledChars[0].style.bold, isTrue);
      expect(controller.styledChars[5].style.bold, isFalse);

      final markdown = generateMarkdownFromStyledChars(controller.styledChars);
      expect(markdown, equals('**Hello** World'));
    });

    test('WYSIWYG: RichTextEditingController checklist and alignment toggling', () {
      final controller = RichTextEditingController();
      controller.text = 'Checklist item';

      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 14);
      controller.toggleParagraphStyle('checkbox');

      expect(controller.text, equals('\u2610Checklist item'));
      expect(controller.styledChars[0].char, equals('\u2610'));
      expect(controller.styledChars[0].style.listType, equals('checkbox'));

      controller.toggleChecklistState(0);
      expect(controller.styledChars[0].char, equals('\u2611'));
      expect(controller.styledChars[1].style.strikethrough, isTrue);

      controller.selection = const TextSelection(baseOffset: 3, extentOffset: 3);
      controller.toggleParagraphStyle('align-center');
      expect(controller.styledChars[3].style.align, equals(TextAlign.center));

      final markdown = generateMarkdownFromStyledChars(controller.styledChars);
      expect(markdown, contains('<p align="center">'));
    });

    test('WYSIWYG: Image parsing, generating, and resizing', () {
      const markdown = 'Hello ![](file:///path/to/img.png?width=250) World';
      final chars = parseMarkdownToStyledChars(markdown);
      
      expect(chars.map((c) => c.char).join(), equals('Hello \uFFFC World'));
      
      final imgChar = chars[6];
      expect(imgChar.char, equals('\uFFFC'));
      expect(imgChar.style.imageUrl, equals('file:///path/to/img.png'));
      expect(imgChar.style.imageWidth, equals(250.0));
      
      final generated = generateMarkdownFromStyledChars(chars);
      expect(generated, equals(markdown));
      
      final controller = RichTextEditingController(markdown: markdown);
      expect(controller.styledChars[6].style.imageWidth, equals(250.0));
      
      controller.styledChars[6] = StyledChar(
        char: controller.styledChars[6].char,
        style: controller.styledChars[6].style.copyWith(imageWidth: 400.0),
      );
      
      final updatedMarkdown = generateMarkdownFromStyledChars(controller.styledChars);
      expect(updatedMarkdown, equals('Hello ![](file:///path/to/img.png?width=400) World'));
    });

    test('WYSIWYG: Image caption parsing, generating, and updating', () {
      const markdown = 'Text ![Custom Caption](file:///path/to/image.png?width=300) Text';
      final chars = parseMarkdownToStyledChars(markdown);
      
      expect(chars.map((c) => c.char).join(), equals('Text \uFFFC Text'));
      
      final imgChar = chars[5];
      expect(imgChar.char, equals('\uFFFC'));
      expect(imgChar.style.imageUrl, equals('file:///path/to/image.png'));
      expect(imgChar.style.imageWidth, equals(300.0));
      expect(imgChar.style.imageCaption, equals('Custom Caption'));
      
      final generated = generateMarkdownFromStyledChars(chars);
      expect(generated, equals(markdown));
      
      final controller = RichTextEditingController(markdown: markdown);
      expect(controller.styledChars[5].style.imageCaption, equals('Custom Caption'));
      
      controller.styledChars[5] = StyledChar(
        char: controller.styledChars[5].char,
        style: controller.styledChars[5].style.copyWith(imageCaption: 'New Caption'),
      );
      
      final updatedMarkdown = generateMarkdownFromStyledChars(controller.styledChars);
      expect(updatedMarkdown, equals('Text ![New Caption](file:///path/to/image.png?width=300) Text'));

      controller.styledChars[5] = StyledChar(
        char: controller.styledChars[5].char,
        style: controller.styledChars[5].style.copyWith(clearCaption: true),
      );

      final clearedMarkdown = generateMarkdownFromStyledChars(controller.styledChars);
      expect(clearedMarkdown, equals('Text ![](file:///path/to/image.png?width=300) Text'));
    });

    testWidgets('WYSIWYG: Block-level image insertion from gallery', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => NotesProvider()),
          ],
          child: MaterialApp(
            home: NoteEditorScreen(
              note: Note(
                id: 'test_active',
                title: 'Test Note',
                content: '',
                tags: [],
                attachments: [],
                category: 'Personal',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                colorValue: 0,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      final contentFinder = find.byWidgetPredicate(
        (widget) => widget is TextField && widget.decoration?.hintText == 'Start writing...',
      );
      expect(contentFinder, findsOneWidget);
      await tester.tap(contentFinder);
      await tester.enterText(contentFinder, 'Hello World');
      await tester.pump();

      final TextField contentField = tester.widget(contentFinder);
      final controller = contentField.controller as RichTextEditingController;
      
      controller.selection = const TextSelection.collapsed(offset: 5);
      await tester.pump();

      final pageViewFinder = find.byType(PageView);
      expect(pageViewFinder, findsOneWidget);

      final attachmentCategoryFinder = find.byWidgetPredicate(
        (widget) => widget is SvgPicture && widget.toString().contains('link.svg'),
      );
      expect(attachmentCategoryFinder, findsOneWidget);
      await tester.tap(attachmentCategoryFinder);
      await tester.pumpAndSettle();

      final attachImageFinder = find.byTooltip('Attach Image');
      expect(attachImageFinder, findsOneWidget);
      await tester.tap(attachImageFinder);
      await tester.pumpAndSettle();

      final networkImageFinder = find.byType(Image);
      expect(networkImageFinder, findsWidgets);
      
      await tester.tap(networkImageFinder.first);
      await tester.pump();

      final insertButtonFinder = find.text('Insert (1)');
      expect(insertButtonFinder, findsOneWidget);
      await tester.tap(insertButtonFinder);
      await tester.pumpAndSettle();

      await tester.pump(const Duration(milliseconds: 400));

      final paragraphFields = tester.widgetList<TextField>(find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText != 'Title',
      )).toList();
      expect(paragraphFields.length, equals(2));
      expect(paragraphFields[0].controller?.text, equals('Hello'));
      expect(paragraphFields[1].controller?.text, equals(' World'));
      expect(paragraphFields[1].focusNode?.hasFocus, isTrue);

      expect(find.byType(ResizableImageWidget), findsOneWidget);

      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('WYSIWYG: Escape from empty ChecklistBlock to ParagraphBlock on Enter', (WidgetTester tester) async {
      final textNote = Note(
        id: 'test_checklist_escape_enter',
        title: 'Checklist Escape Title',
        content: '- [ ] Task\n',
        tags: [],
        attachments: [],
        category: 'Personal',
        noteType: 'text',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        colorValue: 0,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => NotesProvider()),
          ],
          child: MaterialApp(
            home: NoteEditorScreen(note: textNote),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(NoteEditorScreen), findsOneWidget);

      final checklistFieldFinder = find.byWidgetPredicate(
        (widget) => widget is TextField && widget.decoration?.hintText == 'To-do item',
      );
      expect(checklistFieldFinder, findsOneWidget);

      await tester.tap(checklistFieldFinder);
      await tester.pump();

      // Clear text to make it empty
      await tester.enterText(checklistFieldFinder, '');
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == 'To-do item'), findsNothing);
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('WYSIWYG: Escape from empty ChecklistBlock to ParagraphBlock on Backspace', (WidgetTester tester) async {
      final textNote = Note(
        id: 'test_checklist_escape_backspace',
        title: 'Checklist Escape Title',
        content: '- [ ] Task\n',
        tags: [],
        attachments: [],
        category: 'Personal',
        noteType: 'text',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        colorValue: 0,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => NotesProvider()),
          ],
          child: MaterialApp(
            home: NoteEditorScreen(note: textNote),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(NoteEditorScreen), findsOneWidget);

      final checklistFieldFinder = find.byWidgetPredicate(
        (widget) => widget is TextField && widget.decoration?.hintText == 'To-do item',
      );
      expect(checklistFieldFinder, findsOneWidget);

      await tester.tap(checklistFieldFinder);
      await tester.pump();

      // Clear text to make it empty
      await tester.enterText(checklistFieldFinder, '');
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();

      expect(find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == 'To-do item'), findsNothing);
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('WYSIWYG: Horizontal drag resize on ResizableImageWidget', (WidgetTester tester) async {
      final imgNote = Note(
        id: 'test_img_resize',
        title: 'Image Resize Title',
        content: '![](https://example.com/pic.png?width=200)\n',
        tags: [],
        attachments: [],
        category: 'Personal',
        noteType: 'text',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        colorValue: 0,
      );

      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => NotesProvider()),
          ],
          child: MaterialApp(
            home: NoteEditorScreen(note: imgNote),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ResizableImageWidget), findsOneWidget);

      final rect = tester.getRect(find.byType(ResizableImageWidget));
      final center = tester.getCenter(find.byType(ResizableImageWidget));
      print('DEBUGGING_RESIZE: rect=$rect, center=$center');

      // Single tap on image to show controls
      await tester.tap(find.byType(ResizableImageWidget));
      await tester.pump(const Duration(milliseconds: 400));

      // Verify handles are present
      final handleFinder = find.byIcon(Icons.drag_handle_rounded);
      expect(handleFinder, findsNWidgets(2)); // Left and right handle icons

      final leftHandleCenter = tester.getCenter(handleFinder.first);
      final rightHandleCenter = tester.getCenter(handleFinder.last);
      expect(rightHandleCenter.dx > leftHandleCenter.dx, isTrue);

      // Drag the right handle to the right by 100 pixels
      final drag = await tester.startGesture(rightHandleCenter);
      await drag.moveBy(const Offset(100.0, 0));
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();

      // Verify widget is still present
      expect(find.byType(ResizableImageWidget), findsOneWidget);
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('WYSIWYG: Image stack merging via drag-and-drop', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final imgNote = Note(
        id: 'test_img_merge',
        title: 'Image Merge Title',
        content: '![](https://example.com/pic1.png?width=100)\n\n![](https://example.com/pic2.png?width=100)\n',
        tags: [],
        attachments: [],
        category: 'Personal',
        noteType: 'text',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        colorValue: 0,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => NotesProvider()),
          ],
          child: MaterialApp(
            home: NoteEditorScreen(note: imgNote),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ResizableImageWidget), findsNWidgets(2));

      final firstImage = find.byType(ResizableImageWidget).at(0);
      final secondImage = find.byType(ResizableImageWidget).at(1);

      final firstCenter = tester.getCenter(firstImage);
      final secondCenter = tester.getCenter(secondImage);
      print('DEBUGGING: firstCenter=$firstCenter, secondCenter=$secondCenter');

      final gesture = await tester.startGesture(firstCenter);
      await tester.pump(const Duration(milliseconds: 900));

      // Recompute the second image center dynamically after layout has shifted due to childWhenDragging
      var targetCenter = tester.getCenter(find.byType(ResizableImageWidget).at(1));

      // Drag incrementally
      const steps = 10;
      for (int i = 1; i <= steps; i++) {
        final point = Offset(
          firstCenter.dx + (targetCenter.dx - firstCenter.dx) * (i / steps),
          firstCenter.dy + (targetCenter.dy - firstCenter.dy) * (i / steps),
        );
        await gesture.moveTo(point);
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Re-query targetCenter after hover layout transitions have completed
      targetCenter = tester.getCenter(find.byType(ResizableImageWidget).at(1));
      await gesture.moveTo(targetCenter);
      await tester.pump(const Duration(milliseconds: 100));

      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.byType(ImageStackWidget), findsOneWidget);
      await tester.pump(const Duration(seconds: 11));
    });

    test('3-Layer Note Paper System settings serialization & copyWith', () {
      final note = Note(
        id: 'test_paper_model',
        title: 'Model Title',
        content: 'Model Content',
        tags: [],
        attachments: [],
        category: 'Personal',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        colorValue: 0,
      );

      // Verify defaults
      expect(note.paperGuideType, equals('lines_extra_tight'));
      expect(note.paperGuideVisible, isFalse);
      expect(note.paperGuideHeight, equals(1.05));
      expect(note.paperGuideOpacity, equals(0.15));
      expect(note.paperGuideColor, equals(0));

      // Verify copyWith
      final updated = note.copyWith(
        paperGuideType: 'grid',
        paperGuideVisible: false,
        paperGuideHeight: 1.5,
        paperGuideOpacity: 0.35,
        paperGuideColor: 0xFFF07167,
      );
      expect(updated.paperGuideType, equals('grid'));
      expect(updated.paperGuideVisible, isFalse);
      expect(updated.paperGuideHeight, equals(1.5));
      expect(updated.paperGuideOpacity, equals(0.35));
      expect(updated.paperGuideColor, equals(0xFFF07167));

      // Verify serialization/deserialization
      final map = updated.toMap();
      expect(map['paperSettings'], isNotNull);
      final decodedMap = jsonDecode(map['paperSettings'] as String);
      expect(decodedMap['guideType'], equals('grid'));
      expect(decodedMap['guideVisible'], isFalse);

      final fromMap = Note.fromMap(map);
      expect(fromMap.paperGuideType, equals('grid'));
      expect(fromMap.paperGuideVisible, isFalse);
      expect(fromMap.paperGuideHeight, equals(1.5));
      expect(fromMap.paperGuideOpacity, equals(0.35));
      expect(fromMap.paperGuideColor, equals(0xFFF07167));
    });

    testWidgets('HomePromptView displays correct contextual greeting based on time', (WidgetTester tester) async {
      final notesProvider = NotesProvider();

      // Test morning time (8:00 AM)
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: notesProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: HomePromptView(
                date: DateTime(2026, 6, 15, 8, 0),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Good Morning'), findsOneWidget);

      // Test afternoon time (2:00 PM / 14:00)
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: notesProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: HomePromptView(
                date: DateTime(2026, 6, 15, 14, 0),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Good Afternoon'), findsOneWidget);

      // Test evening time (8:00 PM / 20:00)
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: notesProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: HomePromptView(
                date: DateTime(2026, 6, 15, 20, 0),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Good Evening'), findsOneWidget);
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('HomePromptView displays correct activity indicator based on note count', (WidgetTester tester) async {
      final notesProvider = NotesProvider();

      // Case 1: No notes yet
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: notesProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: HomePromptView(
                date: DateTime(2026, 6, 15, 12, 0),
              ),
            ),
          ),
        ),
      );
      expect(find.text('No notes yet'), findsNWidgets(2));

      // Add 1 note for today (June 15, 2026)
      final now = DateTime.now();
      final note1 = Note(
        id: '1',
        title: 'Note 1',
        content: 'Content 1',
        colorValue: 0,
        tags: [],
        attachments: [],
        createdAt: now,
        updatedAt: now,
      );
      notesProvider.setNotesForTesting([note1]);
      await tester.pump();

      // Re-render and check count is 1 entry today
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: notesProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: HomePromptView(
                date: now,
              ),
            ),
          ),
        ),
      );
      expect(find.text('1 entry today'), findsOneWidget);

      // Add another note for today
      final note2 = Note(
        id: '2',
        title: 'Note 2',
        content: 'Content 2',
        colorValue: 0,
        tags: [],
        attachments: [],
        createdAt: now,
        updatedAt: now,
      );
      notesProvider.setNotesForTesting([note1, note2]);
      await tester.pump();

      // Re-render and check count is 2 notes today
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: notesProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: HomePromptView(
                date: now,
              ),
            ),
          ),
        ),
      );
      expect(find.text('2 notes today'), findsOneWidget);
      await tester.pump(const Duration(seconds: 11));
    });

    test('HomePromptView dynamic placeholder prompts rotation logic tests', () {
      HomePromptView.resetDeckForTesting();
      final prompts = HomePromptView.prompts;

      // 1st Cycle
      final List<String> deck1 = [];
      for (int i = 0; i < 8; i++) {
        deck1.add(HomePromptView.getRandomPromptForTesting());
      }
      // Verify all 8 prompts from the first cycle are unique
      expect(deck1.toSet().length, equals(8));
      for (final p in deck1) {
        expect(prompts.contains(p), isTrue);
      }

      // 2nd Cycle (starts on the 9th call)
      final String firstOfDeck2 = HomePromptView.getRandomPromptForTesting();
      // Verify no consecutive repeat at the boundary
      expect(firstOfDeck2, isNot(equals(deck1.last)));

      final List<String> deck2 = [firstOfDeck2];
      for (int i = 0; i < 7; i++) {
        deck2.add(HomePromptView.getRandomPromptForTesting());
      }
      // Verify all 8 prompts from the second cycle are unique
      expect(deck2.toSet().length, equals(8));
      for (final p in deck2) {
        expect(prompts.contains(p), isTrue);
      }

      // 3rd Cycle (starts on the 17th call)
      final String firstOfDeck3 = HomePromptView.getRandomPromptForTesting();
      // Verify no consecutive repeat at the boundary
      expect(firstOfDeck3, isNot(equals(deck2.last)));
    });

    testWidgets('SettingsScreen rendering and interaction test', (WidgetTester tester) async {
      final notesProvider = NotesProvider();
      addTearDown(() => notesProvider.dispose());
      bool backTapped = false;
      bool themeToggled = false;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: notesProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SettingsScreen(
                isDarkMode: false,
                onThemeToggle: () {
                  themeToggled = true;
                },
                onMenuTap: () {
                  backTapped = true;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      // Verify that title Settings exists
      expect(find.text('Settings'), findsOneWidget);

      // Verify Olivia Green profile card exists
      expect(find.text('Olivia Green'), findsNWidgets(2)); // Name + Username

      // Verify Change Password section is present
      final changePasswordFinder = find.text('Change Password');
      expect(changePasswordFinder, findsOneWidget);

      // Tap on Change Password to trigger the mock dialog
      await tester.tap(changePasswordFinder);
      await tester.pump();
      
      // Verify dialog is shown
      expect(find.text('Password change verification request has been sent to your registered email address.'), findsOneWidget);
      
      // Tap Dismiss to close the dialog
      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();

      // Verify toggle switch state toggles theme when clicked
      final appearanceFinder = find.text('Appearance');
      expect(appearanceFinder, findsOneWidget);

      // Find the toggle switches (StitchToggleSwitch)
      final switchFinder = find.byType(StitchToggleSwitch);
      expect(switchFinder, findsNWidgets(2)); // Appearance and Zen Focus Mode

      // Tap the first switch (Appearance)
      await tester.tap(switchFinder.first);
      await tester.pump();
      expect(themeToggled, isTrue);

      // Tap back button (TactileButton enclosing back chevron)
      final backButtonFinder = find.descendant(
        of: find.byType(TactileButton),
        matching: find.byType(SvgPicture),
      ).first;
      expect(backButtonFinder, findsOneWidget);
      await tester.tap(backButtonFinder);
      await tester.pump();
      expect(backTapped, isTrue);

      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('WYSIWYG: Bulleted and Numbered list blocks rendering, formatting, and propagation', (WidgetTester tester) async {
      final textNote = Note(
        id: 'test_bullet_number_list',
        title: 'Lists Title',
        content: '- Item 1\n1. First item\n',
        tags: [],
        attachments: [],
        category: 'Personal',
        noteType: 'text',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        colorValue: 0,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => NotesProvider()),
          ],
          child: MaterialApp(
            home: NoteEditorScreen(note: textNote),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(NoteEditorScreen), findsOneWidget);

      // Verify that BulletedListBlock and NumberedListBlock are rendered
      // Hint text for List items is "List item"
      final listFields = find.byWidgetPredicate(
        (widget) => widget is TextField && widget.decoration?.hintText == 'List item',
      );
      expect(listFields, findsNWidgets(2));

      // Tap on the first list field (BulletedListBlock)
      await tester.tap(listFields.first);
      await tester.pump();

      // Clear the bullet block text
      await tester.enterText(listFields.first, '');
      await tester.pump();

      // Press backspace to escape bullet list mode
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();

      // BulletedListBlock should convert to ParagraphBlock, so hintText changes to empty/placeholder
      expect(find.byWidgetPredicate(
        (widget) => widget is TextField && widget.decoration?.hintText == 'List item',
      ), findsOneWidget); // Only NumberedListBlock remains

      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('WYSIWYG single-document improvements: active style cursor sync, image tap focus, paragraph alignments, list prefixes', (WidgetTester tester) async {
      final controller = RichTextEditingController();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              controller: controller,
              focusNode: focusNode,
              maxLines: null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Style sync test
      controller.setMarkdown('**bold** normal');
      await tester.pump();
      
      // Cursor at offset 4 (inside 'bold') should have bold = true
      controller.selection = const TextSelection.collapsed(offset: 4);
      await tester.pump();
      expect(controller.currentActiveStyle.bold, isTrue);

      // Cursor at offset 8 (inside 'normal') should have bold = false
      controller.selection = const TextSelection.collapsed(offset: 8);
      await tester.pump();
      expect(controller.currentActiveStyle.bold, isFalse);

      // 2. Typing after image clears style leak test
      controller.insertImage('assets/test.png');
      await tester.pump();
      final lastIdx = controller.text.length;
      controller.value = TextEditingValue(
        text: '${controller.text}a',
        selection: TextSelection.collapsed(offset: lastIdx + 1),
      );
      await tester.pump();
      expect(controller.styledChars[lastIdx].style.imageUrl, isNull);

      // 3. Image tap callback registration test
      bool imageTapped = false;
      controller.onTapImage = (index) {
        imageTapped = true;
      };
      // Trigger tap callback
      if (controller.onTapImage != null) {
        controller.onTapImage!(0);
      }
      expect(imageTapped, isTrue);
    });

    test('Sprint 5: Dividers and Hyperlinks in RichTextEditingController', () {
      final controller = RichTextEditingController();

      // 1. Parsing dividers from markdown
      controller.setMarkdown('Hello\n---\nWorld');
      expect(controller.styledChars.length, equals(13)); // H,e,l,l,o,\n, \u2014, \n, W,o,r,l,d
      expect(controller.styledChars[6].style.isDivider, isTrue);
      expect(controller.styledChars[6].char, equals('\u2014'));

      // 2. Serializing dividers back to markdown
      final markdown = generateMarkdownFromStyledChars(controller.styledChars);
      expect(markdown, contains('---\nWorld'));

      // 3. Programmatic insertion of Divider
      controller.value = const TextEditingValue(
        text: 'Hello World',
        selection: TextSelection.collapsed(offset: 6),
      );
      controller.insertDivider();
      expect(controller.text, contains('\u2014'));
      expect(controller.styledChars.any((sc) => sc.style.isDivider), isTrue);

      // 4. Parsing hyperlinks
      controller.setMarkdown('Check [Google](https://google.com) out');
      expect(controller.text, equals('Check Google out'));
      final googleChars = controller.styledChars.sublist(6, 12);
      for (final sc in googleChars) {
        expect(sc.style.linkUrl, equals('https://google.com'));
      }

      // 5. Serializing hyperlinks
      final linkMarkdown = generateMarkdownFromStyledChars(controller.styledChars);
      expect(linkMarkdown, equals('Check [Google](https://google.com) out'));
    });

    test('Sprint 5: Checklist Empty Item backspace and enter', () {
      final controller = RichTextEditingController();

      // 1. Enter on empty checklist item exits checklist mode
      controller.setMarkdown('- [ ] ');
      controller.value = const TextEditingValue(
        text: '\u2610\n',
        selection: TextSelection.collapsed(offset: 2),
      );
      expect(controller.text, equals('\n'));
      expect(controller.currentActiveStyle.listType, equals('normal'));

      // 2. Backspace on checklist prefix exits checklist mode
      controller.setMarkdown('- [ ] \nHello');
      controller.value = const TextEditingValue(
        text: '\nHello',
        selection: TextSelection.collapsed(offset: 0),
      );
      expect(controller.styledChars[0].char, equals('\n'));
      expect(controller.currentActiveStyle.listType, equals('normal'));
    });

    test('Sprint 6: Heading Enter and Backspace, Undo/Redo, Clipboard formatting', () {
      final controller = RichTextEditingController();

      // 1. Heading Enter resets to normal heading on newline
      controller.setMarkdown('# Heading');
      expect(controller.styledChars[0].style.heading, equals('h1'));

      controller.value = const TextEditingValue(
        text: 'Heading\n',
        selection: TextSelection.collapsed(offset: 8),
      );
      expect(controller.styledChars[7].char, equals('\n'));
      expect(controller.styledChars[7].style.heading, equals('normal'));
      expect(controller.currentActiveStyle.heading, equals('normal'));

      // 2. Heading Backspace at start of line converts to normal
      controller.setMarkdown('Line 1\n# Heading');
      controller.value = const TextEditingValue(
        text: 'Line 1Heading',
        selection: TextSelection.collapsed(offset: 6),
      );
      expect(controller.text, equals('Line 1\nHeading'));
      expect(controller.styledChars[7].style.heading, equals('normal'));
      expect(controller.currentActiveStyle.heading, equals('normal'));

      // 3. Undo/Redo
      controller.setMarkdown('Hello');
      controller.saveUndoState();
      
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
      controller.toggleStyleAttribute('bold');
      expect(controller.styledChars[0].style.bold, isTrue);

      controller.undo();
      expect(controller.styledChars[0].style.bold, isFalse);

      controller.redo();
      expect(controller.styledChars[0].style.bold, isTrue);
    });

    testWidgets('Sprint 7: SDE Caret Traversal and Focus Sync', (WidgetTester tester) async {
      final controller = RichTextEditingController();
      controller.setMarkdown('Hello\n![](assets/pic.png)\nWorld');

      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NewSingleDocumentEditor(
                controller: controller,
                focusNode: focusNode,
                textColor: Colors.black,
                paperGuideHeight: 20.0,
                contextMenuBuilder: (context, state) => const SizedBox.shrink(),
                formattingToolbarHeight: 50.0,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(2));

      await tester.tap(textFields.first);
      await tester.pump();
      final field1 = tester.widget<TextField>(textFields.first);
      expect(field1.focusNode?.hasFocus, isTrue);

      // Verify focus sync from parent controller selection
      controller.selection = const TextSelection.collapsed(offset: 8);
      await tester.pump();
      final field2 = tester.widget<TextField>(textFields.last);
      expect(field2.focusNode?.hasFocus, isTrue);

      // Verify Arrow Left key event at offset 0 moves focus back
      final lastController = field2.controller as RangeTextEditingController;
      lastController.selection = const TextSelection.collapsed(offset: 0);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(field1.focusNode?.hasFocus, isTrue);
    });

    testWidgets('Sprint 8: Layout Engine blocks and spacing', (WidgetTester tester) async {
      final controller = RichTextEditingController();
      controller.setMarkdown('# Hello\n## World\n> quote\n- bullet\n1. number\n- [ ] check');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NewSingleDocumentEditor(
                controller: controller,
                focusNode: FocusNode(),
                textColor: Colors.black,
                paperGuideHeight: 20.0,
                formattingToolbarHeight: 50.0,
                contextMenuBuilder: (context, state) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(6));

      final h1Field = tester.widget<TextField>(textFields.at(0));
      expect(h1Field.style?.fontSize, 24.0);

      final h2Field = tester.widget<TextField>(textFields.at(1));
      expect(h2Field.style?.fontSize, 20.0);

      final bulletField = find.descendant(
        of: find.byType(Row),
        matching: find.byWidget(tester.widget<TextField>(textFields.at(3))),
      );
      expect(bulletField, findsOneWidget);
    });

    testWidgets('Sprint 9: Interactive Checklist and Enter Continuation', (WidgetTester tester) async {
      // Skipped: Bullet/registry testing is out of scope for Checklist-only phase
    }, skip: true);

    testWidgets('Sprint 10: Rich Image Experience', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      final controller = RichTextEditingController();
      controller.setMarkdown('Hello\n![](assets/pic.png)\nWorld');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NewSingleDocumentEditor(
                controller: controller,
                focusNode: FocusNode(),
                textColor: Colors.black,
                paperGuideHeight: 20.0,
                formattingToolbarHeight: 50.0,
                contextMenuBuilder: (context, state) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      final imageFinder = find.byType(NewImageWidget);
      expect(imageFinder, findsOneWidget);

      NewImageWidget imageWidget = tester.widget<NewImageWidget>(imageFinder);
      expect(imageWidget.isSelected, isFalse);

      await tester.tap(imageFinder);
      await tester.pump();

      imageWidget = tester.widget<NewImageWidget>(imageFinder);
      expect(imageWidget.isSelected, isTrue);

      expect(find.byTooltip('Resize'), findsOneWidget);
      expect(find.byTooltip('Delete'), findsOneWidget);

      imageWidget.onResize(400.0);
      await tester.pump();
      expect(controller.styledChars[6].style.imageWidth, 400.0);

      imageWidget.onDelete();
      await tester.pump();

      expect(find.byType(NewImageWidget), findsNothing);
      expect(controller.styledChars.map((sc) => sc.char).join().contains('\uFFFC'), isFalse);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('Sprint 11: Editor Intelligence', (WidgetTester tester) async {
      // Skipped: Out of scope for Checklist-only phase
    }, skip: true);

    testWidgets('Sprint 11A: Perfect Checklist Engine', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      final controller = RichTextEditingController();
      controller.setMarkdown('Checklist item 1');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NewSingleDocumentEditor(
                controller: controller,
                focusNode: FocusNode(),
                textColor: Colors.black,
                paperGuideHeight: 20.0,
                formattingToolbarHeight: 50.0,
                contextMenuBuilder: (context, state) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // 1. Verify applying Checklist from paragraph shifts cursor offset correctly
      final textFields = find.byType(TextField);
      expect(textFields, findsOneWidget);

      final pField = tester.widget<TextField>(textFields);
      final pController = pField.controller as RangeTextEditingController;
      pField.focusNode?.requestFocus();
      await tester.pump();

      // Set cursor at index 0 (very start of 'Checklist item 1')
      pController.selection = const TextSelection.collapsed(offset: 0);
      await tester.pump();

      // Toggle checklist style
      controller.toggleParagraphStyle('checkbox');
      await tester.pump();

      // Verify prefix was added
      expect(pController.text, '\u2610Checklist item 1');
      // The cursor should have shifted past the checkbox prefix (index 1) rather than remaining at index 0
      expect(pController.selection, const TextSelection.collapsed(offset: 1));

      // 2. Test Smart Enter - Continue checklist
      // Place cursor at the end of the checklist line ('\u2610Checklist item 1|')
      pController.selection = const TextSelection.collapsed(offset: 17);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      // A new checkbox segment should be appended
      expect(find.byType(TextField), findsNWidgets(2));
      final nextField = tester.widget<TextField>(find.byType(TextField).at(1));
      final nextController = nextField.controller as RangeTextEditingController;
      expect(nextController.text, '\u2610');

      // 3. Test Smart Enter - Exit empty checklist
      // Pressing enter on an empty checklist item should remove it and convert to paragraph
      nextField.focusNode?.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      // Formatting should be exited, leaving a normal paragraph
      expect(nextController.text.isEmpty, isTrue);

      // Verify typing a character does not re-apply the checklist after Enter exit
      nextController.value = const TextEditingValue(
        text: 'a',
        selection: TextSelection.collapsed(offset: 1),
      );
      await tester.pump();
      expect(nextController.text, 'a');

      // 4. Test Smart Backspace - Remove checklist formatting
      // Let's toggle the first field back to checklist, then make it empty, and backspace it.
      pField.focusNode?.requestFocus();
      await tester.pump();

      // Empty the item text except prefix
      pController.value = const TextEditingValue(
        text: '\u2610',
        selection: TextSelection.collapsed(offset: 1),
      );
      await tester.pump();

      // Press backspace on empty checklist item
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      // Checklist prefix should be stripped, converting it back to a normal empty paragraph
      expect(pController.text.isEmpty, isTrue);

      // Verify typing a character does not re-apply the checklist after Backspace remove
      pController.value = const TextEditingValue(
        text: 'b',
        selection: TextSelection.collapsed(offset: 1),
      );
      await tester.pump();
      expect(pController.text, 'b');

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('Sprint 11B: Perfect Checklist Engine Indentation and Premium Interactions', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 1920));

      final controller = RichTextEditingController();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: SingleChildScrollView(
              child: NewSingleDocumentEditor(
                controller: controller,
                focusNode: focusNode,
                textColor: Colors.black,
                paperGuideHeight: 1.0,
                formattingToolbarHeight: 0,
                contextMenuBuilder: (context, editableTextState) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();

      // 1. Test Markdown Parsing with indentation
      // We parse an indented checkbox list
      controller.setMarkdown('  - [ ] Nested Check\n    - [ ] Checklist Level 2');
      await tester.pump();

      expect(find.byType(TextField), findsNWidgets(2));

      final field1 = tester.widget<TextField>(find.byType(TextField).at(0));
      final controller1 = field1.controller as RangeTextEditingController;
      
      final field2 = tester.widget<TextField>(find.byType(TextField).at(1));
      final controller2 = field2.controller as RangeTextEditingController;

      // Check parsed indent levels
      expect(controller.styledChars[0].style.indent, equals(1)); // 2 spaces
      expect(controller.styledChars[controller1.text.length + 1].style.indent, equals(2)); // 4 spaces

      // 2. Test Markdown Generation with indentation
      final generatedMarkdown = generateMarkdownFromStyledChars(controller.styledChars);
      expect(generatedMarkdown.contains('  - [ ] Nested Check'), isTrue);
      expect(generatedMarkdown.contains('    - [ ] Checklist Level 2'), isTrue);

      // 3. Test Interactive Tab Indentation
      field1.focusNode?.requestFocus();
      await tester.pump();

      // Send Tab key -> should increase indent level from 1 to 2
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(controller.styledChars[0].style.indent, equals(2));

      // Send Shift + Tab -> should decrease indent level from 2 to 1
      // Simulate shift key down
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(controller.styledChars[0].style.indent, equals(1));

      // 4. Test Enter Key outdenting on empty indented list item
      // We clear the second field text (leaving only checkbox prefix)
      controller2.value = const TextEditingValue(
        text: '☐',
        selection: TextSelection.collapsed(offset: 1),
      );
      field2.focusNode?.requestFocus();
      await tester.pump();

      // Hitting enter on indented checklist item should first outdent it
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      // Checklist level 2 has indent 2. Hitting enter once should outdent it to level 1.
      expect(controller.styledChars[controller1.text.length + 1].style.indent, equals(1));

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('Sprint 11B: Soft Keyboard Newline Insertion and List Continuation', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 1920));

      final controller = RichTextEditingController();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: SingleChildScrollView(
              child: NewSingleDocumentEditor(
                controller: controller,
                focusNode: focusNode,
                textColor: Colors.black,
                paperGuideHeight: 1.0,
                formattingToolbarHeight: 0,
                contextMenuBuilder: (context, editableTextState) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();

      // Set initial checkbox content
      controller.setMarkdown('- [ ] Checklist Item 1');
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      final segmentController = field.controller as RangeTextEditingController;

      // Simulate a soft keyboard Enter key press by inserting a newline at the end of the text
      // segmentController.text is "\u2610Checklist Item 1" (length 17)
      // The cursor is at the end (offset 17). With the typed \n, length is 18.
      segmentController.value = const TextEditingValue(
        text: '\u2610Checklist Item 1\n',
        selection: TextSelection.collapsed(offset: 18),
      );
      await tester.pumpAndSettle();

      // The document should now have two lines, both with checkbox prefixes:
      // Line 1: "\u2610Checklist Item 1"
      // Line 2: "\u2610"
      expect(controller.text, equals('\u2610Checklist Item 1\n\u2610'));
      expect(find.byType(TextField), findsNWidgets(2));

      final field2 = tester.widget<TextField>(find.byType(TextField).at(1));
      final segmentController2 = field2.controller as RangeTextEditingController;

      // Simulate a soft keyboard Enter key press on the empty second checklist item
      // segmentController2.text is "\u2610"
      // The cursor is at the end (offset 1)
      segmentController2.value = const TextEditingValue(
        text: '\u2610\n',
        selection: TextSelection.collapsed(offset: 2),
      );
      await tester.pumpAndSettle();

      // The second checklist item should have been converted to a normal empty paragraph (prefix removed)
      // The document text should now be "\u2610Checklist Item 1\n" (Line 1 is checkbox, Line 2 is empty normal paragraph)
      expect(controller.text, equals('\u2610Checklist Item 1\n'));
      expect(find.byType(TextField), findsNWidgets(2));

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('Sprint 11B: Layout Overflow Prevention on Narrow Devices', (WidgetTester tester) async {
      // 1. Verify TaskWidget fits on narrow widths (e.g. 280) and does not throw RenderFlex overflows
      final mockTasks = [
        TaskItem(
          id: 't1',
          title: 'Finalize Proposal',
          dueDate: DateTime.now(),
          priority: 'High',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TaskWidget(
                tasks: mockTasks,
                width: 280.0,
                onComplete: (_) {},
                onEdit: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(TaskWidget), findsOneWidget);

      // 2. Verify FolderGridCard does not overflow under tight constraints
      final mockFolder = Folder(
        id: 'f1',
        name: 'Work',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 140.0,
                height: 170.0, // tight height constraint leading to shrink
                child: FolderGridCard(
                  folder: mockFolder,
                  index: 0,
                  noteCount: 5,
                  onTap: () {},
                  onLongPressStart: (_) {},
                  onCustomizeTap: () {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(FolderGridCard), findsOneWidget);
    });

    testWidgets('Sprint 11B: Checklist Auto Capitalization and Manual Lowercase Override', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 1920));

      final controller = RichTextEditingController();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NewSingleDocumentEditor(
                controller: controller,
                focusNode: focusNode,
                textColor: Colors.black,
                paperGuideHeight: 1.0,
                formattingToolbarHeight: 50.0,
                contextMenuBuilder: (context, editableTextState) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      final textFields = find.byType(TextField);
      expect(textFields, findsOneWidget);

      final pField = tester.widget<TextField>(textFields);
      final pController = pField.controller as RangeTextEditingController;
      pField.focusNode?.requestFocus();
      await tester.pump();

      // Set controller to checkbox prefix
      pController.value = const TextEditingValue(
        text: '\u2610',
        selection: TextSelection.collapsed(offset: 1),
      );
      await tester.pump();
      expect(pController.text, '\u2610');

      // 1. Verify auto-capitalization: typing lowercase 'a' results in '☐A'
      pController.value = const TextEditingValue(
        text: '\u2610a',
        selection: TextSelection.collapsed(offset: 2),
      );
      await tester.pump();
      expect(pController.text, '\u2610A');

      // 2. Verify backspace revert: backspacing 'A' reverts to '☐a' (lowercase)
      pController.value = const TextEditingValue(
        text: '\u2610',
        selection: TextSelection.collapsed(offset: 1),
      );
      await tester.pump();
      expect(pController.text, '\u2610a'); // Reverted to lowercase!

      // Pressing backspace again deletes 'a' completely, returning to '☐'
      pController.value = const TextEditingValue(
        text: '\u2610',
        selection: TextSelection.collapsed(offset: 1),
      );
      await tester.pump();
      expect(pController.text, '\u2610'); // Successfully cleared!

      // 3. Verify resetting allowCapitalization when checklist item is cleared or recreated
      pController.value = const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
      await tester.pump();

      pController.value = const TextEditingValue(
        text: '\u2610',
        selection: TextSelection.collapsed(offset: 1),
      );
      await tester.pump();
      expect(pController.text, '\u2610');

      pController.value = const TextEditingValue(
        text: '\u2610b',
        selection: TextSelection.collapsed(offset: 2),
      );
      await tester.pump();
      expect(pController.text, '\u2610B'); // Auto-capitalizes again!

      // 4. Verify style propagation: typing multiple words on a checklist line and continuing with Enter
      pController.value = const TextEditingValue(
        text: '\u2610milk container and packet',
        selection: TextSelection.collapsed(offset: 27),
      );
      await tester.pump();

      // Press enter to continue checklist
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      // A new checklist item should be created in the next segment
      expect(find.byType(TextField), findsNWidgets(2));
      final nextField = tester.widget<TextField>(find.byType(TextField).at(1));
      final nextController = nextField.controller as RangeTextEditingController;
      expect(nextController.text, '\u2610');

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('Sprint 11B: Bullet List Continuation on Enter', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 1920));

      final controller = RichTextEditingController();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NewSingleDocumentEditor(
                controller: controller,
                focusNode: focusNode,
                textColor: Colors.black,
                paperGuideHeight: 1.0,
                formattingToolbarHeight: 50.0,
                contextMenuBuilder: (context, editableTextState) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      final textFields = find.byType(TextField);
      expect(textFields, findsOneWidget);

      final pField = tester.widget<TextField>(textFields);
      final pController = pField.controller as RangeTextEditingController;
      pField.focusNode?.requestFocus();
      await tester.pump();

      pController.value = const TextEditingValue(
        text: '•Milk container',
        selection: TextSelection.collapsed(offset: 15),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(find.byType(TextField), findsNWidgets(2));
      final nextController = tester.widget<TextField>(find.byType(TextField).at(1)).controller as RangeTextEditingController;
      expect(nextController.text, '•');

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('Sprint 11B: Numbered List Continuation on Enter', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 1920));

      final controller = RichTextEditingController();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NewSingleDocumentEditor(
                controller: controller,
                focusNode: focusNode,
                textColor: Colors.black,
                paperGuideHeight: 1.0,
                formattingToolbarHeight: 50.0,
                contextMenuBuilder: (context, editableTextState) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      final textFields = find.byType(TextField);
      expect(textFields, findsOneWidget);

      final pField = tester.widget<TextField>(textFields);
      final pController = pField.controller as RangeTextEditingController;
      pField.focusNode?.requestFocus();
      await tester.pump();

      pController.value = const TextEditingValue(
        text: '\u2008First step',
        selection: TextSelection.collapsed(offset: 11),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(find.byType(TextField), findsNWidgets(2));
      final nextController = tester.widget<TextField>(find.byType(TextField).at(1)).controller as RangeTextEditingController;
      expect(nextController.text, '\u2008');

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('Sprint 11B: Quote Block Continuation on Enter', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 1920));

      final controller = RichTextEditingController();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NewSingleDocumentEditor(
                controller: controller,
                focusNode: focusNode,
                textColor: Colors.black,
                paperGuideHeight: 1.0,
                formattingToolbarHeight: 50.0,
                contextMenuBuilder: (context, editableTextState) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      final textFields = find.byType(TextField);
      expect(textFields, findsOneWidget);

      final pField = tester.widget<TextField>(textFields);
      final pController = pField.controller as RangeTextEditingController;
      pField.focusNode?.requestFocus();
      await tester.pump();

      pController.value = const TextEditingValue(
        text: '›Quote line',
        selection: TextSelection.collapsed(offset: 11),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(find.byType(TextField), findsNWidgets(2));
      final nextController = tester.widget<TextField>(find.byType(TextField).at(1)).controller as RangeTextEditingController;
      expect(nextController.text, '›');

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('Sprint 11B: Quote Italic Style Persistence Fix', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 1920));

      final controller = RichTextEditingController();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NewSingleDocumentEditor(
                controller: controller,
                focusNode: focusNode,
                textColor: Colors.black,
                paperGuideHeight: 1.0,
                formattingToolbarHeight: 50.0,
                contextMenuBuilder: (context, editableTextState) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      final textFields = find.byType(TextField);
      expect(textFields, findsOneWidget);

      final pField = tester.widget<TextField>(textFields);
      final pController = pField.controller as RangeTextEditingController;
      pField.focusNode?.requestFocus();
      await tester.pump();

      // Type a quote block with text
      pController.value = const TextEditingValue(
        text: '›some text',
        selection: TextSelection.collapsed(offset: 10),
      );
      await tester.pump();

      // Verify that characters in quote do not have italic=true in their actual style
      expect(controller.styledChars[1].char, 's');
      expect(controller.styledChars[1].style.italic, false);

      // Backspace the prefix '›'
      pController.value = const TextEditingValue(
        text: 'some text',
        selection: TextSelection.collapsed(offset: 9),
      );
      await tester.pump();

      // Verify that typing after removing quote does not result in italic text
      pController.value = const TextEditingValue(
        text: 'some texta',
        selection: TextSelection.collapsed(offset: 10),
      );
      await tester.pump();

      expect(controller.styledChars[9].char, 'a');
      expect(controller.styledChars[9].style.italic, false);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('Sprint 11B: Aa Bold Toggle and Typing Inheritance', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 1920));

      final controller = RichTextEditingController();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NewSingleDocumentEditor(
                controller: controller,
                focusNode: focusNode,
                textColor: Colors.black,
                paperGuideHeight: 1.0,
                formattingToolbarHeight: 50.0,
                contextMenuBuilder: (context, editableTextState) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      final textFields = find.byType(TextField);
      expect(textFields, findsOneWidget);

      final pField = tester.widget<TextField>(textFields);
      final pController = pField.controller as RangeTextEditingController;
      pField.focusNode?.requestFocus();
      await tester.pump();

      // Set initial text "hello"
      pController.value = const TextEditingValue(
        text: 'hello',
        selection: TextSelection.collapsed(offset: 5),
      );
      await tester.pump();

      // Move cursor to middle of "hello" (index 3, after second 'l') -> wait, "hello" has:
      // h (0), e (1), l (2), l (3), o (4)
      // selection offset 3 is after first 'l' (index 2)
      pController.value = const TextEditingValue(
        text: 'hello',
        selection: TextSelection.collapsed(offset: 3),
      );
      await tester.pump();

      // Toggle Bold
      controller.toggleStyleAttribute('bold');
      await tester.pump();

      // Verify typing state style has bold = true
      expect(controller.currentActiveStyle.bold, true);

      // Type character 'x' at cursor position 3
      pController.value = const TextEditingValue(
        text: 'helxlo',
        selection: TextSelection.collapsed(offset: 4),
      );
      await tester.pump();

      // The inserted character at index 3 ('x') must be bold
      expect(controller.styledChars[3].char, 'x');
      expect(controller.styledChars[3].style.bold, true);

      // Other characters (e.g. 'e' at index 1) must remain normal
      expect(controller.styledChars[1].char, 'e');
      expect(controller.styledChars[1].style.bold, false);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('Sprint 11B: Aa Active Selection Style Synchronization', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 1920));

      final controller = RichTextEditingController();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NewSingleDocumentEditor(
                controller: controller,
                focusNode: focusNode,
                textColor: Colors.black,
                paperGuideHeight: 1.0,
                formattingToolbarHeight: 50.0,
                contextMenuBuilder: (context, editableTextState) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      final textFields = find.byType(TextField);
      expect(textFields, findsOneWidget);

      final pField = tester.widget<TextField>(textFields);
      final pController = pField.controller as RangeTextEditingController;
      pField.focusNode?.requestFocus();
      await tester.pump();

      // Set initial text "hello"
      pController.value = const TextEditingValue(
        text: 'hello',
        selection: TextSelection.collapsed(offset: 5),
      );
      await tester.pump();

      // Bold 'e' and 'l' (index 1 and 2)
      controller.selection = const TextSelection(baseOffset: 1, extentOffset: 3);
      controller.toggleStyleAttribute('bold');
      await tester.pump();

      // Verify characters are bold
      expect(controller.styledChars[1].char, 'e');
      expect(controller.styledChars[1].style.bold, true);
      expect(controller.styledChars[2].char, 'l');
      expect(controller.styledChars[2].style.bold, true);

      // Select bold characters only: range (1, 3)
      pController.value = const TextEditingValue(
        text: 'hello',
        selection: TextSelection(baseOffset: 1, extentOffset: 3),
      );
      await tester.pump();

      // Verify active style shows bold = true
      expect(controller.currentActiveStyle.bold, true);

      // Select mixed characters: range (0, 3) (which includes 'h' which is not bold)
      pController.value = const TextEditingValue(
        text: 'hello',
        selection: TextSelection(baseOffset: 0, extentOffset: 3),
      );
      await tester.pump();

      // Verify active style shows bold = false
      expect(controller.currentActiveStyle.bold, false);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('Sprint 11B: Emoji Input and Newline Continuation Verification', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 1920));

      final controller = RichTextEditingController();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NewSingleDocumentEditor(
                controller: controller,
                focusNode: focusNode,
                textColor: Colors.black,
                paperGuideHeight: 1.0,
                formattingToolbarHeight: 50.0,
                contextMenuBuilder: (context, editableTextState) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      final textFields = find.byType(TextField);
      expect(textFields, findsOneWidget);

      final pField = tester.widget<TextField>(textFields);
      final pController = pField.controller as RangeTextEditingController;
      pField.focusNode?.requestFocus();
      await tester.pump();

      // 1. Type a surrogate-pair emoji '😃' (length 2)
      pController.value = const TextEditingValue(
        text: 'hello 😃',
        selection: TextSelection.collapsed(offset: 8),
      );
      await tester.pump();

      expect(pController.text, 'hello 😃');
      expect(controller.styledChars.length, 8);

      // 2. Press Enter to go to the next line (by sending newline in value)
      pController.value = const TextEditingValue(
        text: 'hello 😃\n',
        selection: TextSelection.collapsed(offset: 9),
      );
      await tester.pump(); // Executes post-frame callback
      await tester.pump(); // Renders the second TextField segment

      // Verify that a new TextField/segment is created
      expect(find.byType(TextField), findsNWidgets(2));

      final nextController = tester.widget<TextField>(find.byType(TextField).at(1)).controller as RangeTextEditingController;
      expect(nextController.text, '');

      // 3. Delete the emoji in the first TextField
      pField.focusNode?.requestFocus();
      await tester.pump();

      pController.value = const TextEditingValue(
        text: 'hello ',
        selection: TextSelection.collapsed(offset: 6),
      );
      await tester.pump();

      expect(pController.text, 'hello ');

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('Sprint 11B: Multi-line Block Alignment Unified Toggling', (WidgetTester tester) async {
      final controller = RichTextEditingController();
      controller.text = 'Line one\nLine two';

      // 1. Center align the first line only
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 8);
      controller.toggleParagraphStyle('align-center');

      expect(controller.styledChars[0].style.align, TextAlign.center);
      expect(controller.styledChars[9].style.align, TextAlign.left);

      // 2. Select both lines (mixed alignment: line 1 center, line 2 left)
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 17);
      
      // Tapping Center Align should unify both lines to center
      controller.toggleParagraphStyle('align-center');
      expect(controller.styledChars[0].style.align, TextAlign.center);
      expect(controller.styledChars[9].style.align, TextAlign.center);

      // 3. Select both lines again (all centered) and tap Center Align
      // Tapping should revert both to Left alignment
      controller.toggleParagraphStyle('align-center');
      expect(controller.styledChars[0].style.align, TextAlign.left);
      expect(controller.styledChars[9].style.align, TextAlign.left);
    });

    testWidgets('Sprint 11B: Selection Alignment Style Highlight Sync', (WidgetTester tester) async {
      final controller = RichTextEditingController();
      controller.text = 'Line one\nLine two';

      // Center align both lines
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 17);
      controller.toggleParagraphStyle('align-center');

      // Select center-aligned characters
      controller.selection = const TextSelection(baseOffset: 2, extentOffset: 6);
      expect(controller.currentActiveStyle.align, TextAlign.center);

      // Select mixed-aligned characters (e.g. modify line 1 back to left)
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 8);
      controller.toggleParagraphStyle('align-center'); // reverts line 1 to left

      // Select across both lines (mixed alignments)
      controller.selection = const TextSelection(baseOffset: 2, extentOffset: 12);
      expect(controller.currentActiveStyle.align, TextAlign.left);
    });

    testWidgets('Sprint 11B: Multi-line List/Heading Unified Toggling', (WidgetTester tester) async {
      final controller = RichTextEditingController();
      controller.text = 'Line one\nLine two';

      // 1. Make first line h1 only
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 8);
      controller.toggleParagraphStyle('h1');

      expect(controller.styledChars[0].style.heading, 'h1');
      expect(controller.styledChars[9].style.heading, 'normal');

      // 2. Select both lines (mixed headings: line 1 h1, line 2 normal)
      // Toggling h1 should unify both to h1
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 17);
      controller.toggleParagraphStyle('h1');
      expect(controller.styledChars[0].style.heading, 'h1');
      expect(controller.styledChars[9].style.heading, 'h1');

      // 3. Toggling h1 again should revert both to normal
      controller.toggleParagraphStyle('h1');
      expect(controller.styledChars[0].style.heading, 'normal');
      expect(controller.styledChars[9].style.heading, 'normal');
    });
  });
}
