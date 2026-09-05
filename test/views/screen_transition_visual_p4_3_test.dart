import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quick_notes/core/animations/page_transitions.dart';
import 'package:quick_notes/core/motion/motion_constants.dart';
import 'package:quick_notes/models/folder.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/premium/premium.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/providers/settings_provider.dart';
import 'package:quick_notes/providers/tasks_provider.dart';
import 'package:quick_notes/views/screens/folder_management_screen.dart'
    hide FolderGridCard;
import 'package:quick_notes/views/screens/folder_notes_screen.dart';
import 'package:quick_notes/views/screens/note_editor_screen.dart';
import 'package:quick_notes/views/screens/search_screen.dart';
import 'package:quick_notes/views/widgets/folder_card.dart';
import 'package:quick_notes/views/widgets/living_writing_experience.dart';
import 'package:quick_notes/views/widgets/notes_stack_widget.dart';

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

  @override
  List<Folder> get folders => _testFolders;

  @override
  List<Note> get allActiveNotes => _testNotes;

  void addTestFolder(Folder folder) {
    _testFolders.add(folder);
    notifyListeners();
  }

  void addTestNote(Note note) {
    _testNotes.add(note);
    notifyListeners();
  }
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

Note _createTestNote({
  required String id,
  String title = 'Test Note Title',
  String content = 'Test note body content',
  String category = 'Personal',
  String? folderId,
}) {
  return Note(
    id: id,
    title: title,
    content: content,
    category: category,
    folderId: folderId,
    createdAt: DateTime(2026, 1, 1, 10, 0),
    updatedAt: DateTime(2026, 1, 1, 12, 0),
    colorValue: 0xFFFFFF,
    tags: const [],
    attachments: const [],
  );
}

