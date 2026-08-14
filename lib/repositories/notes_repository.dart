import '../models/note.dart';
import '../services/database_service.dart';
import '../services/session_manager.dart';
import '../services/database_exceptions.dart';

abstract class NotesRepository {
  Future<List<Note>> getNotes();
  Future<List<Note>> getTrashNotes();
  Future<Note?> getNoteById(String id);
  Future<List<Map<String, dynamic>>> queryNotesSummaryPaged({
    String? folderId,
    String? category,
    bool? isFavorite,
    bool? isArchived,
    bool isDeleted = false,
    int limit = 20,
    int offset = 0,
  });
  Future<List<Note>> queryHabits();
  Future<List<Note>> searchNotes(String query);
  Future<int> insertNote(Note note);
  Future<int> updateNote(Note note);
  Future<int> togglePin(String id);
  Future<int> toggleFavorite(String id);
  Future<int> toggleArchive(String id);
  Future<int> trashNote(String id);
  Future<int> restoreNote(String id);
  Future<int> deleteNote(String id);
  Future<int> emptyTrash();
}

class SqliteNotesRepository implements NotesRepository {
  final DatabaseService _dbService;

  SqliteNotesRepository({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService.instance;

  String _resolveActiveUserId() {
    final activeId = SessionManager().activeUserId;
    if (activeId == null || activeId.isEmpty) {
      throw const OwnershipException('No active canonical user exists for this repository operation.');
    }
    return activeId;
  }

  @override
  Future<List<Note>> getNotes() async {
    final uid = _resolveActiveUserId();
    final all = await _dbService.queryAll();
    return all.where((n) => n.userId == uid && !n.isDeleted).toList();
  }

  @override
  Future<List<Note>> getTrashNotes() async {
    final uid = _resolveActiveUserId();
    final all = await _dbService.queryAll();
    return all.where((n) => n.userId == uid && n.isDeleted).toList();
  }

  @override
  Future<Note?> getNoteById(String id) async {
    final uid = _resolveActiveUserId();
    final note = await _dbService.queryById(id);
    if (note != null && note.userId != null && note.userId != uid) {
      throw OwnershipException('Ownership violation: User $uid cannot read note belonging to User ${note.userId}');
    }
    return (note != null && note.userId == uid) ? note : null;
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
    final uid = _resolveActiveUserId();
    return await _dbService.queryNotesSummaryPaged(
      userId: uid,
      folderId: folderId,
      category: category,
      isFavorite: isFavorite,
      isArchived: isArchived,
      isDeleted: isDeleted,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<List<Note>> queryHabits() async {
    final uid = _resolveActiveUserId();
    return await _dbService.queryHabits(userId: uid);
  }

  @override
  Future<List<Note>> searchNotes(String query) async {
    final uid = _resolveActiveUserId();
    final rawNotes = await _dbService.search(query);
    return rawNotes.where((n) => n.userId == uid && !n.isDeleted).toList();
  }

  @override
  Future<int> insertNote(Note note) async {
    final uid = _resolveActiveUserId();
    final scopedNote = Note(
      id: note.id,
      userId: uid,
      title: note.title,
      content: note.content,
      isPinned: note.isPinned,
      isFavorite: note.isFavorite,
      isArchived: note.isArchived,
      category: note.category,
      noteType: note.noteType,
      tags: note.tags,
      attachments: note.attachments,
      isLocked: note.isLocked,
      reminderTime: note.reminderTime,
      createdAt: note.createdAt,
      updatedAt: note.updatedAt,
      colorValue: note.colorValue,
      isDeleted: note.isDeleted,
      deletedAt: note.deletedAt,
      trashedByFolderId: note.trashedByFolderId,
      folderId: note.folderId,
      isHabit: note.isHabit,
      habitRecurrence: note.habitRecurrence,
      habitStreak: note.habitStreak,
      habitLastCompleted: note.habitLastCompleted,
      previewText: note.previewText,
      paperGuideType: note.paperGuideType,
      paperGuideVisible: note.paperGuideVisible,
      paperGuideHeight: note.paperGuideHeight,
      paperGuideOpacity: note.paperGuideOpacity,
      paperGuideColor: note.paperGuideColor,
    );
    return await _dbService.insert(scopedNote);
  }

  @override
  Future<int> updateNote(Note note) async {
    final uid = _resolveActiveUserId();
    final existing = await _dbService.queryById(note.id);
    if (existing != null && existing.userId != null && existing.userId != uid) {
      throw OwnershipException('Ownership violation: User $uid cannot update note belonging to User ${existing.userId}');
    }
    final scopedNote = Note(
      id: note.id,
      userId: uid,
      title: note.title,
      content: note.content,
      isPinned: note.isPinned,
      isFavorite: note.isFavorite,
      isArchived: note.isArchived,
      category: note.category,
      noteType: note.noteType,
      tags: note.tags,
      attachments: note.attachments,
      isLocked: note.isLocked,
      reminderTime: note.reminderTime,
      createdAt: note.createdAt,
      updatedAt: DateTime.now(),
      colorValue: note.colorValue,
      isDeleted: note.isDeleted,
      deletedAt: note.deletedAt,
      trashedByFolderId: note.trashedByFolderId,
      folderId: note.folderId,
      isHabit: note.isHabit,
      habitRecurrence: note.habitRecurrence,
      habitStreak: note.habitStreak,
      habitLastCompleted: note.habitLastCompleted,
      previewText: note.previewText,
      paperGuideType: note.paperGuideType,
      paperGuideVisible: note.paperGuideVisible,
      paperGuideHeight: note.paperGuideHeight,
      paperGuideOpacity: note.paperGuideOpacity,
      paperGuideColor: note.paperGuideColor,
    );
    return await _dbService.update(scopedNote);
  }

  @override
  Future<int> togglePin(String id) async {
    final uid = _resolveActiveUserId();
    final existing = await getNoteById(id);
    if (existing == null) return 0;

    final updatedNote = existing.copyWith(
      isPinned: !existing.isPinned,
      updatedAt: DateTime.now(),
    );
    return await _dbService.update(updatedNote);
  }

  @override
  Future<int> toggleFavorite(String id) async {
    final uid = _resolveActiveUserId();
    final existing = await getNoteById(id);
    if (existing == null) return 0;

    final updatedNote = existing.copyWith(
      isFavorite: !existing.isFavorite,
      updatedAt: DateTime.now(),
    );
    return await _dbService.update(updatedNote);
  }

  @override
  Future<int> toggleArchive(String id) async {
    final uid = _resolveActiveUserId();
    final existing = await getNoteById(id);
    if (existing == null) return 0;

    final updatedNote = existing.copyWith(
      isArchived: !existing.isArchived,
      updatedAt: DateTime.now(),
    );
    return await _dbService.update(updatedNote);
  }

  @override
  Future<int> trashNote(String id) async {
    final uid = _resolveActiveUserId();
    final existing = await _dbService.queryById(id);
    if (existing != null && existing.userId != null && existing.userId != uid) {
      throw OwnershipException('Ownership violation: User $uid cannot trash note belonging to User ${existing.userId}');
    }
    if (existing == null) return 0;
    if (existing.isDeleted) return 1; // Idempotent

    final trashedNote = existing.copyWith(
      isDeleted: true,
      deletedAt: DateTime.now(),
      updatedAt: DateTime.now(),
      clearTrashedByFolderId: true,
    );
    return await _dbService.update(trashedNote);
  }

  @override
  Future<int> restoreNote(String id) async {
    final uid = _resolveActiveUserId();
    final existing = await _dbService.queryById(id);
    if (existing != null && existing.userId != null && existing.userId != uid) {
      throw OwnershipException('Ownership violation: User $uid cannot restore note belonging to User ${existing.userId}');
    }
    if (existing == null) return 0;
    if (!existing.isDeleted) return 1; // Idempotent

    final restoredNote = existing.copyWith(
      isDeleted: false,
      clearDeletedAt: true,
      clearTrashedByFolderId: true,
      updatedAt: DateTime.now(),
    );
    return await _dbService.update(restoredNote);
  }

  @override
  Future<int> deleteNote(String id) async {
    final uid = _resolveActiveUserId();
    final existing = await _dbService.queryById(id);
    if (existing != null && existing.userId != null && existing.userId != uid) {
      throw OwnershipException('Ownership violation: User $uid cannot delete note belonging to User ${existing.userId}');
    }
    return await _dbService.delete(id);
  }

  @override
  Future<int> emptyTrash() async {
    final uid = _resolveActiveUserId();
    return await _dbService.runInTransaction((executor) async {
      final res = await executor.delete(
        'notes',
        where: 'userId = ? AND isDeleted = 1',
        whereArgs: [uid],
      );
      return res;
    });
  }
}
