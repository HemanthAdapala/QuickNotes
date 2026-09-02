import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'premium_entitlement.dart';

/// PremiumEntitlementManager — Authoritative reactive state manager for Quick Notes
/// Premium entitlement state, cache persistence, and future purchase synchronization.
///
/// Responsibilities:
/// - Holds the current in-memory [PremiumEntitlement]
/// - Initializes / hydrates cached entitlement state from secure storage
/// - Notifies reactive listeners when entitlement state changes
/// - Persists verified entitlement updates to the secure local cache
/// - Provides clean invalidation and cache-clearing mechanisms
///
/// Security Boundary:
/// Local cached entitlement is treated as **previously verified cache**, not
/// independent or unforgeable proof of purchase. Phase P4 will provide online
/// platform store re-verification on top of this foundation.
class PremiumEntitlementManager extends ChangeNotifier {
  // ── Storage Keys ───────────────────────────────────────────────────────────
  static const String keyCachedEntitlement = 'premium_cached_entitlement';

  // ── Dependencies ───────────────────────────────────────────────────────────
  final FlutterSecureStorage _secureStorage;

  // ── State ──────────────────────────────────────────────────────────────────
  PremiumEntitlement _currentEntitlement = const PremiumEntitlement.none();
  bool _isInitialized = false;

  PremiumEntitlementManager({
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  // ── Getters ────────────────────────────────────────────────────────────────
  /// The current entitlement state of the application.
  PremiumEntitlement get currentEntitlement => _currentEntitlement;

  /// Convenience boolean indicating whether Premium capabilities are currently active.
  bool get isPremiumActive => _currentEntitlement.isActive;

  /// Operational status of the current entitlement.
  EntitlementStatus get status => _currentEntitlement.status;

  /// Whether the manager has finished loading its initial cached state.
  bool get isInitialized => _isInitialized;

  // ── Initialization & Hydration ─────────────────────────────────────────────
  /// Loads previously cached entitlement state from secure storage into memory.
  ///
  /// If the cache is empty, corrupted, or unreadable, defaults safely to
  /// [PremiumEntitlement.none()] without crashing the application.
  Future<void> initialize() async {
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
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  // ── Mutations ──────────────────────────────────────────────────────────────
  /// Updates the current entitlement state, caches it in secure storage, and notifies listeners.
  ///
  /// Called when a new entitlement is verified via the platform store (in P4) or
  /// updated via administrative / test synchronization.
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

  /// Invalidates the active entitlement (e.g., following refund, chargeback, or expiration).
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
