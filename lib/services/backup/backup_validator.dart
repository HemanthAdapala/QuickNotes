import 'dart:convert';
import 'backup_format.dart';
import 'backup_integrity.dart';
import 'backup_manifest.dart';
import 'backup_serializer.dart';
import 'backup_validation_result.dart';
import 'zip_decoder.dart';

/// BackupArchiveInput — Abstract in-memory representation of a .qnb container payload.
class BackupArchiveInput {
  final Map<String, List<int>> entries;

  BackupArchiveInput(this.entries);

  factory BackupArchiveInput.fromZipBytes(List<int> zipBytes) {
    final zipEntries = ZipDecoder.decode(zipBytes);
    final map = <String, List<int>>{};
    for (final entry in zipEntries) {
      map[entry.name] = entry.data;
    }
    return BackupArchiveInput(map);
  }

  bool hasFile(String name) => entries.containsKey(name);

  List<int>? getFileBytes(String name) => entries[name];

  String? getFileString(String name) {
    final bytes = entries[name];
    if (bytes == null) return null;
    return utf8.decode(bytes);
  }
}

/// BackupValidator — Staged validation engine & security boundary for Quick Notes Backup Format V1.
///
/// Pure, read-only validation pipeline evaluating archive safety, format compatibility,
/// cryptographic SHA-256 integrity, structural entity syntax, and relationship integrity.
class BackupValidator {
  // ── Safety & Resource Abuse Limits ────────────────────────────────────────
  static const int maxEntryCount = 5000;
  static const int maxSingleFileSize = 104857600; // 100 MB
  static const int maxTotalUncompressedSize = 524288000; // 500 MB

  static const List<String> dangerousExtensions = [
    '.exe',
    '.sh',
    '.apk',
    '.bat',
    '.cmd',
    '.dll',
    '.bin',
    '.so',
    '.js',
    '.vbs'
  ];

