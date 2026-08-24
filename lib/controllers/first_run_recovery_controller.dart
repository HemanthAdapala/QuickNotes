import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../services/backup/backup_storage_adapter.dart';
import '../services/backup/drive_storage_exception.dart';
import '../services/backup/google_drive_backup_service.dart';
import '../services/backup/remote_backup_metadata.dart';
import '../services/backup/restore_engine.dart';
import '../services/backup/restore_result.dart';
import '../services/recovery/first_run_recovery_state.dart';
import '../services/recovery/local_data_detector.dart';
import '../services/recovery/recovery_completion_store.dart';

/// FirstRunRecoveryUiState — UI operation lifecycle states for the First-Run Recovery flow.
enum FirstRunRecoveryUiState {
  initial,
  ready,
  restoring,
  restoreFailed,
  completed,
}

/// FirstRunRecoveryController — Presentation and business logic controller for First-Run Recovery.
///
/// Sits between [FirstRunRecoveryDetector] results and the presentation layer.
///
/// Invariants & Rules:
/// 1. FRAMEWORK-LIGHT: Zero coupling to BuildContext, Navigator, or widget trees.
/// 2. READ-ONLY ON DETECTION: Does not rerun detection or redisover backups during restore.
/// 3. ATOMIC RESTORE: Delegates full restore execution and rollbacks to [RestoreEngine].
/// 4. IDENTITY ISOLATED: Scopes completion status to the recommended backup's `providerUserIdHash`.
/// 5. DOUBLE-ACTION GUARD: Rejects duplicate taps while restoring or once completed.
/// 6. ERROR SANITIZATION: Never exposes internal paths, credentials, tokens, or raw stack traces.
class FirstRunRecoveryController extends ChangeNotifier {
  final FirstRunRecoveryResult _recoveryResult;
  final RestoreEngine _restoreEngine;
  final BackupStorageAdapter _storageAdapter;
  final RecoveryCompletionStore _completionStore;
  final Directory? _customTempDir;
  final Directory? _customDocumentsDir;

  FirstRunRecoveryUiState _state = FirstRunRecoveryUiState.initial;
  String? _errorMessage;
  String? _progressMessage;
  bool _isDisposed = false;

  FirstRunRecoveryController({
    required FirstRunRecoveryResult recoveryResult,
    RestoreEngine? restoreEngine,
    BackupStorageAdapter? storageAdapter,
    RecoveryCompletionStore? completionStore,
    Directory? customTempDir,
    Directory? customDocumentsDir,
  })  : _recoveryResult = recoveryResult,
        _restoreEngine = restoreEngine ?? RestoreEngine(),
        _storageAdapter = storageAdapter ?? GoogleDriveBackupService(),
        _completionStore = completionStore ?? RecoveryCompletionStore(),
        _customTempDir = customTempDir,
        _customDocumentsDir = customDocumentsDir {
    if (_recoveryResult.isEligible) {
      _state = FirstRunRecoveryUiState.ready;
    } else {
      _state = FirstRunRecoveryUiState.initial;
    }
  }

  // ── State Getters ──────────────────────────────────────────────────────────

  FirstRunRecoveryUiState get state => _state;
  String? get errorMessage => _errorMessage;
  String? get progressMessage => _progressMessage;

  FirstRunRecoveryResult get recoveryResult => _recoveryResult;
  LocalDataSummary get localSummary => _recoveryResult.localSummary;
  RemoteBackupMetadata? get recommendedBackup =>
      _recoveryResult.recommendedBackup;
  List<RemoteBackupMetadata> get eligibleBackups =>
      _recoveryResult.eligibleBackups;
  int get totalEligibleBackupsCount => _recoveryResult.eligibleBackups.length;

  bool get isReady => _state == FirstRunRecoveryUiState.ready;
  bool get isRestoring => _state == FirstRunRecoveryUiState.restoring;
  bool get hasFailed => _state == FirstRunRecoveryUiState.restoreFailed;
  bool get isCompleted => _state == FirstRunRecoveryUiState.completed;

