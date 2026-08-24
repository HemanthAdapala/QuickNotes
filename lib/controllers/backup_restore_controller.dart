import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../services/backup/backup_engine.dart';
import '../services/backup/backup_manifest.dart';
import '../services/backup/backup_result.dart';
import '../services/backup/backup_storage_adapter.dart';
import '../services/backup/backup_validation_result.dart';
import '../services/backup/backup_validator.dart';
import '../services/backup/drive_storage_exception.dart';
import '../services/backup/remote_backup_metadata.dart';
import '../services/backup/restore_engine.dart';
import '../services/backup/restore_result.dart';
import '../services/database_service.dart';
import '../services/session_manager.dart';

/// Single operation state enum ensuring strict concurrency mutual exclusion.
enum BackupOperationState {
  idle,
  creatingLocalBackup,
  uploadingCloudBackup,
  loadingCloudBackups,
  restoring,
  deletingCloudBackup,
}

/// BackupRestoreController — Orchestration layer for Backup & Restore UI.
///
/// Principles & Invariants:
/// 1. CONTROL TOWER: Orchestrates operations between UI and underlying engines (BackupEngine, RestoreEngine, BackupStorageAdapter).
/// 2. STRICT CONCURRENCY GUARD: Enforces single active operation state. Duplicate or conflicting actions are blocked.
/// 3. NO DIRECT ENGINE / DB TAMPERING: Never executes raw SQLite queries, inspects ZIP byte payloads, or calls cloud REST endpoints directly.
/// 4. USER-FRIENDLY ERROR MAPPING: Translates technical exceptions into human-readable messages without credential leakage.
class BackupRestoreController extends ChangeNotifier {
  final BackupEngine _backupEngine;
  final RestoreEngine _restoreEngine;
  final BackupStorageAdapter _storageAdapter;
  final SessionManager _sessionManager;

  BackupOperationState _operationState = BackupOperationState.idle;
  List<RemoteBackupMetadata> _remoteBackups = const [];
  BackupResult? _lastLocalBackupResult;
  RestoreResult? _lastRestoreResult;
  String? _errorMessage;
  String? _infoMessage;
  String? _currentRestoreStage;

  BackupRestoreController({
    required BackupEngine backupEngine,
    required RestoreEngine restoreEngine,
    required BackupStorageAdapter storageAdapter,
    SessionManager? sessionManager,
  })  : _backupEngine = backupEngine,
        _restoreEngine = restoreEngine,
        _storageAdapter = storageAdapter,
        _sessionManager = sessionManager ?? SessionManager();

  // ── Getters ──────────────────────────────────────────────────────────────
  BackupOperationState get operationState => _operationState;
  bool get isIdle => _operationState == BackupOperationState.idle;
  bool get isBusy => _operationState != BackupOperationState.idle;

  List<RemoteBackupMetadata> get remoteBackups =>
      List.unmodifiable(_remoteBackups);
  BackupResult? get lastLocalBackupResult => _lastLocalBackupResult;
  RestoreResult? get lastRestoreResult => _lastRestoreResult;
  String? get errorMessage => _errorMessage;
  String? get infoMessage => _infoMessage;
  String? get currentRestoreStage => _currentRestoreStage;

  Future<Map<String, int>> fetchCurrentDataCounts() async {
    try {
      final userId = _sessionManager.activeUserId;
      if (userId == null)
        return {'notes': 0, 'folders': 0, 'tasks': 0, 'attachments': 0};

      final db = await DatabaseService.instance.database;
      final notesRes = await db.rawQuery(
          'SELECT COUNT(*) as cnt FROM notes WHERE user_id = ? AND is_trashed = 0',
          [userId]);
      final foldersRes = await db.rawQuery(
          'SELECT COUNT(*) as cnt FROM folders WHERE user_id = ? AND is_trashed = 0',
          [userId]);
      final tasksRes = await db.rawQuery(
          'SELECT COUNT(*) as cnt FROM tasks WHERE user_id = ? AND is_trashed = 0',
          [userId]);

      final nCnt = (notesRes.first['cnt'] as int?) ?? 0;
      final fCnt = (foldersRes.first['cnt'] as int?) ?? 0;
      final tCnt = (tasksRes.first['cnt'] as int?) ?? 0;

      return {
        'notes': nCnt,
        'folders': fCnt,
        'tasks': tCnt,
        'attachments': 0,
      };
    } catch (_) {
      return {'notes': 0, 'folders': 0, 'tasks': 0, 'attachments': 0};
    }
  }

