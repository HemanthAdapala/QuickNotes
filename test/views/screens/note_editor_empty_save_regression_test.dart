// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quick_notes/models/folder.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/repositories/folders_repository.dart';
import 'package:quick_notes/repositories/notes_repository.dart';
import 'package:quick_notes/models/session_type.dart';
import 'package:quick_notes/services/session_manager.dart';
import 'package:quick_notes/views/screens/note_editor_screen.dart';
import 'package:quick_notes/views/widgets/new_single_document_editor.dart';
import 'package:quick_notes/views/widgets/quick_notes_liquid_glass_back_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestAudioplayersPlatform extends AudioplayersPlatformInterface {
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
  Future<void> setAudioContext(String playerId, AudioContext audioContext) async {}
  @override
  Future<void> setBalance(String playerId, double balance) async {}
  @override
  Future<void> setPlaybackRate(String playerId, double playbackRate) async {}
  @override
  Future<void> setPlayerMode(String playerId, PlayerMode playerMode) async {}
  @override
  Future<void> setReleaseMode(String playerId, ReleaseMode releaseMode) async {}
  @override
  Future<void> setSourceBytes(String playerId, Uint8List bytes, {String? mimeType}) async {}
  @override
  Future<void> setSourceUrl(String playerId, String url, {bool? isLocal, String? mimeType}) async {
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
    return _eventControllers.putIfAbsent(playerId, () => StreamController<AudioEvent>.broadcast()).stream;
  }
}

class TestGlobalAudioplayersPlatform extends GlobalAudioplayersPlatformInterface {
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
  Stream<GlobalAudioEvent> getGlobalEventStream() => _globalEventController.stream;
}

/// In-memory repository tracking updates and insertions for regression verification.
class FakeNotesRepository implements NotesRepository {
  final Map<String, Note> storage = {};
  int updateCount = 0;
  int insertCount = 0;
  Note? lastUpdatedNote;

  void addNoteForTesting(Note note) {
    storage[note.id] = note;
  }

  @override
  Future<List<Note>> getNotes() async =>
      storage.values.where((n) => !n.isDeleted).toList();

  @override
  Future<List<Note>> getTrashNotes() async =>
      storage.values.where((n) => n.isDeleted).toList();

  @override
  Future<Note?> getNoteById(String id) async => storage[id];

  @override
  Future<List<Note>> queryHabits() async =>
      storage.values.where((n) => n.isHabit && !n.isDeleted).toList();

  @override
  Future<int> updateNote(Note note) async {
    updateCount++;
    lastUpdatedNote = note;
    storage[note.id] = note;
    return 1;
  }

  @override
  Future<int> insertNote(Note note) async {
    insertCount++;
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
  Future<int> deleteNote(String id) async => 1;
  @override
  Future<int> emptyTrash() async => 1;
}

class FakeFoldersRepository implements FoldersRepository {
  @override
  Future<List<Folder>> getFolders() async => [];
  @override
  Future<int> insertFolder(Folder folder) async => 1;
  @override
  Future<int> updateFolder(Folder folder) async => 1;
  @override
  Future<int> deleteFolder(String id) async => 1;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    const MethodChannel homeWidgetChannel = MethodChannel('class.yiss.home_widget');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(homeWidgetChannel, (MethodCall methodCall) async => true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'), (MethodCall methodCall) async => true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('es.antonborri.home_widget'), (MethodCall methodCall) async => true);

    const MethodChannel notificationsChannel =
        MethodChannel('dexterous.com/flutter_local_notifications');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, (MethodCall methodCall) async => true);

    const MethodChannel pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (MethodCall methodCall) async => '.');

