import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:quick_notes/models/folder.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/models/session_type.dart';
import 'package:quick_notes/repositories/folders_repository.dart';
import 'package:quick_notes/repositories/notes_repository.dart';
import 'package:quick_notes/repositories/tasks_repository.dart';
import 'package:quick_notes/repositories/user_identity_repository.dart';
import 'package:quick_notes/services/backup/backup_engine.dart';
import 'package:quick_notes/services/backup/backup_format.dart';
import 'package:quick_notes/services/backup/backup_manifest.dart';
import 'package:quick_notes/services/backup/restore_engine.dart';
import 'package:quick_notes/services/backup/restore_result.dart';
import 'package:quick_notes/services/database_service.dart';
import 'package:quick_notes/services/session_manager.dart';
import 'package:quick_notes/services/backup/zip_decoder.dart';
import 'package:quick_notes/services/backup/zip_encoder.dart';

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

  late Directory tempTestDir;
  late Directory tempBackupDir;
  late Directory tempDocsDir;

  const testUserIdA = 'usr_restore_user_a';
  const testUserIdB = 'usr_restore_user_b';

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
    tempTestDir = Directory.systemTemp.createTempSync('qnb_restore_test_');
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
      userId: testUserIdA,
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
  });

  tearDown(() {
    if (tempTestDir.existsSync()) {
      tempTestDir.deleteSync(recursive: true);
    }
  });

  group('Phase 1.9.4 — RestoreEngine Tests', () {
    test('1. Successful restore replaces user data, creates safety snapshot, and generates 0 outbox events', () async {
      final folder = Folder(id: 'f_rest_1', userId: testUserIdA, name: 'Restored Folder', createdAt: DateTime.now());
      await foldersRepo.insertFolder(folder);

      final note = Note(
        id: 'n_rest_1',
        userId: testUserIdA,
        title: 'Restored Note',
        content: 'Content',
        tags: const [],
        attachments: const [],
        folderId: 'f_rest_1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        colorValue: 0xFFFFFFFF,
      );
      await notesRepo.insertNote(note);

      final backupResult = await backupEngine.createBackup(
        customBackupDir: tempBackupDir,
        customDocumentsDir: tempDocsDir,
      );
      expect(backupResult.success, isTrue);

      final db = await dbService.database;
      await db.delete('notes', where: 'userId = ?', whereArgs: [testUserIdA]);
      await db.delete('folders', where: 'userId = ?', whereArgs: [testUserIdA]);
      await db.delete('sync_outbox');

      final restoreResult = await restoreEngine.restoreFromBackup(
        backupFilePath: backupResult.filePath!,
        customDocumentsDir: tempDocsDir,
        forceOfflineOverride: true,
      );

      expect(restoreResult.success, isTrue);
      expect(restoreResult.folderCount, equals(1));
      expect(restoreResult.noteCount, equals(1));
      expect(restoreResult.safetySnapshotPath, isNotNull);
      expect(File(restoreResult.safetySnapshotPath!).existsSync(), isTrue);

      final outboxRows = await db.query('sync_outbox');
      expect(outboxRows.isEmpty, isTrue);
    });

    test('2. User isolation: Restoring User A data preserves User B records untouched', () async {
      await sessionManager.saveSession(userId: testUserIdB, sessionType: SessionType.google);
      final noteB = Note(
        id: 'n_user_b',
        userId: testUserIdB,
        title: 'User B Private Note',
        content: 'Secret',
        tags: const [],
        attachments: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        colorValue: 0xFFFFFFFF,
      );
      await notesRepo.insertNote(noteB);

      final folderA = Folder(id: 'f_user_a', userId: testUserIdA, name: 'User A', createdAt: DateTime.now());
      await foldersRepo.insertFolder(folderA);

      final backupResult = await backupEngine.createBackup(
        customBackupDir: tempBackupDir,
        customDocumentsDir: tempDocsDir,
      );

      final restoreResult = await restoreEngine.restoreFromBackup(
        backupFilePath: backupResult.filePath!,
        customDocumentsDir: tempDocsDir,
        forceOfflineOverride: true,
      );

      expect(restoreResult.success, isTrue);

      final db = await dbService.database;
      final userBNotes = await db.query('notes', where: 'userId = ?', whereArgs: [testUserIdB]);
      expect(userBNotes.length, equals(1));
      expect(userBNotes.first['id'], equals('n_user_b'));
    });

    test('3. Pre-restore validation failure blocks restore before modifying database', () async {
      final invalidFilePath = p.join(tempBackupDir.path, 'corrupted.qnb');
      final invalidFile = File(invalidFilePath);
      invalidFile.writeAsStringSync('corrupted_not_a_zip');

      final restoreResult = await restoreEngine.restoreFromBackup(
        backupFilePath: invalidFilePath,
        customDocumentsDir: tempDocsDir,
      );

      expect(restoreResult.success, isFalse);
      expect(restoreResult.error!.type, equals(RestoreErrorType.validationFailed));
    });

    test('4. Older schema version (< 18) is rejected by validator before restore', () async {
      final folder = Folder(id: 'f_old', userId: testUserIdA, name: 'Old', createdAt: DateTime.now());
      await foldersRepo.insertFolder(folder);
      final bkp = await backupEngine.createBackup(customBackupDir: tempBackupDir, customDocumentsDir: tempDocsDir);

      // Modify backup manifest schema version to 17
      final zipBytes = File(bkp.filePath!).readAsBytesSync();
      final entries = ZipDecoder.decode(zipBytes);
      final newEntries = <ZipInputEntry>[];

      for (final e in entries) {
        if (e.name == BackupFormat.manifestFileName) {
          final manifestMap = jsonDecode(utf8.decode(e.data)) as Map<String, dynamic>;
          manifestMap['databaseSchemaVersion'] = 17;

          final manifestObj = BackupManifest.fromMap(manifestMap);
          final checksumsMap = Map<String, String>.from(manifestObj.checksums);
          checksumsMap['manifest'] = manifestObj.computeManifestChecksum();

          final updatedManifest = BackupManifest(
            formatVersion: manifestObj.formatVersion,
            backupId: manifestObj.backupId,
            createdAt: manifestObj.createdAt,
            databaseSchemaVersion: 17,
            appVersion: manifestObj.appVersion,
            identity: manifestObj.identity,
            contents: manifestObj.contents,
            checksums: checksumsMap,
          );

          newEntries.add(ZipInputEntry(name: e.name, bytes: utf8.encode(updatedManifest.toJsonString())));
        } else {
          newEntries.add(ZipInputEntry(name: e.name, bytes: e.data));
        }
      }

      final v17Path = p.join(tempBackupDir.path, 'v17_backup.qnb');
      File(v17Path).writeAsBytesSync(ZipEncoder.encode(newEntries));

      final restoreResult = await restoreEngine.restoreFromBackup(
        backupFilePath: v17Path,
        customDocumentsDir: tempDocsDir,
      );

      expect(restoreResult.success, isFalse);
      expect(restoreResult.error!.type, equals(RestoreErrorType.validationFailed));
    });
  });
}
