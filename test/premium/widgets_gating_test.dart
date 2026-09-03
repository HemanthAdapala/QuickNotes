import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quick_notes/models/folder.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/models/task_item.dart';
import 'package:quick_notes/models/task_status.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/providers/settings_provider.dart';
import 'package:quick_notes/providers/tasks_provider.dart';
import 'package:quick_notes/repositories/folders_repository.dart';
import 'package:quick_notes/repositories/notes_repository.dart';
import 'package:quick_notes/services/task_engine.dart';
import 'package:quick_notes/services/reminder_scheduler.dart';
import 'package:quick_notes/services/widget_data_adapter.dart';
import 'package:quick_notes/premium/premium.dart';
import 'package:quick_notes/views/screens/settings_screen.dart';
import 'package:quick_notes/views/screens/widgets_screen.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PremiumEntitlementManager entitlementManager;
  late SettingsProvider settingsProvider;
  late NotesProvider notesProvider;
  late TasksProvider tasksProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});

    entitlementManager = PremiumEntitlementManager();
    await entitlementManager.initialize();

    final prefs = await SharedPreferences.getInstance();
    settingsProvider = SettingsProvider(prefs: prefs);
    await settingsProvider.initialize();

    notesProvider = NotesProvider(
      notesRepository: FakeNotesRepository(),
      foldersRepository: FakeFoldersRepository(),
    );

    tasksProvider = TasksProvider(
      engine: TaskEngine(scheduler: LoggingReminderScheduler()),
    );
  });

  tearDown(() {
    entitlementManager.dispose();
    settingsProvider.dispose();
    notesProvider.dispose();
  });

  Widget buildTestApp({
    required Widget child,
    PremiumEntitlementManager? manager,
    FeatureAccess? customAccess,
  }) {
    final effectiveManager = manager ?? entitlementManager;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<PremiumEntitlementManager>.value(
          value: effectiveManager,
        ),
        if (customAccess != null)
          Provider<FeatureAccess>.value(value: customAccess)
        else
          ProxyProvider<PremiumEntitlementManager, FeatureAccess>(
            update: (_, mgr, __) => DefaultFeatureAccess(mgr),
          ),
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settingsProvider,
        ),
        ChangeNotifierProvider<NotesProvider>.value(
          value: notesProvider,
        ),
        ChangeNotifierProvider<TasksProvider>.value(
          value: tasksProvider,
        ),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('Phase P7: Home Screen Widgets Premium Feature Gating Tests', () {
    testWidgets(
      '1. Free user denied: attempting widget activation opens PremiumGateSheet',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final access = DefaultFeatureAccess(entitlementManager);
        expect(access.canAccess(PremiumFeature.widgets), isFalse);

        await tester.pumpWidget(
          buildTestApp(child: const SettingsScreen()),
        );
        await tester.pumpAndSettle();

        // When: User taps on Widgets tile in Settings
        final widgetsTileFinder = find.text('Widgets');
        expect(widgetsTileFinder, findsOneWidget);

        await tester.tap(widgetsTileFinder);
        await tester.pumpAndSettle();

        // Then: PremiumGateSheet is presented
        expect(find.byType(PremiumGateSheet), findsOneWidget);
        expect(find.text('HOME SCREEN WIDGETS'), findsOneWidget);
        expect(find.text('Your Thoughts, Right at a Glance'), findsOneWidget);
      },
    );

    testWidgets(
      '2. Free user cannot activate/configure widgets (WidgetsScreen not pushed)',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final access = DefaultFeatureAccess(entitlementManager);
        expect(access.canAccess(PremiumFeature.widgets), isFalse);

        await tester.pumpWidget(
          buildTestApp(
            child: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => requestWidgetAccess(context),
                      child: const Text('Open Widgets'),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // When: requestWidgetAccess is called
        await tester.tap(find.text('Open Widgets'));
        await tester.pumpAndSettle();

        // Then: WidgetsScreen is NOT presented; paywall sheet is presented
        expect(find.byType(WidgetsScreen), findsNothing);
        expect(find.byType(PremiumGateSheet), findsOneWidget);
      },
    );

    testWidgets(
      '3. Free user request does not mutate entitlement state',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        expect(entitlementManager.isPremiumActive, isFalse);
        expect(entitlementManager.currentEntitlement.status,
            equals(EntitlementStatus.none));

        await tester.pumpWidget(
          buildTestApp(
            child: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => requestWidgetAccess(context),
                      child: const Text('Trigger Gate'),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // When: Paywall is presented
        await tester.tap(find.text('Trigger Gate'));
        await tester.pumpAndSettle();
        expect(find.byType(PremiumGateSheet), findsOneWidget);

        // Then: Entitlement state is still unentitled
        expect(entitlementManager.isPremiumActive, isFalse);
        expect(entitlementManager.currentEntitlement.status,
            equals(EntitlementStatus.none));
      },
    );

    testWidgets(
      '4. Gate specifically queries PremiumFeature.widgets and renders widget benefits',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          buildTestApp(
            child: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => requestWidgetAccess(context),
                      child: const Text('Request Widgets'),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Request Widgets'));
        await tester.pumpAndSettle();

        // Verify exact widget presentation metadata
        final presentation =
            PremiumFeaturePresentation.forFeature(PremiumFeature.widgets);
        expect(find.text(presentation.categoryTag), findsOneWidget);
        expect(find.text(presentation.headline), findsOneWidget);
        expect(find.text(presentation.description), findsOneWidget);

        for (final benefit in presentation.benefits) {
          expect(find.text(benefit), findsOneWidget);
        }
      },
    );

    testWidgets(
      '5. Premium user allowed: requestWidgetAccess navigates to WidgetsScreen',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Given: Premium active entitlement
        await entitlementManager.updateEntitlement(
          PremiumEntitlement.active(productId: premiumLifetimeProductId),
        );
        final access = DefaultFeatureAccess(entitlementManager);
        expect(access.canAccess(PremiumFeature.widgets), isTrue);

        await tester.pumpWidget(
          buildTestApp(
            child: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => requestWidgetAccess(context),
                      child: const Text('Go to Widgets'),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // When: requestWidgetAccess is called
        await tester.tap(find.text('Go to Widgets'));
        await tester.pumpAndSettle();

        // Then: WidgetsScreen is presented without any paywall
        expect(find.byType(PremiumGateSheet), findsNothing);
        expect(find.byType(WidgetsScreen), findsOneWidget);
        expect(find.text('Home Screen Widgets'), findsOneWidget);
        expect(find.text('Quick Capture'), findsOneWidget);
        expect(find.text('Pinned Single Note'), findsOneWidget);
        expect(find.text('Multi-Task Overview'), findsOneWidget);
        expect(find.text('Priority Task'), findsOneWidget);
        expect(find.text('How to Add to Home Screen'), findsOneWidget);
      },
    );

    testWidgets(
      '6. Purchase unlock propagation: reactively allows immediate widget access',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Step 1: Start as free user
        final access = DefaultFeatureAccess(entitlementManager);
        expect(access.canAccess(PremiumFeature.widgets), isFalse);

        await tester.pumpWidget(
          buildTestApp(
            child: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => requestWidgetAccess(context),
                      child: const Text('Access Widgets'),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tapping opens paywall
        await tester.tap(find.text('Access Widgets'));
        await tester.pumpAndSettle();
        expect(find.byType(PremiumGateSheet), findsOneWidget);

        // Dismiss paywall
        await tester.tap(find.text('Maybe Later'));
        await tester.pumpAndSettle();
        expect(find.byType(PremiumGateSheet), findsNothing);

        // Step 2: Grant lifetime premium purchase
        await entitlementManager.updateEntitlement(
          PremiumEntitlement.active(productId: premiumLifetimeProductId),
        );
        expect(access.canAccess(PremiumFeature.widgets), isTrue);

        // Step 3: Tapping again immediately grants access to WidgetsScreen
        await tester.tap(find.text('Access Widgets'));
        await tester.pumpAndSettle();

        expect(find.byType(WidgetsScreen), findsOneWidget);
        expect(find.byType(PremiumGateSheet), findsNothing);
      },
    );

    testWidgets(
      '7. Gate dismissal: dismissing via Maybe Later leaves entitlement unchanged',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        expect(entitlementManager.isPremiumActive, isFalse);

        await tester.pumpWidget(
          buildTestApp(
            child: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => requestWidgetAccess(context),
                      child: const Text('Open Gate'),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Gate'));
        await tester.pumpAndSettle();
        expect(find.byType(PremiumGateSheet), findsOneWidget);

        // Dismiss via "Maybe Later"
        await tester.tap(find.text('Maybe Later'));
        await tester.pumpAndSettle();

        expect(find.byType(PremiumGateSheet), findsNothing);
        expect(entitlementManager.isPremiumActive, isFalse);
      },
    );

    testWidgets(
      '8. Multiple widget entry points route through the same authoritative gate',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Both SettingsScreen Widgets tile and direct requestWidgetAccess route through FeatureAccess
        await tester.pumpWidget(
          buildTestApp(child: const SettingsScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Widgets'), findsOneWidget);
        expect(find.text('✦ PREMIUM'), findsOneWidget);

        await tester.tap(find.text('Widgets'));
        await tester.pumpAndSettle();

        expect(find.byType(PremiumGateSheet), findsOneWidget);
        expect(find.text('HOME SCREEN WIDGETS'), findsOneWidget);
      },
    );

    test(
      '9. Existing widget infrastructure & snapshot generation remains intact',
      () {
        final adapter = WidgetDataAdapter.custom(
          saveData: (key, value) async => true,
          updateWidget: ({name, androidName, iOSName, qualifiedAndroidName}) async =>
              true,
        );

        final note = Note(
          id: 'n-1',
          title: 'Test Note',
          content: 'Important content',
          colorValue: 0xFFFFFFFF,
          isPinned: true,
          tags: const [],
          attachments: const [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final task = TaskItem(
          id: 't-1',
          title: 'Priority Task',
          dueDate: DateTime.now(),
          priority: 'high',
          status: TaskStatus.waiting,
          completed: false,
          isDeleted: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final snapshot = adapter.buildSnapshot(
          notes: [note],
          tasks: [task],
          hasActiveSession: true,
        );

        expect(snapshot.pinnedNotesCount, equals(1));
        expect(snapshot.pendingTasksCount, equals(1));
        expect(snapshot.hasActiveSession, isTrue);
      },
    );

    testWidgets(
      '10. Core Notes/Tasks functionality remains 100% free without paywall',
      (tester) async {
        final access = DefaultFeatureAccess(entitlementManager);
        expect(access.canAccess(PremiumFeature.widgets), isFalse);

        // Core data operations and views execute freely
        expect(notesProvider.notes, isEmpty);
        expect(tasksProvider.tasks, isEmpty);
      },
    );

    test(
      '11. WidgetDataAdapter synchronization remains independent of Premium',
      () async {
        final adapter = WidgetDataAdapter.custom(
          saveData: (key, value) async => true,
          updateWidget: ({name, androidName, iOSName, qualifiedAndroidName}) async =>
              true,
        );

        final result = await adapter.sync(
          notes: [],
          tasks: [],
          hasActiveSession: false,
        );

        expect(result, isTrue);
      },
    );

    testWidgets(
      '12. No bypass: FeatureAccess is the single authoritative decider',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final mockAccess = DefaultFeatureAccess(entitlementManager);
        expect(mockAccess.canAccess(PremiumFeature.widgets), isFalse);

        await tester.pumpWidget(
          buildTestApp(
            customAccess: mockAccess,
            child: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => requestWidgetAccess(context),
                      child: const Text('Test Bypass'),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Test Bypass'));
        await tester.pumpAndSettle();

        expect(find.byType(PremiumGateSheet), findsOneWidget);
        expect(find.byType(WidgetsScreen), findsNothing);
      },
    );
  });
}
