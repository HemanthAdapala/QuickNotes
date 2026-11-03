import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/models/session_type.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/repositories/folders_repository.dart';
import 'package:quick_notes/repositories/notes_repository.dart';
import 'package:quick_notes/services/database_service.dart';
import 'package:quick_notes/services/session_manager.dart';
import 'package:quick_notes/views/screens/note_editor_screen.dart';
import 'package:quick_notes/views/widgets/new_single_document_editor.dart';
import 'package:quick_notes/views/widgets/quick_notes_liquid_glass_back_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:uuid/uuid.dart';

class _TestAudioplayersPlatform extends AudioplayersPlatformInterface {
  final Map<String, StreamController<AudioEvent>> _eventControllers = {};

  @override
  Future<void> create(String playerId) async {}
  @override
  Future<void> dispose(String playerId) async {
    _eventControllers[playerId]?.close();
    _eventControllers.remove(playerId);
  }
  @override
  Future<void> emitLog(String playerId, String message) async {}
  @override
  Future<void> emitError(String playerId, String code, String message) async {}
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
    return _eventControllers
        .putIfAbsent(playerId, () => StreamController<AudioEvent>.broadcast())
        .stream;
  }
}

class _TestGlobalAudioplayersPlatform extends GlobalAudioplayersPlatformInterface {
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const uuid = Uuid();
  late Directory tempDir;

