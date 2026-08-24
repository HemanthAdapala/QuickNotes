import 'package:shared_preferences/shared_preferences.dart';

/// RecoveryCompletionStatus — Represents the persistent first-run recovery status for an identity.
enum RecoveryCompletionStatus {
  notCompleted,
  restored,
  skipped,
  keptLocalData,
}

extension RecoveryCompletionStatusExtension on RecoveryCompletionStatus {
  String toValue() {
    switch (this) {
      case RecoveryCompletionStatus.notCompleted:
        return 'not_completed';
      case RecoveryCompletionStatus.restored:
        return 'restored';
      case RecoveryCompletionStatus.skipped:
        return 'skipped';
      case RecoveryCompletionStatus.keptLocalData:
        return 'kept_local_data';
    }
  }

  static RecoveryCompletionStatus fromValue(String? value) {
    switch (value) {
      case 'restored':
        return RecoveryCompletionStatus.restored;
      case 'skipped':
        return RecoveryCompletionStatus.skipped;
      case 'kept_local_data':
        return RecoveryCompletionStatus.keptLocalData;
      case 'not_completed':
      default:
        return RecoveryCompletionStatus.notCompleted;
    }
  }
}

/// RecoveryCompletionStore — Identity-scoped persistence for First-Run Recovery completion status.
///
/// Ensures Account A's recovery decisions never suppress or affect Account B on the same device.
/// Stores `recovery_status_<providerUserIdHash>` in SharedPreferences.
class RecoveryCompletionStore {
  final SharedPreferences? _customPrefs;

  static const String _keyPrefix = 'recovery_status_';

  RecoveryCompletionStore({SharedPreferences? prefs}) : _customPrefs = prefs;

  Future<SharedPreferences> _getPrefs() async {
    if (_customPrefs != null) return _customPrefs!;
    return await SharedPreferences.getInstance();
  }

  String _buildKey(String providerUserIdHash) {
    return '$_keyPrefix$providerUserIdHash';
  }

  /// Retrieves the recorded recovery completion status for the given identity hash.
  ///
  /// Returns [RecoveryCompletionStatus.notCompleted] if no prior status exists or hash is empty.
  Future<RecoveryCompletionStatus> getStatus(String providerUserIdHash) async {
    if (providerUserIdHash.trim().isEmpty) {
      return RecoveryCompletionStatus.notCompleted;
    }

    final prefs = await _getPrefs();
    final rawValue = prefs.getString(_buildKey(providerUserIdHash));
    return RecoveryCompletionStatusExtension.fromValue(rawValue);
  }

  /// Persists a recovery completion decision for the specified identity hash.
  Future<void> setStatus(
    String providerUserIdHash,
    RecoveryCompletionStatus status,
  ) async {
    if (providerUserIdHash.trim().isEmpty) return;

    final prefs = await _getPrefs();
    if (status == RecoveryCompletionStatus.notCompleted) {
      await prefs.remove(_buildKey(providerUserIdHash));
    } else {
      await prefs.setString(_buildKey(providerUserIdHash), status.toValue());
    }
  }

  /// Clears the recorded recovery completion status for the specified identity hash.
  Future<void> clearStatus(String providerUserIdHash) async {
    if (providerUserIdHash.trim().isEmpty) return;

    final prefs = await _getPrefs();
    await prefs.remove(_buildKey(providerUserIdHash));
  }
}
