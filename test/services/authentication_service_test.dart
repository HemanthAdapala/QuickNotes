import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/models/current_user.dart';
import 'package:quick_notes/models/session_type.dart';
import 'package:quick_notes/services/authentication_service.dart';

void main() {
  group('AuthenticationService — Scope Decoupling & Architecture', () {
    test('1. Identity scopes strictly contain email and profile only', () {
      expect(AuthenticationService.identityScopes, contains('email'));
      expect(AuthenticationService.identityScopes, contains('profile'));
      expect(
        AuthenticationService.identityScopes,
        isNot(contains('https://www.googleapis.com/auth/drive.file')),
        reason: 'Basic Google Sign-In must never request Google Drive scope upon login',
      );
      expect(AuthenticationService.identityScopes.length, equals(2));
    });

    test('2. Singleton instance returns consistent GoogleSignIn instance', () {
      final serviceA = AuthenticationService();
      final serviceB = AuthenticationService();
      expect(identical(serviceA, serviceB), isTrue);
      expect(identical(serviceA.googleSignIn, serviceB.googleSignIn), isTrue);
    });
  });

  group('AuthenticationService — Exception Mapping & Privacy Diagnostics', () {
    test('3. Maps user cancellation (code: sign_in_canceled) to AuthResult.cancelled', () {
      final exception = PlatformException(
        code: 'sign_in_canceled',
        message: 'Sign-in was cancelled by the user.',
      );

      final result = AuthenticationService.mapPlatformExceptionToAuthResult(exception);
      expect(result.isSuccess, isFalse);
      expect(result.isCancelled, isTrue);
      expect(result.errorType, equals(AuthErrorType.cancelled));
      expect(result.errorMessage, isNull);
    });

    test('4. Maps native status code 12501 (SIGN_IN_CANCELLED) to AuthResult.cancelled', () {
      final exception = PlatformException(
        code: 'sign_in_failed',
        message: 'com.google.android.gms.common.api.ApiException: 12501: ',
      );

      final result = AuthenticationService.mapPlatformExceptionToAuthResult(exception);
      expect(result.isSuccess, isFalse);
      expect(result.isCancelled, isTrue);
      expect(result.errorType, equals(AuthErrorType.cancelled));
    });

    test('5. Maps status code 16 (CANCELED) to AuthResult.cancelled', () {
      final exception = PlatformException(
        code: 'sign_in_failed',
        message: 'com.google.android.gms.common.api.ApiException: 16: ',
      );

      final result = AuthenticationService.mapPlatformExceptionToAuthResult(exception);
      expect(result.isSuccess, isFalse);
      expect(result.isCancelled, isTrue);
    });

    test('6. Maps network failure (code: network_error or status code 7) to networkUnavailable', () {
      final exception = PlatformException(
        code: 'network_error',
        message: 'com.google.android.gms.common.api.ApiException: 7: ',
      );

      final result = AuthenticationService.mapPlatformExceptionToAuthResult(exception);
      expect(result.isSuccess, isFalse);
      expect(result.isCancelled, isFalse);
      expect(result.errorType, equals(AuthErrorType.networkUnavailable));
      expect(result.errorCode, equals('7'));
      expect(result.errorMessage, contains('Network error'));
      expect(result.errorMessage, contains('connection'));
    });

    test('7. Maps configuration error (status code 10 / DEVELOPER_ERROR) to configurationError', () {
      final exception = PlatformException(
        code: 'sign_in_failed',
        message: 'com.google.android.gms.common.api.ApiException: 10: ',
      );

      final result = AuthenticationService.mapPlatformExceptionToAuthResult(exception);
      expect(result.isSuccess, isFalse);
      expect(result.isCancelled, isFalse);
      expect(result.errorType, equals(AuthErrorType.configurationError));
      expect(result.errorCode, equals('10'));
      expect(result.errorMessage, contains('configuration error [code 10]'));
      expect(result.errorMessage, contains('Google Play App Signing'));
      expect(result.diagnosticDetails, contains('DEVELOPER_ERROR'));
    });

    test('8. Maps access denied (status code 12500) to accessDenied', () {
      final exception = PlatformException(
        code: 'sign_in_failed',
        message: 'com.google.android.gms.common.api.ApiException: 12500: ',
      );

      final result = AuthenticationService.mapPlatformExceptionToAuthResult(exception);
      expect(result.isSuccess, isFalse);
      expect(result.isCancelled, isFalse);
      expect(result.errorType, equals(AuthErrorType.accessDenied));
      expect(result.errorCode, equals('12500'));
      expect(result.errorMessage, contains('[code 12500]'));
      expect(result.diagnosticDetails, contains('SIGN_IN_FAILED'));
    });

    test('9. Maps Google Play Services missing/outdated to playServicesError', () {
      final exception = PlatformException(
        code: 'play_services_error',
        message: 'SERVICE_VERSION_UPDATE_REQUIRED',
      );

      final result = AuthenticationService.mapPlatformExceptionToAuthResult(exception);
      expect(result.isSuccess, isFalse);
      expect(result.errorType, equals(AuthErrorType.playServicesError));
      expect(result.errorMessage, contains('Google Play Services'));
    });

    test('10. Maps unrecognized exception to unknown with extracted status code', () {
      final exception = PlatformException(
        code: 'sign_in_failed',
        message: 'com.google.android.gms.common.api.ApiException: 8: Internal error',
      );

      final result = AuthenticationService.mapPlatformExceptionToAuthResult(exception);
      expect(result.isSuccess, isFalse);
      expect(result.errorType, equals(AuthErrorType.unknown));
      expect(result.errorCode, equals('8'));
      expect(result.errorMessage, contains('[8]'));
    });
  });

  group('AuthResult Model Tests', () {
    test('11. AuthResult.success populates user and tokens correctly', () {
      final user = CurrentUser(
        id: 'usr_test_123',
        email: 'tester@example.com',
        displayName: 'Test User',
        sessionType: SessionType.google,
        isOffline: false,
        createdAt: DateTime.now(),
      );

      final result = AuthResult.success(
        user: user,
        accessToken: 'mock_access_token',
        idToken: 'mock_id_token',
      );

      expect(result.isSuccess, isTrue);
      expect(result.isCancelled, isFalse);
      expect(result.user, equals(user));
      expect(result.accessToken, equals('mock_access_token'));
      expect(result.idToken, equals('mock_id_token'));
      expect(result.errorType, equals(AuthErrorType.none));
      expect(result.errorMessage, isNull);
    });

    test('12. AuthResult.cancelled sets isCancelled and no error message', () {
      final result = AuthResult.cancelled();
      expect(result.isSuccess, isFalse);
      expect(result.isCancelled, isTrue);
      expect(result.errorType, equals(AuthErrorType.cancelled));
      expect(result.errorMessage, isNull);
    });

    test('13. AuthResult.failure sets errorType, errorCode, and diagnostic details', () {
      final result = AuthResult.failure(
        'Custom error occurred',
        errorType: AuthErrorType.configurationError,
        errorCode: '10',
        diagnosticDetails: 'Details here',
      );

      expect(result.isSuccess, isFalse);
      expect(result.isCancelled, isFalse);
      expect(result.errorMessage, equals('Custom error occurred'));
      expect(result.errorType, equals(AuthErrorType.configurationError));
      expect(result.errorCode, equals('10'));
      expect(result.diagnosticDetails, equals('Details here'));
    });
  });
}
