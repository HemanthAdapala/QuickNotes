// ─────────────────────────────────────────────────────────────────────────────
// folder_transition_canonical_d5_fn3_test.dart
// Phase D5-FN-3 — Folder Open/Close Transition Surgical Implementation Tests
//
// Regression tests covering:
//  • TEST A: No artificial 150ms delay — navigation begins on first pump
//  • TEST B: Canonical route — FolderNotesScreen opens via QuickNotesPageRoute (340ms/260ms)
//  • TEST C: No navy flash — Dark Mode transition introduces zero #1A1C2E overlay frames
//  • TEST D: Reverse transition — route pops cleanly back to FolderManagementScreen
//  • TEST E: Reduced motion — immediate presentation with Duration.zero under disableAnimations
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quick_notes/core/animations/page_transitions.dart';
import 'package:quick_notes/core/motion/motion_constants.dart';
import 'package:quick_notes/models/folder.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/models/note_summary.dart';
import 'package:quick_notes/premium/premium.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/providers/settings_provider.dart';
import 'package:quick_notes/providers/tasks_provider.dart';
import 'package:quick_notes/views/screens/folder_management_screen.dart'
    hide FolderGridCard;
import 'package:quick_notes/views/screens/folder_notes_screen.dart';
import 'package:quick_notes/views/widgets/folder_card.dart';
import 'package:quick_notes/views/widgets/living_writing_experience.dart';

class _RouteTypeObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushedRoutes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    pushedRoutes.add(route);
  }
}

class _TestNotesProvider extends NotesProvider {
  final List<Folder> _testFolders = [];
  final List<Note> _testNotes = [];
  final List<NoteSummary> _testSummaries = [];

  @override
  List<Folder> get folders => _testFolders;

  @override
  List<Note> get allActiveNotes => _testNotes;

  @override
  List<NoteSummary> get notesSummary => _testSummaries;

  void addTestFolder(Folder folder) {
    _testFolders.add(folder);
    notifyListeners();
  }

  @override
  Future<void> setSelectedFolder(String? id) async {}

  @override
  bool get isVaultUnlocked => false;
}

Folder _createTestFolder({
  required String id,
  required String name,
}) {
  return Folder(
    id: id,
    name: name,
    createdAt: DateTime(2026, 1, 1, 10, 0),
  );
}

