import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import '../models/remote_change.dart';
import '../models/sync_outbox_item.dart';
import 'database_service.dart';
import 'sync_conflict_resolver.dart';

/// RemoteChangeApplier — Applies incoming remote changes directly to local SQLite
/// while enforcing topological dependency ordering, conflict policy, user isolation,
/// and absolute prevention of remote->outbox feedback loops.
class RemoteChangeApplier {
  final DatabaseService _dbService;

  RemoteChangeApplier({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService.instance;

  /// Sorts changes topologically: folders -> notes -> tasks.
  List<RemoteChange> sortTopologically(List<RemoteChange> changes) {
    final sorted = List<RemoteChange>.from(changes);
    sorted.sort((a, b) {
      final rankA = _typeRank(a.entityType);
      final rankB = _typeRank(b.entityType);
      return rankA.compareTo(rankB);
    });
    return sorted;
  }

  int _typeRank(String entityType) {
    switch (entityType.toLowerCase()) {
      case 'folder':
        return 1;
      case 'note':
        return 2;
      case 'task':
        return 3;
      default:
        return 4;
    }
  }

  String _tableNameFor(String entityType) {
    switch (entityType.toLowerCase()) {
      case 'folder':
        return 'folders';
      case 'note':
        return 'notes';
      case 'task':
        return 'tasks';
      default:
        throw ArgumentError('Unsupported entity type: $entityType');
    }
  }

  /// Applies a batch of [RemoteChange] items atomically inside a single SQLite transaction.
  Future<int> applyBatch({
    required String activeUserId,
    required List<RemoteChange> changes,
  }) async {
    if (changes.isEmpty) return 0;

    final sortedChanges = sortTopologically(changes);
    int appliedCount = 0;

    await _dbService.runInTransaction((executor) async {
      for (final change in sortedChanges) {
        // User isolation check
        if (change.userId != activeUserId) {
          debugPrint(
              'RemoteChangeApplier: Rejected change for user ${change.userId} (active: $activeUserId)');
          continue;
        }

        final tableName = _tableNameFor(change.entityType);

        // Fetch current local entity state
        final localRows = await executor.query(
          tableName,
          where: 'id = ? AND userId = ?',
          whereArgs: [change.entityId, activeUserId],
        );
        final localEntityMap = localRows.isNotEmpty ? localRows.first : null;

        // Fetch pending outbox item for this entity
        final outboxRows = await executor.query(
          'sync_outbox',
          where:
              'userId = ? AND entityType = ? AND entityId = ? AND status = ?',
          whereArgs: [
            activeUserId,
            change.entityType,
            change.entityId,
            'pending'
          ],
        );
        final pendingOutboxItem = outboxRows.isNotEmpty
            ? SyncOutboxItem.fromMap(outboxRows.first)
            : null;

        // Evaluate conflict policy
        final decision = SyncConflictResolver.evaluate(
          change: change,
          activeUserId: activeUserId,
          localEntityMap: localEntityMap,
          pendingOutboxItem: pendingOutboxItem,
        );

        switch (decision) {
          case ConflictDecision.applyRemote:
          case ConflictDecision.serverWinsOverWrite:
            await _applyRemoteToDb(executor, tableName, activeUserId, change);
            if (decision == ConflictDecision.serverWinsOverWrite) {
              await _clearPendingOutboxItem(
                  executor, activeUserId, change.entityType, change.entityId);
            }
            appliedCount++;
            break;

          case ConflictDecision.serverDeleteWins:
            await _applyRemoteDeleteToDb(
                executor, tableName, activeUserId, change);
            await _clearPendingOutboxItem(
                executor, activeUserId, change.entityType, change.entityId);
            appliedCount++;
            break;

          case ConflictDecision.localDeleteWins:
          case ConflictDecision.ignoreStaleOrDuplicate:
          case ConflictDecision.userMismatchReject:
            // No write performed
            break;
        }
      }
    });

    return appliedCount;
  }

  Future<void> _applyRemoteToDb(
    DatabaseExecutor executor,
    String tableName,
    String activeUserId,
    RemoteChange change,
  ) async {
    if (change.operation.toLowerCase() == 'delete') {
      await _applyRemoteDeleteToDb(executor, tableName, activeUserId, change);
      return;
    }

    final rawPayload = change.payload ?? {};
    final mapToSave = Map<String, dynamic>.from(rawPayload);

    // Enforce canonical versioning & user ownership
    mapToSave['id'] = change.entityId;
    mapToSave['userId'] = activeUserId;
    mapToSave['version'] = change.remoteVersion;
    mapToSave['lastSyncedVersion'] = change.remoteVersion;

    // Convert booleans/nested structures if needed
    _normalizePayloadForSqlite(tableName, mapToSave);

    await executor.insert(
      tableName,
      mapToSave,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _applyRemoteDeleteToDb(
    DatabaseExecutor executor,
    String tableName,
    String activeUserId,
    RemoteChange change,
  ) async {
    final nowIso = change.serverTimestamp.toIso8601String();
    final count = await executor.update(
      tableName,
      {
        'isDeleted': 1,
        'deletedAt': nowIso,
        'version': change.remoteVersion,
        'lastSyncedVersion': change.remoteVersion,
      },
      where: 'id = ? AND userId = ?',
      whereArgs: [change.entityId, activeUserId],
    );

    // If entity didn't exist locally, insert soft-deleted stub to record version
    if (count == 0) {
      await executor.insert(
        tableName,
        {
          'id': change.entityId,
          'userId': activeUserId,
          'isDeleted': 1,
          'deletedAt': nowIso,
          'version': change.remoteVersion,
          'lastSyncedVersion': change.remoteVersion,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> _clearPendingOutboxItem(
    DatabaseExecutor executor,
    String activeUserId,
    String entityType,
    String entityId,
  ) async {
    await executor.delete(
      'sync_outbox',
      where: 'userId = ? AND entityType = ? AND entityId = ? AND status = ?',
      whereArgs: [activeUserId, entityType, entityId, 'pending'],
    );
  }

  void _normalizePayloadForSqlite(String tableName, Map<String, dynamic> map) {
    // Ensure boolean fields are represented as int 0/1 for sqflite
    for (final entry in map.entries.toList()) {
      if (entry.value is bool) {
        map[entry.key] = (entry.value as bool) ? 1 : 0;
      }
    }
  }
}
