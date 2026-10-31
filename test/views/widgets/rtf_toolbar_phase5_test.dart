// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:quick_notes/models/folder.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/models/session_type.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/repositories/folders_repository.dart';
import 'package:quick_notes/repositories/notes_repository.dart';
import 'package:quick_notes/services/session_manager.dart';
import 'package:quick_notes/views/screens/note_editor_screen.dart';
import 'package:quick_notes/views/widgets/new_single_document_editor.dart';
import 'package:quick_notes/views/widgets/rich_text_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestAudioplayersPlatform extends AudioplayersPlatformInterface {
  final Map<String, StreamController<AudioEvent>> _eventControllers = {};

  @override
  Future<void> create(String playerId) async {
    _eventControllers[playerId] = StreamController<AudioEvent>.broadcast();
  }

  @override
  Future<void> dispose(String playerId) async {
    _eventControllers[playerId]?.close();
    _eventControllers.remove(playerId);
  }

  @override
  Future<void> emitError(String playerId, String code, String message) async {}
  @override
  Future<void> emitLog(String playerId, String message) async {}
  @override
  Future<int?> getCurrentPosition(String playerId) async => 0;
  @override
  Future<int?> getDuration(String playerId) async => 0;
  @override
  Future<void> pause(String playerId) async {}
  @override
  Future<void> release(String playerId) async {}
  @override
  Future<void> resume(String playerId) async {}
  @override
  Future<void> seek(String playerId, Duration position) async {}
  @override
  Future<void> setAudioContext(
      String playerId, AudioContext audioContext) async {}
  @override
  Future<void> setBalance(String playerId, double balance) async {}
  @override
  Future<void> setPlaybackRate(String playerId, double playbackRate) async {}
  @override
  Future<void> setPlayerMode(String playerId, PlayerMode playerMode) async {}
  @override
  Future<void> setReleaseMode(String playerId, ReleaseMode releaseMode) async {}
  @override
  Future<void> setSourceBytes(String playerId, Uint8List bytes,
      {String? mimeType}) async {}
  @override
  Future<void> setSourceUrl(String playerId, String url,
      {bool? isLocal, String? mimeType}) async {
    _eventControllers[playerId]?.add(
      const AudioEvent(eventType: AudioEventType.prepared, isPrepared: true),
    );
  }

  @override
  Future<void> setVolume(String playerId, double volume) async {}
  @override
  Future<void> stop(String playerId) async {}
  @override
  Stream<AudioEvent> getEventStream(String playerId) {
    return _eventControllers
        .putIfAbsent(playerId, () => StreamController<AudioEvent>.broadcast())
        .stream;
  }
}

class _TestGlobalAudioplayersPlatform
    extends GlobalAudioplayersPlatformInterface {
  final StreamController<GlobalAudioEvent> _globalEventController =
      StreamController<GlobalAudioEvent>.broadcast();

  @override
  Future<void> init() async {}
  @override
  Future<void> setGlobalAudioContext(AudioContext ctx) async {}
  @override
  Future<void> emitGlobalLog(String message) async {}
  @override
  Future<void> emitGlobalError(String code, String message) async {}
  @override
  Stream<GlobalAudioEvent> getGlobalEventStream() =>
      _globalEventController.stream;
}

class _MockNotesRepository implements NotesRepository {
  final Map<String, Note> storage = {};
  @override
  Future<List<Note>> getNotes() async =>
      storage.values.where((n) => !n.isDeleted).toList();
  @override
  Future<List<Note>> getTrashNotes() async =>
      storage.values.where((n) => n.isDeleted).toList();
  @override
  Future<Note?> getNoteById(String id) async => storage[id];
  @override
  Future<List<Note>> queryHabits() async => [];
  @override
  Future<int> updateNote(Note note) async {
    storage[note.id] = note;
    return 1;
  }
  @override
  Future<int> insertNote(Note note) async {
    storage[note.id] = note;
    return 1;
  }
  @override
  Future<List<Map<String, dynamic>>> queryNotesSummaryPaged({
    String? folderId,
    String? category,
    bool? isFavorite,
    bool? isArchived,
    bool isDeleted = false,
    int limit = 20,
    int offset = 0,
  }) async =>
      storage.values.map((n) => n.toMap()).toList();
  @override
  Future<List<Note>> searchNotes(String query) async => [];
  @override
  Future<int> togglePin(String id) async => 1;
  @override
  Future<int> toggleFavorite(String id) async => 1;
  @override
  Future<int> toggleArchive(String id) async => 1;
  @override
  Future<int> trashNote(String id) async => 1;
  @override
  Future<int> restoreNote(String id) async => 1;
  @override
  Future<int> deleteNote(String id) async {
    storage.remove(id);
    return 1;
  }
  @override
  Future<int> emptyTrash() async {
    storage.removeWhere((k, v) => v.isDeleted);
    return 1;
  }
}

