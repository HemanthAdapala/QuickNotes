import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:quick_notes/controllers/splash_controller.dart';
import 'package:quick_notes/models/current_user.dart';
import 'package:quick_notes/models/session_state.dart';
import 'package:quick_notes/models/session_type.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/providers/tasks_provider.dart';
import 'package:quick_notes/repositories/user_repository.dart';
import 'package:quick_notes/services/backup/remote_backup_metadata.dart';
import 'package:quick_notes/services/database_service.dart';
import 'package:quick_notes/services/recovery/first_run_recovery_detector.dart';
import 'package:quick_notes/services/recovery/first_run_recovery_state.dart';
import 'package:quick_notes/services/recovery/local_data_detector.dart';
import 'package:quick_notes/services/session_manager.dart';
import 'package:quick_notes/views/screens/first_run_recovery_screen.dart';
import 'package:quick_notes/views/screens/home_screen.dart';
import 'package:quick_notes/views/screens/login_screen.dart';
import 'package:quick_notes/views/screens/passcode_lock_screen.dart';
import 'package:quick_notes/views/screens/splash_screen.dart';
import 'package:quick_notes/views/screens/welcome_screen.dart';

/// Fake FlutterSecureStorage for non-hanging async reads
class FakeFlutterSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _storage;
  FakeFlutterSecureStorage([Map<String, String>? initialData])
      : _storage = initialData ?? <String, String>{};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _storage[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _storage[key] = value;
    } else {
      _storage.remove(key);
    }
  }

  @override
  Future<void> deleteAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _storage.clear();
  }
}

/// Fake DatabaseService for fast test execution
class FakeDatabaseService extends Fake implements DatabaseService {
  Database? _db;

  @override
  Future<Database> get database async {
    _db ??= await openDatabase(inMemoryDatabasePath);
    return _db!;
  }
}

/// Fake SessionManager for Splash Navigation Tests
class FakeSessionManager implements SessionManager {
  SessionState sessionStateToReturn = SessionState.authenticated;
  SessionType activeSessionTypeToReturn = SessionType.google;
  String? activeUserIdToReturn = 'usr_test_123';

  @override
  bool get isInitialized => true;

  @override
  SessionState get currentSessionState => sessionStateToReturn;

  @override
  SessionType get activeSessionType => activeSessionTypeToReturn;

  @override
  String? get activeUserId => activeUserIdToReturn;

  @override
  String get userId => activeUserIdToReturn ?? '';

  @override
  String get provider => activeSessionTypeToReturn.toValue();

  @override
  bool get hasCompletedOnboarding => sessionStateToReturn != SessionState.firstLaunch;

  @override
  bool get isLoggedIn => sessionStateToReturn != SessionState.noSession;

  @override
  Future<void> setOnboardingCompleted() async {}

  @override
  Future<void> init() async {}

  @override
  Future<void> saveSession({
    required String userId,
    required SessionType sessionType,
    String? accessToken,
    String? idToken,
  }) async {
    activeUserIdToReturn = userId;
    activeSessionTypeToReturn = sessionType;
    sessionStateToReturn = SessionState.authenticated;
  }

  @override
  Future<void> clearSession() async {
    sessionStateToReturn = SessionState.noSession;
    activeUserIdToReturn = null;
    activeSessionTypeToReturn = SessionType.offline;
  }

  @override
  Future<String?> getAccessToken() async => 'ya29.test';

  @override
  Future<String?> getIdToken() async => 'id.token';

  @override
  bool get isAuthenticated => sessionStateToReturn == SessionState.authenticated;

  @override
  bool get isOffline => sessionStateToReturn == SessionState.offline;
}

/// Fake UserRepository for Splash Tests
class FakeSplashUserRepository implements UserRepository {
  CurrentUser? userToReturn;
  bool profileCompleted = true;

  @override
  CurrentUser? get currentUser => userToReturn;

  @override
  Future<void> saveUser(CurrentUser user) async {
    userToReturn = user;
  }

  @override
  Future<CurrentUser?> getUserById(String id) async => userToReturn;

