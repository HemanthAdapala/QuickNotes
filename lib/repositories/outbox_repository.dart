import 'package:sqflite/sqflite.dart';
import '../models/sync_outbox_item.dart';
import '../services/database_service.dart';
import '../services/session_manager.dart';
import '../services/database_exceptions.dart';

abstract class OutboxRepository {
  Future<int> insertOutboxItem(DatabaseExecutor executor, SyncOutboxItem item);
  Future<List<SyncOutboxItem>> getPendingOutboxItems(String userId);
  Future<int> markOutboxItemSynced(String id, int syncedVersion);
  Future<int> deleteOutboxItemsForEntity(DatabaseExecutor executor, String entityId);
  Future<void> acknowledgeOutboxItem({
    required String outboxId,
    required String entityType,
    required String entityId,
    required int localVersion,
  });
  Future<int> updateOutboxItemRetryStatus({
    required String id,
    required int attemptCount,
    required String status,
    DateTime? lastAttemptAt,
    DateTime? nextAttemptAt,
    String? lastError,
  });
}

class SqliteOutboxRepository implements OutboxRepository {
  final DatabaseService _dbService;

  SqliteOutboxRepository({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService.instance;

  String _resolveActiveUserId() {
    final activeId = SessionManager().activeUserId;
    if (activeId == null || activeId.isEmpty) {
      throw const OwnershipException('No active canonical user exists for this repository operation.');
    }
    return activeId;
  }

  String? _resolveTableName(String entityType) {
    switch (entityType) {
      case 'note':
        return 'notes';
      case 'folder':
        return 'folders';
      case 'task':
        return 'tasks';
      default:
        return null;
    }
  }

  @override
  Future<int> insertOutboxItem(DatabaseExecutor executor, SyncOutboxItem item) async {
    final uid = _resolveActiveUserId();
    if (item.userId != uid) {
      throw OwnershipException('Ownership violation: Cannot queue outbox item for user ${item.userId} under active user $uid');
    }
    return await executor.insert(
      'sync_outbox',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<SyncOutboxItem>> getPendingOutboxItems(String userId) async {
    final uid = _resolveActiveUserId();
    if (userId != uid) {
      throw OwnershipException('Ownership violation: Cannot read outbox for user $userId under active user $uid');
    }
    return await _dbService.runInTransaction((executor) async {
      final maps = await executor.query(
        'sync_outbox',
        where: 'userId = ? AND status = ?',
        whereArgs: [uid, 'pending'],
        orderBy: 'localSequence ASC',
      );
      return maps.map((m) => SyncOutboxItem.fromMap(m)).toList();
    });
  }

  @override
  Future<int> markOutboxItemSynced(String id, int syncedVersion) async {
    final uid = _resolveActiveUserId();
    return await _dbService.runInTransaction((executor) async {
      return await executor.delete(
        'sync_outbox',
        where: 'id = ? AND userId = ?',
        whereArgs: [id, uid],
      );
    });
  }

  @override
  Future<int> deleteOutboxItemsForEntity(DatabaseExecutor executor, String entityId) async {
    final uid = _resolveActiveUserId();
    return await executor.delete(
      'sync_outbox',
      where: 'entityId = ? AND userId = ?',
      whereArgs: [entityId, uid],
    );
  }

  @override
  Future<void> acknowledgeOutboxItem({
    required String outboxId,
    required String entityType,
    required String entityId,
    required int localVersion,
  }) async {
    final uid = _resolveActiveUserId();
    final tableName = _resolveTableName(entityType);
    await _dbService.runInTransaction((executor) async {
      if (tableName != null) {
        await executor.update(
          tableName,
          {'lastSyncedVersion': localVersion},
          where: 'id = ? AND userId = ?',
          whereArgs: [entityId, uid],
        );
      }
      await executor.delete(
        'sync_outbox',
        where: 'id = ? AND userId = ?',
        whereArgs: [outboxId, uid],
      );
    });
  }

  @override
  Future<int> updateOutboxItemRetryStatus({
    required String id,
    required int attemptCount,
    required String status,
    DateTime? lastAttemptAt,
    DateTime? nextAttemptAt,
    String? lastError,
  }) async {
    final uid = _resolveActiveUserId();
    return await _dbService.runInTransaction((executor) async {
      return await executor.update(
        'sync_outbox',
        {
          'attemptCount': attemptCount,
          'status': status,
          'lastAttemptAt': lastAttemptAt?.toIso8601String(),
          'nextAttemptAt': nextAttemptAt?.toIso8601String(),
          'lastError': lastError,
        },
        where: 'id = ? AND userId = ?',
        whereArgs: [id, uid],
      );
    });
  }
}
