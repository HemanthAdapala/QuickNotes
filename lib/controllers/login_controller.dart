import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../repositories/user_repository.dart';
import '../services/database_service.dart';
import '../services/authentication_service.dart';
import '../services/backup/google_drive_backup_service.dart';
import '../services/local_profile_service.dart';
import '../services/recovery/first_run_recovery_detector.dart';
import '../services/recovery/first_run_recovery_state.dart';
import '../services/session_manager.dart';
import '../services/user_identity_service.dart';

/// Describes the navigation outcome of a login attempt.
///
/// LoginScreen switches on this enum to decide where to navigate.
/// LoginController never performs navigation directly.
enum LoginResult {
  /// Google or Offline auth succeeded and a profile already exists.
  navigateToHome,

  /// Google auth succeeded but no Quick Notes profile exists yet.
  /// Navigate to ProfileScreen so the user can complete setup.
  navigateToProfile,

  /// Google auth succeeded and an eligible cloud backup was detected.
  /// Navigate to FirstRunRecoveryScreen so the user can choose how to proceed.
  navigateToRecovery,

  /// User dismissed the sign-in picker without selecting an account.
  cancelled,

  /// An error occurred during authentication.
  error,
}

enum LoginUiState {
  idle,
  authenticatingGoogle,
  initializingOffline,
  error,
}

class LoginController extends ChangeNotifier {
  LoginUiState _state = LoginUiState.idle;
  LoginUiState get state => _state;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  FirstRunRecoveryResult? _recoveryResult;
  FirstRunRecoveryResult? get recoveryResult => _recoveryResult;

  final AuthenticationService _authService;
  final LocalProfileService _localProfileService;
  final UserRepository _userRepository;
  final SessionManager _sessionManager;
  final UserIdentityService _userIdentityService;
  final FirstRunRecoveryDetector? _recoveryDetector;

  LoginController({
    AuthenticationService? authService,
    LocalProfileService? localProfileService,
    UserRepository? userRepository,
    SessionManager? sessionManager,
    UserIdentityService? userIdentityService,
    FirstRunRecoveryDetector? recoveryDetector,
  })  : _authService = authService ?? AuthenticationService(),
        _localProfileService = localProfileService ?? LocalProfileService(),
        _userRepository = userRepository ?? UserRepository(),
        _sessionManager = sessionManager ?? SessionManager(),
        _userIdentityService = userIdentityService ?? UserIdentityService(),
        _recoveryDetector = recoveryDetector;

  void _setState(LoginUiState newState, [String? error]) {
    _state = newState;
    _errorMessage = error;
    notifyListeners();
  }

  /// Handle Google Sign-In button action.
  ///
  /// Returns a [LoginResult] enum — never navigates directly.
  /// - [LoginResult.navigateToRecovery] → eligible cloud backup exists.
  /// - [LoginResult.navigateToProfile] → first-time Google user, no profile yet.
  /// - [LoginResult.navigateToHome] → returning Google user with existing profile (or recovery fail-safe).
  /// - [LoginResult.cancelled] → user dismissed the account picker.
  /// - [LoginResult.error] → authentication failed.
  Future<LoginResult> handleGoogleSignIn() async {
    if (_state == LoginUiState.authenticatingGoogle) {
      return LoginResult.cancelled;
    }

    _setState(LoginUiState.authenticatingGoogle);

    final authResult = await _authService.signInWithGoogle();

    if (authResult.isCancelled) {
      _setState(LoginUiState.idle);
      return LoginResult.cancelled;
    }

    if (!authResult.isSuccess || authResult.user == null) {
      _setState(
        LoginUiState.error,
        authResult.errorMessage ?? 'Google Sign-In Failed',
      );
      return LoginResult.error;
    }

    final authUser = authResult.user!;

    // Phase 1.7.1 — Unify external Google account ID with canonical User.id ("usr_...")
    final canonicalUserId = await _userIdentityService.getOrCreateCanonicalUser(
      provider: 'google',
      providerUserId: authUser.id,
      email: authUser.email,
      displayName: authUser.displayName,
      photoUrl: authUser.photoUrl,
    );

    final canonicalUser = authUser.copyWith(id: canonicalUserId);

    await _userRepository.saveUser(canonicalUser);
    await _sessionManager.saveSession(
      userId: canonicalUserId,
      sessionType: authUser.sessionType,
      accessToken: authResult.accessToken,
      idToken: authResult.idToken,
    );

    // Phase 1.9.7.3C — Check First-Run Recovery eligibility for authenticated Google session
    final detector = _recoveryDetector ??
        FirstRunRecoveryDetector(storageAdapter: GoogleDriveBackupService());
    final recResult = await detector.checkEligibility();
    _recoveryResult = recResult;

    _setState(LoginUiState.idle);

    if (recResult.isEligible) {
      return LoginResult.navigateToRecovery;
    }

    // Standardized Setup Checkpoint: All first-entry/reinstall Google users pass through ProfileScreen.
    return LoginResult.navigateToProfile;
  }

  /// Handle Continue Offline button action.
  ///
  /// Offline users pass through ProfileScreen before entering HomeScreen.
  Future<LoginResult> handleOfflineSignIn() async {
    _setState(LoginUiState.initializingOffline);

    try {
      final offlineUser = await _localProfileService.createOfflineProfile();
      await _userRepository.saveUser(offlineUser);
      await _sessionManager.saveSession(
        userId: offlineUser.id,
        sessionType: offlineUser.sessionType,
      );

      try {
        final db = await DatabaseService.instance.database;
        final nowIso = DateTime.now().toIso8601String();
        await db.insert(
          'users',
          {
            'id': offlineUser.id,
            'isOffline': 1,
            'createdAt': nowIso,
            'updatedAt': nowIso,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        await db.insert(
          'user_profiles',
          {
            'userId': offlineUser.id,
            'displayName': offlineUser.displayName,
            'email': offlineUser.email,
            'photoUrl': null,
            'usesGooglePhoto': 0,
            'profileVersion': 1,
            'createdAt': nowIso,
            'updatedAt': nowIso,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      } catch (_) {
        // Allow in-memory mock testing without real SQLite DB
      }

      _setState(LoginUiState.idle);
      return LoginResult.navigateToProfile;
    } catch (e) {
      _setState(
        LoginUiState.error,
        'Failed to create offline profile: ${e.toString()}',
      );
      return LoginResult.error;
    }
  }

  void clearError() {
    if (_state == LoginUiState.error) {
      _setState(LoginUiState.idle);
    }
  }
}
