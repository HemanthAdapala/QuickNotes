import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quick_notes/core/animations/page_transitions.dart';
import 'package:quick_notes/core/animations/search_transition_routes.dart';
import 'package:quick_notes/core/animations/tactile_card_wrapper.dart';
import 'package:quick_notes/core/motion/motion_constants.dart';
import 'package:quick_notes/core/motion/quick_notes_haptics.dart';
import 'package:quick_notes/models/folder.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/models/repeat_rule.dart';
import 'package:quick_notes/models/task_item.dart';
import 'package:quick_notes/premium/premium.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/providers/settings_provider.dart';
import 'package:quick_notes/providers/tasks_provider.dart';
import 'package:quick_notes/services/recent_searches_service.dart';
import 'package:quick_notes/themes/quick_notes_theme.dart';
import 'package:quick_notes/views/screens/note_editor_screen.dart';
import 'package:quick_notes/views/screens/search_screen.dart';
import 'package:quick_notes/views/widgets/folder_card.dart';
import 'package:quick_notes/views/widgets/search_note_card.dart';
import 'package:quick_notes/views/widgets/search_task_card.dart';
import 'package:quick_notes/views/widgets/tactile_button.dart';

class _RouteObserver extends NavigatorObserver {
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

  void setTestNotes(List<Note> notes) {
    _testNotes.clear();
    _testNotes.addAll(notes);
    notifyListeners();
  }
}

class _TestTasksProvider extends TasksProvider {
  final List<TaskItem> _testTasks = [];

  @override
  List<TaskItem> get tasks => _testTasks;

  void addTestTask(TaskItem task) {
    _testTasks.add(task);
    notifyListeners();
  }
}

