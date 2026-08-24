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
import 'package:quick_notes/views/widgets/tactile_button.dart';

/// Fake storage adapter for widget tests
class FakeStorageAdapter implements BackupStorageAdapter {
  int downloadCallCount = 0;
  Duration? delay;

  @override
  Future<File> downloadBackup({
    required String remoteFileId,
    required File destinationLocalFile,
  }) async {
    downloadCallCount++;
    if (delay != null) {
      await Future.delayed(delay!);
    }
    destinationLocalFile.createSync(recursive: true);
    destinationLocalFile.writeAsStringSync('fake_content');
    return destinationLocalFile;
  }

  @override
  Future<List<RemoteBackupMetadata>> listBackups() async => [];
  @override
  Future<RemoteBackupMetadata> uploadBackup({required File localBackupFile, required BackupManifest manifest}) => throw UnimplementedError();
  @override
  Future<void> deleteBackup(String remoteFileId) => throw UnimplementedError();
}

/// Fake restore engine for widget tests
class FakeRestoreEngine extends RestoreEngine {
  int restoreCallCount = 0;
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
    restoreCallCount++;
    return resultToReturn;
  }
}

/// Testable controller tracking invocations
class MockFirstRunRecoveryController extends FirstRunRecoveryController {
  int restoreCalls = 0;
  int keepCalls = 0;
  int skipCalls = 0;
  int retryCalls = 0;

  MockFirstRunRecoveryController({
    required super.recoveryResult,
    super.restoreEngine,
    super.storageAdapter,
    super.completionStore,
    super.customTempDir,
  });

  @override
  Future<bool> restoreRecommendedBackup() async {
    restoreCalls++;
    return super.restoreRecommendedBackup();
  }

  @override
  Future<bool> keepLocalData() async {
    keepCalls++;
    return super.keepLocalData();
  }

  @override
  Future<bool> skipAndStartFresh() async {
    skipCalls++;
    return super.skipAndStartFresh();
  }

  @override
  Future<bool> retryRestore() async {
    retryCalls++;
    return super.retryRestore();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  group('FirstRunRecoveryScreen Widget Tests', () {
    late FakeStorageAdapter fakeStorage;
    late FakeRestoreEngine fakeRestoreEngine;
    late RecoveryCompletionStore completionStore;
    late Directory tempTestDir;

    final testHash = BackupIntegrity.sha256String('uid_123');

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
      localSummary: const LocalDataSummary(noteCount: 12, folderCount: 2, taskCount: 4),
      recommendedBackup: testBackupMetadata,
      eligibleBackups: [testBackupMetadata, testBackupMetadata],
    );

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      fakeStorage = FakeStorageAdapter();
      fakeRestoreEngine = FakeRestoreEngine();
      completionStore = RecoveryCompletionStore();
      tempTestDir = Directory.systemTemp.createTempSync('recovery_screen_test_');
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
    }) {
      return MaterialApp(
        home: FirstRunRecoveryScreen(
          recoveryResult: result,
          controller: controller,
        ),
      );
    }

