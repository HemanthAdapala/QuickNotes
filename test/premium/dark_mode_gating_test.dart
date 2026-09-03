import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quick_notes/models/folder.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/providers/settings_provider.dart';
import 'package:quick_notes/repositories/folders_repository.dart';
import 'package:quick_notes/repositories/notes_repository.dart';
import 'package:quick_notes/premium/premium.dart';
import 'package:quick_notes/views/screens/appearance_screen.dart';
import 'package:quick_notes/views/screens/settings_screen.dart';

/// Fake FoldersRepository for NotesProvider in tests
class FakeFoldersRepository implements FoldersRepository {
  @override
  Future<List<Folder>> getFolders() async => [];
  @override
  Future<int> insertFolder(Folder folder) async => 1;
  @override
  Future<int> updateFolder(Folder folder) async => 1;
  @override
  Future<int> deleteFolder(String id) async => 1;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Fake NotesRepository for NotesProvider in tests
class FakeNotesRepository implements NotesRepository {
  @override
  Future<List<Note>> getNotes() async => [];
  @override
  Future<List<Note>> queryHabits() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Helper to build test environment with complete providers
Widget createDarkModeGatingTestApp({
  required PremiumEntitlementManager entitlementManager,
  required SettingsProvider settingsProvider,
  NotesProvider? notesProvider,
  required Widget child,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<PremiumEntitlementManager>.value(
        value: entitlementManager,
      ),
      ProxyProvider<PremiumEntitlementManager, FeatureAccess>(
        update: (_, manager, __) => DefaultFeatureAccess(manager),
      ),
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settingsProvider,
      ),
      if (notesProvider != null)
        ChangeNotifierProvider<NotesProvider>.value(
          value: notesProvider,
        ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: child,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsProvider settingsProvider;
  late PremiumEntitlementManager entitlementManager;
  late NotesProvider notesProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});

    entitlementManager = PremiumEntitlementManager();
    final prefs = await SharedPreferences.getInstance();
    settingsProvider = SettingsProvider(prefs: prefs);

