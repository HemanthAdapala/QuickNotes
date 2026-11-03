import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'premium_entitlement.dart';
import 'jws_lease.dart';
import 'premium_config.dart';

/// PremiumEntitlementManager — Authoritative reactive state manager for Quick Notes
/// Premium entitlement state, cache persistence, and future purchase synchronization.
///
/// Responsibilities:
/// - Holds the current in-memory [PremiumEntitlement] (authoritative store entitlement)
/// - Holds the current verified [JwsLease] (cryptographic 7-day signed lease)
/// - Tracks in-session monotonic elapsed time via [Stopwatch] to guard against clock rollback
/// - Flags [requiresReverification] if reboot or clock rollback creates lease uncertainty
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
  static const String keyCachedLease = 'premium_cached_jws_lease';
  static const String keyLastKnownWallClock = 'premium_last_known_wall_clock';
  static const String keyDebugTestMode = 'debug_premium_test_mode';

  // ── Dependencies ───────────────────────────────────────────────────────────
  final FlutterSecureStorage _secureStorage;
  SharedPreferences? _prefs;
  final bool _isDebug;
  final bool _requireLease;

  // ── State ──────────────────────────────────────────────────────────────────
  PremiumEntitlement _currentEntitlement = const PremiumEntitlement.none();
  JwsLease? _currentLease;
  final Stopwatch _monotonicStopwatch = Stopwatch();
  bool _requiresReverification = false;
  DateTime? _lastKnownWallClock;
  PremiumTestMode _debugTestMode = PremiumTestMode.system;
  bool _isInitialized = false;

  PremiumEntitlementManager({
    FlutterSecureStorage? secureStorage,
    SharedPreferences? prefs,
    bool? isDebug,
    bool? requireLease,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _prefs = prefs,
        _isDebug = isDebug ?? kDebugMode,
        _requireLease = kReleaseMode ? true : (requireLease ?? PremiumBackendConfig.isConfigured);

  // ── Getters ────────────────────────────────────────────────────────────────
  /// The authoritative store-derived entitlement state of the application.
  PremiumEntitlement get authoritativeEntitlement => _currentEntitlement;

  /// Backwards-compatible alias for [authoritativeEntitlement].
  PremiumEntitlement get currentEntitlement => _currentEntitlement;

  /// The active cryptographic 7-day entitlement lease, if present.
  JwsLease? get currentLease => _currentLease;

  /// Whether the cryptographic lease has passed its 7-day expiration time.
  bool get isLeaseExpired => _currentLease != null && _currentLease!.isExpired();

  /// Whether reboot, clock rollback, or expired lease requires online store re-verification.
  bool get requiresReverification => _requiresReverification;

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
  /// derived from [effectiveEntitlement] and lease freshness.
  bool get isPremiumActive {
    if (!effectiveEntitlement.isActive) return false;
    if (_requiresReverification) return false;
    if (_currentLease != null && _currentLease!.isExpired()) return false;
    return true;
  }

  /// Operational status of the current entitlement, derived from [effectiveEntitlement].
  EntitlementStatus get status {
    if (_requiresReverification || isLeaseExpired) {
      return EntitlementStatus.verificationRequired;
    }
    return effectiveEntitlement.status;
  }

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

    // 2. Hydrate cached JWS lease and verify clock consistency
    try {
      final cachedLeaseStr = await _secureStorage.read(key: keyCachedLease);
      if (cachedLeaseStr != null && cachedLeaseStr.isNotEmpty) {
        final Map<String, dynamic> leaseMap = jsonDecode(cachedLeaseStr);
        _currentLease = JwsLease.fromJson(leaseMap);
      } else {
        _currentLease = null;
      }
    } catch (_) {
      _currentLease = null;
    }

    // 3. Inspect wall clock & reboot / clock-skew status
    final now = DateTime.now().toUtc();
    try {
      final lastClockStr = await _secureStorage.read(key: keyLastKnownWallClock);
      if (lastClockStr != null && lastClockStr.isNotEmpty) {
        _lastKnownWallClock = DateTime.tryParse(lastClockStr)?.toUtc();
      }
    } catch (_) {
      _lastKnownWallClock = null;
    }

    if (_currentEntitlement.isActive) {
      if (_requireLease && _currentLease == null) {
        // Active entitlement exists in cache without a cryptographic lease when lease is required -> require re-verification
        _requiresReverification = true;
      } else if (_currentLease != null && _currentLease!.isExpired(now)) {
        // Lease has expired
        _requiresReverification = true;
      } else if (_currentLease != null && _lastKnownWallClock != null && now.isBefore(_lastKnownWallClock!.subtract(const Duration(minutes: 5)))) {
        // Clock rolled back backwards past last known timestamp -> safety uncertainty
        _requiresReverification = true;
      } else if (_currentLease != null && now.isBefore(_currentLease!.issuedAt.subtract(const Duration(minutes: 5)))) {
        // Current wall clock is before lease issuance -> safety uncertainty
        _requiresReverification = true;
      } else {
        // Lease is valid (or legacy mode) and clock is consistent
        _requiresReverification = false;
        if (_currentLease != null) {
          _monotonicStopwatch.reset();
          _monotonicStopwatch.start();
          _lastKnownWallClock = now;
          _persistLastKnownClock(now);
        }
      }
    } else {
      _requiresReverification = false;
    }

    // 4. Hydrate debug override from SharedPreferences (debug mode only)
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

    // 5. Mark initialized and notify listeners ONCE (no start-up state flicker)
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _persistLastKnownClock(DateTime clock) async {
    try {
      await _secureStorage.write(
        key: keyLastKnownWallClock,
        value: clock.toIso8601String(),
      );
    } catch (_) {}
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
  /// Updates the authoritative store entitlement state, caches it in secure storage,
  /// and notifies listeners only after successful persistence.
  ///
  /// Called when a new entitlement is verified via the platform store or
  /// updated via administrative / store synchronization.
  /// Returns `true` if persistence and activation succeeded, `false` otherwise.
  Future<bool> updateEntitlement(PremiumEntitlement entitlement) async {
    if (_currentEntitlement == entitlement && !_requiresReverification) {
      return true;
    }

    final previousEntitlement = _currentEntitlement;
    _currentEntitlement = entitlement;

    try {
      final jsonStr = jsonEncode(entitlement.toJson());
      await _secureStorage.write(key: keyCachedEntitlement, value: jsonStr);
    } catch (e) {
      if (kDebugMode) {
        print('ENTITLEMENT MANAGER [Error]: Failed to persist entitlement: $e');
      }
      _currentEntitlement = previousEntitlement;
      return false;
    }

    _requiresReverification = false;
    notifyListeners();
    return true;
  }

  /// Updates the cryptographic 7-day JWS lease, persists it, and clears re-verification requirement.
  /// Returns `true` on successful persistence, `false` otherwise.
  Future<bool> updateLease(JwsLease lease) async {
    final now = DateTime.now().toUtc();
    final previousEntitlement = _currentEntitlement;
    final previousLease = _currentLease;
    final newEntitlement = (!_currentEntitlement.isActive || _currentEntitlement.productId != lease.productId)
        ? _currentEntitlement.copyWith(
            status: EntitlementStatus.active,
            productId: lease.productId,
          )
        : _currentEntitlement;

    _currentLease = lease;
    _currentEntitlement = newEntitlement;

    try {
      final leaseJson = jsonEncode(lease.toJson());
      await _secureStorage.write(key: keyCachedLease, value: leaseJson);
      final jsonStr = jsonEncode(newEntitlement.toJson());
      await _secureStorage.write(key: keyCachedEntitlement, value: jsonStr);
      await _persistLastKnownClock(now);
    } catch (e) {
      if (kDebugMode) {
        print('ENTITLEMENT MANAGER [Error]: Failed to persist lease: $e');
      }
      _currentLease = previousLease;
      _currentEntitlement = previousEntitlement;
      return false;
    }

    _requiresReverification = false;
    _monotonicStopwatch.reset();
    _monotonicStopwatch.start();
    _lastKnownWallClock = now;

    notifyListeners();
    return true;
  }

  /// Marks that re-verification is required (e.g. after reboot or network failure).
  void markRequiresReverification() {
    if (!_requiresReverification) {
      _requiresReverification = true;
      notifyListeners();
    }
  }

  /// Invalidates the active authoritative entitlement (e.g., following refund, chargeback, or revocation).
  Future<void> invalidateEntitlement({
    EntitlementStatus status = EntitlementStatus.none,
  }) async {
    _currentLease = null;
    _requiresReverification = false;
    _monotonicStopwatch.stop();
    _monotonicStopwatch.reset();

    final updated = _currentEntitlement.copyWith(status: status);
    _currentEntitlement = updated;
    notifyListeners();

    try {
      final jsonStr = jsonEncode(updated.toJson());
      await _secureStorage.write(key: keyCachedEntitlement, value: jsonStr);
      await _secureStorage.delete(key: keyCachedLease);
    } catch (_) {}
  }

  /// Clears the local entitlement cache and resets state to un-entitled.
  Future<void> clearCache() async {
    _currentEntitlement = const PremiumEntitlement.none();
    _currentLease = null;
    _requiresReverification = false;
    _monotonicStopwatch.stop();
    _monotonicStopwatch.reset();
    _lastKnownWallClock = null;
    notifyListeners();

    try {
      await _secureStorage.delete(key: keyCachedEntitlement);
      await _secureStorage.delete(key: keyCachedLease);
      await _secureStorage.delete(key: keyLastKnownWallClock);
    } catch (_) {}
  }
}
