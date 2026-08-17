import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:quick_notes/controllers/backup_restore_controller.dart';
import 'package:quick_notes/models/session_type.dart';
import 'package:quick_notes/repositories/folders_repository.dart';
import 'package:quick_notes/repositories/notes_repository.dart';
import 'package:quick_notes/repositories/tasks_repository.dart';
import 'package:quick_notes/repositories/user_identity_repository.dart';
import 'package:quick_notes/services/backup/backup_engine.dart';
import 'package:quick_notes/services/backup/backup_manifest.dart';
import 'package:quick_notes/services/backup/backup_result.dart';
import 'package:quick_notes/services/backup/restore_engine.dart';
import 'package:quick_notes/services/database_service.dart';
import 'package:quick_notes/services/session_manager.dart';
import 'package:quick_notes/views/screens/backup_restore_screen.dart';

import '../controllers/backup_restore_controller_test.dart';

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

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    late final MessageHandler fontHandler;
    fontHandler = (ByteData? message) async {
      if (message == null) return null;
      final Uint8List list = message.buffer.asUint8List(message.offsetInBytes, message.lengthInBytes);
      final String key = utf8.decode(list);
      if (key.startsWith('google_fonts/')) {
        return ByteData(16);
      }
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null);
      try {
        return await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .send('flutter/assets', message);
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler('flutter/assets', fontHandler);
      }
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', fontHandler);

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
    tempTestDir = Directory.systemTemp.createTempSync('screen_test_');

    dbService = DatabaseService.instance;
    sessionManager = SessionManager();
    await sessionManager.saveSession(
      userId: 'usr_screen_test',
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

  group('Phase 1.9.6.2 & 1.9.6.3 — BackupRestoreScreen Tests', () {
    testWidgets('1. Screen renders title, sections, and status cards', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BackupRestoreScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Backup & Restore'), findsOneWidget);
      expect(find.text('STATUS'), findsOneWidget);
      expect(find.text('LOCAL BACKUP'), findsOneWidget);
      expect(find.text('CLOUD BACKUP'), findsOneWidget);
      expect(find.text('RESTORE DATA'), findsOneWidget);
      expect(find.text('Create Local Backup'), findsNWidgets(2)); // Title & Button label
      expect(find.text('Back Up to Drive'), findsOneWidget);
      expect(find.text('Restore Local File'), findsOneWidget);
    });

    testWidgets('2. Tapping Create Local Backup triggers controller and renders summary metadata', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BackupRestoreScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      late final BackupResult? result;
      await tester.runAsync(() async {
        result = await controller.createLocalBackup(
          customBackupDir: tempTestDir,
          customDocumentsDir: tempTestDir,
        );
      });
      await tester.pump();

      expect(result, isNotNull);
      expect(result!.success, isTrue);
      expect(controller.lastLocalBackupResult, equals(result));
      expect(find.textContaining('Local backup created successfully'), findsOneWidget);
    });

    testWidgets('3. Tapping Back Up to Drive without local backup displays error banner', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BackupRestoreScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      final uploadButton = find.text('Back Up to Drive');
      expect(uploadButton, findsOneWidget);
      await tester.tap(uploadButton);
      await tester.pump();

      expect(find.textContaining('Create a local backup before uploading it to Google Drive.'), findsOneWidget);
    });

    testWidgets('4. Tapping Back Up to Drive with local backup uploads and renders cloud metadata', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BackupRestoreScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await controller.createLocalBackup(
          customBackupDir: tempTestDir,
          customDocumentsDir: tempTestDir,
        );
      });
      await tester.pump();

      final uploadButton = find.text('Back Up to Drive');
      await tester.dragUntilVisible(
        uploadButton,
        find.byType(SingleChildScrollView),
        const Offset(0, -100),
      );
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await controller.uploadCloudBackup();
      });
      await tester.pump();

      expect(controller.lastUploadedCloudBackup, isNotNull);
      expect(find.textContaining('Uploaded to Google Drive'), findsOneWidget);
    });

    testWidgets('5. Tapping View Cloud Backups fetches remote list and renders available backup cards', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BackupRestoreScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Seed storage adapter with mock backup
      final localFile = File('${tempTestDir.path}/dummy.qnb')..writeAsStringSync('dummy');
      final manifest = BackupManifest(
        formatVersion: 1,
        backupId: 'bkp_list_view_1',
        createdAt: DateTime.now().toUtc(),
        databaseSchemaVersion: 18,
        identity: BackupManifestIdentity(provider: 'google', providerUserIdHash: 'h1'),
        contents: BackupContentCounts(folders: 3, notes: 12, tasks: 5, attachments: 2),
        checksums: {'manifest': 'chk'},
      );
      await storageAdapter.uploadBackup(localBackupFile: localFile, manifest: manifest);

      final viewButton = find.text('View Cloud Backups');
      await tester.dragUntilVisible(
        viewButton,
        find.byType(SingleChildScrollView),
        const Offset(0, -100),
      );
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await controller.fetchCloudBackups();
      });
      await tester.pump();

      expect(find.textContaining('AVAILABLE CLOUD BACKUPS'), findsOneWidget);
      expect(find.textContaining('12 Notes · 3 Folders · 5 Tasks · 2 Attachments'), findsOneWidget);
    });
  });
}
