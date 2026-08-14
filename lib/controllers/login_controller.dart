import 'package:flutter/material.dart';
import '../repositories/user_repository.dart';
import '../services/authentication_service.dart';
import '../services/local_profile_service.dart';
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

  final _authService = AuthenticationService();
  final _localProfileService = LocalProfileService();
  final _userRepository = UserRepository();
  final _sessionManager = SessionManager();
  final _userIdentityService = UserIdentityService();

  void _setState(LoginUiState newState, [String? error]) {
    _state = newState;
    _errorMessage = error;
    notifyListeners();
  }

  /// Handle Google Sign-In button action.
  ///
  /// Returns a [LoginResult] enum — never navigates directly.
  /// - [LoginResult.navigateToProfile] → first-time Google user, no profile yet.
  /// - [LoginResult.navigateToHome] → returning Google user with existing profile.
  /// - [LoginResult.cancelled] → user dismissed the account picker.
  /// - [LoginResult.error] → authentication failed.
  Future<LoginResult> handleGoogleSignIn() async {
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

    _setState(LoginUiState.idle);

    // Ask UserRepository whether a profile exists.
    // LoginController never imports ProfileRepository directly.
    final hasProfile = await _userRepository.hasCompletedProfile();
    return hasProfile ? LoginResult.navigateToHome : LoginResult.navigateToProfile;
  }

  /// Handle Continue Offline button action.
  ///
  /// Offline users always go directly to HomeScreen — no profile setup required.
  Future<LoginResult> handleOfflineSignIn() async {
    _setState(LoginUiState.initializingOffline);

    try {
      final offlineUser = await _localProfileService.createOfflineProfile();
      await _userRepository.saveUser(offlineUser);
      await _sessionManager.saveSession(
        userId: offlineUser.id,
        sessionType: offlineUser.sessionType,
      );

      _setState(LoginUiState.idle);
      return LoginResult.navigateToHome;
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
