import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:quick_notes/controllers/first_run_recovery_controller.dart';
import 'package:quick_notes/controllers/login_controller.dart';
import 'package:quick_notes/models/identity_link_result.dart';
import 'package:quick_notes/models/current_user.dart';
import 'package:quick_notes/models/session_type.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/providers/tasks_provider.dart';
import 'package:quick_notes/repositories/user_identity_repository.dart';
import 'package:quick_notes/repositories/user_repository.dart';
import 'package:quick_notes/services/authentication_service.dart';
import 'package:quick_notes/services/backup/backup_manifest.dart';
import 'package:quick_notes/services/backup/backup_storage_adapter.dart';
import 'package:quick_notes/services/backup/backup_validation_result.dart';
import 'package:quick_notes/services/backup/remote_backup_metadata.dart';
import 'package:quick_notes/services/backup/restore_engine.dart';
import 'package:quick_notes/services/backup/restore_result.dart';
import 'package:quick_notes/services/recovery/first_run_recovery_detector.dart';
import 'package:quick_notes/services/recovery/first_run_recovery_state.dart';
import 'package:quick_notes/services/recovery/local_data_detector.dart';
import 'package:quick_notes/services/recovery/recovery_completion_store.dart';
import 'package:quick_notes/services/session_manager.dart';
import 'package:quick_notes/services/user_identity_service.dart';
import 'package:quick_notes/views/screens/first_run_recovery_screen.dart';
import 'package:quick_notes/views/screens/home_screen.dart';
import 'package:quick_notes/views/screens/login_screen.dart';

/// Fake Auth Service for Widget Tests
class MockAuthService implements AuthenticationService {
  AuthResult authResultToReturn = AuthResult.success(
    user: CurrentUser(
      id: 'google_uid_test',
      email: 'test@example.com',
      displayName: 'Test User',
      sessionType: SessionType.google,
      isOffline: false,
      createdAt: DateTime.utc(2026, 1, 1),
    ),
    accessToken: 'ya29.mock',
    idToken: 'mock.id.token',
  );

  @override
  GoogleSignIn get googleSignIn => GoogleSignIn();

  @override
  Future<AuthResult> signInWithGoogle() async => authResultToReturn;
}

/// Fake Recovery Detector for Widget Tests
class MockRecoveryDetector implements FirstRunRecoveryDetector {
  FirstRunRecoveryResult resultToReturn;
  int checkEligibilityCalls = 0;

  MockRecoveryDetector({
    required this.resultToReturn,
    BackupStorageAdapter? storageAdapter,
  });

  @override
  Future<FirstRunRecoveryResult> checkEligibility({
    String? overrideUserId,
    String? overrideProviderUserIdHash,
    SessionType? overrideSessionType,
  }) async {
    checkEligibilityCalls++;
    return resultToReturn;
  }
}

/// Fake UserIdentityService
class FakeUserIdentityService implements UserIdentityService {
  @override
  void setRepositoryForTesting(UserIdentityRepository repository) {}

  @override
  Future<String> getOrCreateCanonicalUser({
    required String provider,
    required String providerUserId,
    String? email,
    String? displayName,
    String? photoUrl,
  }) async {
    return 'usr_canonical_$providerUserId';
  }

  @override
  Future<IdentityLinkResult> linkGoogleIdentityToActiveUser({
    required String activeUserId,
    required String googleId,
    String? email,
    String? displayName,
    String? photoUrl,
  }) async {
    throw UnimplementedError();
  }
}

/// Fake UserRepository
class FakeUserRepository implements UserRepository {
  bool profileCompleted = true;
  CurrentUser? savedUser;

  @override
  CurrentUser? get currentUser => savedUser;

  @override
  Future<void> saveUser(CurrentUser user) async {
    savedUser = user;
  }

  @override
  Future<CurrentUser?> getUserById(String id) async => savedUser;

  @override
  Future<CurrentUser?> restoreActiveSession() async => savedUser;

  @override
  Future<bool> hasCompletedProfile() async => profileCompleted;

  @override
  Future<void> clearActiveUser() async {
    savedUser = null;
  }
}

/// Fake Backup Storage Adapter
class MockStorageAdapter implements BackupStorageAdapter {
  int downloadCallCount = 0;

  @override
  Future<RemoteBackupMetadata> uploadBackup({
    required File localBackupFile,
    required BackupManifest manifest,
  }) async => throw UnimplementedError();

  @override
  Future<List<RemoteBackupMetadata>> listBackups() async => [];

