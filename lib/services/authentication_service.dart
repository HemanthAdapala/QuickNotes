import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/current_user.dart';
import '../models/session_type.dart';

/// Categorization of authentication outcomes and failure modes.
enum AuthErrorType {
  none,
  cancelled,
  networkUnavailable,
  configurationError,
  accessDenied,
  playServicesError,
  unknown,
}

class AuthResult {
  final bool isSuccess;
  final CurrentUser? user;
  final String? accessToken;
  final String? idToken;
  final bool isCancelled;
  final String? errorMessage;
  final AuthErrorType errorType;
  final String? errorCode;
  final String? diagnosticDetails;

  const AuthResult({
    required this.isSuccess,
    this.user,
    this.accessToken,
    this.idToken,
    this.isCancelled = false,
    this.errorMessage,
    this.errorType = AuthErrorType.none,
    this.errorCode,
    this.diagnosticDetails,
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
      errorType: AuthErrorType.none,
    );
  }

  factory AuthResult.cancelled() {
    return const AuthResult(
      isSuccess: false,
      isCancelled: true,
      errorType: AuthErrorType.cancelled,
    );
  }

  factory AuthResult.failure(
    String errorMessage, {
    AuthErrorType errorType = AuthErrorType.unknown,
    String? errorCode,
    String? diagnosticDetails,
  }) {
    return AuthResult(
      isSuccess: false,
      errorMessage: errorMessage,
      errorType: errorType,
      errorCode: errorCode,
      diagnosticDetails: diagnosticDetails,
    );
  }
}

/// AuthenticationService — Single responsibility service for authenticating users.
/// Integrates native GoogleSignIn with graceful cancellation, privacy-safe diagnostics,
/// and decoupled scope authorization.
class AuthenticationService {
  static final AuthenticationService _instance =
      AuthenticationService._internal();
  factory AuthenticationService() => _instance;
  AuthenticationService._internal();

  /// Scopes required strictly for basic Google account identity.
  /// Decoupled from Google Drive authorization (which is requested on-demand).
  static const List<String> identityScopes = [
    'email',
    'profile',
  ];

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: identityScopes,
  );

  GoogleSignIn get googleSignIn => _googleSignIn;

  /// Authenticate user via Google Sign-In with robust, privacy-safe diagnostics.
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
    } on PlatformException catch (e) {
      debugPrint('[AuthenticationService] Google Sign-In PlatformException: code=${e.code}, message=${e.message}');
      return mapPlatformExceptionToAuthResult(e);
    } catch (e) {
      debugPrint('[AuthenticationService] Google Sign-In unexpected error: $e');
      return AuthResult.failure(
        'Google Sign-In failed unexpectedly. Please try again.',
        errorType: AuthErrorType.unknown,
        errorCode: 'unexpected_error',
        diagnosticDetails: e.toString(),
      );
    }
  }

  /// Maps native PlatformExceptions to structured, privacy-safe, and actionable results.
  /// Static pure function with zero instance dependencies.
  static AuthResult mapPlatformExceptionToAuthResult(PlatformException e) {
    final code = e.code.toLowerCase();
    final message = e.message ?? '';

    // 1. User Cancellation
    // Native status code 12501 (SIGN_IN_CANCELLED) or code 'sign_in_canceled' or status 16
    if (code.contains('cancel') ||
        message.contains('12501') ||
        message.contains('SIGN_IN_CANCELLED') ||
        message.contains('16:')) {
      return AuthResult.cancelled();
    }

    // 2. Network / Connectivity Error
    // Native status code 7 (NETWORK_ERROR) or code 'network_error'
    if (code.contains('network') ||
        message.contains('7:') ||
        message.contains('NETWORK_ERROR') ||
        message.contains('SocketException')) {
      return AuthResult.failure(
        'Network error. Please check your internet connection and try again.',
        errorType: AuthErrorType.networkUnavailable,
        errorCode: '7',
        diagnosticDetails: 'NETWORK_ERROR',
      );
    }

    // 3. Configuration / Developer Error (SHA-1 / OAuth Client mismatch)
    // Native status code 10 (DEVELOPER_ERROR)
    if (message.contains('10:') ||
        message.contains('DEVELOPER_ERROR') ||
        code.contains('developer_error')) {
      return AuthResult.failure(
        'Google Sign-In configuration error [code 10]. Please ensure Google Play App Signing SHA-1 is registered.',
        errorType: AuthErrorType.configurationError,
        errorCode: '10',
        diagnosticDetails: 'DEVELOPER_ERROR: SHA-1 or OAuth client mismatch',
      );
    }

    // 4. Access Denied / Scope / Restricted Test User
    // Native status code 12500 (SIGN_IN_FAILED) or access_denied
    if (message.contains('12500') ||
        message.contains('access_denied') ||
        message.contains('SIGN_IN_FAILED')) {
      return AuthResult.failure(
        'Google account sign-in failed [code 12500]. Please verify account permissions and try again.',
        errorType: AuthErrorType.accessDenied,
        errorCode: '12500',
        diagnosticDetails: 'SIGN_IN_FAILED: Access denied or restricted test user',
      );
    }

    // 5. Google Play Services missing / disabled / outdated
    if (message.contains('SERVICE_MISSING') ||
        message.contains('SERVICE_VERSION_UPDATE_REQUIRED') ||
        message.contains('SERVICE_DISABLED')) {
      return AuthResult.failure(
        'Google Play Services is unavailable or requires updating.',
        errorType: AuthErrorType.playServicesError,
        errorCode: 'play_services_error',
        diagnosticDetails: message,
      );
    }

    // 6. Generic failure with sanitized status code
    final extractedCode = _extractStatusCode(message) ?? code;
    return AuthResult.failure(
      'Google Sign-In failed [$extractedCode]. Please try again.',
      errorType: AuthErrorType.unknown,
      errorCode: extractedCode,
      diagnosticDetails: message.isNotEmpty ? message : code,
    );
  }

  /// Extracts numeric status codes like 'ApiException: 10:' or 'status code: 12500'
  static String? _extractStatusCode(String message) {
    final match = RegExp(r'ApiException:\s*(\d+)', caseSensitive: false).firstMatch(message) ??
        RegExp(r'status(?:Code)?[:\s]+(\d+)', caseSensitive: false).firstMatch(message);
    return match?.group(1);
  }
}
