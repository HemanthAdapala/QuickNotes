import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/models/folder.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/models/session_type.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/repositories/folders_repository.dart';
import 'package:quick_notes/repositories/notes_repository.dart';
import 'package:quick_notes/services/session_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InMemoryNotesRepository implements NotesRepository {
  final Map<String, Note> storage = {};
  bool throwOnGetNotes = false;
  bool throwOnInsert = false;
  bool throwOnUpdate = false;
  bool throwOnTrash = false;
  bool throwOnRestore = false;
  bool throwOnDelete = false;
  bool throwOnQueryPaged = false;

  @override
  Future<List<Note>> getNotes() async {
    if (throwOnGetNotes) throw Exception('Simulated getNotes error');
    return storage.values.where((n) => !n.isDeleted).toList();
  }

  @override
  Future<List<Note>> getTrashNotes() async =>
      storage.values.where((n) => n.isDeleted).toList();

  @override
  Future<Note?> getNoteById(String id) async => storage[id];

  @override
  Future<List<Note>> queryHabits() async =>
      storage.values.where((n) => n.isHabit && !n.isDeleted).toList();

  @override
  Future<int> insertNote(Note note) async {
    if (throwOnInsert) throw Exception('Simulated insert error');
    storage[note.id] = note;
    return 1;
  }

  @override
  Future<int> updateNote(Note note) async {
    if (throwOnUpdate) throw Exception('Simulated update error');
    storage[note.id] = note;
    return 1;
  }

  @override
  Future<int> trashNote(String id) async {
    if (throwOnTrash) throw Exception('Simulated trash error');
    final note = storage[id];
    if (note != null) {
      storage[id] = note.copyWith(
        isDeleted: true,
        deletedAt: DateTime.now(),
      );
      return 1;
    }
    return 0;
  }

  @override
  Future<int> restoreNote(String id) async {
    if (throwOnRestore) throw Exception('Simulated restore error');
    final note = storage[id];
    if (note != null) {
      storage[id] = note.copyWith(
        isDeleted: false,
        clearDeletedAt: true,
      );
      return 1;
    }
    return 0;
  }

  @override
  Future<int> deleteNote(String id) async {
    if (throwOnDelete) throw Exception('Simulated delete error');
    return storage.remove(id) != null ? 1 : 0;
  }

  @override
  Future<int> emptyTrash() async {
    final trashIds =
        storage.values.where((n) => n.isDeleted).map((n) => n.id).toList();
    for (final id in trashIds) {
      storage.remove(id);
    }
    return trashIds.length;
  }

  @override
  Future<int> togglePin(String id) async {
    final note = storage[id];
    if (note != null) {
      storage[id] = note.copyWith(isPinned: !note.isPinned);
      return 1;
    }
    return 0;
  }

  @override
  Future<int> toggleFavorite(String id) async {
    final note = storage[id];
    if (note != null) {
      storage[id] = note.copyWith(isFavorite: !note.isFavorite);
      return 1;
    }
    return 0;
  }

  @override
  Future<int> toggleArchive(String id) async {
    final note = storage[id];
    if (note != null) {
      storage[id] = note.copyWith(isArchived: !note.isArchived);
      return 1;
    }
    return 0;
  }

  @override
  Future<List<Note>> searchNotes(String query) async {
    final q = query.toLowerCase();
    return storage.values.where((n) {
      if (n.isDeleted) return false;
      return n.title.toLowerCase().contains(q) ||
          n.content.toLowerCase().contains(q) ||
          n.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
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
    if (throwOnQueryPaged) throw Exception('Simulated queryPaged error');
    var list = storage.values.where((n) => n.isDeleted == isDeleted).toList();
    if (folderId != null) {
      list = list.where((n) => n.folderId == folderId).toList();
    }
    if (category != null) {
      list = list.where((n) => n.category == category).toList();
    }
    if (isFavorite != null) {
      list = list.where((n) => n.isFavorite == isFavorite).toList();
    }
    if (isArchived != null) {
      list = list.where((n) => n.isArchived == isArchived).toList();
    }
    return list.skip(offset).take(limit).map((n) => n.toMap()).toList();
  }
}

class InMemoryFoldersRepository implements FoldersRepository {
  final Map<String, Folder> storage = {};

  @override
  Future<List<Folder>> getFolders() async => storage.values.toList();
  @override
  Future<List<Folder>> getTrashFolders() async => [];
  @override
  Future<int> insertFolder(Folder folder) async {
    storage[folder.id] = folder;
    return 1;
  }

  @override
  Future<int> updateFolder(Folder folder) async {
    storage[folder.id] = folder;
    return 1;
  }

  @override
  Future<int> trashFolder(String id) async => 1;
  @override
  Future<int> restoreFolder(String id) async => 1;
  @override
  Future<int> deleteFolder(String id) async {
    storage.remove(id);
    return 1;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => '.',
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter_local_notifications'),
      (MethodCall methodCall) async => true,
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

    SharedPreferences.setMockInitialValues({});
    final session = SessionManager();
    await session.init();
    await session.saveSession(
      userId: 'usr_provider_test',
      sessionType: SessionType.offline,
    );
  });

  group('NotesProvider State Management Unit Tests', () {
    late InMemoryNotesRepository notesRepo;
    late InMemoryFoldersRepository foldersRepo;
    late NotesProvider provider;

    setUp(() async {
      notesRepo = InMemoryNotesRepository();
      foldersRepo = InMemoryFoldersRepository();
      provider = NotesProvider(
        notesRepository: notesRepo,
        foldersRepository: foldersRepo,
      );
      // Wait for async init
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    tearDown(() {
      provider.dispose();
    });

    test('1. Initial state is populated and clean', () {
      expect(provider.notes, isEmpty);
      expect(provider.trashNotes, isEmpty);
      expect(provider.currentView, equals(NotesViewType.feed));
      expect(provider.currentSort, equals(SortOption.newest));
      expect(provider.selectedCategory, equals('All'));
      expect(provider.selectedTag, isEmpty);
      expect(provider.selectedFolderId, isNull);
    });

    test('2. addNote creates note and exposes it in feed', () async {
      await provider.addNote(
        title: 'Provider Test Note',
        content: 'Content in test note',
        colorIndex: 2,
        category: 'Work',
        tags: ['sprint', 'qa'],
        attachments: [],
      );

      expect(provider.notes.length, equals(1));
      final created = provider.notes.first;
      expect(created.title, equals('Provider Test Note'));
      expect(created.content, equals('Content in test note'));
      expect(created.category, equals('Work'));
      expect(created.tags, contains('sprint'));
      expect(created.isDeleted, isFalse);
    });

    test('3. updateNote modifies persisted note fields', () async {
      await provider.addNote(
        title: 'Original Title',
        content: 'Original Content',
        colorIndex: 0,
        tags: [],
        attachments: [],
      );
      final note = provider.notes.first;

      final updated = note.copyWith(
        title: 'Modified Title',
        content: 'Modified Content',
      );
      await provider.updateNote(updated);

      expect(provider.notes.length, equals(1));
      expect(provider.notes.first.title, equals('Modified Title'));
      expect(provider.notes.first.content, equals('Modified Content'));
    });

    test('4. Soft-delete (trashNote), restore, and emptyTrash flow', () async {
      await provider.addNote(
        title: 'Note to Trash',
        content: 'Trashing test',
        colorIndex: 0,
        tags: [],
        attachments: [],
      );
      final noteId = provider.notes.first.id;

      // Trash the note
      await provider.trashNote(noteId);
      expect(provider.notes, isEmpty); // Removed from active feed
      final trashedInRepo = await notesRepo.getTrashNotes();
      expect(trashedInRepo.length, equals(1)); // Present in trash repository
      expect(trashedInRepo.first.id, equals(noteId));
      expect(trashedInRepo.first.isDeleted, isTrue);

      // Restore from trash
      await provider.restoreFromTrash(noteId);
      expect(provider.notes.length, equals(1)); // Restored back in active feed
      expect(provider.notes.first.id, equals(noteId));
      expect(await notesRepo.getTrashNotes(), isEmpty);

      // Trash again and empty trash
      await provider.trashNote(noteId);
      expect(await notesRepo.getTrashNotes(), isNotEmpty);
      await provider.emptyTrash();
      expect(await notesRepo.getTrashNotes(), isEmpty);
      expect(provider.notes, isEmpty);
    });

    test(
        'DEFECT-001 REMEDIATED: NotesProvider.trashNotes getter accurately reflects trashed notes with strict active/trash separation',
        () async {
      await provider.addNote(
        title: 'Note for Defect-001',
        content: 'Demonstrating trashNotes consistency',
        colorIndex: 0,
        tags: [],
        attachments: [],
      );
      final noteId = provider.notes.first.id;

      // 1. Move note to trash
      await provider.trashNote(noteId);

      // In repository, note is trashed
      final repoTrashed = await notesRepo.getTrashNotes();
      expect(repoTrashed.length, equals(1));
      expect(repoTrashed.first.id, equals(noteId));

      // REMEDIATED: provider.trashNotes is populated and consistent with repository
      expect(provider.trashNotes.length, equals(1));
      expect(provider.trashNotes.first.id, equals(noteId));
      expect(provider.trashNotes.first.isDeleted, isTrue);

      // Strict separation: trashed note is NOT present in active notes
      expect(provider.notes.any((n) => n.id == noteId), isFalse);
      expect(provider.allActiveNotes.any((n) => n.id == noteId), isFalse);

      // 2. Restoring note moves it back to active and clears it from trashNotes
      await provider.restoreFromTrash(noteId);
      expect(provider.trashNotes, isEmpty);
      expect(provider.notes.length, equals(1));
      expect(provider.notes.first.id, equals(noteId));

      // 3. Re-trashing and permanently deleting cleans up both sources
      await provider.trashNote(noteId);
      expect(provider.trashNotes.length, equals(1));
      await provider.deleteNote(noteId);
      expect(provider.trashNotes, isEmpty);
      expect(provider.notes, isEmpty);
    });

    test('5. Status toggles: pin, favorite, and archive', () async {
      await provider.addNote(
        title: 'Status Test Note',
        content: 'Testing pin/fav/archive',
        colorIndex: 1,
        tags: [],
        attachments: [],
      );
      final noteId = provider.notes.first.id;

      // Toggle Pin
      expect(provider.notes.first.isPinned, isFalse);
      await provider.togglePin(noteId);
      expect(provider.notes.first.isPinned, isTrue);

      // Toggle Favorite
      expect(provider.notes.first.isFavorite, isFalse);
      await provider.toggleFavorite(noteId);
      expect(provider.notes.first.isFavorite, isTrue);

      // Toggle Archive
      expect(provider.notes.first.isArchived, isFalse);
      await provider.toggleArchive(noteId);
      // When archived, note disappears from active feed
      expect(provider.notes, isEmpty);

      // Switch view to archive
      provider.setViewType(NotesViewType.archive);
      expect(provider.notes.length, equals(1));
      expect(provider.notes.first.id, equals(noteId));
      expect(provider.notes.first.isArchived, isTrue);
    });

    test('6. View type filtering: feed, archive, favorites, and trash',
        () async {
      // 1. Regular active note
      await provider.addNote(
        title: 'Feed Note',
        content: 'Feed content',
        colorIndex: 0,
        tags: [],
        attachments: [],
      );
      // 2. Favorite note
      await provider.addNote(
        title: 'Fav Note',
        content: 'Fav content',
        colorIndex: 0,
        isFavorite: true,
        tags: [],
        attachments: [],
      );
      // 3. Archived note
      await provider.addNote(
        title: 'Archived Note',
        content: 'Archive content',
        colorIndex: 0,
        isArchived: true,
        tags: [],
        attachments: [],
      );

      // Default feed shows Feed Note and Fav Note (non-archived, non-deleted)
      provider.setViewType(NotesViewType.feed);
      expect(provider.notes.length, equals(2));

      // Favorites view shows only Fav Note
      provider.setViewType(NotesViewType.favorites);
      expect(provider.notes.length, equals(1));
      expect(provider.notes.first.title, equals('Fav Note'));

      // Archive view shows only Archived Note
      provider.setViewType(NotesViewType.archive);
      expect(provider.notes.length, equals(1));
      expect(provider.notes.first.title, equals('Archived Note'));
    });

    test('7. Folder, Category, and Tag filtering', () async {
      await provider.addNote(
        title: 'Work Note',
        content: 'Work stuff',
        colorIndex: 0,
        category: 'Work',
        folderId: 'folder_engineering',
        tags: ['dev', 'flutter'],
        attachments: [],
      );
      await provider.addNote(
        title: 'Personal Note',
        content: 'Personal stuff',
        colorIndex: 0,
        category: 'Personal',
        folderId: 'folder_home',
        tags: ['life'],
        attachments: [],
      );

      // Filter by folder
      provider.setSelectedFolder('folder_engineering');
      expect(provider.notes.length, equals(1));
      expect(provider.notes.first.title, equals('Work Note'));

      // Clear folder and filter by category
      provider.setSelectedFolder(null);
      provider.setSelectedCategory('Personal');
      expect(provider.notes.length, equals(1));
      expect(provider.notes.first.title, equals('Personal Note'));

      // Clear category and filter by tag
      provider.setSelectedCategory('All');
      provider.setSelectedTag('dev');
      expect(provider.notes.length, equals(1));
      expect(provider.notes.first.title, equals('Work Note'));
    });

    test('8. Sorting mechanics and pinned priority', () async {
      final t1 = DateTime.now().subtract(const Duration(hours: 3));
      final t2 = DateTime.now().subtract(const Duration(hours: 2));
      final t3 = DateTime.now().subtract(const Duration(hours: 1));

      // Add 3 notes with specific titles and update timestamps
      await notesRepo.insertNote(Note(
        id: 'n1',
        title: 'Charlie',
        content: 'Content C',
        tags: const [],
        attachments: const [],
        createdAt: t1,
        updatedAt: t1,
        colorValue: 0,
      ));
      await notesRepo.insertNote(Note(
        id: 'n2',
        title: 'Alice',
        content: 'Content A',
        isPinned: true, // Pinned!
        tags: const [],
        attachments: const [],
        createdAt: t2,
        updatedAt: t2,
        colorValue: 0,
      ));
      await notesRepo.insertNote(Note(
        id: 'n3',
        title: 'Bob',
        content: 'Content B',
        tags: const [],
        attachments: const [],
        createdAt: t3,
        updatedAt: t3,
        colorValue: 0,
      ));

      await provider.loadNotes();

      // Pinned note 'Alice' must ALWAYS be first, regardless of sort
      provider.setSortOption(SortOption.newest);
      expect(provider.notes.first.title, equals('Alice'));

      provider.setSortOption(SortOption.oldest);
      expect(provider.notes.first.title, equals('Alice'));
      // Unpinned notes follow oldest order: Charlie (t1) before Bob (t3)
      expect(provider.notes[1].title, equals('Charlie'));
      expect(provider.notes[2].title, equals('Bob'));

      provider.setSortOption(SortOption.alphabetical);
      expect(provider.notes.first.title, equals('Alice'));
      // Unpinned notes follow alphabetical order: Bob before Charlie
      expect(provider.notes[1].title, equals('Bob'));
      expect(provider.notes[2].title, equals('Charlie'));
    });

    test(
        '10. Paging operations: loadNotesPage, loadNextPage, and clearPageCache',
        () async {
      for (int i = 0; i < 25; i++) {
        await notesRepo.insertNote(Note(
          id: 'page_note_$i',
          title: 'Note $i',
          content: 'Content $i',
          tags: const [],
          attachments: const [],
          createdAt: DateTime.now().subtract(Duration(minutes: i)),
          updatedAt: DateTime.now().subtract(Duration(minutes: i)),
          colorValue: 0,
        ));
      }

      await provider.loadNotesPage(refresh: true);
      expect(provider.notesSummary.length, equals(20)); // Limit is 20 per page
      expect(provider.hasMoreNotes, isTrue);

      await provider.loadNextPage();
      expect(provider.notesSummary.length, equals(25)); // 20 + 5 remaining
      expect(provider.hasMoreNotes, isFalse);

      provider.clearPageCache();
      expect(provider.notesSummary, isEmpty);
    });

    test('11. Habit checklist reset engine resets daily habits on loadNotes',
        () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 2));
      final habitNote = Note(
        id: 'habit_1',
        title: 'Morning Routine',
        content: '- [x] 10 min Meditation\n- [x] 20 Pushups',
        tags: const [],
        attachments: const [],
        noteType: 'checklist',
        isHabit: true,
        habitRecurrence: 'daily',
        habitStreak: 3,
        habitLastCompleted: yesterday,
        createdAt: yesterday,
        updatedAt: yesterday,
        colorValue: 0,
      );
      await notesRepo.insertNote(habitNote);

      await provider.loadNotes();

      final updatedHabit = await notesRepo.getNoteById('habit_1');
      expect(updatedHabit, isNotNull);
      // Items should be reset to unchecked
      expect(updatedHabit!.content.contains('- [ ]'), isTrue);
      expect(updatedHabit.content.contains('- [x]'), isFalse);
      // Streak should increment because all items were completed
      expect(updatedHabit.habitStreak, equals(4));
    });

    test(
        '12. Multi-note trash, restore, and permanent deletion state lifecycle',
        () async {
      await provider.addNote(
        title: 'Note To Trash',
        content: 'Content 1',
        colorIndex: 0,
        tags: [],
        attachments: [],
      );
      await provider.addNote(
        title: 'Note To Keep',
        content: 'Content 2',
        colorIndex: 0,
        tags: [],
        attachments: [],
      );
      expect(provider.notes.length, equals(2));

      final trashId =
          provider.notes.firstWhere((n) => n.title == 'Note To Trash').id;
      final keepId =
          provider.notes.firstWhere((n) => n.title == 'Note To Keep').id;

      // Move to trash
      await provider.trashNote(trashId);
      expect(provider.notes.length, equals(1));
      expect(provider.notes.first.id, equals(keepId));

      // Restore from trash
      await provider.restoreFromTrash(trashId);
      expect(provider.notes.length, equals(2));

      // Permanently delete
      await provider.deleteNote(trashId);
      expect(provider.notes.length, equals(1));
      expect(await notesRepo.getNoteById(trashId), isNull);
    });

    test(
        '13. Repository failure resilience during trash, restore, and delete operations',
        () async {
      await provider.addNote(
        title: 'Resilience Test Note',
        content: 'Content',
        colorIndex: 0,
        tags: [],
        attachments: [],
      );
      final noteId = provider.notes.first.id;

      // Simulate trash failure
      notesRepo.throwOnTrash = true;
      expect(() async => await provider.trashNote(noteId), returnsNormally);
      notesRepo.throwOnTrash = false;

      // Simulate restore failure
      notesRepo.throwOnRestore = true;
      expect(
          () async => await provider.restoreFromTrash(noteId), returnsNormally);
      notesRepo.throwOnRestore = false;

      // Simulate delete failure
      notesRepo.throwOnDelete = true;
      expect(() async => await provider.deleteNote(noteId), returnsNormally);
      notesRepo.throwOnDelete = false;

      // Provider remains fully functional
      expect(provider.notes.isNotEmpty, isTrue);
    });

    test(
        '14. Pagination: empty initial result set sets hasMoreNotes to false without throwing',
        () async {
      provider.clearPageCache();
      expect(provider.notesSummary, isEmpty);

      await provider.loadNotesPage(refresh: true);
      expect(provider.notesSummary, isEmpty);
      expect(provider.hasMoreNotes, isFalse);
      expect(provider.isPageLoading, isFalse);
    });

    test(
        '15. Pagination: filtered paging by folderId partitions paged results deterministically',
        () async {
      const folderAlpha = 'folder_alpha';
      const folderBeta = 'folder_beta';

      for (int i = 0; i < 5; i++) {
        await notesRepo.insertNote(Note(
          id: 'alpha_$i',
          title: 'Alpha Note $i',
          content: 'Alpha content',
          folderId: folderAlpha,
          tags: const [],
          attachments: const [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          colorValue: 0,
        ));
      }
      for (int i = 0; i < 3; i++) {
        await notesRepo.insertNote(Note(
          id: 'beta_$i',
          title: 'Beta Note $i',
          content: 'Beta content',
          folderId: folderBeta,
          tags: const [],
          attachments: const [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          colorValue: 0,
        ));
      }

      // Filter by folderAlpha
      provider.setSelectedFolder(folderAlpha);
      await provider.loadNotesPage(refresh: true);

      expect(provider.notesSummary.length, equals(5));
      expect(provider.notesSummary.every((s) => s.folderId == folderAlpha),
          isTrue);

      // Switch to folderBeta
      provider.setSelectedFolder(folderBeta);
      await provider.loadNotesPage(refresh: true);

      expect(provider.notesSummary.length, equals(3));
      expect(
          provider.notesSummary.every((s) => s.folderId == folderBeta), isTrue);
    });

    test(
        '16. Pagination: repository failure during page loading safely resets isPageLoading and preserves existing summaries',
        () async {
      for (int i = 0; i < 25; i++) {
        await notesRepo.insertNote(Note(
          id: 'summary_$i',
          title: 'Summary $i',
          content: 'Content',
          tags: const [],
          attachments: const [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          colorValue: 0,
        ));
      }

      // Load first page successfully (20 items)
      await provider.loadNotesPage(refresh: true);
      expect(provider.notesSummary.length, equals(20));
      expect(provider.hasMoreNotes, isTrue);

      // Simulate failure on loading next page
      notesRepo.throwOnQueryPaged = true;
      await provider.loadNextPage();

      // Error caught: isPageLoading is false, existing 20 summaries preserved
      expect(provider.isPageLoading, isFalse);
      expect(provider.notesSummary.length, equals(20));
    });
  });
}