  bool get isConflict =>
      _recoveryResult.state == FirstRunRecoveryState.eligibleConflictLocal;
  bool get isCleanRestore =>
      _recoveryResult.state == FirstRunRecoveryState.eligibleEmptyLocal;

  // ── Internal State Mutator ────────────────────────────────────────────────

  void _setState(FirstRunRecoveryUiState newState,
      {String? error, String? progress}) {
    if (_isDisposed) return;
    _state = newState;
    _errorMessage = error;
    _progressMessage = progress;
    notifyListeners();
  }

  // ── User Actions ──────────────────────────────────────────────────────────

  /// Downloads and executes atomic restoration of the recommended cloud backup.
  ///
  /// Prevents concurrent or duplicate calls while an operation is running.
  Future<bool> restoreRecommendedBackup() async {
    // Concurrency guard
    if (_state == FirstRunRecoveryUiState.restoring ||
        _state == FirstRunRecoveryUiState.completed) {
      return false;
    }

    final backup = recommendedBackup;
    if (backup == null) {
      _setState(
        FirstRunRecoveryUiState.restoreFailed,
        error: 'No eligible cloud backup was found to restore.',
      );
      return false;
    }

    _setState(
      FirstRunRecoveryUiState.restoring,
      progress: 'Downloading backup...',
      error: null,
    );

    File? tempDownloadedFile;
    try {
      final downloadDir = _customTempDir ?? await getTemporaryDirectory();
      final destinationFile = File(
        p.join(downloadDir.path, 'first_run_recovery_${backup.backupId}.qnb'),
      );

      // 1. Download archive from cloud storage
      tempDownloadedFile = await _storageAdapter.downloadBackup(
        remoteFileId: backup.remoteFileId,
        destinationLocalFile: destinationFile,
      );

      _setState(
        FirstRunRecoveryUiState.restoring,
        progress: 'Restoring notes, folders, and tasks...',
      );

      // 2. Execute multi-resource atomic restore
      final result = await _restoreEngine.restoreFromBackup(
        backupFilePath: tempDownloadedFile.path,
        customDocumentsDir: _customDocumentsDir,
      );

      if (result.success) {
        // 3. Mark persistent recovery status only AFTER successful restore
        await _completionStore.setStatus(
          backup.providerUserIdHash,
          RecoveryCompletionStatus.restored,
        );

        _setState(
          FirstRunRecoveryUiState.completed,
          progress: null,
          error: null,
        );
        return true;
      } else {
        _setState(
          FirstRunRecoveryUiState.restoreFailed,
          error: _mapRestoreError(result),
          progress: null,
        );
        return false;
      }
    } on DriveStorageException catch (e) {
      _setState(
        FirstRunRecoveryUiState.restoreFailed,
        error: _mapDriveError(e),
        progress: null,
      );
      return false;
    } catch (_) {
      _setState(
        FirstRunRecoveryUiState.restoreFailed,
        error: "We couldn't restore your backup. Please try again.",
        progress: null,
      );
      return false;
    } finally {
      if (tempDownloadedFile != null && tempDownloadedFile.existsSync()) {
        try {
          tempDownloadedFile.deleteSync();
        } catch (_) {}
      }
    }
  }

  /// Retries the restore operation after a previous failure.
  Future<bool> retryRestore() async {
    if (_state != FirstRunRecoveryUiState.restoreFailed) {
      return false;
    }
    _setState(FirstRunRecoveryUiState.ready, error: null, progress: null);
    return await restoreRecommendedBackup();
  }

