import '../models/remote_change.dart';
import '../models/sync_outbox_item.dart';

/// Decisions produced by [SyncConflictResolver].
enum ConflictDecision {
  /// Remote state should be applied directly (no local pending conflict).
  applyRemote,

  /// Remote state replaces local pending create/update (Server Wins).
  serverWinsOverWrite,

  /// Local pending delete takes precedence over incoming remote update.
  localDeleteWins,

  /// Server delete takes precedence over incoming local pending update.
  serverDeleteWins,

  /// Remote change version is <= lastSyncedVersion or duplicate.
  ignoreStaleOrDuplicate,

  /// Remote change userId does not match active canonical user ID.
  userMismatchReject,
}

/// SyncConflictResolver — Pure logic class enforcing the Phase 1.8 locked conflict matrix.
class SyncConflictResolver {
  /// Evaluates incoming [RemoteChange] against local database state and pending outbox item.
  static ConflictDecision evaluate({
    required RemoteChange change,
    required String activeUserId,
    required Map<String, dynamic>? localEntityMap,
    required SyncOutboxItem? pendingOutboxItem,
  }) {
    // 1. Security & User Isolation Check
    if (change.userId != activeUserId) {
      return ConflictDecision.userMismatchReject;
    }

    // 2. Stale & Duplicate Check
    if (localEntityMap != null) {
      final lastSyncedVersion = (localEntityMap['lastSyncedVersion'] as num? ?? 0).toInt();
      if (change.remoteVersion <= lastSyncedVersion) {
        return ConflictDecision.ignoreStaleOrDuplicate;
      }
    }

    // 3. Conflict evaluation with pending local mutation
    if (pendingOutboxItem != null) {
      final localOp = pendingOutboxItem.operation.toLowerCase();
      final remoteOp = change.operation.toLowerCase();

      if (localOp == 'delete') {
        if (remoteOp == 'update' || remoteOp == 'create') {
          // CASE D: Pending local delete vs remote update -> Local Delete Wins
          return ConflictDecision.localDeleteWins;
        }
      }

      if (localOp == 'update' || localOp == 'create') {
        if (remoteOp == 'delete') {
          // CASE E: Pending local update vs remote delete -> Server Delete Wins
          return ConflictDecision.serverDeleteWins;
        }
        if (remoteOp == 'create' || remoteOp == 'update') {
          // CASE C: Pending local update/create vs remote update/create -> Server Wins
          return ConflictDecision.serverWinsOverWrite;
        }
      }
    }

    // 4. Clean local state (no pending outbox mutation)
    return ConflictDecision.applyRemote;
  }
}
