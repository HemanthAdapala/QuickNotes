import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

import 'package:quick_notes/models/folder.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/models/session_type.dart';
import 'package:quick_notes/premium/premium.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/providers/settings_provider.dart';
import 'package:quick_notes/providers/tasks_provider.dart';
import 'package:quick_notes/repositories/folders_repository.dart';
import 'package:quick_notes/repositories/notes_repository.dart';
import 'package:quick_notes/repositories/tasks_repository.dart';
import 'package:quick_notes/services/backup/backup_engine.dart';
import 'package:quick_notes/services/backup/restore_engine.dart';
import 'package:quick_notes/services/backup/zip_decoder.dart';
import 'package:quick_notes/services/database_service.dart';
import 'package:quick_notes/services/session_manager.dart';
import 'package:quick_notes/views/screens/appearance_screen.dart';
import 'package:quick_notes/views/screens/developer/premium_test_mode_screen.dart';
import 'package:quick_notes/views/screens/folder_management_screen.dart';
import 'package:quick_notes/views/screens/widgets_screen.dart';

/// In-memory Folders repository for tests
class FakeFoldersRepository implements FoldersRepository {
  final Map<String, Folder> _folders = {};

  @override
  Future<List<Folder>> getFolders() async => _folders.values.toList();
  @override
  Future<int> insertFolder(Folder folder) async {
    _folders[folder.id] = folder;
    return 1;
  }
  @override
  Future<int> updateFolder(Folder folder) async {
    _folders[folder.id] = folder;
    return 1;
  }
  @override
  Future<int> deleteFolder(String id) async {
    _folders.remove(id);
    return 1;
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// In-memory Notes repository for tests
class FakeNotesRepository implements NotesRepository {
  final Map<String, Note> _notes = {};

  @override
  Future<List<Note>> getNotes() async => _notes.values.toList();
  @override
  Future<List<Note>> queryHabits() async => [];
  @override
  Future<List<Map<String, dynamic>>> queryNotesSummaryPaged({
    String? folderId,
    String? category,
    bool? isFavorite,
    bool? isArchived = false,
    bool isDeleted = false,
    int limit = 20,
    int offset = 0,
  }) async => [];
  @override
  Future<int> insertNote(Note note) async {
    _notes[note.id] = note;
    return 1;
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget createTestApp({
  required PremiumEntitlementManager entitlementManager,
  required SettingsProvider settingsProvider,
  required NotesProvider notesProvider,
  TasksProvider? tasksProvider,
  required Widget child,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
      ChangeNotifierProvider<PremiumEntitlementManager>.value(
        value: entitlementManager,
      ),
      ProxyProvider<PremiumEntitlementManager, FeatureAccess>(
        update: (_, manager, __) => DefaultFeatureAccess(manager),
      ),
      ChangeNotifierProvider<NotesProvider>.value(value: notesProvider),
      if (tasksProvider != null)
        ChangeNotifierProvider<TasksProvider>.value(value: tasksProvider),
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

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => '.',
    );
  });

  group('Phase P9: Debug Premium Test Mode Infrastructure Tests', () {
    late PremiumEntitlementManager manager;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      manager = PremiumEntitlementManager();
      await manager.initialize();
    });

    // ── TEST 1: Default State is System & Synchronized with Authoritative ─────
    test('1. Initial default state is System and mirrors authoritative state', () async {
      expect(manager.debugTestMode, equals(PremiumTestMode.system));
      expect(manager.authoritativeEntitlement.status, equals(EntitlementStatus.none));
      expect(manager.effectiveEntitlement.status, equals(EntitlementStatus.none));
      expect(manager.isPremiumActive, isFalse);
    });

    // ── TEST 2: Force Premium Simulation State & Domain Model Guardrail ───────
    test('2. Force Premium simulation sets StoreSource.debug without mutating authoritative state', () async {
      await manager.setDebugTestMode(PremiumTestMode.premium);

      expect(manager.debugTestMode, equals(PremiumTestMode.premium));
      expect(manager.effectiveEntitlement.isActive, isTrue);
      expect(manager.effectiveEntitlement.status, equals(EntitlementStatus.active));
      expect(manager.effectiveEntitlement.productId, equals('debug_simulated_premium'));
      // Guardrail 3: Must explicitly use StoreSource.debug, never fake manual or store source
      expect(manager.effectiveEntitlement.storeSource, equals(StoreSource.debug));

      // Guardrail 2: Authoritative entitlement remains completely un-mutated
      expect(manager.authoritativeEntitlement.status, equals(EntitlementStatus.none));
      expect(manager.authoritativeEntitlement.productId, isNull);
      expect(manager.isPremiumActive, isTrue);
    });

    // ── TEST 3: Force Free Simulation State (Even with Real Store Purchase) ───
    test('3. Force Free simulation enforces locked Free access even when authoritative is Premium', () async {
      // Simulate real store purchase
      await manager.updateEntitlement(const PremiumEntitlement(
        status: EntitlementStatus.active,
        productId: 'quicknotes_premium_lifetime',
        storeSource: StoreSource.google,
      ));

      expect(manager.authoritativeEntitlement.isActive, isTrue);
      expect(manager.effectiveEntitlement.isActive, isTrue);

      // Developer forces Free to test paywalls
      await manager.setDebugTestMode(PremiumTestMode.free);

      expect(manager.debugTestMode, equals(PremiumTestMode.free));
      // Authoritative store status remains active
      expect(manager.authoritativeEntitlement.isActive, isTrue);
      expect(manager.authoritativeEntitlement.productId, equals('quicknotes_premium_lifetime'));
      // Effective entitlement is forced to none
      expect(manager.effectiveEntitlement.isActive, isFalse);
      expect(manager.effectiveEntitlement.status, equals(EntitlementStatus.none));
      expect(manager.isPremiumActive, isFalse);
    });

    // ── TEST 4: Reset to System Restores Authoritative Entitlement ────────────
    test('4. Reset to System removes override and follows authoritative entitlement', () async {
      await manager.updateEntitlement(const PremiumEntitlement(
        status: EntitlementStatus.active,
        productId: 'quicknotes_premium_lifetime',
        storeSource: StoreSource.apple,
      ));

      await manager.setDebugTestMode(PremiumTestMode.free);
      expect(manager.isPremiumActive, isFalse);

      await manager.resetDebugTestMode();
      expect(manager.debugTestMode, equals(PremiumTestMode.system));
      expect(manager.effectiveEntitlement, equals(manager.authoritativeEntitlement));
      expect(manager.isPremiumActive, isTrue);
    });

    // ── TEST 5: Persistence Across Manager Lifecycles in Debug Mode ───────────
    test('5. Debug test mode persists across manager restarts in SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      final manager1 = PremiumEntitlementManager(prefs: prefs);
      await manager1.initialize();

      await manager1.setDebugTestMode(PremiumTestMode.premium);
      expect(prefs.getString(PremiumEntitlementManager.keyDebugTestMode), equals('premium'));

      // Simulate app restart with a fresh manager instance
      final manager2 = PremiumEntitlementManager(prefs: prefs);
      await manager2.initialize();

      expect(manager2.debugTestMode, equals(PremiumTestMode.premium));
      expect(manager2.effectiveEntitlement.isActive, isTrue);
      expect(manager2.effectiveEntitlement.storeSource, equals(StoreSource.debug));
    });

    // ── TEST 6: Strict Release Isolation Guardrail ────────────────────────────
    test('6. Release build strictly ignores SharedPreferences override and disables mutations', () async {
      final prefs = await SharedPreferences.getInstance();
      // Pre-seed an override in SharedPreferences
      await prefs.setString(PremiumEntitlementManager.keyDebugTestMode, 'premium');

      // Create manager simulating release mode (isDebug: false)
      final releaseManager = PremiumEntitlementManager(
        prefs: prefs,
        isDebug: false,
      );
      await releaseManager.initialize();

      // Override must be strictly ignored
      expect(releaseManager.debugTestMode, equals(PremiumTestMode.system));
      expect(releaseManager.effectiveEntitlement.status, equals(EntitlementStatus.none));
      expect(releaseManager.isPremiumActive, isFalse);

      // Attempting to set debug test mode in release is a strict no-op
      await releaseManager.setDebugTestMode(PremiumTestMode.premium);
      expect(releaseManager.debugTestMode, equals(PremiumTestMode.system));
      expect(releaseManager.isPremiumActive, isFalse);
    });

    // ── TEST 7: Initialization Lifecycle & Single-Notification ────────────────
    test('7. Initialization loads authoritative cache first, then debug override, notifying listeners once', () async {
      FlutterSecureStorage.setMockInitialValues({
        PremiumEntitlementManager.keyCachedEntitlement: jsonEncode(const PremiumEntitlement(
          status: EntitlementStatus.active,
          productId: 'lifetime_test',
          storeSource: StoreSource.google,
        ).toJson()),
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PremiumEntitlementManager.keyDebugTestMode, 'free');

      int notifyCount = 0;
      final testManager = PremiumEntitlementManager(prefs: prefs);
      testManager.addListener(() {
        notifyCount++;
      });

      await testManager.initialize();

      // Verified: notifyListeners called exactly once on initialization completion
      expect(notifyCount, equals(1));
      expect(testManager.isInitialized, isTrue);
      expect(testManager.authoritativeEntitlement.isActive, isTrue);
      expect(testManager.debugTestMode, equals(PremiumTestMode.free));
      expect(testManager.effectiveEntitlement.isActive, isFalse);
    });

    // ── TEST 8: Conceptual Separation & FlutterSecureStorage Immutability ────
    test('8. Authoritative, Debug Override, and Effective entitlements remain isolated and FlutterSecureStorage remains immutable', () async {
      const storage = FlutterSecureStorage();
      final initialSecureCache = await storage.read(key: PremiumEntitlementManager.keyCachedEntitlement);

      expect(manager.authoritativeEntitlement, equals(manager.currentEntitlement));
      expect(manager.debugTestMode, equals(PremiumTestMode.system));

      await manager.setDebugTestMode(PremiumTestMode.premium);
      // Authoritative never touches StoreSource.debug
      expect(manager.authoritativeEntitlement.storeSource, isNot(equals(StoreSource.debug)));
      expect(manager.effectiveEntitlement.storeSource, equals(StoreSource.debug));

      // Guardrail 4 & 9: FlutterSecureStorage cache remains completely untouched by debug overrides
      final secureCacheAfterPremium = await storage.read(key: PremiumEntitlementManager.keyCachedEntitlement);
      expect(secureCacheAfterPremium, equals(initialSecureCache));

      await manager.setDebugTestMode(PremiumTestMode.free);
      final secureCacheAfterFree = await storage.read(key: PremiumEntitlementManager.keyCachedEntitlement);
      expect(secureCacheAfterFree, equals(initialSecureCache));

      await manager.resetDebugTestMode();
      final secureCacheAfterReset = await storage.read(key: PremiumEntitlementManager.keyCachedEntitlement);
      expect(secureCacheAfterReset, equals(initialSecureCache));
    });

    // ── TEST 9: Store Updates Do Not Overwrite Active Debug Override ───────────
    test('9. Real store update caches authoritative entitlement without clearing forced override', () async {
      await manager.setDebugTestMode(PremiumTestMode.free);
      expect(manager.isPremiumActive, isFalse);

      // Real store sync occurs
      await manager.updateEntitlement(const PremiumEntitlement(
        status: EntitlementStatus.active,
        productId: 'store_real_product',
        storeSource: StoreSource.google,
      ));

      // Authoritative updated
      expect(manager.authoritativeEntitlement.productId, equals('store_real_product'));
      // But effective is still locked to Free because developer override is active
      expect(manager.effectiveEntitlement.isActive, isFalse);
      expect(manager.isPremiumActive, isFalse);
    });

    // ── TEST 10: Container-Level Backup Isolation in Both Directions ───────────
    test('10. Container-Level Backup Isolation: debug override keys are absent from .qnb and restore does not touch override', () async {
      final tempDir = Directory.systemTemp.createTempSync('qnb_isolation_test_');
      final backupDir = Directory(p.join(tempDir.path, 'backups'))..createSync();
      final docsDir = Directory(p.join(tempDir.path, 'docs'))..createSync();

      try {
        final dbService = DatabaseService.instance;
        final sessionManager = SessionManager();
        const testUserId = 'usr_p9_isolation_test';
        await sessionManager.saveSession(
          userId: testUserId,
          sessionType: SessionType.google,
        );

        final foldersRepo = SqliteFoldersRepository(dbService: dbService);
        final notesRepo = SqliteNotesRepository(dbService: dbService);
        final tasksRepo = SqliteTasksRepository(dbService: dbService);

        final testFolder = Folder(
          id: 'f_p9_test',
          userId: testUserId,
          name: 'P9 Backup Test Folder',
          createdAt: DateTime.now(),
        );
        await foldersRepo.insertFolder(testFolder);

        // Set debug override in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(PremiumEntitlementManager.keyDebugTestMode, 'premium');

        final backupEngine = BackupEngine(
          foldersRepo: foldersRepo,
          notesRepo: notesRepo,
          tasksRepo: tasksRepo,
          sessionManager: sessionManager,
          dbService: dbService,
        );

        final backupResult = await backupEngine.createBackup(
          customBackupDir: backupDir,
          customDocumentsDir: docsDir,
        );

        expect(backupResult.success, isTrue);
        expect(backupResult.filePath, isNotNull);

        // Inspect raw .qnb archive contents at the container level
        final backupFile = File(backupResult.filePath!);
        final bytes = backupFile.readAsBytesSync();
        final entries = ZipDecoder.decode(bytes);

        expect(entries.isNotEmpty, isTrue);
        for (final entry in entries) {
          final contentStr = utf8.decode(entry.data, allowMalformed: true);
          expect(contentStr.contains(PremiumEntitlementManager.keyDebugTestMode), isFalse,
              reason: 'Entry ${entry.name} must not contain debug_premium_test_mode');
          expect(contentStr.contains('debug_simulated_premium'), isFalse,
              reason: 'Entry ${entry.name} must not contain debug_simulated_premium');
          expect(contentStr.contains('PremiumTestMode'), isFalse,
              reason: 'Entry ${entry.name} must not contain PremiumTestMode');
        }

        // Now test reverse direction: Restore does not modify SharedPreferences debug override
        final restoreEngine = RestoreEngine(
          sessionManager: sessionManager,
          dbService: dbService,
          backupEngine: backupEngine,
        );

        final restoreResult = await restoreEngine.restoreFromBackup(
          backupFilePath: backupResult.filePath!,
          customDocumentsDir: docsDir,
        );

        expect(restoreResult.success, isTrue);
        // Verify SharedPreferences override was completely untouched by restore
        expect(prefs.getString(PremiumEntitlementManager.keyDebugTestMode), equals('premium'));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    // ── TEST 11: Production Feature Gates React Directly ──────────────────────
    testWidgets('11. Production Feature Gates (requestWidgetAccess, requestDarkModeAccess, openFolderCustomization) react to effective entitlement', (tester) async {
      final fakeFoldersRepo = FakeFoldersRepository();
      final fakeNotesRepo = FakeNotesRepository();
      final notesProvider = NotesProvider(
        foldersRepository: fakeFoldersRepo,
        notesRepository: fakeNotesRepo,
      );
      final prefs = await SharedPreferences.getInstance();
      final settingsProvider = SettingsProvider(prefs: prefs);

      final testFolder = Folder(
        id: 'f_gate_test',
        userId: 'usr_gate',
        name: 'Gated Folder',
        createdAt: DateTime.now(),
      );

      // Start with manager forced to Free
      await manager.setDebugTestMode(PremiumTestMode.free);

      await tester.pumpWidget(createTestApp(
        entitlementManager: manager,
        settingsProvider: settingsProvider,
        notesProvider: notesProvider,
        child: Builder(
          builder: (context) {
            return Column(
              children: [
                ElevatedButton(
                  key: const Key('btn_widget'),
                  onPressed: () => requestWidgetAccess(context),
                  child: const Text('Widgets'),
                ),
                ElevatedButton(
                  key: const Key('btn_dark_mode'),
                  onPressed: () => requestDarkModeAccess(context),
                  child: const Text('Dark Mode'),
                ),
                ElevatedButton(
                  key: const Key('btn_folder'),
                  onPressed: () => openFolderCustomization(context, testFolder),
                  child: const Text('Folder Customization'),
                ),
              ],
            );
          },
        ),
      ));

      await tester.pumpAndSettle();

      // 1. In Free mode: requestWidgetAccess triggers PremiumGateSheet
      await tester.tap(find.byKey(const Key('btn_widget')));
      await tester.pumpAndSettle();
      expect(find.byType(PremiumGateSheet), findsOneWidget);
      // Dismiss sheet
      Navigator.of(tester.element(find.byType(PremiumGateSheet))).pop();
      await tester.pumpAndSettle();

      // 2. In Free mode: requestDarkModeAccess triggers PremiumGateSheet
      await tester.tap(find.byKey(const Key('btn_dark_mode')));
      await tester.pumpAndSettle();
      expect(find.byType(PremiumGateSheet), findsOneWidget);
      Navigator.of(tester.element(find.byType(PremiumGateSheet))).pop();
      await tester.pumpAndSettle();

      // 3. In Free mode: openFolderCustomization triggers PremiumGateSheet
      await tester.tap(find.byKey(const Key('btn_folder')));
      await tester.pumpAndSettle();
      expect(find.byType(PremiumGateSheet), findsOneWidget);
      Navigator.of(tester.element(find.byType(PremiumGateSheet))).pop();
      await tester.pumpAndSettle();

      // Switch manager to Premium
      await manager.setDebugTestMode(PremiumTestMode.premium);
      await tester.pumpAndSettle();

      // 4. In Premium mode: requestWidgetAccess navigates to WidgetsScreen
      await tester.tap(find.byKey(const Key('btn_widget')));
      await tester.pumpAndSettle();
      expect(find.byType(WidgetsScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(WidgetsScreen))).pop();
      await tester.pumpAndSettle();

      // 5. In Premium mode: requestDarkModeAccess activates Dark Theme
      await tester.tap(find.byKey(const Key('btn_dark_mode')));
      await tester.pumpAndSettle();
      expect(settingsProvider.isDarkMode, isTrue);

      // 6. In Premium mode: openFolderCustomization opens FolderCustomizationSheet
      await tester.tap(find.byKey(const Key('btn_folder')));
      await tester.pumpAndSettle();
      expect(find.byType(FolderCustomizationSheet), findsOneWidget);
    });

    // ── TEST 12: UI Tests for PremiumTestModeScreen & SettingsScreen ──────────
    testWidgets('12. PremiumTestModeScreen displays developer banner, badges, diagnostics, and reacts to interactions', (tester) async {
      final fakeFoldersRepo = FakeFoldersRepository();
      final fakeNotesRepo = FakeNotesRepository();
      final notesProvider = NotesProvider(
        foldersRepository: fakeFoldersRepo,
        notesRepository: fakeNotesRepo,
      );
      final prefs = await SharedPreferences.getInstance();
      final settingsProvider = SettingsProvider(prefs: prefs);

      await tester.pumpWidget(createTestApp(
        entitlementManager: manager,
        settingsProvider: settingsProvider,
        notesProvider: notesProvider,
        child: const PremiumTestModeScreen(),
      ));
      await tester.pumpAndSettle();

      // Guardrail 10: Check unmistakable developer banner
      expect(find.text('DEVELOPER UTILITY'), findsOneWidget);
      expect(
        find.text('This screen only affects local debug testing. It does not create or modify a real purchase.'),
        findsOneWidget,
      );

      // Initial state is system
      expect(find.text('SYSTEM (REAL STORE)'), findsOneWidget);

      // Tap "Force Premium (Simulated)"
      await tester.tap(find.text('Force Premium (Simulated)'));
      await tester.pumpAndSettle();

      expect(manager.debugTestMode, equals(PremiumTestMode.premium));
      expect(find.text('SIMULATED PREMIUM'), findsOneWidget);

      // Tap "Force Free (Simulated)"
      await tester.tap(find.text('Force Free (Simulated)'));
      await tester.pumpAndSettle();

      expect(manager.debugTestMode, equals(PremiumTestMode.free));
      expect(find.text('FORCED FREE'), findsOneWidget);

      // Tap "Reset to System Entitlement"
      await tester.tap(find.text('Reset to System Entitlement'));
      await tester.pumpAndSettle();

      expect(manager.debugTestMode, equals(PremiumTestMode.system));
      expect(find.text('SYSTEM (REAL STORE)'), findsOneWidget);
    });

    // ── TEST 13: Transition Test: System Follows Authoritative, Forced Locked ──
    test('13. System mode follows authoritative changes while forced modes remain locked', () async {
      // 1. Authoritative = Free, Override = system -> Free
      expect(manager.authoritativeEntitlement.isActive, isFalse);
      expect(manager.debugTestMode, equals(PremiumTestMode.system));
      expect(manager.effectiveEntitlement.isActive, isFalse);

      // 2. Authoritative changes -> Premium
      await manager.updateEntitlement(const PremiumEntitlement(
        status: EntitlementStatus.active,
        productId: 'lifetime_test',
        storeSource: StoreSource.google,
      ));
      expect(manager.authoritativeEntitlement.isActive, isTrue);
      // Override = system -> still follows Premium
      expect(manager.effectiveEntitlement.isActive, isTrue);

      // 3. Override = free -> Free
      await manager.setDebugTestMode(PremiumTestMode.free);
      expect(manager.effectiveEntitlement.isActive, isFalse);

      // 4. Authoritative changes -> update again
      await manager.updateEntitlement(const PremiumEntitlement(
        status: EntitlementStatus.active,
        productId: 'lifetime_test_updated',
        storeSource: StoreSource.apple,
      ));
      // Override = free -> STILL Free
      expect(manager.effectiveEntitlement.isActive, isFalse);

      // 5. Override = premium -> Premium
      await manager.setDebugTestMode(PremiumTestMode.premium);
      expect(manager.effectiveEntitlement.isActive, isTrue);

      // 6. Authoritative changes -> Free (invalidated)
      await manager.invalidateEntitlement(status: EntitlementStatus.revoked);
      expect(manager.authoritativeEntitlement.isActive, isFalse);
      // Override = premium -> STILL Premium
      expect(manager.effectiveEntitlement.isActive, isTrue);
      expect(manager.effectiveEntitlement.storeSource, equals(StoreSource.debug));
    });

    // ── TEST 14: Definitive 6-State Gating Matrix ─────────────────────────────
    test('14. Validates definitive 6-state integration matrix', () async {
      const activeStoreEntitlement = PremiumEntitlement(
        status: EntitlementStatus.active,
        productId: 'lifetime',
        storeSource: StoreSource.google,
      );
      const freeStoreEntitlement = PremiumEntitlement.none();

      // State 1: System + Free Store -> Paywall (isActive = false)
      await manager.updateEntitlement(freeStoreEntitlement);
      await manager.setDebugTestMode(PremiumTestMode.system);
      expect(manager.isPremiumActive, isFalse);

      // State 2: System + Premium Store -> Feature opens (isActive = true)
      await manager.updateEntitlement(activeStoreEntitlement);
      await manager.setDebugTestMode(PremiumTestMode.system);
      expect(manager.isPremiumActive, isTrue);

      // State 3: Forced Free + Free Store -> Paywall (isActive = false)
      await manager.updateEntitlement(freeStoreEntitlement);
      await manager.setDebugTestMode(PremiumTestMode.free);
      expect(manager.isPremiumActive, isFalse);

      // State 4: Forced Free + Premium Store -> Paywall (isActive = false)
      await manager.updateEntitlement(activeStoreEntitlement);
      await manager.setDebugTestMode(PremiumTestMode.free);
      expect(manager.isPremiumActive, isFalse);

      // State 5: Forced Premium + Free Store -> Feature opens (isActive = true)
      await manager.updateEntitlement(freeStoreEntitlement);
      await manager.setDebugTestMode(PremiumTestMode.premium);
      expect(manager.isPremiumActive, isTrue);

      // State 6: Forced Premium + Premium Store -> Feature opens (isActive = true)
      await manager.updateEntitlement(activeStoreEntitlement);
      await manager.setDebugTestMode(PremiumTestMode.premium);
      expect(manager.isPremiumActive, isTrue);
    });
  });
}