  /// User chooses to keep existing local device data and bypass cloud restore.
  Future<bool> keepLocalData() async {
    if (_state == FirstRunRecoveryUiState.restoring ||
        _state == FirstRunRecoveryUiState.completed) {
      return false;
    }

    final hash = _resolveIdentityHash();
    if (hash.isNotEmpty) {
      await _completionStore.setStatus(
        hash,
        RecoveryCompletionStatus.keptLocalData,
      );
    }

    _setState(
      FirstRunRecoveryUiState.completed,
      error: null,
      progress: null,
    );
    return true;
  }

  /// User chooses to start fresh and skip cloud restore.
  ///
  /// In accordance with safety rules, this records [RecoveryCompletionStatus.skipped]
  /// and NEVER executes destructive local data deletion.
  Future<bool> skipAndStartFresh() async {
    if (_state == FirstRunRecoveryUiState.restoring ||
        _state == FirstRunRecoveryUiState.completed) {
      return false;
    }

    final hash = _resolveIdentityHash();
    if (hash.isNotEmpty) {
      await _completionStore.setStatus(
        hash,
        RecoveryCompletionStatus.skipped,
      );
    }

    _setState(
      FirstRunRecoveryUiState.completed,
      error: null,
      progress: null,
    );
    return true;
  }

  /// Postpones decision without writing permanent completion status.
  void postpone() {
    if (_state == FirstRunRecoveryUiState.restoring ||
        _state == FirstRunRecoveryUiState.completed) {
      return;
    }

    _setState(
      FirstRunRecoveryUiState.completed,
      error: null,
      progress: null,
    );
  }

  // ── Helper Resolvers & Error Mappers ──────────────────────────────────────

  String _resolveIdentityHash() {
    return recommendedBackup?.providerUserIdHash ?? '';
  }

  static String _mapDriveError(DriveStorageException exception) {
    switch (exception.type) {
      case DriveStorageErrorType.unauthenticated:
        return "Google Drive isn't connected. Please sign in with Google to enable cloud backups.";
      case DriveStorageErrorType.networkUnavailable:
        return 'No internet connection. Please check your network and try again.';
      case DriveStorageErrorType.permissionDenied:
        return "Quick Notes doesn't currently have permission to access Google Drive. Please grant Google Drive access when prompted.";
      case DriveStorageErrorType.backupNotFound:
        return 'This cloud backup is no longer available on Google Drive.';
      case DriveStorageErrorType.quotaExceeded:
      case DriveStorageErrorType.insufficientStorage:
        return 'Your Google Drive storage is full. Free up space and try again.';
      case DriveStorageErrorType.uploadFailed:
        return 'Failed to communicate with Google Drive.';
      case DriveStorageErrorType.downloadFailed:
        return 'The backup file could not be downloaded safely.';
    }
  }

  static String _mapRestoreError(RestoreResult result) {
    if (result.error == null) {
      return "We couldn't restore your backup. Please try again.";
    }
    switch (result.error!.type) {
      case RestoreErrorType.identityMismatch:
        return 'Backup identity does not match your current Google account.';
      case RestoreErrorType.validationFailed:
      case RestoreErrorType.unsupportedSchema:
      case RestoreErrorType.invalidBackup:
        return 'This backup file is invalid, corrupted, or uses an unsupported format.';
      case RestoreErrorType.safetySnapshotFailed:
        return 'Could not create a safety snapshot before restoring. Restore aborted.';
      case RestoreErrorType.stagingFailed:
        return 'Failed to prepare backup files for restore. Restore aborted.';
      case RestoreErrorType.attachmentRestoreFailed:
        return 'Failed to restore image attachments. Your existing data remains untouched.';
      case RestoreErrorType.databaseRestoreFailed:
        return 'Failed to restore database records. Your existing data remains untouched.';
      case RestoreErrorType.filesystemCommitFailed:
        return 'Failed to commit attachment files. Database restored cleanly.';
      case RestoreErrorType.verificationFailed:
        return 'Post-restore verification failed. System rolled back to safety snapshot.';
      case RestoreErrorType.cleanupFailed:
        return 'Restore completed, but temporary files could not be cleaned up.';
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
