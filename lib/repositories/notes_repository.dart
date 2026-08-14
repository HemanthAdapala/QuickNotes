import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';
import '../models/sync_outbox_item.dart';
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

  Future<void> _recordOutboxEvent(
    DatabaseExecutor executor, {
    required String userId,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payloadMap,
    required int localVersion,
  }) async {
    final outboxItem = SyncOutboxItem(
      id: const Uuid().v4(),
      operationId: const Uuid().v4(),
      userId: userId,
      entityType: 'note',
      entityId: entityId,
      operation: operation,
      payload: jsonEncode(payloadMap),
      localVersion: localVersion,
      createdAt: DateTime.now(),
    );
    await executor.insert(
      'sync_outbox',
      outboxItem.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
    return await _dbService.runInTransaction((executor) async {
      final now = DateTime.now();
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
        updatedAt: now,
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
        version: 1,
        lastSyncedVersion: note.lastSyncedVersion,
      );
      await executor.insert(
        'notes',
        scopedNote.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _recordOutboxEvent(
        executor,
        userId: uid,
        entityId: scopedNote.id,
        operation: 'create',
        payloadMap: scopedNote.toMap(),
        localVersion: 1,
      );
      return 1;
    });
  }

  @override
  Future<int> updateNote(Note note) async {
    final uid = _resolveActiveUserId();
    return await _dbService.runInTransaction((executor) async {
      final existingMap = await executor.query(
        'notes',
        where: 'id = ?',
        whereArgs: [note.id],
      );
      if (existingMap.isNotEmpty) {
        final ownerId = existingMap.first['userId'] as String?;
        if (ownerId != null && ownerId != uid) {
          throw OwnershipException('Ownership violation: User $uid cannot update note belonging to User $ownerId');
        }
      }
      final currentVersion = existingMap.isNotEmpty ? (existingMap.first['version'] as int? ?? 1) : 1;
      final newVersion = currentVersion + 1;
      final now = DateTime.now();

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
        updatedAt: now,
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
        version: newVersion,
        lastSyncedVersion: note.lastSyncedVersion,
      );
      final count = await executor.update(
        'notes',
        scopedNote.toMap(),
        where: 'id = ? AND userId = ?',
        whereArgs: [note.id, uid],
      );
      if (count > 0) {
        await _recordOutboxEvent(
          executor,
          userId: uid,
          entityId: scopedNote.id,
          operation: 'update',
          payloadMap: scopedNote.toMap(),
          localVersion: newVersion,
        );
      }
      return count;
    });
  }

  @override
  Future<int> togglePin(String id) async {
    final uid = _resolveActiveUserId();
    return await _dbService.runInTransaction((executor) async {
      final existingMap = await executor.query(
        'notes',
        where: 'id = ? AND userId = ?',
        whereArgs: [id, uid],
      );
      if (existingMap.isEmpty) return 0;
      final existing = Note.fromMap(existingMap.first);

      final newVersion = existing.version + 1;
      final updatedNote = existing.copyWith(
        isPinned: !existing.isPinned,
        updatedAt: DateTime.now(),
        version: newVersion,
      );
      await executor.update(
        'notes',
        updatedNote.toMap(),
        where: 'id = ? AND userId = ?',
        whereArgs: [id, uid],
      );
      await _recordOutboxEvent(
        executor,
        userId: uid,
        entityId: id,
        operation: 'update',
        payloadMap: updatedNote.toMap(),
        localVersion: newVersion,
      );
      return 1;
    });
  }

  @override
  Future<int> toggleFavorite(String id) async {
    final uid = _resolveActiveUserId();
    return await _dbService.runInTransaction((executor) async {
      final existingMap = await executor.query(
        'notes',
        where: 'id = ? AND userId = ?',
        whereArgs: [id, uid],
      );
      if (existingMap.isEmpty) return 0;
      final existing = Note.fromMap(existingMap.first);

      final newVersion = existing.version + 1;
      final updatedNote = existing.copyWith(
        isFavorite: !existing.isFavorite,
        updatedAt: DateTime.now(),
        version: newVersion,
      );
      await executor.update(
        'notes',
        updatedNote.toMap(),
        where: 'id = ? AND userId = ?',
        whereArgs: [id, uid],
      );
      await _recordOutboxEvent(
        executor,
        userId: uid,
        entityId: id,
        operation: 'update',
        payloadMap: updatedNote.toMap(),
        localVersion: newVersion,
      );
      return 1;
    });
  }

  @override
  Future<int> toggleArchive(String id) async {
    final uid = _resolveActiveUserId();
    return await _dbService.runInTransaction((executor) async {
      final existingMap = await executor.query(
        'notes',
        where: 'id = ? AND userId = ?',
        whereArgs: [id, uid],
      );
      if (existingMap.isEmpty) return 0;
      final existing = Note.fromMap(existingMap.first);

      final newVersion = existing.version + 1;
      final updatedNote = existing.copyWith(
        isArchived: !existing.isArchived,
        updatedAt: DateTime.now(),
        version: newVersion,
      );
      await executor.update(
        'notes',
        updatedNote.toMap(),
        where: 'id = ? AND userId = ?',
        whereArgs: [id, uid],
      );
      await _recordOutboxEvent(
        executor,
        userId: uid,
        entityId: id,
        operation: 'update',
        payloadMap: updatedNote.toMap(),
        localVersion: newVersion,
      );
      return 1;
    });
  }

  @override
  Future<int> trashNote(String id) async {
    final uid = _resolveActiveUserId();
    return await _dbService.runInTransaction((executor) async {
      final existingMap = await executor.query(
        'notes',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (existingMap.isEmpty) return 0;
      final ownerId = existingMap.first['userId'] as String?;
      if (ownerId != null && ownerId != uid) {
        throw OwnershipException('Ownership violation: User $uid cannot trash note belonging to User $ownerId');
      }
      final existing = Note.fromMap(existingMap.first);
      if (existing.isDeleted) return 1; // Idempotent

      final newVersion = existing.version + 1;
      final trashedNote = existing.copyWith(
        isDeleted: true,
        deletedAt: DateTime.now(),
        updatedAt: DateTime.now(),
        clearTrashedByFolderId: true,
        version: newVersion,
      );
      await executor.update(
        'notes',
        trashedNote.toMap(),
        where: 'id = ? AND userId = ?',
        whereArgs: [id, uid],
      );
      await _recordOutboxEvent(
        executor,
        userId: uid,
        entityId: id,
        operation: 'update',
        payloadMap: trashedNote.toMap(),
        localVersion: newVersion,
      );
      return 1;
    });
  }

  @override
  Future<int> restoreNote(String id) async {
    final uid = _resolveActiveUserId();
    return await _dbService.runInTransaction((executor) async {
      final existingMap = await executor.query(
        'notes',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (existingMap.isEmpty) return 0;
      final ownerId = existingMap.first['userId'] as String?;
      if (ownerId != null && ownerId != uid) {
        throw OwnershipException('Ownership violation: User $uid cannot restore note belonging to User $ownerId');
      }
      final existing = Note.fromMap(existingMap.first);
      if (!existing.isDeleted) return 1; // Idempotent

      final newVersion = existing.version + 1;
      final restoredNote = existing.copyWith(
        isDeleted: false,
        clearDeletedAt: true,
        clearTrashedByFolderId: true,
        updatedAt: DateTime.now(),
        version: newVersion,
      );
      await executor.update(
        'notes',
        restoredNote.toMap(),
        where: 'id = ? AND userId = ?',
        whereArgs: [id, uid],
      );
      await _recordOutboxEvent(
        executor,
        userId: uid,
        entityId: id,
        operation: 'update',
        payloadMap: restoredNote.toMap(),
        localVersion: newVersion,
      );
      return 1;
    });
  }

  @override
  Future<int> deleteNote(String id) async {
    final uid = _resolveActiveUserId();
    return await _dbService.runInTransaction((executor) async {
      final existingMap = await executor.query(
        'notes',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (existingMap.isEmpty) return 0;
      final ownerId = existingMap.first['userId'] as String?;
      if (ownerId != null && ownerId != uid) {
        throw OwnershipException('Ownership violation: User $uid cannot delete note belonging to User $ownerId');
      }
      final existing = Note.fromMap(existingMap.first);

      final count = await executor.delete(
        'notes',
        where: 'id = ? AND userId = ?',
        whereArgs: [id, uid],
      );

      // Hard Delete Rule
      if (existing.lastSyncedVersion == 0) {
        // Silent purge: Delete pending outbox items for entityId
        await executor.delete(
          'sync_outbox',
          where: 'entityId = ? AND userId = ?',
          whereArgs: [id, uid],
        );
      } else {
        // Previously synced: Record DELETE outbox event
        await _recordOutboxEvent(
          executor,
          userId: uid,
          entityId: id,
          operation: 'delete',
          payloadMap: {'id': id, 'version': existing.version},
          localVersion: existing.version,
        );
      }
      return count;
    });
  }

  @override
  Future<int> emptyTrash() async {
    final uid = _resolveActiveUserId();
    return await _dbService.runInTransaction((executor) async {
      final trashedNotesMaps = await executor.query(
        'notes',
        where: 'userId = ? AND isDeleted = 1',
        whereArgs: [uid],
      );
      final trashedNotes = trashedNotesMaps.map((m) => Note.fromMap(m)).toList();

      final res = await executor.delete(
        'notes',
        where: 'userId = ? AND isDeleted = 1',
        whereArgs: [uid],
      );

      for (final note in trashedNotes) {
        if (note.lastSyncedVersion == 0) {
          await executor.delete(
            'sync_outbox',
            where: 'entityId = ? AND userId = ?',
            whereArgs: [note.id, uid],
          );
        } else {
          await _recordOutboxEvent(
            executor,
            userId: uid,
            entityId: note.id,
            operation: 'delete',
            payloadMap: {'id': note.id, 'version': note.version},
            localVersion: note.version,
          );
        }
      }
      return res;
    });
  }
}
