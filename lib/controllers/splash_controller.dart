import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/session_state.dart';
import '../repositories/user_repository.dart';
import '../services/backup/google_drive_backup_service.dart';
import '../services/database_service.dart';
import '../services/recovery/first_run_recovery_detector.dart';
import '../services/recovery/first_run_recovery_state.dart';
import '../services/session_manager.dart';

enum SplashDestination {
  onboarding,
  login,
  passcodeLock,
  profileCompletion,
  recovery,
  home,
}

class SplashController {
  final FlutterSecureStorage _secureStorage;
  final SessionManager _sessionManager;
  final UserRepository _userRepository;
  final DatabaseService _databaseService;
  final FirstRunRecoveryDetector? _recoveryDetector;

  FirstRunRecoveryResult? _recoveryResult;
  FirstRunRecoveryResult? get recoveryResult => _recoveryResult;

  SplashController({
    FlutterSecureStorage? secureStorage,
    SessionManager? sessionManager,
    UserRepository? userRepository,
    DatabaseService? databaseService,
    FirstRunRecoveryDetector? recoveryDetector,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _sessionManager = sessionManager ?? SessionManager(),
        _userRepository = userRepository ?? UserRepository(),
        _databaseService = databaseService ?? DatabaseService.instance,
        _recoveryDetector = recoveryDetector;

  /// Performs background service initializations and determines the initial
  /// navigation destination using the following priority order:
  ///
  /// 1. Has the user seen onboarding? → onboarding
  /// 2. Is there an active session? → login
  /// 3. Offline session → home (or passcodeLock) (no profile/recovery required)
  /// 4. Authenticated session, no profile → profileCompletion
  /// 5. Authenticated session, eligible cloud backup → recovery (or passcodeLock)
  /// 6. Authenticated session, profile complete, no recovery → home (or passcodeLock)
  Future<SplashDestination> initializeAndDetermineDestination({
    Duration minDisplayDuration = const Duration(milliseconds: 1500),
  }) async {
    final stopwatch = Stopwatch()..start();

    // 1. Initialize local database and session manager in background
    final dbFuture = _databaseService.database;
    final sessionInitFuture = _sessionManager.init();
    final appLockFuture = _secureStorage.read(key: 'app_lock_enabled');

    // Await core initializations
    await dbFuture;
    await sessionInitFuture;
    final appLockEnabled = (await appLockFuture) == 'true';

    // Restore active session CurrentUser domain model
    await _userRepository.restoreActiveSession();

    // 2. Query SessionManager for the current session state decision
    final sessionState = _sessionManager.currentSessionState;

    SplashDestination destination;
    switch (sessionState) {
      case SessionState.firstLaunch:
        destination = SplashDestination.onboarding;
        break;

      case SessionState.noSession:
        destination = SplashDestination.login;
        break;

      case SessionState.offline:
        // Offline users skip profile setup and cloud recovery entirely.
        destination = appLockEnabled
            ? SplashDestination.passcodeLock
            : SplashDestination.home;
        break;

      case SessionState.authenticated:
        // Google-authenticated users: check whether they have a profile.
        final hasProfile = await _userRepository.hasCompletedProfile();
        if (!hasProfile) {
          destination = SplashDestination.profileCompletion;
        } else {
          // Phase 1.9.7.3C — Check First-Run Recovery eligibility for authenticated Google session
          final detector = _recoveryDetector ??
              FirstRunRecoveryDetector(
                  storageAdapter: GoogleDriveBackupService());
          final recResult = await detector.checkEligibility();
          _recoveryResult = recResult;

          if (recResult.isEligible) {
            destination = appLockEnabled
                ? SplashDestination.passcodeLock
                : SplashDestination.recovery;
          } else {
            destination = appLockEnabled
                ? SplashDestination.passcodeLock
                : SplashDestination.home;
          }
        }
        break;
    }

    // 3. Ensure minimum display duration has elapsed
    final elapsed = stopwatch.elapsed;
    if (elapsed < minDisplayDuration) {
      await Future.delayed(minDisplayDuration - elapsed);
    }

    return destination;
  }
}
