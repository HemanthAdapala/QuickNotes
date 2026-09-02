import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// SettingsProvider — Single authoritative source of truth for Quick Notes
/// application settings, appearance preferences, and global theme mode.
class SettingsProvider extends ChangeNotifier {
  // ── Storage Keys ───────────────────────────────────────────────────────────
  static const String keyThemeMode = 'theme_mode';
  static const String keyLegacyIsDarkMode = 'is_dark_mode';
  static const String keyLayoutDensity = 'layout_density';
  static const String keyFontScale = 'font_scale';
  static const String keyAccentPreference = 'accent_preference';

  // ── Defaults ───────────────────────────────────────────────────────────────
  static const ThemeMode defaultThemeMode = ThemeMode.light;
  static const String defaultLayoutDensity = 'grid';
  static const double defaultFontScale = 1.0;
  static const String defaultAccentPreference = 'yellow';

  // ── State ──────────────────────────────────────────────────────────────────
  ThemeMode _themeMode = defaultThemeMode;
  String _layoutDensity = defaultLayoutDensity;
  double _fontSizeScale = defaultFontScale;
  String _selectedAccent = defaultAccentPreference;
  bool _isInitialized = false;

  SharedPreferences? _prefs;
  final FlutterSecureStorage _secureStorage;

  SettingsProvider({
    SharedPreferences? prefs,
    FlutterSecureStorage? secureStorage,
  })  : _prefs = prefs,
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  // ── Getters ────────────────────────────────────────────────────────────────
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  String get layoutDensity => _layoutDensity;
  double get fontSizeScale => _fontSizeScale;
  String get selectedAccent => _selectedAccent;
  bool get isBentoGrid => _layoutDensity == 'grid';
  bool get isInitialized => _isInitialized;

  // ── Initialization ─────────────────────────────────────────────────────────
  /// Loads persisted settings from storage into memory.
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();

    // 1. Theme Mode
    final savedThemeStr = _prefs?.getString(keyThemeMode);
    if (savedThemeStr != null) {
      _themeMode = _parseThemeMode(savedThemeStr);
    } else {
      // Check legacy boolean key
      final legacyDark = _prefs?.getBool(keyLegacyIsDarkMode);
      if (legacyDark != null) {
        _themeMode = legacyDark ? ThemeMode.dark : ThemeMode.light;
      } else {
        _themeMode = defaultThemeMode;
      }
    }

    // 2. Layout Density
    String? density = _prefs?.getString(keyLayoutDensity);
    if (density == null) {
      try {
        density = await _secureStorage.read(key: keyLayoutDensity);
      } catch (_) {}
    }
    _layoutDensity = (density == 'grid' || density == 'list')
        ? density!
        : defaultLayoutDensity;

    // 3. Font Scale
    double? fontScale;
    final fontScaleNum = _prefs?.getDouble(keyFontScale);
    if (fontScaleNum != null) {
      fontScale = fontScaleNum;
    } else {
      final fontScaleStr = _prefs?.getString(keyFontScale);
      if (fontScaleStr != null) {
        fontScale = double.tryParse(fontScaleStr);
      } else {
        try {
          final secureScaleStr = await _secureStorage.read(key: keyFontScale);
          if (secureScaleStr != null) {
            fontScale = double.tryParse(secureScaleStr);
          }
        } catch (_) {}
      }
    }
    _fontSizeScale = fontScale ?? defaultFontScale;

    // 4. Accent Preference
    String? accent = _prefs?.getString(keyAccentPreference);
    if (accent == null) {
      try {
        accent = await _secureStorage.read(key: keyAccentPreference);
      } catch (_) {}
    }
    _selectedAccent = accent ?? defaultAccentPreference;

    _isInitialized = true;
    notifyListeners();
  }

  // ── Mutations ──────────────────────────────────────────────────────────────
  /// Sets the application theme mode (light, dark, system) and persists it.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();

    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setString(keyThemeMode, mode.name);
    await _prefs?.setBool(keyLegacyIsDarkMode, mode == ThemeMode.dark);
  }

  /// Toggles between Light and Dark modes.
  Future<void> toggleTheme() async {
    final nextMode = isDarkMode ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(nextMode);
  }

  /// Sets the note card layout density ('grid' or 'list') and persists it.
  Future<void> setLayoutDensity(String density) async {
    if (_layoutDensity == density) return;
    _layoutDensity = density;
    notifyListeners();

    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setString(keyLayoutDensity, density);
    try {
      await _secureStorage.write(key: keyLayoutDensity, value: density);
    } catch (_) {}
  }

  /// Sets the typography scale (0.8, 1.0, 1.2) and persists it.
  Future<void> setFontSizeScale(double scale) async {
    if (_fontSizeScale == scale) return;
    _fontSizeScale = scale;
    notifyListeners();

    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setDouble(keyFontScale, scale);
    try {
      await _secureStorage.write(key: keyFontScale, value: scale.toString());
    } catch (_) {}
  }

  /// Sets the UI accent color preference and persists it.
  Future<void> setSelectedAccent(String accent) async {
    if (_selectedAccent == accent) return;
    _selectedAccent = accent;
    notifyListeners();

    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setString(keyAccentPreference, accent);
    try {
      await _secureStorage.write(key: keyAccentPreference, value: accent);
    } catch (_) {}
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  static ThemeMode _parseThemeMode(String value) {
    switch (value.toLowerCase()) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      default:
        return defaultThemeMode;
    }
  }
}
