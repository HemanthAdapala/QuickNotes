import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quick_notes/controllers/first_run_recovery_controller.dart';
import 'package:quick_notes/services/backup/backup_integrity.dart';
import 'package:quick_notes/services/backup/backup_manifest.dart';
import 'package:quick_notes/services/backup/backup_storage_adapter.dart';
import 'package:quick_notes/services/backup/remote_backup_metadata.dart';
import 'package:quick_notes/services/backup/restore_engine.dart';
import 'package:quick_notes/services/backup/restore_result.dart';
import 'package:quick_notes/services/recovery/first_run_recovery_state.dart';
import 'package:quick_notes/services/recovery/local_data_detector.dart';
import 'package:quick_notes/services/recovery/recovery_completion_store.dart';
import 'package:quick_notes/views/screens/first_run_recovery_screen.dart';

/// Fake storage adapter for widget tests
class _FakeStorageAdapter implements BackupStorageAdapter {
  @override
  Future<File> downloadBackup({
    required String remoteFileId,
    required File destinationLocalFile,
  }) async {
    destinationLocalFile.createSync(recursive: true);
    destinationLocalFile.writeAsStringSync('fake_content');
    return destinationLocalFile;
  }

  @override
  Future<List<RemoteBackupMetadata>> listBackups() async => [];
  @override
  Future<RemoteBackupMetadata> uploadBackup(
          {required File localBackupFile, required BackupManifest manifest}) =>
      throw UnimplementedError();
  @override
  Future<void> deleteBackup(String remoteFileId) => throw UnimplementedError();
}

/// Fake restore engine for widget tests
class _FakeRestoreEngine extends RestoreEngine {
  RestoreResult resultToReturn = const RestoreResult(
    success: true,
    backupId: 'b_123',
    noteCount: 42,
    folderCount: 3,
    taskCount: 5,
    attachmentCount: 2,
    verificationPassed: true,
  );

