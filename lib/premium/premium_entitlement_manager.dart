import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'premium_entitlement.dart';

/// PremiumEntitlementManager — Authoritative reactive state manager for Quick Notes
/// Premium entitlement state, cache persistence, and future purchase synchronization.
///
/// Responsibilities:
/// - Holds the current in-memory [PremiumEntitlement] (authoritative store entitlement)
/// - Holds the development-only [PremiumTestMode] debug override
/// - Exposes [effectiveEntitlement] for consumption by feature gates
/// - Initializes / hydrates cached entitlement state from secure storage
/// - Notifies reactive listeners when entitlement state changes
/// - Persists verified entitlement updates to the secure local cache
/// - Provides clean invalidation and cache-clearing mechanisms
///
/// Security Boundary:
/// Local cached entitlement is treated as **previously verified cache**, not
/// independent or unforgeable proof of purchase. Phase P4 will provide online
/// platform store re-verification on top of this foundation.
/// In release mode, debug overrides are strictly ignored and never hydrated.
class PremiumEntitlementManager extends ChangeNotifier {
  // ── Storage Keys ───────────────────────────────────────────────────────────
  static const String keyCachedEntitlement = 'premium_cached_entitlement';
  static const String keyDebugTestMode = 'debug_premium_test_mode';

  // ── Dependencies ───────────────────────────────────────────────────────────
  final FlutterSecureStorage _secureStorage;
  SharedPreferences? _prefs;
  final bool _isDebug;

  // ── State ──────────────────────────────────────────────────────────────────
  PremiumEntitlement _currentEntitlement = const PremiumEntitlement.none();
  PremiumTestMode _debugTestMode = PremiumTestMode.system;
  bool _isInitialized = false;

