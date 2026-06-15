import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/views/screens/home_screen.dart';
import 'package:quick_notes/views/screens/folder_management_screen.dart';
import 'package:quick_notes/views/screens/note_editor_screen.dart';
import 'package:quick_notes/views/widgets/note_card.dart';
import 'package:quick_notes/views/widgets/rich_text_controller.dart';
import 'package:quick_notes/views/widgets/home_prompt_view.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    GoogleFonts.config.allowRuntimeFetching = false;

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
        (widget) => widget is TextField && widget.decoration?.hintText == 'Note Title',
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

    testWidgets('Issue 2: Checklist typing check', (WidgetTester tester) async {
      final checklistNote = Note(
        id: 'test_checklist',
        title: 'Checklist Title',
        content: jsonEncode([
          {'text': 'Buy milk', 'done': false},
          {'text': 'Walk dog', 'done': true},
        ]),
        tags: [],
        attachments: [],
        category: 'Work',
        noteType: 'checklist',
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
            home: NoteEditorScreen(note: checklistNote),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      final itemFinder = find.byWidgetPredicate(
        (widget) => widget is TextField && widget.decoration?.hintText == 'List item',
      );
      expect(itemFinder, findsNWidgets(2));

      final TextField firstItemField = tester.widget(itemFinder.first);
      expect(firstItemField.decoration?.filled, isFalse);
      expect(firstItemField.controller.runtimeType, equals(TextEditingController));
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
      expect(find.text('Start writing...'), findsOneWidget);

      // Tap on Folders tab (index 1) which shows FolderManagementScreen
      final folderIconFinder = find.byKey(const Key('nav_folders'));
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
                note: note,
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

    testWidgets('Checking standard caret controller doesn\'t fail type checks', (WidgetTester tester) async {
      final checklistNote = Note(
        id: 'test_checklist_2',
        title: 'Checklist Title 2',
        content: jsonEncode([
          {'text': 'Buy milk', 'done': false},
        ]),
        tags: [],
        attachments: [],
        category: 'Work',
        noteType: 'checklist',
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
            home: NoteEditorScreen(note: checklistNote),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(NoteEditorScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('Rich formatting toolbar and PageView navigation check', (WidgetTester tester) async {
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

      // Verify that the formatting toolbar with PageView is present
      final pageViewFinder = find.byType(PageView);
      expect(pageViewFinder, findsOneWidget);

      // Page 0: Text style options
      expect(find.byTooltip('Bold'), findsOneWidget);
      expect(find.byTooltip('Italic'), findsOneWidget);
      expect(find.byTooltip('Underline'), findsOneWidget);
      expect(find.byTooltip('Strikethrough'), findsOneWidget);
      expect(find.byTooltip('Highlight'), findsOneWidget);
      expect(find.byTooltip('Link'), findsOneWidget);

      // Find both left and right arrow buttons (Icons.play_arrow_rounded)
      final arrowButtons = find.byIcon(Icons.play_arrow_rounded);
      expect(arrowButtons, findsNWidgets(2));

      // Tap the right arrow button (last in widget tree) to slide to Page 1
      await tester.tap(arrowButtons.last);
      await tester.pumpAndSettle();

      // Page 1: Headings & Lists options
      expect(find.byTooltip('Heading 1'), findsOneWidget);
      expect(find.byTooltip('Heading 2'), findsOneWidget);
      expect(find.byTooltip('Heading 3'), findsOneWidget);
      expect(find.byTooltip('Bullet List'), findsOneWidget);
      expect(find.byTooltip('Numbered List'), findsOneWidget);
      expect(find.byTooltip('Checklist'), findsOneWidget);

      // Tap the right arrow button again to slide to Page 2
      await tester.tap(arrowButtons.last);
      await tester.pumpAndSettle();

      // Page 2: Alignments & Actions options
      expect(find.byTooltip('Align Left'), findsOneWidget);
      expect(find.byTooltip('Align Center'), findsOneWidget);
      expect(find.byTooltip('Align Right'), findsOneWidget);
      expect(find.byTooltip('Align Justify'), findsOneWidget);
      expect(find.byTooltip('Attach Image'), findsOneWidget);
      expect(find.byTooltip('Record Audio'), findsOneWidget);
      expect(find.byTooltip('Hide Keyboard'), findsOneWidget);
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

      final arrowButtons = find.byIcon(Icons.play_arrow_rounded);
      expect(arrowButtons, findsNWidgets(2));

      await tester.tap(arrowButtons.last);
      await tester.pumpAndSettle();
      await tester.tap(arrowButtons.last);
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
        (w) => w is TextField && w.decoration?.hintText != 'Note Title',
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
      final steps = 10;
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
      expect(note.paperGuideVisible, isTrue);
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
      expect(find.text('No notes yet'), findsOneWidget);

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
  });
}