  // ── Concurrency Protection Helper ─────────────────────────────────────────
  bool _startOperation(BackupOperationState state) {
    if (_operationState != BackupOperationState.idle) {
      _errorMessage =
          'Another operation is currently in progress. Please wait.';
      notifyListeners();
      return false;
    }
    _operationState = state;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();
    return true;
  }

  void _finishOperation() {
    _operationState = BackupOperationState.idle;
    _currentRestoreStage = null;
    notifyListeners();
  }

  void clearMessages() {
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();
  }

  // ── 1. Local Backup Creation ──────────────────────────────────────────────
  Future<BackupResult?> createLocalBackup({
    Directory? customBackupDir,
    Directory? customDocumentsDir,
  }) async {
    if (!_startOperation(BackupOperationState.creatingLocalBackup)) return null;

    try {
      final result = await _backupEngine.createBackup(
        customBackupDir: customBackupDir,
        customDocumentsDir: customDocumentsDir,
      );

      _lastLocalBackupResult = result;
      if (result.success) {
        _infoMessage =
            'Local backup created successfully (${result.noteCount} notes, ${result.folderCount} folders).';
      } else {
        _errorMessage = 'Local backup creation failed: ${result.error}';
      }
      return result;
    } catch (e) {
      _errorMessage =
          'An unexpected error occurred during local backup creation.';
      return BackupResult.failure(error: e.toString());
    } finally {
      _finishOperation();
    }
  }

  RemoteBackupMetadata? _lastUploadedCloudBackup;
  RemoteBackupMetadata? get lastUploadedCloudBackup => _lastUploadedCloudBackup;

  // ── 2. Cloud Backup Upload ────────────────────────────────────────────────
  Future<RemoteBackupMetadata?> uploadCloudBackup() async {
    if (!_startOperation(BackupOperationState.uploadingCloudBackup))
      return null;

    try {
      final localResult = _lastLocalBackupResult;
      final manifest = localResult?.validationResult?.manifest;
      if (localResult == null ||
          !localResult.success ||
          localResult.filePath == null ||
          manifest == null ||
          !File(localResult.filePath!).existsSync()) {
        _errorMessage =
            'Create a local backup before uploading it to Google Drive.';
        return null;
      }

      final localFile = File(localResult.filePath!);
      final remoteMetadata = await _storageAdapter.uploadBackup(
        localBackupFile: localFile,
        manifest: manifest,
      );

      _lastUploadedCloudBackup = remoteMetadata;
      _infoMessage = 'Backup uploaded to Google Drive successfully.';
      await fetchCloudBackups();
      return remoteMetadata;
    } on DriveStorageException catch (e) {
      _errorMessage = mapDriveError(e);
      return null;
    } catch (e) {
      _errorMessage = 'Failed to upload backup to cloud storage.';
      return null;
    } finally {
      _finishOperation();
    }
  }

  // ── 3. Fetch Cloud Backups Listing ────────────────────────────────────────
  Future<List<RemoteBackupMetadata>> fetchCloudBackups() async {
    if (_operationState != BackupOperationState.idle &&
        _operationState != BackupOperationState.uploadingCloudBackup &&
        _operationState != BackupOperationState.deletingCloudBackup) {
      return _remoteBackups;
    }

    final previousState = _operationState;
    if (previousState == BackupOperationState.idle) {
      _operationState = BackupOperationState.loadingCloudBackups;
      notifyListeners();
    }

    try {
      final list = await _storageAdapter.listBackups();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _remoteBackups = list;
      return list;
    } on DriveStorageException catch (e) {
      _errorMessage = mapDriveError(e);
      return const [];
    } catch (e) {
      debugPrint('fetchCloudBackups error: $e');
      _errorMessage =
          'Failed to retrieve cloud backup listing: ${e.toString()}';
      return const [];
    } finally {
      if (previousState == BackupOperationState.idle) {
        _finishOperation();
      }
    }
  }

