import 'package:flutter/material.dart';
import '../models/current_user.dart';
import '../models/identity_link_result.dart';
import '../models/session_type.dart';
import '../repositories/user_repository.dart';
import '../services/authentication_service.dart';
import '../services/backup/google_drive_backup_service.dart';
import '../services/recovery/first_run_recovery_detector.dart';
import '../services/recovery/first_run_recovery_state.dart';
import '../services/session_manager.dart';
import '../services/user_identity_service.dart';

/// Account UI States
enum AccountUiState {
  idle,
  signingIn,
  conflict,
  error,
}

/// Navigation and business action outcomes for Account linking
enum AccountLinkAction {
  success,
  navigateToRecovery,
  conflict,
  cancelled,
  error,
}

/// Result returned to the Account UI / navigation layer
class AccountLinkResult {
  final AccountLinkAction action;
  final FirstRunRecoveryResult? recoveryResult;
  final String? conflictingUserId;
  final String? googleEmail;
  final String? errorMessage;

  const AccountLinkResult({
    required this.action,
    this.recoveryResult,
    this.conflictingUserId,
    this.googleEmail,
    this.errorMessage,
  });

  bool get isSuccess =>
      action == AccountLinkAction.success ||
      action == AccountLinkAction.navigateToRecovery;
  bool get isConflict => action == AccountLinkAction.conflict;
  bool get isCancelled => action == AccountLinkAction.cancelled;
  bool get isError => action == AccountLinkAction.error;

  factory AccountLinkResult.success() =>
      const AccountLinkResult(action: AccountLinkAction.success);

  factory AccountLinkResult.navigateToRecovery(
          FirstRunRecoveryResult recoveryResult) =>
      AccountLinkResult(
        action: AccountLinkAction.navigateToRecovery,
        recoveryResult: recoveryResult,
      );

  factory AccountLinkResult.conflict({
    required String conflictingUserId,
    String? googleEmail,
  }) =>
      AccountLinkResult(
        action: AccountLinkAction.conflict,
        conflictingUserId: conflictingUserId,
        googleEmail: googleEmail,
        errorMessage:
            'This Google account is already linked to another Quick Notes account.',
      );

  factory AccountLinkResult.cancelled() =>
      const AccountLinkResult(action: AccountLinkAction.cancelled);

  factory AccountLinkResult.error(String message) =>
      AccountLinkResult(action: AccountLinkAction.error, errorMessage: message);
}

/// AccountController — Orchestrates offline-to-Google account linking, conflict handling,
/// and post-link recovery eligibility checks for Quick Notes.
class AccountController extends ChangeNotifier {
  AccountUiState _state = AccountUiState.idle;
  AccountUiState get state => _state;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _conflictingUserId;
  String? get conflictingUserId => _conflictingUserId;

  String? _conflictEmail;
  String? get conflictEmail => _conflictEmail;

  FirstRunRecoveryResult? _recoveryResult;
  FirstRunRecoveryResult? get recoveryResult => _recoveryResult;

  final AuthenticationService _authService;
  final UserIdentityService _userIdentityService;
  final SessionManager _sessionManager;
  final UserRepository _userRepository;
  final FirstRunRecoveryDetector? _recoveryDetector;

  AccountController({
    AuthenticationService? authService,
    UserIdentityService? userIdentityService,
    SessionManager? sessionManager,
    UserRepository? userRepository,
    FirstRunRecoveryDetector? recoveryDetector,
  })  : _authService = authService ?? AuthenticationService(),
        _userIdentityService = userIdentityService ?? UserIdentityService(),
        _sessionManager = sessionManager ?? SessionManager(),
        _userRepository = userRepository ?? UserRepository(),
        _recoveryDetector = recoveryDetector;

  bool get isOffline => _sessionManager.isOffline;
  bool get isAuthenticated => _sessionManager.isAuthenticated;
  String get activeUserId => _sessionManager.activeUserId ?? '';
  CurrentUser? get currentUser => _userRepository.currentUser;

  String get displayName =>
      _userRepository.currentUser?.displayName ??
      (isOffline ? 'Offline User' : 'QuickNotes User');

  String get email =>
      _userRepository.currentUser?.email ??
      (isOffline ? 'Not connected' : '');

  String? get photoUrl => _userRepository.currentUser?.photoUrl;

  void _setState(AccountUiState newState, {String? error}) {
    _state = newState;
    _errorMessage = error;
    notifyListeners();
  }

  void resetError() {
    if (_state == AccountUiState.error) {
      _setState(AccountUiState.idle);
    }
  }

  void cancelConflict() {
    _conflictingUserId = null;
    _conflictEmail = null;
    _setState(AccountUiState.idle);
  }

  Future<bool> switchAccountToConflictingUser({
    String? accessToken,
    String? idToken,
  }) async {
    final targetUserId = _conflictingUserId;
    if (targetUserId == null || targetUserId.isEmpty) {
      return false;
    }

    await _sessionManager.saveSession(
      userId: targetUserId,
      sessionType: SessionType.google,
      accessToken: accessToken,
      idToken: idToken,
    );

    await _userRepository.getUserById(targetUserId);

    _conflictingUserId = null;
    _conflictEmail = null;
    _setState(AccountUiState.idle);
    return true;
  }

