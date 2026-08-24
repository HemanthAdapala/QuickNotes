import 'dart:async';
import '../backup/backup_integrity.dart';
import '../backup/backup_storage_adapter.dart';
import '../backup/drive_storage_exception.dart';
import '../backup/remote_backup_metadata.dart';
import '../database_service.dart';
import '../session_manager.dart';
import '../../models/session_type.dart';
import 'first_run_recovery_state.dart';
import 'local_data_detector.dart';
import 'recovery_completion_store.dart';

/// FirstRunRecoveryDetector — Provider-neutral orchestrator for detecting first-run recovery eligibility.
///
/// Evaluates whether an authenticated Google user should be presented with a First-Run Recovery flow.
///
/// Principles & Invariants:
/// 1. READ-ONLY: Never mutates local SQLite records or executes backup restoration.
/// 2. PROVIDER-NEUTRAL: Communicates through [BackupStorageAdapter] rather than direct cloud REST clients.
/// 3. METADATA ONLY: Evaluates eligibility from remote metadata list; never downloads full `.qnb` archives.
/// 4. IDENTITY ISOLATION: Scoped strictly to the active user's identity hash.
/// 5. ERROR RESILIENCE: Catches all cloud, network, and auth failures cleanly and returns sanitized results.
class FirstRunRecoveryDetector {
  final BackupStorageAdapter _storageAdapter;
  final LocalDataDetector _localDataDetector;
  final RecoveryCompletionStore _completionStore;
  final SessionManager _sessionManager;
  final DatabaseService _dbService;

  FirstRunRecoveryDetector({
    required BackupStorageAdapter storageAdapter,
    LocalDataDetector? localDataDetector,
    RecoveryCompletionStore? completionStore,
    SessionManager? sessionManager,
    DatabaseService? dbService,
  })  : _storageAdapter = storageAdapter,
        _localDataDetector = localDataDetector ?? LocalDataDetector(),
        _completionStore = completionStore ?? RecoveryCompletionStore(),
        _sessionManager = sessionManager ?? SessionManager(),
        _dbService = dbService ?? DatabaseService.instance;

  /// Performs recovery eligibility check for the currently active or specified user session.
  Future<FirstRunRecoveryResult> checkEligibility({
    String? overrideUserId,
    String? overrideProviderUserIdHash,
    SessionType? overrideSessionType,
  }) async {
    final activeUserId = overrideUserId ?? _sessionManager.activeUserId;
    final activeSessionType = overrideSessionType ?? _sessionManager.activeSessionType;

    // 1. Session Type Gate: Offline sessions immediately bypass recovery
    if (activeSessionType == SessionType.offline) {
      final localSummary = await _localDataDetector.detectLocalData(userId: activeUserId);
      return FirstRunRecoveryResult.noRecoveryRequired(
        localSummary: localSummary,
        recoveryStatus: RecoveryCompletionStatus.notCompleted,
      );
    }

    if (activeUserId == null || activeUserId.isEmpty) {
      return const FirstRunRecoveryResult.noRecoveryRequired();
    }

    // 2. Resolve Provider User ID Hash for active identity
    final providerUserIdHash = overrideProviderUserIdHash ?? await _resolveProviderUserIdHash(activeUserId);

    // 3. Persistent Status Gate: If recovery was already completed/skipped, bypass network check
    final currentStatus = await _completionStore.getStatus(providerUserIdHash);
    if (currentStatus != RecoveryCompletionStatus.notCompleted) {
      final localSummary = await _localDataDetector.detectLocalData(userId: activeUserId);
      return FirstRunRecoveryResult.noRecoveryRequired(
        localSummary: localSummary,
        recoveryStatus: currentStatus,
      );
    }

    // 4. Capture session snapshot for concurrency validation
    final initialSessionUserId = _sessionManager.activeUserId;
    LocalDataSummary localSummary = const LocalDataSummary.empty();

    try {
      // 5. Execute local data inspection and cloud backup listing concurrently
      final results = await Future.wait([
        _localDataDetector.detectLocalData(userId: activeUserId),
        _storageAdapter.listBackups(),
      ]);

      localSummary = results[0] as LocalDataSummary;
      final rawRemoteBackups = results[1] as List<RemoteBackupMetadata>;

      // 6. Concurrency check: If running against live session, ensure identity did not switch
      if (overrideUserId == null && initialSessionUserId != null) {
        final currentActiveUserId = _sessionManager.activeUserId;
        if (currentActiveUserId != initialSessionUserId) {
          return FirstRunRecoveryResult.detectionFailed(
            failureReason: 'User identity changed during recovery detection.',
            localSummary: localSummary,
          );
        }
      }

      // 7. Filter eligible backups: schema v18, format v1, non-empty
      final eligibleBackups = _filterAndSortEligibleBackups(rawRemoteBackups);

      // 8. Evaluate Decision Matrix
      if (eligibleBackups.isEmpty) {
        // No eligible cloud backup found -> no recovery required (remain notCompleted)
        return FirstRunRecoveryResult.noRecoveryRequired(
          localSummary: localSummary,
          recoveryStatus: RecoveryCompletionStatus.notCompleted,
        );
      }

      final recommendedBackup = eligibleBackups.first;

      if (localSummary.hasData) {
        // Local data exists + Cloud backup available -> Conflict / Choice Flow
        return FirstRunRecoveryResult.eligibleConflictLocal(
          localSummary: localSummary,
          recommendedBackup: recommendedBackup,
          eligibleBackups: eligibleBackups,
        );
      } else {
        // Zero local data + Cloud backup available -> Clean Restore Flow
        return FirstRunRecoveryResult.eligibleEmptyLocal(
          localSummary: localSummary,
          recommendedBackup: recommendedBackup,
          eligibleBackups: eligibleBackups,
        );
      }
    } on DriveStorageException {
      return FirstRunRecoveryResult.detectionFailed(
        failureReason: 'Cloud backup detection is temporarily unavailable.',
        localSummary: localSummary,
      );
    } on TimeoutException {
      return FirstRunRecoveryResult.detectionFailed(
        failureReason: 'Connection timed out while checking for cloud backups.',
        localSummary: localSummary,
      );
    } catch (_) {
      return FirstRunRecoveryResult.detectionFailed(
        failureReason: 'Cloud backup detection is temporarily unavailable.',
        localSummary: localSummary,
      );
    }
  }

  /// Resolves the SHA-256 identity hash for the specified canonical user ID.
  Future<String> _resolveProviderUserIdHash(String userId) async {
    try {
      final db = await _dbService.database;
      final identityMaps = await db.query(
        'user_identities',
        where: 'userId = ?',
        whereArgs: [userId],
        limit: 1,
      );

      if (identityMaps.isNotEmpty) {
        final pUserId = identityMaps.first['providerUserId'] as String? ?? '';
        if (pUserId.isNotEmpty) {
          return BackupIntegrity.sha256String(pUserId);
        }
      }
    } catch (_) {}

    return BackupIntegrity.sha256String(userId);
  }

  /// Filters backups by schema v18, format v1, and non-empty contents, sorted newest first.
  static List<RemoteBackupMetadata> _filterAndSortEligibleBackups(
    List<RemoteBackupMetadata> backups,
  ) {
    final eligible = backups.where((b) {
      final isSchemaValid = b.databaseSchemaVersion == 18;
      final isFormatValid = b.formatVersion == 1;
      final hasData = (b.noteCount + b.folderCount + b.taskCount) > 0;
      return isSchemaValid && isFormatValid && hasData;
    }).toList();

    eligible.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return eligible;
  }
}