  @override
  Future<CurrentUser?> restoreActiveSession() async => userToReturn;

  @override
  Future<bool> hasCompletedProfile() async => profileCompleted;

  @override
  Future<void> clearActiveUser() async {
    userToReturn = null;
  }
}

/// Fake Recovery Detector for Splash Tests
class FakeSplashRecoveryDetector implements FirstRunRecoveryDetector {
  FirstRunRecoveryResult resultToReturn;
  int checkEligibilityCalls = 0;

  FakeSplashRecoveryDetector({
    required this.resultToReturn,
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempTestDir;
  final secureStorageData = <String, String>{};

  final sampleBackup = RemoteBackupMetadata(
    remoteFileId: 'splash_drive_backup_1',
    fileName: 'quicknotes_splash.qnb',
    fileSizeBytes: 10240,
    backupId: 'backup_splash_uuid',
    providerUserIdHash: 'splash_hash_123',
    createdAt: DateTime.utc(2026, 8, 18, 11, 0),
    formatVersion: 1,
    databaseSchemaVersion: 18,
    appVersion: '1.0.0',
    noteCount: 8,
    folderCount: 1,
    taskCount: 2,
    attachmentCount: 0,
    sha256Checksum: 'splash_chk',
  );

  final eligibleResult = FirstRunRecoveryResult(
    state: FirstRunRecoveryState.eligibleEmptyLocal,
    localSummary: const LocalDataSummary.empty(),
    recommendedBackup: sampleBackup,
    eligibleBackups: [sampleBackup],
  );

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final warmupDb = await openDatabase(inMemoryDatabasePath);
    await warmupDb.close();

    GoogleFonts.config.allowRuntimeFetching = false;
    tempTestDir = await Directory.systemTemp.createTemp('splash_nav_tests_');
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

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'read') {
          final key = methodCall.arguments['key'] as String;
          return secureStorageData[key];
        } else if (methodCall.method == 'write') {
          final key = methodCall.arguments['key'] as String;
          final value = methodCall.arguments['value'] as String?;
          if (value != null) {
            secureStorageData[key] = value;
          } else {
            secureStorageData.remove(key);
          }
          return null;
        } else if (methodCall.method == 'deleteAll') {
          secureStorageData.clear();
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
    secureStorageData.clear();
    SharedPreferences.setMockInitialValues({
      'has_completed_onboarding': true,
      'app_lock_enabled': false,
    });
    await SessionManager().init();
  });

