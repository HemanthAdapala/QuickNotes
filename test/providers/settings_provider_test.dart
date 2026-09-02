import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quick_notes/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsProvider Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('1. Default initial state before and after initialize() with empty storage', () async {
      final provider = SettingsProvider();
      expect(provider.themeMode, equals(ThemeMode.light));
      expect(provider.isDarkMode, isFalse);
      expect(provider.layoutDensity, equals('grid'));
      expect(provider.fontSizeScale, equals(1.0));
      expect(provider.selectedAccent, equals('yellow'));
      expect(provider.isBentoGrid, isTrue);
      expect(provider.isInitialized, isFalse);

      await provider.initialize();

      expect(provider.themeMode, equals(ThemeMode.light));
      expect(provider.isDarkMode, isFalse);
      expect(provider.layoutDensity, equals('grid'));
      expect(provider.fontSizeScale, equals(1.0));
      expect(provider.selectedAccent, equals('yellow'));
      expect(provider.isInitialized, isTrue);
    });

    test('2. Setting and toggling theme mode updates state, notifies listeners, and persists', () async {
      final provider = SettingsProvider();
      await provider.initialize();

      int notificationCount = 0;
      provider.addListener(() {
        notificationCount++;
      });

      // Set to Dark
      await provider.setThemeMode(ThemeMode.dark);
      expect(provider.themeMode, equals(ThemeMode.dark));
      expect(provider.isDarkMode, isTrue);
      expect(notificationCount, equals(1));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(SettingsProvider.keyThemeMode), equals('dark'));
      expect(prefs.getBool(SettingsProvider.keyLegacyIsDarkMode), isTrue);

      // Toggle back to Light
      await provider.toggleTheme();
      expect(provider.themeMode, equals(ThemeMode.light));
      expect(provider.isDarkMode, isFalse);
      expect(notificationCount, equals(2));
      expect(prefs.getString(SettingsProvider.keyThemeMode), equals('light'));
      expect(prefs.getBool(SettingsProvider.keyLegacyIsDarkMode), isFalse);

      // Toggle to Dark again
      await provider.toggleTheme();
      expect(provider.themeMode, equals(ThemeMode.dark));
      expect(provider.isDarkMode, isTrue);
      expect(notificationCount, equals(3));
      expect(prefs.getString(SettingsProvider.keyThemeMode), equals('dark'));
    });

    test('3. Setting layout density, font scale, and accent color updates state and persists', () async {
      final provider = SettingsProvider();
      await provider.initialize();

      int notifications = 0;
      provider.addListener(() => notifications++);

      // Layout Density
      await provider.setLayoutDensity('list');
      expect(provider.layoutDensity, equals('list'));
      expect(provider.isBentoGrid, isFalse);
      expect(notifications, equals(1));

      // Font Scale
      await provider.setFontSizeScale(1.2);
      expect(provider.fontSizeScale, equals(1.2));
      expect(notifications, equals(2));

      // Accent Preference
      await provider.setSelectedAccent('indigo');
      expect(provider.selectedAccent, equals('indigo'));
      expect(notifications, equals(3));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(SettingsProvider.keyLayoutDensity), equals('list'));
      expect(prefs.getDouble(SettingsProvider.keyFontScale), equals(1.2));
      expect(prefs.getString(SettingsProvider.keyAccentPreference), equals('indigo'));
    });

    test('4. Restoration on initialize() from persisted SharedPreferences values', () async {
      SharedPreferences.setMockInitialValues({
        SettingsProvider.keyThemeMode: 'dark',
        SettingsProvider.keyLayoutDensity: 'list',
        SettingsProvider.keyFontScale: 0.8,
        SettingsProvider.keyAccentPreference: 'gray',
      });

      final provider = SettingsProvider();
      await provider.initialize();

      expect(provider.themeMode, equals(ThemeMode.dark));
      expect(provider.isDarkMode, isTrue);
      expect(provider.layoutDensity, equals('list'));
      expect(provider.fontSizeScale, equals(0.8));
      expect(provider.selectedAccent, equals('gray'));
    });

    test('5. Backward compatibility: loads legacy boolean is_dark_mode if theme_mode key is absent', () async {
      SharedPreferences.setMockInitialValues({
        SettingsProvider.keyLegacyIsDarkMode: true,
      });

      final provider = SettingsProvider();
      await provider.initialize();

      expect(provider.themeMode, equals(ThemeMode.dark));
      expect(provider.isDarkMode, isTrue);
    });
  });
}
