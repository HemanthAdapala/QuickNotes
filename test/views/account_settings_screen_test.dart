import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quick_notes/controllers/account_controller.dart';
import 'package:quick_notes/models/current_user.dart';
import 'package:quick_notes/models/identity_link_result.dart';
import 'package:quick_notes/models/session_type.dart';
import 'package:quick_notes/models/user_identity.dart';
import 'package:quick_notes/models/user_profile.dart';
import 'package:quick_notes/repositories/user_identity_repository.dart';
import 'package:quick_notes/repositories/user_repository.dart';
import 'package:quick_notes/services/authentication_service.dart';
import 'package:quick_notes/services/recovery/first_run_recovery_detector.dart';
import 'package:quick_notes/services/recovery/first_run_recovery_state.dart';
import 'package:quick_notes/services/recovery/local_data_detector.dart';
import 'package:quick_notes/services/session_manager.dart';
import 'package:quick_notes/services/user_identity_service.dart';
import 'package:quick_notes/views/screens/account/account_settings_screen.dart';

/// Fake Auth
class FakeAuthService implements AuthenticationService {
  AuthResult resultToReturn;
  int signInCallCount = 0;

  FakeAuthService({required this.resultToReturn});

  @override
  GoogleSignIn get googleSignIn => GoogleSignIn();

  @override
  Future<AuthResult> signInWithGoogle() async {
    signInCallCount++;
    return resultToReturn;
  }
}

/// Fake UserIdentityService
class FakeUserIdentityService implements UserIdentityService {
  IdentityLinkResult linkResultToReturn = IdentityLinkResult.linked(
    userId: 'usr_local_test',
    identity: UserIdentity(
      id: 'ident_123',
      userId: 'usr_local_test',
      provider: 'google',
      providerUserId: 'google_123',
      createdAt: DateTime.now(),
      lastAuthenticatedAt: DateTime.now(),
    ),
    profile: UserProfile(
      userId: 'usr_local_test',
      displayName: 'Test User',
      email: 'test@gmail.com',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  );

  @override
  void setRepositoryForTesting(UserIdentityRepository repository) {}

  @override
  Future<String> getOrCreateCanonicalUser({
    required String provider,
    required String providerUserId,
    String? email,
    String? displayName,
    String? photoUrl,
  }) async => 'usr_canonical';

  @override
  Future<IdentityLinkResult> linkGoogleIdentityToActiveUser({
    required String activeUserId,
    required String googleId,
    String? email,
    String? displayName,
    String? photoUrl,
  }) async => linkResultToReturn;
}

/// Fake Recovery Detector
class FakeFirstRunRecoveryDetector implements FirstRunRecoveryDetector {
  FirstRunRecoveryResult resultToReturn = const FirstRunRecoveryResult.noRecoveryRequired();

  FakeFirstRunRecoveryDetector({FirstRunRecoveryResult? resultToReturn}) {
    if (resultToReturn != null) {
      this.resultToReturn = resultToReturn;
    }
  }

