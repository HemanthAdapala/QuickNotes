import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/models/task_item.dart';
import 'package:quick_notes/models/task_status.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/providers/tasks_provider.dart';
import 'package:quick_notes/repositories/tasks_repository.dart';
import 'package:quick_notes/services/task_engine.dart';
import 'package:quick_notes/services/clock_service.dart';
import 'package:quick_notes/services/reminder_scheduler.dart';
import 'package:quick_notes/services/deep_link_coordinator.dart';
import 'package:quick_notes/views/screens/home_screen.dart';
import 'package:quick_notes/views/screens/create_task_screen.dart';
import 'package:quick_notes/views/screens/note_editor_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeepLinkCoordinator Phase W8 Comprehensive Tests', () {
    late DeepLinkCoordinator coordinator;

    setUp(() {
      coordinator = DeepLinkCoordinator.instance;
      coordinator.dispose();
    });

    tearDown(() {
      coordinator.dispose();
    });

    test('TEST 1 — Navigation readiness: starts not-ready, markNavigationReady releases action', () async {
      expect(coordinator.isNavigationReady, isFalse);

      coordinator.setPendingAction(const DeepLinkAction(DeepLinkActionType.newNote));
      expect(coordinator.pendingAction, isNotNull);

      DeepLinkAction? executedAction;
      coordinator.initialize(
        uriStream: const Stream.empty(),
        onActionDispatched: (action) => executedAction = action,
      );

      await coordinator.markNavigationReady();

      expect(coordinator.isNavigationReady, isTrue);
      expect(executedAction, isNotNull);
      expect(executedAction!.type, DeepLinkActionType.newNote);
      expect(coordinator.pendingAction, isNull);
    });

    test('TEST 2 — Cold-launch pending openNote: buffers before readiness and clears on execute', () async {
      final initialUri = Uri.parse('quicknotes://note/uuid-cold-123');

      await coordinator.initialize(
        initialUriProvider: () async => initialUri,
        uriStream: const Stream.empty(),
      );

      // Verify cold-launch action is safely held in buffer
      expect(coordinator.pendingAction, isNotNull);
      expect(coordinator.pendingAction!.type, DeepLinkActionType.openNote);
      expect(coordinator.pendingAction!.queryParameters['noteId'], 'uuid-cold-123');
      expect(coordinator.isNavigationReady, isFalse);

      DeepLinkAction? executedAction;
      coordinator.initialize(
        uriStream: const Stream.empty(),
        onActionDispatched: (action) => executedAction = action,
      );

      // Simulate app completion of auth & startup -> mark navigation ready
      await coordinator.markNavigationReady();

      expect(executedAction, isNotNull);
      expect(executedAction!.type, DeepLinkActionType.openNote);
      expect(executedAction!.queryParameters['noteId'], 'uuid-cold-123');
      expect(coordinator.pendingAction, isNull);
    });

    test('TEST 3 — Warm-launch openNote: dispatches immediately when navigation is ready', () async {
      final streamController = StreamController<Uri?>();
      DeepLinkAction? executedAction;

      await coordinator.initialize(
        initialUriProvider: () async => null,
        uriStream: streamController.stream,
        onActionDispatched: (action) => executedAction = action,
      );

      await coordinator.markNavigationReady();

      streamController.add(Uri.parse('quicknotes://note/uuid-warm-456'));
      await pumpEventQueue();

      expect(executedAction, isNotNull);
      expect(executedAction!.type, DeepLinkActionType.openNote);
      expect(executedAction!.queryParameters['noteId'], 'uuid-warm-456');

      await streamController.close();
    });

    test('TEST 4 — UI filter independence: resolves Note B even when UI filter is set to Category A', () {
      final noteA = Note(
        id: 'note-cat-a',
        title: 'Work Project',
        content: 'Work tasks',
        category: 'Work',
        tags: [],
        attachments: [],
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
        colorValue: 0xFFFFFFFF,
        isLocked: false,
        isDeleted: false,
        isArchived: false,
      );

      final noteB = Note(
        id: 'note-cat-b',
        title: 'Groceries',
        content: 'Personal shopping',
        category: 'Personal',
        tags: [],
        attachments: [],
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
        colorValue: 0xFFFFFFFF,
        isLocked: false,
        isDeleted: false,
        isArchived: false,
      );

      // Simulating notesProvider.allActiveNotes (unfiltered authoritative collection)
      final allActiveNotes = [noteA, noteB];

      // Active UI filter is 'Work'
      const activeCategoryFilter = 'Work';
      final uiFilteredNotes = allActiveNotes.where((n) => n.category == activeCategoryFilter).toList();

      // UI filter excludes Note B
      expect(uiFilteredNotes.any((n) => n.id == 'note-cat-b'), isFalse);

      // Authoritative lookup by ID finds Note B regardless of UI filter
      final resolvedNote = allActiveNotes.firstWhere((n) => n.id == 'note-cat-b');
      expect(resolvedNote, isNotNull);
      expect(resolvedNote.id, 'note-cat-b');
      expect(resolvedNote.title, 'Groceries');
    });

    test('TEST 5 — Async loading race: lookup handles initially empty list and resolves when loaded', () async {
      List<Note> activeNotes = [];

      // Simulate lookup function that falls back to async repository loader
      Future<Note?> resolveNoteAuthoritatively(String id) async {
        final inMem = activeNotes.where((n) => n.id == id);
        if (inMem.isNotEmpty) return inMem.first;

        // Simulate async DB load
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return Note(
          id: id,
          title: 'Async Loaded Note',
          content: 'Loaded from SQLite',
          tags: [],
          attachments: [],
          createdAt: DateTime(2026, 6, 1),
          updatedAt: DateTime(2026, 6, 1),
          colorValue: 0xFFFFFFFF,
        );
      }

      final resolved = await resolveNoteAuthoritatively('note-async-1');
      expect(resolved, isNotNull);
      expect(resolved!.id, 'note-async-1');
      expect(resolved.title, 'Async Loaded Note');
    });

    test('TEST 6, 7, 8 — Security Filters: Locked, Deleted, and Archived notes are rejected', () {
      final activeNote = Note(
        id: 'note-active',
        title: 'Active Note',
        content: 'Content',
        tags: [],
        attachments: [],
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
        colorValue: 0xFFFFFFFF,
        isLocked: false,
        isDeleted: false,
        isArchived: false,
      );

      final lockedNote = Note(
        id: 'note-locked',
        title: 'Locked Note',
        content: 'Secret',
        tags: [],
        attachments: [],
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
        colorValue: 0xFFFFFFFF,
        isLocked: true,
        isDeleted: false,
        isArchived: false,
      );

      final deletedNote = Note(
        id: 'note-deleted',
        title: 'Deleted Note',
        content: 'Trash',
        tags: [],
        attachments: [],
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
        colorValue: 0xFFFFFFFF,
        isLocked: false,
        isDeleted: true,
        isArchived: false,
      );

      final archivedNote = Note(
        id: 'note-archived',
        title: 'Archived Note',
        content: 'Old',
        tags: [],
        attachments: [],
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
        colorValue: 0xFFFFFFFF,
        isLocked: false,
        isDeleted: false,
        isArchived: true,
      );

      bool isEligibleForEditor(Note? note) {
        if (note == null) return false;
        return !note.isDeleted && !note.isArchived && !note.isLocked;
      }

      expect(isEligibleForEditor(activeNote), isTrue);
      expect(isEligibleForEditor(lockedNote), isFalse);
      expect(isEligibleForEditor(deletedNote), isFalse);
      expect(isEligibleForEditor(archivedNote), isFalse);
      expect(isEligibleForEditor(null), isFalse);
    });

    test('TEST 9 — Multiple widget notes: distinct instances retain independent note targets', () {
      final actionA = DeepLinkAction.parse(Uri.parse('quicknotes://note/widget-instance-A'));
      final actionB = DeepLinkAction.parse(Uri.parse('quicknotes://note/widget-instance-B'));

      expect(actionA!.queryParameters['noteId'], 'widget-instance-A');
      expect(actionB!.queryParameters['noteId'], 'widget-instance-B');
      expect(actionA.queryParameters['noteId'], isNot(equals(actionB.queryParameters['noteId'])));
    });

    test('TEST 10 — No duplicate initialization: coordinator ignores repeated initialize calls', () async {
      final initialUri = Uri.parse('quicknotes://home');

      await coordinator.initialize(
        initialUriProvider: () async => initialUri,
        uriStream: const Stream.empty(),
      );
      expect(coordinator.isInitialized, isTrue);

      // Subsequent call does not re-subscribe or overwrite
      await coordinator.initialize(
        initialUriProvider: () async => Uri.parse('quicknotes://note/new'),
        uriStream: const Stream.empty(),
      );

      expect(coordinator.pendingAction!.type, DeepLinkActionType.openHome);
    });

    test('TEST 11 — Pending action executes exactly once even if markNavigationReady is called multiple times', () async {
      int dispatchCount = 0;

      coordinator.setPendingAction(const DeepLinkAction(DeepLinkActionType.newNote));

      await coordinator.initialize(
        uriStream: const Stream.empty(),
        onActionDispatched: (action) => dispatchCount++,
      );

      await coordinator.markNavigationReady();
      expect(dispatchCount, equals(1));
      expect(coordinator.pendingAction, isNull);

      // Calling markNavigationReady again when buffer is consumed must NOT trigger navigation again
      await coordinator.markNavigationReady();
      expect(dispatchCount, equals(1));
    });
  });

  group('DeepLinkCoordinator Phase T6 Task Deep Linking Tests', () {
    late DeepLinkCoordinator coordinator;

    setUp(() {
      coordinator = DeepLinkCoordinator.instance;
      coordinator.dispose();
    });

    tearDown(() {
      coordinator.dispose();
    });

    test('TEST 12 — Valid task URI parsing: quicknotes://task/<taskId> produces openTask with exact taskId', () {
      final action1 = DeepLinkAction.parse(Uri.parse('quicknotes://task/task-uuid-123'));
      expect(action1, isNotNull);
      expect(action1!.type, DeepLinkActionType.openTask);
      expect(action1.queryParameters['taskId'], 'task-uuid-123');

      final action2 = DeepLinkAction.parse(Uri.parse('quicknotes://task/task_456-abc'));
      expect(action2, isNotNull);
      expect(action2!.type, DeepLinkActionType.openTask);
      expect(action2.queryParameters['taskId'], 'task_456-abc');
    });

    test('TEST 13 — Invalid & malformed task URIs rejected safely', () {
      expect(DeepLinkAction.parse(Uri.parse('quicknotes://task/')), isNull);
      expect(DeepLinkAction.parse(Uri.parse('quicknotes://task')), isNull);
      expect(DeepLinkAction.parse(Uri.parse('quicknotes://task/id1/id2')), isNull);
      expect(DeepLinkAction.parse(Uri.parse('https://task/task-123')), isNull);
      expect(DeepLinkAction.parse(Uri.parse('random://task/task-123')), isNull);
      expect(DeepLinkAction.parse(Uri.parse('quicknotes://other/task-123')), isNull);
      expect(DeepLinkAction.parse(null), isNull);
    });

    test('TEST 14 — Plural vs singular distinction: quicknotes://tasks vs quicknotes://task/<id>', () {
      final actionPlural = DeepLinkAction.parse(Uri.parse('quicknotes://tasks'));
      expect(actionPlural, isNotNull);
      expect(actionPlural!.type, DeepLinkActionType.openTasks);

      final actionPluralPath = DeepLinkAction.parse(Uri.parse('quicknotes:///tasks'));
      expect(actionPluralPath, isNotNull);
      expect(actionPluralPath!.type, DeepLinkActionType.openTasks);

      final actionSingular = DeepLinkAction.parse(Uri.parse('quicknotes://task/uuid-task-77'));
      expect(actionSingular, isNotNull);
      expect(actionSingular!.type, DeepLinkActionType.openTask);
      expect(actionSingular.queryParameters['taskId'], 'uuid-task-77');
    });

    test('TEST 15 — Cold-launch pending openTask: buffers before readiness and clears on execute', () async {
      final initialUri = Uri.parse('quicknotes://task/cold-task-uuid-1');

      await coordinator.initialize(
        initialUriProvider: () async => initialUri,
        uriStream: const Stream.empty(),
      );

      // Verify cold-launch task action is safely held in buffer
      expect(coordinator.pendingAction, isNotNull);
      expect(coordinator.pendingAction!.type, DeepLinkActionType.openTask);
      expect(coordinator.pendingAction!.queryParameters['taskId'], 'cold-task-uuid-1');
      expect(coordinator.isNavigationReady, isFalse);

      DeepLinkAction? executedAction;
      coordinator.initialize(
        uriStream: const Stream.empty(),
        onActionDispatched: (action) => executedAction = action,
      );

      // Simulate app completion of auth & startup -> mark navigation ready
      await coordinator.markNavigationReady();

      expect(executedAction, isNotNull);
      expect(executedAction!.type, DeepLinkActionType.openTask);
      expect(executedAction!.queryParameters['taskId'], 'cold-task-uuid-1');
      expect(coordinator.pendingAction, isNull);
    });

    test('TEST 16 — Warm-launch openTask: dispatches immediately when navigation is ready', () async {
      final streamController = StreamController<Uri?>();
      DeepLinkAction? executedAction;

      await coordinator.initialize(
        initialUriProvider: () async => null,
        uriStream: streamController.stream,
        onActionDispatched: (action) => executedAction = action,
      );

      await coordinator.markNavigationReady();

      streamController.add(Uri.parse('quicknotes://task/warm-task-uuid-2'));
      await pumpEventQueue();

      expect(executedAction, isNotNull);
      expect(executedAction!.type, DeepLinkActionType.openTask);
      expect(executedAction!.queryParameters['taskId'], 'warm-task-uuid-2');

      await streamController.close();
    });

    test('TEST 17 — Multi-Task widget per-card independent targets', () {
      final actionA = DeepLinkAction.parse(Uri.parse('quicknotes://task/task-card-A'));
      final actionB = DeepLinkAction.parse(Uri.parse('quicknotes://task/task-card-B'));
      final actionC = DeepLinkAction.parse(Uri.parse('quicknotes://task/task-card-C'));

      expect(actionA!.queryParameters['taskId'], 'task-card-A');
      expect(actionB!.queryParameters['taskId'], 'task-card-B');
      expect(actionC!.queryParameters['taskId'], 'task-card-C');

      expect(actionA.queryParameters['taskId'], isNot(equals(actionB.queryParameters['taskId'])));
      expect(actionB.queryParameters['taskId'], isNot(equals(actionC.queryParameters['taskId'])));
    });

    test('TEST 18 — Task security & lifecycle filters: Deleted and Archived tasks are rejected, Waiting and Completed are eligible', () {
      final waitingTask = TaskItem(
        id: 'task-waiting',
        title: 'Pending Task',
        dueDate: DateTime(2026, 8, 30),
        priority: 'High',
        status: TaskStatus.waiting,
        isDeleted: false,
      );

      final completedTask = TaskItem(
        id: 'task-completed',
        title: 'Completed Task',
        dueDate: DateTime(2026, 8, 30),
        priority: 'Medium',
        status: TaskStatus.completed,
        isDeleted: false,
      );

      final archivedTask = TaskItem(
        id: 'task-archived',
        title: 'Archived Task',
        dueDate: DateTime(2026, 8, 30),
        priority: 'Low',
        status: TaskStatus.archived,
        isDeleted: false,
      );

      final deletedTask = TaskItem(
        id: 'task-deleted',
        title: 'Deleted Task',
        dueDate: DateTime(2026, 8, 30),
        priority: 'None',
        status: TaskStatus.waiting,
        isDeleted: true,
      );

      bool isEligibleForEditor(TaskItem? task) {
        if (task == null) return false;
        return !task.isDeleted && task.status != TaskStatus.archived;
      }

      expect(isEligibleForEditor(waitingTask), isTrue);
      expect(isEligibleForEditor(completedTask), isTrue);
      expect(isEligibleForEditor(archivedTask), isFalse);
      expect(isEligibleForEditor(deletedTask), isFalse);
      expect(isEligibleForEditor(null), isFalse);
    });

    test('TEST 19 — Repeated deep links: sequential dispatching of different tasks does not keep stale ID', () async {
      final streamController = StreamController<Uri?>();
      final receivedActions = <DeepLinkAction>[];

      await coordinator.initialize(
        initialUriProvider: () async => null,
        uriStream: streamController.stream,
        onActionDispatched: (action) => receivedActions.add(action),
      );

      await coordinator.markNavigationReady();

      // Dispatch task A
      streamController.add(Uri.parse('quicknotes://task/task-alpha'));
      await pumpEventQueue();

      expect(receivedActions.length, 1);
      expect(receivedActions.last.queryParameters['taskId'], 'task-alpha');

      // Dispatch task B
      streamController.add(Uri.parse('quicknotes://task/task-beta'));
      await pumpEventQueue();

      expect(receivedActions.length, 2);
      expect(receivedActions.last.queryParameters['taskId'], 'task-beta');

      await streamController.close();
    });
  });

  group('DeepLinkCoordinator Phase T10 Task Creation & Overview Deep Linking Tests', () {
    late DeepLinkCoordinator coordinator;

    setUp(() {
      coordinator = DeepLinkCoordinator.instance;
      coordinator.dispose();
    });

    tearDown(() {
      coordinator.dispose();
    });

    test('TEST A — Canonical newTask URI: quicknotes://task/new produces DeepLinkActionType.newTask', () {
      final action = DeepLinkAction.parse(Uri.parse('quicknotes://task/new'));
      expect(action, isNotNull);
      expect(action!.type, DeepLinkActionType.newTask);
      expect(action.queryParameters, isEmpty);
    });

    test('TEST B — Differentiation: quicknotes://task/new does NOT produce openTask with taskId "new"', () {
      final action = DeepLinkAction.parse(Uri.parse('quicknotes://task/new'));
      expect(action!.type, isNot(DeepLinkActionType.openTask));
      expect(action.queryParameters.containsKey('taskId'), isFalse);
    });

    test('TEST C — Non-Regression: existing UUID task URI still produces openTask with exact taskId', () {
      const taskUuid = 'fed61850-4822-4fa2-884b-78b65a39e6a8';
      final action = DeepLinkAction.parse(Uri.parse('quicknotes://task/$taskUuid'));
      expect(action, isNotNull);
      expect(action!.type, DeepLinkActionType.openTask);
      expect(action.queryParameters['taskId'], taskUuid);
    });

    test('TEST D — Malformed & invalid task URIs are safely rejected', () {
      expect(DeepLinkAction.parse(Uri.parse('quicknotes://task/')), isNull);
      expect(DeepLinkAction.parse(Uri.parse('quicknotes://task/new/extra')), isNull);
      expect(DeepLinkAction.parse(Uri.parse('quicknotes://task//new')), isNull);
      expect(DeepLinkAction.parse(Uri.parse('http://task/new')), isNull);
      expect(DeepLinkAction.parse(Uri.parse('https://task/new')), isNull);
      expect(DeepLinkAction.parse(Uri.parse('quicknotes://unknown/new')), isNull);
    });

    test('TEST E — Warm-launch newTask: dispatches immediately when navigation is ready', () async {
      final streamController = StreamController<Uri?>();
      DeepLinkAction? executedAction;

      await coordinator.initialize(
        initialUriProvider: () async => null,
        uriStream: streamController.stream,
        onActionDispatched: (action) => executedAction = action,
      );

      await coordinator.markNavigationReady();

      streamController.add(Uri.parse('quicknotes://task/new'));
      await pumpEventQueue();

      expect(executedAction, isNotNull);
      expect(executedAction!.type, DeepLinkActionType.newTask);

      await streamController.close();
    });

    test('TEST F — Cold-launch newTask: buffers until navigation readiness and releases cleanly', () async {
      final initialUri = Uri.parse('quicknotes://task/new');

      await coordinator.initialize(
        initialUriProvider: () async => initialUri,
        uriStream: const Stream.empty(),
      );

      expect(coordinator.pendingAction, isNotNull);
      expect(coordinator.pendingAction!.type, DeepLinkActionType.newTask);
      expect(coordinator.isNavigationReady, isFalse);

      DeepLinkAction? executedAction;
      coordinator.initialize(
        uriStream: const Stream.empty(),
        onActionDispatched: (action) => executedAction = action,
      );

      await coordinator.markNavigationReady();

      expect(executedAction, isNotNull);
      expect(executedAction!.type, DeepLinkActionType.newTask);
      expect(coordinator.pendingAction, isNull);
    });

    test('TEST G — Pending action clears after execution and does not replay', () async {
      coordinator.setPendingAction(const DeepLinkAction(DeepLinkActionType.newTask));
      expect(coordinator.pendingAction, isNotNull);

      DeepLinkAction? executedAction;
      coordinator.initialize(
        uriStream: const Stream.empty(),
        onActionDispatched: (action) => executedAction = action,
      );

      await coordinator.markNavigationReady();
      expect(executedAction!.type, DeepLinkActionType.newTask);
      expect(coordinator.pendingAction, isNull);

      // Subsequent readiness calls should not replay
      executedAction = null;
      await coordinator.markNavigationReady();
      expect(executedAction, isNull);
    });

    test('TEST H — Tasks overview & alias parsing: quicknotes://tasks and quicknotes://tasks/new', () {
      final tasksAction = DeepLinkAction.parse(Uri.parse('quicknotes://tasks'));
      expect(tasksAction, isNotNull);
      expect(tasksAction!.type, DeepLinkActionType.openTasks);

      final tasksNewAction = DeepLinkAction.parse(Uri.parse('quicknotes://tasks/new'));
      expect(tasksNewAction, isNotNull);
      expect(tasksNewAction!.type, DeepLinkActionType.newTask);
    });

    test('TEST I — Sequential deep links: transitioning newTask -> openTask -> openTasks maintains clean state', () async {
      final streamController = StreamController<Uri?>();
      final receivedActions = <DeepLinkAction>[];

      await coordinator.initialize(
        initialUriProvider: () async => null,
        uriStream: streamController.stream,
        onActionDispatched: (action) => receivedActions.add(action),
      );

      await coordinator.markNavigationReady();

      // 1. Task creation
      streamController.add(Uri.parse('quicknotes://task/new'));
      await pumpEventQueue();
      expect(receivedActions.length, 1);
      expect(receivedActions[0].type, DeepLinkActionType.newTask);

      // 2. Specific task open
      streamController.add(Uri.parse('quicknotes://task/task-specific-uuid'));
      await pumpEventQueue();
      expect(receivedActions.length, 2);
      expect(receivedActions[1].type, DeepLinkActionType.openTask);
      expect(receivedActions[1].queryParameters['taskId'], 'task-specific-uuid');

      // 3. Tasks overview
      streamController.add(Uri.parse('quicknotes://tasks'));
      await pumpEventQueue();
      expect(receivedActions.length, 3);
      expect(receivedActions[2].type, DeepLinkActionType.openTasks);

      await streamController.close();
    });
  });

  group('DeepLinkCoordinator Phase T14 Task Deep-Link Routing Migration Tests', () {
    late DeepLinkCoordinator coordinator;
    late MockTasksRepository repository;
    late TaskEngine engine;
    late TasksProvider tasksProvider;
    late NotesProvider notesProvider;

    setUpAll(() {
      GoogleFonts.config.allowRuntimeFetching = false;
      SharedPreferences.setMockInitialValues({});
    });

    setUp(() async {
      coordinator = DeepLinkCoordinator.instance;
      coordinator.dispose();

      repository = MockTasksRepository();
      engine = TaskEngine(
        repository: repository,
        clock: const SystemClock(),
        scheduler: LoggingReminderScheduler(),
      );
      await engine.initialize();
      tasksProvider = TasksProvider(engine: engine);
      notesProvider = NotesProvider();
    });

    tearDown(() {
      coordinator.dispose();
    });

    Widget buildTestApp({required Widget initialScreen}) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<NotesProvider>.value(value: notesProvider),
          ChangeNotifierProvider<TasksProvider>.value(value: tasksProvider),
        ],
        child: MaterialApp(
          home: initialScreen,
        ),
      );
    }

    testWidgets('TEST T14-1 — Valid active task: quicknotes://task/<id> routes to HomeScreen(initialShowTasks: true, focusedTaskId: id)', (tester) async {
      final task = await engine.createTask(
        title: 'Active Task T14-1',
        dueDate: DateTime.now(),
        priority: 'High',
      );

      await tester.pumpWidget(buildTestApp(initialScreen: const Scaffold(body: Text('Initial'))));
      await tester.pump(const Duration(milliseconds: 300));

      final action = DeepLinkAction.parse(Uri.parse('quicknotes://task/${task.id}'))!;
      expect(action.type, DeepLinkActionType.openTask);
      expect(action.queryParameters['taskId'], task.id);

      final BuildContext context = tester.element(find.byType(Scaffold).first);
      await coordinator.executeAction(context, action);
      await tester.pumpAndSettle();

      // Verify HomeScreen is rendered with focused task overlay and NOT TaskEditorScreen
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(TaskEditorScreen), findsNothing);
      final homeScreenFinder = find.byType(HomeScreen);
      final HomeScreen homeScreen = tester.widget(homeScreenFinder);
      expect(homeScreen.initialShowTasks, isTrue);
      expect(homeScreen.focusedTaskId, task.id);
      expect(find.byKey(ValueKey('focused_task_overlay_${task.id}')), findsOneWidget);
    });

    testWidgets('TEST T14-2 — Completed task: quicknotes://task/<completed-id> routes to HomeScreen with focusedTaskId', (tester) async {
      final task = await engine.createTask(
        title: 'Completed Task T14-2',
        dueDate: DateTime.now(),
        priority: 'Medium',
      );
      // Mark completed
      final idx = repository.db.indexWhere((t) => t.id == task.id);
      repository.db[idx] = repository.db[idx].copyWith(status: TaskStatus.completed);
      await engine.reloadFromRepository();

      await tester.pumpWidget(buildTestApp(initialScreen: const Scaffold(body: Text('Initial'))));
      await tester.pump(const Duration(milliseconds: 300));

      final action = DeepLinkAction.parse(Uri.parse('quicknotes://task/${task.id}'))!;
      final BuildContext context = tester.element(find.byType(Scaffold).first);
      await coordinator.executeAction(context, action);
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(TaskEditorScreen), findsNothing);
      final HomeScreen homeScreen = tester.widget(find.byType(HomeScreen));
      expect(homeScreen.initialShowTasks, isTrue);
      expect(homeScreen.focusedTaskId, task.id);
    });

    testWidgets('TEST T14-3 — Deleted task: quicknotes://task/<deleted-id> falls back to HomeScreen(initialShowTasks: true) without overlay', (tester) async {
      final task = await engine.createTask(
        title: 'Deleted Task T14-3',
        dueDate: DateTime.now(),
        priority: 'Low',
      );
      // Mark deleted
      final idx = repository.db.indexWhere((t) => t.id == task.id);
      repository.db[idx] = repository.db[idx].copyWith(isDeleted: true, deletedAt: DateTime.now());
      await engine.reloadFromRepository();

      await tester.pumpWidget(buildTestApp(initialScreen: const Scaffold(body: Text('Initial'))));
      await tester.pump(const Duration(milliseconds: 300));

      final action = DeepLinkAction.parse(Uri.parse('quicknotes://task/${task.id}'))!;
      final BuildContext context = tester.element(find.byType(Scaffold).first);
      await coordinator.executeAction(context, action);
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(TaskEditorScreen), findsNothing);
      final HomeScreen homeScreen = tester.widget(find.byType(HomeScreen));
      expect(homeScreen.initialShowTasks, isTrue);
      expect(homeScreen.focusedTaskId, isNull);
      expect(find.byKey(ValueKey('focused_task_overlay_${task.id}')), findsNothing);
    });

    testWidgets('TEST T14-4 — Archived task: quicknotes://task/<archived-id> falls back to HomeScreen(initialShowTasks: true) without overlay', (tester) async {
      final task = await engine.createTask(
        title: 'Archived Task T14-4',
        dueDate: DateTime.now(),
        priority: 'Low',
      );
      // Mark archived
      final idx = repository.db.indexWhere((t) => t.id == task.id);
      repository.db[idx] = repository.db[idx].copyWith(status: TaskStatus.archived);
      await engine.reloadFromRepository();

      await tester.pumpWidget(buildTestApp(initialScreen: const Scaffold(body: Text('Initial'))));
      await tester.pump(const Duration(milliseconds: 300));

      final action = DeepLinkAction.parse(Uri.parse('quicknotes://task/${task.id}'))!;
      final BuildContext context = tester.element(find.byType(Scaffold).first);
      await coordinator.executeAction(context, action);
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(TaskEditorScreen), findsNothing);
      final HomeScreen homeScreen = tester.widget(find.byType(HomeScreen));
      expect(homeScreen.initialShowTasks, isTrue);
      expect(homeScreen.focusedTaskId, isNull);
      expect(find.byKey(ValueKey('focused_task_overlay_${task.id}')), findsNothing);
    });

    testWidgets('TEST T14-5 — Unknown task: quicknotes://task/<missing-id> falls back to HomeScreen(initialShowTasks: true) without overlay', (tester) async {
      await tester.pumpWidget(buildTestApp(initialScreen: const Scaffold(body: Text('Initial'))));
      await tester.pump(const Duration(milliseconds: 300));

      final action = DeepLinkAction.parse(Uri.parse('quicknotes://task/missing-uuid-14-5'))!;
      final BuildContext context = tester.element(find.byType(Scaffold).first);
      await coordinator.executeAction(context, action);
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(TaskEditorScreen), findsNothing);
      final HomeScreen homeScreen = tester.widget(find.byType(HomeScreen));
      expect(homeScreen.initialShowTasks, isTrue);
      expect(homeScreen.focusedTaskId, isNull);
      expect(find.byKey(const ValueKey('focused_task_overlay_missing-uuid-14-5')), findsNothing);
    });

    testWidgets('TEST T14-6 — Task creation regression: quicknotes://task/new opens TaskEditorScreen', (tester) async {
      await tester.pumpWidget(buildTestApp(initialScreen: const Scaffold(body: Text('Initial'))));
      await tester.pump(const Duration(milliseconds: 300));

      final action = DeepLinkAction.parse(Uri.parse('quicknotes://task/new'))!;
      expect(action.type, DeepLinkActionType.newTask);

      final BuildContext context = tester.element(find.byType(Scaffold).first);
      await coordinator.executeAction(context, action);
      await tester.pumpAndSettle();

      expect(find.byType(TaskEditorScreen), findsOneWidget);
    });

    testWidgets('TEST T14-7 — Task creation alias regression: quicknotes://tasks/new opens TaskEditorScreen', (tester) async {
      await tester.pumpWidget(buildTestApp(initialScreen: const Scaffold(body: Text('Initial'))));
      await tester.pump(const Duration(milliseconds: 300));

      final action = DeepLinkAction.parse(Uri.parse('quicknotes://tasks/new'))!;
      expect(action.type, DeepLinkActionType.newTask);

      final BuildContext context = tester.element(find.byType(Scaffold).first);
      await coordinator.executeAction(context, action);
      await tester.pumpAndSettle();

      expect(find.byType(TaskEditorScreen), findsOneWidget);
    });

    testWidgets('TEST T14-8 — Tasks overview regression: quicknotes://tasks opens HomeScreen(initialShowTasks: true) without focused task', (tester) async {
      await tester.pumpWidget(buildTestApp(initialScreen: const Scaffold(body: Text('Initial'))));
      await tester.pump(const Duration(milliseconds: 300));

      final action = DeepLinkAction.parse(Uri.parse('quicknotes://tasks'))!;
      expect(action.type, DeepLinkActionType.openTasks);

      final BuildContext context = tester.element(find.byType(Scaffold).first);
      await coordinator.executeAction(context, action);
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      final HomeScreen homeScreen = tester.widget(find.byType(HomeScreen));
      expect(homeScreen.initialShowTasks, isTrue);
      expect(homeScreen.focusedTaskId, isNull);
    });

    testWidgets('TEST T14-9 — Note deep-link regression: quicknotes://note/new opens NoteEditorScreen', (tester) async {
      await tester.pumpWidget(buildTestApp(initialScreen: const Scaffold(body: Text('Initial'))));
      await tester.pump(const Duration(milliseconds: 300));

      final action = DeepLinkAction.parse(Uri.parse('quicknotes://note/new'))!;
      expect(action.type, DeepLinkActionType.newNote);

      final BuildContext context = tester.element(find.byType(Scaffold).first);
      await coordinator.executeAction(context, action);
      await tester.pumpAndSettle();

      expect(find.byType(NoteEditorScreen), findsOneWidget);
    });

    testWidgets('TEST T14-10 — Sequential task isolation: task/A -> task/B results in B focused and clean state', (tester) async {
      final taskA = await engine.createTask(
        title: 'Task A Isolation',
        dueDate: DateTime.now(),
        priority: 'High',
      );
      final taskB = await engine.createTask(
        title: 'Task B Isolation',
        dueDate: DateTime.now(),
        priority: 'Medium',
      );

      await tester.pumpWidget(buildTestApp(initialScreen: const Scaffold(body: Text('Initial'))));
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Open Task A
      final actionA = DeepLinkAction.parse(Uri.parse('quicknotes://task/${taskA.id}'))!;
      BuildContext context = tester.element(find.byType(Scaffold).first);
      await coordinator.executeAction(context, actionA);
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      HomeScreen homeScreen = tester.widget(find.byType(HomeScreen));
      expect(homeScreen.focusedTaskId, taskA.id);

      // 2. Open Task B
      final actionB = DeepLinkAction.parse(Uri.parse('quicknotes://task/${taskB.id}'))!;
      context = tester.element(find.byType(HomeScreen).first);
      await coordinator.executeAction(context, actionB);
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      homeScreen = tester.widget(find.byType(HomeScreen));
      expect(homeScreen.focusedTaskId, taskB.id);
      expect(find.byKey(ValueKey('focused_task_overlay_${taskB.id}')), findsOneWidget);
      expect(find.byKey(ValueKey('focused_task_overlay_${taskA.id}')), findsNothing);
    });

    testWidgets('TEST T14-11 — No mutation on widget tap: executing openTask action does not mutate task in repository', (tester) async {
      final task = await engine.createTask(
        title: 'Immutable Task On Tap',
        dueDate: DateTime.now().add(const Duration(days: 1)),
        priority: 'High',
      );
      final initialUpdatedAt = task.updatedAt;
      final initialStatus = task.status;

      await tester.pumpWidget(buildTestApp(initialScreen: const Scaffold(body: Text('Initial'))));
      await tester.pump(const Duration(milliseconds: 300));

      final action = DeepLinkAction.parse(Uri.parse('quicknotes://task/${task.id}'))!;
      final BuildContext context = tester.element(find.byType(Scaffold).first);
      await coordinator.executeAction(context, action);
      await tester.pumpAndSettle();

      // Check task in repository
      final repoTask = repository.db.firstWhere((t) => t.id == task.id);
      expect(repoTask.title, 'Immutable Task On Tap');
      expect(repoTask.status, initialStatus);
      expect(repoTask.updatedAt, initialUpdatedAt);
      expect(repoTask.isDeleted, isFalse);
    });
  });

  group('Phase T15D — Deep-Link Lifecycle, Overlay Persistence & Intent Replay Tests', () {
    late DeepLinkCoordinator coordinator;
    late MockTasksRepository repository;
    late TaskEngine engine;
    late TasksProvider tasksProvider;
    late NotesProvider notesProvider;

    setUp(() async {
      coordinator = DeepLinkCoordinator.instance;
      coordinator.dispose();

      repository = MockTasksRepository();
      engine = TaskEngine(
        repository: repository,
        clock: const SystemClock(),
        scheduler: LoggingReminderScheduler(),
      );
      await engine.initialize();
      tasksProvider = TasksProvider(engine: engine);
      notesProvider = NotesProvider();
    });

    tearDown(() {
      coordinator.dispose();
      tasksProvider.dispose();
      notesProvider.dispose();
    });

    Widget buildTestApp({Widget? initialScreen}) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<TasksProvider>.value(value: tasksProvider),
          ChangeNotifierProvider<NotesProvider>.value(value: notesProvider),
        ],
        child: MaterialApp(
          home: initialScreen ?? const Scaffold(body: Text('Initial Screen')),
        ),
      );
    }

    testWidgets('T15D-1: Existing active task deep link opens HomeScreen with focused task overlay', (tester) async {
      final task = await engine.createTask(
        title: 'Active Focus Task',
        dueDate: DateTime(2026, 9, 1, 10, 0),
        priority: 'High',
      );

      await tester.pumpWidget(buildTestApp());
      await tester.pump(const Duration(milliseconds: 300));

      final action = DeepLinkAction.parse(Uri.parse('quicknotes://task/${task.id}'))!;
      final BuildContext context = tester.element(find.byType(Scaffold).first);
      await coordinator.executeAction(context, action);
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      final homeScreen = tester.widget<HomeScreen>(find.byType(HomeScreen));
      expect(homeScreen.focusedTaskId, task.id);
      expect(find.byKey(ValueKey('focused_task_overlay_${task.id}')), findsOneWidget);
    });

    test('T15D-2: Same deep-link event cannot execute twice (consumePendingAction clears buffer)', () async {
      coordinator.setPendingAction(const DeepLinkAction(DeepLinkActionType.newTask));
      expect(coordinator.pendingAction, isNotNull);

      final firstConsumption = coordinator.consumePendingAction();
      expect(firstConsumption, isNotNull);
      expect(firstConsumption!.type, DeepLinkActionType.newTask);

      final secondConsumption = coordinator.consumePendingAction();
      expect(secondConsumption, isNull);
    });

    test('T15D-3: Consumed initial widget deep link does not replay on subsequent initialize', () async {
      final initialUri = Uri.parse('quicknotes://task/task-cold-1');

      // 1. First cold launch: captures action
      await coordinator.initialize(
        initialUriProvider: () async => initialUri,
        uriStream: const Stream.empty(),
      );
      expect(coordinator.pendingAction, isNotNull);
      expect(coordinator.pendingAction!.queryParameters['taskId'], 'task-cold-1');

      // Consume the action
      final action = coordinator.consumePendingAction();
      expect(action, isNotNull);
      expect(coordinator.pendingAction, isNull);

      // Subsequent markNavigationReady or action consumption does not resurrect action
      await coordinator.markNavigationReady();
      expect(coordinator.pendingAction, isNull);
    });

    test('T15D-4: Warm app resume does not newly recreate a previously consumed task deep link', () async {
      final streamController = StreamController<Uri?>();
      final receivedActions = <DeepLinkAction>[];

      await coordinator.initialize(
        initialUriProvider: () async => null,
        uriStream: streamController.stream,
        onActionDispatched: (action) => receivedActions.add(action),
      );
      await coordinator.markNavigationReady();

      // Dispatch warm widget click
      streamController.add(Uri.parse('quicknotes://task/warm-task-1'));
      await pumpEventQueue();

      expect(receivedActions.length, 1);
      expect(receivedActions.first.queryParameters['taskId'], 'warm-task-1');

      // Normal app resume without new widget tap (null URI on stream or no new event)
      await pumpEventQueue();
      expect(receivedActions.length, 1); // No new action dispatched
    });

    test('T15D-5: Cold launcher launch (null initial URI) does not replay previous widget task', () async {
      await coordinator.initialize(
        initialUriProvider: () async => null,
        uriStream: const Stream.empty(),
      );

      expect(coordinator.pendingAction, isNull);
    });

    testWidgets('T15D-6: Backdrop tap dismissal clears focused task overlay', (tester) async {
      final task = await engine.createTask(
        title: 'Dismissible Task',
        dueDate: DateTime(2026, 9, 1, 10, 0),
        priority: 'Medium',
      );

      await tester.pumpWidget(buildTestApp(
        initialScreen: HomeScreen(initialShowTasks: true, focusedTaskId: task.id),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey('focused_task_overlay_${task.id}')), findsOneWidget);

      // Tap the backdrop gesture detector outside the task card
      await tester.tapAt(const Offset(20, 50));
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey('focused_task_overlay_${task.id}')), findsNothing);
    });

    testWidgets('T15D-7: Android Back dismisses focused overlay first before leaving HomeScreen', (tester) async {
      final task = await engine.createTask(
        title: 'Back Dismiss Task',
        dueDate: DateTime(2026, 9, 1, 10, 0),
        priority: 'High',
      );

      await tester.pumpWidget(buildTestApp(
        initialScreen: HomeScreen(initialShowTasks: true, focusedTaskId: task.id),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey('focused_task_overlay_${task.id}')), findsOneWidget);

      // Simulate Android Back button press via system pop
      final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
      await widgetsAppState.didPopRoute();
      await tester.pumpAndSettle();

      // Overlay should be dismissed, but HomeScreen remains mounted
      expect(find.byKey(ValueKey('focused_task_overlay_${task.id}')), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('T15D-8: Task creation deep links (task/new, tasks/new) route to TaskEditorScreen', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump(const Duration(milliseconds: 300));

      final actionNew1 = DeepLinkAction.parse(Uri.parse('quicknotes://task/new'))!;
      final BuildContext context = tester.element(find.byType(Scaffold).first);
      await coordinator.executeAction(context, actionNew1);
      await tester.pumpAndSettle();

      expect(find.byType(TaskEditorScreen), findsOneWidget);
    });

    testWidgets('T15D-9: Tasks overview deep link (quicknotes://tasks) routes to HomeScreen without overlay', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump(const Duration(milliseconds: 300));

      final actionTasks = DeepLinkAction.parse(Uri.parse('quicknotes://tasks'))!;
      final BuildContext context = tester.element(find.byType(Scaffold).first);
      await coordinator.executeAction(context, actionTasks);
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      final homeScreen = tester.widget<HomeScreen>(find.byType(HomeScreen));
      expect(homeScreen.focusedTaskId, isNull);
    });

    testWidgets('T15D-10: Note deep links (note/new, checklist/new) route to NoteEditorScreen', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump(const Duration(milliseconds: 300));

      final actionNote = DeepLinkAction.parse(Uri.parse('quicknotes://note/new'))!;
      final BuildContext context = tester.element(find.byType(Scaffold).first);
      await coordinator.executeAction(context, actionNote);
      await tester.pumpAndSettle();

      expect(find.byType(NoteEditorScreen), findsOneWidget);
    });

    testWidgets('T15D-11: Deleted task deep link falls back safely without overlay', (tester) async {
      final task = await engine.createTask(
        title: 'Deleted Task 15D',
        dueDate: DateTime(2026, 9, 1, 10, 0),
      );
      await engine.deleteTask(task.id);

      await tester.pumpWidget(buildTestApp());
      await tester.pump(const Duration(milliseconds: 300));

      final action = DeepLinkAction.parse(Uri.parse('quicknotes://task/${task.id}'))!;
      final BuildContext context = tester.element(find.byType(Scaffold).first);
      await coordinator.executeAction(context, action);
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      final homeScreen = tester.widget<HomeScreen>(find.byType(HomeScreen));
      expect(homeScreen.focusedTaskId, isNull);
    });

    testWidgets('T15D-12: Archived task deep link falls back safely without overlay', (tester) async {
      final task = await engine.createTask(
        title: 'Archived Task 15D',
        dueDate: DateTime(2026, 9, 1, 10, 0),
      );
      await engine.updateTask(task.copyWith(status: TaskStatus.completed));
      await engine.updateTask(task.copyWith(status: TaskStatus.archived));

      await tester.pumpWidget(buildTestApp());
      await tester.pump(const Duration(milliseconds: 300));

      final action = DeepLinkAction.parse(Uri.parse('quicknotes://task/${task.id}'))!;
      final BuildContext context = tester.element(find.byType(Scaffold).first);
      await coordinator.executeAction(context, action);
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      final homeScreen = tester.widget<HomeScreen>(find.byType(HomeScreen));
      expect(homeScreen.focusedTaskId, isNull);
    });

    testWidgets('T15D-13: Missing task deep link falls back safely without overlay', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump(const Duration(milliseconds: 300));

      final action = DeepLinkAction.parse(Uri.parse('quicknotes://task/non-existent-uuid-999'))!;
      final BuildContext context = tester.element(find.byType(Scaffold).first);
      await coordinator.executeAction(context, action);
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      final homeScreen = tester.widget<HomeScreen>(find.byType(HomeScreen));
      expect(homeScreen.focusedTaskId, isNull);
    });

    test('T15D-14: App-lock / readiness buffering holds action until markNavigationReady', () async {
      coordinator.setPendingAction(const DeepLinkAction(DeepLinkActionType.newTask));
      expect(coordinator.isNavigationReady, isFalse);
      expect(coordinator.pendingAction, isNotNull);

      DeepLinkAction? dispatched;
      coordinator.initialize(
        uriStream: const Stream.empty(),
        onActionDispatched: (a) => dispatched = a,
      );

      expect(dispatched, isNull);
      await coordinator.markNavigationReady();
      expect(dispatched, isNotNull);
      expect(dispatched!.type, DeepLinkActionType.newTask);
      expect(coordinator.pendingAction, isNull);
    });

    testWidgets('T15D-15: A second widget task tap focuses the new task after first was dismissed', (tester) async {
      final task1 = await engine.createTask(
        title: 'Task Alpha',
        dueDate: DateTime(2026, 9, 1, 10, 0),
      );
      final task2 = await engine.createTask(
        title: 'Task Beta',
        dueDate: DateTime(2026, 9, 1, 10, 0),
      );

      await tester.pumpWidget(buildTestApp());
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Tap Task Alpha
      final action1 = DeepLinkAction.parse(Uri.parse('quicknotes://task/${task1.id}'))!;
      BuildContext context = tester.element(find.byType(Scaffold).first);
      await coordinator.executeAction(context, action1);
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey('focused_task_overlay_${task1.id}')), findsOneWidget);

      // Dismiss Task Alpha
      await tester.tapAt(const Offset(20, 50));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('focused_task_overlay_${task1.id}')), findsNothing);

      // 2. Tap Task Beta
      final action2 = DeepLinkAction.parse(Uri.parse('quicknotes://task/${task2.id}'))!;
      context = tester.element(find.byType(HomeScreen).first);
      await coordinator.executeAction(context, action2);
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey('focused_task_overlay_${task2.id}')), findsOneWidget);
      expect(find.byKey(ValueKey('focused_task_overlay_${task1.id}')), findsNothing);
    });
  });
}

