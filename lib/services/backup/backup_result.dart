import 'backup_validation_result.dart';

/// BackupResult — Structured outcome report emitted by BackupEngine.
class BackupResult {
  final bool success;
  final String? filePath;
  final String? backupId;
  final DateTime? createdAt;
  final int? fileSize;
  final int noteCount;
  final int folderCount;
  final int taskCount;
  final int attachmentCount;
  final BackupValidationResult? validationResult;
  final String? error;

  const BackupResult({
    required this.success,
    this.filePath,
    this.backupId,
    this.createdAt,
    this.fileSize,
    this.noteCount = 0,
    this.folderCount = 0,
    this.taskCount = 0,
    this.attachmentCount = 0,
    this.validationResult,
    this.error,
  });

  factory BackupResult.failure({
    required String error,
    BackupValidationResult? validationResult,
  }) {
    return BackupResult(
      success: false,
      error: error,
      validationResult: validationResult,
    );
  }

  factory BackupResult.success({
    required String filePath,
    required String backupId,
    required DateTime createdAt,
    required int fileSize,
    required int noteCount,
    required int folderCount,
    required int taskCount,
    required int attachmentCount,
    required BackupValidationResult validationResult,
  }) {
    return BackupResult(
      success: true,
      filePath: filePath,
      backupId: backupId,
      createdAt: createdAt,
      fileSize: fileSize,
      noteCount: noteCount,
      folderCount: folderCount,
      taskCount: taskCount,
      attachmentCount: attachmentCount,
      validationResult: validationResult,
    );
  }
}