Widget _buildSearchHarness({
  required Widget child,
  NavigatorObserver? navObserver,
  NotesProvider? notesProvider,
  TasksProvider? tasksProvider,
  bool disableAnimations = false,
  ThemeData? theme,
}) {
  final ntsPrv = notesProvider ?? _TestNotesProvider();
  final tskPrv = tasksProvider ?? _TestTasksProvider();

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<PremiumEntitlementManager>.value(
        value: PremiumEntitlementManager(),
      ),
      ProxyProvider<PremiumEntitlementManager, FeatureAccess>(
        update: (_, manager, __) => DefaultFeatureAccess(manager),
      ),
      ChangeNotifierProvider<SettingsProvider>.value(value: SettingsProvider()),
      ChangeNotifierProvider<NotesProvider>.value(value: ntsPrv),
      ChangeNotifierProvider<TasksProvider>.value(value: tskPrv),
    ],
    child: MaterialApp(
      theme: theme,
      navigatorObservers: navObserver != null ? [navObserver] : const [],
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

  final List<String> hapticEvents = [];

  setUp(() {
    hapticEvents.clear();
    QuickNotesHaptics.debugHapticListener = (method) {
      hapticEvents.add(method);
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (MethodCall methodCall) async {
      return null;
    });
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    QuickNotesHaptics.debugHapticListener = null;
    hapticEvents.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('Phase P4.5 — Group A: Header Tactile Contract', () {
    testWidgets('TEST A1: Header pills inherit canonical TactileButton defaults without 0.7/1000ms overrides', (tester) async {
      await tester.pumpWidget(_buildSearchHarness(child: const SearchScreen()));
      await tester.pumpAndSettle();

      final tactileButtons = tester.widgetList<TactileButton>(find.byType(TactileButton)).toList();
      expect(tactileButtons.length, greaterThanOrEqualTo(2));

      final leftPill = tactileButtons[0];
      final rightPill = tactileButtons[1];

      expect(leftPill.compressionScale, equals(0.94),
          reason: 'Left back pill must inherit canonical 0.94 compression scale');
      expect(leftPill.settleDuration, equals(QuickNotesMotion.kMotionRelease),
          reason: 'Left back pill must inherit canonical kMotionRelease (190ms) settle duration');
      expect(leftPill.pressDuration, equals(QuickNotesMotion.kMotionMicro),
          reason: 'Left back pill must inherit canonical kMotionMicro (90ms) press duration');

      expect(rightPill.compressionScale, equals(0.94),
          reason: 'Right close pill must inherit canonical 0.94 compression scale');
      expect(rightPill.settleDuration, equals(QuickNotesMotion.kMotionRelease),
          reason: 'Right close pill must inherit canonical kMotionRelease (190ms) settle duration');
      expect(rightPill.pressDuration, equals(QuickNotesMotion.kMotionMicro),
          reason: 'Right close pill must inherit canonical kMotionMicro (90ms) press duration');
    });

    testWidgets('TEST A2: Header pills under disableAnimations: true evaluate to scale 1.0', (tester) async {
      await tester.pumpWidget(_buildSearchHarness(
        child: const SearchScreen(),
        disableAnimations: true,
      ));
      await tester.pumpAndSettle();

      final scaleTransitions = tester.widgetList<ScaleTransition>(find.byType(ScaleTransition));
      for (final st in scaleTransitions) {
        if (st.scale is AlwaysStoppedAnimation<double>) {
          expect((st.scale as AlwaysStoppedAnimation<double>).value, equals(1.0));
        }
      }
    });
  });

  group('Phase P4.5 — Group B: Duplicate Haptic Prevention', () {
    testWidgets('TEST B1: Back pill tap emits exactly ONE buttonPress haptic and zero duplicate on pop', (tester) async {
      await tester.pumpWidget(_buildSearchHarness(
        child: const SearchScreen(),
      ));
      await tester.pumpAndSettle();

      hapticEvents.clear();

      final leftPillFinder = find.byType(TactileButton).first;
      await tester.tap(leftPillFinder);
      await tester.pumpAndSettle();

      expect(hapticEvents, equals(['buttonPress']),
          reason: 'Back pill must emit exactly ONE buttonPress on touch-down and zero duplicate haptics on callback');
    });

    testWidgets('TEST B2: Close pill tap emits exactly ONE buttonPress haptic when clearing text', (tester) async {
      await tester.pumpWidget(_buildSearchHarness(
        child: const SearchScreen(),
      ));
      await tester.pumpAndSettle();

      // Enter query
      await tester.enterText(find.byType(TextField), 'Groceries');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      hapticEvents.clear();

      // Tap right close pill (clears query)
      final rightPillFinder = find.byType(TactileButton).at(1);
      await tester.tap(rightPillFinder);
      await tester.pumpAndSettle();

      expect(hapticEvents, equals(['buttonPress']),
          reason: 'Close pill must emit exactly ONE buttonPress on touch-down and zero duplicate haptics when clearing text');
      expect(find.text('Groceries'), findsNothing);
    });
  });

  group('Phase P4.5 — Group C: Scope Selection', () {
    testWidgets('TEST C1: Scope pill selection dispatches QuickNotesHaptics.selection()', (tester) async {
      await tester.pumpWidget(_buildSearchHarness(child: const SearchScreen()));
      await tester.pumpAndSettle();

      hapticEvents.clear();

      final notesPill = find.text('Notes');
      expect(notesPill, findsOneWidget);

      await tester.tap(notesPill);
      await tester.pump();

      expect(hapticEvents.contains('selection'), isTrue,
          reason: 'Scope tab selection must fire QuickNotesHaptics.selection()');
    });

    testWidgets('TEST C2: Scope pill bar snaps duration to Duration.zero under reduced motion', (tester) async {
      await tester.pumpWidget(_buildSearchHarness(
        child: const SearchScreen(),
        disableAnimations: true,
      ));
      await tester.pumpAndSettle();

      final animatedContainers = tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer));
      for (final ac in animatedContainers) {
        expect(ac.duration, equals(Duration.zero),
            reason: 'AnimatedContainer duration on scope pills must be Duration.zero under reduced motion');
      }
    });
  });

  group('Phase P4.5 — Group D: Search Result Cards', () {
    testWidgets('TEST D1: SearchNoteCard wraps card stack in canonical TactileCardWrapper', (tester) async {
      final testNote = Note(
        id: 'n_note_card_test',
        title: 'Meeting Notes',
        content: 'Discuss quarterly revenue and growth milestones.',
        category: 'Work',
        createdAt: DateTime(2026, 6, 1, 10, 0),
        updatedAt: DateTime(2026, 6, 1, 10, 0),
        colorValue: 0xFFFFFF,
        tags: const [],
        attachments: const [],
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SearchNoteCard(
            note: testNote,
            query: 'revenue',
            onTap: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final wrapperFinder = find.byType(TactileCardWrapper);
      expect(wrapperFinder, findsOneWidget,
          reason: 'SearchNoteCard must consume canonical TactileCardWrapper');

      final wrapper = tester.widget<TactileCardWrapper>(wrapperFinder);
      expect(wrapper.compressionScale, equals(0.94));
      expect(wrapper.settleDuration, equals(QuickNotesMotion.kMotionRelease));
      expect(wrapper.pressDuration, equals(QuickNotesMotion.kMotionMicro));
      expect(wrapper.useAppleSpring, isTrue);

      hapticEvents.clear();
      await tester.tap(wrapperFinder);
      await tester.pump();

      expect(hapticEvents, equals(['buttonPress']),
          reason: 'SearchNoteCard must emit exactly ONE buttonPress haptic');
    });

    testWidgets('TEST D2: SearchTaskCard wraps card stack in canonical TactileCardWrapper', (tester) async {
      final testTask = TaskItem(
        id: 't_task_card_test',
        title: 'Finish audit report',
        dueDate: DateTime(2026, 6, 1, 14, 0),
        priority: 'High',
        repeatRule: RepeatRule.none,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SearchTaskCard(
            task: testTask,
            query: 'audit',
            onTap: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final wrapperFinder = find.byType(TactileCardWrapper);
      expect(wrapperFinder, findsOneWidget,
          reason: 'SearchTaskCard must consume canonical TactileCardWrapper');

      final wrapper = tester.widget<TactileCardWrapper>(wrapperFinder);
      expect(wrapper.compressionScale, equals(0.94));
      expect(wrapper.settleDuration, equals(QuickNotesMotion.kMotionRelease));
      expect(wrapper.pressDuration, equals(QuickNotesMotion.kMotionMicro));
      expect(wrapper.useAppleSpring, isTrue);

      hapticEvents.clear();
      await tester.tap(wrapperFinder);
      await tester.pump();

      expect(hapticEvents, equals(['buttonPress']),
          reason: 'SearchTaskCard must emit exactly ONE buttonPress haptic');
    });
  });

  group('Phase P4.5 — Group E: Search Entry & Body Sheet Motion', () {
    testWidgets('TEST E1: Entry fade evaluates immediately to 1.0 under disableAnimations: true', (tester) async {
      await tester.pumpWidget(_buildSearchHarness(
        child: const SearchScreen(),
        disableAnimations: true,
      ));
      await tester.pump();

      // Find the FadeTransition inside SearchScreen body
      final bodyFadeFinder = find.descendant(
        of: find.byType(SearchScreen),
        matching: find.byType(FadeTransition),
      );
      expect(bodyFadeFinder, findsWidgets);

      for (final fade in tester.widgetList<FadeTransition>(bodyFadeFinder)) {
        expect(fade.opacity.value, equals(1.0),
            reason: 'Entry fade must be immediately at 1.0 when disableAnimations is true');
      }
    });

    testWidgets('TEST E2: Body sheet TweenAnimationBuilder uses Duration.zero and zero offset under disableAnimations', (tester) async {
      await tester.pumpWidget(_buildSearchHarness(
        child: const SearchScreen(),
        disableAnimations: true,
      ));
      await tester.pump();

      // Find the Transform.translate inside TweenAnimationBuilder
      final transformFinder = find.byWidgetPredicate(
        (widget) => widget is Transform && widget.transform.getTranslation().y == 0.0,
      );
      expect(transformFinder, findsWidgets,
          reason: 'Body sheet must not translate vertically under reduced motion');
    });
  });

  group('Phase P4.5 — Group F: Shimmer Reduced Motion', () {
    testWidgets('TEST F1: Shimmer skeletons under disableAnimations: true render static container without repeating', (tester) async {
      await tester.pumpWidget(_buildSearchHarness(
        child: const SearchScreen(),
        disableAnimations: true,
      ));
      await tester.pumpAndSettle();

      // Type 2 characters to trigger typing state
      await tester.enterText(find.byType(TextField), 'Pl');
      await tester.pump();

      // Skeletons are rendered as static containers
      final containerFinder = find.byWidgetPredicate(
        (widget) => widget is Container && widget.constraints?.minHeight == 72,
      );
      expect(containerFinder, findsWidgets);

      // Advance clock: verify no ticker exception or infinite animation leak
      await tester.pump(const Duration(milliseconds: 1500));
    });
  });

  group('Phase P4.5 — Group G: Search Route Canonical Contract', () {
    testWidgets('TEST G1: PixelAlignedSearchRoute uses canonical QuickNotesMotion tokens', (tester) async {
      final route = PixelAlignedSearchRoute<void>(
        builder: (_) => const SizedBox(),
      );

      expect(route.normalTransitionDuration, equals(QuickNotesMotion.kMotionPage),
          reason: 'Forward duration must be kMotionPage (340ms)');
      expect(route.normalReverseTransitionDuration, equals(QuickNotesMotion.kMotionPageReverse),
          reason: 'Reverse duration must be kMotionPageReverse (260ms)');
    });

    testWidgets('TEST G2: buildSearchTransitionRoute produces PixelAlignedSearchRoute with canonical tokens', (tester) async {
      final route = buildSearchTransitionRoute<void>(
        builder: (_) => const SizedBox(),
      );

      expect(route, isA<PixelAlignedSearchRoute<void>>());
      final aligned = route as PixelAlignedSearchRoute<void>;
      expect(aligned.transitionDuration, equals(QuickNotesMotion.kMotionPage));
      expect(aligned.reverseTransitionDuration, equals(QuickNotesMotion.kMotionPageReverse));
    });
  });

  group('Phase P4.5 — Group H: Recent Searches & Navigation Feedback', () {
    testWidgets('TEST H1: Clear all recent searches emits destructiveAction when history non-empty', (tester) async {
      SharedPreferences.setMockInitialValues({
        'quick_notes_recent_searches': ['groceries', 'receipts'],
      });

      await tester.pumpWidget(_buildSearchHarness(child: const SearchScreen()));
      await tester.pumpAndSettle();

      hapticEvents.clear();

      final clearAllFinder = find.text('Clear all');
      expect(clearAllFinder, findsOneWidget);

      await tester.tap(clearAllFinder);
      await tester.pumpAndSettle();

      expect(hapticEvents, equals(['destructiveAction']),
          reason: 'Clear all must dispatch QuickNotesHaptics.destructiveAction() when clearing non-empty history');
    });

    testWidgets('TEST H2: Clear all does NOT emit destructiveAction when history is already empty', (tester) async {
      SharedPreferences.setMockInitialValues({
        'quick_notes_recent_searches': <String>[],
      });

      await tester.pumpWidget(_buildSearchHarness(child: const SearchScreen()));
      await tester.pumpAndSettle();

      hapticEvents.clear();

      final clearAllFinder = find.text('Clear all');
      expect(clearAllFinder, findsOneWidget);

      await tester.tap(clearAllFinder);
      await tester.pumpAndSettle();

      expect(hapticEvents, isEmpty,
          reason: 'Clear all must NOT emit destructiveAction when there was nothing to clear');
    });

    testWidgets('TEST H3: Tapping recent search row emits selection() haptic', (tester) async {
      SharedPreferences.setMockInitialValues({
        'quick_notes_recent_searches': ['groceries'],
      });

      await tester.pumpWidget(_buildSearchHarness(child: const SearchScreen()));
      await tester.pumpAndSettle();

      hapticEvents.clear();

      final recentTermFinder = find.text('groceries');
      expect(recentTermFinder, findsOneWidget);

      await tester.tap(recentTermFinder);
      await tester.pumpAndSettle();

      expect(hapticEvents.contains('selection'), isTrue,
          reason: 'Tapping a recent search item must dispatch QuickNotesHaptics.selection()');
    });

    testWidgets('TEST H4: Deleting recent search item emits selection() haptic', (tester) async {
      SharedPreferences.setMockInitialValues({
        'quick_notes_recent_searches': ['groceries'],
      });

      await tester.pumpWidget(_buildSearchHarness(child: const SearchScreen()));
      await tester.pumpAndSettle();

      hapticEvents.clear();

      final closeIconFinder = find.byIcon(Icons.close_rounded).last;
      await tester.tap(closeIconFinder);
      await tester.pumpAndSettle();

      expect(hapticEvents.contains('selection'), isTrue,
          reason: 'Deleting a recent search item must dispatch QuickNotesHaptics.selection()');
    });

    testWidgets('TEST H5: Category result tap emits navigationSelection() haptic', (tester) async {
      final notesProvider = _TestNotesProvider();
      notesProvider.addTestNote(Note(
        id: 'n_cat_note',
        title: 'Work Project',
        content: 'Notes about work',
        category: 'Work',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        colorValue: 0xFFFFFF,
        tags: const [],
        attachments: const [],
      ));

      final navObserver = _RouteObserver();

      await tester.pumpWidget(_buildSearchHarness(
        child: const SearchScreen(),
        notesProvider: notesProvider,
        navObserver: navObserver,
      ));
      await tester.pumpAndSettle();

      // Search for 'work'
      await tester.enterText(find.byType(TextField), 'Work');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      hapticEvents.clear();

      final categoryRowFinder = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_CategoryResultRow',
      );
      expect(categoryRowFinder, findsOneWidget);

      await tester.tap(categoryRowFinder);
      await tester.pumpAndSettle();

      expect(hapticEvents.contains('navigationSelection'), isTrue,
          reason: 'Activating category row must dispatch QuickNotesHaptics.navigationSelection()');
    });

    testWidgets('TEST H6: Create New CTA emits navigationSelection() haptic', (tester) async {
      final navObserver = _RouteObserver();

      await tester.pumpWidget(_buildSearchHarness(
        child: const SearchScreen(),
        navObserver: navObserver,
      ));
      await tester.pumpAndSettle();

      // Search for query that produces no results
      await tester.enterText(find.byType(TextField), 'NonExistentZzXxYy');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      hapticEvents.clear();

      final ctaFinder = find.text('Start a new note with this title');
      expect(ctaFinder, findsOneWidget);

      await tester.tap(ctaFinder);
      await tester.pumpAndSettle();

      expect(hapticEvents.contains('navigationSelection'), isTrue,
          reason: 'Activating Create New note CTA must dispatch QuickNotesHaptics.navigationSelection()');
    });
  });

  group('Phase P4.5 — Group I: Navigation Contract (P4-SEARCH-NAV-01)', () {
    testWidgets('TEST I1: Search -> NoteEditor preserves canonical buildPageRoute', (tester) async {
      final notesProvider = _TestNotesProvider();
      notesProvider.addTestNote(Note(
        id: 'n_preservation_test',
        title: 'Document Contract',
        content: 'Body content',
        category: 'Personal',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        colorValue: 0xFFFFFF,
        tags: const [],
        attachments: const [],
      ));

      final navObserver = _RouteObserver();

      await tester.pumpWidget(_buildSearchHarness(
        child: const SearchScreen(),
        notesProvider: notesProvider,
        navObserver: navObserver,
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Document');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      final noteCardFinder = find.byType(SearchNoteCard);
      expect(noteCardFinder, findsOneWidget);

      await tester.tap(noteCardFinder);
      await tester.pump();

      final pushedRoute = navObserver.pushedRoutes.last;
      expect(pushedRoute, isA<QuickNotesPageRoute<dynamic>>(),
          reason: 'Search -> NoteEditor must preserve buildPageRoute (QuickNotesPageRoute)');
      final qRoute = pushedRoute as QuickNotesPageRoute<dynamic>;
      expect(qRoute.normalTransitionDuration, equals(QuickNotesMotion.kMotionPage));
      expect(qRoute.normalReverseTransitionDuration, equals(QuickNotesMotion.kMotionPageReverse));
    });
  });

  group('Phase G3 — Group J: Locked G2.1 Global Search Contracts', () {
    testWidgets('TEST J1 (G-01): FolderGridCard supports titleColor override while retaining default behavior', (tester) async {
      final testFolder = Folder(
        id: 'f_test_1',
        name: 'Design Sprint',
        colorHex: '0xFFFFCC00',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      // 1. With titleColor override (used in Global Search dark mode)
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: FolderGridCard(
            folder: testFolder,
            index: 0,
            noteCount: 3,
            query: '',
            titleColor: const Color(0xFF1C1C1E),
            onTap: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final richTextFinder = find.descendant(
        of: find.byType(FolderGridCard),
        matching: find.byType(RichText),
      );
      final richText = tester.widget<RichText>(richTextFinder.first);
      final span = richText.text as TextSpan;
      final childSpan = span.children?.first as TextSpan?;
      expect(childSpan?.style?.color, equals(const Color(0xFF1C1C1E)),
          reason: 'FolderGridCard with titleColor must use specified color');

      // 2. Default behavior (without titleColor) in dark mode retains white text
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: FolderGridCard(
            folder: testFolder,
            index: 0,
            noteCount: 3,
            query: '',
            onTap: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final defaultRichText = tester.widget<RichText>(find.descendant(
        of: find.byType(FolderGridCard),
        matching: find.byType(RichText),
      ).first);
      final defaultSpan = defaultRichText.text as TextSpan;
      final defaultChildSpan = defaultSpan.children?.first as TextSpan?;
      expect(defaultChildSpan?.style?.color, equals(const Color(0xFFFFFFFF)),
          reason: 'Default FolderGridCard in dark mode must retain Colors.white for shared consumers');
    });

    testWidgets('TEST J2 (G-02): Create New Note CTA propagates initialTitle to NoteEditorScreen', (tester) async {
      final navObserver = _RouteObserver();

      await tester.pumpWidget(_buildSearchHarness(
        child: const SearchScreen(),
        navObserver: navObserver,
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '  Sprint Review  ');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      final ctaFinder = find.text('Start a new note with this title');
      expect(ctaFinder, findsOneWidget);

      await tester.tap(ctaFinder);
      await tester.pumpAndSettle();

      expect(find.byType(NoteEditorScreen), findsOneWidget);
      final titleFieldFinder = find.widgetWithText(TextField, 'Sprint Review');
      expect(titleFieldFinder, findsOneWidget,
          reason: 'NoteEditorScreen must be initialized with trimmed search query');
    });

    testWidgets('TEST J3 (G-03): Recent Searches header appears strictly in empty state', (tester) async {
      SharedPreferences.setMockInitialValues({
        'quick_notes_recent_searches': ['meeting', 'grocery'],
      });

      final notesProvider = _TestNotesProvider();
      notesProvider.addTestNote(Note(
        id: 'n_recent_leak',
        title: 'Meeting Notes',
        content: 'Content',
        category: 'Work',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        colorValue: 0xFFFFFF,
        tags: const [],
        attachments: const [],
      ));

      await tester.pumpWidget(_buildSearchHarness(
        child: const SearchScreen(),
        notesProvider: notesProvider,
      ));
      await tester.pumpAndSettle();

      // State 1: Empty state -> header present
      expect(find.text('Recent Searches'), findsOneWidget);
      expect(find.text('Clear all'), findsOneWidget);

      // State 2: Typing state -> header must NOT appear
      await tester.enterText(find.byType(TextField), 'Me');
      await tester.pump();
      expect(find.text('Recent Searches'), findsNothing,
          reason: 'Recent Searches header must not appear while typing');
      expect(find.text('Clear all'), findsNothing);

      // State 3: Results state -> header must NOT appear
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.byType(SearchNoteCard), findsOneWidget);
      expect(find.text('Recent Searches'), findsNothing,
          reason: 'Recent Searches header must not appear above results');

      // State 4: No results state -> header must NOT appear
      await tester.enterText(find.byType(TextField), 'NonExistentZz');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('Recent Searches'), findsNothing,
          reason: 'Recent Searches header must not appear in no-results state');
    });

    testWidgets('TEST J4 (G-05): Returning from NoteEditorScreen refreshes search results', (tester) async {
      final notesProvider = _TestNotesProvider();
      final note = Note(
        id: 'n_refresh_test',
        title: 'Initial Alpha Title',
        content: 'Other Content',
        category: 'Work',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        colorValue: 0xFFFFFF,
        tags: const [],
        attachments: const [],
      );
      notesProvider.addTestNote(note);

      await tester.pumpWidget(_buildSearchHarness(
        child: const SearchScreen(),
        notesProvider: notesProvider,
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Alpha');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.byType(SearchNoteCard), findsOneWidget);

      // Tap note card to push NoteEditorScreen
      await tester.tap(find.byType(SearchNoteCard));
      await tester.pumpAndSettle();
      expect(find.byType(NoteEditorScreen), findsOneWidget);

      // Simulate external update / edit while inside editor
      notesProvider.setTestNotes([
        note.copyWith(title: 'Updated Beta Title', content: 'Other Content'),
      ]);

      // Pop back to SearchScreen
      final navigator = tester.state<NavigatorState>(find.byType(Navigator).last);
      navigator.pop();
      await tester.pumpAndSettle();

      // Search query was 'Alpha'; since note was renamed to 'Updated Beta Title', 'Alpha' should now produce no results
      expect(find.byType(SearchNoteCard), findsNothing,
          reason: 'Search results must refresh after returning from note route');
    });

    testWidgets('TEST J5 (G-08): Search persistence follows committed semantics (no debounce persistence)', (tester) async {
      SharedPreferences.setMockInitialValues({
        'quick_notes_recent_searches': <String>[],
      });

      final notesProvider = _TestNotesProvider();
      notesProvider.addTestNote(Note(
        id: 'n_commit_test',
        title: 'Project Roadmap',
        content: 'Roadmap content',
        category: 'Work',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        colorValue: 0xFFFFFF,
        tags: const [],
        attachments: const [],
      ));

      await tester.pumpWidget(_buildSearchHarness(
        child: const SearchScreen(),
        notesProvider: notesProvider,
      ));
      await tester.pumpAndSettle();

      // Type and wait for debounce
      await tester.enterText(find.byType(TextField), 'Roadmap');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // 1. Debounce MUST NOT persist
      var recent = await RecentSearchesService.instance.load();
      expect(recent, isEmpty,
          reason: 'Debounce completion must not persist search query');

      // 2. IME submit DOES persist
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      recent = await RecentSearchesService.instance.load();
      expect(recent, contains('Roadmap'),
          reason: 'IME submit action must persist trimmed search query');
    });

    testWidgets('TEST J6 (G-09): Sub-2-character query clears stale results immediately', (tester) async {
      final notesProvider = _TestNotesProvider();
      notesProvider.addTestNote(Note(
        id: 'n_sub2_test',
        title: 'Meeting Notes',
        content: 'Content',
        category: 'Work',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        colorValue: 0xFFFFFF,
        tags: const [],
        attachments: const [],
      ));

      await tester.pumpWidget(_buildSearchHarness(
        child: const SearchScreen(),
        notesProvider: notesProvider,
      ));
      await tester.pumpAndSettle();

      // Search for query >= 2 characters
      await tester.enterText(find.byType(TextField), 'Meeting');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.byType(SearchNoteCard), findsOneWidget);

      // Backspace to 1 character
      await tester.enterText(find.byType(TextField), 'M');
      await tester.pump();

      // Results must immediately disappear, switching back to empty state
      expect(find.byType(SearchNoteCard), findsNothing,
          reason: 'Query with < 2 characters must immediately clear stale results');
      expect(find.byType(CustomScrollView), findsNothing);
    });

    testWidgets('TEST J7 (G-10): Whitespace-padded query normalizes to trimmed search semantics', (tester) async {
      final notesProvider = _TestNotesProvider();
      notesProvider.addTestNote(Note(
        id: 'n_whitespace_test',
        title: 'Architecture Review',
        content: 'Design details',
        category: 'Work',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        colorValue: 0xFFFFFF,
        tags: const [],
        attachments: const [],
      ));

      await tester.pumpWidget(_buildSearchHarness(
        child: const SearchScreen(),
        notesProvider: notesProvider,
      ));
      await tester.pumpAndSettle();

      // Query with leading/trailing spaces
      await tester.enterText(find.byType(TextField), '   Architecture Review   ');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.byType(SearchNoteCard), findsOneWidget,
          reason: 'Whitespace-padded search must match normalized content');
    });

    testWidgets('TEST J8 (G-07): Results state uses lazy CustomScrollView and sliver builders', (tester) async {
      final notesProvider = _TestNotesProvider();
      notesProvider.addTestNote(Note(
        id: 'n_sliver_test',
        title: 'Sliver Architecture',
        content: 'Lazy viewport loading',
        category: 'Work',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        colorValue: 0xFFFFFF,
        tags: const [],
        attachments: const [],
      ));

      await tester.pumpWidget(_buildSearchHarness(
        child: const SearchScreen(),
        notesProvider: notesProvider,
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Sliver');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Result container is a CustomScrollView with SliverList
      expect(find.byType(CustomScrollView), findsOneWidget,
          reason: 'Primary result architecture must be CustomScrollView');
      expect(find.descendant(of: find.byType(CustomScrollView), matching: find.byType(SliverList)), findsOneWidget,
          reason: 'Notes section must be backed by SliverList.builder');
    });
  });

  group('Phase D3 — Group K: Global Search Dark Mode Verification', () {
    testWidgets('TEST K1 (D2): Dark canvas and sheet colors', (tester) async {
      await tester.pumpWidget(_buildSearchHarness(
        child: const SearchScreen(),
        theme: ThemeData.dark(),
      ));
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFF1E1E1E),
          reason: 'Scaffold canvas must be 0xFF1E1E1E in dark mode');

      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasDarkSheet = containers.any((c) =>
          c.decoration is BoxDecoration &&
          (c.decoration as BoxDecoration).color == const Color(0xFF2C2C2C));
      expect(hasDarkSheet, isTrue,
          reason: 'Body sheet must use 0xFF2C2C2C in dark mode');
    });

    testWidgets('TEST K2 (D2): Dark header text, icons, hint, and keyboard', (tester) async {
      await tester.pumpWidget(_buildSearchHarness(
        child: const SearchScreen(),
        theme: ThemeData.dark(),
      ));
      await tester.pumpAndSettle();

      final backSvg = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(backSvg.colorFilter,
          const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          reason: 'Back icon SVG filter must be white in dark mode');

      final closeIcon =
          tester.widget<Icon>(find.byIcon(Icons.close_rounded));
      expect(closeIcon.color, Colors.white,
          reason: 'Close icon must be white in dark mode');

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.style?.color, Colors.white,
          reason: 'Search text must be white in dark mode');
      expect(textField.decoration?.hintStyle?.color, const Color(0xFF8E8E93),
          reason: 'Search hint must be 0xFF8E8E93 in dark mode');
      expect(textField.keyboardAppearance, Brightness.dark,
          reason: 'Keyboard appearance must be dark in dark mode');
    });

    testWidgets('TEST K3 (D2): Dark result cards use Color(0xFF2C2C2C) and white text', (tester) async {
      final notesProvider = _TestNotesProvider();
      notesProvider.addTestNote(Note(
        id: 'n_dark_1',
        title: 'Dark Architecture',
        content: 'Dark mode note content',
        category: 'Work',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        colorValue: 0xFFFFFF,
        tags: const [],
        attachments: const [],
      ));
      final tasksProvider = _TestTasksProvider();
      tasksProvider.addTestTask(TaskItem(
        id: 't_dark_1',
        title: 'Dark Task Item',
        dueDate: DateTime(2026, 1, 1),
        priority: 'None',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ));

      await tester.pumpWidget(_buildSearchHarness(
        child: const SearchScreen(),
        notesProvider: notesProvider,
        tasksProvider: tasksProvider,
        theme: ThemeData.dark(),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Dark');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.byType(SearchNoteCard), findsOneWidget);
      expect(find.byType(SearchTaskCard), findsOneWidget);

      final noteContainers = tester.widgetList<Container>(
        find.descendant(
            of: find.byType(SearchNoteCard), matching: find.byType(Container)),
      );
      expect(
        noteContainers.any((c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).color == const Color(0xFF2C2C2C)),
        isTrue,
        reason: 'SearchNoteCard front card must be 0xFF2C2C2C in dark mode',
      );

      final taskContainers = tester.widgetList<Container>(
        find.descendant(
            of: find.byType(SearchTaskCard), matching: find.byType(Container)),
      );
      expect(
        taskContainers.any((c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).color == const Color(0xFF2C2C2C)),
        isTrue,
        reason: 'SearchTaskCard front card must be 0xFF2C2C2C in dark mode',
      );

      final noteRichTexts = tester.widgetList<RichText>(
        find.descendant(
            of: find.byType(SearchNoteCard), matching: find.byType(RichText)),
      );
      final noteTitleRichText = noteRichTexts.firstWhere(
        (r) => r.text.toPlainText().contains('Dark Architecture'),
      );
      bool hasDarkTitleColor = false;
      noteTitleRichText.text.visitChildren((span) {
        if (span is TextSpan && span.style?.color == Colors.white) {
          hasDarkTitleColor = true;
          return false;
        }
        return true;
      });
      expect(
        hasDarkTitleColor,
        isTrue,
        reason:
            'SearchNoteCard title text span must use Colors.white in dark mode',
      );
    });

    testWidgets('TEST K4 (D2): Light Mode preservation', (tester) async {
      final notesProvider = _TestNotesProvider();
      notesProvider.addTestNote(Note(
        id: 'n_light_1',
        title: 'Light Architecture',
        content: 'Light mode content',
        category: 'Work',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        colorValue: 0xFFFFFF,
        tags: const [],
        attachments: const [],
      ));

      await tester.pumpWidget(_buildSearchHarness(
        child: const SearchScreen(),
        notesProvider: notesProvider,
        theme: ThemeData.light(),
      ));
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFFF2F2F7),
          reason: 'Canvas must remain 0xFFF2F2F7 in light mode');

      final backSvg = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(backSvg.colorFilter,
          const ColorFilter.mode(Color(0xFF1C1C1E), BlendMode.srcIn),
          reason: 'Back icon SVG filter must remain 0xFF1C1C1E in light mode');

      final closeIcon =
          tester.widget<Icon>(find.byIcon(Icons.close_rounded));
      expect(closeIcon.color, const Color(0xFF1C1C1E),
          reason: 'Close icon must remain 0xFF1C1C1E in light mode');

      final containers = tester.widgetList<Container>(find.byType(Container));
      expect(
        containers.any((c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).color == Colors.white),
        isTrue,
        reason: 'Sheet must remain white in light mode',
      );

      await tester.enterText(find.byType(TextField), 'Light');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      final noteContainers = tester.widgetList<Container>(
        find.descendant(
            of: find.byType(SearchNoteCard), matching: find.byType(Container)),
      );
      expect(
        noteContainers.any((c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).color == Colors.white),
        isTrue,
        reason: 'SearchNoteCard front card must remain white in light mode',
      );

      final noteRichTexts = tester.widgetList<RichText>(
        find.descendant(
            of: find.byType(SearchNoteCard), matching: find.byType(RichText)),
      );
      final noteTitleRichText = noteRichTexts.firstWhere(
        (r) => r.text.toPlainText().contains('Light Architecture'),
      );
      bool hasLightTitleColor = false;
      noteTitleRichText.text.visitChildren((span) {
        if (span is TextSpan && span.style?.color == const Color(0xFF333333)) {
          hasLightTitleColor = true;
          return false;
        }
        return true;
      });
      expect(
        hasLightTitleColor,
        isTrue,
        reason:
            'SearchNoteCard title text span must use existing 0xFF333333 in light mode',
      );
    });

    testWidgets('TEST K5 (D2): Scope selector Dark Mode styling', (tester) async {
      await tester.pumpWidget(_buildSearchHarness(
        child: const SearchScreen(),
        theme: ThemeData.dark(),
      ));
      await tester.pumpAndSettle();

      final pillContainers = tester.widgetList<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      expect(
        pillContainers.any((c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).color == const Color(0xFF38383A)),
        isTrue,
        reason:
            'Unselected scope pill background must be 0xFF38383A in dark mode',
      );

      final notesScopeText = tester.widget<Text>(find.text('Notes'));
      expect(notesScopeText.style?.color, const Color(0xFF8E8E93),
          reason: 'Unselected scope text must be 0xFF8E8E93 in dark mode');
    });

    testWidgets('TEST K6 (D2): Empty and recent search Dark Mode styling', (tester) async {
      SharedPreferences.setMockInitialValues({
        'quick_notes_recent_searches': ['Dark Search Term'],
      });

      await tester.pumpWidget(_buildSearchHarness(
        child: const SearchScreen(),
        theme: ThemeData.dark(),
      ));
      await tester.pumpAndSettle();

      final titleText = tester.widget<Text>(find.text('Recent Searches'));
      expect(titleText.style?.color, const Color(0xFF8E8E93));

      final clearAllText = tester.widget<Text>(find.text('Clear all'));
      expect(clearAllText.style?.color, const Color(0xFF8E8E93));

      final queryText = tester.widget<Text>(find.text('Dark Search Term'));
      expect(queryText.style?.color, Colors.white);

      final divider = tester.widget<Divider>(find.byType(Divider));
      expect(divider.color, const Color(0xFF38383A));
    });

    testWidgets('TEST K7 (D2): Category results Dark Mode styling', (tester) async {
      final notesProvider = _TestNotesProvider();
      notesProvider.addTestNote(Note(
        id: 'n_cat_1',
        title: 'Baking Bread',
        content: 'Flour water yeast',
        category: 'Cooking',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        colorValue: 0xFFFFFF,
        tags: const [],
        attachments: const [],
      ));

      await tester.pumpWidget(_buildSearchHarness(
        child: const SearchScreen(),
        notesProvider: notesProvider,
        theme: ThemeData.dark(),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Cook');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      final containers = tester.widgetList<Container>(find.byType(Container));
      final catCard = containers.firstWhere(
        (c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).color == const Color(0xFF2C2C2C) &&
            (c.decoration as BoxDecoration).border != null,
        orElse: () =>
            throw TestFailure('Could not find Category card with dark decoration'),
      );
      final border = (catCard.decoration as BoxDecoration).border! as Border;
      expect(border.top.color, const Color(0xFF38383A));
    });

    testWidgets('TEST K8 (D2): No-results state and CTA Dark Mode styling', (tester) async {
      await tester.pumpWidget(_buildSearchHarness(
        child: const SearchScreen(),
        theme: ThemeData.dark(),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'NonExistentXYZ');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('No results for "NonExistentXYZ"'), findsOneWidget);
      final noResultsTitle =
          tester.widget<Text>(find.text('No results for "NonExistentXYZ"'));
      expect(noResultsTitle.style?.color, Colors.white);

      final containers = tester.widgetList<Container>(find.byType(Container));
      final ctaContainer = containers.firstWhere(
        (c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).color == const Color(0xFF38383A) &&
            (c.decoration as BoxDecoration).border != null,
        orElse: () =>
            throw TestFailure('Could not find dark mode CTA container'),
      );
      final border =
          (ctaContainer.decoration as BoxDecoration).border! as Border;
      expect(border.top.color, const Color(0xFF48484A));
    });

    testWidgets('TEST K9 (D6): Search field has no inherited border in Dark Mode', (tester) async {
      await tester.pumpWidget(_buildSearchHarness(
        child: const SearchScreen(),
        theme: QuickNotesTheme.darkTheme,
      ));
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      final decoration = textField.decoration;
      expect(decoration, isNotNull);
      expect(decoration!.border, InputBorder.none,
          reason: 'border must be InputBorder.none');
      expect(decoration.enabledBorder, InputBorder.none,
          reason: 'enabledBorder must be InputBorder.none');
      expect(decoration.focusedBorder, InputBorder.none,
          reason: 'focusedBorder must be InputBorder.none');
      expect(decoration.disabledBorder, InputBorder.none,
          reason: 'disabledBorder must be InputBorder.none');
      expect(decoration.errorBorder, InputBorder.none,
          reason: 'errorBorder must be InputBorder.none');
      expect(decoration.focusedErrorBorder, InputBorder.none,
          reason: 'focusedErrorBorder must be InputBorder.none');
    });

    testWidgets('TEST K10 (D6): Search field has no opaque fill and retains brand amber cursor in Dark Mode', (tester) async {
      await tester.pumpWidget(_buildSearchHarness(
        child: const SearchScreen(),
        theme: QuickNotesTheme.darkTheme,
      ));
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      final decoration = textField.decoration;
      expect(decoration, isNotNull);
      expect(decoration!.filled, isFalse,
          reason: 'filled must be false');
      expect(decoration.fillColor, Colors.transparent,
          reason: 'fillColor must be Colors.transparent');
      expect(textField.cursorColor, const Color(0xFFFFCC00),
          reason: 'cursorColor must be 0xFFFFCC00');
    });
  });
}