  @override
  Future<File> downloadBackup({
    required String remoteFileId,
    required File destinationLocalFile,
  }) async {
    downloadCallCount++;
    destinationLocalFile.createSync(recursive: true);
    destinationLocalFile.writeAsStringSync('fake_backup_data');
    return destinationLocalFile;
  }

  @override
  Future<void> deleteBackup(String remoteFileId) async {}
}

/// Fake Restore Engine
class MockRestoreEngine implements RestoreEngine {
  bool shouldSucceed = true;
  String? failError;
  int restoreCalls = 0;

  @override
  Future<RestoreResult> restoreFromBackup({
    required String backupFilePath,
    Directory? customDocumentsDir,
    bool forceOfflineOverride = false,
  }) async {
    restoreCalls++;
    if (shouldSucceed) {
      return const RestoreResult(
        success: true,
        backupId: 'backup_123',
        noteCount: 10,
        folderCount: 2,
        taskCount: 3,
        attachmentCount: 0,
        identityStatus: BackupIdentityStatus.match,
        validationResult: BackupValidationResult(isValid: true),
        safetySnapshotPath: '/tmp/safety_snapshot.db',
        verificationPassed: true,
      );
    } else {
      return RestoreResult.failure(
        error: RestoreError(
          type: RestoreErrorType.invalidBackup,
          message: failError ?? 'Corrupted backup payload',
        ),
      );
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempTestDir;
  late MockStorageAdapter fakeStorage;
  late MockRestoreEngine fakeRestoreEngine;
  late RecoveryCompletionStore completionStore;

  final sampleBackup = RemoteBackupMetadata(
    remoteFileId: 'drive_sample_123',
    fileName: 'quicknotes_20260818.qnb',
    fileSizeBytes: 20480,
    backupId: 'backup_uuid_1',
    providerUserIdHash: 'hash_abc',
    createdAt: DateTime.utc(2026, 8, 18, 10, 30),
    formatVersion: 1,
    databaseSchemaVersion: 18,
    appVersion: '1.0.0',
    noteCount: 15,
    folderCount: 2,
    taskCount: 5,
    attachmentCount: 0,
    sha256Checksum: 'checksum_123',
  );

  final eligibleResult = FirstRunRecoveryResult(
    state: FirstRunRecoveryState.eligibleEmptyLocal,
    localSummary: const LocalDataSummary.empty(),
    recommendedBackup: sampleBackup,
    eligibleBackups: [sampleBackup],
  );

  final conflictResult = FirstRunRecoveryResult(
    state: FirstRunRecoveryState.eligibleConflictLocal,
    localSummary: const LocalDataSummary(noteCount: 3, folderCount: 1, taskCount: 2),
    recommendedBackup: sampleBackup,
    eligibleBackups: [sampleBackup],
  );

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    GoogleFonts.config.allowRuntimeFetching = false;
    tempTestDir = await Directory.systemTemp.createTemp('login_nav_tests_');
    SharedPreferences.setMockInitialValues({});

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

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => tempTestDir.path,
    );
    final secureStorageStore = <String, String>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
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
  });

  tearDownAll(() async {
    try {
      if (tempTestDir.existsSync()) {
        await tempTestDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionManager().init();
    fakeStorage = MockStorageAdapter();
    fakeRestoreEngine = MockRestoreEngine();
    completionStore = RecoveryCompletionStore();
  });

  Widget createLoginTestWidget({required LoginController controller}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NotesProvider()),
        ChangeNotifierProvider(create: (_) => TasksProvider()),
      ],
      child: MaterialApp(
        home: LoginScreen(controller: controller),
      ),
    );
  }

  Widget createRecoveryFlowWidget({
    required FirstRunRecoveryResult result,
    required FirstRunRecoveryController controller,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NotesProvider()),
        ChangeNotifierProvider(create: (_) => TasksProvider()),
      ],
      child: MaterialApp(
        home: FirstRunRecoveryFlow(
          recoveryResult: result,
          controller: controller,
        ),
      ),
    );
  }

  LoginController createLoginController({
    required MockRecoveryDetector detector,
    MockAuthService? auth,
  }) {
    return LoginController(
      authService: auth ?? MockAuthService(),
      userRepository: FakeUserRepository(),
      userIdentityService: FakeUserIdentityService(),
      recoveryDetector: detector,
    );
  }

  group('LoginScreen Recovery Navigation Widget Tests', () {
    testWidgets('11. LoginResult.navigateToRecovery transitions to FirstRunRecoveryScreen', (tester) async {
      final fakeDetector = MockRecoveryDetector(
        resultToReturn: eligibleResult,
        storageAdapter: fakeStorage,
      );
      final controller = createLoginController(detector: fakeDetector);

      await tester.pumpWidget(createLoginTestWidget(controller: controller));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Welcome to\nQuick Notes'), findsOneWidget);

      await tester.tap(find.text('Continue with Google'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('RECOVERY'), findsOneWidget);
      expect(find.text('Welcome back.'), findsOneWidget);
      expect(find.byType(FirstRunRecoveryScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('12. Recovery screen receives exact FirstRunRecoveryResult and displays backup info', (tester) async {
      final fakeDetector = MockRecoveryDetector(
        resultToReturn: eligibleResult,
        storageAdapter: fakeStorage,
      );
      final controller = createLoginController(detector: fakeDetector);

      await tester.pumpWidget(createLoginTestWidget(controller: controller));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Continue with Google'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('15 Notes'), findsOneWidget);
      expect(find.text('2 Folders'), findsOneWidget);
      expect(find.text('5 Tasks'), findsOneWidget);
      expect(find.text('Ready for Recovery'), findsOneWidget);
    });

    testWidgets('13. LoginResult.navigateToHome navigates directly to HomeScreen when no recovery needed', (tester) async {
      final fakeDetector = MockRecoveryDetector(
        resultToReturn: const FirstRunRecoveryResult.noRecoveryRequired(),
        storageAdapter: fakeStorage,
      );
      final controller = createLoginController(detector: fakeDetector);

      await tester.pumpWidget(createLoginTestWidget(controller: controller));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Continue with Google'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(FirstRunRecoveryScreen), findsNothing);

      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('14. Existing login failure shows error UI without navigating', (tester) async {
      final fakeAuth = MockAuthService();
      fakeAuth.authResultToReturn = AuthResult.failure('Network connection lost');

      final controller = createLoginController(
        detector: MockRecoveryDetector(
          resultToReturn: eligibleResult,
          storageAdapter: fakeStorage,
        ),
        auth: fakeAuth,
      );

      await tester.pumpWidget(createLoginTestWidget(controller: controller));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Continue with Google'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Network connection lost'), findsOneWidget);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(FirstRunRecoveryScreen), findsNothing);
    });

    testWidgets('15. Offline login navigates to HomeScreen without calling detector', (tester) async {
      final fakeDetector = MockRecoveryDetector(
        resultToReturn: eligibleResult,
        storageAdapter: fakeStorage,
      );
      final controller = createLoginController(detector: fakeDetector);

      await tester.pumpWidget(createLoginTestWidget(controller: controller));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final offlineBtn = find.text('Continue Offline');
      await tester.ensureVisible(offlineBtn);
      await tester.runAsync(() async {
        await tester.tap(offlineBtn);
        while (controller.state == LoginUiState.initializingOffline) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(fakeDetector.checkEligibilityCalls, equals(0));
    });

    testWidgets('16-19. Stack replacement & fail-safe: Drive error routes to HomeScreen without trapped loop', (tester) async {
      final fakeDetector = MockRecoveryDetector(
        resultToReturn: const FirstRunRecoveryResult.detectionFailed(
          failureReason: '503 Service Unavailable',
        ),
        storageAdapter: fakeStorage,
      );
      final controller = createLoginController(detector: fakeDetector);

      await tester.pumpWidget(createLoginTestWidget(controller: controller));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Continue with Google'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);

      await tester.pump(const Duration(seconds: 11));
    });
  });

  group('Recovery Flow to HomeScreen Navigation Tests', () {
    testWidgets('20-22. Restore button tap stays during restore and navigates to HomeScreen on success', (tester) async {
      final recoveryController = FirstRunRecoveryController(
        recoveryResult: eligibleResult,
        restoreEngine: fakeRestoreEngine,
        storageAdapter: fakeStorage,
        completionStore: completionStore,
        customTempDir: tempTestDir,
      );

      await tester.pumpWidget(createRecoveryFlowWidget(
        result: eligibleResult,
        controller: recoveryController,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 20. Initial ready state remains on Recovery
      expect(find.byType(FirstRunRecoveryScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);

      // 21. Tap Restore Backup -> transition to HomeScreen on completion
      final restoreBtn = find.text('Restore Backup');
      await tester.ensureVisible(restoreBtn);
      await tester.tap(restoreBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));

      // 22. Restore success -> replaces route with HomeScreen
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(FirstRunRecoveryScreen), findsNothing);
      expect(fakeRestoreEngine.restoreCalls, equals(1));

      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('23-24. Restore failure remains on RecoveryScreen and allows Retry', (tester) async {
      fakeRestoreEngine.shouldSucceed = false;
      fakeRestoreEngine.failError = 'Corrupted .qnb payload';

      final recoveryController = FirstRunRecoveryController(
        recoveryResult: eligibleResult,
        restoreEngine: fakeRestoreEngine,
        storageAdapter: fakeStorage,
        completionStore: completionStore,
        customTempDir: tempTestDir,
      );

      await tester.pumpWidget(createRecoveryFlowWidget(
        result: eligibleResult,
        controller: recoveryController,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap restore -> fails
      final restoreBtn = find.text('Restore Backup');
      await tester.ensureVisible(restoreBtn);
      await tester.tap(restoreBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));

      // 23. Stays on RecoveryScreen showing error
      expect(find.byType(FirstRunRecoveryScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.text('Try Again'), findsOneWidget);

      // 24. Retry
      fakeRestoreEngine.shouldSucceed = true;
      final tryAgainBtn = find.text('Try Again');
      await tester.ensureVisible(tryAgainBtn);
      await tester.tap(tryAgainBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(fakeRestoreEngine.restoreCalls, equals(2));

      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('25. Keep Local Data navigates to HomeScreen without modifying database', (tester) async {
      final recoveryController = FirstRunRecoveryController(
        recoveryResult: conflictResult,
        restoreEngine: fakeRestoreEngine,
        storageAdapter: fakeStorage,
        completionStore: completionStore,
        customTempDir: tempTestDir,
      );

      await tester.pumpWidget(createRecoveryFlowWidget(
        result: conflictResult,
        controller: recoveryController,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Keep Local Data'), findsOneWidget);
      final keepBtn = find.text('Keep Local Data');
      await tester.ensureVisible(keepBtn);
      await tester.tap(keepBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(fakeRestoreEngine.restoreCalls, equals(0));

      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('26. Start Fresh navigates to HomeScreen without deleting data', (tester) async {
      final recoveryController = FirstRunRecoveryController(
        recoveryResult: eligibleResult,
        restoreEngine: fakeRestoreEngine,
        storageAdapter: fakeStorage,
        completionStore: completionStore,
        customTempDir: tempTestDir,
      );

      await tester.pumpWidget(createRecoveryFlowWidget(
        result: eligibleResult,
        controller: recoveryController,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final startFreshBtn = find.text('Start Fresh');
      await tester.ensureVisible(startFreshBtn);
      await tester.tap(startFreshBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(fakeRestoreEngine.restoreCalls, equals(0));

      // Settle pending DatabaseService timedQuery timer
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('30-31. Completed state navigation occurs exactly once', (tester) async {
      final recoveryController = FirstRunRecoveryController(
        recoveryResult: eligibleResult,
        restoreEngine: fakeRestoreEngine,
        storageAdapter: fakeStorage,
        completionStore: completionStore,
        customTempDir: tempTestDir,
      );

      await tester.pumpWidget(createRecoveryFlowWidget(
        result: eligibleResult,
        controller: recoveryController,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final restoreBtn = find.text('Restore Backup');
      await tester.ensureVisible(restoreBtn);
      await tester.tap(restoreBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));

      // Trigger multiple controller notifications while completed
      recoveryController.notifyListeners();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(HomeScreen), findsOneWidget);

      // Settle pending DatabaseService timedQuery timer
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('64-68. Navigation stack safety: Recovery is completely removed from route stack', (tester) async {
      final recoveryController = FirstRunRecoveryController(
        recoveryResult: eligibleResult,
        restoreEngine: fakeRestoreEngine,
        storageAdapter: fakeStorage,
        completionStore: completionStore,
        customTempDir: tempTestDir,
      );

      await tester.pumpWidget(createRecoveryFlowWidget(
        result: eligibleResult,
        controller: recoveryController,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final restoreBtn = find.text('Restore Backup');
      await tester.ensureVisible(restoreBtn);
      await tester.tap(restoreBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(FirstRunRecoveryScreen), findsNothing);
      expect(find.byType(FirstRunRecoveryFlow), findsNothing);

      // Settle pending DatabaseService timedQuery timer
      await tester.pump(const Duration(seconds: 11));
    });
  });
}
