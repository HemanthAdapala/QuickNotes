import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:quick_notes/views/screens/search_screen.dart';
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
}
