import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/models/task_item.dart';
import 'package:quick_notes/models/task_status.dart';
import 'package:quick_notes/models/widget_snapshot_payload.dart';
import 'package:quick_notes/services/widget_data_adapter.dart';

void main() {
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
}
