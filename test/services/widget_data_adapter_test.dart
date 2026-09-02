import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/models/task_item.dart';
import 'package:quick_notes/models/task_status.dart';
import 'package:quick_notes/models/widget_snapshot_payload.dart';
import 'package:quick_notes/providers/tasks_provider.dart';
import 'package:quick_notes/repositories/tasks_repository.dart';
import 'package:quick_notes/services/clock_service.dart';
import 'package:quick_notes/services/reminder_scheduler.dart';
import 'package:quick_notes/services/session_manager.dart';
import 'package:quick_notes/services/task_engine.dart';
import 'package:quick_notes/services/widget_data_adapter.dart';

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

class MockReminderScheduler implements ReminderScheduler {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> scheduleReminder(TaskItem task) async {}

  @override
  Future<void> cancelReminder(int notificationId) async {}

  Future<void> cancelAllReminders() async {}

  @override
  Future<List<int>> getPendingNotificationIds() async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WidgetDataAdapter Unit Tests', () {
    final fixedNow = DateTime(2026, 8, 28, 14, 0, 0); // Friday, 28 Aug 2026

    Note createTestNote({
      required String id,
      bool isPinned = false,
      bool isLocked = false,
      bool isDeleted = false,
      bool isArchived = false,
      String title = 'Sensitive Secret Note Title',
      String content =
          'Super secret note content that must never leak into widget',
    }) {
      return Note(
        id: id,
        title: title,
        content: content,
        isPinned: isPinned,
        isLocked: isLocked,
        isDeleted: isDeleted,
        isArchived: isArchived,
        tags: const ['work'],
        attachments: const [],
        createdAt: fixedNow,
        updatedAt: fixedNow,
        colorValue: 0,
      );
    }

    TaskItem createTestTask({
      required String id,
      required DateTime dueDate,
      bool completed = false,
      bool isDeleted = false,
      TaskStatus? status,
      String priority = 'Medium',
      String title = 'Secret Task Title',
    }) {
      return TaskItem(
        id: id,
        title: title,
        dueDate: dueDate,
        completed: completed,
        isDeleted: isDeleted,
        status: status,
        priority: priority,
      );
    }

    test('buildSnapshot filters locked, deleted, and archived notes strictly',
        () {
      final adapter = WidgetDataAdapter.custom(
        saveData: (key, value) async => true,
        updateWidget:
            ({name, androidName, iOSName, qualifiedAndroidName}) async => true,
      );

      final notes = [
        createTestNote(id: '1', isPinned: true), // Valid pinned note
        createTestNote(id: '2', isPinned: true), // Valid pinned note
        createTestNote(
            id: '3',
            isPinned: true,
            isLocked: true), // LOCKED (MUST BE EXCLUDED)
        createTestNote(
            id: '4',
            isPinned: true,
            isDeleted: true), // DELETED (MUST BE EXCLUDED)
        createTestNote(
            id: '5',
            isPinned: true,
            isArchived: true), // ARCHIVED (MUST BE EXCLUDED)
        createTestNote(id: '6', isPinned: false), // Not pinned
      ];

      final payload = adapter.buildSnapshot(
        notes: notes,
        tasks: [],
        now: fixedNow,
        hasActiveSession: true,
      );

      expect(payload.pinnedNotesCount, 2);
      expect(payload.dateDayName, 'Friday');
      expect(payload.dateFormatted, '28 Aug');
      expect(payload.hasActiveSession, isTrue);
    });

    test('buildSnapshot calculates pending today and overdue tasks accurately',
        () {
      final adapter = WidgetDataAdapter.custom(
        saveData: (key, value) async => true,
        updateWidget:
            ({name, androidName, iOSName, qualifiedAndroidName}) async => true,
      );

      final tasks = [
        // Task due today (active)
        createTestTask(id: 't1', dueDate: DateTime(2026, 8, 28, 16, 0)),
        // Task due today (completed - EXCLUDED)
        createTestTask(
            id: 't2', dueDate: DateTime(2026, 8, 28, 10, 0), completed: true),
        // Task due today (deleted - EXCLUDED)
        createTestTask(
            id: 't3', dueDate: DateTime(2026, 8, 28, 12, 0), isDeleted: true),
        // Overdue task from yesterday (active)
        createTestTask(id: 't4', dueDate: DateTime(2026, 8, 27, 18, 0)),
        // Overdue task from last week (completed - EXCLUDED)
        createTestTask(
            id: 't5', dueDate: DateTime(2026, 8, 20, 12, 0), completed: true),
        // Future task for tomorrow (active - not today, not overdue)
        createTestTask(id: 't6', dueDate: DateTime(2026, 8, 29, 9, 0)),
      ];

      final payload = adapter.buildSnapshot(
        notes: [],
        tasks: tasks,
        now: fixedNow,
        hasActiveSession: true,
      );

      expect(payload.pendingTasksCount, 1); // Only t1
      expect(payload.overdueTasksCount, 1); // Only t4
    });

