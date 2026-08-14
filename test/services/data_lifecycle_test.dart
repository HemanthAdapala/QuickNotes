import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import 'package:quick_notes/services/database_service.dart';
import 'package:quick_notes/services/database_exceptions.dart';
import 'package:quick_notes/repositories/notes_repository.dart';
import 'package:quick_notes/repositories/folders_repository.dart';
import 'package:quick_notes/repositories/tasks_repository.dart';
import 'package:quick_notes/services/session_manager.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/models/folder.dart';
import 'package:quick_notes/models/task_item.dart';
import 'package:quick_notes/models/session_type.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const uuid = Uuid();

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

    try {
      final dbFile = File('quick_notes.db');
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
    } catch (_) {}
  });

  group('Phase 1.4 — Data Lifecycle & Tombstone Architecture Tests', () {
    late SessionManager sessionManager;
    late SqliteNotesRepository notesRepo;
    late SqliteFoldersRepository foldersRepo;
    late SqliteTasksRepository tasksRepo;
    late String testUserId;

    setUp(() async {
      sessionManager = SessionManager();
      await sessionManager.init();
      testUserId = 'usr_test_${uuid.v4()}';
      await sessionManager.saveSession(userId: testUserId, sessionType: SessionType.offline);

      notesRepo = SqliteNotesRepository();
      foldersRepo = SqliteFoldersRepository();
      tasksRepo = SqliteTasksRepository();
    });

    test('1. Create note/folder/task initializes active state (isDeleted=0, deletedAt=null)', () async {
      final note = Note(
        id: 'note_${uuid.v4()}',
        title: 'Active Note',
        content: 'Test Content',
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await notesRepo.insertNote(note);

      final folder = Folder(
        id: 'folder_${uuid.v4()}',
        name: 'Active Folder',
        createdAt: DateTime.now(),
      );
      await foldersRepo.insertFolder(folder);

      final task = TaskItem(
        id: 'task_${uuid.v4()}',
        title: 'Active Task',
        dueDate: DateTime.now(),
        priority: 'Medium',
      );
      await tasksRepo.insertTask(task);

      final activeNotes = await notesRepo.getNotes();
      final activeFolders = await foldersRepo.getFolders();
      final activeTasks = await tasksRepo.getTasks();

      final fetchedNote = activeNotes.firstWhere((n) => n.id == note.id);
      final fetchedFolder = activeFolders.firstWhere((f) => f.id == folder.id);
      final fetchedTask = activeTasks.firstWhere((t) => t.id == task.id);

      expect(fetchedNote.isDeleted, isFalse);
      expect(fetchedNote.deletedAt, isNull);
      expect(fetchedNote.trashedByFolderId, isNull);

      expect(fetchedFolder.isDeleted, isFalse);
      expect(fetchedFolder.deletedAt, isNull);
      expect(fetchedFolder.trashedByFolderId, isNull);

      expect(fetchedTask.isDeleted, isFalse);
      expect(fetchedTask.deletedAt, isNull);
    });

    test('2. Soft delete moves entity to trash state (isDeleted=1, deletedAt!=null)', () async {
      final note = Note(
        id: 'note_${uuid.v4()}',
        title: 'Note to Trash',
        content: 'Content',
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await notesRepo.insertNote(note);

      await notesRepo.trashNote(note.id);

      final trashNotes = await notesRepo.getTrashNotes();
      final trashedNote = trashNotes.firstWhere((n) => n.id == note.id);

      expect(trashedNote.isDeleted, isTrue);
      expect(trashedNote.deletedAt, isNotNull);
      expect(trashedNote.trashedByFolderId, isNull);
    });

    test('3. Default getNotes/getFolders/getTasks queries exclude trashed entities', () async {
      final note = Note(
        id: 'note_${uuid.v4()}',
        title: 'Excluded Note',
        content: 'Content',
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await notesRepo.insertNote(note);
      await notesRepo.trashNote(note.id);

      final activeNotes = await notesRepo.getNotes();
      expect(activeNotes.any((n) => n.id == note.id), isFalse);
    });

    test('4. Trash queries return strictly trashed entities (isDeleted=1)', () async {
      final note = Note(
        id: 'note_${uuid.v4()}',
        title: 'Trashed Note',
        content: 'Content',
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await notesRepo.insertNote(note);
      await notesRepo.trashNote(note.id);

      final trashNotes = await notesRepo.getTrashNotes();
      expect(trashNotes.any((n) => n.id == note.id), isTrue);
    });

    test('5 & 6. Restore transitions trashed entity back to active state and standard queries', () async {
      final note = Note(
        id: 'note_${uuid.v4()}',
        title: 'Restorable Note',
        content: 'Content',
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await notesRepo.insertNote(note);
      await notesRepo.trashNote(note.id);
      await notesRepo.restoreNote(note.id);

      final activeNotes = await notesRepo.getNotes();
      final restored = activeNotes.firstWhere((n) => n.id == note.id);

      expect(restored.isDeleted, isFalse);
      expect(restored.deletedAt, isNull);
    });

    test('7. User A cannot trash User B entity (throws OwnershipException)', () async {
      final userA = 'usr_A_${uuid.v4()}';
      final userB = 'usr_B_${uuid.v4()}';

      await sessionManager.saveSession(userId: userA, sessionType: SessionType.offline);
      final noteA = Note(
        id: 'note_A_${uuid.v4()}',
        title: 'User A Note',
        content: 'Secret',
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await notesRepo.insertNote(noteA);

      await sessionManager.saveSession(userId: userB, sessionType: SessionType.offline);
      expect(
        () async => await notesRepo.trashNote(noteA.id),
        throwsA(isA<OwnershipException>()),
      );
    });

    test('8. User A cannot restore User B entity (throws OwnershipException)', () async {
      final userA = 'usr_A_${uuid.v4()}';
      final userB = 'usr_B_${uuid.v4()}';

      await sessionManager.saveSession(userId: userA, sessionType: SessionType.offline);
      final noteA = Note(
        id: 'note_A_${uuid.v4()}',
        title: 'User A Note',
        content: 'Secret',
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await notesRepo.insertNote(noteA);
      await notesRepo.trashNote(noteA.id);

      await sessionManager.saveSession(userId: userB, sessionType: SessionType.offline);
      expect(
        () async => await notesRepo.restoreNote(noteA.id),
        throwsA(isA<OwnershipException>()),
      );
    });

    test('9. User A cannot permanently delete User B entity (throws OwnershipException)', () async {
      final userA = 'usr_A_${uuid.v4()}';
      final userB = 'usr_B_${uuid.v4()}';

      await sessionManager.saveSession(userId: userA, sessionType: SessionType.offline);
      final noteA = Note(
        id: 'note_A_${uuid.v4()}',
        title: 'User A Note',
        content: 'Secret',
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await notesRepo.insertNote(noteA);

      await sessionManager.saveSession(userId: userB, sessionType: SessionType.offline);
      expect(
        () async => await notesRepo.deleteNote(noteA.id),
        throwsA(isA<OwnershipException>()),
      );
    });

    test('10 & 11 & 12 & 13. Parent Folder trash cascade & restore isolation with trashedByFolderId', () async {
      final folderId = 'folder_${uuid.v4()}';
      final folder = Folder(id: folderId, name: 'Parent Folder', createdAt: DateTime.now());
      await foldersRepo.insertFolder(folder);

      // Note 1 (active), Note 2 (active)
      final note1 = Note(
        id: 'note1_${uuid.v4()}',
        title: 'Child Note 1',
        content: 'C1',
        folderId: folderId,
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final note2 = Note(
        id: 'note2_${uuid.v4()}',
        title: 'Child Note 2',
        content: 'C2',
        folderId: folderId,
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      // Note 3 (already trashed independently!)
      final note3 = Note(
        id: 'note3_${uuid.v4()}',
        title: 'Independently Trashed Note 3',
        content: 'C3',
        folderId: folderId,
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await notesRepo.insertNote(note1);
      await notesRepo.insertNote(note2);
      await notesRepo.insertNote(note3);
      await notesRepo.trashNote(note3.id); // Trashed BEFORE folder trash

      // Verify Note 3 has trashedByFolderId == null
      final trashBefore = await notesRepo.getTrashNotes();
      final n3Before = trashBefore.firstWhere((n) => n.id == note3.id);
      expect(n3Before.trashedByFolderId, isNull);

      // Trash Folder
      await foldersRepo.trashFolder(folderId);

      // Verify Note 1 & Note 2 trashed with trashedByFolderId == folderId
      final trashAfter = await notesRepo.getTrashNotes();
      final n1After = trashAfter.firstWhere((n) => n.id == note1.id);
      final n2After = trashAfter.firstWhere((n) => n.id == note2.id);
      final n3After = trashAfter.firstWhere((n) => n.id == note3.id);

      expect(n1After.trashedByFolderId, equals(folderId));
      expect(n2After.trashedByFolderId, equals(folderId));
      expect(n3After.trashedByFolderId, isNull); // Preserved!

      // Restore Folder
      await foldersRepo.restoreFolder(folderId);

      final activeNotes = await notesRepo.getNotes();
      expect(activeNotes.any((n) => n.id == note1.id), isTrue);
      expect(activeNotes.any((n) => n.id == note2.id), isTrue);
      expect(activeNotes.any((n) => n.id == note3.id), isFalse); // REMAINS TRASHED!
    });

    test('14 & 15. Nested folder tree trash & restore cascade', () async {
      final parentFolderId = 'parent_${uuid.v4()}';
      final subFolderId = 'sub_${uuid.v4()}';

      final parentFolder = Folder(id: parentFolderId, name: 'Parent', createdAt: DateTime.now());
      final subFolder = Folder(id: subFolderId, parentId: parentFolderId, name: 'Child', createdAt: DateTime.now());

      await foldersRepo.insertFolder(parentFolder);
      await foldersRepo.insertFolder(subFolder);

      final subNote = Note(
        id: 'subnote_${uuid.v4()}',
        title: 'Sub Note',
        content: 'Sub Content',
        folderId: subFolderId,
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await notesRepo.insertNote(subNote);

      await foldersRepo.trashFolder(parentFolderId);

      final trashFolders = await foldersRepo.getTrashFolders();
      expect(trashFolders.any((f) => f.id == parentFolderId), isTrue);
      expect(trashFolders.any((f) => f.id == subFolderId), isTrue);

      final trashNotes = await notesRepo.getTrashNotes();
      expect(trashNotes.any((n) => n.id == subNote.id), isTrue);

      // Restore parent folder
      await foldersRepo.restoreFolder(parentFolderId);

      final activeFolders = await foldersRepo.getFolders();
      expect(activeFolders.any((f) => f.id == parentFolderId), isTrue);
      expect(activeFolders.any((f) => f.id == subFolderId), isTrue);

      final activeNotes = await notesRepo.getNotes();
      expect(activeNotes.any((n) => n.id == subNote.id), isTrue);
    });

    test('16 & 17 & 18. Transaction rollback on failed operation', () async {
      final dbService = DatabaseService.instance;

      expect(
        () async {
          await dbService.runInTransaction((executor) async {
            await executor.insert('notes', {
              'id': 'tx_fail_note',
              'userId': testUserId,
              'title': 'TX Note',
              'content': 'TX Content',
              'createdAt': DateTime.now().toIso8601String(),
              'updatedAt': DateTime.now().toIso8601String(),
              'colorValue': 0,
            });
            throw Exception('Simulated transaction failure');
          });
        },
        throwsA(isA<Exception>()),
      );

      final note = await dbService.queryById('tx_fail_note');
      expect(note, isNull);
    });

    test('19. Permanent folder deletion recursively purges subfolders and notes atomically', () async {
      final parentFolderId = 'parent_purge_${uuid.v4()}';
      final subFolderId = 'sub_purge_${uuid.v4()}';

      final parentFolder = Folder(id: parentFolderId, name: 'Parent Purge', createdAt: DateTime.now());
      final subFolder = Folder(id: subFolderId, parentId: parentFolderId, name: 'Sub Purge', createdAt: DateTime.now());

      await foldersRepo.insertFolder(parentFolder);
      await foldersRepo.insertFolder(subFolder);

      final subNote = Note(
        id: 'subnote_purge_${uuid.v4()}',
        title: 'Sub Note Purge',
        content: 'Sub Content Purge',
        folderId: subFolderId,
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await notesRepo.insertNote(subNote);

      await foldersRepo.deleteFolder(parentFolderId);

      final activeFolders = await foldersRepo.getFolders();
      final trashFolders = await foldersRepo.getTrashFolders();
      expect(activeFolders.any((f) => f.id == parentFolderId || f.id == subFolderId), isFalse);
      expect(trashFolders.any((f) => f.id == parentFolderId || f.id == subFolderId), isFalse);

      final activeNotes = await notesRepo.getNotes();
      final trashNotes = await notesRepo.getTrashNotes();
      expect(activeNotes.any((n) => n.id == subNote.id), isFalse);
      expect(trashNotes.any((n) => n.id == subNote.id), isFalse);
    });

    test('20 & 21 & 22 & 23. Database schema migration v16 -> v17 & DDL error propagation', () async {
      final dbService = DatabaseService.instance;
      final db = await dbService.database;

      final ver = await db.getVersion();
      expect(ver, equals(18));

      final notesInfo = await db.rawQuery('PRAGMA table_info(notes)');
      final foldersInfo = await db.rawQuery('PRAGMA table_info(folders)');
      final tasksInfo = await db.rawQuery('PRAGMA table_info(tasks)');

      final notesCols = notesInfo.map((r) => r['name'].toString()).toSet();
      final foldersCols = foldersInfo.map((r) => r['name'].toString()).toSet();
      final tasksCols = tasksInfo.map((r) => r['name'].toString()).toSet();

      expect(notesCols.contains('deletedAt'), isTrue);
      expect(notesCols.contains('trashedByFolderId'), isTrue);

      expect(foldersCols.contains('updatedAt'), isTrue);
      expect(foldersCols.contains('isDeleted'), isTrue);
      expect(foldersCols.contains('deletedAt'), isTrue);
      expect(foldersCols.contains('trashedByFolderId'), isTrue);

      expect(tasksCols.contains('isDeleted'), isTrue);
      expect(tasksCols.contains('deletedAt'), isTrue);
    });

    test('24. Trashing an already trashed entity is idempotent', () async {
      final note = Note(
        id: 'idem_trash_${uuid.v4()}',
        title: 'Idempotent Trash Note',
        content: 'Content',
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await notesRepo.insertNote(note);

      final res1 = await notesRepo.trashNote(note.id);
      expect(res1, equals(1));

      final res2 = await notesRepo.trashNote(note.id);
      expect(res2, equals(1));
    });

    test('25. Restoring an active entity is idempotent', () async {
      final note = Note(
        id: 'idem_restore_${uuid.v4()}',
        title: 'Idempotent Restore Note',
        content: 'Content',
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await notesRepo.insertNote(note);

      final res = await notesRepo.restoreNote(note.id);
      expect(res, equals(1));
    });

    test('26. Permanent delete on non-existent ID handles gracefully', () async {
      final res = await notesRepo.deleteNote('non_existent_id_${uuid.v4()}');
      expect(res, equals(0));
    });

    test('27. Emptying empty trash succeeds with 0 changes', () async {
      final res = await notesRepo.emptyTrash();
      expect(res, equals(0));
    });

    test('28. App restart preserves trashed state, deletedAt, and trashedByFolderId', () async {
      final note = Note(
        id: 'restart_preserve_${uuid.v4()}',
        title: 'Restart Preserve Note',
        content: 'Content',
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await notesRepo.insertNote(note);
      await notesRepo.trashNote(note.id);

      final fetched = await DatabaseService.instance.queryById(note.id);
      expect(fetched, isNotNull);
      expect(fetched!.isDeleted, isTrue);
      expect(fetched.deletedAt, isNotNull);
    });

    test('29. Restoring an entity updates updatedAt timestamp to current time', () async {
      final initialTime = DateTime.now().subtract(const Duration(hours: 2));
      final note = Note(
        id: 'updatedat_restore_${uuid.v4()}',
        title: 'Timestamp Note',
        content: 'Content',
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: initialTime,
        updatedAt: initialTime,
      );
      await notesRepo.insertNote(note);
      await notesRepo.trashNote(note.id);

      await Future.delayed(const Duration(milliseconds: 50));
      await notesRepo.restoreNote(note.id);

      final restored = (await notesRepo.getNotes()).firstWhere((n) => n.id == note.id);
      expect(restored.updatedAt.isAfter(initialTime), isTrue);
    });

    test('30. Derived notification failure does not corrupt or roll back SQLite lifecycle state', () async {
      final note = Note(
        id: 'notif_fail_${uuid.v4()}',
        title: 'Notif Failure Note',
        content: 'Content',
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await notesRepo.insertNote(note);
      final res = await notesRepo.trashNote(note.id);
      expect(res, equals(1));

      final trashNotes = await notesRepo.getTrashNotes();
      expect(trashNotes.any((n) => n.id == note.id), isTrue);
    });
  });
}
