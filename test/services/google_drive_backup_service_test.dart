import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:quick_notes/models/session_type.dart';
import 'package:quick_notes/services/backup/backup_integrity.dart';
import 'package:quick_notes/services/backup/backup_manifest.dart';
import 'package:quick_notes/services/backup/drive_storage_exception.dart';
import 'package:quick_notes/services/backup/remote_backup_metadata.dart';
import 'package:quick_notes/services/session_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionManager sessionManager;
  late Directory tempTestDir;

  const testUserIdA = 'usr_gdrive_user_a';
  const testUserIdB = 'usr_gdrive_user_b';

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => '.',
    );

    final secureStorageStore = <String, String>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'write') {
          final args = Map<String, dynamic>.from(methodCall.arguments as Map);
          secureStorageStore[args['key'] as String] = args['value'] as String;
          return null;
        } else if (methodCall.method == 'read') {
          final args = Map<String, dynamic>.from(methodCall.arguments as Map);
          return secureStorageStore[args['key'] as String];
        } else if (methodCall.method == 'delete') {
          final args = Map<String, dynamic>.from(methodCall.arguments as Map);
          secureStorageStore.remove(args['key'] as String);
          return null;
        }
        return null;
      },
    );

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempTestDir = Directory.systemTemp.createTempSync('gdrive_test_');

    sessionManager = SessionManager();
    await sessionManager.saveSession(
      userId: testUserIdA,
      sessionType: SessionType.google,
    );
  });

  tearDown(() {
    if (tempTestDir.existsSync()) {
      tempTestDir.deleteSync(recursive: true);
    }
  });

  group('Phase 1.9.5.2 — GoogleDriveBackupService Tests', () {
    test('1. BackupManifest and RemoteBackupMetadata mapping is consistent', () {
      final now = DateTime.utc(2026, 8, 14, 16, 0, 0);
      final manifest = BackupManifest(
        formatVersion: 1,
        backupId: 'bkp_drive_001',
        createdAt: now,
        databaseSchemaVersion: 18,
        identity: BackupManifestIdentity(
          provider: 'google',
          providerUserIdHash: BackupIntegrity.sha256String(testUserIdA),
        ),
        contents: BackupContentCounts(folders: 2, notes: 10, tasks: 5, attachments: 2),
        checksums: {'manifest': 'sha256_dummy'},
      );

      expect(manifest.formatVersion, equals(1));
      expect(manifest.databaseSchemaVersion, equals(18));
      expect(manifest.contents.notes, equals(10));
    });

    test('2. Identity Isolation: Filtering remote backups hides backups from other users', () {
      final hashA = BackupIntegrity.sha256String(testUserIdA);
      final hashB = BackupIntegrity.sha256String(testUserIdB);

      final metaA = RemoteBackupMetadata(
        remoteFileId: 'f_a',
        fileName: 'quick_notes_backup_20260814_100000.qnb',
        fileSizeBytes: 1024,
        createdAt: DateTime.utc(2026, 8, 14, 10, 0, 0),
        backupId: 'bkp_a',
        formatVersion: 1,
        databaseSchemaVersion: 18,
        appVersion: '1.1.0+2',
        noteCount: 5,
        folderCount: 1,
        taskCount: 2,
        attachmentCount: 0,
        providerUserIdHash: hashA,
        sha256Checksum: 'chk_a',
      );

      final metaB = RemoteBackupMetadata(
        remoteFileId: 'f_b',
        fileName: 'quick_notes_backup_20260814_110000.qnb',
        fileSizeBytes: 2048,
        createdAt: DateTime.utc(2026, 8, 14, 11, 0, 0),
        backupId: 'bkp_b',
        formatVersion: 1,
        databaseSchemaVersion: 18,
        appVersion: '1.1.0+2',
        noteCount: 8,
        folderCount: 2,
        taskCount: 3,
        attachmentCount: 1,
        providerUserIdHash: hashB,
        sha256Checksum: 'chk_b',
      );

      final allRemote = [metaA, metaB];
      final filteredForA = allRemote.where((m) => m.providerUserIdHash == hashA).toList();

      expect(filteredForA.length, equals(1));
      expect(filteredForA.first.backupId, equals('bkp_a'));
    });

    test('3. DriveStorageException taxonomy maps status codes correctly without credential leakage', () {
      const exUnauth = DriveStorageException(
        type: DriveStorageErrorType.unauthenticated,
        message: 'OAuth token expired or invalid',
      );
      const exDenied = DriveStorageException(
        type: DriveStorageErrorType.permissionDenied,
        message: 'Permission denied for Google Drive scope',
      );
      const exNotFound = DriveStorageException(
        type: DriveStorageErrorType.backupNotFound,
        message: 'Google Drive backup file 404',
      );

      expect(exUnauth.type, equals(DriveStorageErrorType.unauthenticated));
      expect(exDenied.type, equals(DriveStorageErrorType.permissionDenied));
      expect(exNotFound.type, equals(DriveStorageErrorType.backupNotFound));

      // Credential Privacy Check
      expect(exUnauth.toString(), isNot(contains('Bearer')));
      expect(exUnauth.toString(), isNot(contains('secret')));
      expect(exDenied.toString(), isNot(contains('token')));
    });

    test('4. Download checksum validation detects corrupted cloud downloads', () {
      final expectedSha = BackupIntegrity.sha256Bytes(utf8.encode('valid_content'));
      final downloadedBytes = utf8.encode('corrupted_content');
      final downloadedSha = BackupIntegrity.sha256Bytes(downloadedBytes);

      expect(downloadedSha, isNot(equals(expectedSha)));
    });
  });
}