  // ── 4. Restore from Backup (Cloud or Local) ───────────────────────────────
  Future<RestoreResult?> restoreBackup({
    required String backupFilePath,
    Directory? customDocumentsDir,
    bool forceOfflineOverride = false,
  }) async {
    if (!_startOperation(BackupOperationState.restoring)) return null;

    try {
      _currentRestoreStage = 'Validating backup...';
      notifyListeners();

      final result = await _restoreEngine.restoreFromBackup(
        backupFilePath: backupFilePath,
        customDocumentsDir: customDocumentsDir,
        forceOfflineOverride: forceOfflineOverride,
      );

      _lastRestoreResult = result;
      if (result.success) {
        _infoMessage =
            'Restore complete! Restored ${result.noteCount} notes, ${result.folderCount} folders, and ${result.taskCount} tasks.';
      } else {
        _errorMessage = mapRestoreError(result);
      }
      return result;
    } catch (e) {
      _errorMessage = 'The backup could not be restored safely.';
      return RestoreResult.failure(
        error: RestoreError(
          type: RestoreErrorType.databaseRestoreFailed,
          message: e.toString(),
        ),
      );
    } finally {
      _finishOperation();
    }
  }

  /// Inspects a local .qnb file safely via BackupValidator without mutating data or performing restore.
  Future<RemoteBackupMetadata?> inspectLocalBackup(File file) async {
    if (!file.existsSync()) {
      _errorMessage = 'Specified backup file does not exist on disk.';
      notifyListeners();
      return null;
    }
    if (!file.path.toLowerCase().endsWith('.qnb')) {
      _errorMessage =
          'Selected file is not a valid .qnb Quick Notes backup file.';
      notifyListeners();
      return null;
    }

    try {
      final zipBytes = file.readAsBytesSync();
      final archiveInput = BackupArchiveInput.fromZipBytes(zipBytes);
      final validationResult =
          await BackupValidator.validate(archiveInput: archiveInput);

      if (!validationResult.isValid || validationResult.manifest == null) {
        final firstError = validationResult.errors.isNotEmpty
            ? validationResult.errors.first.message
            : 'Backup validation failed.';
        _errorMessage =
            'This backup could not be verified and was not restored ($firstError).';
        notifyListeners();
        return null;
      }

      final manifest = validationResult.manifest!;
      return RemoteBackupMetadata(
        remoteFileId: file.path,
        fileName: p.basename(file.path),
        fileSizeBytes: file.lengthSync(),
        createdAt: manifest.createdAt,
        backupId: manifest.backupId,
        formatVersion: manifest.formatVersion,
        databaseSchemaVersion: manifest.databaseSchemaVersion,
        appVersion: manifest.appVersion ?? '1.0.0',
        noteCount: manifest.contents.notes,
        folderCount: manifest.contents.folders,
        taskCount: manifest.contents.tasks,
        attachmentCount: manifest.contents.attachments,
        providerUserIdHash: manifest.identity.providerUserIdHash,
        sha256Checksum: '',
      );
    } catch (_) {
      _errorMessage =
          'Selected file could not be parsed as a valid .qnb archive.';
      notifyListeners();
      return null;
    }
  }

  /// Restores from a local .qnb file safely.
  Future<RestoreResult?> restoreLocalBackup({
    required File localFile,
    Directory? customDocumentsDir,
    bool forceOfflineOverride = false,
  }) async {
    if (!localFile.existsSync()) {
      _errorMessage = 'Local backup file does not exist.';
      notifyListeners();
      return null;
    }
    return restoreBackup(
      backupFilePath: localFile.path,
      customDocumentsDir: customDocumentsDir,
      forceOfflineOverride: forceOfflineOverride,
    );
  }