  PremiumEntitlementManager({
    FlutterSecureStorage? secureStorage,
    SharedPreferences? prefs,
    bool? isDebug,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _prefs = prefs,
        _isDebug = isDebug ?? kDebugMode;

  // ── Getters ────────────────────────────────────────────────────────────────
  /// The authoritative store-derived entitlement state of the application.
  PremiumEntitlement get authoritativeEntitlement => _currentEntitlement;

  /// Backwards-compatible alias for [authoritativeEntitlement].
  PremiumEntitlement get currentEntitlement => _currentEntitlement;

  /// The active debug test mode override (development only).
  PremiumTestMode get debugTestMode => _debugTestMode;

  /// The effective entitlement consumed by feature gates.
  ///
  /// In debug mode:
  /// - [PremiumTestMode.system]: returns [_currentEntitlement] (authoritative).
  /// - [PremiumTestMode.free]: returns [PremiumEntitlement.none()].
  /// - [PremiumTestMode.premium]: returns a simulated active entitlement with [StoreSource.debug].
  ///
  /// In release mode:
  /// - Always returns [_currentEntitlement] regardless of any override state.
  PremiumEntitlement get effectiveEntitlement {
    if (_isDebug) {
      switch (_debugTestMode) {
        case PremiumTestMode.free:
          return const PremiumEntitlement.none();
        case PremiumTestMode.premium:
          return const PremiumEntitlement(
            status: EntitlementStatus.active,
            productId: 'debug_simulated_premium',
            storeSource: StoreSource.debug,
          );
        case PremiumTestMode.system:
          return _currentEntitlement;
      }
    }
    return _currentEntitlement;
  }

  /// Convenience boolean indicating whether Premium capabilities are currently active,
  /// derived from [effectiveEntitlement].
  bool get isPremiumActive => effectiveEntitlement.isActive;

  /// Operational status of the current entitlement, derived from [effectiveEntitlement].
  EntitlementStatus get status => effectiveEntitlement.status;

  /// Whether the manager has finished loading its initial cached state.
  bool get isInitialized => _isInitialized;

  Future<SharedPreferences?> _getPrefs() async {
    if (_prefs != null) return _prefs;
    try {
      _prefs = await SharedPreferences.getInstance().timeout(
        const Duration(milliseconds: 100),
      );
      return _prefs;
    } catch (_) {
      return null;
    }
  }

  // ── Initialization & Hydration ─────────────────────────────────────────────
  /// Loads previously cached entitlement state from secure storage and debug override
  /// into memory.
  ///
  /// If the cache is empty, corrupted, or unreadable, defaults safely to
  /// [PremiumEntitlement.none()] without crashing the application.
  Future<void> initialize() async {
    // 1. Hydrate authoritative entitlement from secure storage cache
    try {
      final cachedJsonStr = await _secureStorage.read(key: keyCachedEntitlement);
      if (cachedJsonStr != null && cachedJsonStr.isNotEmpty) {
        final Map<String, dynamic> jsonMap = jsonDecode(cachedJsonStr);
        _currentEntitlement = PremiumEntitlement.fromJson(jsonMap);
      } else {
        _currentEntitlement = const PremiumEntitlement.none();
      }
    } catch (e) {
      // Safe fallback on cache read failure or corruption
      _currentEntitlement = const PremiumEntitlement.none();
    }

    // 2. Hydrate debug override from SharedPreferences (debug mode only)
    if (_isDebug) {
      try {
        final prefs = await _getPrefs();
        if (prefs != null) {
          final rawMode = prefs.getString(keyDebugTestMode);
          if (rawMode != null && rawMode.isNotEmpty) {
            _debugTestMode = PremiumTestMode.values.firstWhere(
              (m) => m.name == rawMode,
              orElse: () => PremiumTestMode.system,
            );
          } else {
            _debugTestMode = PremiumTestMode.system;
          }
        } else {
          _debugTestMode = PremiumTestMode.system;
        }
      } catch (_) {
        _debugTestMode = PremiumTestMode.system;
      }
    } else {
      _debugTestMode = PremiumTestMode.system;
    }

    // 3. Mark initialized and notify listeners ONCE (no start-up state flicker)
    _isInitialized = true;
    notifyListeners();
  }

  // ── Debug Override Mutations ───────────────────────────────────────────────
  /// Sets the debug test mode override (development only).
  ///
  /// In release builds, this is a strict no-op to preserve release isolation.
  Future<void> setDebugTestMode(PremiumTestMode mode) async {
    if (!_isDebug) return;
    if (_debugTestMode == mode) return;

    _debugTestMode = mode;
    notifyListeners();

    try {
      final prefs = await _getPrefs();
      if (prefs != null) {
        if (mode == PremiumTestMode.system) {
          await prefs.remove(keyDebugTestMode);
        } else {
          await prefs.setString(keyDebugTestMode, mode.name);
        }
      }
    } catch (_) {}
  }

  /// Resets the debug test mode override to [PremiumTestMode.system] (development only).
  Future<void> resetDebugTestMode() async {
    await setDebugTestMode(PremiumTestMode.system);
  }

  // ── Mutations ──────────────────────────────────────────────────────────────
  /// Updates the authoritative store entitlement state, caches it in secure storage,
  /// and notifies listeners.
  ///
  /// Called when a new entitlement is verified via the platform store (in P4) or
  /// updated via administrative / store synchronization.
  Future<void> updateEntitlement(PremiumEntitlement entitlement) async {
    if (_currentEntitlement == entitlement) return;
    _currentEntitlement = entitlement;
    notifyListeners();

    try {
      final jsonStr = jsonEncode(entitlement.toJson());
      await _secureStorage.write(key: keyCachedEntitlement, value: jsonStr);
    } catch (_) {
      // Local cache persistence failure does not disrupt current in-memory state
    }
  }

  /// Invalidates the active authoritative entitlement (e.g., following refund, chargeback, or expiration).
  Future<void> invalidateEntitlement({
    EntitlementStatus status = EntitlementStatus.none,
  }) async {
    final updated = _currentEntitlement.copyWith(status: status);
    await updateEntitlement(updated);
  }

  /// Clears the local entitlement cache and resets state to un-entitled.
  Future<void> clearCache() async {
    _currentEntitlement = const PremiumEntitlement.none();
    notifyListeners();

    try {
      await _secureStorage.delete(key: keyCachedEntitlement);
    } catch (_) {}
  }
}
