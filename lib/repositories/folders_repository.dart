import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/folder.dart';
import '../models/note.dart';
import '../models/sync_outbox_item.dart';
import '../services/database_service.dart';
import '../services/session_manager.dart';
import '../services/database_exceptions.dart';

abstract class FoldersRepository {
  Future<List<Folder>> getFolders();
  Future<List<Folder>> getTrashFolders();
  Future<int> insertFolder(Folder folder);
  Future<int> updateFolder(Folder folder);
  Future<int> trashFolder(String id);
  Future<int> restoreFolder(String id);
  Future<int> deleteFolder(String id);
}

class SqliteFoldersRepository implements FoldersRepository {
  final DatabaseService _dbService;

  SqliteFoldersRepository({DatabaseService? dbService})
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
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payloadMap,
    required int localVersion,
  }) async {
    final outboxItem = SyncOutboxItem(
      id: const Uuid().v4(),
      operationId: const Uuid().v4(),
      userId: userId,
      entityType: entityType,
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
  Future<List<Folder>> getFolders() async {
    final uid = _resolveActiveUserId();
    final all = await _dbService.queryAllFolders();
    return all.where((f) => f.userId == uid && !f.isDeleted).toList();
  }

  @override
  Future<List<Folder>> getTrashFolders() async {
    final uid = _resolveActiveUserId();
    final all = await _dbService.queryAllFolders();
    return all.where((f) => f.userId == uid && f.isDeleted).toList();
  }

  @override
  Future<int> insertFolder(Folder folder) async {
    final uid = _resolveActiveUserId();
    return await _dbService.runInTransaction((executor) async {
      final now = DateTime.now();
      final scopedFolder = folder.copyWith(
        userId: uid,
        updatedAt: now,
        version: 1,
      );
      await executor.insert(
        'folders',
        scopedFolder.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _recordOutboxEvent(
        executor,
        userId: uid,
        entityType: 'folder',
        entityId: scopedFolder.id,
        operation: 'create',
        payloadMap: scopedFolder.toMap(),
        localVersion: 1,
      );
      return 1;
    });
  }

  @override
  Future<int> updateFolder(Folder folder) async {
    final uid = _resolveActiveUserId();
    return await _dbService.runInTransaction((executor) async {
      final existingMap = await executor.query(
        'folders',
        where: 'id = ?',
        whereArgs: [folder.id],
      );
      if (existingMap.isNotEmpty) {
        final ownerId = existingMap.first['userId'] as String?;
        if (ownerId != null && ownerId != uid) {
          throw OwnershipException('Ownership violation: User $uid cannot update folder belonging to User $ownerId');
        }
      }
      final currentVersion = existingMap.isNotEmpty ? (existingMap.first['version'] as int? ?? 1) : 1;
      final newVersion = currentVersion + 1;
      final now = DateTime.now();

      final scopedFolder = folder.copyWith(
        userId: uid,
        updatedAt: now,
        version: newVersion,
      );
      final count = await executor.update(
        'folders',
        scopedFolder.toMap(),
        where: 'id = ? AND userId = ?',
        whereArgs: [folder.id, uid],
      );
      if (count > 0) {
        await _recordOutboxEvent(
          executor,
          userId: uid,
          entityType: 'folder',
          entityId: scopedFolder.id,
          operation: 'update',
          payloadMap: scopedFolder.toMap(),
          localVersion: newVersion,
        );
      }
      return count;
    });
  }

  /// Arbitrary depth traversal to find all descendant folder IDs for a given parent
  Future<List<String>> _getDescendantFolderIds(DatabaseExecutor executor, String uid, String parentId) async {
    final List<String> result = [];
    final List<String> queue = [parentId];

    while (queue.isNotEmpty) {
      final currentId = queue.removeAt(0);
      final children = await executor.query(
        'folders',
        columns: ['id'],
        where: 'userId = ? AND parentId = ?',
        whereArgs: [uid, currentId],
      );
      for (final child in children) {
        final childId = child['id'] as String;
        if (!result.contains(childId)) {
          result.add(childId);
          queue.add(childId);
        }
      }
    }
    return result;
  }

  @override
  Future<int> trashFolder(String id) async {
    final uid = _resolveActiveUserId();
    return await _dbService.runInTransaction((executor) async {
      final existing = await executor.query(
        'folders',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (existing.isEmpty) return 0;
      final folderMap = existing.first;
      final ownerId = folderMap['userId'] as String?;
      if (ownerId != null && ownerId != uid) {
        throw OwnershipException('Ownership violation: User $uid cannot trash folder belonging to User $ownerId');
      }

      final isAlreadyDeleted = (folderMap['isDeleted'] as int? ?? 0) == 1;
      if (isAlreadyDeleted) return 1; // Idempotent

      final now = DateTime.now();
      final descendants = await _getDescendantFolderIds(executor, uid, id);
      final allFolderIds = [id, ...descendants];

      // 1. Trash target folder & descendant subfolders topologically
      for (final fId in allFolderIds) {
        final fMaps = await executor.query(
          'folders',
          where: 'id = ? AND userId = ?',
          whereArgs: [fId, uid],
        );
        if (fMaps.isEmpty) continue;
        final fObj = Folder.fromMap(fMaps.first);
        if (fId != id && fObj.isDeleted) continue; // Skip independently deleted subfolders

        final newVersion = fObj.version + 1;
        final trashedFolder = fObj.copyWith(
          isDeleted: true,
          deletedAt: now,
          updatedAt: now,
          trashedByFolderId: fId == id ? null : id,
          version: newVersion,
        );
        await executor.update(
          'folders',
          trashedFolder.toMap(),
          where: 'id = ? AND userId = ?',
          whereArgs: [fId, uid],
        );
        await _recordOutboxEvent(
          executor,
          userId: uid,
          entityType: 'folder',
          entityId: fId,
          operation: 'update',
          payloadMap: trashedFolder.toMap(),
          localVersion: newVersion,
        );
      }

      // 2. Soft-delete active child notes for target & subfolders
      for (final fId in allFolderIds) {
        final nMaps = await executor.query(
          'notes',
          where: 'folderId = ? AND userId = ? AND isDeleted = 0',
          whereArgs: [fId, uid],
        );
        for (final nMap in nMaps) {
          final note = Note.fromMap(nMap);
          final newVersion = note.version + 1;
          final trashedNote = note.copyWith(
            isDeleted: true,
            deletedAt: now,
            updatedAt: now,
            trashedByFolderId: id,
            version: newVersion,
          );
          await executor.update(
            'notes',
            trashedNote.toMap(),
            where: 'id = ? AND userId = ?',
            whereArgs: [note.id, uid],
          );
          await _recordOutboxEvent(
            executor,
            userId: uid,
            entityType: 'note',
            entityId: note.id,
            operation: 'update',
            payloadMap: trashedNote.toMap(),
            localVersion: newVersion,
          );
        }
      }

      return 1;
    });
  }

  @override
  Future<int> restoreFolder(String id) async {
    final uid = _resolveActiveUserId();
    return await _dbService.runInTransaction((executor) async {
      final existing = await executor.query(
        'folders',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (existing.isEmpty) return 0;
      final folderMap = existing.first;
      final ownerId = folderMap['userId'] as String?;
      if (ownerId != null && ownerId != uid) {
        throw OwnershipException('Ownership violation: User $uid cannot restore folder belonging to User $ownerId');
      }

      final isAlreadyDeleted = (folderMap['isDeleted'] as int? ?? 0) == 1;
      if (!isAlreadyDeleted) return 1; // Idempotent

      final now = DateTime.now();

      // 1. Restore target folder
      final targetFolder = Folder.fromMap(folderMap);
      final targetVersion = targetFolder.version + 1;
      final restoredTarget = targetFolder.copyWith(
        isDeleted: false,
        clearDeletedAt: true,
        clearTrashedByFolderId: true,
        updatedAt: now,
        version: targetVersion,
      );
      await executor.update(
        'folders',
        restoredTarget.toMap(),
        where: 'id = ? AND userId = ?',
        whereArgs: [id, uid],
      );
      await _recordOutboxEvent(
        executor,
        userId: uid,
        entityType: 'folder',
        entityId: id,
        operation: 'update',
        payloadMap: restoredTarget.toMap(),
        localVersion: targetVersion,
      );

      // 2. Restore descendant subfolders trashed BY target folder
      final subfolderMaps = await executor.query(
        'folders',
        where: 'trashedByFolderId = ? AND userId = ?',
        whereArgs: [id, uid],
      );
      for (final sMap in subfolderMaps) {
        final subfolder = Folder.fromMap(sMap);
        final newVersion = subfolder.version + 1;
        final restoredSub = subfolder.copyWith(
          isDeleted: false,
          clearDeletedAt: true,
          clearTrashedByFolderId: true,
          updatedAt: now,
          version: newVersion,
        );
        await executor.update(
          'folders',
          restoredSub.toMap(),
          where: 'id = ? AND userId = ?',
          whereArgs: [subfolder.id, uid],
        );
        await _recordOutboxEvent(
          executor,
          userId: uid,
          entityType: 'folder',
          entityId: subfolder.id,
          operation: 'update',
          payloadMap: restoredSub.toMap(),
          localVersion: newVersion,
        );
      }

      // 3. Restore notes trashed BY target folder
      final noteMaps = await executor.query(
        'notes',
        where: 'trashedByFolderId = ? AND userId = ?',
        whereArgs: [id, uid],
      );
      for (final nMap in noteMaps) {
        final note = Note.fromMap(nMap);
        final newVersion = note.version + 1;
        final restoredNote = note.copyWith(
          isDeleted: false,
          clearDeletedAt: true,
          clearTrashedByFolderId: true,
          updatedAt: now,
          version: newVersion,
        );
        await executor.update(
          'notes',
          restoredNote.toMap(),
          where: 'id = ? AND userId = ?',
          whereArgs: [note.id, uid],
        );
        await _recordOutboxEvent(
          executor,
          userId: uid,
          entityType: 'note',
          entityId: note.id,
          operation: 'update',
          payloadMap: restoredNote.toMap(),
          localVersion: newVersion,
        );
      }

      return 1;
    });
  }

  @override
  Future<int> deleteFolder(String id) async {
    final uid = _resolveActiveUserId();
    return await _dbService.runInTransaction((executor) async {
      final existing = await executor.query(
        'folders',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (existing.isEmpty) return 0;
      final folderMap = existing.first;
      final ownerId = folderMap['userId'] as String?;
      if (ownerId != null && ownerId != uid) {
        throw OwnershipException('Ownership violation: User $uid cannot delete folder belonging to User $ownerId');
      }

      final descendants = await _getDescendantFolderIds(executor, uid, id);
      final allFolderIds = [id, ...descendants];

      // Delete notes in these folders
      for (final fId in allFolderIds) {
        final noteMaps = await executor.query(
          'notes',
          where: 'folderId = ? AND userId = ?',
          whereArgs: [fId, uid],
        );
        for (final nMap in noteMaps) {
          final note = Note.fromMap(nMap);
          await executor.delete(
            'notes',
            where: 'id = ? AND userId = ?',
            whereArgs: [note.id, uid],
          );
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
              entityType: 'note',
              entityId: note.id,
              operation: 'delete',
              payloadMap: {'id': note.id, 'version': note.version},
              localVersion: note.version,
            );
          }
        }

        // Delete folder
        final fMaps = await executor.query(
          'folders',
          where: 'id = ? AND userId = ?',
          whereArgs: [fId, uid],
        );
        if (fMaps.isNotEmpty) {
          final folder = Folder.fromMap(fMaps.first);
          await executor.delete(
            'folders',
            where: 'id = ? AND userId = ?',
            whereArgs: [fId, uid],
          );
          if (folder.lastSyncedVersion == 0) {
            await executor.delete(
              'sync_outbox',
              where: 'entityId = ? AND userId = ?',
              whereArgs: [fId, uid],
            );
          } else {
            await _recordOutboxEvent(
              executor,
              userId: uid,
              entityType: 'folder',
              entityId: fId,
              operation: 'delete',
              payloadMap: {'id': fId, 'version': folder.version},
              localVersion: folder.version,
            );
          }
        }
      }
      return 1;
    });
  }
}

