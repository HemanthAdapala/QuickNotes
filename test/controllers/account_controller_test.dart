import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:quick_notes/controllers/account_controller.dart';
import 'package:quick_notes/models/current_user.dart';
import 'package:quick_notes/models/folder.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/models/session_type.dart';
import 'package:quick_notes/models/task_item.dart';
import 'package:quick_notes/repositories/folders_repository.dart';
import 'package:quick_notes/repositories/notes_repository.dart';
import 'package:quick_notes/repositories/tasks_repository.dart';
import 'package:quick_notes/repositories/user_identity_repository.dart';
import 'package:quick_notes/repositories/user_repository.dart';
import 'package:quick_notes/services/authentication_service.dart';
import 'package:quick_notes/services/database_service.dart';
import 'package:quick_notes/services/local_profile_service.dart';
import 'package:quick_notes/services/recovery/first_run_recovery_detector.dart';
import 'package:quick_notes/services/recovery/first_run_recovery_state.dart';
import 'package:quick_notes/services/recovery/local_data_detector.dart';
import 'package:quick_notes/services/session_manager.dart';
import 'package:quick_notes/services/user_identity_service.dart';

/// Fake AuthenticationService for deterministic testing
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

/// Fake FirstRunRecoveryDetector for testing recovery flows
class FakeFirstRunRecoveryDetector implements FirstRunRecoveryDetector {
  FirstRunRecoveryResult resultToReturn = const FirstRunRecoveryResult.noRecoveryRequired();
  bool shouldThrow = false;
  int checkEligibilityCallCount = 0;

  FakeFirstRunRecoveryDetector({
    FirstRunRecoveryResult? resultToReturn,
    this.shouldThrow = false,
  }) {
    if (resultToReturn != null) {
      this.resultToReturn = resultToReturn;
    }
  }

