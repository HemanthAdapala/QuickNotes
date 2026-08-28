import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:quick_notes/models/folder.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/models/task_item.dart';
import 'package:quick_notes/models/task_status.dart';
import 'package:quick_notes/models/session_type.dart';
import 'package:quick_notes/repositories/folders_repository.dart';
import 'package:quick_notes/repositories/notes_repository.dart';
import 'package:quick_notes/repositories/tasks_repository.dart';
import 'package:quick_notes/repositories/user_identity_repository.dart';
import 'package:quick_notes/services/backup/backup_engine.dart';
import 'package:quick_notes/services/database_service.dart';
import 'package:quick_notes/services/session_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService dbService;
  late SessionManager sessionManager;
  late SqliteFoldersRepository foldersRepo;
  late SqliteNotesRepository notesRepo;
  late SqliteTasksRepository tasksRepo;
  late SqliteUserIdentityRepository identityRepo;
  late BackupEngine backupEngine;

  late Directory tempTestDir;
  late Directory tempBackupDir;
  late Directory tempDocsDir;

  const testUserIdA = 'usr_backup_test_user_a';
  const testUserIdB = 'usr_backup_test_user_b';

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
    dbService = DatabaseService.instance;
    await dbService.queryAll();

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
      sessionManager: sessionManager,
      dbService: dbService,
    );

    tempTestDir = Directory.systemTemp.createTempSync('qnb_test_');
    tempBackupDir = Directory(p.join(tempTestDir.path, 'backups'))..createSync(recursive: true);
    tempDocsDir = Directory(p.join(tempTestDir.path, 'docs'))..createSync(recursive: true);
  });

  tearDown(() {
    if (tempTestDir.existsSync()) {
      tempTestDir.deleteSync(recursive: true);
    }
  });

  group('Phase 1.9.3 — BackupEngine Tests', () {
    test('1. Successful backup creation generates valid .qnb file and passes validation', () async {
      final folder = Folder(id: 'f_work', userId: testUserIdA, name: 'Work', createdAt: DateTime.now());
      await foldersRepo.insertFolder(folder);

      // Create dummy image file in documents dir
      final imgFile = File(p.join(tempDocsDir.path, 'sample_chart.png'));
      imgFile.writeAsBytesSync([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

      final note = Note(
        id: 'n_doc1',
        userId: testUserIdA,
        title: 'Project Roadmap',
        content: 'Overview diagram: ![Chart](attachment://sample_chart.png)',
        tags: const ['roadmap', 'q3'],
        attachments: const [
          {'id': 'att_1', 'path': 'attachment://sample_chart.png'}
        ],
        folderId: 'f_work',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        colorValue: 0xFF00FF00,
      );
      await notesRepo.insertNote(note);

      final task = TaskItem(
        id: 't_review',
        userId: testUserIdA,
        title: 'Review Roadmap',
        dueDate: DateTime.now(),
        priority: 'High',
        status: TaskStatus.waiting,
        folderId: 'f_work',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await tasksRepo.insertTask(task);

      final result = await backupEngine.createBackup(
        customBackupDir: tempBackupDir,
        customDocumentsDir: tempDocsDir,
      );

      expect(result.success, isTrue);
      expect(result.filePath, isNotNull);
      expect(File(result.filePath!).existsSync(), isTrue);

      expect(result.folderCount, equals(1));
      expect(result.noteCount, equals(1));
      expect(result.taskCount, equals(1));
      expect(result.attachmentCount, equals(1));

      // Post-creation validation passed
      expect(result.validationResult, isNotNull);
      expect(result.validationResult!.isValid, isTrue);
    });

    test('2. User data isolation: Backup includes ONLY active user data', () async {
      // Insert User A folder
      final folderA = Folder(id: 'f_user_a', userId: testUserIdA, name: 'User A Folder', createdAt: DateTime.now());
      await foldersRepo.insertFolder(folderA);

      // Switch session to User B and insert User B folder
      await sessionManager.saveSession(userId: testUserIdB, sessionType: SessionType.google);
      final folderB = Folder(id: 'f_user_b', userId: testUserIdB, name: 'User B Folder', createdAt: DateTime.now());
      await foldersRepo.insertFolder(folderB);

      // Switch back to User A
      await sessionManager.saveSession(userId: testUserIdA, sessionType: SessionType.google);

      final result = await backupEngine.createBackup(
        customBackupDir: tempBackupDir,
        customDocumentsDir: tempDocsDir,
      );

      expect(result.success, isTrue);
      expect(result.folderCount, equals(1)); // ONLY User A folder included
    });

    test('3. Missing local attachment asset fails backup and cleans up temporary .tmp file', () async {
      final noteWithMissingAttachment = Note(
        id: 'n_missing',
        userId: testUserIdA,
        title: 'Broken Attachment Note',
        content: 'Missing image: ![Missing](attachment://non_existent_file.png)',
        tags: const [],
        attachments: const [
          {'id': 'att_missing', 'path': 'attachment://non_existent_file.png'}
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        colorValue: 0xFFFFFFFF,
      );
      await notesRepo.insertNote(noteWithMissingAttachment);

      final result = await backupEngine.createBackup(
        customBackupDir: tempBackupDir,
        customDocumentsDir: tempDocsDir,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('missing local attachment asset'));

      // Verify ZERO leftover .tmp files in backup directory
      final tmpFiles = tempBackupDir.listSync().where((f) => f.path.endsWith('.tmp'));
      expect(tmpFiles.isEmpty, isTrue);
    });

    test('4. Note with remote web image URL (e.g. picsum / 400) creates backup successfully without misidentifying as missing local attachment', () async {
      final noteWithWebImage = Note(
        id: 'n_web_img',
        userId: testUserIdA,
        title: 'Note with Web Image',
        content: 'Sample remote image: ![Remote Image](https://picsum.photos/200/400)',
        tags: const [],
        attachments: const [
          {'id': 'att_web', 'url': 'https://picsum.photos/200/400'}
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        colorValue: 0xFFFFFFFF,
      );
      await notesRepo.insertNote(noteWithWebImage);

      final result = await backupEngine.createBackup(
        customBackupDir: tempBackupDir,
        customDocumentsDir: tempDocsDir,
      );

      expect(result.success, isTrue);
      expect(result.attachmentCount, equals(0)); // Remote web image URL is not bundled as a local asset file
      expect(result.filePath, isNotNull);
      expect(File(result.filePath!).existsSync(), isTrue);
    });
  });
}