  Future<AccountLinkResult> signInWithGoogle() async {
    // STEP 1: Guard against concurrent operations (double-tap protection)
    if (_state == AccountUiState.signingIn) {
      return AccountLinkResult.cancelled();
    }

    _setState(AccountUiState.signingIn);

    try {
      // STEP 2: Call AuthenticationService.signInWithGoogle()
      final authResult = await _authService.signInWithGoogle();

      // STEP 3: Handle authentication result
      if (authResult.isCancelled) {
        _setState(AccountUiState.idle);
        return AccountLinkResult.cancelled();
      }

      if (!authResult.isSuccess || authResult.user == null) {
        final error = _sanitizeErrorMessage(
            authResult.errorMessage ?? 'Google Sign-In failed');
        _setState(AccountUiState.error, error: error);
        return AccountLinkResult.error(error);
      }

      final authUser = authResult.user!;
      final activeUserId = _sessionManager.activeUserId ?? _userRepository.currentUser?.id;

      if (activeUserId == null || activeUserId.isEmpty) {
        const error = 'No active user session found to link Google account.';
        _setState(AccountUiState.error, error: error);
        return AccountLinkResult.error(error);
      }

      // STEP 4: Call UserIdentityService.linkGoogleIdentityToActiveUser
      final linkResult = await _userIdentityService.linkGoogleIdentityToActiveUser(
        activeUserId: activeUserId,
        googleId: authUser.id,
        email: authUser.email,
        displayName: authUser.displayName,
        photoUrl: authUser.photoUrl,
      );

      switch (linkResult.status) {
        case IdentityLinkStatus.linked:
        case IdentityLinkStatus.alreadyLinked:
          // 1. Keep canonical user ID unchanged (activeUserId)
          // 2. Update authenticated session to Google
          await _sessionManager.saveSession(
            userId: activeUserId,
            sessionType: SessionType.google,
            accessToken: authResult.accessToken,
            idToken: authResult.idToken,
          );

          // 3. Update current UserRepository profile state
          final updatedCurrentUser = CurrentUser(
            id: activeUserId,
            email: linkResult.profile?.email ?? authUser.email,
            displayName: linkResult.profile?.displayName ?? authUser.displayName,
            photoUrl: linkResult.profile?.photoUrl ?? authUser.photoUrl,
            sessionType: SessionType.google,
            isOffline: false,
            createdAt: _userRepository.currentUser?.createdAt ?? DateTime.now(),
          );
          await _userRepository.saveUser(updatedCurrentUser);

          // 4. Check First-Run Recovery eligibility
          try {
            final detector = _recoveryDetector ??
                FirstRunRecoveryDetector(storageAdapter: GoogleDriveBackupService());
            final recResult = await detector.checkEligibility();
            _recoveryResult = recResult;

            _setState(AccountUiState.idle);

            if (recResult.isEligible) {
              return AccountLinkResult.navigateToRecovery(recResult);
            }
            return AccountLinkResult.success();
          } catch (_) {
            // Fail-safe continuation: If recovery detector fails, do not trap user
            _setState(AccountUiState.idle);
            return AccountLinkResult.success();
          }

        case IdentityLinkStatus.conflict:
          _conflictingUserId = linkResult.conflictingUserId;
          _conflictEmail = authUser.email;
          _setState(AccountUiState.conflict);
          return AccountLinkResult.conflict(
            conflictingUserId: linkResult.conflictingUserId ?? '',
            googleEmail: authUser.email,
          );

        case IdentityLinkStatus.userNotFound:
          const notFoundErr = 'Active user was not found. Please restart the app.';
          _setState(AccountUiState.error, error: notFoundErr);
          return AccountLinkResult.error(notFoundErr);

        case IdentityLinkStatus.alreadyLinkedToDifferentIdentity:
          const diffErr = 'Account is already linked to a different Google account.';
          _setState(AccountUiState.error, error: diffErr);
          return AccountLinkResult.error(diffErr);

        case IdentityLinkStatus.failure:
          final failErr = _sanitizeErrorMessage(
              linkResult.errorMessage ?? 'Identity linking failed');
          _setState(AccountUiState.error, error: failErr);
          return AccountLinkResult.error(failErr);
      }
    } catch (e) {
      final error = _sanitizeErrorMessage('Unexpected error: ${e.toString()}');
      _setState(AccountUiState.error, error: error);
      return AccountLinkResult.error(error);
    }
  }

  static String _sanitizeErrorMessage(String rawMessage) {
    if (rawMessage.contains('Exception:')) {
      rawMessage = rawMessage.replaceFirst('Exception:', '').trim();
    }
    if (rawMessage.contains('/') ||
        rawMessage.contains('\\') ||
        rawMessage.contains('.db')) {
      return 'A storage or configuration error occurred. Please try again.';
    }
    if (rawMessage.toLowerCase().contains('token') ||
        rawMessage.toLowerCase().contains('bearer') ||
        rawMessage.toLowerCase().contains('secret') ||
        rawMessage.toLowerCase().contains('credential')) {
      return 'Authentication service encountered an error. Please try again.';
    }
    return rawMessage;
  }
}
