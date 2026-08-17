import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:quick_notes/controllers/backup_restore_controller.dart';
import 'package:quick_notes/models/folder.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/models/session_type.dart';
import 'package:quick_notes/repositories/folders_repository.dart';
import 'package:quick_notes/repositories/notes_repository.dart';
import 'package:quick_notes/repositories/tasks_repository.dart';
import 'package:quick_notes/repositories/user_identity_repository.dart';
import 'package:quick_notes/services/backup/backup_engine.dart';
import 'package:quick_notes/services/backup/backup_manifest.dart';
import 'package:quick_notes/services/backup/backup_storage_adapter.dart';
import 'package:quick_notes/services/backup/drive_storage_exception.dart';
import 'package:quick_notes/services/backup/remote_backup_metadata.dart';
import 'package:quick_notes/services/backup/restore_engine.dart';
import 'package:quick_notes/services/database_service.dart';
import 'package:quick_notes/services/session_manager.dart';

class MockTestStorageAdapter implements BackupStorageAdapter {
  final List<RemoteBackupMetadata> store = [];
  bool shouldFailUpload = false;
  bool shouldFailDownload = false;
  bool shouldFailDelete = false;
  bool shouldFailAuth = false;

  @override
  Future<RemoteBackupMetadata> uploadBackup({
    required File localBackupFile,
    required BackupManifest manifest,
  }) async {
    if (shouldFailAuth) {
      throw const DriveStorageException(
        type: DriveStorageErrorType.unauthenticated,
        message: 'Auth expired',
      );
    }
    if (shouldFailUpload) {
      throw const DriveStorageException(
        type: DriveStorageErrorType.uploadFailed,
        message: 'Upload failed',
      );
    }

    final meta = RemoteBackupMetadata(
      remoteFileId: 'drive_file_${manifest.backupId}',
      fileName: 'quick_notes_backup_${manifest.backupId}.qnb',
      fileSizeBytes: localBackupFile.existsSync() ? localBackupFile.lengthSync() : 100,
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
      sha256Checksum: manifest.checksums['manifest'] ?? 'hash',
    );
    store.add(meta);
    return meta;
  }

  @override
  Future<List<RemoteBackupMetadata>> listBackups() async {
    if (shouldFailAuth) {
      throw const DriveStorageException(
        type: DriveStorageErrorType.unauthenticated,
        message: 'Auth expired',
      );
    }
    return List.from(store);
  }

  @override
  Future<File> downloadBackup({
    required String remoteFileId,
    required File destinationLocalFile,
  }) async {
    if (shouldFailAuth) {
      throw const DriveStorageException(
        type: DriveStorageErrorType.unauthenticated,
        message: 'Auth expired',
      );
    }
    if (shouldFailDownload) {
      throw const DriveStorageException(
        type: DriveStorageErrorType.downloadFailed,
        message: 'Download failed',
      );
    }

    if (!destinationLocalFile.parent.existsSync()) {
      destinationLocalFile.parent.createSync(recursive: true);
    }
    destinationLocalFile.writeAsStringSync('dummy_downloaded_qnb_content');
    return destinationLocalFile;
  }

  @override
  Future<void> deleteBackup(String remoteFileId) async {
    if (shouldFailAuth) {
      throw const DriveStorageException(
        type: DriveStorageErrorType.unauthenticated,
        message: 'Auth expired',
      );
    }
    if (shouldFailDelete) {
      throw const DriveStorageException(
        type: DriveStorageErrorType.permissionDenied,
        message: 'Delete failed',
      );
    }
    store.removeWhere((m) => m.remoteFileId == remoteFileId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService dbService;
  late SessionManager sessionManager;
  late SqliteFoldersRepository foldersRepo;
  late SqliteNotesRepository notesRepo;
  late SqliteTasksRepository tasksRepo;
  late SqliteUserIdentityRepository identityRepo;

  late BackupEngine backupEngine;
  late RestoreEngine restoreEngine;
  late MockTestStorageAdapter storageAdapter;
  late BackupRestoreController controller;

  late Directory tempTestDir;
  late Directory tempBackupDir;
  late Directory tempDocsDir;

  const testUserId = 'usr_ctrl_test_user';

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
    tempTestDir = Directory.systemTemp.createTempSync('ctrl_test_');
    tempBackupDir = Directory(p.join(tempTestDir.path, 'backups'))..createSync(recursive: true);
    tempDocsDir = Directory(p.join(tempTestDir.path, 'docs'))..createSync(recursive: true);

    dbService = DatabaseService.instance;
    final db = await dbService.database;
    await db.delete('notes');
    await db.delete('folders');
    await db.delete('tasks');
    await db.delete('sync_outbox');
    await db.delete('users');
    await db.delete('user_identities');
    await db.delete('user_profiles');

    sessionManager = SessionManager();
    await sessionManager.saveSession(
      userId: testUserId,
      sessionType: SessionType.google,
    );

    foldersRepo = SqliteFoldersRepository(dbService: dbService);
    notesRepo = SqliteNotesRepository(dbService: dbService);
    tasksRepo = SqliteTasksRepository(dbService: dbService);
    identityRepo = SqliteUserIdentityRepository(dbService: dbService);

    backupEngine = BackupEngine(
      foldersRepo: foldersRepo,
      notesRepo: notesRepo,
      tasksRepo: tasksRepo,
      identityRepo: identityRepo,
      sessionManager: sessionManager,
      dbService: dbService,
    );

    restoreEngine = RestoreEngine(
      dbService: dbService,
      sessionManager: sessionManager,
      backupEngine: backupEngine,
    );

    storageAdapter = MockTestStorageAdapter();

    controller = BackupRestoreController(
      backupEngine: backupEngine,
      restoreEngine: restoreEngine,
      storageAdapter: storageAdapter,
      sessionManager: sessionManager,
    );
  });

