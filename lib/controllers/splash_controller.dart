import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/session_state.dart';
import '../repositories/user_repository.dart';
import '../services/database_service.dart';
import '../services/session_manager.dart';

enum SplashDestination {
  onboarding,
  login,
  passcodeLock,
  profileCompletion,
  home,
}

class SplashController {
  final FlutterSecureStorage _secureStorage;

  SplashController({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Performs background service initializations and determines the initial
  /// navigation destination using the following priority order:
  ///
  /// 1. Has the user seen onboarding? → onboarding
  /// 2. Is there an active session? → login
  /// 3. Offline session → home (no profile required)
  /// 4. Authenticated session, no profile → profileCompletion
  /// 5. Authenticated session, profile complete → home (or passcodeLock)
  Future<SplashDestination> initializeAndDetermineDestination({
    Duration minDisplayDuration = const Duration(milliseconds: 1500),
  }) async {
    final stopwatch = Stopwatch()..start();

    // 1. Initialize local database and session manager in background
    final dbFuture = DatabaseService.instance.database;
    final sessionInitFuture = SessionManager().init();
    final appLockFuture = _secureStorage.read(key: 'app_lock_enabled');

    // Await core initializations
    await dbFuture;
    await sessionInitFuture;
    final appLockEnabled = (await appLockFuture) == 'true';

    // Restore active session CurrentUser domain model
    await UserRepository().restoreActiveSession();

    // 2. Query SessionManager for the current session state decision
    final sessionState = SessionManager().currentSessionState;

    SplashDestination destination;
    switch (sessionState) {
      case SessionState.firstLaunch:
        destination = SplashDestination.onboarding;
        break;

      case SessionState.noSession:
        destination = SplashDestination.login;
        break;

      case SessionState.offline:
        // Offline users skip profile setup entirely.
        destination = appLockEnabled
            ? SplashDestination.passcodeLock
            : SplashDestination.home;
        break;

      case SessionState.authenticated:
        // Google-authenticated users: check whether they have a profile.
        // UserRepository coordinates with SqliteProfileRepository internally.
        final hasProfile = await UserRepository().hasCompletedProfile();
        if (!hasProfile) {
          destination = SplashDestination.profileCompletion;
        } else {
          destination = appLockEnabled
              ? SplashDestination.passcodeLock
              : SplashDestination.home;
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
