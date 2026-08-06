import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/current_user.dart';
import '../models/session_type.dart';

class AuthResult {
  final bool isSuccess;
  final CurrentUser? user;
  final String? accessToken;
  final String? idToken;
  final bool isCancelled;
  final String? errorMessage;

  const AuthResult({
    required this.isSuccess,
    this.user,
    this.accessToken,
    this.idToken,
    this.isCancelled = false,
    this.errorMessage,
  });

  factory AuthResult.success({
    required CurrentUser user,
    String? accessToken,
    String? idToken,
  }) {
    return AuthResult(
      isSuccess: true,
      user: user,
      accessToken: accessToken,
      idToken: idToken,
    );
  }

  factory AuthResult.cancelled() {
    return const AuthResult(
      isSuccess: false,
      isCancelled: true,
    );
  }

  factory AuthResult.failure(String errorMessage) {
    return AuthResult(
      isSuccess: false,
      errorMessage: errorMessage,
    );
  }
}

/// AuthenticationService — Single responsibility service for authenticating users.
/// Integrates native GoogleSignIn with graceful cancellation & error handling.
class AuthenticationService {
  static final AuthenticationService _instance = AuthenticationService._internal();
  factory AuthenticationService() => _instance;
  AuthenticationService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  /// Authenticate user via Google Sign-In
  Future<AuthResult> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();

      if (account == null) {
        // User cancelled sign-in or dismissed account picker
        return AuthResult.cancelled();
      }

      final authentication = await account.authentication;
      final authenticatedUser = CurrentUser(
        id: account.id,
        email: account.email,
        displayName: account.displayName ?? 'Google User',
        photoUrl: account.photoUrl,
        sessionType: SessionType.google,
        isOffline: false,
        createdAt: DateTime.now(),
      );

      return AuthResult.success(
        user: authenticatedUser,
        accessToken: authentication.accessToken,
        idToken: authentication.idToken,
      );
    } catch (e) {
      return AuthResult.failure(
        'Google Sign-In failed. Please check your connection and try again.',
      );
    }
  }
}
