import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quick_notes/models/remote_change.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/services/remote_change_applier.dart';
import 'package:quick_notes/services/database_service.dart';
import 'package:quick_notes/services/session_manager.dart';
import 'package:quick_notes/models/session_type.dart';
import 'package:quick_notes/repositories/notes_repository.dart';
import 'package:quick_notes/repositories/outbox_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Note createTestNote({
  required String id,
  String? userId,
  required String title,
  String content = 'Content',
  int version = 1,
  int lastSyncedVersion = 0,
}) {
  final now = DateTime.now();
  return Note(
    id: id,
    userId: userId,
    title: title,
    content: content,
    tags: const [],
    attachments: const [],
    createdAt: now,
    updatedAt: now,
    colorValue: 0xFFFFFFFF,
    version: version,
    lastSyncedVersion: lastSyncedVersion,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService dbService;
  late RemoteChangeApplier applier;
  late SqliteNotesRepository notesRepo;
  late SqliteOutboxRepository outboxRepo;

  const testUserId = 'usr_phase18_applier';

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => '.',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async => null,
    );

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    dbService = DatabaseService.instance;
    await dbService.queryAll();

    final db = await dbService.database;
    await db.delete('notes');
    await db.delete('folders');
    await db.delete('tasks');
    await db.delete('sync_outbox');
    await db.delete('users');

    applier = RemoteChangeApplier(dbService: dbService);
    notesRepo = SqliteNotesRepository(dbService: dbService);
    outboxRepo = SqliteOutboxRepository(dbService: dbService);

    await SessionManager().saveSession(
      userId: testUserId,
      sessionType: SessionType.google,
    );
  });

  group('Phase 1.8 — RemoteChangeApplier Tests', () {
    test('1. Topological sorting orders folders -> notes -> tasks', () {
      final changeTask = RemoteChange(
        entityType: 'task',
        entityId: 't1',
        userId: testUserId,
        operation: 'create',
        remoteVersion: 1,
        serverTimestamp: DateTime.now(),
      );
      final changeFolder = RemoteChange(
        entityType: 'folder',
        entityId: 'f1',
        userId: testUserId,
        operation: 'create',
        remoteVersion: 1,
        serverTimestamp: DateTime.now(),
      );
      final changeNote = RemoteChange(
        entityType: 'note',
        entityId: 'n1',
        userId: testUserId,
        operation: 'create',
        remoteVersion: 1,
        serverTimestamp: DateTime.now(),
      );

      final sorted = applier.sortTopologically([changeTask, changeFolder, changeNote]);

      expect(sorted[0].entityType, equals('folder'));
      expect(sorted[1].entityType, equals('note'));
      expect(sorted[2].entityType, equals('task'));
    });

    test('2. Clean remote create applies to SQLite without generating sync_outbox record', () async {
      final remoteNote = createTestNote(
        id: 'note_rem_101',
        userId: testUserId,
        title: 'Remote Title',
        content: 'Remote Content',
        version: 1,
        lastSyncedVersion: 1,
      );

      final change = RemoteChange(
        entityType: 'note',
        entityId: remoteNote.id,
        userId: testUserId,
        operation: 'create',
        remoteVersion: 1,
        payload: remoteNote.toMap(),
        serverTimestamp: DateTime.now(),
      );

      final count = await applier.applyBatch(
        activeUserId: testUserId,
        changes: [change],
      );

      expect(count, equals(1));

      // Verify entity saved in SQLite
      final fetched = await notesRepo.getNoteById(remoteNote.id);
      expect(fetched, isNotNull);
      expect(fetched!.title, equals('Remote Title'));
      expect(fetched.version, equals(1));
      expect(fetched.lastSyncedVersion, equals(1));

      // Verify ZERO outbox items created
      final outboxItems = await outboxRepo.getPendingOutboxItems(testUserId);
      expect(outboxItems.isEmpty, isTrue);
    });

    test('3. Stale remote change (remoteVersion <= lastSyncedVersion) is ignored', () async {
      final note = createTestNote(
        id: 'note_stale_1',
        userId: testUserId,
        title: 'Current Local',
        content: 'Local Content',
        version: 5,
        lastSyncedVersion: 5,
      );

      final db = await dbService.database;
      await db.insert('notes', note.toMap());

      // Attempt to apply stale remote change with version 3
      final staleChange = RemoteChange(
        entityType: 'note',
        entityId: note.id,
        userId: testUserId,
        operation: 'update',
        remoteVersion: 3,
        payload: note.copyWith(title: 'Stale Remote Title').toMap(),
        serverTimestamp: DateTime.now(),
      );

      final applied = await applier.applyBatch(
        activeUserId: testUserId,
        changes: [staleChange],
      );

      expect(applied, equals(0));

      // Entity remains unchanged
      final fetched = await notesRepo.getNoteById(note.id);
      expect(fetched!.title, equals('Current Local'));
      expect(fetched.version, equals(5));
    });

    test('4. Server Wins: Pending local update is overwritten by newer remote update, and outbox row is cleared', () async {
      final initialNote = createTestNote(
        id: 'note_conflict_1',
        title: 'Initial Note',
        content: 'Initial Content',
      );
      await notesRepo.insertNote(initialNote);

      final updatedLocal = initialNote.copyWith(title: 'Pending Local Title');
      await notesRepo.updateNote(updatedLocal);

      var outboxItems = await outboxRepo.getPendingOutboxItems(testUserId);
      expect(outboxItems.where((i) => i.entityId == initialNote.id).isNotEmpty, isTrue);

      final remoteUpdate = RemoteChange(
        entityType: 'note',
        entityId: initialNote.id,
        userId: testUserId,
        operation: 'update',
        remoteVersion: 5,
        payload: initialNote.copyWith(title: 'Server Winner Title').toMap(),
        serverTimestamp: DateTime.now(),
      );

      final applied = await applier.applyBatch(
        activeUserId: testUserId,
        changes: [remoteUpdate],
      );

      expect(applied, equals(1));

      final fetched = await notesRepo.getNoteById(initialNote.id);
      expect(fetched!.title, equals('Server Winner Title'));
      expect(fetched.version, equals(5));
      expect(fetched.lastSyncedVersion, equals(5));

      // Pending local outbox item CLEARED
      outboxItems = await outboxRepo.getPendingOutboxItems(testUserId);
      expect(outboxItems.where((i) => i.entityId == initialNote.id).isEmpty, isTrue);
    });

    test('5. Local Delete Wins: Pending local delete retains outbox item and ignores remote update', () async {
      final note = createTestNote(
        id: 'note_del_win',
        userId: testUserId,
        title: 'To Be Deleted',
        content: 'Content',
        version: 1,
        lastSyncedVersion: 1,
      );
      final db = await dbService.database;
      await db.insert('notes', note.toMap());

      await notesRepo.deleteNote(note.id);

      var outboxItems = await outboxRepo.getPendingOutboxItems(testUserId);
      final deleteOutboxItem = outboxItems.firstWhere((i) => i.entityId == note.id);
      expect(deleteOutboxItem.operation, equals('delete'));

      final remoteUpdate = RemoteChange(
        entityType: 'note',
        entityId: note.id,
        userId: testUserId,
        operation: 'update',
        remoteVersion: 3,
        payload: note.copyWith(title: 'Remote Ignored Update').toMap(),
        serverTimestamp: DateTime.now(),
      );

      final applied = await applier.applyBatch(
        activeUserId: testUserId,
        changes: [remoteUpdate],
      );

      expect(applied, equals(0));

      outboxItems = await outboxRepo.getPendingOutboxItems(testUserId);
      expect(outboxItems.where((i) => i.entityId == note.id).isNotEmpty, isTrue);
    });

    test('6. User ID mismatch change is rejected', () async {
      final badNote = createTestNote(id: 'note_other_usr', title: 'Hacked');
      final changeOtherUser = RemoteChange(
        entityType: 'note',
        entityId: 'note_other_usr',
        userId: 'usr_other_hacker',
        operation: 'create',
        remoteVersion: 1,
        payload: badNote.toMap(),
        serverTimestamp: DateTime.now(),
      );

      final applied = await applier.applyBatch(
        activeUserId: testUserId,
        changes: [changeOtherUser],
      );

      expect(applied, equals(0));

      final fetched = await notesRepo.getNoteById('note_other_usr');
      expect(fetched, isNull);
    });
  });
}
