import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quick_notes/views/screens/home_screen.dart';
import 'package:quick_notes/views/widgets/notes_and_task_pill.dart';
import 'package:quick_notes/providers/settings_provider.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/providers/tasks_provider.dart';
import 'package:quick_notes/premium/premium.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => '.',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async => null,
    );
  });

  Widget buildHarness({
    bool? initialShowTasks,
    SettingsProvider? settingsProvider,
  }) {
    return MediaQuery(
      data: const MediaQueryData(
        size: Size(390, 844),
        disableAnimations: true,
      ),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider.value(
            value: settingsProvider ?? SettingsProvider(),
          ),
          ChangeNotifierProvider(create: (_) => PremiumEntitlementManager()),
          Provider<FeatureAccess>(
            create: (c) => DefaultFeatureAccess(
              Provider.of<PremiumEntitlementManager>(c, listen: false),
            ),
          ),
          ChangeNotifierProvider(create: (_) => NotesProvider()),
          ChangeNotifierProvider(create: (_) => TasksProvider()),
        ],
        child: MaterialApp(
          home: HomeScreen(initialShowTasks: initialShowTasks),
        ),
      ),
    );
  }

  group('HomeScreen — Tab Persistence & Startup Override Tests', () {
    testWidgets('1. Ordinary startup with missing preference defaults to Notes', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();
      await settings.initialize();

      await tester.pumpWidget(buildHarness(settingsProvider: settings));
      await tester.pumpAndSettle();

      final pill = tester.widget<NotesAndTaskPill>(find.byType(NotesAndTaskPill));
      expect(pill.isNotesActive, isTrue, reason: 'Should default to Notes when no preference exists');
    });

    testWidgets('2. Ordinary startup restores persisted Notes preference', (tester) async {
      SharedPreferences.setMockInitialValues({
        SettingsProvider.keyLastActiveTab: 'notes',
      });
      final settings = SettingsProvider();
      await settings.initialize();

      await tester.pumpWidget(buildHarness(settingsProvider: settings));
      await tester.pumpAndSettle();

      final pill = tester.widget<NotesAndTaskPill>(find.byType(NotesAndTaskPill));
      expect(pill.isNotesActive, isTrue);
    });

    testWidgets('3. Ordinary startup restores persisted Tasks preference', (tester) async {
      SharedPreferences.setMockInitialValues({
        SettingsProvider.keyLastActiveTab: 'tasks',
      });
      final settings = SettingsProvider();
      await settings.initialize();

      await tester.pumpWidget(buildHarness(settingsProvider: settings));
      await tester.pumpAndSettle();

      final pill = tester.widget<NotesAndTaskPill>(find.byType(NotesAndTaskPill));
      expect(pill.isNotesActive, isFalse, reason: 'Should restore Tasks tab from persisted preference');
    });

    testWidgets('4. Explicit task startup (deep link) overrides persisted Notes without overwriting preference', (tester) async {
      SharedPreferences.setMockInitialValues({
        SettingsProvider.keyLastActiveTab: 'notes',
      });
      final settings = SettingsProvider();
      await settings.initialize();

      // Launch with explicit task override
      await tester.pumpWidget(buildHarness(
        initialShowTasks: true,
        settingsProvider: settings,
      ));
      await tester.pumpAndSettle();

      // Verify Tasks is shown
      final pill = tester.widget<NotesAndTaskPill>(find.byType(NotesAndTaskPill));
      expect(pill.isNotesActive, isFalse);

      // Verify the persisted preference was NOT changed
      expect(settings.lastActiveTab, 'notes');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(SettingsProvider.keyLastActiveTab), 'notes');
    });

    testWidgets('5. Explicit Notes startup overrides persisted Tasks without overwriting preference', (tester) async {
      SharedPreferences.setMockInitialValues({
        SettingsProvider.keyLastActiveTab: 'tasks',
      });
      final settings = SettingsProvider();
      await settings.initialize();

      // Launch with explicit notes override
      await tester.pumpWidget(buildHarness(
        initialShowTasks: false,
        settingsProvider: settings,
      ));
      await tester.pumpAndSettle();

      // Verify Notes is shown
      final pill = tester.widget<NotesAndTaskPill>(find.byType(NotesAndTaskPill));
      expect(pill.isNotesActive, isTrue);

      // Verify persisted preference remains Tasks
      expect(settings.lastActiveTab, 'tasks');
    });

    testWidgets('6. User-initiated tab change updates persisted preference', (tester) async {
      SharedPreferences.setMockInitialValues({
        SettingsProvider.keyLastActiveTab: 'notes',
      });
      final settings = SettingsProvider();
      await settings.initialize();

      await tester.pumpWidget(buildHarness(settingsProvider: settings));
      await tester.pumpAndSettle();

      // Tap on Tasks button inside NotesAndTaskPill
      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();

      final pill = tester.widget<NotesAndTaskPill>(find.byType(NotesAndTaskPill));
      expect(pill.isNotesActive, isFalse);
      expect(settings.lastActiveTab, 'tasks');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(SettingsProvider.keyLastActiveTab), 'tasks');
    });
  });
}