Widget _buildHarness({
  required Widget child,
  required NavigatorObserver navObserver,
  NotesProvider? notesProvider,
  SettingsProvider? settingsProvider,
  PremiumEntitlementManager? entitlementManager,
  bool disableAnimations = false,
}) {
  final entMgr = entitlementManager ?? PremiumEntitlementManager();
  final stgPrv = settingsProvider ?? SettingsProvider();
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

  group('Phase P4.3 — Screen & Document Transition Visual Polish Tests', () {
    // ── TEST 1: Search Folder uses standard page transition ───────────────────
    testWidgets(
        'TEST 1: Search folder result navigates via buildPageRoute and NOT FolderMorphPageRoute(Rect.zero)',
        (tester) async {
      final notesProvider = _TestNotesProvider();
      final testFolder = _createTestFolder(
        id: 'work_folder_p4_3',
        name: 'Work Projects',
      );
      notesProvider.addTestFolder(testFolder);

      final navObserver = _RouteTypeObserver();

      await tester.pumpWidget(
        _buildHarness(
          navObserver: navObserver,
          notesProvider: notesProvider,
          child: const SearchScreen(initialScope: 'all'),
        ),
      );
      await tester.pumpAndSettle();

      // Enter query to trigger folder search results
      await tester.enterText(find.byType(TextField), 'Work');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      final folderCardFinder = find.byType(FolderGridCard);
      expect(
        folderCardFinder,
        findsOneWidget,
        reason: 'SearchScreen must render FolderGridCard for matching folder',
      );

      // Tap folder search result
      await tester.tap(folderCardFinder);
      await tester.pump();

      // Verify the pushed route
      expect(
        navObserver.pushedRoutes.length,
        greaterThanOrEqualTo(2),
        reason: 'Navigator should have pushed a destination route',
      );

      final pushedRoute = navObserver.pushedRoutes.last;

      // Assert it is the standard QuickNotesPageRoute and NOT FolderMorphPageRoute
      expect(
        pushedRoute,
        isA<QuickNotesPageRoute<dynamic>>(),
        reason: 'Search folder result must use QuickNotesPageRoute',
      );
      expect(
        pushedRoute,
        isNot(isA<FolderMorphPageRoute<dynamic>>()),
        reason:
            'Search folder result must NOT use FolderMorphPageRoute (resolves P4-DEF-10)',
      );

      final qRoute = pushedRoute as QuickNotesPageRoute<dynamic>;
      expect(
        qRoute.normalTransitionDuration,
        equals(QuickNotesMotion.kMotionPage),
        reason: 'Standard forward duration must be 340ms',
      );
      expect(
        qRoute.normalReverseTransitionDuration,
        equals(QuickNotesMotion.kMotionPageReverse),
        reason: 'Standard reverse duration must be 260ms',
      );

      await tester.pumpAndSettle();
      expect(
        find.byType(FolderNotesScreen),
        findsOneWidget,
        reason: 'Destination must successfully render FolderNotesScreen',
      );
    });

    // ── TEST 2: Search result transition consistency ──────────────────────────
    testWidgets(
        'TEST 2: All Search result navigations share the standard page transition foundation',
        (tester) async {
      final testFolder = _createTestFolder(
        id: 'f_consistency',
        name: 'Design Assets',
      );
      final testNote = _createTestNote(
        id: 'n_consistency',
        title: 'Design Guidelines',
      );

      final folderRoute = buildPageRoute<void>(
        FolderNotesScreen(folder: testFolder),
      );
      final noteRoute = buildPageRoute<void>(
        NoteEditorScreen(note: testNote),
      );

      expect(folderRoute, isA<QuickNotesPageRoute<void>>());
      expect(noteRoute, isA<QuickNotesPageRoute<void>>());

      final qFolder = folderRoute as QuickNotesPageRoute<void>;
      final qNote = noteRoute as QuickNotesPageRoute<void>;

      // Both folder and note routes must have identical timing and curves
      expect(qFolder.normalTransitionDuration, equals(qNote.normalTransitionDuration));
      expect(qFolder.normalReverseTransitionDuration,
          equals(qNote.normalReverseTransitionDuration));
      expect(qFolder.normalTransitionDuration, equals(QuickNotesMotion.kMotionPage));
      expect(qFolder.normalReverseTransitionDuration,
          equals(QuickNotesMotion.kMotionPageReverse));
    });

    // ── TEST 3: Search Folder reduced motion ──────────────────────────────────
    testWidgets(
        'TEST 3: Search -> FolderNotesScreen under disableAnimations: true presents immediately',
        (tester) async {
      final notesProvider = _TestNotesProvider();
      final testFolder = _createTestFolder(
        id: 'reduced_motion_folder',
        name: 'Finance Folder',
      );
      notesProvider.addTestFolder(testFolder);

      final navObserver = _RouteTypeObserver();

      await tester.pumpWidget(
        _buildHarness(
          navObserver: navObserver,
          notesProvider: notesProvider,
          disableAnimations: true,
          child: const SearchScreen(initialScope: 'all'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Finance');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      final folderCardFinder = find.byType(FolderGridCard);
      expect(folderCardFinder, findsOneWidget);

      await tester.tap(folderCardFinder);
      await tester.pump();

      final pushedRoute = navObserver.pushedRoutes.last;
      expect(pushedRoute, isA<QuickNotesPageRoute<dynamic>>());

      final qRoute = pushedRoute as QuickNotesPageRoute<dynamic>;
      // Under disableAnimations, duration must evaluate to zero
      expect(
        qRoute.transitionDuration,
        equals(Duration.zero),
        reason:
            'QuickNotesPageRoute must return Duration.zero when disableAnimations is true',
      );
      expect(
        qRoute.reverseTransitionDuration,
        equals(Duration.zero),
        reason:
            'QuickNotesPageRoute must return Duration.zero for reverse when disableAnimations is true',
      );

      await tester.pumpAndSettle();
      expect(find.byType(FolderNotesScreen), findsOneWidget);
    });

    // ── TEST 4: Folder Management morph preservation ─────────────────────────
    testWidgets(
        'TEST 4: FolderManagementScreen preserves legitimate FolderMorphPageRoute with measured bounds',
        (tester) async {
      final notesProvider = _TestNotesProvider();
      final testFolder = _createTestFolder(
        id: 'fm_morph_folder',
        name: 'Photography',
      );
      notesProvider.addTestFolder(testFolder);

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

      final folderCardFinder = find.text('Photography');
      expect(folderCardFinder, findsOneWidget);

      // Tap the folder in FolderManagementScreen
      await tester.tap(folderCardFinder);
      // Wait for the tap press-lift animation delay (150ms in _handleFolderTap)
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        navObserver.pushedRoutes.length,
        greaterThanOrEqualTo(2),
      );

      final pushedRoute = navObserver.pushedRoutes.last;

      // Legitimate FolderManagementScreen tap must retain FolderMorphPageRoute
      expect(
        pushedRoute,
        isA<FolderMorphPageRoute<dynamic>>(),
        reason:
            'FolderManagementScreen must preserve FolderMorphPageRoute for folder card morphs',
      );

      final morphRoute = pushedRoute as FolderMorphPageRoute<dynamic>;
      // Assert that cardBounds are NOT zero (valid measured screen bounds)
      expect(
        morphRoute.cardBounds,
        isNot(equals(Rect.zero)),
        reason: 'FolderManagementScreen morph must use valid non-zero card bounds',
      );

      await tester.pumpAndSettle();
      expect(find.byType(FolderNotesScreen), findsOneWidget);
    });

    // ── TEST 5: Home document opening regression ─────────────────────────────
    testWidgets(
        'TEST 5: Home -> NoteEditor preserves buildNoteOpeningPageRoute and Hero choreography',
        (tester) async {
      const testId = 'home_doc_regression_001';
      final note = _createTestNote(id: testId, title: 'Home Deck Note');

      // 1. Verify buildNoteOpeningPageRoute token contract
      final route = buildNoteOpeningPageRoute<void>(
        NoteEditorScreen(note: note),
      );
      expect(route, isA<QuickNotesPageRoute<void>>());

      final qRoute = route as QuickNotesPageRoute<void>;
      expect(qRoute.normalTransitionDuration, equals(QuickNotesMotion.kMotionPage));
      expect(qRoute.normalReverseTransitionDuration,
          equals(QuickNotesMotion.kMotionPageReverse));

      // 2. Verify source Hero tag
      final navObserver = _RouteTypeObserver();
      await tester.pumpWidget(
        _buildHarness(
          navObserver: navObserver,
          child: Scaffold(
            body: Center(
              child: NotesStackWidget(
                notes: [note],
                onEdit: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      final sourceHeroFinder = find.byWidgetPredicate(
        (w) => w is Hero && w.tag == 'hero_note_card_$testId',
      );
      expect(
        sourceHeroFinder,
        findsOneWidget,
        reason: 'NotesStackWidget must declare hero_note_card_$testId',
      );

      // 3. Verify destination Hero tag
      await tester.pumpWidget(
        _buildHarness(
          navObserver: navObserver,
          child: NoteEditorScreen(note: note),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final destHeroFinder = find.byWidgetPredicate(
        (w) => w is Hero && w.tag == 'hero_note_card_$testId',
      );
      expect(
        destHeroFinder,
        findsOneWidget,
        reason: 'NoteEditorScreen must declare matching hero_note_card_$testId',
      );
    });
  });
}
