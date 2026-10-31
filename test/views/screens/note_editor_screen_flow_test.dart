// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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

class TestGlobalAudioplayersPlatform
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

class FlowNotesRepository implements NotesRepository {
  final Map<String, Note> storage = {};
  int updateCount = 0;
  int insertCount = 0;
  bool throwOnInsert = false;
  bool throwOnUpdate = false;

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
    if (throwOnUpdate) {
      throw Exception('Simulated repository update failure');
    }
    updateCount++;
    storage[note.id] = note;
    return 1;
  }

  @override
  Future<int> insertNote(Note note) async {
    if (throwOnInsert) {
      throw Exception('Simulated repository insert failure');
    }
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

class FlowFoldersRepository implements FoldersRepository {
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

    AudioplayersPlatformInterface.instance = TestAudioplayersPlatform();
    GlobalAudioplayersPlatformInterface.instance =
        TestGlobalAudioplayersPlatform();
  });

  group('NoteEditorScreen Flow & Widget Integration Tests', () {
    late FlowNotesRepository notesRepo;
    late FlowFoldersRepository foldersRepo;
    late NotesProvider notesProvider;

    setUp(() async {
      AudioplayersPlatformInterface.instance = TestAudioplayersPlatform();
      GlobalAudioplayersPlatformInterface.instance =
          TestGlobalAudioplayersPlatform();
      SharedPreferences.setMockInitialValues(
          {'active_user_id': 'test-user-editor'});
      await SessionManager().init();
      await SessionManager().saveSession(
        userId: 'test-user-editor',
        sessionType: SessionType.guest,
      );

      notesRepo = FlowNotesRepository();
      foldersRepo = FlowFoldersRepository();
      notesProvider = NotesProvider(
        notesRepository: notesRepo,
        foldersRepository: foldersRepo,
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

    testWidgets('1. Discards empty note without saving or creating DB record',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NoteEditorScreen()),
                  );
                },
                child: const Text('Open Editor'),
              ),
            ),
          ),
        ),
      );

      // Open new editor
      await tester.tap(find.text('Open Editor'));
      await tester.pumpAndSettle();

      expect(find.byType(NoteEditorScreen), findsOneWidget);
      expect(notesRepo.storage, isEmpty);

      // Tap back button without entering text
      final backBtn = find.byType(QuickNotesLiquidGlassBackButton);
      expect(backBtn, findsOneWidget);
      await tester.tap(backBtn);
      await tester.pumpAndSettle();

      // Returned to home, zero notes created
      expect(find.byType(NoteEditorScreen), findsNothing);
      expect(notesRepo.storage, isEmpty);
      expect(notesRepo.insertCount, equals(0));
    });

    testWidgets(
        '2. Creating new note auto-saves title and content on back button pop',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NoteEditorScreen()),
                  );
                },
                child: const Text('Open Editor'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Editor'));
      await tester.pumpAndSettle();

      // Enter note title
      final titleFinder = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Title',
      );
      expect(titleFinder, findsOneWidget);
      final titleWidget = tester.widget<TextField>(titleFinder);
      titleWidget.controller!.text = 'Sprint Planning';
      titleWidget.onChanged?.call('Sprint Planning');
      await tester.pump();

      // Enter note body content in SDE via controller
      final sdeFinder = find.byType(NewSingleDocumentEditor);
      expect(sdeFinder, findsOneWidget);
      final sdeWidget = tester.widget<NewSingleDocumentEditor>(sdeFinder);
      sdeWidget.controller.setMarkdown('Finalize release checklist');
      await tester.pump();

      // Exit editor via back button
      final backBtn = find.byType(QuickNotesLiquidGlassBackButton);
      await tester.tap(backBtn);
      await tester.pumpAndSettle();

      // Verify note was inserted into repository
      expect(notesRepo.insertCount, equals(1));
      expect(notesRepo.storage.length, equals(1));
      final savedNote = notesRepo.storage.values.first;
      expect(savedNote.title, equals('Sprint Planning'));
      expect(savedNote.content, contains('Finalize release checklist'));
    });

    testWidgets(
        '3. Opening existing note loads data and updates upon modification',
        (tester) async {
      final existingNote = Note(
        id: 'existing_note_42',
        title: 'Original Title 42',
        content: 'Original Content 42',
        tags: const ['existing'],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      notesRepo.addNoteForTesting(existingNote);

      await tester.pumpWidget(
        createTestApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => NoteEditorScreen(note: existingNote)),
                  );
                },
                child: const Text('Edit Note'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Edit Note'));
      await tester.pumpAndSettle();

      // Modify the title
      final titleFinder = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Title',
      );
      expect(titleFinder, findsOneWidget);
      final titleWidget = tester.widget<TextField>(titleFinder);
      expect(titleWidget.controller!.text, equals('Original Title 42'));

      titleWidget.controller!.text = 'Revised Title 42';
      titleWidget.onChanged?.call('Revised Title 42');
      await tester.pump();

      // Exit editor via back button
      final backBtn = find.byType(QuickNotesLiquidGlassBackButton);
      await tester.tap(backBtn);
      await tester.pumpAndSettle();

      // Verify updateNote was called and stored
      expect(notesRepo.updateCount, equals(1));
      expect(notesRepo.storage['existing_note_42']!.title,
          equals('Revised Title 42'));
    });

    testWidgets(
        '4. Editing existing note preserves metadata: folderId, tags, and colorValue',
        (tester) async {
      final noteWithMetadata = Note(
        id: 'meta_note_99',
        title: 'Project Architecture',
        content: 'System invariants and contracts',
        folderId: 'folder_arch',
        tags: const ['system', 'governance'],
        colorValue: 3,
        attachments: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      notesRepo.addNoteForTesting(noteWithMetadata);

      await tester.pumpWidget(
        createTestApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) =>
                            NoteEditorScreen(note: noteWithMetadata)),
                  );
                },
                child: const Text('Open Meta Note'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Meta Note'));
      await tester.pumpAndSettle();

      // Modify the note body content
      final sdeFinder = find.byType(NewSingleDocumentEditor);
      final sdeWidget = tester.widget<NewSingleDocumentEditor>(sdeFinder);
      sdeWidget.controller.setMarkdown('Updated system invariants content');
      await tester.pump();

      // Tap back button
      final backBtn = find.byType(QuickNotesLiquidGlassBackButton);
      await tester.tap(backBtn);
      await tester.pumpAndSettle();

      final saved = notesRepo.storage['meta_note_99']!;
      expect(saved.content, contains('Updated system invariants content'));
      expect(saved.folderId, equals('folder_arch'));
      expect(saved.tags, equals(['system', 'governance']));
      expect(saved.colorValue, equals(3));
    });

    testWidgets(
        '5. Whitespace-only new note (spaces, tabs, newlines) is discarded without DB insertion',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NoteEditorScreen()),
                  );
                },
                child: const Text('Open Editor'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Editor'));
      await tester.pumpAndSettle();

      // Enter whitespace-only title
      final titleFinder = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Title',
      );
      final titleWidget = tester.widget<TextField>(titleFinder);
      titleWidget.controller!.text = '   \t  ';
      titleWidget.onChanged?.call('   \t  ');
      await tester.pump();

      // Enter whitespace-only content in SDE
      final sdeFinder = find.byType(NewSingleDocumentEditor);
      final sdeWidget = tester.widget<NewSingleDocumentEditor>(sdeFinder);
      sdeWidget.controller.setMarkdown('   \n\t\n   ');
      await tester.pump();

      // Tap back button
      final backBtn = find.byType(QuickNotesLiquidGlassBackButton);
      await tester.tap(backBtn);
      await tester.pumpAndSettle();

      // Editor pops, but no note was persisted
      expect(find.byType(NoteEditorScreen), findsNothing);
      expect(notesRepo.storage, isEmpty);
      expect(notesRepo.insertCount, equals(0));
    });

    testWidgets(
        '6. Save idempotency: exiting editor creates exactly one note without duplicates',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NoteEditorScreen()),
                  );
                },
                child: const Text('Open Editor'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Editor'));
      await tester.pumpAndSettle();

      final titleFinder = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Title',
      );
      final titleWidget = tester.widget<TextField>(titleFinder);
      titleWidget.controller!.text = 'Idempotency Note';
      titleWidget.onChanged?.call('Idempotency Note');
      await tester.pump();

      final backBtn = find.byType(QuickNotesLiquidGlassBackButton);
      await tester.tap(backBtn);
      await tester.pumpAndSettle();

      // Must be inserted exactly once
      expect(notesRepo.insertCount, equals(1));
      expect(notesRepo.storage.length, equals(1));
      expect(notesRepo.storage.values.first.title, equals('Idempotency Note'));
    });

    testWidgets(
        '7. Failure-path: repository write error during save is handled gracefully without crashing UI',
        (tester) async {
      notesRepo.throwOnInsert = true;

      await tester.pumpWidget(
        createTestApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NoteEditorScreen()),
                  );
                },
                child: const Text('Open Editor'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Editor'));
      await tester.pumpAndSettle();

      final titleFinder = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Title',
      );
      final titleWidget = tester.widget<TextField>(titleFinder);
      titleWidget.controller!.text = 'Doomed Note';
      titleWidget.onChanged?.call('Doomed Note');
      await tester.pump();

      final backBtn = find.byType(QuickNotesLiquidGlassBackButton);
      await tester.tap(backBtn);
      await tester.pumpAndSettle();

      // UI safely popped and did not crash or corrupt storage
      expect(find.byType(NoteEditorScreen), findsNothing);
      expect(notesRepo.storage, isEmpty);
    });
  });
}
