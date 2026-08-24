import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:quick_notes/models/session_type.dart';
import 'package:quick_notes/services/backup/backup_integrity.dart';
import 'package:quick_notes/services/backup/backup_manifest.dart';
import 'package:quick_notes/services/backup/backup_storage_adapter.dart';
import 'package:quick_notes/services/backup/drive_storage_exception.dart';
import 'package:quick_notes/services/backup/remote_backup_metadata.dart';
import 'package:quick_notes/services/database_service.dart';
import 'package:quick_notes/services/session_manager.dart';
import 'package:quick_notes/services/recovery/first_run_recovery_detector.dart';
import 'package:quick_notes/services/recovery/first_run_recovery_state.dart';
import 'package:quick_notes/services/recovery/local_data_detector.dart';
import 'package:quick_notes/services/recovery/recovery_completion_store.dart';

/// Mock BackupStorageAdapter for testing without network or Google Drive
class FakeBackupStorageAdapter implements BackupStorageAdapter {
  List<RemoteBackupMetadata> backupsToReturn;
  Exception? exceptionToThrow;
  int listBackupsCallCount = 0;
  int downloadBackupCallCount = 0;
  int uploadBackupCallCount = 0;
  int deleteBackupCallCount = 0;
  Duration? simulatedDelay;
  Future<void> Function()? onListBackups;

  FakeBackupStorageAdapter({
    this.backupsToReturn = const [],
    this.exceptionToThrow,
    this.simulatedDelay,
    this.onListBackups,
  });

  @override
  Future<List<RemoteBackupMetadata>> listBackups() async {
    listBackupsCallCount++;
    if (simulatedDelay != null) {
      await Future.delayed(simulatedDelay!);
    }
    if (onListBackups != null) {
      await onListBackups!();
    }
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return backupsToReturn;
  }

  @override
  Future<File> downloadBackup({
    required String remoteFileId,
    required File destinationLocalFile,
  }) async {
    downloadBackupCallCount++;
    throw UnimplementedError('downloadBackup should never be called during detection');
  }

  @override
  Future<RemoteBackupMetadata> uploadBackup({
    required File localBackupFile,
    required BackupManifest manifest,
  }) async {
    uploadBackupCallCount++;
    throw UnimplementedError();
  }

  @override
  Future<void> deleteBackup(String remoteFileId) async {
    deleteBackupCallCount++;
    throw UnimplementedError();
  }
}

/// Fake LocalDataDetector for controlled testing of local counts
class FakeLocalDataDetector extends LocalDataDetector {
  LocalDataSummary summaryToReturn;
  int detectCount = 0;

  FakeLocalDataDetector({
    this.summaryToReturn = const LocalDataSummary.empty(),
  });