    AudioplayersPlatformInterface.instance = TestAudioplayersPlatform();
    GlobalAudioplayersPlatformInterface.instance = TestGlobalAudioplayersPlatform();
  });

  group('BUG-001 / NOTE-040 — Existing Note Cleared Completely Regression Tests', () {
    late FakeNotesRepository fakeNotesRepository;
    late FakeFoldersRepository fakeFoldersRepository;
    late NotesProvider notesProvider;

    void registerChannelMocks() {
      const MethodChannel homeWidgetChannel = MethodChannel('class.yiss.home_widget');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(homeWidgetChannel, (MethodCall methodCall) async => true);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('home_widget'), (MethodCall methodCall) async => true);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('es.antonborri.home_widget'), (MethodCall methodCall) async => true);

      const MethodChannel notificationsChannel =
          MethodChannel('dexterous.com/flutter_local_notifications');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(notificationsChannel, (MethodCall methodCall) async => true);

      const MethodChannel pathChannel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, (MethodCall methodCall) async => '.');
    }

    setUp(() async {
      registerChannelMocks();
      AudioplayersPlatformInterface.instance = TestAudioplayersPlatform();
      GlobalAudioplayersPlatformInterface.instance = TestGlobalAudioplayersPlatform();
      SharedPreferences.setMockInitialValues({'active_user_id': 'test-user'});
      await SessionManager().init();
      await SessionManager().saveSession(
        userId: 'test-user',
        sessionType: SessionType.guest,
      );

      fakeNotesRepository = FakeNotesRepository();
      fakeFoldersRepository = FakeFoldersRepository();
      notesProvider = NotesProvider(
        notesRepository: fakeNotesRepository,
        foldersRepository: fakeFoldersRepository,
      );
    });

    Widget createTestApp({required Widget home}) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<NotesProvider>.value(value: notesProvider),
        ],
        child: MaterialApp(
          key: UniqueKey(),
          home: home,
        ),
      );
    }

    void registerCleanTeardown(WidgetTester tester) {
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      });
    }

    Future<void> exitEditorViaBackButton(WidgetTester tester) async {
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      final backButtonFinder = find.byType(QuickNotesLiquidGlassBackButton);
      expect(backButtonFinder, findsOneWidget);

      await tester.tap(backButtonFinder);
      await tester.pumpAndSettle();
    }

    testWidgets(
      'CONTROL TEST B: Existing note with non-empty title but cleared content correctly persists',
      (tester) async {
        registerCleanTeardown(tester);
        const noteId = 'control-note-content-empty';
        final existingNote = Note(
          id: noteId,
          userId: 'test-user',
          title: 'Meeting',
          content: 'Discussion points',
          tags: const [],
          attachments: const [],
          category: 'Work',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          updatedAt: DateTime.now().subtract(const Duration(days: 1)),
          colorValue: 0,
        );
        fakeNotesRepository.addNoteForTesting(existingNote);

        await tester.pumpWidget(
          createTestApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => NoteEditorScreen(key: UniqueKey(), note: existingNote),
                      ),
                    );
                  },
                  child: const Text('Open Note'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Note'));
        await tester.pumpAndSettle();
        expect(find.byType(NoteEditorScreen), findsOneWidget);

        // Clear ONLY content
        final sdeFinder = find.byType(NewSingleDocumentEditor);
        expect(sdeFinder, findsOneWidget);
        final sde = tester.widget<NewSingleDocumentEditor>(sdeFinder);
        sde.controller.text = '';
        sde.controller.setMarkdown('');
        await tester.pump();

        final titleFinder = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'Title',
        );
        final titleField = tester.widget<TextField>(titleFinder);
        titleField.controller!.text = 'Meeting Edited';
        titleField.onChanged?.call('Meeting Edited');
        await tester.pump();

        // Pop via back button
        await exitEditorViaBackButton(tester);

        final persistedNote = await fakeNotesRepository.getNoteById(noteId);
        expect(persistedNote, isNotNull);
        expect(fakeNotesRepository.updateCount, greaterThanOrEqualTo(1));
        expect(persistedNote!.title, equals('Meeting Edited'));
        expect(persistedNote.content, equals(''));
      },
    );

    testWidgets(
      'CONTROL TEST A: Existing note with cleared title but non-empty content correctly persists',
      (tester) async {
        registerCleanTeardown(tester);
        const noteId = 'control-note-title-empty';
        final existingNote = Note(
          id: noteId,
          userId: 'test-user',
          title: 'Meeting',
          content: 'Discussion points',
          tags: const [],
          attachments: const [],
          category: 'Work',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          updatedAt: DateTime.now().subtract(const Duration(days: 1)),
          colorValue: 0,
        );
        fakeNotesRepository.addNoteForTesting(existingNote);

        await tester.pumpWidget(
          createTestApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => NoteEditorScreen(key: UniqueKey(), note: existingNote),
                      ),
                    );
                  },
                  child: const Text('Open Note'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Note'));
        await tester.pumpAndSettle();
        expect(find.byType(NoteEditorScreen), findsOneWidget);

        // Clear ONLY title
        final titleFinder = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'Title',
        );
        expect(titleFinder, findsOneWidget);
        final titleField = tester.widget<TextField>(titleFinder);
        titleField.controller!.text = '';
        titleField.onChanged?.call('');
        await tester.pump();

        final sdeFinder = find.byType(NewSingleDocumentEditor);
        final sde = tester.widget<NewSingleDocumentEditor>(sdeFinder);
        expect(sde.controller.text, equals('Discussion points'));

        // Pop via back button
        await exitEditorViaBackButton(tester);

        // Assert: Content was non-empty, so updateNote is called and title is saved as empty
        final persistedNote = await fakeNotesRepository.getNoteById(noteId);
        expect(persistedNote, isNotNull);
        expect(fakeNotesRepository.updateCount, greaterThanOrEqualTo(1));
        expect(persistedNote!.title, equals(''));
        expect(persistedNote.content, equals('Discussion points'));
      },
    );

    testWidgets(
      'NEW NOTE SAFETY: Blank new note MUST NOT create an empty/ghost row in persistence',
      (tester) async {
        registerCleanTeardown(tester);
        // Open a new note (note: null) and immediately exit without typing
        await tester.pumpWidget(
          createTestApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => NoteEditorScreen(key: UniqueKey()),
                      ),
                    );
                  },
                  child: const Text('New Note'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('New Note'));
        await tester.pumpAndSettle();
        expect(find.byType(NoteEditorScreen), findsOneWidget);

        // Pop without entering text via back button
        await exitEditorViaBackButton(tester);

        // Assert: No note was inserted
        expect(fakeNotesRepository.insertCount, equals(0));
        expect(fakeNotesRepository.storage, isEmpty);
      },
    );

    testWidgets(
      'TDD REGRESSION (BUG-001): Existing note cleared of both title and content MUST persist empty state on exit',
      (tester) async {
        registerCleanTeardown(tester);
        // 1. Arrange: An existing persisted note with non-empty title and content
        const noteId = 'existing-persisted-note-001';
        final existingNote = Note(
          id: noteId,
          userId: 'test-user',
          title: 'Meeting',
          content: 'Discussion points',
          tags: const ['work'],
          attachments: const [],
          category: 'Work',
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
          updatedAt: DateTime.now().subtract(const Duration(days: 3)),
          colorValue: 1,
        );
        fakeNotesRepository.addNoteForTesting(existingNote);

        // 2. Act: Open the existing note in NoteEditorScreen via a push route
        await tester.pumpWidget(
          createTestApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => NoteEditorScreen(key: UniqueKey(), note: existingNote),
                      ),
                    );
                  },
                  child: const Text('Open Note'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Note'));
        await tester.pumpAndSettle();
        expect(find.byType(NoteEditorScreen), findsOneWidget);

        // Clear title
        final titleFinder = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'Title',
        );
        expect(titleFinder, findsOneWidget);
        final titleField = tester.widget<TextField>(titleFinder);
        titleField.controller!.text = '';
        titleField.onChanged?.call('');
        await tester.pump();

        // Clear content in SingleDocumentEditor
        final sdeFinder = find.byType(NewSingleDocumentEditor);
        expect(sdeFinder, findsOneWidget);
        final sde = tester.widget<NewSingleDocumentEditor>(sdeFinder);
        sde.controller.text = '';
        sde.controller.setMarkdown('');
        await tester.pump();

        // Leave editor via normal back button path
        await exitEditorViaBackButton(tester);

        // 3. Assert: The note must be updated in persistence with empty strings
        expect(
          fakeNotesRepository.updateCount,
          greaterThanOrEqualTo(1),
          reason: 'BUG-001: updateNote must be called when an existing note is cleared.',
        );

        final persistedNote = await fakeNotesRepository.getNoteById(noteId);
        expect(persistedNote, isNotNull, reason: 'The note must still exist in storage.');
        expect(
          persistedNote!.id,
          equals(noteId),
          reason: 'The note identity must remain unchanged.',
        );
        expect(
          persistedNote.isDeleted,
          isFalse,
          reason: 'Emptying text must NEVER automatically trash or delete an existing note.',
        );

        // Primary BUG-001 assertion: title and content must be empty, not reverting to old text
        expect(
          persistedNote.title,
          equals(''),
          reason: 'BUG-001: Title was cleared and must persist as empty string, not "Meeting".',
        );
        expect(
          persistedNote.content,
          equals(''),
          reason: 'BUG-001: Content was cleared and must persist as empty string, not "Discussion points".',
        );
      },
    );

    testWidgets(
      'TDD REGRESSION (BUG-001): Existing note with whitespace-only title and newline-only content MUST persist empty state',
      (tester) async {
        registerCleanTeardown(tester);
        // 1. Arrange: Existing note
        const noteId = 'existing-whitespace-note-002';
        final existingNote = Note(
          id: noteId,
          userId: 'test-user',
          title: 'Old Title',
          content: 'Old Content',
          tags: const [],
          attachments: const [],
          category: 'Personal',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          updatedAt: DateTime.now().subtract(const Duration(days: 1)),
          colorValue: 0,
        );
        fakeNotesRepository.addNoteForTesting(existingNote);

        // 2. Act: Open, enter whitespace/newlines, and tap back button
        await tester.pumpWidget(
          createTestApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => NoteEditorScreen(key: UniqueKey(), note: existingNote),
                      ),
                    );
                  },
                  child: const Text('Open Note'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Note'));
        await tester.pumpAndSettle();

        // Enter whitespace in title
        final titleFinder = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'Title',
        );
        final titleField = tester.widget<TextField>(titleFinder);
        titleField.controller!.text = '   ';
        titleField.onChanged?.call('   ');
        await tester.pump();

        // Enter newlines in content
        final sdeFinder = find.byType(NewSingleDocumentEditor);
        final sde = tester.widget<NewSingleDocumentEditor>(sdeFinder);
        sde.controller.text = '\n\n\n';
        sde.controller.setMarkdown('\n\n\n');
        await tester.pump();

        // Exit via back button
        await exitEditorViaBackButton(tester);

        // 3. Assert
        expect(
          fakeNotesRepository.updateCount,
          greaterThanOrEqualTo(1),
          reason: 'BUG-001: updateNote must be called when note is effectively cleared.',
        );
        final persistedNote = await fakeNotesRepository.getNoteById(noteId);
        expect(persistedNote, isNotNull);
        expect(persistedNote!.title, equals(''), reason: 'Trimmed title should be empty.');
        expect(persistedNote.content, equals(''), reason: 'Trimmed content should be empty.');
      },
    );

    testWidgets(
      'METADATA PRESERVATION: Clearing text on existing note preserves folderId, tags, colorValue, and habit configuration',
      (tester) async {
        registerCleanTeardown(tester);
        const noteId = 'existing-metadata-note-003';
        final existingNote = Note(
          id: noteId,
          userId: 'test-user',
          title: 'Project Plan',
          content: 'Roadmap timeline',
          tags: const ['q4', 'roadmap'],
          attachments: const [
            {'path': 'attachment://doc.pdf', 'name': 'doc.pdf'}
          ],
          category: 'Work',
          folderId: 'folder-strategy-101',
          isFavorite: true,
          isPinned: true,
          isHabit: true,
          habitRecurrence: 'weekly',
          habitStreak: 7,
          colorValue: 3,
          createdAt: DateTime.now().subtract(const Duration(days: 14)),
          updatedAt: DateTime.now().subtract(const Duration(days: 14)),
        );
        fakeNotesRepository.addNoteForTesting(existingNote);

        await tester.pumpWidget(
          createTestApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => NoteEditorScreen(key: UniqueKey(), note: existingNote),
                      ),
                    );
                  },
                  child: const Text('Open Note'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Note'));
        await tester.pumpAndSettle();

        // Clear title
        final titleFinder = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'Title',
        );
        final titleField = tester.widget<TextField>(titleFinder);
        titleField.controller!.text = '';
        titleField.onChanged?.call('');
        await tester.pump();

        // Clear content
        final sdeFinder = find.byType(NewSingleDocumentEditor);
        final sde = tester.widget<NewSingleDocumentEditor>(sdeFinder);
        sde.controller.text = '';
        sde.controller.setMarkdown('');
        await tester.pump();

        // Exit via back button
        await exitEditorViaBackButton(tester);

        // Assert: Once BUG-001 is fixed, metadata must survive intact
        final persistedNote = await fakeNotesRepository.getNoteById(noteId);
        expect(persistedNote, isNotNull);
        expect(fakeNotesRepository.updateCount, greaterThanOrEqualTo(1));
        expect(persistedNote!.folderId, equals('folder-strategy-101'));
        expect(persistedNote.tags, equals(['q4', 'roadmap']));
        expect(persistedNote.attachments.length, equals(1));
        expect(persistedNote.isFavorite, isTrue);
        expect(persistedNote.isPinned, isTrue);
        expect(persistedNote.isHabit, isTrue);
        expect(persistedNote.habitRecurrence, equals('weekly'));
        expect(persistedNote.habitStreak, equals(7));
        expect(persistedNote.colorValue, equals(3));
        expect(persistedNote.title, equals(''));
        expect(persistedNote.content, equals(''));
      },
    );
  });
}
