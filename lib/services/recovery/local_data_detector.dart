import '../database_service.dart';
import '../session_manager.dart';

/// LocalDataSummary — Immutable representation of active, non-deleted records for a specific user.
class LocalDataSummary {
  final int noteCount;
  final int folderCount;
  final int taskCount;
  final int totalCount;

  const LocalDataSummary({
    required this.noteCount,
    required this.folderCount,
    required this.taskCount,
  }) : totalCount = noteCount + folderCount + taskCount;

  const LocalDataSummary.empty()
      : noteCount = 0,
        folderCount = 0,
        taskCount = 0,
        totalCount = 0;

  bool get hasData => totalCount > 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalDataSummary &&
          runtimeType == other.runtimeType &&
          noteCount == other.noteCount &&
          folderCount == other.folderCount &&
          taskCount == other.taskCount &&
          totalCount == other.totalCount;

  @override
  int get hashCode =>
      noteCount.hashCode ^
      folderCount.hashCode ^
      taskCount.hashCode ^
      totalCount.hashCode;

  @override
  String toString() =>
      'LocalDataSummary(notes: $noteCount, folders: $folderCount, tasks: $taskCount, total: $totalCount)';
}

/// LocalDataDetector — Read-only service for counting active domain entities for a user.
///
/// Uses efficient indexed SQL `COUNT(*)` queries without loading entity objects into memory.
/// Never mutates SQLite data or counts deleted/trashed/other-user records.
class LocalDataDetector {
  final DatabaseService _dbService;
  final SessionManager _sessionManager;

  LocalDataDetector({
    DatabaseService? dbService,
    SessionManager? sessionManager,
  })  : _dbService = dbService ?? DatabaseService.instance,
        _sessionManager = sessionManager ?? SessionManager();

  /// Inspects SQLite database to compute active record counts for the specified or active user.
  Future<LocalDataSummary> detectLocalData({String? userId}) async {
    final targetUserId = userId ?? _sessionManager.activeUserId;
    if (targetUserId == null || targetUserId.isEmpty) {
      return const LocalDataSummary.empty();
    }

    try {
      final db = await _dbService.database;

      final notesRes = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM notes WHERE userId = ? AND isDeleted = 0',
        [targetUserId],
      );
      final foldersRes = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM folders WHERE userId = ? AND isDeleted = 0',
        [targetUserId],
      );
      final tasksRes = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM tasks WHERE userId = ? AND isDeleted = 0',
        [targetUserId],
      );

      final nCnt = (notesRes.first['cnt'] as num?)?.toInt() ?? 0;
      final fCnt = (foldersRes.first['cnt'] as num?)?.toInt() ?? 0;
      final tCnt = (tasksRes.first['cnt'] as num?)?.toInt() ?? 0;

      return LocalDataSummary(
        noteCount: nCnt,
        folderCount: fCnt,
        taskCount: tCnt,
      );
    } catch (_) {
      return const LocalDataSummary.empty();
    }
  }
}