Widget _buildHarness({
  required Widget child,
  required NavigatorObserver navObserver,
  NotesProvider? notesProvider,
  bool isDark = false,
  bool disableAnimations = false,
}) {
  final entMgr = PremiumEntitlementManager();
  final stgPrv = SettingsProvider();
  final ntsPrv = notesProvider ?? _TestNotesProvider();

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<PremiumEntitlementManager>.value(value: entMgr),
      ProxyProvider<PremiumEntitlementManager, FeatureAccess>(
        update: (_, manager, __) => DefaultFeatureAccess(manager),
      ),
      ChangeNotifierProvider<SettingsProvider>.value(value: stgPrv),
      ChangeNotifierProvider<NotesProvider>.value(value: ntsPrv),
      ChangeNotifierProvider<TasksProvider>(create: (_) => TasksProvider()),
    ],
    child: MaterialApp(
      theme: isDark
          ? ThemeData.dark().copyWith(
              cardColor: const Color(0xFF1A1C2E),
              scaffoldBackgroundColor: const Color(0xFF1E1E1E),
            )
          : ThemeData.light(),
      navigatorObservers: [navObserver],
      builder: (context, widget) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: disableAnimations,
          ),
          child: widget!,
        );
      },
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase D5-FN-3 — Folder Open/Close Transition Surgical Verification',
      () {
    // ── TEST A: No artificial 150ms delay ────────────────────────────────────
    testWidgets(
        'TEST A: Navigation begins immediately upon folder tap without 150ms delay',
        (tester) async {
      final notesProvider = _TestNotesProvider();
      notesProvider.addTestFolder(
        _createTestFolder(id: 'folder_a', name: 'Design Archive'),
      );
      final navObserver = _RouteTypeObserver();

      await tester.pumpWidget(
        _buildHarness(
          navObserver: navObserver,
          notesProvider: notesProvider,
          child: FolderManagementScreen(
            onMenuTap: () {},
            onNavigateToTab: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final folderCardFinder = find.byType(FolderGridCard);
      expect(folderCardFinder, findsOneWidget);

      // Initial route state: only the home route
      expect(navObserver.pushedRoutes.length, equals(1));

      // Tap the folder
      await tester.tap(folderCardFinder);

      // Verify route begins immediately on the very first pump (0ms artificial delay)
      await tester.pump();

      expect(
        navObserver.pushedRoutes.length,
        equals(2),
        reason:
            'Route must be pushed immediately on first pump without awaiting 150ms',
      );

      final pushedRoute = navObserver.pushedRoutes.last;
      expect(pushedRoute, isA<QuickNotesPageRoute<dynamic>>());

      // Advance through animation to settle
      await tester.pumpAndSettle();
      expect(find.byType(FolderNotesScreen), findsOneWidget);
    });

    // ── TEST B: Canonical route verification ─────────────────────────────────
    testWidgets(
        'TEST B: Opens FolderNotesScreen via canonical buildPageRoute (340ms/260ms, AppleEase)',
        (tester) async {
      final notesProvider = _TestNotesProvider();
      notesProvider.addTestFolder(
        _createTestFolder(id: 'folder_b', name: 'Personal Records'),
      );
      final navObserver = _RouteTypeObserver();

      await tester.pumpWidget(
        _buildHarness(
          navObserver: navObserver,
          notesProvider: notesProvider,
          child: FolderManagementScreen(
            onMenuTap: () {},
            onNavigateToTab: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FolderGridCard));
      await tester.pump();

      final pushedRoute = navObserver.pushedRoutes.last;

      // Must be canonical QuickNotesPageRoute
      expect(
        pushedRoute,
        isA<QuickNotesPageRoute<dynamic>>(),
        reason: 'Must use canonical QuickNotesPageRoute',
      );

      // Must NOT be FolderMorphPageRoute
      expect(
        pushedRoute,
        isNot(isA<FolderMorphPageRoute<dynamic>>()),
        reason: 'FolderMorphPageRoute must not be used (resolves DEF-01)',
      );

      final qRoute = pushedRoute as QuickNotesPageRoute<dynamic>;
      expect(
        qRoute.normalTransitionDuration,
        equals(QuickNotesMotion.kMotionPage),
        reason:
            'Forward duration must equal QuickNotesMotion.kMotionPage (340ms)',
      );
      expect(
        qRoute.normalReverseTransitionDuration,
        equals(QuickNotesMotion.kMotionPageReverse),
        reason:
            'Reverse duration must equal QuickNotesMotion.kMotionPageReverse (260ms)',
      );

      await tester.pumpAndSettle();
      expect(find.byType(FolderNotesScreen), findsOneWidget);
    });

    // ── TEST C: No navy flash under Dark Mode ────────────────────────────────
    testWidgets(
        'TEST C: Under Dark Mode, transition introduces zero #1A1C2E overlay frames',
        (tester) async {
      final notesProvider = _TestNotesProvider();
      notesProvider.addTestFolder(
        _createTestFolder(id: 'folder_c', name: 'Dark Mode Folder'),
      );
      final navObserver = _RouteTypeObserver();

      await tester.pumpWidget(
        _buildHarness(
          navObserver: navObserver,
          notesProvider: notesProvider,
          isDark: true,
          child: FolderManagementScreen(
            onMenuTap: () {},
            onNavigateToTab: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FolderGridCard));
      await tester.pump();

      // Sample intermediate frames across the 340ms transition duration
      const sampleDurations = [
        Duration(milliseconds: 50),
        Duration(milliseconds: 100),
        Duration(milliseconds: 170),
        Duration(milliseconds: 250),
      ];

      for (final duration in sampleDurations) {
        await tester.pump(duration);

        // Verify that NO widget in the tree has a BoxDecoration with Color(0xFF1A1C2E)
        // serving as a transition aperture or background overlay
        final navyBoxes =
            tester.widgetList<DecoratedBox>(find.byWidgetPredicate((widget) {
          if (widget is DecoratedBox) {
            final decoration = widget.decoration;
            if (decoration is BoxDecoration &&
                decoration.color == const Color(0xFF1A1C2E)) {
              return true;
            }
          }
          return false;
        }));

        expect(
          navyBoxes,
          isEmpty,
          reason:
              'No #1A1C2E transition overlay should exist during transition (resolves DEF-03)',
        );
      }

      await tester.pumpAndSettle();
      expect(find.byType(FolderNotesScreen), findsOneWidget);
    });

    // ── TEST D: Reverse transition and pop restoration ───────────────────────
    testWidgets(
        'TEST D: Reverse transition pops smoothly and restores FolderManagementScreen',
        (tester) async {
      final notesProvider = _TestNotesProvider();
      notesProvider.addTestFolder(
        _createTestFolder(id: 'folder_d', name: 'Back Navigation Test'),
      );
      final navObserver = _RouteTypeObserver();

      await tester.pumpWidget(
        _buildHarness(
          navObserver: navObserver,
          notesProvider: notesProvider,
          child: FolderManagementScreen(
            onMenuTap: () {},
            onNavigateToTab: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open folder
      await tester.tap(find.byType(FolderGridCard));
      await tester.pumpAndSettle();

      expect(find.byType(FolderNotesScreen), findsOneWidget);

      // Trigger pop via Navigator.of(context).maybePop()
      final navigatorContext = tester.element(find.byType(FolderNotesScreen));
      Navigator.of(navigatorContext).maybePop();

      // Pump partially through reverse transition (e.g. 130ms of 260ms)
      await tester.pump(const Duration(milliseconds: 130));

      // Route is reversing; FolderManagementScreen is animating back
      expect(find.byType(FolderManagementScreen), findsOneWidget);

      // Complete reverse transition
      await tester.pumpAndSettle();

      // FolderNotesScreen is dismissed, FolderManagementScreen is restored
      expect(find.byType(FolderNotesScreen), findsNothing);
      expect(find.byType(FolderManagementScreen), findsOneWidget);

      // Verify folder can be tapped again (confirms _tappedFolderId was reset to null on pop)
      await tester.tap(find.byType(FolderGridCard));
      await tester.pump();

      expect(
        navObserver.pushedRoutes.length,
        equals(3),
        reason:
            'Folder should be tappable again after reverse transition completes',
      );

      await tester.pumpAndSettle();
      expect(find.byType(FolderNotesScreen), findsOneWidget);
    });

    // ── TEST E: Reduced motion contract ──────────────────────────────────────
    testWidgets(
        'TEST E: Reduced motion presents FolderNotesScreen immediately with Duration.zero',
        (tester) async {
      final notesProvider = _TestNotesProvider();
      notesProvider.addTestFolder(
        _createTestFolder(id: 'folder_e', name: 'Accessibility Folder'),
      );
      final navObserver = _RouteTypeObserver();

      await tester.pumpWidget(
        _buildHarness(
          navObserver: navObserver,
          notesProvider: notesProvider,
          disableAnimations: true,
          child: FolderManagementScreen(
            onMenuTap: () {},
            onNavigateToTab: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FolderGridCard));
      await tester.pump();

      final pushedRoute = navObserver.pushedRoutes.last;
      expect(pushedRoute, isA<QuickNotesPageRoute<dynamic>>());

      final qRoute = pushedRoute as QuickNotesPageRoute<dynamic>;
      // Under disableAnimations, transitionDuration reports Duration.zero
      expect(
        qRoute.transitionDuration,
        equals(Duration.zero),
        reason:
            'Route transition duration must be zero when disableAnimations is true',
      );

      // Destination is presented immediately
      expect(
        find.byType(FolderNotesScreen),
        findsOneWidget,
        reason:
            'FolderNotesScreen must be immediately presented under reduced motion',
      );
    });
  });
}
