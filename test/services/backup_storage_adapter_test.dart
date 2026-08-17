import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/services/backup/backup_manifest.dart';
import 'package:quick_notes/services/backup/backup_storage_adapter.dart';
import 'package:quick_notes/services/backup/drive_storage_exception.dart';
import 'package:quick_notes/services/backup/remote_backup_metadata.dart';

/// Test double implementing BackupStorageAdapter without third-party mocking packages.
class MockBackupStorageAdapter implements BackupStorageAdapter {
  final Map<String, RemoteBackupMetadata> _remoteStore = {};
  final Map<String, List<int>> _fileBytesStore = {};

  bool shouldFailUpload = false;
  bool shouldFailDownload = false;
  bool shouldFailAuth = false;

  @override
  Future<RemoteBackupMetadata> uploadBackup({
    required File localBackupFile,
    required BackupManifest manifest,
  }) async {
    if (shouldFailAuth) {
      throw const DriveStorageException(
        type: DriveStorageErrorType.unauthenticated,
        message: 'Google OAuth session expired or unauthenticated',
      );
    }
    if (shouldFailUpload) {
      throw const DriveStorageException(
        type: DriveStorageErrorType.uploadFailed,
        message: 'Simulated network failure during cloud backup upload',
      );
    }

    final bytes = localBackupFile.existsSync() ? localBackupFile.readAsBytesSync() : <int>[];
    final fileId = 'drive_file_${manifest.backupId}';
    final fileName = 'quick_notes_backup_${manifest.backupId}.qnb';

    final metadata = RemoteBackupMetadata(
      remoteFileId: fileId,
      fileName: fileName,
      fileSizeBytes: bytes.length,
      createdAt: manifest.createdAt,
      backupId: manifest.backupId,
      formatVersion: manifest.formatVersion,
      databaseSchemaVersion: manifest.databaseSchemaVersion,
      appVersion: manifest.appVersion,
      noteCount: manifest.contents.notes,
      folderCount: manifest.contents.folders,
      taskCount: manifest.contents.tasks,
      attachmentCount: manifest.contents.attachments,
      providerUserIdHash: manifest.identity.providerUserIdHash,
      sha256Checksum: manifest.checksums['manifest'] ?? 'dummy_hash',
    );

    _remoteStore[fileId] = metadata;
    _fileBytesStore[fileId] = bytes;
    return metadata;
  }

  @override
  Future<List<RemoteBackupMetadata>> listBackups() async {
    if (shouldFailAuth) {
      throw const DriveStorageException(
        type: DriveStorageErrorType.unauthenticated,
        message: 'Google OAuth session expired or unauthenticated',
      );
    }
    return _remoteStore.values.toList();
  }

  @override
  Future<File> downloadBackup({
    required String remoteFileId,
    required File destinationLocalFile,
  }) async {
    if (shouldFailAuth) {
      throw const DriveStorageException(
        type: DriveStorageErrorType.unauthenticated,
        message: 'Google OAuth session expired or unauthenticated',
      );
    }
    if (shouldFailDownload) {
      throw const DriveStorageException(
        type: DriveStorageErrorType.downloadFailed,
        message: 'Simulated stream interrupt during download',
      );
    }
    if (!_remoteStore.containsKey(remoteFileId)) {
      throw DriveStorageException(
        type: DriveStorageErrorType.backupNotFound,
        message: 'Remote backup file not found: $remoteFileId',
      );
    }

    final bytes = _fileBytesStore[remoteFileId] ?? [];
    if (!destinationLocalFile.parent.existsSync()) {
      destinationLocalFile.parent.createSync(recursive: true);
    }
    destinationLocalFile.writeAsBytesSync(bytes, flush: true);
    return destinationLocalFile;
  }

  @override
  Future<void> deleteBackup(String remoteFileId) async {
    if (shouldFailAuth) {
      throw const DriveStorageException(
        type: DriveStorageErrorType.unauthenticated,
        message: 'Google OAuth session expired or unauthenticated',
      );
    }
    _remoteStore.remove(remoteFileId);
    _fileBytesStore.remove(remoteFileId);
  }
}

