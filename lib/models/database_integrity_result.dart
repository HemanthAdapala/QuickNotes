/// Encapsulates the health status and diagnostics of a SQLite database integrity check.
class DatabaseIntegrityResult {
  /// True if SQLite PRAGMA integrity_check returned 'ok' without errors.
  final bool isHealthy;

  /// List of raw diagnostic strings returned by SQLite PRAGMA integrity_check.
  final List<String> errors;

  const DatabaseIntegrityResult({
    required this.isHealthy,
    required this.errors,
  });

  factory DatabaseIntegrityResult.healthy() {
    return const DatabaseIntegrityResult(
      isHealthy: true,
      errors: [],
    );
  }

  factory DatabaseIntegrityResult.unhealthy(List<String> errors) {
    return DatabaseIntegrityResult(
      isHealthy: false,
      errors: List.unmodifiable(errors),
    );
  }

  @override
  String toString() {
    return 'DatabaseIntegrityResult(isHealthy: $isHealthy, errors: $errors)';
  }
}