class _MockFoldersRepository implements FoldersRepository {
  @override
  Future<List<Folder>> getFolders() async => [];
  @override
  Future<List<Folder>> getTrashFolders() async => [];
  @override
  Future<int> insertFolder(Folder folder) async => 1;
  @override
  Future<int> updateFolder(Folder folder) async => 1;
  @override
  Future<int> trashFolder(String id) async => 1;
  @override
  Future<int> restoreFolder(String id) async => 1;
  @override
  Future<int> deleteFolder(String id) async => 1;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;

    late final MessageHandler fontHandler;
    fontHandler = (ByteData? message) async {
      if (message == null) return null;
      final Uint8List list = message.buffer
          .asUint8List(message.offsetInBytes, message.lengthInBytes);
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
            .setMockMessageHandler('flutter/assets', fontHandler);
      }
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', fontHandler);

    const MethodChannel homeWidgetChannel = MethodChannel('home_widget');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            homeWidgetChannel, (MethodCall methodCall) async => true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('class.yiss.home_widget'),
            (MethodCall methodCall) async => true);

    const MethodChannel notificationsChannel =
        MethodChannel('dexterous.com/flutter_local_notifications');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            notificationsChannel, (MethodCall methodCall) async => true);

    const MethodChannel pathChannel =
        MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            pathChannel, (MethodCall methodCall) async => '.');

    AudioplayersPlatformInterface.instance = _TestAudioplayersPlatform();
    GlobalAudioplayersPlatformInterface.instance =
        _TestGlobalAudioplayersPlatform();
  });

  group('RTF-014: Controller _getTextOnly StringBuffer Optimization', () {
    test('Optimized _getTextOnly accurately reflects text content across mutations', () {
      final controller = RichTextEditingController(markdown: 'Hello **World**!');
      expect(controller.text, equals('Hello World!'));

      // Mutate via setStyleAttribute
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
      controller.setStyleAttribute('color', enable: true, value: const Color(0xFFFF3B30));
      expect(controller.text, equals('Hello World!'));

      // Mutate via setMarkdown
      controller.setMarkdown('Line 1\nLine 2 with <span highlight="0xffffcc80">orange</span>');
      expect(controller.text, equals('Line 1\nLine 2 with orange'));

      // Insert link
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 6);
      controller.setLinkForSelection('https://flutter.dev');
      expect(controller.text, equals('Line 1\nLine 2 with orange'));
    });

    test('Exact Markdown serialization of color and highlight round-trips cleanly', () {
      final controller = RichTextEditingController(markdown: 'Color and highlight test');
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
      controller.setStyleAttribute('color', enable: true, value: const Color(0xFFFF3B30));

      controller.selection = const TextSelection(baseOffset: 10, extentOffset: 19);
      controller.setStyleAttribute('highlight', enable: true, value: const Color(0xFFA5D6A7));

      final serialized = generateMarkdownFromStyledChars(controller.styledChars);
      expect(serialized, equals('<span color="0xffff3b30">Color</span> and <span highlight="0xffa5d6a7">highlight</span> test'));

      final roundTrip = RichTextEditingController(markdown: serialized);
      expect(roundTrip.text, equals('Color and highlight test'));
      expect(roundTrip.styledChars[0].style.color, equals(const Color(0xFFFF3B30)));
      expect(roundTrip.styledChars[10].style.highlight, equals(const Color(0xFFA5D6A7)));

      // Combined color + highlight on "test"
      controller.selection = const TextSelection(baseOffset: 20, extentOffset: 24);
      controller.setStyleAttribute('color', enable: true, value: const Color(0xFF007AFF));
      controller.setStyleAttribute('highlight', enable: true, value: const Color(0xFFFFE082));

      final combinedSerialized = generateMarkdownFromStyledChars(controller.styledChars);
      expect(combinedSerialized, equals('<span color="0xffff3b30">Color</span> and <span highlight="0xffa5d6a7">highlight</span> <span color="0xff007aff" highlight="0xffffe082">test</span>'));

      final combinedRoundTrip = RichTextEditingController(markdown: combinedSerialized);
      expect(combinedRoundTrip.text, equals('Color and highlight test'));
      expect(combinedRoundTrip.styledChars[20].style.color, equals(const Color(0xFF007AFF)));
      expect(combinedRoundTrip.styledChars[20].style.highlight, equals(const Color(0xFFFFE082)));
    });
  });

  group('RTF-009: Highlight Palette and Text Color Selector', () {
    late _MockNotesRepository notesRepo;
    late _MockFoldersRepository foldersRepo;
    late NotesProvider notesProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues(
          {'active_user_id': 'test-user-rtf-phase5'});
      await SessionManager().init();
      await SessionManager().saveSession(
        userId: 'test-user-rtf-phase5',
        sessionType: SessionType.guest,
      );

      notesRepo = _MockNotesRepository();
      foldersRepo = _MockFoldersRepository();
      notesProvider = NotesProvider(
        notesRepository: notesRepo,
        foldersRepository: foldersRepo,
      );
    });

    Widget createTestEditorApp({Note? note}) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<NotesProvider>.value(value: notesProvider),
        ],
        child: MaterialApp(
          home: NoteEditorScreen(note: note),
        ),
      );
    }

    Note createTestNote({
      required String id,
      required String title,
      required String content,
    }) {
      return Note(
        id: id,
        title: title,
        content: content,
        tags: const [],
        attachments: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        colorValue: 0,
      );
    }

    testWidgets('Tapping highlighter icon opens 5-color palette drawer and applies selected color',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final note = createTestNote(
        id: 'phase5-highlight-palette',
        title: 'Highlight Palette',
        content: 'Highlight this specific word in green',
      );
      await notesRepo.insertNote(note);

      await tester.pumpWidget(createTestEditorApp(note: note));
      await tester.pumpAndSettle();

      final sdeFinder = find.byType(NewSingleDocumentEditor);
      final sdeWidget = tester.widget<NewSingleDocumentEditor>(sdeFinder);
      final controller = sdeWidget.controller;

      // Select "specific" (indices 15..23)
      controller.selection = const TextSelection(baseOffset: 15, extentOffset: 23);
      await tester.pumpAndSettle();

      // Tap Highlighter button on Category Page 1
      final highlighterFinder = find.byTooltip('Highlight');
      await tester.tap(highlighterFinder);
      await tester.pumpAndSettle();

      // Verify all 5 color swatches are rendered in the drawer
      expect(find.byTooltip('Highlight Yellow'), findsOneWidget);
      expect(find.byTooltip('Highlight Green'), findsOneWidget);
      expect(find.byTooltip('Highlight Blue'), findsOneWidget);
      expect(find.byTooltip('Highlight Pink'), findsOneWidget);
      expect(find.byTooltip('Highlight Orange'), findsOneWidget);
      expect(find.byTooltip('Clear Highlight'), findsOneWidget);

      // Tap Green swatch
      await tester.tap(find.byTooltip('Highlight Green'));
      await tester.pumpAndSettle();

      // Verify selected range has green highlight applied
      expect(controller.styledChars[15].style.highlight, equals(const Color(0xFFA5D6A7)));

      // Tap Clear Highlight button
      await tester.tap(find.byTooltip('Clear Highlight'));
      await tester.pumpAndSettle();

      // Verify highlight is cleared
      expect(controller.styledChars[15].style.highlight, isNull);
    });

    testWidgets('Typography drawer includes Text Color button and enables color selection',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final note = createTestNote(
        id: 'phase5-text-color',
        title: 'Text Color Test',
        content: 'Color this word in red text',
      );
      await notesRepo.insertNote(note);

      await tester.pumpWidget(createTestEditorApp(note: note));
      await tester.pumpAndSettle();

      final sdeFinder = find.byType(NewSingleDocumentEditor);
      final sdeWidget = tester.widget<NewSingleDocumentEditor>(sdeFinder);
      final controller = sdeWidget.controller;

      // Open Aa subsection
      await tester.tap(find.byTooltip('Text Formatting'));
      await tester.pumpAndSettle();

      // Verify Text Color button is present alongside B, I, U, T
      expect(find.byTooltip('Bold'), findsOneWidget);
      expect(find.byTooltip('Italic'), findsOneWidget);
      expect(find.byTooltip('Underline'), findsOneWidget);
      expect(find.byTooltip('Strikethrough'), findsOneWidget);
      final textColorButtonFinder = find.byTooltip('Text Color');
      expect(textColorButtonFinder, findsOneWidget);

      // Select "Color" (0..5)
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
      await tester.pumpAndSettle();

      // Tap Text Color button to open palette view
      await tester.tap(textColorButtonFinder);
      await tester.pumpAndSettle();

      // Verify Back button and color options appear
      expect(find.byTooltip('Back to formatting'), findsOneWidget);
      expect(find.byTooltip('Default Text Color'), findsOneWidget);
      expect(find.byTooltip('Text Color: Red'), findsOneWidget);
      expect(find.byTooltip('Text Color: Blue'), findsOneWidget);
      expect(find.byTooltip('Text Color: Green'), findsOneWidget);
      expect(find.byTooltip('Text Color: Amber'), findsOneWidget);
      expect(find.byTooltip('Text Color: Purple'), findsOneWidget);

      // Select Red
      await tester.tap(find.byTooltip('Text Color: Red'));
      await tester.pumpAndSettle();

      // Verify red color is applied to selected characters
      expect(controller.styledChars[0].style.color, equals(const Color(0xFFFF3B30)));

      // Tap Default Text Color to clear color
      await tester.tap(find.byTooltip('Default Text Color'));
      await tester.pumpAndSettle();

      // Verify color is cleared
      expect(controller.styledChars[0].style.color, isNull);

      // Tap Back to return to B/I/U/T view
      await tester.tap(find.byTooltip('Back to formatting'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Bold'), findsOneWidget);
      expect(find.byTooltip('Text Color'), findsOneWidget);
    });
  });
}