  setUpAll(() async {
    // 1. Initialize SQLite FFI engine
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // 2. Initialize timezone & local notifications registration
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    tz.initializeTimeZones();

    // 3. Setup isolated temporary directory for SQLite DB
    tempDir = Directory.systemTemp.createTempSync('qn_sqlite_e2e_');

    // 4. Register mock handlers for platform channels
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => tempDir.path,
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async => null,
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('home_widget'),
      (MethodCall methodCall) async => true,
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('class.yiss.home_widget'),
      (MethodCall methodCall) async => true,
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('es.antonborri.home_widget'),
      (MethodCall methodCall) async => true,
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (MethodCall methodCall) async => true,
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (MethodCall methodCall) async => 1,
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'),
      (MethodCall methodCall) async => null,
    );

    // 5. Mock Audio player platform interfaces
    AudioplayersPlatformInterface.instance = _TestAudioplayersPlatform();
    GlobalAudioplayersPlatformInterface.instance = _TestGlobalAudioplayersPlatform();
  });

  tearDownAll(() async {
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('UI-to-SQLite Full Integration Suite (GAP-002)', () {
    late String testUserId;
    late SqliteNotesRepository sqliteNotesRepo;
    late SqliteFoldersRepository sqliteFoldersRepo;
    late NotesProvider notesProvider;

    setUp(() async {
      AudioplayersPlatformInterface.instance = _TestAudioplayersPlatform();
      GlobalAudioplayersPlatformInterface.instance = _TestGlobalAudioplayersPlatform();

      // Isolate each test with a unique user ID and dedicated session
      testUserId = 'usr_e2e_${uuid.v4()}';
      SharedPreferences.setMockInitialValues({'active_user_id': testUserId});

      final session = SessionManager();
      await session.init();
      await session.saveSession(
        userId: testUserId,
        sessionType: SessionType.offline,
      );

      // Construct live SQLite-backed repositories and provider
      sqliteNotesRepo = SqliteNotesRepository();
      sqliteFoldersRepo = SqliteFoldersRepository();
      notesProvider = NotesProvider(
        notesRepository: sqliteNotesRepo,
        foldersRepository: sqliteFoldersRepo,
      );
    });

    tearDown(() async {
      try {
        final db = await DatabaseService.instance.database;
        await db.delete('notes', where: 'userId = ?', whereArgs: [testUserId]);
        await db.delete('sync_outbox', where: 'userId = ?', whereArgs: [testUserId]);
      } catch (_) {}
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

    Future<void> triggerSaveAndPop(WidgetTester tester) async {
      final backBtn = find.byType(QuickNotesLiquidGlassBackButton);
      expect(backBtn, findsOneWidget);
      await tester.tap(backBtn);
      await tester.pump();

      // Allow background isolate / SQLite write operations to complete
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets(
        'Scenario 1: Create a note through NoteEditorScreen UI, save through NotesProvider and SqliteNotesRepository, and verify persisted SQLite row',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NoteEditorScreen(),
                    ),
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

      // 1. Enter note title via Title text field
      final titleFinder = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Title',
      );
      expect(titleFinder, findsOneWidget);
      final titleWidget = tester.widget<TextField>(titleFinder);
      titleWidget.controller!.text = 'Live SQLite Integration Note';
      titleWidget.onChanged?.call('Live SQLite Integration Note');
      await tester.pump();

      // 2. Enter note body content in SDE via controller
      final sdeFinder = find.byType(NewSingleDocumentEditor);
      expect(sdeFinder, findsOneWidget);
      final sdeWidget = tester.widget<NewSingleDocumentEditor>(sdeFinder);
      sdeWidget.controller.setMarkdown('Verified UI text saved directly to SQLite table.');
      await tester.pump();

      // 3. Trigger auto-save via back button pop
      await triggerSaveAndPop(tester);

      // 4. Verify persistence via Repository API
      final activeNotes = await tester.runAsync(() async {
        return await sqliteNotesRepo.getNotes();
      });
      expect(activeNotes, hasLength(1));
      final persistedNote = activeNotes!.first;
      expect(persistedNote.title, equals('Live SQLite Integration Note'));
      expect(persistedNote.content, contains('Verified UI text saved directly to SQLite table.'));
      expect(persistedNote.userId, equals(testUserId));
      expect(persistedNote.version, equals(1));

      // 5. Direct SQL query assertion against SQLite table 'notes'
      final rows = await tester.runAsync(() async {
        final db = await DatabaseService.instance.database;
        return await db.query(
          'notes',
          where: 'userId = ? AND isDeleted = 0',
          whereArgs: [testUserId],
        );
      });
      expect(rows, hasLength(1));
      expect(rows!.first['id'], equals(persistedNote.id));
      expect(rows.first['title'], equals('Live SQLite Integration Note'));
      expect(rows.first['content'], contains('Verified UI text saved directly to SQLite table.'));
      expect(rows.first['version'], equals(1));
      expect(rows.first['isDeleted'], equals(0));
    });

    testWidgets(
        'Scenario 2: Reopen and edit the same note through UI, save it, and verify update without creating duplicate',
        (tester) async {
      // 1. Create a note initially using repository
      final initialNote = Note(
        id: 'note_e2e_edit_${uuid.v4()}',
        userId: testUserId,
        title: 'Initial Title Before Edit',
        content: 'Initial content before UI edit.',
        tags: const ['integration'],
        attachments: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        colorValue: 1,
      );
      await tester.runAsync(() async {
        await sqliteNotesRepo.insertNote(initialNote);
      });

      // 2. Open the existing note in NoteEditorScreen
      await tester.pumpWidget(
        createTestApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => NoteEditorScreen(note: initialNote),
                    ),
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

      expect(find.byType(NoteEditorScreen), findsOneWidget);

      // 3. Verify initial text is loaded in title controller
      final titleFinder = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Title',
      );
      expect(titleFinder, findsOneWidget);
      final titleWidget = tester.widget<TextField>(titleFinder);
      expect(titleWidget.controller!.text, equals('Initial Title Before Edit'));

      // 4. Modify Title and Content in UI
      titleWidget.controller!.text = 'Updated Title After UI Edit';
      titleWidget.onChanged?.call('Updated Title After UI Edit');
      await tester.pump();

      final sdeFinder = find.byType(NewSingleDocumentEditor);
      expect(sdeFinder, findsOneWidget);
      final sdeWidget = tester.widget<NewSingleDocumentEditor>(sdeFinder);
      sdeWidget.controller.setMarkdown('Updated content modified in SDE.');
      await tester.pump();

      // 5. Save changes via back button pop
      await triggerSaveAndPop(tester);

      // 6. Direct SQL query assertion: exactly 1 row exists, ID preserved, version incremented
      final rows = await tester.runAsync(() async {
        final db = await DatabaseService.instance.database;
        return await db.query(
          'notes',
          where: 'userId = ? AND isDeleted = 0',
          whereArgs: [testUserId],
        );
      });

      expect(rows, hasLength(1), reason: 'Editing must update the existing record without duplicate');
      expect(rows!.first['id'], equals(initialNote.id));
      expect(rows.first['title'], equals('Updated Title After UI Edit'));
      expect(rows.first['content'], contains('Updated content modified in SDE.'));
      expect(rows.first['version'], equals(2), reason: 'SqliteNotesRepository.updateNote must increment entity version');

      // 7. Verify via SqliteNotesRepository getNotes()
      final refreshedNotes = await tester.runAsync(() async {
        return await sqliteNotesRepo.getNotes();
      });
      expect(refreshedNotes, hasLength(1));
      expect(refreshedNotes!.first.id, equals(initialNote.id));
      expect(refreshedNotes.first.title, equals('Updated Title After UI Edit'));
    });

    testWidgets(
        'Scenario 3: Exit an empty new-note editor and verify that no note row was created in SQLite',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NoteEditorScreen(),
                    ),
                  );
                },
                child: const Text('Open Empty Editor'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Empty Editor'));
      await tester.pumpAndSettle();

      expect(find.byType(NoteEditorScreen), findsOneWidget);

      // Exit immediately without entering title or body
      final backBtn = find.byType(QuickNotesLiquidGlassBackButton);
      expect(backBtn, findsOneWidget);
      await tester.tap(backBtn);
      await tester.pumpAndSettle();

      expect(find.byType(NoteEditorScreen), findsNothing);

      // Direct SQL query assertion: 0 rows inserted
      final rows = await tester.runAsync(() async {
        final db = await DatabaseService.instance.database;
        return await db.query(
          'notes',
          where: 'userId = ?',
          whereArgs: [testUserId],
        );
      });
      expect(rows, isEmpty, reason: 'Empty note must be discarded without inserting an SQLite row');

      final notes = await tester.runAsync(() async {
        return await sqliteNotesRepo.getNotes();
      });
      expect(notes, isEmpty);
    });
  });
}