    test('buildSnapshot returns empty zeroed payload when session is inactive',
        () {
      final adapter = WidgetDataAdapter.custom(
        saveData: (key, value) async => true,
        updateWidget:
            ({name, androidName, iOSName, qualifiedAndroidName}) async => true,
      );

      final notes = [createTestNote(id: '1', isPinned: true)];
      final tasks = [createTestTask(id: 't1', dueDate: fixedNow)];

      final payload = adapter.buildSnapshot(
        notes: notes,
        tasks: tasks,
        now: fixedNow,
        hasActiveSession: false,
      );

      expect(payload.pinnedNotesCount, 0);
      expect(payload.pendingTasksCount, 0);
      expect(payload.overdueTasksCount, 0);
      expect(payload.hasActiveSession, isFalse);
    });

    test('sync writes payload and legacy keys to platform shared storage',
        () async {
      final savedData = <String, dynamic>{};
      var updateCalled = false;

      final adapter = WidgetDataAdapter.custom(
        saveData: (key, value) async {
          savedData[key] = value;
          return true;
        },
        updateWidget: (
            {name, androidName, iOSName, qualifiedAndroidName}) async {
          updateCalled = true;
          return true;
        },
      );

      final notes = [createTestNote(id: '1', isPinned: true)];
      final tasks = [createTestTask(id: 't1', dueDate: fixedNow)];

      final success = await adapter.sync(
        notes: notes,
        tasks: tasks,
        now: fixedNow,
        hasActiveSession: true,
      );

      expect(success, isTrue);
      expect(updateCalled, isTrue);
      expect(savedData.containsKey(WidgetSnapshotPayload.storageKey), isTrue);
      expect(savedData['pinned_count'], '1');
      expect(savedData['pending_tasks_count'], 1);

      // Verify privacy guarantee: zero note content in serialized aggregate JSON
      final rawJson = savedData[WidgetSnapshotPayload.storageKey] as String;
      expect(rawJson, isNot(contains('Sensitive Secret Note Title')));
      expect(rawJson, isNot(contains('Super secret note content')));
    });

    test('sync writes Task catalog and map excluding deleted and archived tasks',
        () async {
      final savedData = <String, dynamic>{};

      final adapter = WidgetDataAdapter.custom(
        saveData: (key, value) async {
          savedData[key] = value;
          return true;
        },
        updateWidget:
            ({name, androidName, iOSName, qualifiedAndroidName}) async => true,
      );

      final tasks = [
        createTestTask(
          id: 'task-1',
          title: 'Active Task 1',
          dueDate: fixedNow,
          status: TaskStatus.waiting,
          priority: 'High',
        ),
        createTestTask(
          id: 'task-2',
          title: 'Completed Task 2',
          dueDate: fixedNow,
          status: TaskStatus.completed,
          completed: true,
          priority: 'Low',
        ),
        createTestTask(
          id: 'task-deleted',
          title: 'Deleted Task',
          dueDate: fixedNow,
          isDeleted: true,
        ),
        createTestTask(
          id: 'task-archived',
          title: 'Archived Task',
          dueDate: fixedNow,
          status: TaskStatus.archived,
        ),
      ];

      final success = await adapter.sync(
        notes: [],
        tasks: tasks,
        now: fixedNow,
        hasActiveSession: true,
      );

      expect(success, isTrue);
      expect(savedData.containsKey(WidgetDataAdapter.tasksCatalogKey), isTrue);
      expect(savedData.containsKey(WidgetDataAdapter.tasksMapKey), isTrue);

      final catalog = jsonDecode(
          savedData[WidgetDataAdapter.tasksCatalogKey] as String) as List;
      final map = jsonDecode(
          savedData[WidgetDataAdapter.tasksMapKey] as String) as Map<String, dynamic>;

      // 2 valid active tasks included, deleted & archived excluded
      expect(catalog.length, 2);
      expect(map.length, 2);

      expect(map.containsKey('task-1'), isTrue);
      expect(map.containsKey('task-2'), isTrue);
      expect(map.containsKey('task-deleted'), isFalse);
      expect(map.containsKey('task-archived'), isFalse);

      final task1Snap = map['task-1'] as Map<String, dynamic>;
      expect(task1Snap['title'], 'Active Task 1');
      expect(task1Snap['priority'], 'High');
      expect(task1Snap['status_label'], 'Pending');
      expect(task1Snap['completed'], isFalse);

      final task2Snap = map['task-2'] as Map<String, dynamic>;
      expect(task2Snap['title'], 'Completed Task 2');
      expect(task2Snap['priority'], 'Low');
      expect(task2Snap['status_label'], 'Completed');
      expect(task2Snap['completed'], isTrue);
    });

