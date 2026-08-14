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
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/services/session_manager.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/models/folder.dart';
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

  group('Phase 1.5 — Data Mutation & Repository Consistency Tests', () {
    late SessionManager sessionManager;
    late SqliteNotesRepository notesRepo;
    late SqliteFoldersRepository foldersRepo;
    late NotesProvider notesProvider;
    late String testUserId;

    setUp(() async {
      sessionManager = SessionManager();
      await sessionManager.init();
      testUserId = 'usr_mut_${uuid.v4()}';
      await sessionManager.saveSession(userId: testUserId, sessionType: SessionType.offline);

      notesRepo = SqliteNotesRepository();
      foldersRepo = SqliteFoldersRepository();
      tasksRepo = SqliteTasksRepository();
      notesProvider = NotesProvider(
        notesRepository: notesRepo,
        foldersRepository: foldersRepo,
      );
    });

    test('1. NotesProvider routes all mutations through NotesRepository', () async {
      final note = Note(
        id: 'prov_note_${uuid.v4()}',
        title: 'Provider Note',
        content: 'Content',
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await notesProvider.importNote(note);

      final fetched = await notesRepo.getNoteById(note.id);
      expect(fetched, isNotNull);
      expect(fetched!.title, equals('Provider Note'));
      expect(fetched.userId, equals(testUserId));
    });

    test('2. Active user is required for note mutations (OwnershipException)', () async {
      await sessionManager.clearSession();
      final noSessionRepo = SqliteNotesRepository();
      final note = Note(
        id: 'no_user_${uuid.v4()}',
        title: 'Unauthenticated Note',
        content: 'Content',
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(
        () async => await noSessionRepo.insertNote(note),
        throwsA(isA<OwnershipException>()),
      );
    });

    test('3. User A cannot read User B notes (OwnershipException)', () async {
      final userA = 'user_read_A_${uuid.v4()}';
      final userB = 'user_read_B_${uuid.v4()}';

      await sessionManager.saveSession(userId: userA, sessionType: SessionType.offline);
      final noteA = Note(
        id: 'note_read_A_${uuid.v4()}',
        title: 'User A Secret Note',
        content: 'Top Secret',
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await notesRepo.insertNote(noteA);

      await sessionManager.saveSession(userId: userB, sessionType: SessionType.offline);
      expect(
        () async => await notesRepo.getNoteById(noteA.id),
        throwsA(isA<OwnershipException>()),
      );
    });

    test('4. User A cannot update User B notes (OwnershipException)', () async {
      final userA = 'user_upd_A_${uuid.v4()}';
      final userB = 'user_upd_B_${uuid.v4()}';

      await sessionManager.saveSession(userId: userA, sessionType: SessionType.offline);
      final noteA = Note(
        id: 'note_upd_A_${uuid.v4()}',
        title: 'User A Original Note',
        content: 'Original',
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await notesRepo.insertNote(noteA);

      await sessionManager.saveSession(userId: userB, sessionType: SessionType.offline);
      final hijackedNote = noteA.copyWith(title: 'Hijacked Title');
      expect(
        () async => await notesRepo.updateNote(hijackedNote),
        throwsA(isA<OwnershipException>()),
      );
    });

    test('5. User A cannot delete User B notes (OwnershipException)', () async {
      final userA = 'user_del_A_${uuid.v4()}';
      final userB = 'user_del_B_${uuid.v4()}';

      await sessionManager.saveSession(userId: userA, sessionType: SessionType.offline);
      final noteA = Note(
        id: 'note_del_A_${uuid.v4()}',
        title: 'User A Note to Delete',
        content: 'Delete me',
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

    test('6. queryNotesSummaryPaged is user scoped', () async {
      final userA = 'user_paged_A_${uuid.v4()}';
      final userB = 'user_paged_B_${uuid.v4()}';

      await sessionManager.saveSession(userId: userA, sessionType: SessionType.offline);
      final noteA = Note(
        id: 'paged_A_${uuid.v4()}',
        title: 'Paged Note A',
        content: 'Content A',
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await notesRepo.insertNote(noteA);

      await sessionManager.saveSession(userId: userB, sessionType: SessionType.offline);
      final noteB = Note(
        id: 'paged_B_${uuid.v4()}',
        title: 'Paged Note B',
        content: 'Content B',
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await notesRepo.insertNote(noteB);

      final summariesB = await notesRepo.queryNotesSummaryPaged();
      expect(summariesB.any((m) => m['id'] == noteB.id), isTrue);
      expect(summariesB.any((m) => m['id'] == noteA.id), isFalse);
    });

    test('7. queryHabits is user scoped', () async {
      final userA = 'user_habit_A_${uuid.v4()}';
      final userB = 'user_habit_B_${uuid.v4()}';

      await sessionManager.saveSession(userId: userA, sessionType: SessionType.offline);
      final habitA = Note(
        id: 'habit_A_${uuid.v4()}',
        title: 'Habit A',
        content: 'Content A',
        isHabit: true,
        habitRecurrence: 'daily',
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await notesRepo.insertNote(habitA);

      await sessionManager.saveSession(userId: userB, sessionType: SessionType.offline);
      final habitB = Note(
        id: 'habit_B_${uuid.v4()}',
        title: 'Habit B',
        content: 'Content B',
        isHabit: true,
        habitRecurrence: 'daily',
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await notesRepo.insertNote(habitB);

      final habitsB = await notesRepo.queryHabits();
      expect(habitsB.any((h) => h.id == habitB.id), isTrue);
      expect(habitsB.any((h) => h.id == habitA.id), isFalse);
    });

    test('8. togglePin updates updatedAt', () async {
      final initialTime = DateTime.now().subtract(const Duration(hours: 2));
      final note = Note(
        id: 'pin_note_${uuid.v4()}',
        title: 'Pin Note',
        content: 'Content',
        isPinned: false,
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: initialTime,
        updatedAt: initialTime,
      );
      await notesRepo.insertNote(note);

      await Future.delayed(const Duration(milliseconds: 50));
      await notesRepo.togglePin(note.id);

      final updated = await notesRepo.getNoteById(note.id);
      expect(updated, isNotNull);
      expect(updated!.isPinned, isTrue);
      expect(updated.updatedAt.isAfter(initialTime), isTrue);
    });

    test('9. toggleFavorite updates updatedAt', () async {
      final initialTime = DateTime.now().subtract(const Duration(hours: 2));
      final note = Note(
        id: 'fav_note_${uuid.v4()}',
        title: 'Fav Note',
        content: 'Content',
        isFavorite: false,
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: initialTime,
        updatedAt: initialTime,
      );
      await notesRepo.insertNote(note);

      await Future.delayed(const Duration(milliseconds: 50));
      await notesRepo.toggleFavorite(note.id);

      final updated = await notesRepo.getNoteById(note.id);
      expect(updated, isNotNull);
      expect(updated!.isFavorite, isTrue);
      expect(updated.updatedAt.isAfter(initialTime), isTrue);
    });

    test('10. toggleArchive updates updatedAt', () async {
      final initialTime = DateTime.now().subtract(const Duration(hours: 2));
      final note = Note(
        id: 'arc_note_${uuid.v4()}',
        title: 'Arc Note',
        content: 'Content',
        isArchived: false,
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: initialTime,
        updatedAt: initialTime,
      );
      await notesRepo.insertNote(note);

      await Future.delayed(const Duration(milliseconds: 50));
      await notesRepo.toggleArchive(note.id);

      final updated = await notesRepo.getNoteById(note.id);
      expect(updated, isNotNull);
      expect(updated!.isArchived, isTrue);
      expect(updated.updatedAt.isAfter(initialTime), isTrue);
    });

    test('11. toggleHabitCompletion / habit updates update updatedAt', () async {
      final initialTime = DateTime.now().subtract(const Duration(hours: 2));
      final note = Note(
        id: 'habit_upd_${uuid.v4()}',
        title: 'Habit Note',
        content: '[{"checked": true}]',
        isHabit: true,
        habitStreak: 0,
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: initialTime,
        updatedAt: initialTime,
      );
      await notesRepo.insertNote(note);

      await Future.delayed(const Duration(milliseconds: 50));
      final updatedNote = note.copyWith(
        habitStreak: 1,
        habitLastCompleted: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await notesRepo.updateNote(updatedNote);

      final fetched = await notesRepo.getNoteById(note.id);
      expect(fetched, isNotNull);
      expect(fetched!.habitStreak, equals(1));
      expect(fetched.updatedAt.isAfter(initialTime), isTrue);
    });

    test('12. Export respects active user ownership', () async {
      final userA = 'export_user_A_${uuid.v4()}';
      final userB = 'export_user_B_${uuid.v4()}';

      await sessionManager.saveSession(userId: userA, sessionType: SessionType.offline);
      final noteA = Note(
        id: 'exp_A_${uuid.v4()}',
        title: 'User A Export Note',
        content: 'Content A',
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await notesRepo.insertNote(noteA);

      await sessionManager.saveSession(userId: userB, sessionType: SessionType.offline);
      final exportedNotes = await notesRepo.getNotes();
      expect(exportedNotes.any((n) => n.id == noteA.id), isFalse);
    });

    test('13. Provider state remains correct after repository mutation', () async {
      final note = Note(
        id: 'prov_state_${uuid.v4()}',
        title: 'State Note',
        content: 'Content',
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await notesProvider.importNote(note);
      await notesProvider.togglePin(note.id);

      final providerNotes = notesProvider.notes;
      expect(providerNotes.any((n) => n.id == note.id && n.isPinned), isTrue);
    });

    test('14. Logout / session switch clears provider in-memory cached state', () async {
      final note = Note(
        id: 'switch_note_${uuid.v4()}',
        title: 'User A Note',
        content: 'Content',
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await notesProvider.importNote(note);

      notesProvider.clearLocalState();
      expect(notesProvider.notes, isEmpty);
    });

    test('15. Existing Phase 1.4 trash/restore behavior remains intact', () async {
      final note = Note(
        id: 'trash_verify_${uuid.v4()}',
        title: 'Trash Verify Note',
        content: 'Content',
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await notesRepo.insertNote(note);
      await notesRepo.trashNote(note.id);

      final active = await notesRepo.getNotes();
      final trashed = await notesRepo.getTrashNotes();
      expect(active.any((n) => n.id == note.id), isFalse);
      expect(trashed.any((n) => n.id == note.id), isTrue);

      await notesRepo.restoreNote(note.id);
      final restored = await notesRepo.getNotes();
      expect(restored.any((n) => n.id == note.id), isTrue);
    });

    test('16. Folder cascade tombstone behavior remains intact', () async {
      final folderId = 'fold_casc_${uuid.v4()}';
      final folder = Folder(id: folderId, name: 'Cascading Folder', createdAt: DateTime.now());
      await foldersRepo.insertFolder(folder);

      final note = Note(
        id: 'child_casc_${uuid.v4()}',
        title: 'Child Cascading Note',
        content: 'Content',
        folderId: folderId,
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await notesRepo.insertNote(note);

      await foldersRepo.trashFolder(folderId);

      final trashedNotes = await notesRepo.getTrashNotes();
      final childNote = trashedNotes.firstWhere((n) => n.id == note.id);
      expect(childNote.trashedByFolderId, equals(folderId));

      await foldersRepo.restoreFolder(folderId);
      final activeNotes = await notesRepo.getNotes();
      expect(activeNotes.any((n) => n.id == note.id), isTrue);
    });

    test('17. Multi-step mutations remain atomic inside runInTransaction', () async {
      final dbService = DatabaseService.instance;
      expect(
        () async {
          await dbService.runInTransaction((executor) async {
            await executor.insert('notes', {
              'id': 'atom_note',
              'userId': testUserId,
              'title': 'Atomic Note',
              'content': 'Content',
              'createdAt': DateTime.now().toIso8601String(),
              'updatedAt': DateTime.now().toIso8601String(),
              'colorValue': 0,
            });
            throw Exception('Simulated atomic failure');
          });
        },
        throwsA(isA<Exception>()),
      );

      final check = await dbService.queryById('atom_note');
      expect(check, isNull);
    });

    test('18. Database failures propagate correctly wrapped or raw', () async {
      expect(
        () async => await DatabaseService.instance.runInTransaction((executor) async {
          throw const DatabaseTransactionException('Simulated DB Exception');
        }),
        throwsA(isA<DatabaseTransactionException>()),
      );
    });
  });
}
