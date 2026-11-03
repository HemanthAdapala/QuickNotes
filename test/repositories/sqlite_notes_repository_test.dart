import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import 'package:quick_notes/services/database_service.dart';
import 'package:quick_notes/services/database_exceptions.dart';
import 'package:quick_notes/repositories/notes_repository.dart';
import 'package:quick_notes/services/session_manager.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/models/session_type.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const uuid = Uuid();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => '.',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async => null,
    );

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final db = await DatabaseService.instance.database;
    await db.delete('notes', where: 'isPinned IS NULL OR colorValue IS NULL');
  });

  group('SqliteNotesRepository & Persistence Tests', () {
    late SessionManager sessionManager;
    late SqliteNotesRepository repository;
    late String userA;
    late String userB;

    setUp(() async {
      sessionManager = SessionManager();
      await sessionManager.init();
      userA = 'usr_repo_a_${uuid.v4()}';
      userB = 'usr_repo_b_${uuid.v4()}';

      await sessionManager.saveSession(
          userId: userA, sessionType: SessionType.offline);
      repository = SqliteNotesRepository();
    });

    test('1. insertNote and getNotes persist note with user isolation',
        () async {
      final noteA = Note(
        id: 'note_${uuid.v4()}',
        title: 'User A Note',
        content: 'Content A',
        tags: const ['tagA'],
        attachments: const [],
        colorValue: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await repository.insertNote(noteA);
      expect(result, greaterThan(0));

      // Fetch as User A
      final notesA = await repository.getNotes();
      expect(notesA.any((n) => n.id == noteA.id), isTrue);
      final fetched = await repository.getNoteById(noteA.id);
      expect(fetched, isNotNull);
      expect(fetched!.title, equals('User A Note'));
      expect(fetched.userId, equals(userA));

      // Switch to User B
      await sessionManager.saveSession(
          userId: userB, sessionType: SessionType.offline);
      final notesB = await repository.getNotes();
      expect(notesB.any((n) => n.id == noteA.id), isFalse);

      // User B querying User A note throws OwnershipException
      expect(
        () async => await repository.getNoteById(noteA.id),
        throwsA(isA<OwnershipException>()),
      );
    });

    test('2. updateNote modifies content and increments entity version',
        () async {
      final note = Note(
        id: 'note_${uuid.v4()}',
        title: 'Initial Title',
        content: 'Initial Content',
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.insertNote(note);
      final inserted = await repository.getNoteById(note.id);
      expect(inserted!.version, equals(1));

      final updatedNote = inserted.copyWith(
        title: 'Updated Title',
        content: 'Updated Content',
      );
      await repository.updateNote(updatedNote);

      final fetched = await repository.getNoteById(note.id);
      expect(fetched!.title, equals('Updated Title'));
      expect(fetched.content, equals('Updated Content'));
      expect(fetched.version, equals(2)); // Version incremented atomically
    });

    test('3. Soft-delete (trashNote), restoreNote, and emptyTrash', () async {
      final note = Note(
        id: 'note_${uuid.v4()}',
        title: 'Note to be Trashed',
        content: 'Trash content',
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.insertNote(note);

      // Trash the note
      await repository.trashNote(note.id);
      final activeNotes = await repository.getNotes();
      expect(activeNotes.any((n) => n.id == note.id), isFalse);

      final trashNotes = await repository.getTrashNotes();
      expect(trashNotes.any((n) => n.id == note.id), isTrue);
      final trashed = trashNotes.firstWhere((n) => n.id == note.id);
      expect(trashed.isDeleted, isTrue);
      expect(trashed.deletedAt, isNotNull);

      // Restore the note
      await repository.restoreNote(note.id);
      final restoredNotes = await repository.getNotes();
      expect(restoredNotes.any((n) => n.id == note.id), isTrue);
      final restored = restoredNotes.firstWhere((n) => n.id == note.id);
      expect(restored.isDeleted, isFalse);
      expect(restored.deletedAt, isNull);

      // Trash again and empty trash
      await repository.trashNote(note.id);
      await repository.emptyTrash();
      final trashAfterEmpty = await repository.getTrashNotes();
      expect(trashAfterEmpty.any((n) => n.id == note.id), isFalse);
    });

    test('4. Atomic Outbox generation on CRUD mutations', () async {
      final db = await DatabaseService.instance.database;
      final noteId = 'note_${uuid.v4()}';
      final note = Note(
        id: noteId,
        title: 'Outbox Test Note',
        content: 'Content for Outbox',
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Insert mutation
      await repository.insertNote(note);
      final outboxAfterInsert = await db.query(
        'sync_outbox',
        where: 'entityId = ? AND operation = ?',
        whereArgs: [noteId, 'create'],
      );
      expect(outboxAfterInsert.length, equals(1));
      expect(outboxAfterInsert.first['entityType'], equals('note'));

      // Update mutation
      final updated = note.copyWith(title: 'Outbox Updated Title');
      await repository.updateNote(updated);
      final outboxAfterUpdate = await db.query(
        'sync_outbox',
        where: 'entityId = ? AND operation = ?',
        whereArgs: [noteId, 'update'],
      );
      expect(outboxAfterUpdate.length, equals(1));

      // Trash mutation records an outbox update event with incremented version
      await repository.trashNote(noteId);
      final outboxAfterTrash = await db.query(
        'sync_outbox',
        where: 'entityId = ? AND operation = ? AND localVersion = ?',
        whereArgs: [noteId, 'update', 3],
      );
      expect(outboxAfterTrash.length, equals(1));

      // Hard delete of a synced note records a 'delete' outbox event
      final syncedNoteId = 'synced_${uuid.v4()}';
      await repository.insertNote(Note(
        id: syncedNoteId,
        title: 'Synced Note',
        content: 'Content',
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        lastSyncedVersion: 1, // Synced flag
      ));

      await repository.deleteNote(syncedNoteId);
      final outboxAfterHardDelete = await db.query(
        'sync_outbox',
        where: 'entityId = ? AND operation = ?',
        whereArgs: [syncedNoteId, 'delete'],
      );
      expect(outboxAfterHardDelete.length, equals(1));
    });

    test(
        '5. Operation throws OwnershipException when session is unauthenticated',
        () async {
      // Clear session
      await sessionManager.clearSession();

      final note = Note(
        id: 'note_${uuid.v4()}',
        title: 'Unauthenticated Note',
        content: 'Will fail',
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(() async => await repository.getNotes(),
          throwsA(isA<OwnershipException>()));
      expect(() async => await repository.insertNote(note),
          throwsA(isA<OwnershipException>()));
      expect(() async => await repository.updateNote(note),
          throwsA(isA<OwnershipException>()));
      expect(() async => await repository.trashNote('some_id'),
          throwsA(isA<OwnershipException>()));
      expect(() async => await repository.deleteNote('some_id'),
          throwsA(isA<OwnershipException>()));
    });

    test(
        '6. queryNotesSummaryPaged performs database-level filtering and pagination',
        () async {
      final folderId = 'f_${uuid.v4()}';
      for (int i = 0; i < 5; i++) {
        await repository.insertNote(Note(
          id: 'paged_${uuid.v4()}',
          title: 'Paged Note $i',
          content: 'Content $i',
          category: i.isEven ? 'Work' : 'Personal',
          folderId: i == 0 ? folderId : null,
          isFavorite: i == 1,
          isArchived: i == 2,
          tags: const [],
          attachments: const [],
          colorValue: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }

      // Filter by folder
      final folderSummaries =
          await repository.queryNotesSummaryPaged(folderId: folderId);
      expect(folderSummaries.length, equals(1));
      expect(folderSummaries.first['title'], equals('Paged Note 0'));

      // Filter by category Work
      final workSummaries =
          await repository.queryNotesSummaryPaged(category: 'Work');
      expect(workSummaries.every((s) => s['category'] == 'Work'), isTrue);

      // Pagination limits
      final paged =
          await repository.queryNotesSummaryPaged(limit: 2, offset: 0);
      expect(paged.length, equals(2));
    });

    test('7. searchNotes matches title, content, and tags in SQLite', () async {
      await repository.insertNote(Note(
        id: 'search_1_${uuid.v4()}',
        title: 'Architectural Blueprint',
        content: 'Overview of system layers',
        tags: const ['system', 'core'],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      await repository.insertNote(Note(
        id: 'search_2_${uuid.v4()}',
        title: 'Shopping List',
        content: 'Milk, bread, and honey',
        tags: const ['personal'],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // Title match
      final matchTitle = await repository.searchNotes('Blueprint');
      expect(matchTitle.length, equals(1));
      expect(matchTitle.first.title, equals('Architectural Blueprint'));

      // Content match
      final matchContent = await repository.searchNotes('honey');
      expect(matchContent.length, equals(1));
      expect(matchContent.first.title, equals('Shopping List'));

      // Tag match
      final matchTag = await repository.searchNotes('core');
      expect(matchTag.length, equals(1));
      expect(matchTag.first.title, equals('Architectural Blueprint'));
    });

    test(
        '8. Hard delete outbox rules: silent purge for unsynced vs delete record for synced notes',
        () async {
      final db = await DatabaseService.instance.database;

      // Unsynced note (lastSyncedVersion == 0)
      final unsyncedId = 'unsynced_${uuid.v4()}';
      await repository.insertNote(Note(
        id: unsyncedId,
        title: 'Unsynced Temporary Draft',
        content: 'Never reached cloud',
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        lastSyncedVersion: 0,
      ));

      // Hard delete unsynced note
      await repository.deleteNote(unsyncedId);
      final outboxUnsynced = await db.query(
        'sync_outbox',
        where: 'entityId = ?',
        whereArgs: [unsyncedId],
      );
      // Pending outbox items are purged, zero delete outbox rows remain
      expect(outboxUnsynced, isEmpty);

      // Synced note (lastSyncedVersion = 1)
      final syncedId = 'synced_${uuid.v4()}';
      await repository.insertNote(Note(
        id: syncedId,
        title: 'Synced Cloud Note',
        content: 'Already exists on remote server',
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        version: 1,
        lastSyncedVersion: 1,
      ));

      // Hard delete synced note
      await repository.deleteNote(syncedId);
      final outboxSynced = await db.query(
        'sync_outbox',
        where: 'entityId = ? AND operation = ?',
        whereArgs: [syncedId, 'delete'],
      );
      expect(outboxSynced.length, equals(1));
      expect(outboxSynced.first['operation'], equals('delete'));
    });

    test(
        '9. Unauthenticated session throws OwnershipException across all repository operations',
        () async {
      final sampleNote = Note(
        id: 'anon_${uuid.v4()}',
        title: 'Anonymous Attempt',
        content: 'Should not persist',
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Clear session to simulate unauthenticated state
      await sessionManager.clearSession();

      expect(() async => await repository.getNotes(),
          throwsA(isA<OwnershipException>()));
      expect(() async => await repository.getTrashNotes(),
          throwsA(isA<OwnershipException>()));
      expect(() async => await repository.insertNote(sampleNote),
          throwsA(isA<OwnershipException>()));
      expect(() async => await repository.updateNote(sampleNote),
          throwsA(isA<OwnershipException>()));
      expect(() async => await repository.trashNote(sampleNote.id),
          throwsA(isA<OwnershipException>()));
      expect(() async => await repository.restoreNote(sampleNote.id),
          throwsA(isA<OwnershipException>()));
      expect(() async => await repository.deleteNote(sampleNote.id),
          throwsA(isA<OwnershipException>()));
    });

    test(
        '10. Non-existent note mutations return 0 affected rows and null lookup gracefully',
        () async {
      final nonExistentId = 'ghost_${uuid.v4()}';

      // Queries and mutations on absent IDs
      final fetched = await repository.getNoteById(nonExistentId);
      expect(fetched, isNull);

      final trashResult = await repository.trashNote(nonExistentId);
      expect(trashResult, equals(0));

      final restoreResult = await repository.restoreNote(nonExistentId);
      expect(restoreResult, equals(0));

      final deleteResult = await repository.deleteNote(nonExistentId);
      expect(deleteResult, equals(0));
    });

    test(
        '11. SQLite error resilience: handling raw DB row with missing/null optional fields',
        () async {
      final db = await DatabaseService.instance.database;
      final rawId = 'raw_sparse_${uuid.v4()}';

      try {
        // Directly insert sparse row with minimal columns
        await db.insert('notes', {
          'id': rawId,
          'title': 'Raw Sparse Note',
          'content': 'Content in sparse note',
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
          'userId': userA,
          'isPinned': 0,
          'colorValue': 0,
          'isDeleted': 0,
          'version': 1,
          'lastSyncedVersion': 0,
        });

        // Fetch via repository and ensure it handles sparse/null columns cleanly
        final fetched = await repository.getNoteById(rawId);
        expect(fetched, isNotNull);
        expect(fetched!.title, equals('Raw Sparse Note'));
        expect(fetched.tags, isEmpty);
        expect(fetched.attachments, isEmpty);
        expect(fetched.folderId, isNull);
        expect(fetched.isHabit, isFalse);
      } finally {
        await db.delete('notes', where: 'id = ?', whereArgs: [rawId]);
      }
    });
  });
}
