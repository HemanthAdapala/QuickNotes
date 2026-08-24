import 'package:uuid/uuid.dart';
import '../models/current_user.dart';
import '../models/session_type.dart';

/// LocalProfileService — Responsible for generating local offline user identities.
class LocalProfileService {
  static final LocalProfileService _instance = LocalProfileService._internal();
  factory LocalProfileService() => _instance;
  LocalProfileService._internal();

  final _uuid = const Uuid();

  /// Create a local offline user profile
  Future<CurrentUser> createOfflineProfile() async {
    final localId = 'usr_local_${_uuid.v4()}';
    return CurrentUser(
      id: localId,
      email: 'offline@local.quicknotes',
      displayName: 'Guest',
      photoUrl: null,
      sessionType: SessionType.offline,
      isOffline: true,
      createdAt: DateTime.now(),
    );
  }
}
