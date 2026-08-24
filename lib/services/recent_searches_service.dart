// ─────────────────────────────────────────────────────────────────────────────
// recent_searches_service.dart
// Persists the user's last 8 search queries in SharedPreferences.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:shared_preferences/shared_preferences.dart';

class RecentSearchesService {
  RecentSearchesService._();
  static final RecentSearchesService instance = RecentSearchesService._();

  static const String _kKey = 'quick_notes_recent_searches';
  static const int _kMaxItems = 8;

  /// Load persisted recent searches (most-recent first).
  Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_kKey) ?? [];
  }

  /// Prepend [term], deduplicate, cap at [_kMaxItems], then persist.
  Future<List<String>> addSearch(String term) async {
    final trimmed = term.trim();
    if (trimmed.isEmpty) return load();

    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_kKey) ?? [];
    current.remove(trimmed); // deduplicate
    current.insert(0, trimmed); // most-recent first
    final capped = current.take(_kMaxItems).toList();
    await prefs.setStringList(_kKey, capped);
    return capped;
  }

  /// Remove a single [term].
  Future<List<String>> removeSearch(String term) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_kKey) ?? [];
    current.remove(term.trim());
    await prefs.setStringList(_kKey, current);
    return current;
  }

  /// Clear all recent searches.
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
  }
}
