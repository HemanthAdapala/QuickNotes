import 'package:sqflite/sqflite.dart';
import '../models/folder.dart';
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
    final scopedFolder = folder.copyWith(userId: uid, updatedAt: DateTime.now());
    return await _dbService.insertFolder(scopedFolder);
  }

  @override
  Future<int> updateFolder(Folder folder) async {
    final uid = _resolveActiveUserId();
    final scopedFolder = folder.copyWith(userId: uid, updatedAt: DateTime.now());
    return await _dbService.updateFolder(scopedFolder);
  }

  /// Arbitrary depth traversal to find all descendant folder IDs for a given parent
  Future<Set<String>> _getDescendantFolderIds(DatabaseExecutor executor, String uid, String parentId) async {
    final Set<String> result = {};
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

      final nowIso = DateTime.now().toIso8601String();
      final descendants = await _getDescendantFolderIds(executor, uid, id);
      final allFolderIds = {id, ...descendants};

      // 1. Trash target folder
      await executor.update(
        'folders',
        {
          'isDeleted': 1,
          'deletedAt': nowIso,
          'updatedAt': nowIso,
          'trashedByFolderId': null,
        },
        where: 'id = ? AND userId = ?',
        whereArgs: [id, uid],
      );

      // 2. Trash descendant subfolders
      for (final descId in descendants) {
        await executor.update(
          'folders',
          {
            'isDeleted': 1,
            'deletedAt': nowIso,
            'updatedAt': nowIso,
            'trashedByFolderId': id,
          },
          where: 'id = ? AND userId = ? AND isDeleted = 0',
          whereArgs: [descId, uid],
        );
      }

      // 3. Soft-delete active child notes for target & subfolders
      for (final fId in allFolderIds) {
        await executor.update(
          'notes',
          {
            'isDeleted': 1,
            'deletedAt': nowIso,
            'updatedAt': nowIso,
            'trashedByFolderId': id,
          },
          where: 'folderId = ? AND userId = ? AND isDeleted = 0',
          whereArgs: [fId, uid],
        );
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

      final nowIso = DateTime.now().toIso8601String();

      // 1. Restore target folder
      await executor.update(
        'folders',
        {
          'isDeleted': 0,
          'deletedAt': null,
          'trashedByFolderId': null,
          'updatedAt': nowIso,
        },
        where: 'id = ? AND userId = ?',
        whereArgs: [id, uid],
      );

      // 2. Restore descendant subfolders trashed BY target folder
      await executor.update(
        'folders',
        {
          'isDeleted': 0,
          'deletedAt': null,
          'trashedByFolderId': null,
          'updatedAt': nowIso,
        },
        where: 'trashedByFolderId = ? AND userId = ?',
        whereArgs: [id, uid],
      );

      // 3. Restore notes trashed BY target folder
      await executor.update(
        'notes',
        {
          'isDeleted': 0,
          'deletedAt': null,
          'trashedByFolderId': null,
          'updatedAt': nowIso,
        },
        where: 'trashedByFolderId = ? AND userId = ?',
        whereArgs: [id, uid],
      );

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
      final allFolderIds = {id, ...descendants};

      // Unlink or delete notes in these folders
      for (final fId in allFolderIds) {
        await executor.delete(
          'notes',
          where: 'folderId = ? AND userId = ?',
          whereArgs: [fId, uid],
        );
        await executor.delete(
          'folders',
          where: 'id = ? AND userId = ?',
          whereArgs: [fId, uid],
        );
      }
      return 1;
    });
  }
}
