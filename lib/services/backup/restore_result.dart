import 'backup_validation_result.dart';

/// Categories of restore failures.
enum RestoreErrorType {
  validationFailed,
  identityMismatch,
  unsupportedSchema,
  invalidBackup,
  safetySnapshotFailed,
  stagingFailed,
  databaseRestoreFailed,
  attachmentRestoreFailed,
  filesystemCommitFailed,
  verificationFailed,
  cleanupFailed,
}

/// Single structured restore error.
class RestoreError {
  final RestoreErrorType type;
  final String message;
  final String? target;

  const RestoreError({
    required this.type,
    required this.message,
    this.target,
  });

  @override
  String toString() =>
      '[$type] $message${target != null ? " (target: $target)" : ""}';
}

/// RestoreResult — Structured outcome report emitted by RestoreEngine.
class RestoreResult {
  final bool success;
  final String? backupId;
  final DateTime? restoredAt;
  final int folderCount;
  final int noteCount;
  final int taskCount;
  final int attachmentCount;
  final BackupIdentityStatus identityStatus;
  final BackupValidationResult? validationResult;
  final String? safetySnapshotPath;
  final bool verificationPassed;
  final RestoreError? error;

  const RestoreResult({
    required this.success,
    this.backupId,
    this.restoredAt,
    this.folderCount = 0,
    this.noteCount = 0,
    this.taskCount = 0,
    this.attachmentCount = 0,
    this.identityStatus = BackupIdentityStatus.unknown,
    this.validationResult,
    this.safetySnapshotPath,
    this.verificationPassed = false,
    this.error,
  });

  factory RestoreResult.failure({
    required RestoreError error,
    BackupValidationResult? validationResult,
    String? safetySnapshotPath,
  }) {
    return RestoreResult(
      success: false,
      error: error,
      validationResult: validationResult,
      safetySnapshotPath: safetySnapshotPath,
    );
  }

  factory RestoreResult.success({
    required String backupId,
    required DateTime restoredAt,
    required int folderCount,
    required int noteCount,
    required int taskCount,
    required int attachmentCount,
    required BackupIdentityStatus identityStatus,
    required BackupValidationResult validationResult,
    required String safetySnapshotPath,
  }) {
    return RestoreResult(
      success: true,
      backupId: backupId,
      restoredAt: restoredAt,
      folderCount: folderCount,
      noteCount: noteCount,
      taskCount: taskCount,
      attachmentCount: attachmentCount,
      identityStatus: identityStatus,
      validationResult: validationResult,
      safetySnapshotPath: safetySnapshotPath,
      verificationPassed: true,
    );
  }
}
