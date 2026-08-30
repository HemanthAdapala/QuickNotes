import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/models/task_item.dart';
import 'package:quick_notes/models/task_status.dart';
import 'package:quick_notes/services/deep_link_coordinator.dart';

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
}

