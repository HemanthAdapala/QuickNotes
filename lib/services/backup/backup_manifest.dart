import 'dart:convert';
import 'backup_format.dart';
import 'backup_integrity.dart';

/// Identity metadata included in the backup manifest to enforce identity isolation rules.
class BackupManifestIdentity {
  final String provider;
  final String providerUserIdHash;
  final String? email;

  BackupManifestIdentity({
    required this.provider,
    required this.providerUserIdHash,
    this.email,
  });

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'provider': provider,
      'providerUserIdHash': providerUserIdHash,
    };
  }

  factory BackupManifestIdentity.fromMap(Map<String, dynamic> map) {
    return BackupManifestIdentity(
      provider: map['provider'] as String? ?? 'offline',
      providerUserIdHash: map['providerUserIdHash'] as String? ?? '',
      email: map['email'] as String?,
    );
  }
}

/// Content entity counts summary stored in the backup manifest.
class BackupContentCounts {
  final int folders;
  final int notes;
  final int tasks;
  final int attachments;

  BackupContentCounts({
    required this.folders,
    required this.notes,
    required this.tasks,
    required this.attachments,
  });

  Map<String, dynamic> toMap() {
    return {
      'attachments': attachments,
      'folders': folders,
      'notes': notes,
      'tasks': tasks,
    };
  }

  factory BackupContentCounts.fromMap(Map<String, dynamic> map) {
    return BackupContentCounts(
      folders: (map['folders'] as num?)?.toInt() ?? 0,
      notes: (map['notes'] as num?)?.toInt() ?? 0,
      tasks: (map['tasks'] as num?)?.toInt() ?? 0,
      attachments: (map['attachments'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Format V1 Manifest Model representing metadata, identity context, content counts,
/// and SHA-256 checksum maps.
class BackupManifest {
  final int formatVersion;
  final String backupId;
  final DateTime createdAt;
  final String appVersion;
  final int databaseSchemaVersion;
  final BackupManifestIdentity identity;
  final BackupContentCounts contents;
  final Map<String, String> checksums;

  BackupManifest({
    this.formatVersion = BackupFormat.formatVersion,
    required this.backupId,
    required this.createdAt,
    this.appVersion = BackupFormat.defaultAppVersion,
    this.databaseSchemaVersion = BackupFormat.databaseSchemaVersion,
    required this.identity,
    required this.contents,
    required this.checksums,
  });

  /// Computes the deterministic SHA-256 checksum of this manifest file itself.
  ///
  /// Self-Checksum Rule:
  /// 1. Takes map representation of manifest.
  /// 2. Copies checksums map WITHOUT the 'manifest' key.
  /// 3. Canonicalizes JSON keys alphabetically and encodes to UTF-8 string.
  /// 4. Returns SHA-256 digest of that canonical string.
  String computeManifestChecksum() {
    final map = toMap();
    final checksumsMap = Map<String, dynamic>.from(map['checksums'] as Map);
    checksumsMap.remove('manifest');
    map['checksums'] = checksumsMap;

    final canonicalJson = BackupIntegrity.encodeDeterministicJson(map);
    return BackupIntegrity.sha256String(canonicalJson);
  }

  /// Converts manifest to a deterministic JSON map with sorted keys.
  Map<String, dynamic> toMap() {
    return {
      'appVersion': appVersion,
      'backupId': backupId,
      'checksums': Map<String, String>.from(checksums),
      'contents': contents.toMap(),
      'createdAt': createdAt.toUtc().toIso8601String(),
      'databaseSchemaVersion': databaseSchemaVersion,
      'formatVersion': formatVersion,
      'identity': identity.toMap(),
    };
  }

  /// Encodes manifest map to a deterministic JSON string.
  String toJsonString() {
    return BackupIntegrity.encodeDeterministicJson(toMap());
  }

  factory BackupManifest.fromMap(Map<String, dynamic> map) {
    final rawChecksums = map['checksums'];
    final checksums = <String, String>{};
    if (rawChecksums is Map) {
      rawChecksums.forEach((key, value) {
        checksums[key.toString()] = value.toString();
      });
    }

    return BackupManifest(
      formatVersion: (map['formatVersion'] as num?)?.toInt() ?? BackupFormat.formatVersion,
      backupId: map['backupId'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      appVersion: map['appVersion'] as String? ?? BackupFormat.defaultAppVersion,
      databaseSchemaVersion: (map['databaseSchemaVersion'] as num?)?.toInt() ?? BackupFormat.databaseSchemaVersion,
      identity: BackupManifestIdentity.fromMap(map['identity'] as Map<String, dynamic>? ?? {}),
      contents: BackupContentCounts.fromMap(map['contents'] as Map<String, dynamic>? ?? {}),
      checksums: checksums,
    );
  }

  factory BackupManifest.fromJsonString(String jsonStr) {
    final Map<String, dynamic> map = jsonDecode(jsonStr);
    return BackupManifest.fromMap(map);
  }
}