  Widget createSplashTestWidget({required SplashController controller}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NotesProvider()),
        ChangeNotifierProvider(create: (_) => TasksProvider()),
      ],
      child: MaterialApp(
        home: SplashScreen(splashController: controller),
      ),
    );
  }

  group('SplashScreen Recovery Navigation Integration Tests', () {
    testWidgets('00. Pre-warm test environment', (tester) async {
      final fakeDetector = FakeSplashRecoveryDetector(
        resultToReturn: const FirstRunRecoveryResult.noRecoveryRequired(),
      );
      final fakeSessionManager = FakeSessionManager();
      fakeSessionManager.sessionStateToReturn = SessionState.firstLaunch;
      final controller = SplashController(
        secureStorage: FakeFlutterSecureStorage(secureStorageData),
        sessionManager: fakeSessionManager,
        databaseService: FakeDatabaseService(),
        recoveryDetector: fakeDetector,
      );
      await tester.pumpWidget(createSplashTestWidget(controller: controller));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('45. Cold launch with recovery eligible navigates to FirstRunRecoveryScreen', (tester) async {
      final fakeDetector = FakeSplashRecoveryDetector(resultToReturn: eligibleResult);
      final fakeSessionManager = FakeSessionManager();
      fakeSessionManager.sessionStateToReturn = SessionState.authenticated;
      fakeSessionManager.activeSessionTypeToReturn = SessionType.google;
      final fakeRepo = FakeSplashUserRepository();
      fakeRepo.userToReturn = CurrentUser(
        id: 'usr_cold_google_1',
        email: 'cold@example.com',
        displayName: 'Cold User',
        sessionType: SessionType.google,
        isOffline: false,
        createdAt: DateTime.utc(2026, 1, 1),
      );

      final controller = SplashController(
        secureStorage: FakeFlutterSecureStorage(secureStorageData),
        sessionManager: fakeSessionManager,
        userRepository: fakeRepo,
        databaseService: FakeDatabaseService(),
        recoveryDetector: fakeDetector,
      );

      await tester.pumpWidget(createSplashTestWidget(controller: controller));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(FirstRunRecoveryScreen), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
      expect(fakeDetector.checkEligibilityCalls, equals(1));
    });

    testWidgets('46. Cold launch without recovery eligibility navigates to HomeScreen', (tester) async {
      final fakeDetector = FakeSplashRecoveryDetector(
        resultToReturn: const FirstRunRecoveryResult.noRecoveryRequired(),
      );
      final fakeSessionManager = FakeSessionManager();
      fakeSessionManager.sessionStateToReturn = SessionState.authenticated;
      fakeSessionManager.activeSessionTypeToReturn = SessionType.google;
      final fakeRepo = FakeSplashUserRepository();
      fakeRepo.userToReturn = CurrentUser(
        id: 'usr_cold_google_2',
        email: 'cold2@example.com',
        displayName: 'Cold User 2',
        sessionType: SessionType.google,
        isOffline: false,
        createdAt: DateTime.utc(2026, 1, 1),
      );

      final controller = SplashController(
        secureStorage: FakeFlutterSecureStorage(secureStorageData),
        sessionManager: fakeSessionManager,
        userRepository: fakeRepo,
        databaseService: FakeDatabaseService(),
        recoveryDetector: fakeDetector,
      );

      await tester.pumpWidget(createSplashTestWidget(controller: controller));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(FirstRunRecoveryScreen), findsNothing);

      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('47. Offline session cold launch bypasses detector and navigates to HomeScreen', (tester) async {
      final fakeDetector = FakeSplashRecoveryDetector(resultToReturn: eligibleResult);
      final fakeSessionManager = FakeSessionManager();
      fakeSessionManager.sessionStateToReturn = SessionState.offline;
      fakeSessionManager.activeSessionTypeToReturn = SessionType.offline;
      final fakeRepo = FakeSplashUserRepository();
      fakeRepo.userToReturn = CurrentUser(
        id: 'usr_cold_offline',
        email: 'offline@device.local',
        displayName: 'Offline User',
        sessionType: SessionType.offline,
        isOffline: true,
        createdAt: DateTime.utc(2026, 1, 1),
      );

      final controller = SplashController(
        secureStorage: FakeFlutterSecureStorage(secureStorageData),
        sessionManager: fakeSessionManager,
        userRepository: fakeRepo,
        databaseService: FakeDatabaseService(),
        recoveryDetector: fakeDetector,
      );

      await tester.pumpWidget(createSplashTestWidget(controller: controller));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(FirstRunRecoveryScreen), findsNothing);
      expect(fakeDetector.checkEligibilityCalls, equals(0));

      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('48. First launch without onboarding navigates to WelcomeScreen', (tester) async {
      final fakeDetector = FakeSplashRecoveryDetector(resultToReturn: eligibleResult);
      final fakeSessionManager = FakeSessionManager();
      fakeSessionManager.sessionStateToReturn = SessionState.firstLaunch;
      final controller = SplashController(
        secureStorage: FakeFlutterSecureStorage(secureStorageData),
        sessionManager: fakeSessionManager,
        databaseService: FakeDatabaseService(),
        recoveryDetector: fakeDetector,
      );

      await tester.pumpWidget(createSplashTestWidget(controller: controller));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(fakeDetector.checkEligibilityCalls, equals(0));
    });

    testWidgets('49. Logged out session navigates to LoginScreen', (tester) async {
      final fakeDetector = FakeSplashRecoveryDetector(resultToReturn: eligibleResult);
      final fakeSessionManager = FakeSessionManager();
      fakeSessionManager.sessionStateToReturn = SessionState.noSession;
      final fakeRepo = FakeSplashUserRepository();
      fakeRepo.userToReturn = null;

      final controller = SplashController(
        secureStorage: FakeFlutterSecureStorage(secureStorageData),
        sessionManager: fakeSessionManager,
        userRepository: fakeRepo,
        databaseService: FakeDatabaseService(),
        recoveryDetector: fakeDetector,
      );

      await tester.pumpWidget(createSplashTestWidget(controller: controller));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(FirstRunRecoveryScreen), findsNothing);
      expect(fakeDetector.checkEligibilityCalls, equals(0));
    });

    testWidgets('50. Passcode lock routes to PasscodeLockScreen', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      secureStorageData['app_lock_enabled'] = 'true';

      final fakeDetector = FakeSplashRecoveryDetector(resultToReturn: eligibleResult);
      final fakeSessionManager = FakeSessionManager();
      fakeSessionManager.sessionStateToReturn = SessionState.authenticated;
      fakeSessionManager.activeSessionTypeToReturn = SessionType.google;
      final fakeRepo = FakeSplashUserRepository();
      fakeRepo.userToReturn = CurrentUser(
        id: 'usr_cold_google_locked',
        email: 'locked@example.com',
        displayName: 'Locked User',
        sessionType: SessionType.google,
        isOffline: false,
        createdAt: DateTime.utc(2026, 1, 1),
      );

      final controller = SplashController(
        secureStorage: FakeFlutterSecureStorage(secureStorageData),
        sessionManager: fakeSessionManager,
        userRepository: fakeRepo,
        databaseService: FakeDatabaseService(),
        recoveryDetector: fakeDetector,
      );

      await tester.pumpWidget(createSplashTestWidget(controller: controller));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(PasscodeLockScreen), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
    });

    testWidgets('51-52. Detection failure routes safely to HomeScreen (fail-safe)', (tester) async {
      final fakeDetector = FakeSplashRecoveryDetector(
        resultToReturn: const FirstRunRecoveryResult.detectionFailed(
          failureReason: 'SocketException: Network down',
        ),
      );
      final fakeSessionManager = FakeSessionManager();
      fakeSessionManager.sessionStateToReturn = SessionState.authenticated;
      fakeSessionManager.activeSessionTypeToReturn = SessionType.google;
      final fakeRepo = FakeSplashUserRepository();
      fakeRepo.userToReturn = CurrentUser(
        id: 'usr_cold_google_failsafe',
        email: 'failsafe@example.com',
        displayName: 'Failsafe User',
        sessionType: SessionType.google,
        isOffline: false,
        createdAt: DateTime.utc(2026, 1, 1),
      );

      final controller = SplashController(
        secureStorage: FakeFlutterSecureStorage(secureStorageData),
        sessionManager: fakeSessionManager,
        userRepository: fakeRepo,
        databaseService: FakeDatabaseService(),
        recoveryDetector: fakeDetector,
      );

      await tester.pumpWidget(createSplashTestWidget(controller: controller));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(FirstRunRecoveryScreen), findsNothing);

      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('69-70. Cold launch navigation stack safety: SplashScreen replaced', (tester) async {
      final fakeDetector = FakeSplashRecoveryDetector(resultToReturn: eligibleResult);
      final fakeSessionManager = FakeSessionManager();
      fakeSessionManager.sessionStateToReturn = SessionState.authenticated;
      fakeSessionManager.activeSessionTypeToReturn = SessionType.google;
      final fakeRepo = FakeSplashUserRepository();
      fakeRepo.userToReturn = CurrentUser(
        id: 'usr_cold_google_stack',
        email: 'stack@example.com',
        displayName: 'Stack User',
        sessionType: SessionType.google,
        isOffline: false,
        createdAt: DateTime.utc(2026, 1, 1),
      );

      final controller = SplashController(
        secureStorage: FakeFlutterSecureStorage(secureStorageData),
        sessionManager: fakeSessionManager,
        userRepository: fakeRepo,
        databaseService: FakeDatabaseService(),
        recoveryDetector: fakeDetector,
      );

      await tester.pumpWidget(createSplashTestWidget(controller: controller));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(FirstRunRecoveryScreen), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
    });
  });
}
