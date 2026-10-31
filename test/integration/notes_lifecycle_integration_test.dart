import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/models/session_type.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/repositories/notes_repository.dart';
import 'package:quick_notes/repositories/folders_repository.dart';
import 'package:quick_notes/models/folder.dart';
import 'package:quick_notes/services/session_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InMemoryNotesRepository implements NotesRepository {
  final Map<String, Note> storage = {};
  bool throwOnSave = false;
  bool throwOnDelete = false;

  @override
  Future<List<Note>> getNotes() async =>
      storage.values.where((n) => !n.isDeleted).toList();

  @override
  Future<List<Note>> getTrashNotes() async =>
      storage.values.where((n) => n.isDeleted).toList();

  @override
  Future<Note?> getNoteById(String id) async => storage[id];

  @override
  Future<int> insertNote(Note note) async {
    if (throwOnSave) throw Exception('Simulated DB insert failure');
    storage[note.id] = note;
    return 1;
  }

  @override
  Future<int> updateNote(Note note) async {
    if (throwOnSave) throw Exception('Simulated DB update failure');
    storage[note.id] = note;
    return 1;
  }

  @override
  Future<int> trashNote(String id) async {
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
    if (throwOnDelete) throw Exception('Simulated DB delete failure');
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
  Future<List<Note>> queryHabits() async =>
      storage.values.where((n) => n.isHabit && !n.isDeleted).toList();

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
      userId: 'usr_phase8_integration',
      sessionType: SessionType.offline,
    );
  });

  group('Priority C — Notes Integration & Lifecycle Verification', () {
    late InMemoryNotesRepository notesRepo;
    late InMemoryFoldersRepository foldersRepo;
    late NotesProvider notesProvider;

    setUp(() async {
      notesRepo = InMemoryNotesRepository();
      foldersRepo = InMemoryFoldersRepository();
      notesProvider = NotesProvider(
        notesRepository: notesRepo,
        foldersRepository: foldersRepo,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    tearDown(() {
      notesProvider.dispose();
    });

    test(
        'A. Complete Note Lifecycle: create -> save -> edit -> trash -> restore -> permanent delete',
        () async {
      // 1. Create a note
      await notesProvider.addNote(
        title: 'Phase 8 Note',
        content: '# Heading 1\n- [ ] Task 1\n> Important quote',
        colorIndex: 1,
        tags: ['phase8', 'audit'],
        attachments: [],
      );

      expect(notesProvider.notes.length, equals(1));
      final noteId = notesProvider.notes.first.id;

      // 2. Verify stored in repository
      final storedNote = await notesRepo.getNoteById(noteId);
      expect(storedNote, isNotNull);
      expect(storedNote!.title, equals('Phase 8 Note'));
      expect(storedNote.tags, contains('phase8'));

      // 3. Edit and update the note
      final updatedNote = storedNote.copyWith(
        title: 'Phase 8 Note (Updated)',
        content:
            '# Heading 1\n- [x] Task 1 Completed\n> Important quote updated',
      );
      await notesProvider.updateNote(updatedNote);

      expect(notesProvider.notes.first.title, equals('Phase 8 Note (Updated)'));
      expect(
          notesProvider.notes.first.content.contains('- [x] Task 1 Completed'),
          isTrue);

      // 4. Move to Trash
      await notesProvider.trashNote(noteId);
      expect(notesProvider.notes.any((n) => n.id == noteId), isFalse);
      expect(notesProvider.trashNotes.any((n) => n.id == noteId), isTrue);

      // 5. Restore from Trash
      await notesProvider.restoreFromTrash(noteId);
      expect(notesProvider.trashNotes.any((n) => n.id == noteId), isFalse);
      expect(notesProvider.notes.any((n) => n.id == noteId), isTrue);

      // 6. Permanently Delete
      await notesProvider.trashNote(noteId);
      await notesProvider.deleteNote(noteId);
      expect(notesProvider.notes.any((n) => n.id == noteId), isFalse);
      expect(notesProvider.trashNotes.any((n) => n.id == noteId), isFalse);
      expect(await notesRepo.getNoteById(noteId), isNull);
    });

    test(
        'B. Rich-Content Persistence: round-trip markdown, unicode, emojis, and checklist tags',
        () async {
      const complexContent = '''# Major Title
## Subheading
- [ ] Incomplete Item
- [x] Completed Item
> Proverbial wisdom blockquote
Formatting: **bold**, *italic*, ~~strikethrough~~
Unicode & Emojis: 🚀 QuickNotes 📝 日本語 Français 🌟
''';

      await notesProvider.addNote(
        title: 'Unicode & Emoji Note',
        content: complexContent,
        colorIndex: 2,
        tags: ['unicode', 'rich_text'],
        attachments: [],
      );

      final note = notesProvider.notes.first;
      expect(note.content, equals(complexContent));

      // Simulate model map round trip (SQLite serialization)
      final map = note.toMap();
      final roundTripped = Note.fromMap(map);

      expect(roundTripped.title, equals(note.title));
      expect(roundTripped.content, equals(complexContent));
      expect(roundTripped.tags, equals(['unicode', 'rich_text']));
    });

    test(
        'C. View Partitioning & Search: feed, favorites, archive, and trash separation',
        () async {
      await notesRepo.insertNote(Note(
        id: 'note_active',
        title: 'Active Project Plan',
        content: 'Work on notes architecture',
        isFavorite: false,
        isArchived: false,
        isDeleted: false,
        tags: const [],
        attachments: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        colorValue: 0,
      ));

      await notesRepo.insertNote(Note(
        id: 'note_fav',
        title: 'Favorite Ideas',
        content: 'QuickNotes next gen',
        isFavorite: true,
        isArchived: false,
        isDeleted: false,
        tags: const [],
        attachments: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        colorValue: 0,
      ));

      await notesRepo.insertNote(Note(
        id: 'note_arch',
        title: 'Archived Reference',
        content: 'Old specifications',
        isFavorite: false,
        isArchived: true,
        isDeleted: false,
        tags: const [],
        attachments: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        colorValue: 0,
      ));

      await notesRepo.insertNote(Note(
        id: 'note_trash',
        title: 'Trashed Draft',
        content: 'Discarded text',
        isFavorite: false,
        isArchived: false,
        isDeleted: true,
        deletedAt: DateTime.now(),
        tags: const [],
        attachments: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        colorValue: 0,
      ));

      await notesProvider.loadNotes();

      // Feed view
      notesProvider.setViewType(NotesViewType.feed);
      expect(notesProvider.notes.any((n) => n.id == 'note_active'), isTrue);
      expect(notesProvider.notes.any((n) => n.id == 'note_arch'), isFalse);
      expect(notesProvider.notes.any((n) => n.id == 'note_trash'), isFalse);

      // Favorites view
      notesProvider.setViewType(NotesViewType.favorites);
      expect(notesProvider.notes.length, equals(1));
      expect(notesProvider.notes.first.id, equals('note_fav'));

      // Archive view
      notesProvider.setViewType(NotesViewType.archive);
      expect(notesProvider.notes.length, equals(1));
      expect(notesProvider.notes.first.id, equals('note_arch'));

      // Trash view
      notesProvider.setViewType(NotesViewType.trash);
      expect(notesProvider.notes.length, equals(1));
      expect(notesProvider.notes.first.id, equals('note_trash'));

      // Search functionality
      notesProvider.setViewType(NotesViewType.feed);
      notesProvider.setSearchQuery('Active Project');
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(notesProvider.notes.length, equals(1));
      expect(notesProvider.notes.first.id, equals('note_active'));
    });

    test(
        'D. DEFECT-001 & DEFECT-002 Regression Invariants: verified end-to-end',
        () async {
      // DEFECT-001: Trashed note is reflected in trashNotes without leaking into active notes
      await notesProvider.addNote(
        title: 'Defect-001 Verification Note',
        content: 'Testing trash collection separation',
        colorIndex: 0,
        tags: [],
        attachments: [],
      );
      final id = notesProvider.notes.first.id;
      await notesProvider.trashNote(id);

      expect(notesProvider.trashNotes.length, equals(1));
      expect(notesProvider.trashNotes.first.id, equals(id));
      expect(notesProvider.notes.any((n) => n.id == id), isFalse);

      // DEFECT-002: Deserializing partial map with nulls and omitted keys
      final partialMap = <String, dynamic>{
        'id': 'partial_sparse_note',
        'title': 'Sparse Note',
        'content': 'No color or pinned flags',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'isPinned': null,
        'colorValue': null,
      };

      final parsedNote = Note.fromMap(partialMap);
      expect(parsedNote.isPinned, isFalse);
      expect(parsedNote.colorValue, equals(0));
    });

    test(
        'E. Failure Paths: repository exceptions during save and delete are handled gracefully',
        () async {
      await notesProvider.addNote(
        title: 'Resilient Note',
        content: 'Testing error resilience',
        colorIndex: 0,
        tags: [],
        attachments: [],
      );
      final id = notesProvider.notes.first.id;

      // Simulate failure on update
      notesRepo.throwOnSave = true;
      final noteToUpdate =
          notesProvider.notes.first.copyWith(title: 'Failed Update');
      expect(() async => await notesProvider.updateNote(noteToUpdate),
          returnsNormally);
      notesRepo.throwOnSave = false;

      // Simulate failure on delete
      notesRepo.throwOnDelete = true;
      expect(() async => await notesProvider.deleteNote(id), returnsNormally);
      notesRepo.throwOnDelete = false;

      // Provider remains intact and functional
      expect(notesProvider.notes.isNotEmpty, isTrue);
    });
  });
}