    test('sync isolates platform errors and does not throw', () async {
      final adapter = WidgetDataAdapter.custom(
        saveData: (key, value) async {
          throw Exception('Platform channel unreachable');
        },
        updateWidget:
            ({name, androidName, iOSName, qualifiedAndroidName}) async => true,
      );

      final success = await adapter.sync(
        notes: [createTestNote(id: '1', isPinned: true)],
        tasks: [],
        now: fixedNow,
        hasActiveSession: true,
      );

      // Must return false cleanly without crashing caller
      expect(success, isFalse);
    });

    test('clearSnapshot resets shared storage to signed-out state', () async {
      final savedData = <String, dynamic>{};

      final adapter = WidgetDataAdapter.custom(
        saveData: (key, value) async {
          savedData[key] = value;
          return true;
        },
        updateWidget:
            ({name, androidName, iOSName, qualifiedAndroidName}) async => true,
      );

      final success = await adapter.clearSnapshot(now: fixedNow);

      expect(success, isTrue);
      expect(savedData['pinned_count'], '0');
      expect(savedData['pending_tasks_count'], 0);
      expect(savedData[WidgetDataAdapter.notesCatalogKey], '[]');
      expect(savedData[WidgetDataAdapter.notesMapKey], '{}');
      expect(savedData[WidgetDataAdapter.tasksCatalogKey], '[]');
      expect(savedData[WidgetDataAdapter.tasksMapKey], '{}');

      final decoded =
          jsonDecode(savedData[WidgetSnapshotPayload.storageKey] as String);
      expect(decoded['has_active_session'], false);
      expect(decoded['pinned_notes_count'], 0);
      expect(decoded['pending_tasks_count'], 0);
    });