  @override
  Future<LocalDataSummary> detectLocalData({String? userId}) async {
    detectCount++;
    return summaryToReturn;
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

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('FirstRunRecoveryDetector Comprehensive Unit Tests', () {
    late FakeBackupStorageAdapter fakeStorage;
    late FakeLocalDataDetector fakeLocalDetector;
    late RecoveryCompletionStore completionStore;
    late FirstRunRecoveryDetector detector;

    const testUserId = 'usr_active_user_123';
    const testProviderUserId = 'google_uid_987654';
    final testHash = BackupIntegrity.sha256String(testProviderUserId);

    final validBackupA = RemoteBackupMetadata(
      remoteFileId: 'drive_file_id_a',
      fileName: 'quicknotes_20260818.qnb',
      fileSizeBytes: 10240,
      backupId: 'backup_a_id',
      providerUserIdHash: testHash,
      createdAt: DateTime.parse('2026-08-18T12:00:00Z'),
      formatVersion: 1,
      databaseSchemaVersion: 18,
      appVersion: '1.0.0',
      noteCount: 42,
      folderCount: 3,
      taskCount: 5,
      attachmentCount: 2,
      sha256Checksum: 'checksum_a',
    );

    final validBackupB = RemoteBackupMetadata(
      remoteFileId: 'drive_file_id_b',
      fileName: 'quicknotes_20260817.qnb',
      fileSizeBytes: 9800,
      backupId: 'backup_b_id',
      providerUserIdHash: testHash,
      createdAt: DateTime.parse('2026-08-17T10:00:00Z'),
      formatVersion: 1,
      databaseSchemaVersion: 18,
      appVersion: '1.0.0',
      noteCount: 38,
      folderCount: 3,
      taskCount: 5,
      attachmentCount: 2,
      sha256Checksum: 'checksum_b',
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SessionManager().init();
      fakeStorage = FakeBackupStorageAdapter();
      fakeLocalDetector = FakeLocalDataDetector();
      completionStore = RecoveryCompletionStore();

      detector = FirstRunRecoveryDetector(
        storageAdapter: fakeStorage,
        localDataDetector: fakeLocalDetector,
        completionStore: completionStore,
      );
    });

    test('1. Offline session immediately returns noRecoveryRequired and bypasses cloud storage', () async {
      fakeStorage.backupsToReturn = [validBackupA];

      final result = await detector.checkEligibility(
        overrideUserId: testUserId,
        overrideProviderUserIdHash: testHash,
        overrideSessionType: SessionType.offline,
      );

      expect(result.state, equals(FirstRunRecoveryState.noRecoveryRequired));
      expect(fakeStorage.listBackupsCallCount, equals(0)); // Zero network calls
    });

    test('2. Prior status "restored" bypasses cloud check and returns noRecoveryRequired', () async {
      await completionStore.setStatus(testHash, RecoveryCompletionStatus.restored);
      fakeStorage.backupsToReturn = [validBackupA];

      final result = await detector.checkEligibility(
        overrideUserId: testUserId,
        overrideProviderUserIdHash: testHash,
        overrideSessionType: SessionType.google,
      );

      expect(result.state, equals(FirstRunRecoveryState.noRecoveryRequired));
      expect(result.recoveryStatus, equals(RecoveryCompletionStatus.restored));
      expect(fakeStorage.listBackupsCallCount, equals(0));
    });

    test('3. Prior status "skipped" bypasses cloud check and returns noRecoveryRequired', () async {
      await completionStore.setStatus(testHash, RecoveryCompletionStatus.skipped);
      fakeStorage.backupsToReturn = [validBackupA];

      final result = await detector.checkEligibility(
        overrideUserId: testUserId,
        overrideProviderUserIdHash: testHash,
        overrideSessionType: SessionType.google,
      );

      expect(result.state, equals(FirstRunRecoveryState.noRecoveryRequired));
      expect(result.recoveryStatus, equals(RecoveryCompletionStatus.skipped));
      expect(fakeStorage.listBackupsCallCount, equals(0));
    });

    test('4. Prior status "keptLocalData" bypasses cloud check and returns noRecoveryRequired', () async {
      await completionStore.setStatus(testHash, RecoveryCompletionStatus.keptLocalData);
      fakeStorage.backupsToReturn = [validBackupA];

      final result = await detector.checkEligibility(
        overrideUserId: testUserId,
        overrideProviderUserIdHash: testHash,
        overrideSessionType: SessionType.google,
      );

      expect(result.state, equals(FirstRunRecoveryState.noRecoveryRequired));
      expect(result.recoveryStatus, equals(RecoveryCompletionStatus.keptLocalData));
      expect(fakeStorage.listBackupsCallCount, equals(0));
    });

    test('5. Google session + empty local + no cloud backup yields noRecoveryRequired and leaves status notCompleted', () async {
      fakeLocalDetector.summaryToReturn = const LocalDataSummary.empty();
      fakeStorage.backupsToReturn = [];

      final result = await detector.checkEligibility(
        overrideUserId: testUserId,
        overrideProviderUserIdHash: testHash,
        overrideSessionType: SessionType.google,
      );

      expect(result.state, equals(FirstRunRecoveryState.noRecoveryRequired));
      expect(result.recoveryStatus, equals(RecoveryCompletionStatus.notCompleted));
      expect(fakeStorage.listBackupsCallCount, equals(1));

      // Invariant check: Did NOT fabricate user skip decision
      final persistedStatus = await completionStore.getStatus(testHash);
      expect(persistedStatus, equals(RecoveryCompletionStatus.notCompleted));
    });

    test('6. Google session + existing local + no cloud backup yields noRecoveryRequired', () async {
      fakeLocalDetector.summaryToReturn = const LocalDataSummary(noteCount: 5, folderCount: 1, taskCount: 2);
      fakeStorage.backupsToReturn = [];

      final result = await detector.checkEligibility(
        overrideUserId: testUserId,
        overrideProviderUserIdHash: testHash,
        overrideSessionType: SessionType.google,
      );

      expect(result.state, equals(FirstRunRecoveryState.noRecoveryRequired));
      expect(result.localSummary.hasData, isTrue);
      expect(result.localSummary.noteCount, equals(5));
    });

    test('7. Google session + empty local + valid cloud backup yields eligibleEmptyLocal (Clean Restore)', () async {
      fakeLocalDetector.summaryToReturn = const LocalDataSummary.empty();
      fakeStorage.backupsToReturn = [validBackupA];

      final result = await detector.checkEligibility(
        overrideUserId: testUserId,
        overrideProviderUserIdHash: testHash,
        overrideSessionType: SessionType.google,
      );

      expect(result.state, equals(FirstRunRecoveryState.eligibleEmptyLocal));
      expect(result.isEligible, isTrue);
      expect(result.recommendedBackup, equals(validBackupA));
      expect(result.eligibleBackups.length, equals(1));
      expect(result.localSummary.hasData, isFalse);
    });

    test('8. Google session + existing local + valid cloud backup yields eligibleConflictLocal (Choice Flow)', () async {
      fakeLocalDetector.summaryToReturn = const LocalDataSummary(noteCount: 10, folderCount: 2, taskCount: 3);
      fakeStorage.backupsToReturn = [validBackupA];

      final result = await detector.checkEligibility(
        overrideUserId: testUserId,
        overrideProviderUserIdHash: testHash,
        overrideSessionType: SessionType.google,
      );

      expect(result.state, equals(FirstRunRecoveryState.eligibleConflictLocal));
      expect(result.isEligible, isTrue);
      expect(result.recommendedBackup, equals(validBackupA));
      expect(result.localSummary.hasData, isTrue);
      expect(result.localSummary.totalCount, equals(15));
    });

    test('9. Multiple backups are sorted newest-first and newest is recommended', () async {
      fakeLocalDetector.summaryToReturn = const LocalDataSummary.empty();
      // Provide in reverse chronological order
      fakeStorage.backupsToReturn = [validBackupB, validBackupA];

      final result = await detector.checkEligibility(
        overrideUserId: testUserId,
        overrideProviderUserIdHash: testHash,
        overrideSessionType: SessionType.google,
      );

      expect(result.state, equals(FirstRunRecoveryState.eligibleEmptyLocal));
      expect(result.recommendedBackup?.backupId, equals('backup_a_id')); // Newer backup
      expect(result.eligibleBackups.length, equals(2));
      expect(result.eligibleBackups[0].backupId, equals('backup_a_id'));
      expect(result.eligibleBackups[1].backupId, equals('backup_b_id'));
    });

    test('10. Ineligible backups with older schema (< 18) are filtered out', () async {
      final oldSchemaBackup = RemoteBackupMetadata(
        remoteFileId: 'drive_file_v17',
        fileName: 'v17.qnb',
        fileSizeBytes: 5000,
        backupId: 'backup_v17',
        providerUserIdHash: testHash,
        createdAt: DateTime.parse('2026-08-18T15:00:00Z'),
        formatVersion: 1,
        databaseSchemaVersion: 17,
        appVersion: '1.0.0',
        noteCount: 10,
        folderCount: 1,
        taskCount: 1,
        attachmentCount: 0,
        sha256Checksum: 'chk',
      );

      fakeLocalDetector.summaryToReturn = const LocalDataSummary.empty();
      fakeStorage.backupsToReturn = [oldSchemaBackup];

      final result = await detector.checkEligibility(
        overrideUserId: testUserId,
        overrideProviderUserIdHash: testHash,
        overrideSessionType: SessionType.google,
      );

      expect(result.state, equals(FirstRunRecoveryState.noRecoveryRequired));
      expect(result.eligibleBackups, isEmpty);
    });

    test('11. Ineligible backups with newer schema (> 18) are filtered out', () async {
      final futureSchemaBackup = RemoteBackupMetadata(
        remoteFileId: 'drive_file_v19',
        fileName: 'v19.qnb',
        fileSizeBytes: 5000,
        backupId: 'backup_v19',
        providerUserIdHash: testHash,
        createdAt: DateTime.parse('2026-08-18T15:00:00Z'),
        formatVersion: 1,
        databaseSchemaVersion: 19,
        appVersion: '1.0.0',
        noteCount: 10,
        folderCount: 1,
        taskCount: 1,
        attachmentCount: 0,
        sha256Checksum: 'chk',
      );

      fakeLocalDetector.summaryToReturn = const LocalDataSummary.empty();
      fakeStorage.backupsToReturn = [futureSchemaBackup];

      final result = await detector.checkEligibility(
        overrideUserId: testUserId,
        overrideProviderUserIdHash: testHash,
        overrideSessionType: SessionType.google,
      );

      expect(result.state, equals(FirstRunRecoveryState.noRecoveryRequired));
      expect(result.eligibleBackups, isEmpty);
    });

    test('12. Ineligible backups with unsupported formatVersion (> 1) are filtered out', () async {
      final futureFormatBackup = RemoteBackupMetadata(
        remoteFileId: 'drive_file_f2',
        fileName: 'f2.qnb',
        fileSizeBytes: 5000,
        backupId: 'backup_f2',
        providerUserIdHash: testHash,
        createdAt: DateTime.parse('2026-08-18T15:00:00Z'),
        formatVersion: 2,
        databaseSchemaVersion: 18,
        appVersion: '1.0.0',
        noteCount: 10,
        folderCount: 1,
        taskCount: 1,
        attachmentCount: 0,
        sha256Checksum: 'chk',
      );

      fakeLocalDetector.summaryToReturn = const LocalDataSummary.empty();
      fakeStorage.backupsToReturn = [futureFormatBackup];

      final result = await detector.checkEligibility(
        overrideUserId: testUserId,
        overrideProviderUserIdHash: testHash,
        overrideSessionType: SessionType.google,
      );

      expect(result.state, equals(FirstRunRecoveryState.noRecoveryRequired));
    });

    test('13. Empty backups (0 notes, 0 folders, 0 tasks) are filtered out', () async {
      final emptyBackup = RemoteBackupMetadata(
        remoteFileId: 'drive_file_empty',
        fileName: 'empty.qnb',
        fileSizeBytes: 1000,
        backupId: 'backup_empty',
        providerUserIdHash: testHash,
        createdAt: DateTime.parse('2026-08-18T15:00:00Z'),
        formatVersion: 1,
        databaseSchemaVersion: 18,
        appVersion: '1.0.0',
        noteCount: 0,
        folderCount: 0,
        taskCount: 0,
        attachmentCount: 0,
        sha256Checksum: 'chk',
      );

      fakeLocalDetector.summaryToReturn = const LocalDataSummary.empty();
      fakeStorage.backupsToReturn = [emptyBackup];

      final result = await detector.checkEligibility(
        overrideUserId: testUserId,
        overrideProviderUserIdHash: testHash,
        overrideSessionType: SessionType.google,
      );

      expect(result.state, equals(FirstRunRecoveryState.noRecoveryRequired));
    });

    test('14. Cloud Drive network exception returns sanitized detectionFailed result', () async {
      fakeStorage.exceptionToThrow = const DriveStorageException(
        message: 'Network socket failure on googleapis.com/drive/v3/files:443',
        type: DriveStorageErrorType.networkUnavailable,
      );

      final result = await detector.checkEligibility(
        overrideUserId: testUserId,
        overrideProviderUserIdHash: testHash,
        overrideSessionType: SessionType.google,
      );

      expect(result.state, equals(FirstRunRecoveryState.detectionFailed));
      expect(result.hasFailed, isTrue);
      expect(result.failureReason, equals('Cloud backup detection is temporarily unavailable.'));
      // Invariant: raw internal socket URL or credentials never exposed
      expect(result.failureReason!.contains('googleapis.com'), isFalse);
    });

    test('15. Cloud Drive auth failure returns sanitized detectionFailed result', () async {
      fakeStorage.exceptionToThrow = const DriveStorageException(
        message: 'OAuth2 token expired: Bearer ya29.secret_token_value',
        type: DriveStorageErrorType.unauthenticated,
      );

      final result = await detector.checkEligibility(
        overrideUserId: testUserId,
        overrideProviderUserIdHash: testHash,
        overrideSessionType: SessionType.google,
      );

      expect(result.state, equals(FirstRunRecoveryState.detectionFailed));
      expect(result.failureReason, equals('Cloud backup detection is temporarily unavailable.'));
      expect(result.failureReason!.contains('ya29'), isFalse);
    });

    test('16. TimeoutException returns sanitized timeout failure reason', () async {
      fakeStorage.exceptionToThrow = TimeoutException('Operation timed out');

      final result = await detector.checkEligibility(
        overrideUserId: testUserId,
        overrideProviderUserIdHash: testHash,
        overrideSessionType: SessionType.google,
      );

      expect(result.state, equals(FirstRunRecoveryState.detectionFailed));
      expect(result.failureReason, equals('Connection timed out while checking for cloud backups.'));
    });

    test('17. Backup archive is NEVER downloaded during detection', () async {
      fakeStorage.backupsToReturn = [validBackupA];

      await detector.checkEligibility(
        overrideUserId: testUserId,
        overrideProviderUserIdHash: testHash,
        overrideSessionType: SessionType.google,
      );

      expect(fakeStorage.downloadBackupCallCount, equals(0));
    });

    test('18. Null or empty active user ID returns noRecoveryRequired safely', () async {
      final resultNull = await detector.checkEligibility(
        overrideUserId: null,
        overrideSessionType: SessionType.google,
      );
      final resultEmpty = await detector.checkEligibility(
        overrideUserId: '',
        overrideSessionType: SessionType.google,
      );

      expect(resultNull.state, equals(FirstRunRecoveryState.noRecoveryRequired));
      expect(resultEmpty.state, equals(FirstRunRecoveryState.noRecoveryRequired));
    });

    test('19. Session identity change during asynchronous detection rejects stale cloud result', () async {
      final sessionManager = SessionManager();
      await sessionManager.init();
      await sessionManager.saveSession(
        userId: testUserId,
        sessionType: SessionType.google,
      );

      final customDetector = FirstRunRecoveryDetector(
        storageAdapter: fakeStorage,
        localDataDetector: fakeLocalDetector,
        completionStore: completionStore,
        sessionManager: sessionManager,
      );

      fakeStorage.backupsToReturn = [validBackupA];
      fakeStorage.onListBackups = () async {
        // User switched accounts mid-flight!
        await sessionManager.saveSession(
          userId: 'usr_different_switched_user_456',
          sessionType: SessionType.google,
        );
      };

      final result = await customDetector.checkEligibility(
        overrideProviderUserIdHash: testHash,
      );

      expect(result.state, equals(FirstRunRecoveryState.detectionFailed));
      expect(result.failureReason, equals('User identity changed during recovery detection.'));
    });

    test('20. Provider hash resolution reads providerUserId from SQLite user_identities table', () async {
      final db = await DatabaseService.instance.database;
      final uniqueUserId = 'usr_auto_hash_${const Uuid().v4()}';
      final uniqueProviderUid = 'google_uid_test_${const Uuid().v4()}';
      final expectedHash = BackupIntegrity.sha256String(uniqueProviderUid);

      final nowIso = DateTime.now().toIso8601String();
      await db.insert('users', {
        'id': uniqueUserId,
        'isOffline': 0,
        'createdAt': nowIso,
        'updatedAt': nowIso,
      });
      await db.insert('user_identities', {
        'id': 'ident_${const Uuid().v4()}',
        'userId': uniqueUserId,
        'provider': 'google',
        'providerUserId': uniqueProviderUid,
        'email': 'user@example.com',
        'createdAt': nowIso,
        'lastAuthenticatedAt': nowIso,
      });

      fakeStorage.backupsToReturn = [
        RemoteBackupMetadata(
          remoteFileId: 'file_id_resolved',
          fileName: 'quicknotes.qnb',
          fileSizeBytes: 1000,
          backupId: 'backup_resolved',
          providerUserIdHash: expectedHash,
          createdAt: DateTime.parse('2026-08-18T12:00:00Z'),
          formatVersion: 1,
          databaseSchemaVersion: 18,
          appVersion: '1.0.0',
          noteCount: 1,
          folderCount: 0,
          taskCount: 0,
          attachmentCount: 0,
          sha256Checksum: 'chk',
        ),
      ];

      final result = await detector.checkEligibility(
        overrideUserId: uniqueUserId,
        overrideSessionType: SessionType.google,
      );

      expect(result.state, equals(FirstRunRecoveryState.eligibleEmptyLocal));
      expect(result.recommendedBackup?.backupId, equals('backup_resolved'));
    });
  });
}