    testWidgets('1. eligibleEmptyLocal renders clean recovery state', (tester) async {
      final controller = MockFirstRunRecoveryController(
        recoveryResult: cleanRecoveryResult,
        restoreEngine: fakeRestoreEngine,
        storageAdapter: fakeStorage,
        completionStore: completionStore,
        customTempDir: tempTestDir,
      );

      await tester.pumpWidget(createTestWidget(result: cleanRecoveryResult, controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('RECOVERY'), findsOneWidget);
      expect(find.text('Welcome back.'), findsOneWidget);
      expect(find.text('Ready for Recovery'), findsOneWidget);
      expect(find.text('Restore Backup'), findsOneWidget);
      expect(find.text('Start Fresh'), findsOneWidget);
      expect(find.text('Keep Local Data'), findsNothing); // Should not appear in clean mode
    });

    testWidgets('2. eligibleConflictLocal renders local-data conflict state', (tester) async {
      final controller = MockFirstRunRecoveryController(
        recoveryResult: conflictRecoveryResult,
        restoreEngine: fakeRestoreEngine,
        storageAdapter: fakeStorage,
        completionStore: completionStore,
        customTempDir: tempTestDir,
      );

      await tester.pumpWidget(createTestWidget(result: conflictRecoveryResult, controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('Local Data Found on This Device'), findsOneWidget);
      expect(find.textContaining('You already have 12 notes, 2 folders, and 4 tasks'), findsOneWidget);
      expect(find.text('Keep Local Data'), findsOneWidget);
      expect(find.text('Start Fresh'), findsOneWidget);
      expect(find.text('Restore Backup'), findsOneWidget);
    });

    testWidgets('3. Backup metadata is displayed correctly', (tester) async {
      final controller = MockFirstRunRecoveryController(
        recoveryResult: cleanRecoveryResult,
        restoreEngine: fakeRestoreEngine,
        storageAdapter: fakeStorage,
        completionStore: completionStore,
        customTempDir: tempTestDir,
      );

      await tester.pumpWidget(createTestWidget(result: cleanRecoveryResult, controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('Latest Cloud Backup'), findsOneWidget);
      expect(find.text('42 Notes'), findsOneWidget);
      expect(find.text('3 Folders'), findsOneWidget);
      expect(find.text('5 Tasks'), findsOneWidget);
      expect(find.text('2 Attachments'), findsOneWidget);
      expect(find.text('2.4 MB'), findsOneWidget);
    });

    testWidgets('4. Local data counts are displayed correctly when present', (tester) async {
      final controller = MockFirstRunRecoveryController(
        recoveryResult: conflictRecoveryResult,
        restoreEngine: fakeRestoreEngine,
        storageAdapter: fakeStorage,
        completionStore: completionStore,
        customTempDir: tempTestDir,
      );

      await tester.pumpWidget(createTestWidget(result: conflictRecoveryResult, controller: controller));
      await tester.pumpAndSettle();

      expect(find.textContaining('12 notes'), findsOneWidget);
      expect(find.textContaining('2 folders'), findsOneWidget);
      expect(find.textContaining('4 tasks'), findsOneWidget);
    });

    testWidgets('5. Missing optional metadata (0 attachments) does not crash the UI', (tester) async {
      final zeroAttachmentBackup = RemoteBackupMetadata(
        remoteFileId: 'rf_0',
        fileName: 'backup_zero.qnb',
        fileSizeBytes: 1024,
        backupId: 'b_zero',
        providerUserIdHash: testHash,
        createdAt: DateTime.parse('2026-08-18T10:42:00Z'),
        formatVersion: 1,
        databaseSchemaVersion: 18,
        appVersion: '1.0.0',
        noteCount: 1,
        folderCount: 0,
        taskCount: 0,
        attachmentCount: 0,
        sha256Checksum: 'chk',
      );

      final zeroResult = FirstRunRecoveryResult.eligibleEmptyLocal(
        localSummary: const LocalDataSummary.empty(),
        recommendedBackup: zeroAttachmentBackup,
        eligibleBackups: [zeroAttachmentBackup],
      );

      final controller = MockFirstRunRecoveryController(
        recoveryResult: zeroResult,
        restoreEngine: fakeRestoreEngine,
        storageAdapter: fakeStorage,
        completionStore: completionStore,
        customTempDir: tempTestDir,
      );

      await tester.pumpWidget(createTestWidget(result: zeroResult, controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('1 Notes'), findsOneWidget);
      expect(find.text('0 Folders'), findsOneWidget);
      expect(find.text('0 Tasks'), findsOneWidget);
      expect(find.textContaining('Attachments'), findsNothing); // gracefully omitted
    });

    testWidgets('6. Tapping "Restore Backup" calls controller.restoreRecommendedBackup()', (tester) async {
      final controller = MockFirstRunRecoveryController(
        recoveryResult: cleanRecoveryResult,
        restoreEngine: fakeRestoreEngine,
        storageAdapter: fakeStorage,
        completionStore: completionStore,
        customTempDir: tempTestDir,
      );

      await tester.pumpWidget(createTestWidget(result: cleanRecoveryResult, controller: controller));
      await tester.pumpAndSettle();

      final restoreBtn = find.text('Restore Backup');
      await tester.ensureVisible(restoreBtn);
      await tester.tap(restoreBtn);
      await tester.pumpAndSettle();

      expect(controller.restoreCalls, equals(1));
      expect(fakeStorage.downloadCallCount, equals(1));
      expect(fakeRestoreEngine.restoreCallCount, equals(1));
    });

    testWidgets('7. Tapping "Keep Local Data" calls controller.keepLocalData()', (tester) async {
      final controller = MockFirstRunRecoveryController(
        recoveryResult: conflictRecoveryResult,
        restoreEngine: fakeRestoreEngine,
        storageAdapter: fakeStorage,
        completionStore: completionStore,
        customTempDir: tempTestDir,
      );

      await tester.pumpWidget(createTestWidget(result: conflictRecoveryResult, controller: controller));
      await tester.pumpAndSettle();

      final keepBtn = find.text('Keep Local Data');
      await tester.ensureVisible(keepBtn);
      await tester.tap(keepBtn);
      await tester.pumpAndSettle();

      expect(controller.keepCalls, equals(1));
      expect(await completionStore.getStatus(testHash), equals(RecoveryCompletionStatus.keptLocalData));
    });

    testWidgets('8. Tapping "Start Fresh" calls controller.skipAndStartFresh()', (tester) async {
      final controller = MockFirstRunRecoveryController(
        recoveryResult: cleanRecoveryResult,
        restoreEngine: fakeRestoreEngine,
        storageAdapter: fakeStorage,
        completionStore: completionStore,
        customTempDir: tempTestDir,
      );

      await tester.pumpWidget(createTestWidget(result: cleanRecoveryResult, controller: controller));
      await tester.pumpAndSettle();

      final startFreshBtn = find.text('Start Fresh');
      await tester.ensureVisible(startFreshBtn);
      await tester.tap(startFreshBtn);
      await tester.pumpAndSettle();

      expect(controller.skipCalls, equals(1));
      expect(await completionStore.getStatus(testHash), equals(RecoveryCompletionStatus.skipped));
    });

    testWidgets('9. Unsupported actions are not rendered', (tester) async {
      final controller = MockFirstRunRecoveryController(
        recoveryResult: cleanRecoveryResult,
        restoreEngine: fakeRestoreEngine,
        storageAdapter: fakeStorage,
        completionStore: completionStore,
        customTempDir: tempTestDir,
      );

      await tester.pumpWidget(createTestWidget(result: cleanRecoveryResult, controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('Merge Notes'), findsNothing);
      expect(find.text('Combine Data'), findsNothing);
      expect(find.text('Sync Automatically'), findsNothing);
    });

    testWidgets('10. restoring state displays progress UI and disables decision buttons', (tester) async {
      fakeStorage.delay = const Duration(milliseconds: 200);

      final controller = MockFirstRunRecoveryController(
        recoveryResult: cleanRecoveryResult,
        restoreEngine: fakeRestoreEngine,
        storageAdapter: fakeStorage,
        completionStore: completionStore,
        customTempDir: tempTestDir,
      );

      await tester.pumpWidget(createTestWidget(result: cleanRecoveryResult, controller: controller));
      await tester.pumpAndSettle();

      // Tap restore
      final restoreBtn = find.text('Restore Backup');
      await tester.ensureVisible(restoreBtn);
      await tester.tap(restoreBtn);
      await tester.pump(); // Advance frame to render restoring UI

      // Check progress UI
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Downloading backup...'), findsOneWidget);
      expect(find.text('Start Fresh'), findsNothing); // Secondary buttons hidden during restore

      // Complete async
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
    });

    testWidgets('11. restoreFailed displays sanitized errorMessage and exposes Try Again', (tester) async {
      fakeRestoreEngine.resultToReturn = const RestoreResult(
        success: false,
        error: RestoreError(
          type: RestoreErrorType.validationFailed,
          message: 'corrupted format',
        ),
      );

      final controller = MockFirstRunRecoveryController(
        recoveryResult: cleanRecoveryResult,
        restoreEngine: fakeRestoreEngine,
        storageAdapter: fakeStorage,
        completionStore: completionStore,
        customTempDir: tempTestDir,
      );

      await tester.pumpWidget(createTestWidget(result: cleanRecoveryResult, controller: controller));
      await tester.pumpAndSettle();

      final restoreBtn = find.text('Restore Backup');
      await tester.ensureVisible(restoreBtn);
      await tester.tap(restoreBtn);
      await tester.pumpAndSettle();

      expect(find.text('This backup file is invalid, corrupted, or uses an unsupported format.'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);

      // Tap Try Again
      final tryAgainBtn = find.text('Try Again');
      await tester.ensureVisible(tryAgainBtn);
      await tester.tap(tryAgainBtn);
      await tester.pumpAndSettle();

      expect(controller.retryCalls, equals(1));
    });

    testWidgets('12. completed displays success state', (tester) async {
      final controller = MockFirstRunRecoveryController(
        recoveryResult: cleanRecoveryResult,
        restoreEngine: fakeRestoreEngine,
        storageAdapter: fakeStorage,
        completionStore: completionStore,
        customTempDir: tempTestDir,
      );

      await tester.pumpWidget(createTestWidget(result: cleanRecoveryResult, controller: controller));
      await tester.pumpAndSettle();

      final restoreBtn = find.text('Restore Backup');
      await tester.ensureVisible(restoreBtn);
      await tester.tap(restoreBtn);
      await tester.pumpAndSettle();

      expect(find.text("You're all set."), findsOneWidget);
      expect(find.text('Your Quick Notes data is ready.'), findsOneWidget);
    });

    testWidgets('13. Constrained small phone layout does not overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = MockFirstRunRecoveryController(
        recoveryResult: conflictRecoveryResult,
        restoreEngine: fakeRestoreEngine,
        storageAdapter: fakeStorage,
        completionStore: completionStore,
        customTempDir: tempTestDir,
      );

      await tester.pumpWidget(createTestWidget(result: conflictRecoveryResult, controller: controller));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('14. Duplicate restore taps while restoring do not trigger multiple operations', (tester) async {
      fakeStorage.delay = const Duration(milliseconds: 300);

      final controller = MockFirstRunRecoveryController(
        recoveryResult: cleanRecoveryResult,
        restoreEngine: fakeRestoreEngine,
        storageAdapter: fakeStorage,
        completionStore: completionStore,
        customTempDir: tempTestDir,
      );

      await tester.pumpWidget(createTestWidget(result: cleanRecoveryResult, controller: controller));
      await tester.pumpAndSettle();

      final restoreBtn = find.text('Restore Backup');
      await tester.ensureVisible(restoreBtn);
      await tester.tap(restoreBtn);
      await tester.pump(); // In-flight

      // Attempt second tap on the TactileButton while restoring
      final buttonFinder = find.byType(TactileButton).first;
      await tester.tap(buttonFinder, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(fakeStorage.downloadCallCount, equals(1));
      expect(fakeRestoreEngine.restoreCallCount, equals(1));
    });

    testWidgets('15. Screen does not perform direct database or Drive operations without controller', (tester) async {
      final controller = MockFirstRunRecoveryController(
        recoveryResult: cleanRecoveryResult,
        restoreEngine: fakeRestoreEngine,
        storageAdapter: fakeStorage,
        completionStore: completionStore,
        customTempDir: tempTestDir,
      );

      await tester.pumpWidget(createTestWidget(result: cleanRecoveryResult, controller: controller));
      await tester.pumpAndSettle();

      // Zero calls prior to interaction
      expect(fakeStorage.downloadCallCount, equals(0));
      expect(fakeRestoreEngine.restoreCallCount, equals(0));
      expect(controller.restoreCalls, equals(0));
    });
  });
}
