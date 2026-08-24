import 'dart:convert';

/// RemoteBackupMetadata — Immutable, provider-neutral representation of remote backup file metadata.
///
/// Designed to provide all necessary metadata for UI listing, comparison, and verification
/// without requiring downloading the entire .qnb container file.
class RemoteBackupMetadata {
  final String remoteFileId;
  final String fileName;
  final int fileSizeBytes;
  final DateTime createdAt;
  final DateTime? modifiedAt;
  final String backupId;
  final int formatVersion;
  final int databaseSchemaVersion;
  final String appVersion;
  final int noteCount;
  final int folderCount;
  final int taskCount;
  final int attachmentCount;
  final String providerUserIdHash;
  final String sha256Checksum;

  const RemoteBackupMetadata({
    required this.remoteFileId,
    required this.fileName,
    required this.fileSizeBytes,
    required this.createdAt,
    this.modifiedAt,
    required this.backupId,
    required this.formatVersion,
    required this.databaseSchemaVersion,
    required this.appVersion,
    required this.noteCount,
    required this.folderCount,
    required this.taskCount,
    required this.attachmentCount,
    required this.providerUserIdHash,
    required this.sha256Checksum,
  });

  Map<String, dynamic> toJson() {
    return {
      'appVersion': appVersion,
      'attachmentCount': attachmentCount,
      'backupId': backupId,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'databaseSchemaVersion': databaseSchemaVersion,
      'fileName': fileName,
      'fileSizeBytes': fileSizeBytes,
      'folderCount': folderCount,
      'formatVersion': formatVersion,
      'modifiedAt': modifiedAt?.toUtc().toIso8601String(),
      'noteCount': noteCount,
      'providerUserIdHash': providerUserIdHash,
      'remoteFileId': remoteFileId,
      'sha256Checksum': sha256Checksum,
      'taskCount': taskCount,
    };
  }

  factory RemoteBackupMetadata.fromJson(Map<String, dynamic> map) {
    return RemoteBackupMetadata(
      remoteFileId: map['remoteFileId'] as String,
      fileName: map['fileName'] as String,
      fileSizeBytes: (map['fileSizeBytes'] as num).toInt(),
      createdAt: DateTime.parse(map['createdAt'] as String).toUtc(),
      modifiedAt: map['modifiedAt'] != null
          ? DateTime.parse(map['modifiedAt'] as String).toUtc()
          : null,
      backupId: map['backupId'] as String,
      formatVersion: (map['formatVersion'] as num).toInt(),
      databaseSchemaVersion: (map['databaseSchemaVersion'] as num).toInt(),
      appVersion: map['appVersion'] as String? ?? '1.1.0+2',
      noteCount: (map['noteCount'] as num).toInt(),
      folderCount: (map['folderCount'] as num).toInt(),
      taskCount: (map['taskCount'] as num).toInt(),
      attachmentCount: (map['attachmentCount'] as num).toInt(),
      providerUserIdHash: map['providerUserIdHash'] as String,
      sha256Checksum: map['sha256Checksum'] as String,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory RemoteBackupMetadata.fromJsonString(String jsonStr) {
    return RemoteBackupMetadata.fromJson(
        jsonDecode(jsonStr) as Map<String, dynamic>);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RemoteBackupMetadata &&
          runtimeType == other.runtimeType &&
          remoteFileId == other.remoteFileId &&
          backupId == other.backupId &&
          sha256Checksum == other.sha256Checksum;

  @override
  int get hashCode =>
      remoteFileId.hashCode ^ backupId.hashCode ^ sha256Checksum.hashCode;

  @override
  String toString() =>
      'RemoteBackupMetadata(id: $remoteFileId, name: $fileName, backupId: $backupId, schema: $databaseSchemaVersion, bytes: $fileSizeBytes)';
}