    test('sync triggers update for all widget providers including SingleTaskLongWidget',
        () async {
      final updatedWidgets = <String>[];

      final adapter = WidgetDataAdapter.custom(
        saveData: (key, value) async => true,
        updateWidget: (
            {name, androidName, iOSName, qualifiedAndroidName}) async {
          if (androidName != null) updatedWidgets.add(androidName);
          return true;
        },
      );

      final success = await adapter.sync(
        notes: [],
        tasks: [createTestTask(id: 't1', dueDate: fixedNow)],
        now: fixedNow,
        hasActiveSession: true,
      );

      expect(success, isTrue);
      expect(updatedWidgets, contains(WidgetDataAdapter.androidWidgetName));
      expect(updatedWidgets, contains(WidgetDataAdapter.singleNoteWidgetName));
      expect(updatedWidgets, contains(WidgetDataAdapter.singleTaskWidgetName));
      expect(
          updatedWidgets, contains(WidgetDataAdapter.singleTaskLongWidgetName));
      expect(updatedWidgets, contains(WidgetDataAdapter.multiTaskWidgetName));
    });
  });

  group('Phase T15C — Widget Data Synchronization Ordering & Concurrency Tests', () {
    final fixedNow = DateTime(2026, 8, 28, 14, 0, 0);

    Note createTestNote({
      required String id,
      bool isPinned = false,
      bool isLocked = false,
      bool isDeleted = false,
      bool isArchived = false,
      String title = 'Sensitive Secret Note Title',
      String content =
          'Super secret note content that must never leak into widget',
    }) {
      return Note(
        id: id,
        title: title,
        content: content,
        isPinned: isPinned,
        isLocked: isLocked,
        isDeleted: isDeleted,
        isArchived: isArchived,
        tags: const ['work'],
        attachments: const [],
        createdAt: fixedNow,
        updatedAt: fixedNow,
        colorValue: 0,
      );
    }

    TaskItem createTestTask({
      required String id,
      required DateTime dueDate,
      bool completed = false,
      bool isDeleted = false,
      TaskStatus? status,
      String priority = 'Medium',
      String title = 'Secret Task Title',
    }) {
      return TaskItem(
        id: id,
        title: title,
        dueDate: dueDate,
        completed: completed,
        isDeleted: isDeleted,
        status: status,
        priority: priority,
      );
    }

    test('T15C-1: Single sync persists correct snapshot', () async {
      final savedData = <String, dynamic>{};
      final adapter = WidgetDataAdapter.custom(
        saveData: (key, value) async {
          savedData[key] = value;
          return true;
        },
        updateWidget: ({name, androidName, iOSName, qualifiedAndroidName}) async => true,
      );

      final task = createTestTask(id: 't1', title: 'Task One', dueDate: fixedNow);
      final success = await adapter.sync(tasks: [task], now: fixedNow, hasActiveSession: true);

      expect(success, isTrue);
      final map = jsonDecode(savedData[WidgetDataAdapter.tasksMapKey] as String) as Map<String, dynamic>;
      expect(map.containsKey('t1'), isTrue);
      expect(map['t1']['title'], 'Task One');
    });

    test('T15C-2: Sequential sync persists latest state', () async {
      final savedData = <String, dynamic>{};
      final adapter = WidgetDataAdapter.custom(
        saveData: (key, value) async {
          savedData[key] = value;
          return true;
        },
        updateWidget: ({name, androidName, iOSName, qualifiedAndroidName}) async => true,
      );

      final taskA = createTestTask(id: 't1', title: 'State A', dueDate: fixedNow);
      final taskB = createTestTask(id: 't1', title: 'State B', dueDate: fixedNow);

      await adapter.sync(tasks: [taskA], now: fixedNow, hasActiveSession: true);
      await adapter.sync(tasks: [taskB], now: fixedNow, hasActiveSession: true);

      final map = jsonDecode(savedData[WidgetDataAdapter.tasksMapKey] as String) as Map<String, dynamic>;
      expect(map['t1']['title'], 'State B');
    });

    test('T15C-3: Overlapping sync guarantees newer state B wins even if A has delayed I/O', () async {
      final savedData = <String, dynamic>{};
      final completerA = Completer<void>();
      var syncACalled = false;

      final adapter = WidgetDataAdapter.custom(
        saveData: (key, value) async {
          if (value is String && value.contains('State A') && !syncACalled) {
            syncACalled = true;
            // Delay A until released
            await completerA.future;
          }
          savedData[key] = value;
          return true;
        },
        updateWidget: ({name, androidName, iOSName, qualifiedAndroidName}) async => true,
      );

      final taskA = createTestTask(id: 't1', title: 'State A', dueDate: fixedNow);
      final taskB = createTestTask(id: 't1', title: 'State B', dueDate: fixedNow);

      // Start A (which will pause inside saveData)
      final futureA = adapter.sync(tasks: [taskA], now: fixedNow, hasActiveSession: true);

      // Start B immediately while A is paused
      final futureB = adapter.sync(tasks: [taskB], now: fixedNow, hasActiveSession: true);

      // Unblock A after B has been queued
      completerA.complete();

      final results = await Future.wait([futureA, futureB]);
      expect(results[0], isTrue);
      expect(results[1], isTrue);

      final map = jsonDecode(savedData[WidgetDataAdapter.tasksMapKey] as String) as Map<String, dynamic>;
      expect(map['t1']['title'], 'State B');
    });

    test('T15C-4: Three overlapping syncs (A, B, C) ensure newest state C wins', () async {
      final savedData = <String, dynamic>{};
      final adapter = WidgetDataAdapter.custom(
        saveData: (key, value) async {
          savedData[key] = value;
          return true;
        },
        updateWidget: ({name, androidName, iOSName, qualifiedAndroidName}) async => true,
      );

      final taskA = createTestTask(id: 't1', title: 'State A', dueDate: fixedNow);
      final taskB = createTestTask(id: 't1', title: 'State B', dueDate: fixedNow);
      final taskC = createTestTask(id: 't1', title: 'State C', dueDate: fixedNow);

      // Dispatch A, B, C rapidly without awaiting
      final futureA = adapter.sync(tasks: [taskA], now: fixedNow, hasActiveSession: true);
      final futureB = adapter.sync(tasks: [taskB], now: fixedNow, hasActiveSession: true);
      final futureC = adapter.sync(tasks: [taskC], now: fixedNow, hasActiveSession: true);

      await Future.wait([futureA, futureB, futureC]);

      final map = jsonDecode(savedData[WidgetDataAdapter.tasksMapKey] as String) as Map<String, dynamic>;
      expect(map['t1']['title'], 'State C');
    });

    test('T15C-5: Task completion burst reflects final authoritative task state', () async {
      final savedData = <String, dynamic>{};
      final adapter = WidgetDataAdapter.custom(
        saveData: (key, value) async {
          savedData[key] = value;
          return true;
        },
        updateWidget: ({name, androidName, iOSName, qualifiedAndroidName}) async => true,
      );

      final taskPending = createTestTask(id: 'burst-1', title: 'Burst Task', dueDate: fixedNow, completed: false, status: TaskStatus.waiting);
      final taskCompleted = createTestTask(id: 'burst-1', title: 'Burst Task', dueDate: fixedNow, completed: true, status: TaskStatus.completed);

      // Simulate rapid toggles: Pending -> Completed -> Pending -> Completed
      final f1 = adapter.sync(tasks: [taskPending], now: fixedNow, hasActiveSession: true);
      final f2 = adapter.sync(tasks: [taskCompleted], now: fixedNow, hasActiveSession: true);
      final f3 = adapter.sync(tasks: [taskPending], now: fixedNow, hasActiveSession: true);
      final f4 = adapter.sync(tasks: [taskCompleted], now: fixedNow, hasActiveSession: true);

      await Future.wait([f1, f2, f3, f4]);

      final map = jsonDecode(savedData[WidgetDataAdapter.tasksMapKey] as String) as Map<String, dynamic>;
      expect(map['burst-1']['completed'], isTrue);
      expect(map['burst-1']['status_label'], 'Completed');
    });

    test('T15C-6: Map and catalog consistency: written atomically for identical generation', () async {
      final writtenPairs = <Map<String, String>>[];
      String? currentCatalog;
      String? currentMap;

      final adapter = WidgetDataAdapter.custom(
        saveData: (key, value) async {
          if (key == WidgetDataAdapter.tasksCatalogKey) {
            currentCatalog = value as String;
          } else if (key == WidgetDataAdapter.tasksMapKey) {
            currentMap = value as String;
            writtenPairs.add({'catalog': currentCatalog!, 'map': currentMap!});
          }
          return true;
        },
        updateWidget: ({name, androidName, iOSName, qualifiedAndroidName}) async => true,
      );

      final task1 = createTestTask(id: 'gen-1', title: 'Generation 1', dueDate: fixedNow);
      final task2 = createTestTask(id: 'gen-2', title: 'Generation 2', dueDate: fixedNow);

      final f1 = adapter.sync(tasks: [task1], now: fixedNow, hasActiveSession: true);
      final f2 = adapter.sync(tasks: [task2], now: fixedNow, hasActiveSession: true);

      await Future.wait([f1, f2]);

      expect(writtenPairs.length, 2);
      // Verify first write had matching catalog & map
      expect(writtenPairs[0]['catalog'], contains('gen-1'));
      expect(writtenPairs[0]['map'], contains('Generation 1'));
      // Verify second write had matching catalog & map
      expect(writtenPairs[1]['catalog'], contains('gen-2'));
      expect(writtenPairs[1]['map'], contains('Generation 2'));
    });

    test('T15C-7: Widget refresh ordering: HomeWidget.updateWidget occurs only after saveData completes', () async {
      final executionOrder = <String>[];

      final adapter = WidgetDataAdapter.custom(
        saveData: (key, value) async {
          executionOrder.add('saveData:$key');
          return true;
        },
        updateWidget: ({name, androidName, iOSName, qualifiedAndroidName}) async {
          executionOrder.add('updateWidget:$androidName');
          return true;
        },
      );

      final task = createTestTask(id: 'order-1', title: 'Ordering Task', dueDate: fixedNow);
      await adapter.sync(tasks: [task], now: fixedNow, hasActiveSession: true);

      // Verify all saveDatas preceded any updateWidgets
      final lastSaveIndex = executionOrder.lastIndexWhere((e) => e.startsWith('saveData'));
      final firstUpdateIndex = executionOrder.indexWhere((e) => e.startsWith('updateWidget'));

      expect(lastSaveIndex, isNonNegative);
      expect(firstUpdateIndex, isNonNegative);
      expect(lastSaveIndex, lessThan(firstUpdateIndex));
    });

    test('T15C-8: No data loss: sync does not clear cached tasks when notes are updated', () async {
      final savedData = <String, dynamic>{};
      final adapter = WidgetDataAdapter.custom(
        saveData: (key, value) async {
          savedData[key] = value;
          return true;
        },
        updateWidget: ({name, androidName, iOSName, qualifiedAndroidName}) async => true,
      );

      final task = createTestTask(id: 'retain-1', title: 'Retained Task', dueDate: fixedNow);
      await adapter.sync(tasks: [task], now: fixedNow, hasActiveSession: true);

      // Sync notes only
      final note = createTestNote(id: 'note-1', isPinned: true);
      await adapter.sync(notes: [note], now: fixedNow, hasActiveSession: true);

      // Tasks map should still contain the retained task
      final map = jsonDecode(savedData[WidgetDataAdapter.tasksMapKey] as String) as Map<String, dynamic>;
      expect(map.containsKey('retain-1'), isTrue);
    });

    test('T15C-9: Error recovery: failed sync does not poison or block future sync operations', () async {
      final savedData = <String, dynamic>{};

      final adapter = WidgetDataAdapter.custom(
        saveData: (key, value) async {
          if (value is String && value.contains('Failing Task')) {
            throw Exception('Simulated disk full / channel error');
          }
          savedData[key] = value;
          return true;
        },
        updateWidget: ({name, androidName, iOSName, qualifiedAndroidName}) async => true,
      );

      final failingTask = createTestTask(id: 'fail-1', title: 'Failing Task', dueDate: fixedNow);
      final healthyTask = createTestTask(id: 'health-1', title: 'Healthy Task', dueDate: fixedNow);

      final failResult = await adapter.sync(tasks: [failingTask], now: fixedNow, hasActiveSession: true);
      expect(failResult, isFalse);

      final healthResult = await adapter.sync(tasks: [healthyTask], now: fixedNow, hasActiveSession: true);
      expect(healthResult, isTrue);

      final map = jsonDecode(savedData[WidgetDataAdapter.tasksMapKey] as String) as Map<String, dynamic>;
      expect(map.containsKey('health-1'), isTrue);
      expect(map['health-1']['title'], 'Healthy Task');
    });

    test('T15C-10: Clear snapshot runs in serialized queue without race with sync', () async {
      final savedData = <String, dynamic>{};
      final adapter = WidgetDataAdapter.custom(
        saveData: (key, value) async {
          savedData[key] = value;
          return true;
        },
        updateWidget: ({name, androidName, iOSName, qualifiedAndroidName}) async => true,
      );

      final task = createTestTask(id: 't1', title: 'Pre-logout Task', dueDate: fixedNow);
      
      final f1 = adapter.sync(tasks: [task], now: fixedNow, hasActiveSession: true);
      final f2 = adapter.clearSnapshot(now: fixedNow);

      await Future.wait([f1, f2]);

      expect(savedData[WidgetDataAdapter.tasksCatalogKey], '[]');
      expect(savedData[WidgetDataAdapter.tasksMapKey], '{}');
    });
  });

  group('Phase T15F — Startup Task Widget Catalog Synchronization & Partial-Sync Tests', () {
    final fixedNow = DateTime(2026, 8, 28, 14, 0, 0);

    Note createTestNote({
      required String id,
      bool isPinned = false,
      bool isLocked = false,
      bool isDeleted = false,
      bool isArchived = false,
      String title = 'Test Note Title',
      String content = 'Test Note Content',
    }) {
      return Note(
        id: id,
        title: title,
        content: content,
        isPinned: isPinned,
        isLocked: isLocked,
        isDeleted: isDeleted,
        isArchived: isArchived,
        tags: const ['test'],
        attachments: const [],
        createdAt: fixedNow,
        updatedAt: fixedNow,
        colorValue: 0,
      );
    }

    TaskItem createTestTask({
      required String id,
      required DateTime dueDate,
      bool completed = false,
      bool isDeleted = false,
      TaskStatus? status,
      String priority = 'Medium',
      String title = 'Test Task Title',
    }) {
      return TaskItem(
        id: id,
        title: title,
        dueDate: dueDate,
        completed: completed,
        isDeleted: isDeleted,
        status: status ?? (completed ? TaskStatus.completed : TaskStatus.waiting),
        priority: priority,
      );
    }

    test('T15F-1: Fresh adapter + notes-only sync preserves uninitialized task catalog/map', () async {
      final savedData = <String, dynamic>{};
      final adapter = WidgetDataAdapter.custom(
        saveData: (key, value) async {
          savedData[key] = value;
          return true;
        },
        updateWidget: ({name, androidName, iOSName, qualifiedAndroidName}) async => true,
      );

      final note = createTestNote(id: 'note-1', isPinned: true, title: 'Single Note');
      final success = await adapter.sync(notes: [note], now: fixedNow, hasActiveSession: true);

      expect(success, isTrue);
      // Notes must be synchronized
      expect(savedData.containsKey(WidgetDataAdapter.notesCatalogKey), isTrue);
      expect(savedData.containsKey(WidgetDataAdapter.notesMapKey), isTrue);
      expect(savedData[WidgetDataAdapter.notesCatalogKey], contains('note-1'));

      // Tasks catalog and map must NOT be touched / overwritten with [] or {}
      expect(savedData.containsKey(WidgetDataAdapter.tasksCatalogKey), isFalse);
      expect(savedData.containsKey(WidgetDataAdapter.tasksMapKey), isFalse);
    });

    test('T15F-2: Fresh adapter + tasks-only sync preserves uninitialized note catalog/map', () async {
      final savedData = <String, dynamic>{};
      final adapter = WidgetDataAdapter.custom(
        saveData: (key, value) async {
          savedData[key] = value;
          return true;
        },
        updateWidget: ({name, androidName, iOSName, qualifiedAndroidName}) async => true,
      );

      final task = createTestTask(id: 'task-1', title: 'Task Uno', dueDate: fixedNow);
      final success = await adapter.sync(tasks: [task], now: fixedNow, hasActiveSession: true);

      expect(success, isTrue);
      // Tasks must be synchronized
      expect(savedData.containsKey(WidgetDataAdapter.tasksCatalogKey), isTrue);
      expect(savedData.containsKey(WidgetDataAdapter.tasksMapKey), isTrue);
      expect(savedData[WidgetDataAdapter.tasksCatalogKey], contains('task-1'));

      // Notes catalog and map must NOT be touched / overwritten with [] or {}
      expect(savedData.containsKey(WidgetDataAdapter.notesCatalogKey), isFalse);
      expect(savedData.containsKey(WidgetDataAdapter.notesMapKey), isFalse);
    });

    test('T15F-3: Explicit empty task list (tasks: []) clears task catalog and map', () async {
      final savedData = <String, dynamic>{};
      final adapter = WidgetDataAdapter.custom(
        saveData: (key, value) async {
          savedData[key] = value;
          return true;
        },
        updateWidget: ({name, androidName, iOSName, qualifiedAndroidName}) async => true,
      );

      // Explicitly passing empty list must clear tasks
      final success = await adapter.sync(tasks: [], now: fixedNow, hasActiveSession: true);

      expect(success, isTrue);
      expect(savedData[WidgetDataAdapter.tasksCatalogKey], '[]');
      expect(savedData[WidgetDataAdapter.tasksMapKey], '{}');
    });

    test('T15F-4: Explicit empty note list (notes: []) clears note catalog and map', () async {
      final savedData = <String, dynamic>{};
      final adapter = WidgetDataAdapter.custom(
        saveData: (key, value) async {
          savedData[key] = value;
          return true;
        },
        updateWidget: ({name, androidName, iOSName, qualifiedAndroidName}) async => true,
      );

      // Explicitly passing empty list must clear notes
      final success = await adapter.sync(notes: [], now: fixedNow, hasActiveSession: true);

      expect(success, isTrue);
      expect(savedData[WidgetDataAdapter.notesCatalogKey], '[]');
      expect(savedData[WidgetDataAdapter.notesMapKey], '{}');
    });

    test('T15F-5: Startup order: notes first, tasks second produces complete state without data loss', () async {
      final savedData = <String, dynamic>{};
      final adapter = WidgetDataAdapter.custom(
        saveData: (key, value) async {
          savedData[key] = value;
          return true;
        },
        updateWidget: ({name, androidName, iOSName, qualifiedAndroidName}) async => true,
      );

      final note = createTestNote(id: 'note-seq-1', isPinned: true, title: 'Sequential Note');
      final task = createTestTask(id: 'task-seq-1', title: 'Sequential Task', dueDate: fixedNow);

      // 1. NotesProvider loads first on startup
      await adapter.sync(notes: [note], now: fixedNow, hasActiveSession: true);
      // 2. TasksProvider loads second on startup
      await adapter.sync(tasks: [task], now: fixedNow, hasActiveSession: true);

      final notesCatalog = jsonDecode(savedData[WidgetDataAdapter.notesCatalogKey] as String) as List;
      final tasksCatalog = jsonDecode(savedData[WidgetDataAdapter.tasksCatalogKey] as String) as List;

      expect(notesCatalog.length, 1);
      expect(notesCatalog[0]['id'], 'note-seq-1');
      expect(tasksCatalog.length, 1);
      expect(tasksCatalog[0]['id'], 'task-seq-1');
    });

    test('T15F-6: Startup order: tasks first, notes second produces identical complete state', () async {
      final savedData = <String, dynamic>{};
      final adapter = WidgetDataAdapter.custom(
        saveData: (key, value) async {
          savedData[key] = value;
          return true;
        },
        updateWidget: ({name, androidName, iOSName, qualifiedAndroidName}) async => true,
      );

      final note = createTestNote(id: 'note-seq-2', isPinned: true, title: 'Sequential Note 2');
      final task = createTestTask(id: 'task-seq-2', title: 'Sequential Task 2', dueDate: fixedNow);

      // 1. TasksProvider loads first
      await adapter.sync(tasks: [task], now: fixedNow, hasActiveSession: true);
      // 2. NotesProvider loads second
      await adapter.sync(notes: [note], now: fixedNow, hasActiveSession: true);

      final notesCatalog = jsonDecode(savedData[WidgetDataAdapter.notesCatalogKey] as String) as List;
      final tasksCatalog = jsonDecode(savedData[WidgetDataAdapter.tasksCatalogKey] as String) as List;

      expect(tasksCatalog.length, 1);
      expect(tasksCatalog[0]['id'], 'task-seq-2');
      expect(notesCatalog.length, 1);
      expect(notesCatalog[0]['id'], 'note-seq-2');
    });

    test('T15F-7: Existing persisted task data in shared preferences survives an early notes-only sync', () async {
      final savedData = <String, dynamic>{
        WidgetDataAdapter.tasksCatalogKey: '[{"id":"persisted-t1","title":"Persisted Task"}]',
        WidgetDataAdapter.tasksMapKey: '{"persisted-t1":{"id":"persisted-t1","title":"Persisted Task"}}',
      };

      final adapter = WidgetDataAdapter.custom(
        saveData: (key, value) async {
          savedData[key] = value;
          return true;
        },
        updateWidget: ({name, androidName, iOSName, qualifiedAndroidName}) async => true,
      );

      final note = createTestNote(id: 'fresh-note', isPinned: true);
      // Early notes-only sync occurs
      await adapter.sync(notes: [note], now: fixedNow, hasActiveSession: true);

      // Persisted tasks data in shared preferences must remain completely untouched
      expect(savedData[WidgetDataAdapter.tasksCatalogKey], '[{"id":"persisted-t1","title":"Persisted Task"}]');
      expect(savedData[WidgetDataAdapter.tasksMapKey], '{"persisted-t1":{"id":"persisted-t1","title":"Persisted Task"}}');
      expect(savedData[WidgetDataAdapter.notesCatalogKey], contains('fresh-note'));
    });

    test('T15F-8: Existing persisted note data in shared preferences survives an early tasks-only sync', () async {
      final savedData = <String, dynamic>{
        WidgetDataAdapter.notesCatalogKey: '[{"id":"persisted-n1","title":"Persisted Note"}]',
        WidgetDataAdapter.notesMapKey: '{"persisted-n1":{"id":"persisted-n1","title":"Persisted Note"}}',
      };

      final adapter = WidgetDataAdapter.custom(
        saveData: (key, value) async {
          savedData[key] = value;
          return true;
        },
        updateWidget: ({name, androidName, iOSName, qualifiedAndroidName}) async => true,
      );

      final task = createTestTask(id: 'fresh-task', dueDate: fixedNow);
      // Early tasks-only sync occurs
      await adapter.sync(tasks: [task], now: fixedNow, hasActiveSession: true);

      // Persisted notes data in shared preferences must remain completely untouched
      expect(savedData[WidgetDataAdapter.notesCatalogKey], '[{"id":"persisted-n1","title":"Persisted Note"}]');
      expect(savedData[WidgetDataAdapter.notesMapKey], '{"persisted-n1":{"id":"persisted-n1","title":"Persisted Note"}}');
      expect(savedData[WidgetDataAdapter.tasksCatalogKey], contains('fresh-task'));
    });

    test('T15F-9: TasksProvider startup synchronization publishes initial repository tasks to HomeWidget', () async {
      SharedPreferences.setMockInitialValues({'active_user_id': 'test-auth-user'});
      await SessionManager().init();

      final savedData = <String, dynamic>{};
      Future<dynamic> mockHandler(MethodCall call) async {
        if (call.method == 'saveWidgetData') {
          if (call.arguments is Map) {
            final args = call.arguments as Map<dynamic, dynamic>;
            final id = args['id'] ?? args['key'];
            final data = args['data'] ?? args['value'];
            if (id != null) {
              savedData[id.toString()] = data;
            }
          }
          return true;
        }
        return true;
      }

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('home_widget'), mockHandler);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('es.antonborri.home_widget'), mockHandler);

      final repo = MockTasksRepository();
      final startupTask = createTestTask(
        id: 'startup-task-1',
        title: 'Task Loaded on App Launch',
        dueDate: fixedNow,
      );
      await repo.insertTask(startupTask);

      final clock = TestClock(fixedNow);
      final scheduler = MockReminderScheduler();
      final engine = TaskEngine(repository: repo, clock: clock, scheduler: scheduler);

      final provider = TasksProvider(engine: engine);
      await provider.loadTasks();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Verify that the task loaded from repository was synced to WidgetDataAdapter / HomeWidget
      expect(savedData.containsKey(WidgetDataAdapter.tasksCatalogKey), isTrue);
      final catalogJson = savedData[WidgetDataAdapter.tasksCatalogKey] as String;
      expect(catalogJson, contains('startup-task-1'));
      expect(catalogJson, contains('Task Loaded on App Launch'));
    });

    test('T15F-10: Repeated loadTasks and consecutive sync calls do not produce redundant clearing', () async {
      final savedData = <String, dynamic>{};
      final adapter = WidgetDataAdapter.custom(
        saveData: (key, value) async {
          savedData[key] = value;
          return true;
        },
        updateWidget: ({name, androidName, iOSName, qualifiedAndroidName}) async => true,
      );

      final note = createTestNote(id: 'n1', isPinned: true);
      final task = createTestTask(id: 't1', dueDate: fixedNow);

      await adapter.sync(notes: [note], now: fixedNow, hasActiveSession: true);
      await adapter.sync(tasks: [task], now: fixedNow, hasActiveSession: true);

      // Perform multiple consecutive note updates (as when user creates/edits notes)
      await adapter.sync(notes: [note], now: fixedNow, hasActiveSession: true);
      await adapter.sync(notes: [note], now: fixedNow, hasActiveSession: true);

      // Task catalog must still be intact and never cleared
      final tasksCatalog = jsonDecode(savedData[WidgetDataAdapter.tasksCatalogKey] as String) as List;
      expect(tasksCatalog.length, 1);
      expect(tasksCatalog[0]['id'], 't1');
    });
  });
}
