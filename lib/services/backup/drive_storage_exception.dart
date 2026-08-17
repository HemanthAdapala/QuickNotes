/// Categories of remote storage errors.
enum DriveStorageErrorType {
  unauthenticated,
  networkUnavailable,
  insufficientStorage,
  backupNotFound,
  quotaExceeded,
  permissionDenied,
  uploadFailed,
  downloadFailed,
}

/// DriveStorageException — Provider-neutral exception thrown by remote storage transport adapters.
///
/// Ensures strict privacy: OAuth tokens, credentials, and sensitive private user data
/// are NEVER exposed in exception string outputs or diagnostic logs.
class DriveStorageException implements Exception {
  final DriveStorageErrorType type;
  final String message;
  final Object? cause;

  const DriveStorageException({
    required this.type,
    required this.message,
    this.cause,
  });

  @override
  String toString() => 'DriveStorageException($type): $message';
}
