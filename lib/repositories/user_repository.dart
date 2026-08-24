import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/current_user.dart';
import '../models/session_type.dart';
import '../services/session_manager.dart';
import '../data/sqlite_profile_repository.dart';

/// UserRepository — Single source of truth for loading, creating,
/// updating, and restoring the active CurrentUser domain entity.
///
/// Also acts as the coordinator between authentication and profile status.
/// Call [hasCompletedProfile] to determine whether to route to ProfileScreen
/// or HomeScreen — without needing to import ProfileRepository directly.
class UserRepository {
  static final UserRepository _instance = UserRepository._internal();
  factory UserRepository() => _instance;
  UserRepository._internal();

  CurrentUser? _currentUser;
  CurrentUser? get currentUser => _currentUser;

  static const String _userPrefix = 'user_profile_';

  /// Save or update CurrentUser
  Future<void> saveUser(CurrentUser user) async {
    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_userPrefix${user.id}', jsonEncode(user.toJson()));
  }

  /// Load user profile by ID
  Future<CurrentUser?> getUserById(String id) async {
    if (_currentUser?.id == id) return _currentUser;

    final prefs = await SharedPreferences.getInstance();
    final rawJson = prefs.getString('$_userPrefix$id');
    if (rawJson != null) {
      try {
        final Map<String, dynamic> data = jsonDecode(rawJson);
        _currentUser = CurrentUser.fromJson(data);
        return _currentUser;
      } catch (_) {}
    }
    return null;
  }

  /// Restore active session CurrentUser using SessionManager
  Future<CurrentUser?> restoreActiveSession() async {
    final sessionManager = SessionManager();
    await sessionManager.init();

    if (!sessionManager.isLoggedIn) {
      _currentUser = null;
      return null;
    }

    final activeId = sessionManager.activeUserId;
    if (activeId == null) return null;

    final user = await getUserById(activeId);
    if (user != null) {
      _currentUser = user;
      return user;
    }

    // Fallback reconstruction if profile metadata key is missing
    final fallbackUser = CurrentUser(
      id: activeId,
      email: sessionManager.activeSessionType == SessionType.offline
          ? 'offline@local.quicknotes'
          : 'user@quicknotes.app',
      displayName: sessionManager.activeSessionType == SessionType.offline
          ? 'Guest'
          : 'QuickNotes User',
      sessionType: sessionManager.activeSessionType,
      isOffline: sessionManager.activeSessionType == SessionType.offline,
      createdAt: DateTime.now(),
    );

    await saveUser(fallbackUser);
    return fallbackUser;
  }

  /// Returns true if the active user has a completed Quick Notes profile.
  ///
  /// A profile is considered complete when a [UserProfile] record exists in
  /// [SqliteProfileRepository] for the current user's ID.
  ///
  /// Controllers (LoginController, SplashController) call this method and
  /// never import ProfileRepository or SqliteProfileRepository directly.
  Future<bool> hasCompletedProfile() async {
    final userId = _currentUser?.id;
    if (userId == null) return false;
    final profile = await SqliteProfileRepository().getProfileForUser(userId);
    return profile != null;
  }

  /// Clear active user in memory
  void clearActiveUser() {
    _currentUser = null;
  }
}