  // ── 5. Cloud Restore Flow (Download -> Restore) ───────────────────────────
  Future<RestoreResult?> downloadAndRestoreCloudBackup({
    required String remoteFileId,
    required Directory tempDownloadDir,
    Directory? customDocumentsDir,
    bool forceOfflineOverride = false,
  }) async {
    if (!_startOperation(BackupOperationState.restoring)) return null;

    File? tempDownloadedFile;
    try {
      _currentRestoreStage = 'Downloading backup from Google Drive...';
      notifyListeners();

      final destFile = File(
          p.join(tempDownloadDir.path, 'downloaded_cloud_$remoteFileId.qnb'));
      tempDownloadedFile = await _storageAdapter.downloadBackup(
        remoteFileId: remoteFileId,
        destinationLocalFile: destFile,
      );

      _currentRestoreStage = 'Executing multi-resource restore...';
      notifyListeners();

      final result = await _restoreEngine.restoreFromBackup(
        backupFilePath: tempDownloadedFile.path,
        customDocumentsDir: customDocumentsDir,
        forceOfflineOverride: forceOfflineOverride,
      );

      _lastRestoreResult = result;
      if (result.success) {
        _infoMessage =
            'Cloud restore complete! Restored ${result.noteCount} notes, ${result.folderCount} folders, and ${result.taskCount} tasks.';
      } else {
        _errorMessage = mapRestoreError(result);
      }
      return result;
    } on DriveStorageException catch (e) {
      _errorMessage = mapDriveError(e);
      return null;
    } catch (e) {
      _errorMessage =
          'The cloud backup could not be downloaded or restored safely.';
      return null;
    } finally {
      if (tempDownloadedFile != null && tempDownloadedFile.existsSync()) {
        try {
          tempDownloadedFile.deleteSync();
        } catch (_) {}
      }
      _finishOperation();
    }
  }

  // ── 6. Delete Cloud Backup ────────────────────────────────────────────────
  Future<bool> deleteCloudBackup(dynamic target) async {
    if (!_startOperation(BackupOperationState.deletingCloudBackup))
      return false;

    final String remoteFileId = target is RemoteBackupMetadata
        ? target.remoteFileId
        : target.toString();

    try {
      await _storageAdapter.deleteBackup(remoteFileId);
      _infoMessage = 'Cloud backup deleted successfully.';
      _remoteBackups =
          _remoteBackups.where((b) => b.remoteFileId != remoteFileId).toList();
      notifyListeners();
      return true;
    } on DriveStorageException catch (e) {
      _errorMessage = mapDriveError(e);
      return false;
    } catch (e) {
      _errorMessage = 'Failed to delete remote cloud backup.';
      return false;
    } finally {
      _finishOperation();
    }
  }

  // ── 7. Human-Readable Error Mappings ─────────────────────────────────────
  static String mapDriveError(DriveStorageException exception) {
    switch (exception.type) {
      case DriveStorageErrorType.unauthenticated:
        return "Google Drive isn't connected. Please sign in with Google to enable cloud backups.";
      case DriveStorageErrorType.networkUnavailable:
        return 'No internet connection. Please check your network and try again.';
      case DriveStorageErrorType.permissionDenied:
        if (exception.message
            .contains('Google Drive permission denied (403):')) {
          final details = exception.message
              .split('Google Drive permission denied (403):')
              .last
              .trim();
          if (details.contains('disabled') ||
              details.contains('has not been used')) {
            return "Google Drive API is not enabled in Google Cloud Console. Please enable 'Google Drive API' for your project.";
          }
          if (details.isNotEmpty && details.length < 160) {
            return "Google Drive permission denied: $details";
          }
        }
        return "Quick Notes doesn't currently have permission to access Google Drive. Please grant Google Drive access when prompted.";
      case DriveStorageErrorType.backupNotFound:
        return 'This cloud backup is no longer available on Google Drive.';
      case DriveStorageErrorType.quotaExceeded:
      case DriveStorageErrorType.insufficientStorage:
        return 'Your Google Drive storage is full. Free up space and try again.';
      case DriveStorageErrorType.uploadFailed:
        return 'Failed to upload backup to Google Drive.';
      case DriveStorageErrorType.downloadFailed:
        return 'The backup file could not be downloaded safely.';
    }
  }

  static String mapRestoreError(RestoreResult result) {
    if (result.error == null) return 'Restore failed.';
    switch (result.error!.type) {
      case RestoreErrorType.identityMismatch:
        return 'Backup identity does not match your current Google account.';
      case RestoreErrorType.validationFailed:
      case RestoreErrorType.unsupportedSchema:
      case RestoreErrorType.invalidBackup:
        return 'This backup file is invalid, corrupted, or uses an unsupported database schema.';
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
        return 'Post-restore verification failed. Database and attachments were rolled back to safety snapshot.';
      case RestoreErrorType.cleanupFailed:
        return 'Restore completed, but temporary files could not be cleaned up.';
    }
  }
}
