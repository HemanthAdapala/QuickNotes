import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/sync_pull_request.dart';
import '../models/sync_pull_response.dart';
import 'sync_network_client.dart';
import 'remote_change_applier.dart';
import 'session_manager.dart';

/// PullSyncEngine — Orchestrates cursor-based delta pull synchronization,
/// atomicity, crash-safe pagination, and SharedPreferences cursor persistence.
class PullSyncEngine {
  final SyncNetworkClient _networkClient;
  final RemoteChangeApplier _applier;
  final SessionManager _sessionManager;

  PullSyncEngine({
    required SyncNetworkClient networkClient,
    RemoteChangeApplier? applier,
    SessionManager? sessionManager,
  })  : _networkClient = networkClient,
        _applier = applier ?? RemoteChangeApplier(),
        _sessionManager = sessionManager ?? SessionManager();

  String _cursorKey(String canonicalUserId) => 'sync_cursor_$canonicalUserId';

  /// Pulls remote changes for [activeUserId] until `hasMore` is false or session invalid.
  Future<void> pull({required String activeUserId}) async {
    final token = await _sessionManager.getIdToken();
    if (token == null || token.isEmpty) {
      debugPrint('PullSyncEngine: Aborting pull because auth token is null/empty');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    String? currentCursor = prefs.getString(_cursorKey(activeUserId));
    bool hasMore = true;
    int pageSafetyLimit = 50;

    while (hasMore && pageSafetyLimit > 0) {
      pageSafetyLimit--;

      // Session boundary check before every page request
      if (_sessionManager.activeUserId != activeUserId) {
        debugPrint('PullSyncEngine: Session changed during pull loop; aborting');
        return;
      }

      final request = SyncPullRequest(cursor: currentCursor, limit: 50);
      SyncPullResponse response;

      try {
        response = await _networkClient.pullChanges(
          userId: activeUserId,
          authToken: token,
          request: request,
        );
      } on SyncNetworkException catch (e) {
        if (e.type == SyncNetworkErrorType.malformedResponse) {
          debugPrint('PullSyncEngine: Invalid cursor or malformed response; resetting cursor');
          await clearCursor(activeUserId);
        }
        rethrow;
      } catch (e) {
        debugPrint('PullSyncEngine error fetching pull changes: $e');
        rethrow;
      }

      // Session check prior to database transaction
      if (_sessionManager.activeUserId != activeUserId) {
        debugPrint('PullSyncEngine: Session changed prior to DB commit; aborting');
        return;
      }

      // Apply batch atomically inside SQLite transaction
      if (response.changes.isNotEmpty) {
        await _applier.applyBatch(
          activeUserId: activeUserId,
          changes: response.changes,
        );
      }

      // ONLY AFTER successful SQLite commit, advance the cursor in SharedPreferences
      currentCursor = response.nextCursor;
      if (currentCursor != null && currentCursor.isNotEmpty) {
        await prefs.setString(_cursorKey(activeUserId), currentCursor);
      } else {
        await prefs.remove(_cursorKey(activeUserId));
      }

      hasMore = response.hasMore && (currentCursor != null && currentCursor.isNotEmpty);
    }
  }

  /// Clears stored cursor for [canonicalUserId].
  Future<void> clearCursor(String canonicalUserId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cursorKey(canonicalUserId));
  }

  /// Gets stored cursor for [canonicalUserId].
  Future<String?> getCursor(String canonicalUserId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_cursorKey(canonicalUserId));
  }
}
