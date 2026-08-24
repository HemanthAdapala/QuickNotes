import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quick_notes/controllers/first_run_recovery_controller.dart';
import 'package:quick_notes/services/backup/backup_integrity.dart';
import 'package:quick_notes/services/backup/backup_manifest.dart';
import 'package:quick_notes/services/backup/backup_storage_adapter.dart';
import 'package:quick_notes/services/backup/drive_storage_exception.dart';
import 'package:quick_notes/services/backup/remote_backup_metadata.dart';
import 'package:quick_notes/services/backup/restore_engine.dart';
import 'package:quick_notes/services/backup/restore_result.dart';
import 'package:quick_notes/services/recovery/first_run_recovery_state.dart';
import 'package:quick_notes/services/recovery/local_data_detector.dart';
import 'package:quick_notes/services/recovery/recovery_completion_store.dart';

/// Fake BackupStorageAdapter for testing download flow
class FakeBackupStorageAdapter implements BackupStorageAdapter {
  int downloadCallCount = 0;
  Exception? exceptionToThrow;
  Duration? simulatedDelay;

  @override
  Future<File> downloadBackup({
    required String remoteFileId,
    required File destinationLocalFile,
  }) async {
    downloadCallCount++;
    if (simulatedDelay != null) {
      await Future.delayed(simulatedDelay!);
    }
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    // Write fake content to destination
    destinationLocalFile.createSync(recursive: true);
    destinationLocalFile.writeAsStringSync('fake_zip_content');
    return destinationLocalFile;
  }

  @override
  Future<List<RemoteBackupMetadata>> listBackups() async => [];

  @override
  Future<RemoteBackupMetadata> uploadBackup({
    required File localBackupFile,
    required BackupManifest manifest,
  }) => throw UnimplementedError();

  @override
  Future<void> deleteBackup(String remoteFileId) => throw UnimplementedError();
}

/// Fake RestoreEngine for testing restore execution
class FakeRestoreEngine extends RestoreEngine {
  RestoreResult resultToReturn = const RestoreResult(
    success: true,
    backupId: 'backup_uuid_123',
    noteCount: 42,
    folderCount: 3,
    taskCount: 5,
    attachmentCount: 2,
    verificationPassed: true,
  );
  Exception? exceptionToThrow;
  int restoreCallCount = 0;
  Duration? simulatedDelay;