    notesProvider = NotesProvider(
      notesRepository: FakeNotesRepository(),
      foldersRepository: FakeFoldersRepository(),
    );
  });

  tearDown(() {
    entitlementManager.dispose();
    settingsProvider.dispose();
    notesProvider.dispose();
  });

  group('Phase P6: Obsidian Dark Mode Premium Feature Gating Tests', () {
    testWidgets('1. Free user denied: requesting Dark Mode opens PremiumGateSheet',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await entitlementManager.initialize();
      expect(entitlementManager.isPremiumActive, isFalse);
      expect(settingsProvider.themeMode, equals(ThemeMode.light));

      await tester.pumpWidget(
        createDarkModeGatingTestApp(
          entitlementManager: entitlementManager,
          settingsProvider: settingsProvider,
          child: const AppearanceScreen(),
        ),
      );

      // Tap Obsidian Night
      await tester.tap(find.text('Obsidian Night'));
      await tester.pumpAndSettle();

      // Premium Gate Sheet MUST be open
      expect(find.byType(PremiumGateSheet), findsOneWidget);
      expect(find.text('Unlock Premium'), findsOneWidget);
      expect(find.text('OBSIDIAN DARK MODE'), findsOneWidget);
      expect(find.text('A Calmer Workspace for Night'), findsOneWidget);

      // SettingsProvider must NOT be mutated
      expect(settingsProvider.themeMode, equals(ThemeMode.light));
      expect(settingsProvider.isDarkMode, isFalse);
    });

    testWidgets('2. Free user cannot mutate persistence for dark mode',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await entitlementManager.initialize();

      await tester.pumpWidget(
        createDarkModeGatingTestApp(
          entitlementManager: entitlementManager,
          settingsProvider: settingsProvider,
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => requestDarkModeAccess(context),
              child: const Text('Enable Dark Mode'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Enable Dark Mode'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(SettingsProvider.keyThemeMode), isNot('dark'));
      expect(settingsProvider.isDarkMode, isFalse);
    });

    testWidgets('3. Premium user allowed: activating Dark Mode succeeds immediately',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await entitlementManager.initialize();
      // Activate lifetime premium
      await entitlementManager.updateEntitlement(
        PremiumEntitlement.active(productId: premiumLifetimeProductId),
      );
      expect(entitlementManager.isPremiumActive, isTrue);

      await tester.pumpWidget(
        createDarkModeGatingTestApp(
          entitlementManager: entitlementManager,
          settingsProvider: settingsProvider,
          child: const AppearanceScreen(),
        ),
      );

      // Tap Obsidian Night
      await tester.tap(find.text('Obsidian Night'));
      await tester.pumpAndSettle();

      // Premium Gate should NOT be open
      expect(find.byType(PremiumGateSheet), findsNothing);

      // SettingsProvider MUST be updated to dark
      expect(settingsProvider.themeMode, equals(ThemeMode.dark));
      expect(settingsProvider.isDarkMode, isTrue);
    });

    testWidgets('4. Premium user persistence: Dark Mode persists in SharedPreferences',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await entitlementManager.initialize();
      await entitlementManager.updateEntitlement(
        PremiumEntitlement.active(productId: premiumLifetimeProductId),
      );

      await tester.pumpWidget(
        createDarkModeGatingTestApp(
          entitlementManager: entitlementManager,
          settingsProvider: settingsProvider,
          child: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => requestDarkModeAccess(ctx),
              child: const Text('Enable Dark Mode'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Enable Dark Mode'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(SettingsProvider.keyThemeMode), equals('dark'));
    });

    testWidgets('5. Turning Dark Mode off remains 100% free without paywall',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await entitlementManager.initialize();
      // Free user starts in dark mode (e.g. from existing settings)
      await settingsProvider.setThemeMode(ThemeMode.dark);
      expect(settingsProvider.isDarkMode, isTrue);
      expect(entitlementManager.isPremiumActive, isFalse);

      await tester.pumpWidget(
        createDarkModeGatingTestApp(
          entitlementManager: entitlementManager,
          settingsProvider: settingsProvider,
          child: const AppearanceScreen(),
        ),
      );

      // Tap Light Paper
      await tester.tap(find.text('Light Paper'));
      await tester.pumpAndSettle();

      // No paywall should appear
      expect(find.byType(PremiumGateSheet), findsNothing);
      expect(settingsProvider.themeMode, equals(ThemeMode.light));
      expect(settingsProvider.isDarkMode, isFalse);
    });

    testWidgets('6. Gate dismissal: dismissing via Maybe Later preserves current theme',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await entitlementManager.initialize();
      expect(settingsProvider.themeMode, equals(ThemeMode.light));

      await tester.pumpWidget(
        createDarkModeGatingTestApp(
          entitlementManager: entitlementManager,
          settingsProvider: settingsProvider,
          child: const AppearanceScreen(),
        ),
      );

      // Trigger gate
      await tester.tap(find.text('Obsidian Night'));
      await tester.pumpAndSettle();
      expect(find.byType(PremiumGateSheet), findsOneWidget);

      // Dismiss gate
      await tester.tap(find.text('Maybe Later'));
      await tester.pumpAndSettle();

      expect(find.byType(PremiumGateSheet), findsNothing);
      expect(settingsProvider.themeMode, equals(ThemeMode.light));
      expect(entitlementManager.isPremiumActive, isFalse);
    });

    testWidgets('7. Purchase unlock propagation: reactively allows Obsidian Night',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await entitlementManager.initialize();
      expect(entitlementManager.isPremiumActive, isFalse);

      await tester.pumpWidget(
        createDarkModeGatingTestApp(
          entitlementManager: entitlementManager,
          settingsProvider: settingsProvider,
          child: const AppearanceScreen(),
        ),
      );

      // Attempt 1: Free user denied
      await tester.tap(find.text('Obsidian Night'));
      await tester.pumpAndSettle();
      expect(find.byType(PremiumGateSheet), findsOneWidget);

      // Close gate
      await tester.tap(find.text('Maybe Later'));
      await tester.pumpAndSettle();

      // Simulate purchase unlock
      await entitlementManager.updateEntitlement(
        PremiumEntitlement.active(productId: premiumLifetimeProductId),
      );
      await tester.pumpAndSettle();

      // Attempt 2: Allowed!
      await tester.tap(find.text('Obsidian Night'));
      await tester.pumpAndSettle();
      expect(find.byType(PremiumGateSheet), findsNothing);
      expect(settingsProvider.themeMode, equals(ThemeMode.dark));
    });

    testWidgets('8. Multiple entry points: SettingsScreen toggle uses authoritative gate',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await entitlementManager.initialize();
      expect(entitlementManager.isPremiumActive, isFalse);

      await tester.pumpWidget(
        createDarkModeGatingTestApp(
          entitlementManager: entitlementManager,
          settingsProvider: settingsProvider,
          notesProvider: notesProvider,
          child: const SettingsScreen(),
        ),
      );

      // Tap Dark Mode toggle switch in SettingsScreen
      await tester.tap(find.byType(ToggleSwitch));
      await tester.pumpAndSettle();

      // Must open PremiumGateSheet
      expect(find.byType(PremiumGateSheet), findsOneWidget);
      expect(find.text('OBSIDIAN DARK MODE'), findsOneWidget);
      expect(settingsProvider.themeMode, equals(ThemeMode.light));
    });

    testWidgets('9. Light Paper is free and never presents PremiumGateSheet',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await entitlementManager.initialize();
      expect(entitlementManager.isPremiumActive, isFalse);

      await tester.pumpWidget(
        createDarkModeGatingTestApp(
          entitlementManager: entitlementManager,
          settingsProvider: settingsProvider,
          child: const AppearanceScreen(),
        ),
      );

      await tester.tap(find.text('Light Paper'));
      await tester.pumpAndSettle();

      expect(find.byType(PremiumGateSheet), findsNothing);
      expect(settingsProvider.themeMode, equals(ThemeMode.light));
    });

    testWidgets('10. Opening Dark Mode gate does NOT mutate entitlement',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await entitlementManager.initialize();
      expect(entitlementManager.isPremiumActive, isFalse);

      await tester.pumpWidget(
        createDarkModeGatingTestApp(
          entitlementManager: entitlementManager,
          settingsProvider: settingsProvider,
          child: const AppearanceScreen(),
        ),
      );

      await tester.tap(find.text('Obsidian Night'));
      await tester.pumpAndSettle();

      expect(find.byType(PremiumGateSheet), findsOneWidget);
      expect(entitlementManager.isPremiumActive, isFalse);
      expect(entitlementManager.currentEntitlement.status,
          equals(EntitlementStatus.none));
    });

    test('11. Existing persisted Dark Mode compatibility: loads safely on startup',
        () async {
      SharedPreferences.setMockInitialValues({
        SettingsProvider.keyThemeMode: 'dark',
      });
      final prefs = await SharedPreferences.getInstance();
      final loadedProvider = SettingsProvider(prefs: prefs);
      await loadedProvider.initialize();

      // Must restore dark mode without crashing or overwriting
      expect(loadedProvider.themeMode, equals(ThemeMode.dark));
      expect(loadedProvider.isDarkMode, isTrue);
    });

    test('12. No bypass: FeatureAccess is the single authoritative decider', () {
      final freeManager = PremiumEntitlementManager();
      final freeAccess = DefaultFeatureAccess(freeManager);

      expect(freeAccess.canAccess(PremiumFeature.darkMode), isFalse);
      expect(freeAccess.isPremiumFeature(PremiumFeature.darkMode), isTrue);

      final premiumManager = PremiumEntitlementManager()
        ..updateEntitlement(
          PremiumEntitlement.active(productId: premiumLifetimeProductId),
        );
      final premiumAccess = DefaultFeatureAccess(premiumManager);

      expect(premiumAccess.canAccess(PremiumFeature.darkMode), isTrue);
    });
  });
}