void main() {
  group('Phase 1.9.5.1 — BackupStorageAdapter & Remote Models Tests', () {
    late MockBackupStorageAdapter mockAdapter;
    late Directory tempTestDir;
    final now = DateTime.utc(2026, 8, 14, 16, 0, 0);

    setUp(() {
      mockAdapter = MockBackupStorageAdapter();
      tempTestDir = Directory.systemTemp.createTempSync('adapter_test_');
    });

    tearDown(() {
      if (tempTestDir.existsSync()) {
        tempTestDir.deleteSync(recursive: true);
      }
    });

    test('TEST 1: Adapter interface can be implemented by a mock without Google SDKs', () {
      expect(mockAdapter, isA<BackupStorageAdapter>());
    });

    test('TEST 2: Upload returns RemoteBackupMetadata with correct properties', () async {
      final localFile = File('${tempTestDir.path}/test_backup.qnb');
      localFile.writeAsBytesSync([0x01, 0x02, 0x03, 0x04]);

      final manifest = BackupManifest(
        formatVersion: 1,
        backupId: 'bkp_100',
        createdAt: now,
        databaseSchemaVersion: 18,
        identity: BackupManifestIdentity(
          provider: 'google',
          providerUserIdHash: 'hash_123',
        ),
        contents: BackupContentCounts(folders: 2, notes: 5, tasks: 3, attachments: 1),
        checksums: {'manifest': 'sha256_manifest_abc'},
      );

      final metadata = await mockAdapter.uploadBackup(localBackupFile: localFile, manifest: manifest);

      expect(metadata.remoteFileId, equals('drive_file_bkp_100'));
      expect(metadata.backupId, equals('bkp_100'));
      expect(metadata.fileSizeBytes, equals(4));
      expect(metadata.noteCount, equals(5));
      expect(metadata.folderCount, equals(2));
      expect(metadata.taskCount, equals(3));
      expect(metadata.attachmentCount, equals(1));
      expect(metadata.databaseSchemaVersion, equals(18));
      expect(metadata.providerUserIdHash, equals('hash_123'));
    });

    test('TEST 3: List returns multiple RemoteBackupMetadata objects', () async {
      final localFile = File('${tempTestDir.path}/test.qnb');
      localFile.writeAsBytesSync([0x00]);

      final manifest1 = BackupManifest(
        formatVersion: 1,
        backupId: 'bkp_001',
        createdAt: now,
        databaseSchemaVersion: 18,
        identity: BackupManifestIdentity(provider: 'google', providerUserIdHash: 'h1'),
        contents: BackupContentCounts(folders: 1, notes: 1, tasks: 1, attachments: 0),
        checksums: {'manifest': 'chk1'},
      );

      final manifest2 = BackupManifest(
        formatVersion: 1,
        backupId: 'bkp_002',
        createdAt: now,
        databaseSchemaVersion: 18,
        identity: BackupManifestIdentity(provider: 'google', providerUserIdHash: 'h1'),
        contents: BackupContentCounts(folders: 2, notes: 3, tasks: 2, attachments: 1),
        checksums: {'manifest': 'chk2'},
      );

      await mockAdapter.uploadBackup(localBackupFile: localFile, manifest: manifest1);
      await mockAdapter.uploadBackup(localBackupFile: localFile, manifest: manifest2);

      final list = await mockAdapter.listBackups();
      expect(list.length, equals(2));
      expect(list.map((m) => m.backupId), containsAll(['bkp_001', 'bkp_002']));
    });

    test('TEST 4: Download returns the requested local destination file', () async {
      final localFile = File('${tempTestDir.path}/source.qnb');
      localFile.writeAsBytesSync([0xAA, 0xBB, 0xCC]);

      final manifest = BackupManifest(
        formatVersion: 1,
        backupId: 'bkp_dl',
        createdAt: now,
        databaseSchemaVersion: 18,
        identity: BackupManifestIdentity(provider: 'google', providerUserIdHash: 'h1'),
        contents: BackupContentCounts(folders: 0, notes: 1, tasks: 0, attachments: 0),
        checksums: {'manifest': 'chk_dl'},
      );

      final meta = await mockAdapter.uploadBackup(localBackupFile: localFile, manifest: manifest);

      final destFile = File('${tempTestDir.path}/downloaded.qnb');
      final resultFile = await mockAdapter.downloadBackup(remoteFileId: meta.remoteFileId, destinationLocalFile: destFile);

      expect(resultFile.existsSync(), isTrue);
      expect(resultFile.readAsBytesSync(), equals([0xAA, 0xBB, 0xCC]));
    });

    test('TEST 5: Delete completes successfully', () async {
      final localFile = File('${tempTestDir.path}/del.qnb');
      localFile.writeAsStringSync('data');

      final manifest = BackupManifest(
        formatVersion: 1,
        backupId: 'bkp_del',
        createdAt: now,
        databaseSchemaVersion: 18,
        identity: BackupManifestIdentity(provider: 'google', providerUserIdHash: 'h1'),
        contents: BackupContentCounts(folders: 0, notes: 0, tasks: 0, attachments: 0),
        checksums: {'manifest': 'chk_del'},
      );

      final meta = await mockAdapter.uploadBackup(localBackupFile: localFile, manifest: manifest);
      expect((await mockAdapter.listBackups()).length, equals(1));

      await mockAdapter.deleteBackup(meta.remoteFileId);
      expect((await mockAdapter.listBackups()).isEmpty, isTrue);
    });

    test('TEST 6: Upload failure propagates DriveStorageException', () async {
      mockAdapter.shouldFailUpload = true;

      final localFile = File('${tempTestDir.path}/fail.qnb');
      localFile.writeAsStringSync('data');

      final manifest = BackupManifest(
        formatVersion: 1,
        backupId: 'bkp_fail',
        createdAt: now,
        databaseSchemaVersion: 18,
        identity: BackupManifestIdentity(provider: 'google', providerUserIdHash: 'h1'),
        contents: BackupContentCounts(folders: 0, notes: 0, tasks: 0, attachments: 0),
        checksums: {'manifest': 'chk_fail'},
      );

      expect(
        () => mockAdapter.uploadBackup(localBackupFile: localFile, manifest: manifest),
        throwsA(isA<DriveStorageException>().having((e) => e.type, 'type', DriveStorageErrorType.uploadFailed)),
      );
    });

    test('TEST 7: Download failure propagates DriveStorageException', () async {
      mockAdapter.shouldFailDownload = true;

      final destFile = File('${tempTestDir.path}/dest.qnb');

      expect(
        () => mockAdapter.downloadBackup(remoteFileId: 'non_existent_id', destinationLocalFile: destFile),
        throwsA(isA<DriveStorageException>().having((e) => e.type, 'type', DriveStorageErrorType.downloadFailed)),
      );
    });

    test('TEST 8: RemoteBackupMetadata preserves all fields correctly through JSON serialization', () {
      final meta = RemoteBackupMetadata(
        remoteFileId: 'f_123',
        fileName: 'quick_notes_backup_20260814.qnb',
        fileSizeBytes: 2048,
        createdAt: now,
        modifiedAt: now,
        backupId: 'bkp_999',
        formatVersion: 1,
        databaseSchemaVersion: 18,
        appVersion: '1.1.0+2',
        noteCount: 15,
        folderCount: 3,
        taskCount: 8,
        attachmentCount: 4,
        providerUserIdHash: 'sha256_hash_value',
        sha256Checksum: 'sha256_checksum_value',
      );

      final jsonMap = meta.toJson();
      final restored = RemoteBackupMetadata.fromJson(jsonMap);

      expect(restored.remoteFileId, equals('f_123'));
      expect(restored.fileName, equals('quick_notes_backup_20260814.qnb'));
      expect(restored.fileSizeBytes, equals(2048));
      expect(restored.createdAt, equals(now));
      expect(restored.backupId, equals('bkp_999'));
      expect(restored.formatVersion, equals(1));
      expect(restored.databaseSchemaVersion, equals(18));
      expect(restored.noteCount, equals(15));
      expect(restored.folderCount, equals(3));
      expect(restored.taskCount, equals(8));
      expect(restored.attachmentCount, equals(4));
      expect(restored.providerUserIdHash, equals('sha256_hash_value'));
      expect(restored.sha256Checksum, equals('sha256_checksum_value'));
    });

    test('TEST 9: Sensitive credential fields do NOT exist in RemoteBackupMetadata', () {
      final jsonMap = RemoteBackupMetadata(
        remoteFileId: 'f_1',
        fileName: 'b.qnb',
        fileSizeBytes: 10,
        createdAt: now,
        backupId: 'b1',
        formatVersion: 1,
        databaseSchemaVersion: 18,
        appVersion: '1.1.0+2',
        noteCount: 1,
        folderCount: 1,
        taskCount: 1,
        attachmentCount: 0,
        providerUserIdHash: 'h1',
        sha256Checksum: 'c1',
      ).toJson();

      expect(jsonMap.containsKey('accessToken'), isFalse);
      expect(jsonMap.containsKey('idToken'), isFalse);
      expect(jsonMap.containsKey('refreshToken'), isFalse);
      expect(jsonMap.containsKey('clientSecret'), isFalse);
      expect(jsonMap.containsKey('password'), isFalse);
    });

    test('TEST 10: DriveStorageException preserves typed error classification', () {
      const ex = DriveStorageException(
        type: DriveStorageErrorType.quotaExceeded,
        message: 'Google Drive storage quota exceeded',
      );

      expect(ex.type, equals(DriveStorageErrorType.quotaExceeded));
      expect(ex.toString(), contains('quotaExceeded'));
      expect(ex.toString(), contains('Google Drive storage quota exceeded'));
    });
  });
}
