import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session_state.dart';
import '../models/session_type.dart';

/// SessionManager — Centralized single source of truth for session state and app launch decision-making.
class SessionManager {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  final _secureStorage = const FlutterSecureStorage();

  static const String _keyOnboarding = 'has_completed_onboarding';
  static const String _keySessionType = 'session_type';
  static const String _keyActiveUserId = 'active_user_id';
  static const String _keyAccessToken = 'auth_access_token';
  static const String _keyIdToken = 'auth_id_token';

  bool _isInitialized = false;
  SharedPreferences? _prefs;

  Future<void> init() async {
    if (_isInitialized) return;
    _prefs = await SharedPreferences.getInstance();
    _isInitialized = true;
  }

  // ── 1. Onboarding Flag ──────────────────────────────────────────────────
  bool get hasCompletedOnboarding {
    return _prefs?.getBool(_keyOnboarding) ?? false;
  }

  Future<void> setOnboardingCompleted() async {
    await init();
    await _prefs?.setBool(_keyOnboarding, true);
    await _secureStorage.write(key: 'has_completed_onboarding', value: 'true');
  }

  // ── 2. Session Classification & Getters ─────────────────────────────────
  SessionType get activeSessionType {
    final val = _prefs?.getString(_keySessionType);
    return SessionTypeExtension.fromValue(val);
  }

  String? get activeUserId {
    return _prefs?.getString(_keyActiveUserId);
  }

  String get userId => activeUserId ?? '';

  String get provider => activeSessionType.toValue();

  bool get isLoggedIn {
    return activeUserId != null && activeUserId!.isNotEmpty;
  }

  bool get isAuthenticated {
    return isLoggedIn && activeSessionType != SessionType.offline;
  }

  bool get isOffline {
    return isLoggedIn && activeSessionType == SessionType.offline;
  }

  /// Single decision maker for how Quick Notes launches.
  SessionState get currentSessionState {
    if (!hasCompletedOnboarding) {
      return SessionState.firstLaunch;
    }
    if (!isLoggedIn) {
      return SessionState.noSession;
    }
    if (activeSessionType == SessionType.offline) {
      return SessionState.offline;
    }
    return SessionState.authenticated;
  }

  // ── 3. Save Session Metadata & Tokens ──────────────────────────────────
  Future<void> saveSession({
    required String userId,
    required SessionType sessionType,
    String? accessToken,
    String? idToken,
  }) async {
    await init();

    await _prefs?.setString(_keySessionType, sessionType.toValue());
    await _prefs?.setString(_keyActiveUserId, userId);

    if (accessToken != null) {
      await _secureStorage.write(key: _keyAccessToken, value: accessToken);
    }
    if (idToken != null) {
      await _secureStorage.write(key: _keyIdToken, value: idToken);
    }
  }

  // ── 4. Token Retrieval ─────────────────────────────────────────────────
  Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: _keyAccessToken);
  }

  Future<String?> getIdToken() async {
    return await _secureStorage.read(key: _keyIdToken);
  }

  // ── 5. Clear Session ───────────────────────────────────────────────────
  Future<void> clearSession() async {
    await init();
    await _prefs?.remove(_keySessionType);
    await _prefs?.remove(_keyActiveUserId);
    await _secureStorage.delete(key: _keyAccessToken);
    await _secureStorage.delete(key: _keyIdToken);
  }
}