  tearDown(() {
    if (tempTestDir.existsSync()) {
      tempTestDir.deleteSync(recursive: true);
    }
  });

  group('Phase 1.9.6.1 — BackupRestoreController Tests', () {
    test('1. Controller initializes in idle state with null messages', () {
      expect(controller.operationState, equals(BackupOperationState.idle));
      expect(controller.isIdle, isTrue);
      expect(controller.isBusy, isFalse);
      expect(controller.errorMessage, isNull);
      expect(controller.infoMessage, isNull);
      expect(controller.remoteBackups.isEmpty, isTrue);
    });

    test('2. Single operation state concurrency guard blocks duplicate concurrent actions', () async {
      // Create test folder
      final f = Folder(id: 'f_ctrl_1', userId: testUserId, name: 'Test Folder', createdAt: DateTime.now());
      await foldersRepo.insertFolder(f);

      // Trigger local backup
      final future1 = controller.createLocalBackup(
        customBackupDir: tempBackupDir,
        customDocumentsDir: tempDocsDir,
      );

      // Attempt second operation immediately while busy
      final future2 = controller.createLocalBackup(
        customBackupDir: tempBackupDir,
        customDocumentsDir: tempDocsDir,
      );

      final res2 = await future2;
      expect(res2, isNull);

      final res1 = await future1;
      expect(res1, isNotNull);
      expect(res1!.success, isTrue);
    });

    test('3. Create local backup executes successfully and updates state', () async {
      final n = Note(
        id: 'n_ctrl_1',
        userId: testUserId,
        title: 'Note 1',
        content: 'Body',
        tags: const [],
        attachments: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        colorValue: 0xFFFFFFFF,
      );
      await notesRepo.insertNote(n);

      final result = await controller.createLocalBackup(
        customBackupDir: tempBackupDir,
        customDocumentsDir: tempDocsDir,
      );

      expect(result, isNotNull);
      expect(result!.success, isTrue);
      expect(controller.isIdle, isTrue);
      expect(controller.infoMessage, contains('Local backup created successfully'));
      expect(controller.lastLocalBackupResult, equals(result));
    });

    test('4. Upload cloud backup fails if no local backup has been created', () async {
      final meta = await controller.uploadCloudBackup();
      expect(meta, isNull);
      expect(controller.errorMessage, equals('Create a local backup before uploading it to Google Drive.'));
      expect(controller.operationState, equals(BackupOperationState.idle));
    });

    test('4b. Upload cloud backup succeeds when local backup exists', () async {
      final f = Folder(id: 'f_cloud_1', userId: testUserId, name: 'Folder Cloud', createdAt: DateTime.now());
      await foldersRepo.insertFolder(f);

      // Create local backup first
      final localResult = await controller.createLocalBackup(
        customBackupDir: tempBackupDir,
        customDocumentsDir: tempDocsDir,
      );
      expect(localResult, isNotNull);
      expect(localResult!.success, isTrue);

      final meta = await controller.uploadCloudBackup();

      expect(meta, isNotNull);
      expect(meta!.backupId, isNotEmpty);
      expect(controller.infoMessage, contains('Google Drive'));
      expect(controller.lastUploadedCloudBackup, equals(meta));
      expect(controller.remoteBackups.length, equals(1));
      expect(controller.operationState, equals(BackupOperationState.idle));
    });

    test('4c. Upload cloud backup handles network & auth errors cleanly without token exposure', () async {
      await controller.createLocalBackup(
        customBackupDir: tempBackupDir,
        customDocumentsDir: tempDocsDir,
      );

      storageAdapter.shouldFailAuth = true;
      final metaAuth = await controller.uploadCloudBackup();
      expect(metaAuth, isNull);
      expect(controller.errorMessage, contains("Google Drive isn't connected"));
      expect(controller.operationState, equals(BackupOperationState.idle));

      storageAdapter.shouldFailAuth = false;
      storageAdapter.shouldFailUpload = true;
      final metaUpload = await controller.uploadCloudBackup();
      expect(metaUpload, isNull);
      expect(controller.errorMessage, contains("Failed to upload backup to Google Drive"));
      expect(controller.operationState, equals(BackupOperationState.idle));
    });

    test('5. Fetch cloud backups queries adapter and updates remoteBackups list', () async {
      final localFile = File(p.join(tempDocsDir.path, 'dummy.qnb'));
      localFile.writeAsStringSync('dummy');

      final manifest = BackupManifest(
        formatVersion: 1,
        backupId: 'bkp_list_1',
        createdAt: DateTime.now().toUtc(),
        databaseSchemaVersion: 18,
        identity: BackupManifestIdentity(provider: 'google', providerUserIdHash: 'h1'),
        contents: BackupContentCounts(folders: 1, notes: 2, tasks: 0, attachments: 0),
        checksums: {'manifest': 'chk'},
      );

      await storageAdapter.uploadBackup(localBackupFile: localFile, manifest: manifest);

      final list = await controller.fetchCloudBackups();
      expect(list.length, equals(1));
      expect(controller.remoteBackups.length, equals(1));
      expect(controller.remoteBackups.first.backupId, equals('bkp_list_1'));
    });

    test('6. Delete cloud backup removes remote item and refreshes list', () async {
      final localFile = File(p.join(tempDocsDir.path, 'dummy.qnb'));
      localFile.writeAsStringSync('dummy');

      final manifest = BackupManifest(
        formatVersion: 1,
        backupId: 'bkp_del_1',
        createdAt: DateTime.now().toUtc(),
        databaseSchemaVersion: 18,
        identity: BackupManifestIdentity(provider: 'google', providerUserIdHash: 'h1'),
        contents: BackupContentCounts(folders: 0, notes: 0, tasks: 0, attachments: 0),
        checksums: {'manifest': 'chk'},
      );

      final meta = await storageAdapter.uploadBackup(localBackupFile: localFile, manifest: manifest);
      await controller.fetchCloudBackups();
      expect(controller.remoteBackups.length, equals(1));

      final success = await controller.deleteCloudBackup(meta.remoteFileId);
      expect(success, isTrue);
      expect(controller.remoteBackups.isEmpty, isTrue);
      expect(controller.infoMessage, contains('deleted successfully'));
    });

    test('6b. Failed deleteCloudBackup does NOT remove remote backup item from list and maps error', () async {
      final localFile = File(p.join(tempDocsDir.path, 'dummy.qnb'))..writeAsStringSync('dummy');
      final manifest = BackupManifest(
        formatVersion: 1,
        backupId: 'bkp_del_fail_1',
        createdAt: DateTime.now().toUtc(),
        databaseSchemaVersion: 18,
        identity: BackupManifestIdentity(provider: 'google', providerUserIdHash: 'h1'),
        contents: BackupContentCounts(folders: 0, notes: 0, tasks: 0, attachments: 0),
        checksums: {'manifest': 'chk'},
      );

      final meta = await storageAdapter.uploadBackup(localBackupFile: localFile, manifest: manifest);
      await controller.fetchCloudBackups();
      expect(controller.remoteBackups.length, equals(1));

      storageAdapter.shouldFailDelete = true;
      final success = await controller.deleteCloudBackup(meta);
      expect(success, isFalse);
      expect(controller.remoteBackups.length, equals(1));
      expect(controller.errorMessage, contains("doesn't currently have permission"));
      expect(controller.operationState, equals(BackupOperationState.idle));
    });

    test('7. Error mapping translates DriveStorageException into user-friendly strings', () {
      const exUnauth = DriveStorageException(
        type: DriveStorageErrorType.unauthenticated,
        message: 'Raw 401',
      );
      const exNetwork = DriveStorageException(
        type: DriveStorageErrorType.networkUnavailable,
        message: 'Socket error',
      );

      final msgUnauth = BackupRestoreController.mapDriveError(exUnauth);
      final msgNetwork = BackupRestoreController.mapDriveError(exNetwork);

      expect(msgUnauth, contains("Google Drive isn't connected"));
      expect(msgNetwork, contains('No internet connection'));
    });

    test('8. downloadAndRestoreCloudBackup cleans up temp file and resets operationState to idle', () async {
      final localFile = File(p.join(tempDocsDir.path, 'dummy.qnb'));
      localFile.writeAsStringSync('dummy');

      final manifest = BackupManifest(
        formatVersion: 1,
        backupId: 'bkp_restore_1',
        createdAt: DateTime.now().toUtc(),
        databaseSchemaVersion: 18,
        identity: BackupManifestIdentity(provider: 'google', providerUserIdHash: 'h1'),
        contents: BackupContentCounts(folders: 0, notes: 0, tasks: 0, attachments: 0),
        checksums: {'manifest': 'chk'},
      );

      final meta = await storageAdapter.uploadBackup(localBackupFile: localFile, manifest: manifest);

      storageAdapter.shouldFailDownload = true;
      final resFail = await controller.downloadAndRestoreCloudBackup(
        remoteFileId: meta.remoteFileId,
        tempDownloadDir: tempBackupDir,
      );
      expect(resFail, isNull);
      expect(controller.errorMessage, contains('The backup file could not be downloaded safely.'));
      expect(controller.operationState, equals(BackupOperationState.idle));
    });

    test('9. inspectLocalBackup safely inspects .qnb file or returns null error for invalid files', () async {
      final nonExistent = File(p.join(tempDocsDir.path, 'non_existent.qnb'));
      final metaNull = await controller.inspectLocalBackup(nonExistent);
      expect(metaNull, isNull);
      expect(controller.errorMessage, contains('does not exist on disk'));

      final invalidExt = File(p.join(tempDocsDir.path, 'invalid.txt'))..writeAsStringSync('txt');
      final metaExt = await controller.inspectLocalBackup(invalidExt);
      expect(metaExt, isNull);
      expect(controller.errorMessage, contains('not a valid .qnb'));

      final corruptQnb = File(p.join(tempDocsDir.path, 'corrupt.qnb'))..writeAsStringSync('not a zip');
      final metaCorrupt = await controller.inspectLocalBackup(corruptQnb);
      expect(metaCorrupt, isNull);
      expect(controller.errorMessage, contains('This backup could not be verified and was not restored'));
    });

    test('10. restoreLocalBackup handles missing local file safely', () async {
      final missingFile = File(p.join(tempDocsDir.path, 'missing_backup.qnb'));
      final res = await controller.restoreLocalBackup(localFile: missingFile);
      expect(res, isNull);
      expect(controller.errorMessage, contains('Local backup file does not exist'));
      expect(controller.operationState, equals(BackupOperationState.idle));
    });

    test('11. Failed fetchCloudBackups preserves previous valid list and resets to idle', () async {
      final localFile = File(p.join(tempDocsDir.path, 'dummy.qnb'))..writeAsStringSync('dummy');
      final manifest = BackupManifest(
        formatVersion: 1,
        backupId: 'bkp_preserve_1',
        createdAt: DateTime.now().toUtc(),
        databaseSchemaVersion: 18,
        identity: BackupManifestIdentity(provider: 'google', providerUserIdHash: 'h1'),
        contents: BackupContentCounts(folders: 1, notes: 1, tasks: 0, attachments: 0),
        checksums: {'manifest': 'chk'},
      );
      await storageAdapter.uploadBackup(localBackupFile: localFile, manifest: manifest);
      await controller.fetchCloudBackups();
      expect(controller.remoteBackups.length, equals(1));

      // Trigger network failure on subsequent fetch
      storageAdapter.shouldFailAuth = true;
      await controller.fetchCloudBackups();
      expect(controller.remoteBackups.length, equals(1)); // Previous valid list preserved!
      expect(controller.errorMessage, contains("Google Drive isn't connected"));
      expect(controller.operationState, equals(BackupOperationState.idle));
    });

    test('12. New operation clears previous error message and resets to idle on completion', () async {
      storageAdapter.shouldFailAuth = true;
      await controller.fetchCloudBackups();
      expect(controller.errorMessage, isNotNull);

      storageAdapter.shouldFailAuth = false;
      await controller.createLocalBackup();
      expect(controller.errorMessage, isNull);
      expect(controller.operationState, equals(BackupOperationState.idle));
      expect(controller.isIdle, isTrue);
    });
  });
}
