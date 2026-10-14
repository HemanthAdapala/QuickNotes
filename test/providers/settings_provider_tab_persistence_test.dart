import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quick_notes/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsProvider — Tab Persistence Tests', () {
    test('1. Missing preference defaults to Notes', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = SettingsProvider();
      await provider.initialize();

      expect(provider.lastActiveTab, 'notes');
      expect(provider.isNotesTab, isTrue);
    });

    test('2. Persisted Notes restores Notes', () async {
      SharedPreferences.setMockInitialValues({
        SettingsProvider.keyLastActiveTab: 'notes',
      });
      final provider = SettingsProvider();
      await provider.initialize();

      expect(provider.lastActiveTab, 'notes');
      expect(provider.isNotesTab, isTrue);
    });

    test('3. Persisted Tasks restores Tasks', () async {
      SharedPreferences.setMockInitialValues({
        SettingsProvider.keyLastActiveTab: 'tasks',
      });
      final provider = SettingsProvider();
      await provider.initialize();

      expect(provider.lastActiveTab, 'tasks');
      expect(provider.isNotesTab, isFalse);
    });

    test('4. Invalid persisted value safely falls back to Notes', () async {
      SharedPreferences.setMockInitialValues({
        SettingsProvider.keyLastActiveTab: 'corrupted_value_xyz',
      });
      final provider = SettingsProvider();
      await provider.initialize();

      expect(provider.lastActiveTab, 'notes');
      expect(provider.isNotesTab, isTrue);
    });

    test('5. A user tab change updates persistence and notifies listeners', () async {
      SharedPreferences.setMockInitialValues({
        SettingsProvider.keyLastActiveTab: 'notes',
      });
      final provider = SettingsProvider();
      await provider.initialize();

      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      await provider.setLastActiveTab('tasks');

      expect(provider.lastActiveTab, 'tasks');
      expect(provider.isNotesTab, isFalse);
      expect(notifyCount, 1);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(SettingsProvider.keyLastActiveTab), 'tasks');
    });

    test('6. A tab change to current selection does not trigger unnecessary write or notification', () async {
      SharedPreferences.setMockInitialValues({
        SettingsProvider.keyLastActiveTab: 'notes',
      });
      final provider = SettingsProvider();
      await provider.initialize();

      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      await provider.setLastActiveTab('notes');

      expect(notifyCount, 0);
      expect(provider.lastActiveTab, 'notes');
    });

    test('7. Normalized input: whitespace or mixed case is handled safely', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = SettingsProvider();
      await provider.initialize();

      await provider.setLastActiveTab('  TASKS  ');
      expect(provider.lastActiveTab, 'tasks');

      await provider.setLastActiveTab('  NOTES ');
      expect(provider.lastActiveTab, 'notes');

      await provider.setLastActiveTab('unknown');
      expect(provider.lastActiveTab, 'notes');
    });
  });
}
