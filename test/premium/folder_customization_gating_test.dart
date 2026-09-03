import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quick_notes/models/folder.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/repositories/folders_repository.dart';
import 'package:quick_notes/repositories/notes_repository.dart';
import 'package:quick_notes/premium/premium.dart';
import 'package:quick_notes/views/screens/folder_management_screen.dart';

/// Fake in-memory FoldersRepository for unit/widget testing
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

  Future<Folder?> getFolderById(String id) async => _folders[id];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Fake in-memory NotesRepository for NotesProvider
class FakeNotesRepository implements NotesRepository {
  final Map<String, Note> _notes = {};

  @override
  Future<List<Note>> getNotes() async => _notes.values.toList();

  @override
  Future<List<Note>> queryHabits() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Helper to build test environment
Widget createFolderGatingTestApp({
  required PremiumEntitlementManager entitlementManager,
  required NotesProvider notesProvider,
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

  late FakeFoldersRepository foldersRepo;
  late FakeNotesRepository notesRepo;
  late NotesProvider notesProvider;
  late PremiumEntitlementManager entitlementManager;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    foldersRepo = FakeFoldersRepository();
    notesRepo = FakeNotesRepository();
    entitlementManager = PremiumEntitlementManager();

    notesProvider = NotesProvider(
      notesRepository: notesRepo,
      foldersRepository: foldersRepo,
    );
  });

  tearDown(() {
    entitlementManager.dispose();
    notesProvider.dispose();
  });

  group('Phase P5: Folder Customization Premium Gating Tests', () {
    final testFolder = Folder(
      id: 'folder-1',
      name: 'Design Projects',
      createdAt: DateTime.now(),
    );

    testWidgets('1. Free user denied: openFolderCustomization opens PremiumGateSheet',
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
        createFolderGatingTestApp(
          entitlementManager: entitlementManager,
          notesProvider: notesProvider,
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => openFolderCustomization(context, testFolder),
              child: const Text('Customize'),
            ),
          ),
        ),
      );

      // Tap Customize
      await tester.tap(find.text('Customize'));
      await tester.pumpAndSettle();

      // Customization sheet should NOT be open
      expect(find.byType(FolderCustomizationSheet), findsNothing);