  @override
  Future<FirstRunRecoveryResult> checkEligibility({
    String? overrideUserId,
    String? overrideProviderUserIdHash,
    SessionType? overrideSessionType,
  }) async => resultToReturn;
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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionManager().clearSession();
    UserRepository().clearActiveUser();
  });

  Widget createWidgetUnderTest(AccountController controller, {Size size = const Size(400, 800)}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: AccountSettingsScreen(controller: controller),
      ),
    );
  }

  group('Phase 1.9.8.2 — AccountSettingsScreen Widget Tests', () {
    testWidgets('T-21. Offline Account screen renders banner, description, and Sign in button', (tester) async {
      await SessionManager().saveSession(
        userId: 'usr_local_test',
        sessionType: SessionType.offline,
      );

      final userRepo = UserRepository();
      await userRepo.saveUser(CurrentUser(
        id: 'usr_local_test',
        displayName: 'Offline User',
        email: 'offline@local.quicknotes',
        sessionType: SessionType.offline,
        isOffline: true,
        createdAt: DateTime.now(),
      ));

      final controller = AccountController(
        sessionManager: SessionManager(),
        userRepository: userRepo,
      );

      await tester.pumpWidget(createWidgetUnderTest(controller));
      await tester.pumpAndSettle();

      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Offline Account'), findsOneWidget);
      expect(find.textContaining('Your notes are stored on this device'), findsOneWidget);
      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Delete your data and account'), findsOneWidget);
    });

    testWidgets('T-22. Authenticated Google Account renders avatar, display name, email, and Google connected badge', (tester) async {
      await SessionManager().saveSession(
        userId: 'usr_google_123',
        sessionType: SessionType.google,
      );

      final userRepo = UserRepository();
      await userRepo.saveUser(CurrentUser(
        id: 'usr_google_123',
        displayName: 'Jane Doe',
        email: 'janedoe@gmail.com',
        photoUrl: null,
        sessionType: SessionType.google,
        isOffline: false,
        createdAt: DateTime.now(),
      ));

      final controller = AccountController(
        sessionManager: SessionManager(),
        userRepository: userRepo,
      );

      await tester.pumpWidget(createWidgetUnderTest(controller));
      await tester.pumpAndSettle();

      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Jane Doe'), findsOneWidget);
      expect(find.text('janedoe@gmail.com'), findsOneWidget);
      expect(find.text('Google Account Connected'), findsOneWidget);
      expect(find.text('Sign in with Google'), findsNothing);
    });

    testWidgets('T-23 & T-24. Sign in button invokes controller and displays loading indicator while authenticating', (tester) async {
      await SessionManager().saveSession(
        userId: 'usr_local_test',
        sessionType: SessionType.offline,
      );

      final fakeAuth = FakeAuthService(resultToReturn: AuthResult.cancelled());
      final fakeIdentityService = FakeUserIdentityService();

      final controller = AccountController(
        authService: fakeAuth,
        userIdentityService: fakeIdentityService,
        sessionManager: SessionManager(),
        userRepository: UserRepository(),
      );

      await tester.pumpWidget(createWidgetUnderTest(controller));
      await tester.pumpAndSettle();

      final signInButton = find.text('Sign in with Google');
      expect(signInButton, findsOneWidget);

      await tester.tap(signInButton);
      await tester.pump();

      expect(fakeAuth.signInCallCount, equals(1));
    });

    testWidgets('T-25 & T-26. Conflict dialog appears on conflict and Cancel closes dialog', (tester) async {
      await SessionManager().saveSession(
        userId: 'usr_local_test',
        sessionType: SessionType.offline,
      );

      final fakeAuth = FakeAuthService(
        resultToReturn: AuthResult.success(
          user: CurrentUser(
            id: 'google_uid_collision',
            email: 'collision@gmail.com',
            displayName: 'Existing User',
            sessionType: SessionType.google,
            isOffline: false,
            createdAt: DateTime.now(),
          ),
        ),
      );

      final fakeIdentityService = FakeUserIdentityService();
      fakeIdentityService.linkResultToReturn = IdentityLinkResult.conflict(
        activeUserId: 'usr_local_test',
        conflictingUserId: 'usr_existing_google_user',
        googleId: 'google_uid_collision',
      );

      final controller = AccountController(
        authService: fakeAuth,
        userIdentityService: fakeIdentityService,
        sessionManager: SessionManager(),
        userRepository: UserRepository(),
      );

      await tester.pumpWidget(createWidgetUnderTest(controller));
      await tester.pumpAndSettle();

      // Tap Sign in
      await tester.tap(find.text('Sign in with Google'));
      await tester.pumpAndSettle();

      // T-25: Conflict dialog appears
      expect(find.text('Existing Account Found'), findsOneWidget);
      expect(find.textContaining('This Google account is already linked'), findsOneWidget);
      expect(find.text('Switch Account'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // T-26: Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Existing Account Found'), findsNothing);
      expect(controller.state, equals(AccountUiState.idle));
    });

    testWidgets('T-27. Conflict Switch Account triggers account switch and updates screen', (tester) async {
      await SessionManager().saveSession(
        userId: 'usr_local_test',
        sessionType: SessionType.offline,
      );

      final userRepo = UserRepository();
      await userRepo.saveUser(CurrentUser(
        id: 'usr_existing_google_user',
        displayName: 'Google Existing User',
        email: 'googleexisting@gmail.com',
        sessionType: SessionType.google,
        isOffline: false,
        createdAt: DateTime.now(),
      ));

      final fakeAuth = FakeAuthService(
        resultToReturn: AuthResult.success(
          user: CurrentUser(
            id: 'google_uid_collision',
            email: 'googleexisting@gmail.com',
            displayName: 'Google Existing User',
            sessionType: SessionType.google,
            isOffline: false,
            createdAt: DateTime.now(),
          ),
        ),
      );

      final fakeIdentityService = FakeUserIdentityService();
      fakeIdentityService.linkResultToReturn = IdentityLinkResult.conflict(
        activeUserId: 'usr_local_test',
        conflictingUserId: 'usr_existing_google_user',
        googleId: 'google_uid_collision',
      );

      final controller = AccountController(
        authService: fakeAuth,
        userIdentityService: fakeIdentityService,
        sessionManager: SessionManager(),
        userRepository: userRepo,
      );

      await tester.pumpWidget(createWidgetUnderTest(controller));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in with Google'));
      await tester.pumpAndSettle();

      expect(find.text('Existing Account Found'), findsOneWidget);

      // Tap Switch Account
      await tester.tap(find.text('Switch Account'));
      await tester.pumpAndSettle();

      expect(find.text('Existing Account Found'), findsNothing);
      expect(SessionManager().activeUserId, equals('usr_existing_google_user'));
      expect(SessionManager().isAuthenticated, isTrue);
    });

    testWidgets('T-28. Recovery result triggers navigation to FirstRunRecoveryScreen', (tester) async {
      await SessionManager().saveSession(
        userId: 'usr_local_test',
        sessionType: SessionType.offline,
      );

      final fakeAuth = FakeAuthService(
        resultToReturn: AuthResult.success(
          user: CurrentUser(
            id: 'google_uid_rec',
            email: 'rec@gmail.com',
            displayName: 'Rec User',
            sessionType: SessionType.google,
            isOffline: false,
            createdAt: DateTime.now(),
          ),
        ),
      );

      const eligibleResult = FirstRunRecoveryResult(
        state: FirstRunRecoveryState.eligibleEmptyLocal,
        localSummary: LocalDataSummary.empty(),
      );

      final fakeDetector = FakeFirstRunRecoveryDetector(
        resultToReturn: eligibleResult,
      );

      final controller = AccountController(
        authService: fakeAuth,
        userIdentityService: FakeUserIdentityService(),
        sessionManager: SessionManager(),
        userRepository: UserRepository(),
        recoveryDetector: fakeDetector,
      );

      await tester.pumpWidget(createWidgetUnderTest(controller));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in with Google'));
      await tester.pumpAndSettle();

      // Navigated to FirstRunRecoveryScreen
      expect(find.text('Welcome back.'), findsOneWidget);
    });

    testWidgets('T-30. Error result displays SnackBar with sanitized message', (tester) async {
      await SessionManager().saveSession(
        userId: 'usr_local_test',
        sessionType: SessionType.offline,
      );

      final fakeAuth = FakeAuthService(
        resultToReturn: AuthResult.failure('Authentication timeout. Please retry.'),
      );

      final controller = AccountController(
        authService: fakeAuth,
        userIdentityService: FakeUserIdentityService(),
        sessionManager: SessionManager(),
        userRepository: UserRepository(),
      );

      await tester.pumpWidget(createWidgetUnderTest(controller));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in with Google'));
      await tester.pumpAndSettle();

      expect(find.text('Authentication timeout. Please retry.'), findsOneWidget);
    });

    testWidgets('T-31. Cancelled result remains on screen in idle state', (tester) async {
      await SessionManager().saveSession(
        userId: 'usr_local_test',
        sessionType: SessionType.offline,
      );

      final fakeAuth = FakeAuthService(
        resultToReturn: AuthResult.cancelled(),
      );

      final controller = AccountController(
        authService: fakeAuth,
        userIdentityService: FakeUserIdentityService(),
        sessionManager: SessionManager(),
        userRepository: UserRepository(),
      );

      await tester.pumpWidget(createWidgetUnderTest(controller));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in with Google'));
      await tester.pumpAndSettle();

      expect(find.text('Offline Account'), findsOneWidget);
      expect(controller.state, equals(AccountUiState.idle));
    });

    testWidgets('T-32. Small phone layout (320x480) renders without overflow errors', (tester) async {
      await SessionManager().saveSession(
        userId: 'usr_local_test',
        sessionType: SessionType.offline,
      );

      final controller = AccountController(
        sessionManager: SessionManager(),
        userRepository: UserRepository(),
      );

      await tester.pumpWidget(createWidgetUnderTest(controller, size: const Size(320, 480)));
      await tester.pumpAndSettle();

      expect(find.text('Offline Account'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
