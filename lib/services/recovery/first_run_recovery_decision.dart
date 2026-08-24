/// RecoveryUserDecision — Enumerates possible user decisions in the first-run recovery flow.
///
/// Designed to separate the detection state machine from explicit user intent.
enum RecoveryUserDecision {
  /// User chose to download and execute an atomic restore of the recommended backup.
  restoreRecommendedBackup,

  /// User chose to keep existing local device data and bypass cloud restore.
  keepLocalData,

  /// User chose to start fresh and skip cloud restore.
  skipAndStartFresh,

  /// User requested retrying cloud backup detection after a transient failure.
  retryDetection,

  /// User postponed decision (e.g. continuing offline without writing persistent completion).
  postpone,
}