  @override
  Future<RestoreResult> restoreFromBackup({
    required String backupFilePath,
    Directory? customDocumentsDir,
    bool forceOfflineOverride = false,
  }) async {
    return resultToReturn;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    late final MessageHandler fontHandler;
    fontHandler = (ByteData? message) async {
      if (message == null) return null;
      final Uint8List list = message.buffer
          .asUint8List(message.offsetInBytes, message.lengthInBytes);
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => '.',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async => null,
    );
  });

  group('DM-F3 — First Run Recovery Dark Mode Palette Tests', () {
    late _FakeStorageAdapter fakeStorage;
    late _FakeRestoreEngine fakeRestoreEngine;
    late RecoveryCompletionStore completionStore;
    late Directory tempTestDir;

    final testHash = BackupIntegrity.sha256String('uid_dm_f3');

    final testBackupMetadata = RemoteBackupMetadata(
      remoteFileId: 'remote_file_1',
      fileName: 'backup_2026.qnb',
      fileSizeBytes: 2500000, // ~2.4 MB
      backupId: 'backup_uuid_1',
      providerUserIdHash: testHash,
      createdAt: DateTime.parse('2026-08-18T10:42:00Z'),
      formatVersion: 1,
      databaseSchemaVersion: 18,
      appVersion: '1.0.0',
      noteCount: 42,
      folderCount: 3,
      taskCount: 5,
      attachmentCount: 2,
      sha256Checksum: 'chk',
    );

    final cleanRecoveryResult = FirstRunRecoveryResult.eligibleEmptyLocal(
      localSummary: const LocalDataSummary.empty(),
      recommendedBackup: testBackupMetadata,
      eligibleBackups: [testBackupMetadata],
    );

    final conflictRecoveryResult = FirstRunRecoveryResult.eligibleConflictLocal(
      localSummary: const LocalDataSummary(
          noteCount: 12, folderCount: 2, taskCount: 4),
      recommendedBackup: testBackupMetadata,
      eligibleBackups: [testBackupMetadata, testBackupMetadata],
    );

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      fakeStorage = _FakeStorageAdapter();
      fakeRestoreEngine = _FakeRestoreEngine();
      completionStore = RecoveryCompletionStore();
      tempTestDir =
          Directory.systemTemp.createTempSync('recovery_screen_palette_test_');
    });

    tearDown(() {
      try {
        if (tempTestDir.existsSync()) {
          tempTestDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    Widget createTestWidget({
      required FirstRunRecoveryResult result,
      FirstRunRecoveryController? controller,
      Brightness brightness = Brightness.dark,
    }) {
      return MaterialApp(
        theme: ThemeData(
          brightness: brightness,
        ),
        home: FirstRunRecoveryScreen(
          recoveryResult: result,
          controller: controller,
        ),
      );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // GROUP A — Surfaces & Typography (Dark Mode)
    // ─────────────────────────────────────────────────────────────────────────
    group('Group A — Surfaces & Typography', () {
      testWidgets('Dark Mode: canvas, card, badges, chips, and typography',
          (tester) async {
        final controller = FirstRunRecoveryController(
          recoveryResult: cleanRecoveryResult,
          restoreEngine: fakeRestoreEngine,
          storageAdapter: fakeStorage,
          completionStore: completionStore,
          customTempDir: tempTestDir,
        );

        await tester.pumpWidget(createTestWidget(
          result: cleanRecoveryResult,
          controller: controller,
          brightness: Brightness.dark,
        ));
        await tester.pumpAndSettle();

        // 1. Scaffold background → #1E1E1E
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.backgroundColor, const Color(0xFF1E1E1E));

        // 2. Header Title → Colors.white (#FFFFFF)
        final headerTitle = tester.widget<Text>(find.text('Welcome back.'));
        expect(headerTitle.style?.color, Colors.white);

        // 3. Header Subtitle → #8E8E93
        final subtitle = tester.widget<Text>(find.text(
            'We found a Quick Notes backup from your previous session. Choose how you would like to proceed.'));
        expect(subtitle.style?.color, const Color(0xFF8E8E93));

        // 4. Backup card background → #2C2C2C, border → #38383A
        final cardContainers =
            tester.widgetList<Container>(find.byType(Container)).where((c) {
          final d = c.decoration;
          return d is BoxDecoration &&
              d.borderRadius == BorderRadius.circular(18);
        });
        expect(cardContainers.isNotEmpty, isTrue);
        final cardBox = cardContainers.first.decoration as BoxDecoration;
        expect(cardBox.color, const Color(0xFF2C2C2C));
        expect(cardBox.border?.top.color, const Color(0xFF38383A));

        // 5. Card Title → Colors.white
        final cardTitle =
            tester.widget<Text>(find.text('Latest Cloud Backup'));
        expect(cardTitle.style?.color, Colors.white);

        // 6. File size badge → background #38383A, text #8E8E93
        final badgeText = tester.widget<Text>(find.text('2.4 MB'));
        expect(badgeText.style?.color, const Color(0xFF8E8E93));
        final badgeContainer = tester.widget<Container>(find
            .ancestor(
              of: find.text('2.4 MB'),
              matching: find.byType(Container),
            )
            .first);
        final badgeBox = badgeContainer.decoration as BoxDecoration;
        expect(badgeBox.color, const Color(0xFF38383A));

        // 7. Divider → #38383A
        final divider = tester.widget<Divider>(find.byType(Divider));
        expect(divider.color, const Color(0xFF38383A));

        // 8. Metric chips → background #38383A, icon #8E8E93, label Colors.white
        final notesChipText = tester.widget<Text>(find.text('42 Notes'));
        expect(notesChipText.style?.color, Colors.white);
        final notesChipContainer = tester.widget<Container>(find
            .ancestor(
              of: find.text('42 Notes'),
              matching: find.byType(Container),
            )
            .first);
        final chipBox = notesChipContainer.decoration as BoxDecoration;
        expect(chipBox.color, const Color(0xFF38383A));

        final notesIcon =
            tester.widget<Icon>(find.byIcon(Icons.description_outlined));
        expect(notesIcon.color, const Color(0xFF8E8E93));

        // 9. Intentional Blue Accents preserved in Dark Mode (#007AFF)
        final eyebrowText = tester.widget<Text>(find.text('RECOVERY'));
        expect(eyebrowText.style?.color, const Color(0xFF007AFF));
        final cloudIcon =
            tester.widget<Icon>(find.byIcon(Icons.cloud_done_rounded));
        expect(cloudIcon.color, const Color(0xFF007AFF));
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // GROUP B — Notices & Banners (Dark Mode)
    // ─────────────────────────────────────────────────────────────────────────
    group('Group B — Notices & Banners', () {
      testWidgets('Dark Mode: Clean Notice palette', (tester) async {
        final controller = FirstRunRecoveryController(
          recoveryResult: cleanRecoveryResult,
          restoreEngine: fakeRestoreEngine,
          storageAdapter: fakeStorage,
          completionStore: completionStore,
          customTempDir: tempTestDir,
        );

        await tester.pumpWidget(createTestWidget(
          result: cleanRecoveryResult,
          controller: controller,
          brightness: Brightness.dark,
        ));
        await tester.pumpAndSettle();

        // Clean notice: background #2634C759, border #38383A, icon #34C759, title #34C759, message #8E8E93
        final cleanTitle = tester.widget<Text>(find.text('Ready for Recovery'));
        expect(cleanTitle.style?.color, const Color(0xFF34C759));

        final cleanMsg = tester.widget<Text>(find.text(
            'This device is ready to restore your notes, folders, and tasks seamlessly.'));
        expect(cleanMsg.style?.color, const Color(0xFF8E8E93));

        final cleanIcon =
            tester.widget<Icon>(find.byIcon(Icons.check_circle_outline_rounded));
        expect(cleanIcon.color, const Color(0xFF34C759));

        final cleanContainer = tester.widget<Container>(find
            .ancestor(
              of: find.text('Ready for Recovery'),
              matching: find.byType(Container),
            )
            .first);
        final cleanBox = cleanContainer.decoration as BoxDecoration;
        expect(cleanBox.color, const Color(0x2634C759));
        expect(cleanBox.border?.top.color, const Color(0xFF38383A));
      });

      testWidgets('Dark Mode: Conflict Notice palette', (tester) async {
        final controller = FirstRunRecoveryController(
          recoveryResult: conflictRecoveryResult,
          restoreEngine: fakeRestoreEngine,
          storageAdapter: fakeStorage,
          completionStore: completionStore,
          customTempDir: tempTestDir,
        );

        await tester.pumpWidget(createTestWidget(
          result: conflictRecoveryResult,
          controller: controller,
          brightness: Brightness.dark,
        ));
        await tester.pumpAndSettle();

        // Conflict notice: background #26FF9500, border #38383A, icon #FF9500, title #FFCC00, message #8E8E93
        final conflictTitle =
            tester.widget<Text>(find.text('Local Data Found on This Device'));
        expect(conflictTitle.style?.color, const Color(0xFFFFCC00));

        final conflictMsg =
            tester.widget<Text>(find.textContaining('You already have'));
        expect(conflictMsg.style?.color, const Color(0xFF8E8E93));

        final conflictIcon =
            tester.widget<Icon>(find.byIcon(Icons.info_outline_rounded));
        expect(conflictIcon.color, const Color(0xFFFF9500));

        final conflictContainer = tester.widget<Container>(find
            .ancestor(
              of: find.text('Local Data Found on This Device'),
              matching: find.byType(Container),
            )
            .first);
        final conflictBox = conflictContainer.decoration as BoxDecoration;
        expect(conflictBox.color, const Color(0x26FF9500));
        expect(conflictBox.border?.top.color, const Color(0xFF38383A));
      });

      testWidgets('Dark Mode: Failure Banner palette', (tester) async {
        fakeRestoreEngine.resultToReturn = const RestoreResult(
          success: false,
          error: RestoreError(
            type: RestoreErrorType.validationFailed,
            message: 'corrupted',
          ),
        );

        final controller = FirstRunRecoveryController(
          recoveryResult: cleanRecoveryResult,
          restoreEngine: fakeRestoreEngine,
          storageAdapter: fakeStorage,
          completionStore: completionStore,
          customTempDir: tempTestDir,
        );

        await tester.pumpWidget(createTestWidget(
          result: cleanRecoveryResult,
          controller: controller,
          brightness: Brightness.dark,
        ));
        await tester.pumpAndSettle();

        // Trigger failure
        final restoreBtn = find.text('Restore Backup');
        await tester.ensureVisible(restoreBtn);
        await tester.tap(restoreBtn);
        await tester.pumpAndSettle();

        // Failure banner: bg #33FF453A, border #38383A, icon #FF453A, message #FF453A, Try Again #FF453A
        final failMsg = tester.widget<Text>(find.textContaining('corrupted'));
        expect(failMsg.style?.color, const Color(0xFFFF453A));

        final tryAgain = tester.widget<Text>(find.text('Try Again'));
        expect(tryAgain.style?.color, const Color(0xFFFF453A));

        final failIcon =
            tester.widget<Icon>(find.byIcon(Icons.error_outline_rounded));
        expect(failIcon.color, const Color(0xFFFF453A));

        final failContainer = tester.widget<Container>(find
            .ancestor(
              of: find.text('Try Again'),
              matching: find.byType(Container),
            )
            .first);
        final failBox = failContainer.decoration as BoxDecoration;
        expect(failBox.color, const Color(0x33FF453A));
        expect(failBox.border?.top.color, const Color(0xFF38383A));
      });

      testWidgets('Dark Mode: Success Banner palette', (tester) async {
        final controller = FirstRunRecoveryController(
          recoveryResult: cleanRecoveryResult,
          restoreEngine: fakeRestoreEngine,
          storageAdapter: fakeStorage,
          completionStore: completionStore,
          customTempDir: tempTestDir,
        );

        await tester.pumpWidget(createTestWidget(
          result: cleanRecoveryResult,
          controller: controller,
          brightness: Brightness.dark,
        ));
        await tester.pumpAndSettle();

        // Trigger restore success
        final restoreBtn = find.text('Restore Backup');
        await tester.ensureVisible(restoreBtn);
        await tester.tap(restoreBtn);
        await tester.pumpAndSettle();

        // Success banner: bg #2634C759, border #38383A, icon #34C759, title #34C759, message #8E8E93
        final succTitle = tester.widget<Text>(find.text("You're all set."));
        expect(succTitle.style?.color, const Color(0xFF34C759));

        final succMsg =
            tester.widget<Text>(find.text('Your Quick Notes data is ready.'));
        expect(succMsg.style?.color, const Color(0xFF8E8E93));

        final succIcon =
            tester.widget<Icon>(find.byIcon(Icons.check_circle_rounded));
        expect(succIcon.color, const Color(0xFF34C759));

        final succContainer = tester.widget<Container>(find
            .ancestor(
              of: find.text("You're all set."),
              matching: find.byType(Container),
            )
            .first);
        final succBox = succContainer.decoration as BoxDecoration;
        expect(succBox.color, const Color(0x2634C759));
        expect(succBox.border?.top.color, const Color(0xFF38383A));
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // GROUP C — Buttons & Controls (Dark Mode)
    // ─────────────────────────────────────────────────────────────────────────
    group('Group C — Buttons & Controls', () {
      testWidgets('Dark Mode: Restore Backup, Keep Local Data, Start Fresh',
          (tester) async {
        final controller = FirstRunRecoveryController(
          recoveryResult: conflictRecoveryResult,
          restoreEngine: fakeRestoreEngine,
          storageAdapter: fakeStorage,
          completionStore: completionStore,
          customTempDir: tempTestDir,
        );

        await tester.pumpWidget(createTestWidget(
          result: conflictRecoveryResult,
          controller: controller,
          brightness: Brightness.dark,
        ));
        await tester.pumpAndSettle();

        // 1. Primary Action: Restore Backup
        // Background = Colors.white, Text = #1C1C1E
        final restoreText = tester.widget<Text>(find.text('Restore Backup'));
        expect(restoreText.style?.color, const Color(0xFF1C1C1E));
        final restoreContainer = tester.widget<Container>(find
            .ancestor(
              of: find.text('Restore Backup'),
              matching: find.byType(Container),
            )
            .first);
        final restoreBox = restoreContainer.decoration as BoxDecoration;
        expect(restoreBox.color, Colors.white);

        // 2. Secondary Action: Keep Local Data
        // Background = #38383A, Border = #38383A, Text = Colors.white
        final keepText = tester.widget<Text>(find.text('Keep Local Data'));
        expect(keepText.style?.color, Colors.white);
        final keepContainer = tester.widget<Container>(find
            .ancestor(
              of: find.text('Keep Local Data'),
              matching: find.byType(Container),
            )
            .first);
        final keepBox = keepContainer.decoration as BoxDecoration;
        expect(keepBox.color, const Color(0xFF38383A));
        expect(keepBox.border?.top.color, const Color(0xFF38383A));

        // 3. Tertiary Action: Start Fresh
        // Text = #8E8E93
        final startFreshText = tester.widget<Text>(find.text('Start Fresh'));
        expect(startFreshText.style?.color, const Color(0xFF8E8E93));
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // GROUP D — Light Mode Regression (Preservation of 100% Light Palette)
    // ─────────────────────────────────────────────────────────────────────────
    group('Group D — Light Mode Regression', () {
      testWidgets('Light Mode: Surfaces, Cards, Badges, Chips, and Typography',
          (tester) async {
        final controller = FirstRunRecoveryController(
          recoveryResult: cleanRecoveryResult,
          restoreEngine: fakeRestoreEngine,
          storageAdapter: fakeStorage,
          completionStore: completionStore,
          customTempDir: tempTestDir,
        );

        await tester.pumpWidget(createTestWidget(
          result: cleanRecoveryResult,
          controller: controller,
          brightness: Brightness.light,
        ));
        await tester.pumpAndSettle();

        // 1. Canvas → #F2F2F7
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.backgroundColor, const Color(0xFFF2F2F7));

        // 2. Header Title → #1C1C1E
        final headerTitle = tester.widget<Text>(find.text('Welcome back.'));
        expect(headerTitle.style?.color, const Color(0xFF1C1C1E));

        // 3. Header Subtitle → #6E6E73
        final subtitle = tester.widget<Text>(find.text(
            'We found a Quick Notes backup from your previous session. Choose how you would like to proceed.'));
        expect(subtitle.style?.color, const Color(0xFF6E6E73));

        // 4. Backup card background → Colors.white, border → #E5E5EA
        final cardContainers =
            tester.widgetList<Container>(find.byType(Container)).where((c) {
          final d = c.decoration;
          return d is BoxDecoration &&
              d.borderRadius == BorderRadius.circular(18);
        });
        final cardBox = cardContainers.first.decoration as BoxDecoration;
        expect(cardBox.color, Colors.white);
        expect(cardBox.border?.top.color, const Color(0xFFE5E5EA));

        // 5. Card Title → #1C1C1E
        final cardTitle =
            tester.widget<Text>(find.text('Latest Cloud Backup'));
        expect(cardTitle.style?.color, const Color(0xFF1C1C1E));

        // 6. File size badge → background #F2F2F7, text #6E6E73
        final badgeText = tester.widget<Text>(find.text('2.4 MB'));
        expect(badgeText.style?.color, const Color(0xFF6E6E73));
        final badgeContainer = tester.widget<Container>(find
            .ancestor(
              of: find.text('2.4 MB'),
              matching: find.byType(Container),
            )
            .first);
        final badgeBox = badgeContainer.decoration as BoxDecoration;
        expect(badgeBox.color, const Color(0xFFF2F2F7));

        // 7. Divider → #E5E5EA
        final divider = tester.widget<Divider>(find.byType(Divider));
        expect(divider.color, const Color(0xFFE5E5EA));

        // 8. Metric chips → background #F2F2F7, icon #6E6E73, label #3A3A3C
        final notesChipText = tester.widget<Text>(find.text('42 Notes'));
        expect(notesChipText.style?.color, const Color(0xFF3A3A3C));
        final notesChipContainer = tester.widget<Container>(find
            .ancestor(
              of: find.text('42 Notes'),
              matching: find.byType(Container),
            )
            .first);
        final chipBox = notesChipContainer.decoration as BoxDecoration;
        expect(chipBox.color, const Color(0xFFF2F2F7));

        final notesIcon =
            tester.widget<Icon>(find.byIcon(Icons.description_outlined));
        expect(notesIcon.color, const Color(0xFF6E6E73));

        // 9. Clean Notice in Light Mode: bg #F0FDF4, border #BBF7D0, icon #16A34A, title #15803D, msg #166534
        final cleanTitle = tester.widget<Text>(find.text('Ready for Recovery'));
        expect(cleanTitle.style?.color, const Color(0xFF15803D));
        final cleanMsg = tester.widget<Text>(find.text(
            'This device is ready to restore your notes, folders, and tasks seamlessly.'));
        expect(cleanMsg.style?.color, const Color(0xFF166534));
        final cleanIcon =
            tester.widget<Icon>(find.byIcon(Icons.check_circle_outline_rounded));
        expect(cleanIcon.color, const Color(0xFF16A34A));
        final cleanContainer = tester.widget<Container>(find
            .ancestor(
              of: find.text('Ready for Recovery'),
              matching: find.byType(Container),
            )
            .first);
        final cleanBox = cleanContainer.decoration as BoxDecoration;
        expect(cleanBox.color, const Color(0xFFF0FDF4));
        expect(cleanBox.border?.top.color, const Color(0xFFBBF7D0));

        // 10. Primary Action: Restore Backup in Light Mode: bg #1C1C1E, text Colors.white
        final restoreText = tester.widget<Text>(find.text('Restore Backup'));
        expect(restoreText.style?.color, Colors.white);
        final restoreContainer = tester.widget<Container>(find
            .ancestor(
              of: find.text('Restore Backup'),
              matching: find.byType(Container),
            )
            .first);
        final restoreBox = restoreContainer.decoration as BoxDecoration;
        expect(restoreBox.color, const Color(0xFF1C1C1E));

        // 11. Tertiary Action: Start Fresh in Light Mode: text #6E6E73
        final startFreshText = tester.widget<Text>(find.text('Start Fresh'));
        expect(startFreshText.style?.color, const Color(0xFF6E6E73));

        // 12. Intentional Blue Accents in Light Mode (#007AFF)
        final eyebrowText = tester.widget<Text>(find.text('RECOVERY'));
        expect(eyebrowText.style?.color, const Color(0xFF007AFF));
        final cloudIcon =
            tester.widget<Icon>(find.byIcon(Icons.cloud_done_rounded));
        expect(cloudIcon.color, const Color(0xFF007AFF));
      });

      testWidgets('Light Mode: Conflict, Failure, Success and Secondary button',
          (tester) async {
        final controller = FirstRunRecoveryController(
          recoveryResult: conflictRecoveryResult,
          restoreEngine: fakeRestoreEngine,
          storageAdapter: fakeStorage,
          completionStore: completionStore,
          customTempDir: tempTestDir,
        );

        await tester.pumpWidget(createTestWidget(
          result: conflictRecoveryResult,
          controller: controller,
          brightness: Brightness.light,
        ));
        await tester.pumpAndSettle();

        // 1. Conflict Notice in Light Mode: bg #FFFBEB, border #FDE68A, icon #D97706, title #92400E, msg #B45309
        final conflictTitle =
            tester.widget<Text>(find.text('Local Data Found on This Device'));
        expect(conflictTitle.style?.color, const Color(0xFF92400E));
        final conflictMsg =
            tester.widget<Text>(find.textContaining('You already have'));
        expect(conflictMsg.style?.color, const Color(0xFFB45309));
        final conflictIcon =
            tester.widget<Icon>(find.byIcon(Icons.info_outline_rounded));
        expect(conflictIcon.color, const Color(0xFFD97706));
        final conflictContainer = tester.widget<Container>(find
            .ancestor(
              of: find.text('Local Data Found on This Device'),
              matching: find.byType(Container),
            )
            .first);
        final conflictBox = conflictContainer.decoration as BoxDecoration;
        expect(conflictBox.color, const Color(0xFFFFFBEB));
        expect(conflictBox.border?.top.color, const Color(0xFFFDE68A));

        // 2. Secondary Action in Light Mode: Keep Local Data: bg Colors.white, border #E5E5EA, text #1C1C1E
        final keepText = tester.widget<Text>(find.text('Keep Local Data'));
        expect(keepText.style?.color, const Color(0xFF1C1C1E));
        final keepContainer = tester.widget<Container>(find
            .ancestor(
              of: find.text('Keep Local Data'),
              matching: find.byType(Container),
            )
            .first);
        final keepBox = keepContainer.decoration as BoxDecoration;
        expect(keepBox.color, Colors.white);
        expect(keepBox.border?.top.color, const Color(0xFFE5E5EA));

        // 3. Success Banner in Light Mode: bg #F0FDF4, border #86EFAC, icon #16A34A, title #15803D, msg #166534
        final restoreBtn = find.text('Restore Backup');
        await tester.ensureVisible(restoreBtn);
        await tester.tap(restoreBtn);
        await tester.pumpAndSettle();

        final succTitle = tester.widget<Text>(find.text("You're all set."));
        expect(succTitle.style?.color, const Color(0xFF15803D));
        final succMsg =
            tester.widget<Text>(find.text('Your Quick Notes data is ready.'));
        expect(succMsg.style?.color, const Color(0xFF166534));
        final succIcon =
            tester.widget<Icon>(find.byIcon(Icons.check_circle_rounded));
        expect(succIcon.color, const Color(0xFF16A34A));
        final succContainer = tester.widget<Container>(find
            .ancestor(
              of: find.text("You're all set."),
              matching: find.byType(Container),
            )
            .first);
        final succBox = succContainer.decoration as BoxDecoration;
        expect(succBox.color, const Color(0xFFF0FDF4));
        expect(succBox.border?.top.color, const Color(0xFF86EFAC));
      });
    });
  });
}