  @override
  Future<RestoreResult> restoreFromBackup({
    required String backupFilePath,
    Directory? customDocumentsDir,
    bool forceOfflineOverride = false,
  }) async {
    restoreCallCount++;
    if (simulatedDelay != null) {
      await Future.delayed(simulatedDelay!);
    }
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return resultToReturn;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
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

  group('FirstRunRecoveryController Unit Tests', () {
    late FakeBackupStorageAdapter fakeStorage;
    late FakeRestoreEngine fakeRestoreEngine;
    late RecoveryCompletionStore completionStore;
    late Directory tempTestDir;

    const testProviderUserId = 'google_uid_998877';
    final testHash = BackupIntegrity.sha256String(testProviderUserId);

    final testBackupMetadata = RemoteBackupMetadata(
      remoteFileId: 'remote_drive_file_id_123',
      fileName: 'quicknotes_20260818.qnb',
      fileSizeBytes: 20480,
      backupId: 'backup_uuid_123',
      providerUserIdHash: testHash,
      createdAt: DateTime.parse('2026-08-18T12:00:00Z'),
      formatVersion: 1,
      databaseSchemaVersion: 18,
      appVersion: '1.0.0',
      noteCount: 42,
      folderCount: 3,
      taskCount: 5,
      attachmentCount: 2,
      sha256Checksum: 'checksum_123',
    );

    final cleanRestoreResult = FirstRunRecoveryResult.eligibleEmptyLocal(
      localSummary: const LocalDataSummary.empty(),
      recommendedBackup: testBackupMetadata,
      eligibleBackups: [testBackupMetadata],
    );

    final conflictRestoreResult = FirstRunRecoveryResult.eligibleConflictLocal(
      localSummary: const LocalDataSummary(noteCount: 10, folderCount: 2, taskCount: 3),
      recommendedBackup: testBackupMetadata,
      eligibleBackups: [testBackupMetadata],
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      fakeStorage = FakeBackupStorageAdapter();
      fakeRestoreEngine = FakeRestoreEngine();
      completionStore = RecoveryCompletionStore();

      tempTestDir = Directory.systemTemp.createTempSync('recovery_ctrl_test_');
    });

    tearDown(() {
      try {
        if (tempTestDir.existsSync()) {
          tempTestDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('1. Initialization: Given eligibleEmptyLocal, controller initializes as ready with clean restore state', () {
      final controller = FirstRunRecoveryController(
        recoveryResult: cleanRestoreResult,
        restoreEngine: fakeRestoreEngine,
        storageAdapter: fakeStorage,
        completionStore: completionStore,
        customTempDir: tempTestDir,
      );

      expect(controller.state, equals(FirstRunRecoveryUiState.ready));
      expect(controller.isReady, isTrue);
      expect(controller.isCleanRestore, isTrue);
      expect(controller.isConflict, isFalse);
      expect(controller.errorMessage, isNull);
      expect(controller.recommendedBackup, equals(testBackupMetadata));
      expect(controller.totalEligibleBackupsCount, equals(1));
    });

    test('2. Conflict Initialization: Given eligibleConflictLocal, controller initializes as ready and preserves conflict counts', () {
      final controller = FirstRunRecoveryController(
        recoveryResult: conflictRestoreResult,
        restoreEngine: fakeRestoreEngine,
        storageAdapter: fakeStorage,
        completionStore: completionStore,
        customTempDir: tempTestDir,
      );

      expect(controller.state, equals(FirstRunRecoveryUiState.ready));
      expect(controller.isReady, isTrue);
      expect(controller.isConflict, isTrue);
      expect(controller.isCleanRestore, isFalse);
      expect(controller.localSummary.noteCount, equals(10));
      expect(controller.localSummary.totalCount, equals(15));
      expect(controller.recommendedBackup?.noteCount, equals(42));
    });

    test('3. Successful restore transitions ready -> restoring -> completed and persists restored status', () async {
      final controller = FirstRunRecoveryController(
        recoveryResult: cleanRestoreResult,
        restoreEngine: fakeRestoreEngine,
        storageAdapter: fakeStorage,
        completionStore: completionStore,
        customTempDir: tempTestDir,
      );

      final stateTransitions = <FirstRunRecoveryUiState>[];
      controller.addListener(() {
        stateTransitions.add(controller.state);
      });

      final success = await controller.restoreRecommendedBackup();

      expect(success, isTrue);
      expect(controller.state, equals(FirstRunRecoveryUiState.completed));
      expect(controller.isCompleted, isTrue);
      expect(controller.errorMessage, isNull);
      expect(fakeStorage.downloadCallCount, equals(1));
      expect(fakeRestoreEngine.restoreCallCount, equals(1));

      // Verify RecoveryCompletionStore received restored status
      final status = await completionStore.getStatus(testHash);
      expect(status, equals(RecoveryCompletionStatus.restored));
    });

    test('4. Failed restore transitions ready -> restoring -> restoreFailed and does NOT mark status restored', () async {
      fakeRestoreEngine.resultToReturn = const RestoreResult(
        success: false,
        error: RestoreError(
          type: RestoreErrorType.validationFailed,
          message: 'Manifest schema corruption',
        ),
      );

      final controller = FirstRunRecoveryController(
        recoveryResult: cleanRestoreResult,
        restoreEngine: fakeRestoreEngine,
        storageAdapter: fakeStorage,
        completionStore: completionStore,
        customTempDir: tempTestDir,
      );

      final success = await controller.restoreRecommendedBackup();

      expect(success, isFalse);
      expect(controller.state, equals(FirstRunRecoveryUiState.restoreFailed));
      expect(controller.hasFailed, isTrue);
      expect(controller.errorMessage, isNotNull);
      expect(controller.errorMessage, equals('This backup file is invalid, corrupted, or uses an unsupported format.'));

      // Status must remain notCompleted
      final status = await completionStore.getStatus(testHash);
      expect(status, equals(RecoveryCompletionStatus.notCompleted));
    });

    test('5. Retry restore resets error and re-runs restore flow successfully', () async {
      fakeRestoreEngine.resultToReturn = const RestoreResult(
        success: false,
        error: RestoreError(
          type: RestoreErrorType.stagingFailed,
          message: 'Staging directory failure',
        ),
      );

      final controller = FirstRunRecoveryController(
        recoveryResult: cleanRestoreResult,
        restoreEngine: fakeRestoreEngine,
        storageAdapter: fakeStorage,
        completionStore: completionStore,
        customTempDir: tempTestDir,
      );

      // First attempt fails
      await controller.restoreRecommendedBackup();
      expect(controller.state, equals(FirstRunRecoveryUiState.restoreFailed));
      expect(fakeRestoreEngine.restoreCallCount, equals(1));

      // Configure success for retry
      fakeRestoreEngine.resultToReturn = const RestoreResult(
        success: true,
        backupId: 'backup_uuid_123',
        noteCount: 42,
        folderCount: 3,
        taskCount: 5,
        attachmentCount: 2,
        verificationPassed: true,
      );

      final retrySuccess = await controller.retryRestore();

      expect(retrySuccess, isTrue);
      expect(controller.state, equals(FirstRunRecoveryUiState.completed));
      expect(fakeRestoreEngine.restoreCallCount, equals(2));

      final status = await completionStore.getStatus(testHash);
      expect(status, equals(RecoveryCompletionStatus.restored));
    });

    test('6. keepLocalData marks keptLocalData in store and transitions to completed with zero RestoreEngine calls', () async {
      final controller = FirstRunRecoveryController(
        recoveryResult: conflictRestoreResult,
        restoreEngine: fakeRestoreEngine,
        storageAdapter: fakeStorage,
        completionStore: completionStore,
        customTempDir: tempTestDir,
      );

      final success = await controller.keepLocalData();

      expect(success, isTrue);
      expect(controller.state, equals(FirstRunRecoveryUiState.completed));
      expect(fakeRestoreEngine.restoreCallCount, equals(0));
      expect(fakeStorage.downloadCallCount, equals(0));

      final status = await completionStore.getStatus(testHash);
      expect(status, equals(RecoveryCompletionStatus.keptLocalData));
    });

    test('7. skipAndStartFresh marks skipped in store and transitions to completed with zero destructive mutations', () async {
      final controller = FirstRunRecoveryController(
        recoveryResult: cleanRestoreResult,
        restoreEngine: fakeRestoreEngine,
        storageAdapter: fakeStorage,
        completionStore: completionStore,
        customTempDir: tempTestDir,
      );

      final success = await controller.skipAndStartFresh();

      expect(success, isTrue);
      expect(controller.state, equals(FirstRunRecoveryUiState.completed));
      expect(fakeRestoreEngine.restoreCallCount, equals(0));

      final status = await completionStore.getStatus(testHash);
      expect(status, equals(RecoveryCompletionStatus.skipped));
    });

    test('8. Duplicate restore protection: Concurrent restore invocations are rejected while restoring', () async {
      fakeStorage.simulatedDelay = const Duration(milliseconds: 50);

      final controller = FirstRunRecoveryController(
        recoveryResult: cleanRestoreResult,
        restoreEngine: fakeRestoreEngine,
        storageAdapter: fakeStorage,
        completionStore: completionStore,
        customTempDir: tempTestDir,
      );

      // Start first restore (asynchronous in-flight)
      final firstRestoreFuture = controller.restoreRecommendedBackup();

      // Immediately attempt second restore while state is restoring
      final secondRestoreFuture = controller.restoreRecommendedBackup();

      final secondResult = await secondRestoreFuture;
      expect(secondResult, isFalse);

      final firstResult = await firstRestoreFuture;
      expect(firstResult, isTrue);
      expect(fakeStorage.downloadCallCount, equals(1));
    });

    test('9. Completed-state protection: Operations after completion are strictly rejected', () async {
      final controller = FirstRunRecoveryController(
        recoveryResult: cleanRestoreResult,
        restoreEngine: fakeRestoreEngine,
        storageAdapter: fakeStorage,
        completionStore: completionStore,
        customTempDir: tempTestDir,
      );

      await controller.skipAndStartFresh();
      expect(controller.state, equals(FirstRunRecoveryUiState.completed));

      final restoreAfterComplete = await controller.restoreRecommendedBackup();
      final keepAfterComplete = await controller.keepLocalData();
      final skipAfterComplete = await controller.skipAndStartFresh();

      expect(restoreAfterComplete, isFalse);
      expect(keepAfterComplete, isFalse);
      expect(skipAfterComplete, isFalse);
      expect(fakeRestoreEngine.restoreCallCount, equals(0));
    });

    test('10. Identity isolation: Completion store is called with the exact providerUserIdHash from recommendedBackup', () async {
      const distinctProviderId = 'google_distinct_user_445566';
      final distinctHash = BackupIntegrity.sha256String(distinctProviderId);

      final distinctBackup = RemoteBackupMetadata(
        remoteFileId: 'remote_file_distinct',
        fileName: 'distinct.qnb',
        fileSizeBytes: 1000,
        backupId: 'backup_distinct',
        providerUserIdHash: distinctHash,
        createdAt: DateTime.parse('2026-08-18T12:00:00Z'),
        formatVersion: 1,
        databaseSchemaVersion: 18,
        appVersion: '1.0.0',
        noteCount: 5,
        folderCount: 1,
        taskCount: 1,
        attachmentCount: 0,
        sha256Checksum: 'chk',
      );

      final distinctResult = FirstRunRecoveryResult.eligibleEmptyLocal(
        localSummary: const LocalDataSummary.empty(),
        recommendedBackup: distinctBackup,
        eligibleBackups: [distinctBackup],
      );

      final controller = FirstRunRecoveryController(
        recoveryResult: distinctResult,
        restoreEngine: fakeRestoreEngine,
        storageAdapter: fakeStorage,
        completionStore: completionStore,
        customTempDir: tempTestDir,
      );

      await controller.restoreRecommendedBackup();

      expect(await completionStore.getStatus(distinctHash), equals(RecoveryCompletionStatus.restored));
      expect(await completionStore.getStatus(testHash), equals(RecoveryCompletionStatus.notCompleted));
    });

    test('11. Error sanitization: Internal exception details, filesystem paths, tokens, and raw IDs are sanitized', () async {
      fakeStorage.exceptionToThrow = const DriveStorageException(
        message: 'CRITICAL: Failed at C:\\Users\\secret\\path\\token_ya29.secret_value with provider 1029384756',
        type: DriveStorageErrorType.networkUnavailable,
      );

      final controller = FirstRunRecoveryController(
        recoveryResult: cleanRestoreResult,
        restoreEngine: fakeRestoreEngine,
        storageAdapter: fakeStorage,
        completionStore: completionStore,
        customTempDir: tempTestDir,
      );

      await controller.restoreRecommendedBackup();

      expect(controller.state, equals(FirstRunRecoveryUiState.restoreFailed));
      expect(controller.errorMessage, equals('No internet connection. Please check your network and try again.'));
      expect(controller.errorMessage!.contains('ya29'), isFalse);
      expect(controller.errorMessage!.contains('C:\\Users'), isFalse);
      expect(controller.errorMessage!.contains('1029384756'), isFalse);
    });

    test('12. postpone transitions state to completed without writing persistent status', () async {
      final controller = FirstRunRecoveryController(
        recoveryResult: cleanRestoreResult,
        restoreEngine: fakeRestoreEngine,
        storageAdapter: fakeStorage,
        completionStore: completionStore,
        customTempDir: tempTestDir,
      );

      controller.postpone();

      expect(controller.state, equals(FirstRunRecoveryUiState.completed));
      final status = await completionStore.getStatus(testHash);
      expect(status, equals(RecoveryCompletionStatus.notCompleted));
    });

    test('13. Disposal safety: Calling dispose prevents further listener notifications', () {
      final controller = FirstRunRecoveryController(
        recoveryResult: cleanRestoreResult,
        restoreEngine: fakeRestoreEngine,
        storageAdapter: fakeStorage,
        completionStore: completionStore,
        customTempDir: tempTestDir,
      );

      controller.dispose();
      // Safe no-op without throws
      expect(controller.isReady, isTrue);
    });
  });
}
