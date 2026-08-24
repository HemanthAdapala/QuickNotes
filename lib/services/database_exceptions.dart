/// Database Exceptions for Quick Notes.
///
/// Provides a typed exception hierarchy for DatabaseService operations,
/// transaction failures, and integrity diagnostics while allowing raw
/// SQLite [DatabaseException]s to throw naturally when appropriate.

abstract class DatabaseServiceException implements Exception {
  final String message;
  final Object? cause;

  const DatabaseServiceException(this.message, [this.cause]);

  @override
  String toString() {
    if (cause != null) {
      return '$runtimeType: $message (Cause: $cause)';
    }
    return '$runtimeType: $message';
  }
}

/// Thrown when a database transaction fails or cannot be initiated.
class DatabaseTransactionException extends DatabaseServiceException {
  const DatabaseTransactionException(super.message, [super.cause]);
}

/// Thrown when database migration encounters an unrecoverable failure.
class DatabaseMigrationException extends DatabaseServiceException {
  const DatabaseMigrationException(super.message, [super.cause]);
}

/// Thrown when database integrity checks report corruption or structural defects.
class DatabaseIntegrityException extends DatabaseServiceException {
  final List<String> errors;

  const DatabaseIntegrityException(
    super.message,
    this.errors, [
    super.cause,
  ]);
}

/// Thrown when a repository or domain operation lacks a valid canonical active user context.
class OwnershipException implements Exception {
  final String message;
  final Object? cause;

  const OwnershipException(
      [this.message =
          'No active canonical user exists for this repository operation.',
      this.cause]);

  @override
  String toString() {
    if (cause != null) {
      return 'OwnershipException: $message (Cause: $cause)';
    }
    return 'OwnershipException: $message';
  }
}