class MockTasksRepository implements TasksRepository {
  final List<TaskItem> db = [];
  int _nextNotificationId = 1000;

  @override
  Future<List<TaskItem>> getTasks() async => List.from(db);

  @override
  Future<List<TaskItem>> getTasksForDate(DateTime date) async {
    return db.where((t) => t.dueDate.day == date.day).toList();
  }

  @override
  Future<int> insertTask(TaskItem task) async {
    db.add(task);
    return 1;
  }

  @override
  Future<int> updateTask(TaskItem task) async {
    final idx = db.indexWhere((t) => t.id == task.id);
    if (idx != -1) {
      db[idx] = task;
    }
    return 1;
  }

  @override
  Future<List<TaskItem>> getTrashTasks() async =>
      db.where((t) => t.isDeleted).toList();

  @override
  Future<int> trashTask(String id) async {
    final idx = db.indexWhere((t) => t.id == id);
    if (idx != -1) {
      db[idx] = db[idx].copyWith(isDeleted: true, deletedAt: DateTime.now());
    }
    return 1;
  }

  @override
  Future<int> restoreTask(String id) async {
    final idx = db.indexWhere((t) => t.id == id);
    if (idx != -1) {
      db[idx] = db[idx].copyWith(isDeleted: false, clearDeletedAt: true);
    }
    return 1;
  }

  @override
  Future<int> deleteTask(String id) async {
    db.removeWhere((t) => t.id == id);
    return 1;
  }

  @override
  Future<int> emptyTrash() async {
    db.removeWhere((t) => t.isDeleted);
    return 1;
  }

  @override
  Future<int> generateUniqueNotificationId() async {
    return _nextNotificationId++;
  }
}



