import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/services/splash_animation_resolver.dart';

void main() {
  group('SplashAnimationResolver Tests', () {
    test('Notes + Light Mode resolves to QuickNotesYellowTheme_Light.json', () {
      final path = SplashAnimationResolver.resolve(
        isNotesTab: true,
        isDarkMode: false,
      );
      expect(
        path,
        'assets/animations/SplashScreen/QuickNotesYellowTheme_Light.json',
      );
    });

    test('Tasks + Light Mode resolves to QuickNotes_BlueTheme_Light.json', () {
      final path = SplashAnimationResolver.resolve(
        isNotesTab: false,
        isDarkMode: false,
      );
      expect(
        path,
        'assets/animations/SplashScreen/QuickNotes_BlueTheme_Light.json',
      );
    });

    test('Notes + Dark Mode resolves to QuickNotesYellowTheme_Dark.json', () {
      final path = SplashAnimationResolver.resolve(
        isNotesTab: true,
        isDarkMode: true,
      );
      expect(
        path,
        'assets/animations/SplashScreen/QuickNotesYellowTheme_Dark.json',
      );
    });

    test('Tasks + Dark Mode resolves to QuickNotes_BlueTheme_Dark.json', () {
      final path = SplashAnimationResolver.resolve(
        isNotesTab: false,
        isDarkMode: true,
      );
      expect(
        path,
        'assets/animations/SplashScreen/QuickNotes_BlueTheme_Dark.json',
      );
    });

    group('resolveFromTabName helper', () {
      test('String "notes" in Light mode maps to YellowTheme_Light', () {
        expect(
          SplashAnimationResolver.resolveFromTabName(
            tabName: 'notes',
            isDarkMode: false,
          ),
          'assets/animations/SplashScreen/QuickNotesYellowTheme_Light.json',
        );
      });

      test('String "tasks" in Light mode maps to BlueTheme_Light', () {
        expect(
          SplashAnimationResolver.resolveFromTabName(
            tabName: 'tasks',
            isDarkMode: false,
          ),
          'assets/animations/SplashScreen/QuickNotes_BlueTheme_Light.json',
        );
      });

      test('String "notes" in Dark mode maps to YellowTheme_Dark', () {
        expect(
          SplashAnimationResolver.resolveFromTabName(
            tabName: 'notes',
            isDarkMode: true,
          ),
          'assets/animations/SplashScreen/QuickNotesYellowTheme_Dark.json',
        );
      });

      test('String "tasks" in Dark mode maps to BlueTheme_Dark', () {
        expect(
          SplashAnimationResolver.resolveFromTabName(
            tabName: 'tasks',
            isDarkMode: true,
          ),
          'assets/animations/SplashScreen/QuickNotes_BlueTheme_Dark.json',
        );
      });

      test('Null tabName defaults safely to Notes (Yellow)', () {
        expect(
          SplashAnimationResolver.resolveFromTabName(
            tabName: null,
            isDarkMode: false,
          ),
          'assets/animations/SplashScreen/QuickNotesYellowTheme_Light.json',
        );
        expect(
          SplashAnimationResolver.resolveFromTabName(
            tabName: null,
            isDarkMode: true,
          ),
          'assets/animations/SplashScreen/QuickNotesYellowTheme_Dark.json',
        );
      });

      test('Invalid or unknown tabName defaults safely to Notes (Yellow)', () {
        expect(
          SplashAnimationResolver.resolveFromTabName(
            tabName: 'unknown_tab',
            isDarkMode: false,
          ),
          'assets/animations/SplashScreen/QuickNotesYellowTheme_Light.json',
        );
        expect(
          SplashAnimationResolver.resolveFromTabName(
            tabName: '123',
            isDarkMode: true,
          ),
          'assets/animations/SplashScreen/QuickNotesYellowTheme_Dark.json',
        );
        expect(
          SplashAnimationResolver.resolveFromTabName(
            tabName: '',
            isDarkMode: false,
          ),
          'assets/animations/SplashScreen/QuickNotesYellowTheme_Light.json',
        );
      });
    });
  });
}
