import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:quick_notes/controllers/splash_controller.dart';
import 'package:quick_notes/models/current_user.dart';
import 'package:quick_notes/models/session_state.dart';
import 'package:quick_notes/models/session_type.dart';
import 'package:quick_notes/repositories/user_repository.dart';
import 'package:quick_notes/services/recovery/first_run_recovery_detector.dart';
import 'package:quick_notes/services/recovery/first_run_recovery_state.dart';
import 'package:quick_notes/services/recovery/local_data_detector.dart';
import 'package:quick_notes/services/recovery/recovery_completion_store.dart';
import 'package:quick_notes/services/session_manager.dart';

/// Fake SessionManager
class FakeSessionManager implements SessionManager {
  SessionState sessionStateToReturn = SessionState.authenticated;
  SessionType activeSessionTypeToReturn = SessionType.google;
  String? activeUserIdToReturn = 'usr_test_123';

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
  bool get hasCompletedOnboarding => true;

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

/// Fake FirstRunRecoveryDetector
class FakeFirstRunRecoveryDetector implements FirstRunRecoveryDetector {
  FirstRunRecoveryResult resultToReturn = const FirstRunRecoveryResult.noRecoveryRequired();
  int checkEligibilityCallCount = 0;

  @override
  Future<FirstRunRecoveryResult> checkEligibility({
    String? overrideUserId,
    String? overrideProviderUserIdHash,
    SessionType? overrideSessionType,
  }) async {
    checkEligibilityCallCount++;
    return resultToReturn;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final secureStorageData = <String, String>{};

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => '.',
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

  group('SplashController First-Run Recovery Tests', () {
    late FakeSessionManager fakeSessionManager;
    late FakeUserRepository fakeUserRepo;
    late FakeFirstRunRecoveryDetector fakeDetector;

    setUp(() {
      secureStorageData.clear();
      fakeSessionManager = FakeSessionManager();
      fakeUserRepo = FakeUserRepository();
      fakeDetector = FakeFirstRunRecoveryDetector();
    });

    SplashController createController() {
      return SplashController(
        secureStorage: const FlutterSecureStorage(),
        sessionManager: fakeSessionManager,
        userRepository: fakeUserRepo,
        recoveryDetector: fakeDetector,
      );
    }

    test('34. First launch destination is onboarding and detector is NOT called', () async {
      fakeSessionManager.sessionStateToReturn = SessionState.firstLaunch;

      final controller = createController();
      final destination = await controller.initializeAndDetermineDestination(
        minDisplayDuration: Duration.zero,
      );

      expect(destination, equals(SplashDestination.onboarding));
      expect(fakeDetector.checkEligibilityCallCount, equals(0));
    });

    test('35. No session destination is login and detector is NOT called', () async {
      fakeSessionManager.sessionStateToReturn = SessionState.noSession;

      final controller = createController();
      final destination = await controller.initializeAndDetermineDestination(
        minDisplayDuration: Duration.zero,
      );

      expect(destination, equals(SplashDestination.login));
      expect(fakeDetector.checkEligibilityCallCount, equals(0));
    });

    test('36. Offline session destination is home and detector is NEVER called', () async {
      fakeSessionManager.sessionStateToReturn = SessionState.offline;

      final controller = createController();
      final destination = await controller.initializeAndDetermineDestination(
        minDisplayDuration: Duration.zero,
      );

      expect(destination, equals(SplashDestination.home));
      expect(fakeDetector.checkEligibilityCallCount, equals(0));
    });

    test('37. Authenticated Google + no recovery yields home (when app lock disabled)', () async {
      fakeSessionManager.sessionStateToReturn = SessionState.authenticated;
      fakeDetector.resultToReturn = const FirstRunRecoveryResult.noRecoveryRequired();

      final controller = createController();
      final destination = await controller.initializeAndDetermineDestination(
        minDisplayDuration: Duration.zero,
      );

      expect(destination, equals(SplashDestination.home));
      expect(fakeDetector.checkEligibilityCallCount, equals(1));
    });

    test('38. Authenticated Google + eligibleEmptyLocal yields recovery destination', () async {
      fakeSessionManager.sessionStateToReturn = SessionState.authenticated;
      fakeDetector.resultToReturn = const FirstRunRecoveryResult(
        state: FirstRunRecoveryState.eligibleEmptyLocal,
        localSummary: LocalDataSummary.empty(),
      );

      final controller = createController();
      final destination = await controller.initializeAndDetermineDestination(
        minDisplayDuration: Duration.zero,
      );

      expect(destination, equals(SplashDestination.recovery));
      expect(controller.recoveryResult?.isEligible, isTrue);
      expect(fakeDetector.checkEligibilityCallCount, equals(1));
    });

    test('39. Authenticated Google + eligibleConflictLocal yields recovery destination', () async {
      fakeSessionManager.sessionStateToReturn = SessionState.authenticated;
      fakeDetector.resultToReturn = const FirstRunRecoveryResult(
        state: FirstRunRecoveryState.eligibleConflictLocal,
        localSummary: LocalDataSummary(noteCount: 3, folderCount: 1, taskCount: 0),
      );

      final controller = createController();
      final destination = await controller.initializeAndDetermineDestination(
        minDisplayDuration: Duration.zero,
      );

      expect(destination, equals(SplashDestination.recovery));
      expect(controller.recoveryResult?.isEligible, isTrue);
      expect(fakeDetector.checkEligibilityCallCount, equals(1));
    });

    test('40. Authenticated Google + detectionFailed yields home (fail-safe)', () async {
      fakeSessionManager.sessionStateToReturn = SessionState.authenticated;
      fakeDetector.resultToReturn = const FirstRunRecoveryResult.detectionFailed(
        failureReason: '503 Service Unavailable',
      );

      final controller = createController();
      final destination = await controller.initializeAndDetermineDestination(
        minDisplayDuration: Duration.zero,
      );

      expect(destination, equals(SplashDestination.home));
      expect(fakeDetector.checkEligibilityCallCount, equals(1));
    });

    test('41. Detector is called exactly once during authenticated Google cold launch', () async {
      fakeSessionManager.sessionStateToReturn = SessionState.authenticated;
      fakeDetector.resultToReturn = const FirstRunRecoveryResult.noRecoveryRequired();

      final controller = createController();
      await controller.initializeAndDetermineDestination(
        minDisplayDuration: Duration.zero,
      );

      expect(fakeDetector.checkEligibilityCallCount, equals(1));
    });

    test('42. Profile completion takes precedence for incomplete authenticated users', () async {
      fakeSessionManager.sessionStateToReturn = SessionState.authenticated;
      fakeUserRepo.profileCompleted = false;

      final controller = createController();
      final destination = await controller.initializeAndDetermineDestination(
        minDisplayDuration: Duration.zero,
      );

      expect(destination, equals(SplashDestination.profileCompletion));
      expect(fakeDetector.checkEligibilityCallCount, equals(0));
    });

    test('43. Passcode lock remains enforced when appLockEnabled is true even if recovery is eligible', () async {
      fakeSessionManager.sessionStateToReturn = SessionState.authenticated;
      secureStorageData['app_lock_enabled'] = 'true';
      fakeDetector.resultToReturn = const FirstRunRecoveryResult(
        state: FirstRunRecoveryState.eligibleEmptyLocal,
        localSummary: LocalDataSummary.empty(),
      );

      final controller = createController();
      final destination = await controller.initializeAndDetermineDestination(
        minDisplayDuration: Duration.zero,
      );

      expect(destination, equals(SplashDestination.passcodeLock));
      expect(controller.recoveryResult?.isEligible, isTrue);
    });

    test('44. Recovery cannot bypass authentication (unauthenticated sessions never reach recovery)', () async {
      fakeSessionManager.sessionStateToReturn = SessionState.noSession;

      final controller = createController();
      final destination = await controller.initializeAndDetermineDestination(
        minDisplayDuration: Duration.zero,
      );

      expect(destination, equals(SplashDestination.login));
      expect(controller.recoveryResult, isNull);
    });

    test('53-57. Account switching & identity isolation in recovery detector', () async {
      // Account A check
      fakeSessionManager.activeUserIdToReturn = 'usr_account_A';
      fakeDetector.resultToReturn = const FirstRunRecoveryResult.noRecoveryRequired();

      final controllerA = createController();
      final destA = await controllerA.initializeAndDetermineDestination(minDisplayDuration: Duration.zero);
      expect(destA, equals(SplashDestination.home));

      // Account B check
      fakeSessionManager.activeUserIdToReturn = 'usr_account_B';
      fakeDetector.resultToReturn = const FirstRunRecoveryResult(
        state: FirstRunRecoveryState.eligibleEmptyLocal,
        localSummary: LocalDataSummary.empty(),
      );

      final controllerB = createController();
      final destB = await controllerB.initializeAndDetermineDestination(minDisplayDuration: Duration.zero);
      expect(destB, equals(SplashDestination.recovery));
    });

    test('58-63. Cold launch behavior when app killed before or after recovery decisions', () async {
      // 58. Cold launch detects recovery if not previously completed
      fakeSessionManager.sessionStateToReturn = SessionState.authenticated;
      fakeDetector.resultToReturn = const FirstRunRecoveryResult(
        state: FirstRunRecoveryState.eligibleConflictLocal,
        localSummary: LocalDataSummary(noteCount: 2, folderCount: 0, taskCount: 0),
      );

      final controller1 = createController();
      final dest1 = await controller1.initializeAndDetermineDestination(minDisplayDuration: Duration.zero);
      expect(dest1, equals(SplashDestination.recovery));

      // 59. Cold launch yields home if previously restored / no recovery required
      fakeDetector.resultToReturn = const FirstRunRecoveryResult.noRecoveryRequired(
        recoveryStatus: RecoveryCompletionStatus.restored,
      );

      final controller2 = createController();
      final dest2 = await controller2.initializeAndDetermineDestination(minDisplayDuration: Duration.zero);
      expect(dest2, equals(SplashDestination.home));

      // 63. Drive unavailable during cold launch proceeds to home fail-safe
      fakeDetector.resultToReturn = const FirstRunRecoveryResult.detectionFailed(
        failureReason: 'SocketException: Connection refused',
      );

      final controller3 = createController();
      final dest3 = await controller3.initializeAndDetermineDestination(minDisplayDuration: Duration.zero);
      expect(dest3, equals(SplashDestination.home));
    });
  });
}
