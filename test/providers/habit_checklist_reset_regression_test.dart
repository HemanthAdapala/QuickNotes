import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/models/folder.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/repositories/folders_repository.dart';
import 'package:quick_notes/repositories/notes_repository.dart';
import 'package:quick_notes/services/session_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory repository implementing [NotesRepository] for testing habit reset persistence.
class FakeNotesRepository implements NotesRepository {
  final Map<String, Note> storage = {};

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
  }) async {
    return storage.values
        .where((n) => n.isDeleted == isDeleted)
        .map((n) => n.toMap())
        .toList();
  }

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

/// Fake FoldersRepository stub for NotesProvider initialization.
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

  group('BUG-NEW-001 — Habit Checklist Markdown Reset Regression Tests', () {
    late FakeNotesRepository fakeNotesRepository;
    late FakeFoldersRepository fakeFoldersRepository;
    late NotesProvider notesProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'active_user_id': 'canonical-user-001',
      });
      await SessionManager().init();

      fakeNotesRepository = FakeNotesRepository();
      fakeFoldersRepository = FakeFoldersRepository();
    });

    tearDown(() {
      notesProvider.dispose();
    });

    test(
        'TDD REGRESSION: Habit reset on Markdown checklist preserves items, ordering, and resets checkboxes without "[]" corruption',
        () async {
      // 1. Arrange: Habit checklist note in real SDE Markdown format
      const originalMarkdown =
          '- [ ] Task one\n- [x] Task two\n- [ ] Task three';

      final habitNote = Note(
        id: 'habit-checklist-note-001',
        userId: 'canonical-user-001',
        title: 'Morning Routine',
        content: originalMarkdown,
        noteType: 'checklist',
        isHabit: true,
        habitRecurrence: 'daily',
        habitStreak: 5,
        // Completed yesterday so today.isAfter(lastDay) triggers the reset logic
        habitLastCompleted:
            DateTime.now().subtract(const Duration(days: 1)),
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
        tags: const [],
        attachments: const [],
        colorValue: 0,
      );

      fakeNotesRepository.addNoteForTesting(habitNote);

      // 2. Act: Execute the real production path via NotesProvider.loadNotes()
      notesProvider = NotesProvider(
        notesRepository: fakeNotesRepository,
        foldersRepository: fakeFoldersRepository,
      );
      await notesProvider.loadNotes();

      // 3. Assert: Retrieve persisted note from repository
      final persistedNote =
          await fakeNotesRepository.getNoteById('habit-checklist-note-001');

      expect(persistedNote, isNotNull,
          reason: 'The habit note must exist in the repository.');

      // --- CATASTROPHIC DATA-LOSS PROTECTION ---
      expect(
        persistedNote!.content,
        isNot(equals('[]')),
        reason:
            'CRITICAL: Habit reset must NEVER overwrite valid Markdown checklist with empty JSON array "[]".',
      );

      // --- ITEM PRESERVATION ---
      expect(
        persistedNote.content,
        contains('Task one'),
        reason: 'Reset operation must preserve "Task one".',
      );
      expect(
        persistedNote.content,
        contains('Task two'),
        reason: 'Reset operation must preserve "Task two".',
      );
      expect(
        persistedNote.content,
        contains('Task three'),
        reason: 'Reset operation must preserve "Task three".',
      );

      // --- CHECKBOX RESET ---
      expect(
        persistedNote.content,
        isNot(contains('[x]')),
        reason:
            'All checked checklist items must be reset to unchecked ([ ]).',
      );

      // --- EXACT ORDER & FORMAT PRESERVATION ---
      const expectedResetMarkdown =
          '- [ ] Task one\n- [ ] Task two\n- [ ] Task three';
      expect(
        persistedNote.content.trim(),
        equals(expectedResetMarkdown),
        reason:
            'The persisted content must match the expected Markdown checklist structure with all tasks unchecked and order preserved.',
      );

      // --- HABIT STATE VERIFICATION ---
      // Since not all items were completed yesterday (Task one & three were unchecked),
      // streak resets to 0 according to production habit rules.
      expect(persistedNote.habitStreak, equals(0),
          reason: 'Streak should reset when incomplete.');
      expect(persistedNote.habitLastCompleted, isNotNull,
          reason: 'habitLastCompleted must be stamped with reset timestamp.');
    });

    test(
        'TDD REGRESSION: Habit reset on fully completed Markdown checklist increments streak and preserves all items',
        () async {
      // 1. Arrange: Fully completed Markdown checklist
      const originalMarkdown = '- [x] Task one\n- [x] Task two';

      final habitNote = Note(
        id: 'habit-checklist-note-002',
        userId: 'canonical-user-001',
        title: 'Evening Checklist',
        content: originalMarkdown,
        noteType: 'checklist',
        isHabit: true,
        habitRecurrence: 'daily',
        habitStreak: 2,
        habitLastCompleted:
            DateTime.now().subtract(const Duration(days: 1)),
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
        tags: const [],
        attachments: const [],
        colorValue: 0,
      );

      fakeNotesRepository.addNoteForTesting(habitNote);

      // 2. Act: Real production load path
      notesProvider = NotesProvider(
        notesRepository: fakeNotesRepository,
        foldersRepository: fakeFoldersRepository,
      );
      await notesProvider.loadNotes();

      // 3. Assert: Retrieve persisted note from repository
      final persistedNote =
          await fakeNotesRepository.getNoteById('habit-checklist-note-002');

      expect(persistedNote, isNotNull);

      // Must not be wiped to "[]"
      expect(
        persistedNote!.content,
        isNot(equals('[]')),
        reason:
            'CRITICAL: Fully completed checklist must not be corrupted to "[]".',
      );

      // Items must be preserved and reset to unchecked
      const expectedResetMarkdown = '- [ ] Task one\n- [ ] Task two';
      expect(
        persistedNote.content.trim(),
        equals(expectedResetMarkdown),
        reason:
            'Completed tasks must be reset to unchecked without content loss.',
      );

      // Streak should increment by 1 (2 -> 3)
      expect(persistedNote.habitStreak, equals(3),
          reason: 'Fully completed habit should increment streak on reset.');
    });
  });
}
