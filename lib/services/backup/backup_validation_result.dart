import 'backup_manifest.dart';

/// Categories of validation errors that block a backup from proceeding to restore.
enum BackupValidationErrorType {
  invalidContainer,
  unsafeArchive,
  resourceLimitExceeded,
  missingRequiredFile,
  invalidManifest,
  unsupportedFormatVersion,
  unsupportedSchemaVersion,
  checksumMismatch,
  missingChecksum,
  malformedJson,
  invalidEntity,
  duplicateEntityId,
  invalidRelationship,
  invalidAttachmentReference,
  contentCountMismatch,
  identityMismatch,
}

/// Non-blocking validation warnings.
enum BackupValidationWarningType {
  compatibleOlderSchema,
  offlineIdentityOverride,
}

/// Identity alignment classification.
enum BackupIdentityStatus {
  match,
  mismatch,
  offlineOverrideNeeded,
  unknown,
}

/// SQLite database schema alignment classification.
enum BackupSchemaStatus {
  exactMatch,
  compatibleOlderSchema,
  unsupportedNewerSchema,
  unknown,
}

/// Single structured validation error item.
class BackupValidationError {
  final BackupValidationErrorType type;
  final String message;
  final String? targetPath;

  const BackupValidationError({
    required this.type,
    required this.message,
    this.targetPath,
  });

  @override
  String toString() => '[$type] $message${targetPath != null ? " (target: $targetPath)" : ""}';
}

/// Single structured validation warning item.
class BackupValidationWarning {
  final BackupValidationWarningType type;
  final String message;
  final String? targetPath;

  const BackupValidationWarning({
    required this.type,
    required this.message,
    this.targetPath,
  });

  @override
  String toString() => '[$type] $message${targetPath != null ? " (target: $targetPath)" : ""}';
}

/// Complete, structured evaluation report emitted by BackupValidator.
class BackupValidationResult {
  final bool isValid;
  final int? formatVersion;
  final int? databaseSchemaVersion;
  final String? backupId;
  final BackupIdentityStatus identityStatus;
  final BackupSchemaStatus schemaStatus;
  final List<BackupValidationError> errors;
  final List<BackupValidationWarning> warnings;
  final BackupManifest? manifest;

  const BackupValidationResult({
    required this.isValid,
    this.formatVersion,
    this.databaseSchemaVersion,
    this.backupId,
    this.identityStatus = BackupIdentityStatus.unknown,
    this.schemaStatus = BackupSchemaStatus.unknown,
    this.errors = const [],
    this.warnings = const [],
    this.manifest,
  });

  factory BackupValidationResult.failure({
    required List<BackupValidationError> errors,
    List<BackupValidationWarning> warnings = const [],
    int? formatVersion,
    int? databaseSchemaVersion,
    String? backupId,
    BackupIdentityStatus identityStatus = BackupIdentityStatus.unknown,
    BackupSchemaStatus schemaStatus = BackupSchemaStatus.unknown,
    BackupManifest? manifest,
  }) {
    return BackupValidationResult(
      isValid: false,
      formatVersion: formatVersion,
      databaseSchemaVersion: databaseSchemaVersion,
      backupId: backupId,
      identityStatus: identityStatus,
      schemaStatus: schemaStatus,
      errors: errors,
      warnings: warnings,
      manifest: manifest,
    );
  }

  factory BackupValidationResult.success({
    required int formatVersion,
    required int databaseSchemaVersion,
    required String backupId,
    required BackupIdentityStatus identityStatus,
    required BackupSchemaStatus schemaStatus,
    required BackupManifest manifest,
    List<BackupValidationWarning> warnings = const [],
  }) {
    return BackupValidationResult(
      isValid: true,
      formatVersion: formatVersion,
      databaseSchemaVersion: databaseSchemaVersion,
      backupId: backupId,
      identityStatus: identityStatus,
      schemaStatus: schemaStatus,
      errors: const [],
      warnings: warnings,
      manifest: manifest,
    );
  }
}