      // Premium Gate Sheet MUST be open
      expect(find.byType(PremiumGateSheet), findsOneWidget);
      expect(find.text('Unlock Premium'), findsOneWidget);
      expect(find.text('Make Every Folder Yours'), findsOneWidget);
      expect(find.text('FOLDER CUSTOMIZATION'), findsOneWidget);
    });

    testWidgets('2. Premium user allowed: openFolderCustomization opens FolderCustomizationSheet',
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
        createFolderGatingTestApp(
          entitlementManager: entitlementManager,
          notesProvider: notesProvider,
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => openFolderCustomization(context, testFolder),
              child: const Text('Customize'),
            ),
          ),
        ),
      );

      // Tap Customize
      await tester.tap(find.text('Customize'));
      await tester.pumpAndSettle();

      // Premium Gate should NOT be open
      expect(find.byType(PremiumGateSheet), findsNothing);

      // Customization sheet MUST be open
      expect(find.byType(FolderCustomizationSheet), findsOneWidget);
      expect(find.text('Customize Folder'), findsOneWidget);
    });

    testWidgets('3. Basic folder features remain completely free (create & delete)',
        (tester) async {
      await entitlementManager.initialize();
      expect(entitlementManager.isPremiumActive, isFalse);

      // Create folder as free user
      await notesProvider.createFolder('Free Work Folder');
      final folders = await foldersRepo.getFolders();
      expect(folders.length, equals(1));
      expect(folders.first.name, equals('Free Work Folder'));

      // Delete folder as free user
      final deleted = await notesProvider.deleteFolder(folders.first.id);
      expect(deleted, isTrue);
      final remaining = await foldersRepo.getFolders();
      expect(remaining.isEmpty, isTrue);
    });

    test('4. Gate specifically queries PremiumFeature.folderCustomization', () {
      final freeManager = PremiumEntitlementManager();
      final access = DefaultFeatureAccess(freeManager);

      expect(
        access.canAccess(PremiumFeature.folderCustomization),
        isFalse,
      );

      final premiumEntitlement =
          PremiumEntitlement.active(productId: premiumLifetimeProductId);
      final premiumManager = PremiumEntitlementManager()
        ..updateEntitlement(premiumEntitlement);
      final premiumAccess = DefaultFeatureAccess(premiumManager);

      expect(
        premiumAccess.canAccess(PremiumFeature.folderCustomization),
        isTrue,
      );
    });

    testWidgets('5. Opening Folder Customization gate does NOT mutate entitlement',
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
        createFolderGatingTestApp(
          entitlementManager: entitlementManager,
          notesProvider: notesProvider,
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => openFolderCustomization(context, testFolder),
              child: const Text('Customize'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Customize'));
      await tester.pumpAndSettle();

      expect(find.byType(PremiumGateSheet), findsOneWidget);
      // Entitlement MUST remain inactive
      expect(entitlementManager.isPremiumActive, isFalse);
      expect(entitlementManager.currentEntitlement.status,
          equals(EntitlementStatus.none));
    });

    testWidgets('6. Purchase unlock propagation updates FeatureAccess reactively',
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
        createFolderGatingTestApp(
          entitlementManager: entitlementManager,
          notesProvider: notesProvider,
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => openFolderCustomization(context, testFolder),
              child: const Text('Customize'),
            ),
          ),
        ),
      );

      // Attempt 1: Denied
      await tester.tap(find.text('Customize'));
      await tester.pumpAndSettle();
      expect(find.byType(PremiumGateSheet), findsOneWidget);

      // Close gate
      await tester.tap(find.text('Maybe Later'));
      await tester.pumpAndSettle();

      // Simulate purchase completion
      await entitlementManager.updateEntitlement(
        PremiumEntitlement.active(productId: premiumLifetimeProductId),
      );
      await tester.pumpAndSettle();

      // Attempt 2: Allowed!
      await tester.tap(find.text('Customize'));
      await tester.pumpAndSettle();
      expect(find.byType(FolderCustomizationSheet), findsOneWidget);
    });

    testWidgets('7. Dismissing gate via Maybe Later keeps entitlement inactive',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await entitlementManager.initialize();

      await tester.pumpWidget(
        createFolderGatingTestApp(
          entitlementManager: entitlementManager,
          notesProvider: notesProvider,
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => openFolderCustomization(context, testFolder),
              child: const Text('Customize'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Customize'));
      await tester.pumpAndSettle();

      expect(find.byType(PremiumGateSheet), findsOneWidget);

      await tester.tap(find.text('Maybe Later'));
      await tester.pumpAndSettle();

      expect(find.byType(PremiumGateSheet), findsNothing);
      expect(entitlementManager.isPremiumActive, isFalse);
    });

    test('8. Existing customized folder data is preserved and intact', () async {
      final customizedFolder = Folder(
        id: 'folder-custom-1',
        name: 'Personal Journal',
        createdAt: DateTime.now(),
        colorHex: '0xFFFFBDE6',
        sticker: 'birds.png',
      );

      await foldersRepo.insertFolder(customizedFolder);
      final retrieved = await foldersRepo.getFolderById('folder-custom-1');

      expect(retrieved, isNotNull);
      expect(retrieved!.colorHex, equals('0xFFFFBDE6'));
      expect(retrieved.sticker, equals('birds.png'));
    });

    testWidgets('9. Multiple entry points: card action routes through Premium Gate for free users',
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
        createFolderGatingTestApp(
          entitlementManager: entitlementManager,
          notesProvider: notesProvider,
          child: Builder(
            builder: (context) => FolderGridCard(
              folder: testFolder,
              index: 0,
              noteCount: 3,
              onTap: () {},
              onLongPressStart: (_) {},
              onCustomizeTap: () => openFolderCustomization(context, testFolder),
            ),
          ),
        ),
      );

      // Tap + customize circle on folder card
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();

      // Must open PremiumGateSheet
      expect(find.byType(PremiumGateSheet), findsOneWidget);
      expect(find.text('Make Every Folder Yours'), findsOneWidget);
      expect(find.byType(FolderCustomizationSheet), findsNothing);
    });

    test('10. Renaming a folder preserves colorHex and sticker data', () async {
      final customizedFolder = Folder(
        id: 'folder-custom-2',
        name: 'Old Name',
        createdAt: DateTime.now(),
        colorHex: '0xFFD6C8FF',
        sticker: 'love.png',
      );

      await foldersRepo.insertFolder(customizedFolder);

      // Rename folder using copyWith
      final renamedFolder = customizedFolder.copyWith(
        name: 'New Brand Name',
        updatedAt: DateTime.now(),
      );
      await foldersRepo.updateFolder(renamedFolder);

      final updated = await foldersRepo.getFolderById('folder-custom-2');
      expect(updated, isNotNull);
      expect(updated!.name, equals('New Brand Name'));
      expect(updated.colorHex, equals('0xFFD6C8FF'));
      expect(updated.sticker, equals('love.png'));
    });
  });
}
