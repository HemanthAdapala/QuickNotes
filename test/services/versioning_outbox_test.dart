import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/models/folder.dart';
import 'package:quick_notes/models/task_item.dart';
import 'package:quick_notes/models/sync_outbox_item.dart';
import 'package:quick_notes/services/database_service.dart';
import 'package:quick_notes/services/session_manager.dart';
import 'package:quick_notes/repositories/notes_repository.dart';
import 'package:quick_notes/repositories/folders_repository.dart';
import 'package:quick_notes/repositories/tasks_repository.dart';
import 'package:quick_notes/repositories/outbox_repository.dart';

import 'package:quick_notes/models/session_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SqliteNotesRepository notesRepo;
  late SqliteFoldersRepository foldersRepo;
  late SqliteTasksRepository tasksRepo;
  late SqliteOutboxRepository outboxRepo;
  late String testUserId;

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

    testUserId = 'usr_local_test_123';
    await SessionManager().saveSession(
      userId: testUserId,
      sessionType: SessionType.offline,
    );
  });

  setUp(() async {
    final db = await DatabaseService.instance.database;
    await db.delete('sync_outbox');
    await db.delete('notes');
    await db.delete('folders');
    await db.delete('tasks');

    notesRepo = SqliteNotesRepository();
    foldersRepo = SqliteFoldersRepository();
    tasksRepo = SqliteTasksRepository();
    outboxRepo = SqliteOutboxRepository();
  });

  group('Phase 1.6 Entity Versioning & Sync Outbox Infrastructure Tests', () {
    test('Schema v18: sync_outbox table exists and columns present', () async {
      final db = await DatabaseService.instance.database;
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='sync_outbox'");
      expect(tables, isNotEmpty);

      final noteCols = await db.rawQuery('PRAGMA table_info(notes)');
      final colNames = noteCols.map((c) => c['name'].toString()).toSet();
      expect(colNames.contains('version'), isTrue);
      expect(colNames.contains('lastSyncedVersion'), isTrue);
    });

    test('Note Insert: Atomic entity creation + version 1 + outbox record', () async {
      final note = Note(
        id: 'note_v16_1',
        userId: testUserId,
        title: 'Outbox Test Note',
        content: 'Testing atomic outbox contract',
        tags: const [],
        attachments: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        colorValue: 0,
      );

      await notesRepo.insertNote(note);

      final savedNote = await notesRepo.getNoteById('note_v16_1');
      expect(savedNote, isNotNull);
      expect(savedNote!.version, equals(1));
      expect(savedNote.lastSyncedVersion, equals(0));

      final pendingOutbox = await outboxRepo.getPendingOutboxItems(testUserId);
      expect(pendingOutbox.length, equals(1));
      expect(pendingOutbox.first.entityId, equals('note_v16_1'));
      expect(pendingOutbox.first.entityType, equals('note'));
      expect(pendingOutbox.first.operation, equals('create'));
      expect(pendingOutbox.first.localVersion, equals(1));
    });

    test('Note Update: Version increment to 2 + outbox record', () async {
      final note = Note(
        id: 'note_v16_2',
        userId: testUserId,
        title: 'Initial Title',
        content: 'Content',
        tags: const [],
        attachments: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        colorValue: 0,
      );
      await notesRepo.insertNote(note);

      final saved1 = await notesRepo.getNoteById('note_v16_2');
      final updatedNote = saved1!.copyWith(title: 'Updated Title');
      await notesRepo.updateNote(updatedNote);

      final saved2 = await notesRepo.getNoteById('note_v16_2');
      expect(saved2!.version, equals(2));

      final pendingOutbox = await outboxRepo.getPendingOutboxItems(testUserId);
      expect(pendingOutbox.length, equals(2));
      expect(pendingOutbox[0].operation, equals('create'));
      expect(pendingOutbox[1].operation, equals('update'));
      expect(pendingOutbox[1].localVersion, equals(2));
    });

    test('Hard Delete (lastSyncedVersion == 0): Silent purge of outbox & entity', () async {
      final note = Note(
        id: 'note_unsynced',
        userId: testUserId,
        title: 'Never Synced Note',
        content: 'Content',
        tags: const [],
        attachments: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        colorValue: 0,
      );
      await notesRepo.insertNote(note);

      final outboxBefore = await outboxRepo.getPendingOutboxItems(testUserId);
      expect(outboxBefore.length, equals(1));

      await notesRepo.deleteNote('note_unsynced');

      final saved = await notesRepo.getNoteById('note_unsynced');
      expect(saved, isNull);

      final outboxAfter = await outboxRepo.getPendingOutboxItems(testUserId);
      expect(outboxAfter, isEmpty);
    });

    test('Hard Delete (lastSyncedVersion > 0): Creates DELETE outbox event', () async {
      final db = await DatabaseService.instance.database;
      final note = Note(
        id: 'note_synced',
        userId: testUserId,
        title: 'Synced Note',
        content: 'Content',
        tags: const [],
        attachments: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        colorValue: 0,
        version: 3,
        lastSyncedVersion: 3,
      );
      await db.insert('notes', note.toMap());

      await notesRepo.deleteNote('note_synced');

      final saved = await notesRepo.getNoteById('note_synced');
      expect(saved, isNull);

      final outboxAfter = await outboxRepo.getPendingOutboxItems(testUserId);
      expect(outboxAfter.length, equals(1));
      expect(outboxAfter.first.operation, equals('delete'));
      expect(outboxAfter.first.entityId, equals('note_synced'));
      expect(outboxAfter.first.localVersion, equals(3));
    });

    test('Folder Cascade Trash: Increments versions & creates topological outbox events', () async {
      final parentFolder = Folder(
        id: 'folder_parent',
        userId: testUserId,
        name: 'Parent Folder',
        createdAt: DateTime.now(),
      );
      await foldersRepo.insertFolder(parentFolder);

      final childFolder = Folder(
        id: 'folder_child',
        userId: testUserId,
        name: 'Child Folder',
        parentId: 'folder_parent',
        createdAt: DateTime.now(),
      );
      await foldersRepo.insertFolder(childFolder);

      final note = Note(
        id: 'note_in_child',
        userId: testUserId,
        title: 'Nested Note',
        content: 'Nested content',
        folderId: 'folder_child',
        tags: const [],
        attachments: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        colorValue: 0,
      );
      await notesRepo.insertNote(note);

      await foldersRepo.trashFolder('folder_parent');

      final outbox = await outboxRepo.getPendingOutboxItems(testUserId);
      // 3 creates + 3 update outbox events = 6
      expect(outbox.length, equals(6));

      final updateEvents = outbox.where((e) => e.operation == 'update').toList();
      expect(updateEvents.length, equals(3));
      expect(updateEvents[0].entityId, equals('folder_parent'));
      expect(updateEvents[1].entityId, equals('folder_child'));
      expect(updateEvents[2].entityId, equals('note_in_child'));
    });

    test('Task Operations: Insert, update, and trash atomic outbox behavior', () async {
      final task = TaskItem(
        id: 'task_1',
        userId: testUserId,
        title: 'Buy Groceries',
        dueDate: DateTime.now(),
        priority: 'High',
      );
      await tasksRepo.insertTask(task);

      final saved1 = (await tasksRepo.getTasks()).first;
      expect(saved1.version, equals(1));

      await tasksRepo.trashTask('task_1');

      final pendingOutbox = await outboxRepo.getPendingOutboxItems(testUserId);
      expect(pendingOutbox.length, equals(2));
      expect(pendingOutbox[0].operation, equals('create'));
      expect(pendingOutbox[1].operation, equals('update'));
      expect(pendingOutbox[1].localVersion, equals(2));
    });
  });
}
