import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quick_notes/controllers/login_controller.dart';
import 'package:quick_notes/models/identity_link_result.dart';
import 'package:quick_notes/repositories/user_identity_repository.dart';
import 'package:quick_notes/models/current_user.dart';
import 'package:quick_notes/models/session_type.dart';
import 'package:quick_notes/repositories/user_repository.dart';
import 'package:quick_notes/services/authentication_service.dart';
import 'package:quick_notes/services/local_profile_service.dart';
import 'package:quick_notes/services/recovery/first_run_recovery_detector.dart';
import 'package:quick_notes/services/recovery/first_run_recovery_state.dart';
import 'package:quick_notes/services/recovery/local_data_detector.dart';
import 'package:quick_notes/services/session_manager.dart';
import 'package:quick_notes/services/user_identity_service.dart';

/// Fake AuthenticationService
class FakeAuthService implements AuthenticationService {
  AuthResult resultToReturn = AuthResult.success(
    user: CurrentUser(
      id: 'google_uid_123',
      email: 'user@example.com',
      displayName: 'Test User',
      sessionType: SessionType.google,
      isOffline: false,
      createdAt: DateTime.utc(2026, 1, 1),
    ),
    accessToken: 'ya29.fake',
    idToken: 'fake.id.token',
  );

  @override
  GoogleSignIn get googleSignIn => GoogleSignIn();

  @override
  Future<AuthResult> signInWithGoogle() async => resultToReturn;
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

  group('LoginController First-Run Recovery Tests', () {
    late FakeAuthService fakeAuth;
    late FakeUserRepository fakeUserRepo;
    late FakeUserIdentityService fakeIdentityService;
    late FakeFirstRunRecoveryDetector fakeDetector;
    late SessionManager sessionManager;
    late LocalProfileService localProfileService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      fakeAuth = FakeAuthService();
      fakeUserRepo = FakeUserRepository();
      fakeIdentityService = FakeUserIdentityService();
      fakeDetector = FakeFirstRunRecoveryDetector();
      sessionManager = SessionManager();
      localProfileService = LocalProfileService();
    });

    LoginController createController() {
      return LoginController(
        authService: fakeAuth,
        localProfileService: localProfileService,
        userRepository: fakeUserRepo,
        sessionManager: sessionManager,
        userIdentityService: fakeIdentityService,
        recoveryDetector: fakeDetector,
      );
    }

    test('1. Google login + eligibleEmptyLocal yields navigateToRecovery', () async {
      fakeDetector.resultToReturn = const FirstRunRecoveryResult(
        state: FirstRunRecoveryState.eligibleEmptyLocal,
        localSummary: LocalDataSummary.empty(),
      );

      final controller = createController();
      final result = await controller.handleGoogleSignIn();

      expect(result, equals(LoginResult.navigateToRecovery));
      expect(controller.recoveryResult?.isEligible, isTrue);
      expect(controller.recoveryResult?.state, equals(FirstRunRecoveryState.eligibleEmptyLocal));
      expect(fakeDetector.checkEligibilityCallCount, equals(1));
    });

    test('2. Google login + eligibleConflictLocal yields navigateToRecovery', () async {
      fakeDetector.resultToReturn = const FirstRunRecoveryResult(
        state: FirstRunRecoveryState.eligibleConflictLocal,
        localSummary: LocalDataSummary(noteCount: 5, folderCount: 1, taskCount: 2),
      );

      final controller = createController();
      final result = await controller.handleGoogleSignIn();

      expect(result, equals(LoginResult.navigateToRecovery));
      expect(controller.recoveryResult?.isEligible, isTrue);
      expect(controller.recoveryResult?.state, equals(FirstRunRecoveryState.eligibleConflictLocal));
      expect(fakeDetector.checkEligibilityCallCount, equals(1));
    });

    test('3. Google login + noRecoveryRequired yields navigateToProfile (when profile exists)', () async {
      fakeDetector.resultToReturn = const FirstRunRecoveryResult.noRecoveryRequired();
      fakeUserRepo.profileCompleted = true;

      final controller = createController();
      final result = await controller.handleGoogleSignIn();

      expect(result, equals(LoginResult.navigateToProfile));
      expect(fakeDetector.checkEligibilityCallCount, equals(1));
    });

    test('4. Google login + detectionFailed yields navigateToProfile (fail-safe non-blocking)', () async {
      fakeDetector.resultToReturn = const FirstRunRecoveryResult.detectionFailed(
        failureReason: 'Network timeout',
      );
      fakeUserRepo.profileCompleted = true;

      final controller = createController();
      final result = await controller.handleGoogleSignIn();

      expect(result, equals(LoginResult.navigateToProfile));
      expect(fakeDetector.checkEligibilityCallCount, equals(1));
    });

    test('5. Google login cancelled returns LoginResult.cancelled without detector execution', () async {
      fakeAuth.resultToReturn = AuthResult.cancelled();

      final controller = createController();
      final result = await controller.handleGoogleSignIn();

      expect(result, equals(LoginResult.cancelled));
      expect(fakeDetector.checkEligibilityCallCount, equals(0));
    });

    test('6. Google authentication failure returns LoginResult.error with error message', () async {
      fakeAuth.resultToReturn = AuthResult.failure('OAuth server error');

      final controller = createController();
      final result = await controller.handleGoogleSignIn();

      expect(result, equals(LoginResult.error));
      expect(controller.errorMessage, equals('OAuth server error'));
      expect(fakeDetector.checkEligibilityCallCount, equals(0));
    });

    test('7. Google login while already authenticating rejects duplicate request', () async {
      fakeDetector.resultToReturn = const FirstRunRecoveryResult.noRecoveryRequired();

      final controller = createController();
      final firstFuture = controller.handleGoogleSignIn();
      final secondFuture = controller.handleGoogleSignIn();

      final secondResult = await secondFuture;
      expect(secondResult, equals(LoginResult.cancelled));

      final firstResult = await firstFuture;
      expect(firstResult, equals(LoginResult.navigateToProfile));
    });

    test('8. Offline login yields navigateToProfile and NEVER calls recovery detector', () async {
      final controller = createController();
      final result = await controller.handleOfflineSignIn();

      expect(result, equals(LoginResult.navigateToProfile));
      expect(fakeDetector.checkEligibilityCallCount, equals(0));
      expect(sessionManager.isLoggedIn, isTrue);
      expect(sessionManager.isOffline, isTrue);
    });

    test('9. Recovery detector is called exactly once during single Google sign-in', () async {
      fakeDetector.resultToReturn = const FirstRunRecoveryResult.noRecoveryRequired();

      final controller = createController();
      await controller.handleGoogleSignIn();

      expect(fakeDetector.checkEligibilityCallCount, equals(1));
    });

    test('10. Recovery result is forwarded unchanged on LoginController', () async {
      const customResult = FirstRunRecoveryResult(
        state: FirstRunRecoveryState.eligibleEmptyLocal,
        localSummary: LocalDataSummary.empty(),
      );
      fakeDetector.resultToReturn = customResult;

      final controller = createController();
      await controller.handleGoogleSignIn();

      expect(controller.recoveryResult, equals(customResult));
    });
  });
}
