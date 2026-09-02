import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quick_notes/providers/settings_provider.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/providers/tasks_provider.dart';
import 'package:quick_notes/services/task_engine.dart';
import 'package:quick_notes/services/reminder_scheduler.dart';
import 'package:quick_notes/themes/quick_notes_theme.dart';
import 'package:quick_notes/views/screens/settings_screen.dart';
import 'package:quick_notes/views/screens/appearance_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsProvider settingsProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    settingsProvider = SettingsProvider();
    await settingsProvider.initialize();
  });

  Widget buildTestApp(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider(create: (_) => NotesProvider()),
        ChangeNotifierProvider(
          create: (_) => TasksProvider(
            engine: TaskEngine(scheduler: LoggingReminderScheduler()),
          ),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            theme: QuickNotesTheme.lightTheme,
            darkTheme: QuickNotesTheme.darkTheme,
            themeMode: settings.themeMode,
            home: child,
          );
        },
      ),
    );
  }

  group('Settings and Appearance Theme Widget Tests', () {
    testWidgets('1. SettingsScreen renders Dark Mode toggle and tapping updates SettingsProvider',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestApp(const SettingsScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify default state is light
      expect(settingsProvider.isDarkMode, isFalse);

      // Find Dark Mode text & ToggleSwitch
      expect(find.text('Dark Mode'), findsOneWidget);
      expect(find.byType(ToggleSwitch), findsWidgets);

      // Tap Dark Mode switch
      final switchFinder = find.byType(ToggleSwitch).first;
      await tester.tap(switchFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify theme toggled to Dark
      expect(settingsProvider.isDarkMode, isTrue);
      expect(settingsProvider.themeMode, equals(ThemeMode.dark));
    });

    testWidgets('2. AppearanceScreen interactive theme cards switch ThemeMode between Light and Dark',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestApp(const AppearanceScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(settingsProvider.isDarkMode, isFalse);
      expect(find.text('Light Paper'), findsOneWidget);
      expect(find.text('Obsidian Night'), findsOneWidget);

      // Tap Obsidian Night card
      await tester.tap(find.text('Obsidian Night'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(settingsProvider.isDarkMode, isTrue);
      expect(settingsProvider.themeMode, equals(ThemeMode.dark));

      // Tap Light Paper card
      await tester.tap(find.text('Light Paper'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(settingsProvider.isDarkMode, isFalse);
      expect(settingsProvider.themeMode, equals(ThemeMode.light));
    });

    testWidgets('3. AppearanceScreen layout density selection updates SettingsProvider',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestApp(const AppearanceScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(settingsProvider.layoutDensity, equals('grid'));

      // Tap Quiet List
      await tester.tap(find.text('Quiet List'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(settingsProvider.layoutDensity, equals('list'));

      // Tap Bento Grid
      await tester.tap(find.text('Bento Grid'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(settingsProvider.layoutDensity, equals('grid'));
    });
  });
}
