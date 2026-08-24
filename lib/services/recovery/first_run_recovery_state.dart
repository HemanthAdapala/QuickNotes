import '../backup/remote_backup_metadata.dart';
import 'local_data_detector.dart';
import 'recovery_completion_store.dart';

/// FirstRunRecoveryState — The deterministic lifecycle states of first-run recovery detection.
enum FirstRunRecoveryState {
  uninitialized,
  checking,
  noRecoveryRequired,
  eligibleEmptyLocal,
  eligibleConflictLocal,
  detectionFailed,
}

/// FirstRunRecoveryResult — Complete, provider-neutral representation of recovery detection outcome.
///
/// Supplies all information needed for the UI phase without requiring archive downloads or credential exposure.
class FirstRunRecoveryResult {
  final FirstRunRecoveryState state;
  final LocalDataSummary localSummary;
  final RemoteBackupMetadata? recommendedBackup;
  final List<RemoteBackupMetadata> eligibleBackups;
  final RecoveryCompletionStatus recoveryStatus;
  final String? failureReason;

  const FirstRunRecoveryResult({
    required this.state,
    this.localSummary = const LocalDataSummary.empty(),
    this.recommendedBackup,
    this.eligibleBackups = const [],
    this.recoveryStatus = RecoveryCompletionStatus.notCompleted,
    this.failureReason,
  });

  const FirstRunRecoveryResult.uninitialized()
      : state = FirstRunRecoveryState.uninitialized,
        localSummary = const LocalDataSummary.empty(),
        recommendedBackup = null,
        eligibleBackups = const [],
        recoveryStatus = RecoveryCompletionStatus.notCompleted,
        failureReason = null;

  const FirstRunRecoveryResult.checking()
      : state = FirstRunRecoveryState.checking,
        localSummary = const LocalDataSummary.empty(),
        recommendedBackup = null,
        eligibleBackups = const [],
        recoveryStatus = RecoveryCompletionStatus.notCompleted,
        failureReason = null;

  const FirstRunRecoveryResult.noRecoveryRequired({
    this.localSummary = const LocalDataSummary.empty(),
    this.recoveryStatus = RecoveryCompletionStatus.notCompleted,
  })  : state = FirstRunRecoveryState.noRecoveryRequired,
        recommendedBackup = null,
        eligibleBackups = const [],
        failureReason = null;

  const FirstRunRecoveryResult.eligibleEmptyLocal({
    required this.localSummary,
    required this.recommendedBackup,
    required this.eligibleBackups,
  })  : state = FirstRunRecoveryState.eligibleEmptyLocal,
        recoveryStatus = RecoveryCompletionStatus.notCompleted,
        failureReason = null;

  const FirstRunRecoveryResult.eligibleConflictLocal({
    required this.localSummary,
    required this.recommendedBackup,
    required this.eligibleBackups,
  })  : state = FirstRunRecoveryState.eligibleConflictLocal,
        recoveryStatus = RecoveryCompletionStatus.notCompleted,
        failureReason = null;

  const FirstRunRecoveryResult.detectionFailed({
    required this.failureReason,
    this.localSummary = const LocalDataSummary.empty(),
  })  : state = FirstRunRecoveryState.detectionFailed,
        recommendedBackup = null,
        eligibleBackups = const [],
        recoveryStatus = RecoveryCompletionStatus.notCompleted;

  bool get isEligible =>
      state == FirstRunRecoveryState.eligibleEmptyLocal ||
      state == FirstRunRecoveryState.eligibleConflictLocal;

  bool get isChecking => state == FirstRunRecoveryState.checking;
  bool get hasFailed => state == FirstRunRecoveryState.detectionFailed;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FirstRunRecoveryResult &&
          runtimeType == other.runtimeType &&
          state == other.state &&
          localSummary == other.localSummary &&
          recommendedBackup == other.recommendedBackup &&
          recoveryStatus == other.recoveryStatus &&
          failureReason == other.failureReason;

  @override
  int get hashCode =>
      state.hashCode ^
      localSummary.hashCode ^
      recommendedBackup.hashCode ^
      recoveryStatus.hashCode ^
      failureReason.hashCode;

  @override
  String toString() =>
      'FirstRunRecoveryResult(state: $state, localData: $localSummary, recommended: ${recommendedBackup?.backupId}, eligibleCount: ${eligibleBackups.length}, status: $recoveryStatus, failure: $failureReason)';
}