  /// Executes the complete 8-stage validation pipeline on an untrusted backup archive.
  static Future<BackupValidationResult> validate({
    required BackupArchiveInput archiveInput,
    String? expectedProviderUserIdHash,
  }) async {
    final errors = <BackupValidationError>[];
    final warnings = <BackupValidationWarning>[];

    // ── STAGE 1: Container Safety & Path Traversal Inspection ───────────────
    var totalSize = 0;

    if (archiveInput.entries.length > maxEntryCount) {
      errors.add(const BackupValidationError(
        type: BackupValidationErrorType.resourceLimitExceeded,
        message:
            'Archive contains too many entries (exceeds 5,000 maximum entry limit)',
      ));
    }

    for (final entryName in archiveInput.entries.keys) {
      final bytes = archiveInput.entries[entryName]!;

      if (bytes.length > maxSingleFileSize) {
        errors.add(BackupValidationError(
          type: BackupValidationErrorType.resourceLimitExceeded,
          message: 'Entry exceeds maximum 100 MB single file limit',
          targetPath: entryName,
        ));
      }
      totalSize += bytes.length;

      // Path Traversal Detection
      final normalizedPath = entryName.replaceAll('\\', '/');
      if (normalizedPath.contains('../') ||
          normalizedPath.contains('..\\') ||
          normalizedPath.startsWith('/') ||
          RegExp(r'^[a-zA-Z]:').hasMatch(entryName)) {
        errors.add(BackupValidationError(
          type: BackupValidationErrorType.unsafeArchive,
          message: 'Path traversal attempt detected in archive entry path',
          targetPath: entryName,
        ));
      }

      // Dangerous Extension Detection
      final lowerName = entryName.toLowerCase();
      for (final ext in dangerousExtensions) {
        if (lowerName.endsWith(ext)) {
          errors.add(BackupValidationError(
            type: BackupValidationErrorType.unsafeArchive,
            message: 'Suspicious executable payload extension detected',
            targetPath: entryName,
          ));
        }
      }
    }

    if (totalSize > maxTotalUncompressedSize) {
      errors.add(const BackupValidationError(
        type: BackupValidationErrorType.resourceLimitExceeded,
        message: 'Archive uncompressed total size exceeds 500 MB safety limit',
      ));
    }

    if (errors.isNotEmpty) {
      return BackupValidationResult.failure(errors: errors);
    }

    // ── STAGE 2: Required Structure Inspection ──────────────────────────────
    const requiredFiles = [
      BackupFormat.manifestFileName,
      BackupFormat.notesDataFileName,
      BackupFormat.foldersDataFileName,
      BackupFormat.tasksDataFileName,
    ];

    for (final reqFile in requiredFiles) {
      if (!archiveInput.hasFile(reqFile)) {
        errors.add(BackupValidationError(
          type: BackupValidationErrorType.missingRequiredFile,
          message: 'Required container payload file is missing',
          targetPath: reqFile,
        ));
      }
    }

    if (errors.isNotEmpty) {
      return BackupValidationResult.failure(errors: errors);
    }

    // ── STAGE 3: Manifest Parsing & Format Version Inspection ──────────────
    late BackupManifest manifest;
    try {
      final manifestJsonStr =
          archiveInput.getFileString(BackupFormat.manifestFileName)!;
      manifest = BackupManifest.fromJsonString(manifestJsonStr);
    } catch (e) {
      errors.add(BackupValidationError(
        type: BackupValidationErrorType.invalidManifest,
        message: 'Failed to parse manifest.json: ${e.toString()}',
        targetPath: BackupFormat.manifestFileName,
      ));
      return BackupValidationResult.failure(errors: errors);
    }

    // Format Version Check
    if (!BackupFormat.isSupportedFormatVersion(manifest.formatVersion)) {
      errors.add(BackupValidationError(
        type: BackupValidationErrorType.unsupportedFormatVersion,
        message:
            'Unsupported formatVersion ${manifest.formatVersion} (expected ${BackupFormat.formatVersion})',
        targetPath: BackupFormat.manifestFileName,
      ));
    }

    // Database Schema Version Classification
    var schemaStatus = BackupSchemaStatus.unknown;
    if (manifest.databaseSchemaVersion == BackupFormat.databaseSchemaVersion) {
      schemaStatus = BackupSchemaStatus.exactMatch;
    } else {
      schemaStatus =
          manifest.databaseSchemaVersion < BackupFormat.databaseSchemaVersion
              ? BackupSchemaStatus.compatibleOlderSchema
              : BackupSchemaStatus.unsupportedNewerSchema;
      errors.add(BackupValidationError(
        type: BackupValidationErrorType.unsupportedSchemaVersion,
        message:
            'Backup database schema v${manifest.databaseSchemaVersion} is unsupported (expected exact v${BackupFormat.databaseSchemaVersion})',
        targetPath: BackupFormat.manifestFileName,
      ));
    }

    if (errors.isNotEmpty) {
      return BackupValidationResult.failure(
        errors: errors,
        warnings: warnings,
        manifest: manifest,
        formatVersion: manifest.formatVersion,
        databaseSchemaVersion: manifest.databaseSchemaVersion,
        backupId: manifest.backupId,
        schemaStatus: schemaStatus,
      );
    }

    // ── STAGE 4: Identity Inspection ─────────────────────────────────────────
    var identityStatus = BackupIdentityStatus.unknown;
    if (expectedProviderUserIdHash != null &&
        expectedProviderUserIdHash.isNotEmpty) {
      if (manifest.identity.provider == 'google') {
        if (manifest.identity.providerUserIdHash ==
            expectedProviderUserIdHash) {
          identityStatus = BackupIdentityStatus.match;
        } else {
          identityStatus = BackupIdentityStatus.mismatch;
          errors.add(const BackupValidationError(
            type: BackupValidationErrorType.identityMismatch,
            message:
                'Backup identity does not match the active authenticated account',
          ));
        }
      } else {
        identityStatus = BackupIdentityStatus.offlineOverrideNeeded;
        warnings.add(const BackupValidationWarning(
          type: BackupValidationWarningType.offlineIdentityOverride,
          message:
              'Backup created by offline identity; manual restoration confirmation required',
        ));
      }
    }

    // ── STAGE 5: Cryptographic SHA-256 Integrity Verification ──────────────
    // 5a. Verify Self-Checksum of manifest.json
    final declaredManifestChecksum = manifest.checksums['manifest'];
    if (declaredManifestChecksum == null || declaredManifestChecksum.isEmpty) {
      errors.add(const BackupValidationError(
        type: BackupValidationErrorType.missingChecksum,
        message: 'Manifest missing self-checksum entry in checksums map',
        targetPath: BackupFormat.manifestFileName,
      ));
    } else {
      final computedManifestChecksum = manifest.computeManifestChecksum();
      if (computedManifestChecksum != declaredManifestChecksum) {
        errors.add(const BackupValidationError(
          type: BackupValidationErrorType.checksumMismatch,
          message: 'Manifest self-checksum verification failed',
          targetPath: BackupFormat.manifestFileName,
        ));
      }
    }

    // 5b. Verify Data JSON Checksums
    final dataFiles = [
      BackupFormat.notesDataFileName,
      BackupFormat.foldersDataFileName,
      BackupFormat.tasksDataFileName,
    ];

    for (final dataFile in dataFiles) {
      final declaredHash = manifest.checksums[dataFile];
      if (declaredHash == null) {
        errors.add(BackupValidationError(
          type: BackupValidationErrorType.missingChecksum,
          message: 'Checksum entry missing for data payload file',
          targetPath: dataFile,
        ));
      } else {
        final bytes = archiveInput.getFileBytes(dataFile)!;
        final computedHash = BackupIntegrity.sha256Bytes(bytes);
        if (computedHash != declaredHash) {
          errors.add(BackupValidationError(
            type: BackupValidationErrorType.checksumMismatch,
            message: 'SHA-256 checksum mismatch for payload file',
            targetPath: dataFile,
          ));
        }
      }
    }

    // 5c. Verify Attachment Checksums
    final attachmentFiles = archiveInput.entries.keys
        .where((k) =>
            k.startsWith('${BackupFormat.attachmentsDirectory}/') &&
            k.length > BackupFormat.attachmentsDirectory.length + 1)
        .toList();

    for (final attFile in attachmentFiles) {
      final declaredHash = manifest.checksums[attFile];
      if (declaredHash == null) {
        errors.add(BackupValidationError(
          type: BackupValidationErrorType.missingChecksum,
          message:
              'Attachment file present in archive without corresponding manifest checksum',
          targetPath: attFile,
        ));
      } else {
        final bytes = archiveInput.getFileBytes(attFile)!;
        final computedHash = BackupIntegrity.sha256Bytes(bytes);
        if (computedHash != declaredHash) {
          errors.add(BackupValidationError(
            type: BackupValidationErrorType.checksumMismatch,
            message: 'SHA-256 checksum mismatch for attachment asset',
            targetPath: attFile,
          ));
        }
      }
    }

    if (errors.isNotEmpty) {
      return BackupValidationResult.failure(
        errors: errors,
        warnings: warnings,
        manifest: manifest,
        formatVersion: manifest.formatVersion,
        databaseSchemaVersion: manifest.databaseSchemaVersion,
        backupId: manifest.backupId,
        identityStatus: identityStatus,
        schemaStatus: schemaStatus,
      );
    }

    // ── STAGE 6: Entity Payload & Syntax Inspection ─────────────────────────
    final folderIds = <String>{};
    final noteIds = <String>{};
    final taskIds = <String>{};

    List<dynamic> rawFolders = [];
    List<dynamic> rawNotes = [];
    List<dynamic> rawTasks = [];

    // Parse Folders
    try {
      rawFolders = jsonDecode(
          archiveInput.getFileString(BackupFormat.foldersDataFileName)!);
      for (final item in rawFolders) {
        final map = Map<String, dynamic>.from(item as Map);
        final folder = BackupSerializer.deserializeFolder(map);
        if (folderIds.contains(folder.id)) {
          errors.add(BackupValidationError(
            type: BackupValidationErrorType.duplicateEntityId,
            message: 'Duplicate folder primary key detected: ${folder.id}',
            targetPath: BackupFormat.foldersDataFileName,
          ));
        }
        folderIds.add(folder.id);
      }
    } catch (e) {
      errors.add(BackupValidationError(
        type: BackupValidationErrorType.malformedJson,
        message: 'Malformed folders JSON: ${e.toString()}',
        targetPath: BackupFormat.foldersDataFileName,
      ));
    }

    // Parse Notes
    try {
      rawNotes = jsonDecode(
          archiveInput.getFileString(BackupFormat.notesDataFileName)!);
      for (final item in rawNotes) {
        final map = Map<String, dynamic>.from(item as Map);
        final note = BackupSerializer.deserializeNote(map);
        if (noteIds.contains(note.id)) {
          errors.add(BackupValidationError(
            type: BackupValidationErrorType.duplicateEntityId,
            message: 'Duplicate note primary key detected: ${note.id}',
            targetPath: BackupFormat.notesDataFileName,
          ));
        }
        noteIds.add(note.id);
      }
    } catch (e) {
      errors.add(BackupValidationError(
        type: BackupValidationErrorType.malformedJson,
        message: 'Malformed notes JSON: ${e.toString()}',
        targetPath: BackupFormat.notesDataFileName,
      ));
    }

    // Parse Tasks
    try {
      rawTasks = jsonDecode(
          archiveInput.getFileString(BackupFormat.tasksDataFileName)!);
      for (final item in rawTasks) {
        final map = Map<String, dynamic>.from(item as Map);
        final task = BackupSerializer.deserializeTask(map);
        if (taskIds.contains(task.id)) {
          errors.add(BackupValidationError(
            type: BackupValidationErrorType.duplicateEntityId,
            message: 'Duplicate task primary key detected: ${task.id}',
            targetPath: BackupFormat.tasksDataFileName,
          ));
        }
        taskIds.add(task.id);
      }
    } catch (e) {
      errors.add(BackupValidationError(
        type: BackupValidationErrorType.malformedJson,
        message: 'Malformed tasks JSON: ${e.toString()}',
        targetPath: BackupFormat.tasksDataFileName,
      ));
    }

    if (errors.isNotEmpty) {
      return BackupValidationResult.failure(
        errors: errors,
        warnings: warnings,
        manifest: manifest,
        formatVersion: manifest.formatVersion,
        databaseSchemaVersion: manifest.databaseSchemaVersion,
        backupId: manifest.backupId,
        identityStatus: identityStatus,
        schemaStatus: schemaStatus,
      );
    }

    // ── STAGE 7: Relationship & Attachment Reference Inspection ─────────────
    // Validate folder parentId references
    for (final item in rawFolders) {
      final map = Map<String, dynamic>.from(item as Map);
      final parentId = map['parentId'] as String?;
      if (parentId != null &&
          parentId.isNotEmpty &&
          !folderIds.contains(parentId)) {
        errors.add(BackupValidationError(
          type: BackupValidationErrorType.invalidRelationship,
          message:
              'Folder parentId "$parentId" does not exist in backup dataset',
          targetPath: BackupFormat.foldersDataFileName,
        ));
      }
    }

    // Validate Note folderId & Attachment References
    for (final item in rawNotes) {
      final map = Map<String, dynamic>.from(item as Map);
      final folderId = map['folderId'] as String?;
      if (folderId != null &&
          folderId.isNotEmpty &&
          !folderIds.contains(folderId)) {
        errors.add(BackupValidationError(
          type: BackupValidationErrorType.invalidRelationship,
          message: 'Note folderId "$folderId" does not exist in backup dataset',
          targetPath: BackupFormat.notesDataFileName,
        ));
      }

      // Check attachment references in Note
      final content = map['content'] as String? ?? '';
      final rawAtts = map['attachments'] as List? ?? [];

      final referencedFilenames = <String>{};
      final reg = RegExp(r'attachment://([^\s\)\"]+)');
      for (final match in reg.allMatches(content)) {
        referencedFilenames.add(match.group(1)!);
      }

      for (final attMap in rawAtts) {
        if (attMap is Map) {
          final pathStr =
              attMap['path'] as String? ?? attMap['url'] as String? ?? '';
          if (pathStr.startsWith(BackupFormat.attachmentSchemePrefix)) {
            referencedFilenames.add(
                pathStr.substring(BackupFormat.attachmentSchemePrefix.length));
          }
        }
      }

      for (final filename in referencedFilenames) {
        final expectedArchivePath =
            '${BackupFormat.attachmentsDirectory}/$filename';
        if (!archiveInput.hasFile(expectedArchivePath)) {
          errors.add(BackupValidationError(
            type: BackupValidationErrorType.invalidAttachmentReference,
            message:
                'Dangling attachment reference "$filename" missing in archive',
            targetPath: expectedArchivePath,
          ));
        }
      }
    }

    // Validate Task folderId references
    for (final item in rawTasks) {
      final map = Map<String, dynamic>.from(item as Map);
      final folderId = map['folderId'] as String?;
      if (folderId != null &&
          folderId.isNotEmpty &&
          !folderIds.contains(folderId)) {
        errors.add(BackupValidationError(
          type: BackupValidationErrorType.invalidRelationship,
          message: 'Task folderId "$folderId" does not exist in backup dataset',
          targetPath: BackupFormat.tasksDataFileName,
        ));
      }
    }

    // ── STAGE 8: Content Counts Verification ──────────────────────────────
    if (manifest.contents.folders != rawFolders.length) {
      errors.add(BackupValidationError(
        type: BackupValidationErrorType.contentCountMismatch,
        message:
            'Manifest folders count (${manifest.contents.folders}) does not match actual folder records (${rawFolders.length})',
      ));
    }

    if (manifest.contents.notes != rawNotes.length) {
      errors.add(BackupValidationError(
        type: BackupValidationErrorType.contentCountMismatch,
        message:
            'Manifest notes count (${manifest.contents.notes}) does not match actual note records (${rawNotes.length})',
      ));
    }

    if (manifest.contents.tasks != rawTasks.length) {
      errors.add(BackupValidationError(
        type: BackupValidationErrorType.contentCountMismatch,
        message:
            'Manifest tasks count (${manifest.contents.tasks}) does not match actual task records (${rawTasks.length})',
      ));
    }

    if (manifest.contents.attachments != attachmentFiles.length) {
      errors.add(BackupValidationError(
        type: BackupValidationErrorType.contentCountMismatch,
        message:
            'Manifest attachments count (${manifest.contents.attachments}) does not match actual attachment assets (${attachmentFiles.length})',
      ));
    }

    if (errors.isNotEmpty) {
      return BackupValidationResult.failure(
        errors: errors,
        warnings: warnings,
        manifest: manifest,
        formatVersion: manifest.formatVersion,
        databaseSchemaVersion: manifest.databaseSchemaVersion,
        backupId: manifest.backupId,
        identityStatus: identityStatus,
        schemaStatus: schemaStatus,
      );
    }

    return BackupValidationResult.success(
      formatVersion: manifest.formatVersion,
      databaseSchemaVersion: manifest.databaseSchemaVersion,
      backupId: manifest.backupId,
      identityStatus: identityStatus,
      schemaStatus: schemaStatus,
      manifest: manifest,
      warnings: warnings,
    );
  }
}
