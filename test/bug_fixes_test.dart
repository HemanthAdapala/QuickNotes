import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/views/screens/navigation_shell.dart';
import 'package:quick_notes/views/screens/note_editor_screen.dart';
import 'package:quick_notes/views/screens/notes_list_screen.dart';
import 'package:quick_notes/views/widgets/note_card.dart';
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
          child: const MaterialApp(
            home: NoteEditorScreen(),
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
    });

    testWidgets('Issue 3: Drawer Sync / unique keys check', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => NotesProvider()),
          ],
          child: MaterialApp(
            home: NavigationShell(
              isDarkMode: true,
              onThemeToggle: () {},
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      final feedScreenFinder = find.byType(NotesListScreen);
      expect(feedScreenFinder, findsOneWidget);

      final NotesListScreen feedScreen = tester.widget(feedScreenFinder);
      expect(feedScreen.key, const ValueKey(NotesViewType.feed));

      final scaffoldState = tester.firstState(find.byType(Scaffold)) as ScaffoldState;
      scaffoldState.openDrawer();
      await tester.pump(const Duration(milliseconds: 500));

      final archiveTileFinder = find.byWidgetPredicate(
        (widget) => widget is ListTile && widget.title is Text && (widget.title as Text).data == 'Archive',
      );
      expect(archiveTileFinder, findsOneWidget);

      await tester.tap(archiveTileFinder);
      await tester.pump(const Duration(milliseconds: 500));

      final archiveScreenFinder = find.byType(NotesListScreen);
      expect(archiveScreenFinder, findsOneWidget);

      final NotesListScreen archiveScreen = tester.widget(archiveScreenFinder);
      expect(archiveScreen.key, const ValueKey(NotesViewType.archive));
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
    });
  });
}