  @override
  Future<FirstRunRecoveryResult> checkEligibility({
    String? overrideUserId,
    String? overrideProviderUserIdHash,
    SessionType? overrideSessionType,
  }) async {
    checkEligibilityCallCount++;
    if (shouldThrow) {
      throw Exception('Simulated network failure querying Google Drive');
    }
    return resultToReturn;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SqliteUserIdentityRepository identityRepo;
  late UserIdentityService identityService;
  late SessionManager sessionManager;
  late UserRepository userRepository;
  late SqliteNotesRepository notesRepo;
  late SqliteFoldersRepository foldersRepo;
  late SqliteTasksRepository tasksRepo;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => '.',
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

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final db = await DatabaseService.instance.database;
    await db.delete('users');
    await db.delete('user_identities');
    await db.delete('user_profiles');
    await db.delete('notes');
    await db.delete('folders');
    await db.delete('tasks');
    await db.delete('sync_outbox');

    identityRepo = SqliteUserIdentityRepository();
    identityService = UserIdentityService();
    identityService.setRepositoryForTesting(identityRepo);
    sessionManager = SessionManager();
    userRepository = UserRepository();
    notesRepo = SqliteNotesRepository();
    foldersRepo = SqliteFoldersRepository();
    tasksRepo = SqliteTasksRepository();
    await sessionManager.clearSession();
  });

  /// Helper to initialize an active offline user in DB and SessionManager
  Future<String> setupActiveOfflineUser({String? customDisplayName}) async {
    final offlineUser = await LocalProfileService().createOfflineProfile();
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final db = await DatabaseService.instance.database;

    await db.insert('users', {
      'id': offlineUser.id,
      'isOffline': 1,
      'createdAt': nowIso,
      'updatedAt': nowIso,
    });

    await db.insert('user_profiles', {
      'userId': offlineUser.id,
      'displayName': customDisplayName ?? offlineUser.displayName,
      'email': offlineUser.email,
      'photoUrl': null,
      'usesGooglePhoto': 0,
      'profileVersion': 1,
      'createdAt': nowIso,
      'updatedAt': nowIso,
    });

    await sessionManager.saveSession(
      userId: offlineUser.id,
      sessionType: SessionType.offline,
    );
    await userRepository.saveUser(offlineUser);

    return offlineUser.id;
  }

  group('Phase 1.9.8.2 — AccountController Unit Tests', () {
    test('T-1. Offline user taps Sign in with Google calls AuthenticationService once', () async {
      await setupActiveOfflineUser();

      final fakeAuth = FakeAuthService(
        resultToReturn: AuthResult.cancelled(),
      );
      final controller = AccountController(
        authService: fakeAuth,
        userIdentityService: identityService,
        sessionManager: sessionManager,
        userRepository: userRepository,
      );

      final result = await controller.signInWithGoogle();

      expect(fakeAuth.signInCallCount, equals(1));
      expect(result.action, equals(AccountLinkAction.cancelled));
      expect(controller.state, equals(AccountUiState.idle));
      expect(sessionManager.isOffline, isTrue);
    });

    test('T-2 & T-3 & T-4 & T-5. Google authentication succeeds, links in-place, preserves canonical ID and updates session', () async {
      final offlineId = await setupActiveOfflineUser();

      const googleId = 'google_uid_test_100';
      const email = 'johndoe@gmail.com';
      const displayName = 'John Doe';
      const photoUrl = 'https://photos.google.com/johndoe.png';

      final fakeAuth = FakeAuthService(
        resultToReturn: AuthResult.success(
          user: CurrentUser(
            id: googleId,
            email: email,
            displayName: displayName,
            photoUrl: photoUrl,
            sessionType: SessionType.google,
            isOffline: false,
            createdAt: DateTime.now(),
          ),
          accessToken: 'access_token_123',
          idToken: 'id_token_123',
        ),
      );

      final fakeDetector = FakeFirstRunRecoveryDetector(
        resultToReturn: const FirstRunRecoveryResult.noRecoveryRequired(),
      );

      final controller = AccountController(
        authService: fakeAuth,
        userIdentityService: identityService,
        sessionManager: sessionManager,
        userRepository: userRepository,
        recoveryDetector: fakeDetector,
      );

      final result = await controller.signInWithGoogle();

      // T-3: Result is success
      expect(result.action, equals(AccountLinkAction.success));
      expect(controller.state, equals(AccountUiState.idle));

      // T-4: Canonical ID is exactly preserved
      expect(sessionManager.activeUserId, equals(offlineId));
      expect(userRepository.currentUser?.id, equals(offlineId));

      // T-5: Session updated to authenticated Google
      expect(sessionManager.activeSessionType, equals(SessionType.google));
      expect(sessionManager.isAuthenticated, isTrue);
      expect(sessionManager.isOffline, isFalse);

      // Verify UserProfile in DB
      final identity = await identityRepo.findIdentity('google', googleId);
      expect(identity, isNotNull);
      expect(identity!.userId, equals(offlineId));

      final userInDb = await identityRepo.findUserById(offlineId);
      expect(userInDb!.isOffline, isFalse);
    });

    test('T-6. Local data (notes, folders, tasks) remains untouched and accessible under canonical ID', () async {
      final offlineId = await setupActiveOfflineUser();

      // Create note, folder, task under offlineId
      final note = Note(
        id: const Uuid().v4(),
        userId: offlineId,
        title: 'Local Note',
        content: 'Local Content',
        tags: const [],
        attachments: const [],
        colorValue: 0xFFFFFFFF,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await notesRepo.insertNote(note);

      final folder = Folder(
        id: const Uuid().v4(),
        userId: offlineId,
        name: 'Local Folder',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await foldersRepo.insertFolder(folder);

      final task = TaskItem(
        id: const Uuid().v4(),
        userId: offlineId,
        title: 'Local Task',
        dueDate: DateTime.now(),
        priority: 'high',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await tasksRepo.insertTask(task);

      final fakeAuth = FakeAuthService(
        resultToReturn: AuthResult.success(
          user: CurrentUser(
            id: 'google_uid_data_preservation',
            email: 'preserve@gmail.com',
            displayName: 'Preserve',
            sessionType: SessionType.google,
            isOffline: false,
            createdAt: DateTime.now(),
          ),
        ),
      );

      final fakeDetector = FakeFirstRunRecoveryDetector(
        resultToReturn: const FirstRunRecoveryResult.noRecoveryRequired(),
      );

      final controller = AccountController(
        authService: fakeAuth,
        userIdentityService: identityService,
        sessionManager: sessionManager,
        userRepository: userRepository,
        recoveryDetector: fakeDetector,
      );

      await controller.signInWithGoogle();

      // Verify all data is intact and queries still return them
      final notes = await notesRepo.getNotes();
      expect(notes.length, equals(1));
      expect(notes.first.id, equals(note.id));
      expect(notes.first.userId, equals(offlineId));

      final folders = await foldersRepo.getFolders();
      expect(folders.length, equals(1));
      expect(folders.first.id, equals(folder.id));

      final tasks = await tasksRepo.getTasks();
      expect(tasks.length, equals(1));
      expect(tasks.first.id, equals(task.id));
    });

    test('T-7. Recovery detector returns eligible -> navigateToRecovery', () async {
      await setupActiveOfflineUser();

      final fakeAuth = FakeAuthService(
        resultToReturn: AuthResult.success(
          user: CurrentUser(
            id: 'google_uid_recovery_eligible',
            email: 'rec@gmail.com',
            displayName: 'Recovery User',
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
        userIdentityService: identityService,
        sessionManager: sessionManager,
        userRepository: userRepository,
        recoveryDetector: fakeDetector,
      );

      final result = await controller.signInWithGoogle();

      expect(result.action, equals(AccountLinkAction.navigateToRecovery));
      expect(result.recoveryResult, equals(eligibleResult));
      expect(controller.recoveryResult, equals(eligibleResult));
    });

    test('T-8. Recovery detector returns not eligible -> success', () async {
      await setupActiveOfflineUser();

      final fakeAuth = FakeAuthService(
        resultToReturn: AuthResult.success(
          user: CurrentUser(
            id: 'google_uid_not_eligible',
            email: 'notrec@gmail.com',
            displayName: 'Clean User',
            sessionType: SessionType.google,
            isOffline: false,
            createdAt: DateTime.now(),
          ),
        ),
      );

      final fakeDetector = FakeFirstRunRecoveryDetector(
        resultToReturn: const FirstRunRecoveryResult.noRecoveryRequired(),
      );

      final controller = AccountController(
        authService: fakeAuth,
        userIdentityService: identityService,
        sessionManager: sessionManager,
        userRepository: userRepository,
        recoveryDetector: fakeDetector,
      );

      final result = await controller.signInWithGoogle();

      expect(result.action, equals(AccountLinkAction.success));
      expect(controller.state, equals(AccountUiState.idle));
    });

    test('T-9. Recovery detector fails -> fail-safe continuation (success)', () async {
      await setupActiveOfflineUser();

      final fakeAuth = FakeAuthService(
        resultToReturn: AuthResult.success(
          user: CurrentUser(
            id: 'google_uid_detector_fails',
            email: 'failsafe@gmail.com',
            displayName: 'Failsafe User',
            sessionType: SessionType.google,
            isOffline: false,
            createdAt: DateTime.now(),
          ),
        ),
      );

      final fakeDetector = FakeFirstRunRecoveryDetector(
        resultToReturn: const FirstRunRecoveryResult.detectionFailed(
          failureReason: 'Network timeout',
        ),
        shouldThrow: true,
      );

      final controller = AccountController(
        authService: fakeAuth,
        userIdentityService: identityService,
        sessionManager: sessionManager,
        userRepository: userRepository,
        recoveryDetector: fakeDetector,
      );

      final result = await controller.signInWithGoogle();

      // Does not trap the user in error state
      expect(result.action, equals(AccountLinkAction.success));
      expect(controller.state, equals(AccountUiState.idle));
    });

    test('T-10. Google authentication cancelled -> returns cancelled, remains offline', () async {
      final offlineId = await setupActiveOfflineUser();

      final fakeAuth = FakeAuthService(
        resultToReturn: AuthResult.cancelled(),
      );

      final controller = AccountController(
        authService: fakeAuth,
        userIdentityService: identityService,
        sessionManager: sessionManager,
        userRepository: userRepository,
      );

      final result = await controller.signInWithGoogle();

      expect(result.action, equals(AccountLinkAction.cancelled));
      expect(controller.state, equals(AccountUiState.idle));
      expect(sessionManager.activeUserId, equals(offlineId));
      expect(sessionManager.isOffline, isTrue);
    });

    test('T-11. Google authentication fails -> returns error, remains offline', () async {
      final offlineId = await setupActiveOfflineUser();

      final fakeAuth = FakeAuthService(
        resultToReturn: AuthResult.failure('Network connection timed out'),
      );

      final controller = AccountController(
        authService: fakeAuth,
        userIdentityService: identityService,
        sessionManager: sessionManager,
        userRepository: userRepository,
      );

      final result = await controller.signInWithGoogle();

      expect(result.action, equals(AccountLinkAction.error));
      expect(result.errorMessage, contains('Network connection timed out'));
      expect(controller.state, equals(AccountUiState.error));
      expect(sessionManager.activeUserId, equals(offlineId));
      expect(sessionManager.isOffline, isTrue);
    });

    test('T-12. Google identity conflict -> returns conflict, stays offline with 0 mutations', () async {
      // 1. Existing user B with google_uid_collision
      const conflictingGoogleId = 'google_uid_collision_999';
      final userBId = await identityService.getOrCreateCanonicalUser(
        provider: 'google',
        providerUserId: conflictingGoogleId,
        email: 'userb@gmail.com',
        displayName: 'User B',
      );

      // 2. Active offline user A
      final userAId = await setupActiveOfflineUser();

      final fakeAuth = FakeAuthService(
        resultToReturn: AuthResult.success(
          user: CurrentUser(
            id: conflictingGoogleId,
            email: 'userb@gmail.com',
            displayName: 'User B',
            sessionType: SessionType.google,
            isOffline: false,
            createdAt: DateTime.now(),
          ),
        ),
      );

      final controller = AccountController(
        authService: fakeAuth,
        userIdentityService: identityService,
        sessionManager: sessionManager,
        userRepository: userRepository,
      );

      final result = await controller.signInWithGoogle();

      expect(result.action, equals(AccountLinkAction.conflict));
      expect(result.conflictingUserId, equals(userBId));
      expect(result.googleEmail, equals('userb@gmail.com'));
      expect(controller.state, equals(AccountUiState.conflict));

      // Active session remains User A offline
      expect(sessionManager.activeUserId, equals(userAId));
      expect(sessionManager.isOffline, isTrue);
    });

    test('T-13. Conflict Cancel -> remains offline, resets to idle, 0 mutations', () async {
      const conflictingGoogleId = 'google_uid_cancel_test';
      await identityService.getOrCreateCanonicalUser(
        provider: 'google',
        providerUserId: conflictingGoogleId,
        email: 'existing@gmail.com',
        displayName: 'Existing User',
      );

      final userAId = await setupActiveOfflineUser();

      final fakeAuth = FakeAuthService(
        resultToReturn: AuthResult.success(
          user: CurrentUser(
            id: conflictingGoogleId,
            email: 'existing@gmail.com',
            displayName: 'Existing User',
            sessionType: SessionType.google,
            isOffline: false,
            createdAt: DateTime.now(),
          ),
        ),
      );

      final controller = AccountController(
        authService: fakeAuth,
        userIdentityService: identityService,
        sessionManager: sessionManager,
        userRepository: userRepository,
      );

      await controller.signInWithGoogle();
      expect(controller.state, equals(AccountUiState.conflict));

      controller.cancelConflict();
      expect(controller.state, equals(AccountUiState.idle));
      expect(controller.conflictingUserId, isNull);
      expect(sessionManager.activeUserId, equals(userAId));
      expect(sessionManager.isOffline, isTrue);
    });

    test('T-14 & T-15. Conflict Switch Account -> activates existing Google account while offline account remains stored', () async {
      const conflictingGoogleId = 'google_uid_switch_test';
      final existingGoogleUserId = await identityService.getOrCreateCanonicalUser(
        provider: 'google',
        providerUserId: conflictingGoogleId,
        email: 'googleuser@gmail.com',
        displayName: 'Google User',
      );

      final offlineUserId = await setupActiveOfflineUser();

      final fakeAuth = FakeAuthService(
        resultToReturn: AuthResult.success(
          user: CurrentUser(
            id: conflictingGoogleId,
            email: 'googleuser@gmail.com',
            displayName: 'Google User',
            sessionType: SessionType.google,
            isOffline: false,
            createdAt: DateTime.now(),
          ),
        ),
      );

      final controller = AccountController(
        authService: fakeAuth,
        userIdentityService: identityService,
        sessionManager: sessionManager,
        userRepository: userRepository,
      );

      await controller.signInWithGoogle();
      expect(controller.state, equals(AccountUiState.conflict));

      // Switch account
      final switched = await controller.switchAccountToConflictingUser();
      expect(switched, isTrue);
      expect(controller.state, equals(AccountUiState.idle));

      // T-14: Active session is now the existing Google account
      expect(sessionManager.activeUserId, equals(existingGoogleUserId));
      expect(sessionManager.activeSessionType, equals(SessionType.google));

      // T-15: Offline account remains stored on disk
      final offlineUserInDb = await identityRepo.findUserById(offlineUserId);
      expect(offlineUserInDb, isNotNull);
      expect(offlineUserInDb!.isOffline, isTrue);
    });

    test('T-16. Repeated link with same identity is handled idempotently', () async {
      final offlineId = await setupActiveOfflineUser();
      const googleId = 'google_uid_idempotent_test';

      final fakeAuth = FakeAuthService(
        resultToReturn: AuthResult.success(
          user: CurrentUser(
            id: googleId,
            email: 'idem@gmail.com',
            displayName: 'Idempotent User',
            sessionType: SessionType.google,
            isOffline: false,
            createdAt: DateTime.now(),
          ),
        ),
      );

      final controller = AccountController(
        authService: fakeAuth,
        userIdentityService: identityService,
        sessionManager: sessionManager,
        userRepository: userRepository,
        recoveryDetector: FakeFirstRunRecoveryDetector(
          resultToReturn: const FirstRunRecoveryResult.noRecoveryRequired(),
        ),
      );

      final r1 = await controller.signInWithGoogle();
      expect(r1.action, equals(AccountLinkAction.success));

      final r2 = await controller.signInWithGoogle();
      expect(r2.action, equals(AccountLinkAction.success));

      final db = await DatabaseService.instance.database;
      final countResult = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM user_identities WHERE userId = ?',
        [offlineId],
      );
      expect(countResult.first['cnt'], equals(1));
    });

    test('T-17. User already linked to different Google identity is safely rejected', () async {
      final offlineId = await setupActiveOfflineUser();
      const firstGoogleId = 'google_primary_id';
      const secondGoogleId = 'google_secondary_id';

      // Link first identity
      await identityService.linkGoogleIdentityToActiveUser(
        activeUserId: offlineId,
        googleId: firstGoogleId,
        displayName: 'Primary User',
      );

      // Try linking second identity
      final fakeAuth = FakeAuthService(
        resultToReturn: AuthResult.success(
          user: CurrentUser(
            id: secondGoogleId,
            email: 'second@gmail.com',
            displayName: 'Second User',
            sessionType: SessionType.google,
            isOffline: false,
            createdAt: DateTime.now(),
          ),
        ),
      );

      final controller = AccountController(
        authService: fakeAuth,
        userIdentityService: identityService,
        sessionManager: sessionManager,
        userRepository: userRepository,
      );

      final result = await controller.signInWithGoogle();

      expect(result.action, equals(AccountLinkAction.error));
      expect(result.errorMessage, contains('different Google account'));
    });

    test('T-18. Unknown current user returns safe failure', () async {
      await sessionManager.saveSession(
        userId: 'usr_nonexistent_user_xyz',
        sessionType: SessionType.offline,
      );

      final fakeAuth = FakeAuthService(
        resultToReturn: AuthResult.success(
          user: CurrentUser(
            id: 'google_uid_any',
            email: 'test@gmail.com',
            displayName: 'Test User',
            sessionType: SessionType.google,
            isOffline: false,
            createdAt: DateTime.now(),
          ),
        ),
      );

      final controller = AccountController(
        authService: fakeAuth,
        userIdentityService: identityService,
        sessionManager: sessionManager,
        userRepository: userRepository,
      );

      final result = await controller.signInWithGoogle();

      expect(result.action, equals(AccountLinkAction.error));
      expect(result.errorMessage, contains('not found'));
    });

    test('T-19. Double tap guards against concurrent operations', () async {
      await setupActiveOfflineUser();

      final fakeAuth = FakeAuthService(
        resultToReturn: AuthResult.cancelled(),
      );

      final controller = AccountController(
        authService: fakeAuth,
        userIdentityService: identityService,
        sessionManager: sessionManager,
        userRepository: userRepository,
      );

      // Simulate simultaneous double-tap
      final f1 = controller.signInWithGoogle();
      final f2 = controller.signInWithGoogle();

      final results = await Future.wait([f1, f2]);

      expect(fakeAuth.signInCallCount, equals(1));
      expect(results.any((r) => r.action == AccountLinkAction.cancelled), isTrue);
    });

    test('T-20. Unexpected exception returns sanitized error and preserves offline account', () async {
      final offlineId = await setupActiveOfflineUser();

      final throwingAuth = _ThrowingAuthService();

      final controller = AccountController(
        authService: throwingAuth,
        userIdentityService: identityService,
        sessionManager: sessionManager,
        userRepository: userRepository,
      );

      final result = await controller.signInWithGoogle();

      expect(result.action, equals(AccountLinkAction.error));
      expect(result.errorMessage?.contains('/data/user/0/databases/'), isFalse);
      expect(controller.state, equals(AccountUiState.error));
      expect(sessionManager.activeUserId, equals(offlineId));
      expect(sessionManager.isOffline, isTrue);
    });
  });
}

class _ThrowingAuthService implements AuthenticationService {
  @override
  GoogleSignIn get googleSignIn => GoogleSignIn();

  @override
  Future<AuthResult> signInWithGoogle() async {
    throw Exception('Disk read error at /data/user/0/databases/app.db with token=secret123');
  }
}
