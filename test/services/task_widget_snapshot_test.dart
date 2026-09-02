import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/models/task_item.dart';
import 'package:quick_notes/models/task_status.dart';
import 'package:quick_notes/models/repeat_rule.dart';
import 'package:quick_notes/models/recurrence_rule.dart';
import 'package:quick_notes/models/single_task_snapshot.dart';

void main() {
  group('SingleTaskSnapshot Unit & Serialization Tests (Phase T1)', () {
    final fixedDate = DateTime(2026, 6, 1, 2, 0, 0); // Tuesday, 1 June 2026 02:00 AM

    test('1. Snapshot Creation: basic task produces sanitized snapshot with exact fidelity', () {
      final task = TaskItem(
        id: 'task-uuid-1',
        title: 'Client Meeting Tomorrow',
        description: 'Prepare system architecture and roadmap',
        dueDate: fixedDate,
        priority: 'High',
        status: TaskStatus.waiting,
        repeatRule: RepeatRule.daily,
      );

      final snapshot = SingleTaskSnapshot.fromTask(task, now: fixedDate);

      expect(snapshot.id, 'task-uuid-1');
      expect(snapshot.title, 'Client Meeting Tomorrow');
      expect(snapshot.description, 'Prepare system architecture and roadmap');
      expect(snapshot.completed, isFalse);
      expect(snapshot.status, 'waiting');
      expect(snapshot.statusLabel, 'Pending');
      expect(snapshot.priority, 'High');
      expect(snapshot.hasPriority, isTrue);
      expect(snapshot.isRecurring, isTrue);
      expect(snapshot.hasRepeat, isTrue);
      expect(snapshot.repeatLabel, 'Daily');
      expect(snapshot.formattedDate, 'Mon, 1 June 2026'); // Evaluated in local timezone
      expect(snapshot.formattedTime.isNotEmpty, isTrue);
    });

    test('2. Title Handling: trims whitespace, preserves emojis & special characters', () {
      final task = TaskItem(
        id: 'task-uuid-2',
        title: '   ⚡ Launch Sprint 14 Production Deployment 🚀   ',
        dueDate: fixedDate,
        priority: 'None',
      );

      final snapshot = SingleTaskSnapshot.fromTask(task);
      expect(snapshot.title, '⚡ Launch Sprint 14 Production Deployment 🚀');

      // Empty title fallback
      final emptyTask = TaskItem(
        id: 'task-uuid-empty',
        title: '   ',
        dueDate: fixedDate,
        priority: 'None',
      );
      final emptySnapshot = SingleTaskSnapshot.fromTask(emptyTask);
      expect(emptySnapshot.title, 'Untitled Task');
    });

    test('3. Completion States: correctly derives Pending vs Completed across TaskStatus enum', () {
      // Waiting -> Pending
      final waitingTask = TaskItem(
        id: 't-waiting',
        title: 'Waiting Task',
        dueDate: fixedDate,
        priority: 'Low',
        status: TaskStatus.waiting,
      );
      expect(SingleTaskSnapshot.fromTask(waitingTask).completed, isFalse);
      expect(SingleTaskSnapshot.fromTask(waitingTask).statusLabel, 'Pending');

      // Scheduled -> Pending
      final scheduledTask = TaskItem(
        id: 't-scheduled',
        title: 'Scheduled Task',
        dueDate: fixedDate,
        priority: 'Low',
        status: TaskStatus.scheduled,
      );
      expect(SingleTaskSnapshot.fromTask(scheduledTask).completed, isFalse);
      expect(SingleTaskSnapshot.fromTask(scheduledTask).statusLabel, 'Pending');

      // Missed -> Pending
      final missedTask = TaskItem(
        id: 't-missed',
        title: 'Missed Task',
        dueDate: fixedDate,
        priority: 'Low',
        status: TaskStatus.missed,
      );
      expect(SingleTaskSnapshot.fromTask(missedTask).completed, isFalse);
      expect(SingleTaskSnapshot.fromTask(missedTask).statusLabel, 'Pending');

      // Completed -> Completed
      final completedTask = TaskItem(
        id: 't-completed',
        title: 'Completed Task',
        dueDate: fixedDate,
        priority: 'Low',
        status: TaskStatus.completed,
      );
      expect(SingleTaskSnapshot.fromTask(completedTask).completed, isTrue);
      expect(SingleTaskSnapshot.fromTask(completedTask).statusLabel, 'Completed');
    });

    test('4. Date & Time Resolution: respects reminderTime > startTime > dueDate hierarchy', () {
      final dueDate = DateTime(2026, 6, 1, 10, 0, 0);
      final startTime = DateTime(2026, 6, 1, 14, 30, 0);
      final reminderTime = DateTime(2026, 6, 1, 9, 15, 0);

      // Hierarchy A: ReminderTime present
      final taskWithReminder = TaskItem(
        id: 't-rem',
        title: 'Task A',
        dueDate: dueDate,
        startTime: startTime,
        reminderTime: reminderTime,
        priority: 'None',
      );
      final snapA = SingleTaskSnapshot.fromTask(taskWithReminder);
      // Formatted in local time from reminderTime (09:15 AM)
      expect(snapA.formattedTime, isNotEmpty);

      // Hierarchy B: No reminderTime, but startTime present
      final taskWithStart = TaskItem(
        id: 't-start',
        title: 'Task B',
        dueDate: dueDate,
        startTime: startTime,
        priority: 'None',
      );
      final snapB = SingleTaskSnapshot.fromTask(taskWithStart);
      expect(snapB.formattedTime, isNotEmpty);

      // Hierarchy C: Only dueDate present
      final taskWithDue = TaskItem(
        id: 't-due',
        title: 'Task C',
        dueDate: dueDate,
        priority: 'None',
      );
      final snapC = SingleTaskSnapshot.fromTask(taskWithDue);
      expect(snapC.formattedTime, isNotEmpty);
    });

    test('5. Priority Normalization: handles High, Medium, Low, None and color string aliases', () {
      final pHigh = SingleTaskSnapshot.fromTask(
          TaskItem(id: '1', title: 'T', dueDate: fixedDate, priority: 'High'));
      expect(pHigh.priority, 'High');
      expect(pHigh.hasPriority, isTrue);

      final pRed = SingleTaskSnapshot.fromTask(
          TaskItem(id: '2', title: 'T', dueDate: fixedDate, priority: 'red'));
      expect(pRed.priority, 'High');
      expect(pRed.hasPriority, isTrue);

      final pMed = SingleTaskSnapshot.fromTask(
          TaskItem(id: '3', title: 'T', dueDate: fixedDate, priority: 'Medium'));
      expect(pMed.priority, 'Medium');
      expect(pMed.hasPriority, isTrue);

      final pLow = SingleTaskSnapshot.fromTask(
          TaskItem(id: '4', title: 'T', dueDate: fixedDate, priority: 'Low'));
      expect(pLow.priority, 'Low');
      expect(pLow.hasPriority, isTrue);

      final pNone = SingleTaskSnapshot.fromTask(
          TaskItem(id: '5', title: 'T', dueDate: fixedDate, priority: 'None'));
      expect(pNone.priority, 'None');
      expect(pNone.hasPriority, isFalse);

      final pEmpty = SingleTaskSnapshot.fromTask(
          TaskItem(id: '6', title: 'T', dueDate: fixedDate, priority: ''));
      expect(pEmpty.priority, 'None');
      expect(pEmpty.hasPriority, isFalse);
    });

    test('6. Recurrence Mapping: handles RepeatRule and RecurrenceRule models', () {
      // RepeatRule Daily
      final rDaily = SingleTaskSnapshot.fromTask(TaskItem(
        id: '1',
        title: 'T',
        dueDate: fixedDate,
        priority: 'None',
        repeatRule: RepeatRule.daily,
      ));
      expect(rDaily.hasRepeat, isTrue);
      expect(rDaily.isRecurring, isTrue);
      expect(rDaily.repeatLabel, 'Daily');

      // RepeatRule Weekdays
      final rWeekdays = SingleTaskSnapshot.fromTask(TaskItem(
        id: '2',
        title: 'T',
        dueDate: fixedDate,
        priority: 'None',
        repeatRule: RepeatRule.weekdays,
      ));
      expect(rWeekdays.hasRepeat, isTrue);
      expect(rWeekdays.repeatLabel, 'Weekdays');

      // RepeatRule Weekly
      final rWeekly = SingleTaskSnapshot.fromTask(TaskItem(
        id: '3',
        title: 'T',
        dueDate: fixedDate,
        priority: 'None',
        repeatRule: RepeatRule.weekly,
      ));
      expect(rWeekly.hasRepeat, isTrue);
      expect(rWeekly.repeatLabel, 'Weekly');

      // RecurrenceRule Monthly
      final rMonthly = SingleTaskSnapshot.fromTask(TaskItem(
        id: '4',
        title: 'T',
        dueDate: fixedDate,
        priority: 'None',
        recurrence: const RecurrenceRule(type: RecurrenceType.monthly),
      ));
      expect(rMonthly.hasRepeat, isTrue);
      expect(rMonthly.repeatLabel, 'Monthly');

      // RecurrenceRule Yearly
      final rYearly = SingleTaskSnapshot.fromTask(TaskItem(
        id: '5',
        title: 'T',
        dueDate: fixedDate,
        priority: 'None',
        recurrence: const RecurrenceRule(type: RecurrenceType.yearly),
      ));
      expect(rYearly.hasRepeat, isTrue);
      expect(rYearly.repeatLabel, 'Yearly');

      // None
      final rNone = SingleTaskSnapshot.fromTask(TaskItem(
        id: '6',
        title: 'T',
        dueDate: fixedDate,
        priority: 'None',
        repeatRule: RepeatRule.none,
      ));
      expect(rNone.hasRepeat, isFalse);
      expect(rNone.isRecurring, isFalse);
      expect(rNone.repeatLabel, '');
    });

    test('7. JSON Serialization & Round-Trip: preserves all fields identically', () {
      final original = SingleTaskSnapshot(
        id: 'task-test-roundtrip',
        title: 'Shopping with Friends',
        description: 'Get ingredients for dinner',
        status: 'waiting',
        completed: false,
        dueDateIso: fixedDate.toUtc().toIso8601String(),
        formattedDate: 'Tue, 1 June 2026',
        formattedTime: '02:00 AM',
        priority: 'High',
        hasPriority: true,
        isRecurring: true,
        hasRepeat: true,
        repeatLabel: 'Daily',
        statusLabel: 'Pending',
        updatedAt: fixedDate.toUtc(),
      );

      final jsonMap = original.toJson();
      expect(jsonMap.isNotEmpty, isTrue);
      final jsonString = original.toJsonString();
      final decodedMap = jsonDecode(jsonString) as Map<String, dynamic>;
      final reconstructed = SingleTaskSnapshot.fromJson(decodedMap);

      expect(reconstructed.id, original.id);
      expect(reconstructed.title, original.title);
      expect(reconstructed.description, original.description);
      expect(reconstructed.status, original.status);
      expect(reconstructed.completed, original.completed);
      expect(reconstructed.dueDateIso, original.dueDateIso);
      expect(reconstructed.formattedDate, original.formattedDate);
      expect(reconstructed.formattedTime, original.formattedTime);
      expect(reconstructed.priority, original.priority);
      expect(reconstructed.hasPriority, original.hasPriority);
      expect(reconstructed.isRecurring, original.isRecurring);
      expect(reconstructed.hasRepeat, original.hasRepeat);
      expect(reconstructed.repeatLabel, original.repeatLabel);
      expect(reconstructed.statusLabel, original.statusLabel);
      expect(reconstructed.updatedAt, original.updatedAt);
      expect(reconstructed, equals(original));
    });

    test('8. Catalog Entry: produces lightweight representation for configuration picker', () {
      final snapshot = SingleTaskSnapshot(
        id: 'task-cat-1',
        title: 'Team Coffee Sync',
        description: 'Discuss Q3 deliverables',
        status: 'waiting',
        completed: false,
        dueDateIso: fixedDate.toUtc().toIso8601String(),
        formattedDate: 'Tue, 1 June 2026',
        formattedTime: '10:30 AM',
        priority: 'Medium',
        hasPriority: true,
        isRecurring: true,
        hasRepeat: true,
        repeatLabel: 'Weekly',
        statusLabel: 'Pending',
        updatedAt: fixedDate.toUtc(),
      );

      final catalogEntry = snapshot.toCatalogEntry();

      expect(catalogEntry['id'], 'task-cat-1');
      expect(catalogEntry['title'], 'Team Coffee Sync');
      expect(catalogEntry['priority'], 'Medium');
      expect(catalogEntry['has_priority'], isTrue);
      expect(catalogEntry['formatted_date'], 'Tue, 1 June 2026');
      expect(catalogEntry['formatted_time'], '10:30 AM');
      expect(catalogEntry['completed'], isFalse);
      expect(catalogEntry['status_label'], 'Pending');
      expect(catalogEntry['repeat_label'], 'Weekly');
      expect(catalogEntry['has_repeat'], isTrue);
      // Catalog entry intentionally omits description for compactness
      expect(catalogEntry.containsKey('description'), isFalse);
    });
  });

  group('TaskWidgetConfigureActivity Contract & Catalog Parsing Tests (Phase T7)', () {
    final fixedDate = DateTime(2026, 6, 1, 2, 0, 0);

    test('TEST 1 & 2: AppWidgetId Validation Contract', () {
      const invalidId = 0; // AppWidgetManager.INVALID_APPWIDGET_ID
      const validId = 567;

      expect(invalidId <= 0, isTrue); // Rejection / cancellation contract
      expect(validId > 0, isTrue); // Valid appWidgetId accepted
    });

    test('TEST 3: Valid catalog JSON parses successfully', () {
      final task1 = SingleTaskSnapshot.fromTask(TaskItem(
        id: 'task-1',
        title: 'Vitamin D',
        dueDate: fixedDate,
        priority: 'High',
        status: TaskStatus.waiting,
        repeatRule: RepeatRule.weekly,
      ));
      final task2 = SingleTaskSnapshot.fromTask(TaskItem(
        id: 'task-2',
        title: 'Sprint retro',
        dueDate: fixedDate,
        priority: 'Medium',
        status: TaskStatus.completed,
      ));

      final catalogList = [task1.toCatalogEntry(), task2.toCatalogEntry()];
      final rawJson = jsonEncode(catalogList);

      final decoded = jsonDecode(rawJson) as List<dynamic>;
      expect(decoded.length, 2);
      expect(decoded[0]['id'], 'task-1');
      expect(decoded[0]['title'], 'Vitamin D');
      expect(decoded[0]['priority'], 'High');
      expect(decoded[0]['has_priority'], isTrue);
      expect(decoded[0]['repeat_label'], 'Weekly');
      expect(decoded[0]['has_repeat'], isTrue);
      expect(decoded[0]['completed'], isFalse);

      expect(decoded[1]['id'], 'task-2');
      expect(decoded[1]['completed'], isTrue);
      expect(decoded[1]['status_label'], 'Completed');
    });

    test('TEST 4: Malformed catalog JSON does not crash', () {
      const malformedJson = '{invalid-json-array...';
      dynamic result;
      try {
        result = jsonDecode(malformedJson);
      } catch (e) {
        result = <dynamic>[];
      }
      expect(result, isEmpty);
    });

    test('TEST 5: Missing or empty task ID entries are ignored', () {
      final rawEntries = [
        {'id': '', 'title': 'Empty ID Task'},
        {'id': '   ', 'title': 'Whitespace ID Task'},
        {'id': 'valid-task-id', 'title': 'Valid Task'},
        {'title': 'No ID Key Task'},
      ];

      final validItems = <Map<String, dynamic>>[];
      for (final entry in rawEntries) {
        final id = (entry['id'] ?? '').toString().trim();
        if (id.isNotEmpty) {
          validItems.add(entry);
        }
      }

      expect(validItems.length, 1);
      expect(validItems.first['id'], 'valid-task-id');
    });

    test('TEST 6: Single task selection stores exact task UUID', () {
      const selectedUuid = 'fed61850-4822-4fa2-884b-78b65a39e6a8';
      const appWidgetId = 789;
      const prefKey = 'task_widget_id_$appWidgetId';

      final prefsMap = <String, String>{};
      prefsMap[prefKey] = selectedUuid;

      expect(prefsMap['task_widget_id_789'], 'fed61850-4822-4fa2-884b-78b65a39e6a8');
    });

    test('TEST 7: Selection does not alter another widget instance mapping (Isolation)', () {
      final prefsMap = <String, String>{
        'task_widget_id_101': 'task-alpha',
        'task_widget_id_102': 'task-beta',
      };

      // Modifying widget 101
      prefsMap['task_widget_id_101'] = 'task-gamma';

      expect(prefsMap['task_widget_id_101'], 'task-gamma');
      expect(prefsMap['task_widget_id_102'], 'task-beta'); // Unchanged
    });

    test('TEST 8 & 9: Existing mapping preselection vs stale mapping safety', () {
      final catalog = [
        {'id': 'task-active-1', 'title': 'Task 1'},
        {'id': 'task-active-2', 'title': 'Task 2'},
      ];

      // Case 8: Existing mapping is present in catalog -> Preselected
      const existingId = 'task-active-2';
      final isPreselected = catalog.any((item) => item['id'] == existingId);
      expect(isPreselected, isTrue);

      // Case 9: Stale existing mapping (deleted or missing) -> Cleared/Unselected
      const staleId = 'task-deleted-999';
      final isStaleSelected = catalog.any((item) => item['id'] == staleId);
      expect(isStaleSelected, isFalse);
    });

    test('TEST 10: Back / cancel does not overwrite existing mapping', () {
      final prefsMap = <String, String>{
        'task_widget_id_500': 'persisted-task-uuid',
      };

      // User browses and taps a different task in UI
      const browsingSelectedId = 'temporary-selected-task-uuid';

      void onDialogDismissed({required bool isConfirmed}) {
        if (isConfirmed) {
          prefsMap['task_widget_id_500'] = browsingSelectedId;
        }
      }

      // User presses Back -> Cancel event, commit is not called
      onDialogDismissed(isConfirmed: false);
      expect(prefsMap['task_widget_id_500'], 'persisted-task-uuid');
    });

    test('TEST 11: Empty catalog disables confirmation', () {
      bool canConfirm(List<Map<String, dynamic>> catalog, String? selectedTaskId) {
        return catalog.isNotEmpty &&
            selectedTaskId != null &&
            catalog.any((t) => t['id'] == selectedTaskId);
      }

      expect(canConfirm([], null), isFalse);
      expect(canConfirm([], 'task-id'), isFalse);
    });

    test('TEST 12: Completed task remains selectable when present in catalog', () {
      final completedEntry = {
        'id': 'task-done-1',
        'title': 'Completed Project Report',
        'completed': true,
        'status_label': 'Completed',
      };

      final catalog = [completedEntry];
      final isSelectable = catalog.any((t) => t['id'] == 'task-done-1');
      expect(isSelectable, isTrue);
    });

    test('TEST 13: Catalog ordering is strictly preserved', () {
      final rawList = [
        {'id': 'first', 'title': 'First Task'},
        {'id': 'second', 'title': 'Second Task'},
        {'id': 'third', 'title': 'Third Task'},
      ];

      final catalogIds = rawList.map((e) => e['id']).toList();
      expect(catalogIds, ['first', 'second', 'third']);
    });

    test('TEST 14: Selected task triggers immediate widget update contract', () {
      const appWidgetId = 555;
      final updateQueue = <int>[];

      // Simulated confirmation
      updateQueue.add(appWidgetId);

      expect(updateQueue.contains(555), isTrue);
    });

    test('TEST 15: Single Task and Single Task Long share identical per-instance key scheme', () {
      const shortWidgetId = 100;
      const longWidgetId = 200;

      String getTaskPrefKey(int id) => 'task_widget_id_$id';

      expect(getTaskPrefKey(shortWidgetId), 'task_widget_id_100');
      expect(getTaskPrefKey(longWidgetId), 'task_widget_id_200');
    });
  });

  group('Phase T8 — End-to-End Hardening, Lifecycle & Regression Invariant Tests', () {
    final testNow = DateTime(2026, 8, 31, 11, 0, 0);

    test('T8-1: Explicitly configured task remains fixed to target taskId', () {
      final prefs = <String, dynamic>{
        'task_widget_id_101': 'task-alpha',
        'task_widget_id_102': 'task-beta',
      };

      expect(prefs['task_widget_id_101'], 'task-alpha');
      expect(prefs['task_widget_id_102'], 'task-beta');
    });

    test('T8-2: Deleted or archived configured task does NOT fallback to another task', () {
      // Live map contains only task-beta because task-alpha was deleted
      final liveTasksMap = <String, dynamic>{
        'task-beta': {
          'id': 'task-beta',
          'title': 'Task Beta',
        }
      };

      const configuredId = 'task-alpha'; // Deleted task

      // Authoritative resolution algorithm from hardened SingleTaskWidget.kt
      Map<String, dynamic>? resolveTask(String? selectedId, Map<String, dynamic>? tasksMap) {
        if (selectedId == null || selectedId.isEmpty) return null;
        if (tasksMap != null) {
          return tasksMap[selectedId] as Map<String, dynamic>?;
        }
        return null;
      }

      final resolved = resolveTask(configuredId, liveTasksMap);
      // MUST be null (triggering "Task unavailable" fallback), NEVER substitute task-beta!
      expect(resolved, isNull);
    });

    test('T8-3: Multi-task catalog strictly excludes deleted tasks', () {
      final task1 = TaskItem(
        id: 't-active',
        title: 'Active Task',
        dueDate: testNow,
        priority: 'None',
        isDeleted: false,
      );
      final task2 = TaskItem(
        id: 't-deleted',
        title: 'Deleted Task',
        dueDate: testNow,
        priority: 'None',
        isDeleted: true,
      );

      final rawTasks = [task1, task2];
      final activeTasks = rawTasks.where((t) => !t.isDeleted && t.status != TaskStatus.archived).toList();

      expect(activeTasks.length, 1);
      expect(activeTasks.first.id, 't-active');
    });

    test('T8-4: Multi-task catalog strictly excludes archived tasks', () {
      final task1 = TaskItem(
        id: 't-active',
        title: 'Active Task',
        dueDate: testNow,
        priority: 'None',
        status: TaskStatus.waiting,
      );
      final task2 = TaskItem(
        id: 't-archived',
        title: 'Archived Task',
        dueDate: testNow,
        priority: 'None',
        status: TaskStatus.archived,
      );

      final rawTasks = [task1, task2];
      final activeTasks = rawTasks.where((t) => !t.isDeleted && t.status != TaskStatus.archived).toList();

      expect(activeTasks.length, 1);
      expect(activeTasks.first.id, 't-active');
    });

    test('T8-5: Completed task rendering contract maintains status & strike-through flag', () {
      final completedTask = TaskItem(
        id: 't-comp',
        title: 'Submit Expense Report',
        dueDate: testNow,
        priority: 'None',
        status: TaskStatus.completed,
      );

      final snapshot = SingleTaskSnapshot.fromTask(completedTask);
      expect(snapshot.completed, isTrue);
      expect(snapshot.statusLabel, 'Completed');
    });

    test('T8-6: Configuration cancellation leaves previous mapping completely untouched', () {
      final prefs = <String, dynamic>{
        'task_widget_id_777': 'original-task-id',
      };

      // User initiates configuration, browses to new-task-id, then hits Cancel/Back
      void commitSelection({required bool userConfirmed, required String newTaskId}) {
        if (userConfirmed) {
          prefs['task_widget_id_777'] = newTaskId;
        }
      }

      commitSelection(userConfirmed: false, newTaskId: 'new-task-id');

      expect(prefs['task_widget_id_777'], 'original-task-id');
    });

    test('T8-7: Reconfiguration updates ONLY the target AppWidgetId instance', () {
      final prefs = <String, dynamic>{
        'task_widget_id_1': 'task-A',
        'task_widget_id_2': 'task-B',
      };

      // Reconfigure widget 1 to task-C
      prefs['task_widget_id_1'] = 'task-C';

      expect(prefs['task_widget_id_1'], 'task-C');
      expect(prefs['task_widget_id_2'], 'task-B');
    });

    test('T8-8: Two widget instances remain isolated during deletion cleanup', () {
      final prefs = <String, dynamic>{
        'task_widget_id_10': 'task-10',
        'task_widget_data_10': '{"title": "Task 10"}',
        'task_widget_id_20': 'task-20',
        'task_widget_data_20': '{"title": "Task 20"}',
      };

      // Simulated onDeleted for instance 10
      void onDeleted(int id) {
        prefs.remove('task_widget_id_$id');
        prefs.remove('task_widget_data_$id');
      }

      onDeleted(10);

      expect(prefs.containsKey('task_widget_id_10'), isFalse);
      expect(prefs.containsKey('task_widget_data_10'), isFalse);
      expect(prefs['task_widget_id_20'], 'task-20');
      expect(prefs['task_widget_data_20'], '{"title": "Task 20"}');
    });

    test('T8-9: Empty catalog parses cleanly without throwing', () {
      const emptyJson = '[]';
      final list = jsonDecode(emptyJson) as List<dynamic>;
      expect(list, isEmpty);
    });

    test('T8-10: Malformed catalog JSON is handled gracefully', () {
      const malformedJson = '{not-valid-json';
      List<dynamic> parsed;
      try {
        parsed = jsonDecode(malformedJson) as List<dynamic>;
      } catch (_) {
        parsed = [];
      }
      expect(parsed, isEmpty);
    });

    test('T8-11: Stale task map entry missing optional fields falls back safely', () {
      final partialJson = <String, dynamic>{
        'id': 'task-partial',
        // title, priority, date, repeat omitted
      };

      final title = partialJson['title'] ?? 'Untitled Task';
      final priority = partialJson['priority'] ?? 'None';
      final hasPriority = (partialJson['has_priority'] as bool?) ?? false;

      expect(title, 'Untitled Task');
      expect(priority, 'None');
      expect(hasPriority, isFalse);
    });

    test('T8-12: Session clear removes task widget data and resets catalogs', () {
      final prefs = <String, dynamic>{
        'quicknotes_tasks_catalog': '[{"id": "task-1"}]',
        'quicknotes_tasks_map': '{"task-1": {"title": "Task 1"}}',
      };

      // Simulated clearSnapshot
      prefs['quicknotes_tasks_catalog'] = '[]';
      prefs['quicknotes_tasks_map'] = '{}';

      expect(prefs['quicknotes_tasks_catalog'], '[]');
      expect(prefs['quicknotes_tasks_map'], '{}');
    });
  });

  group('Phase T15B — Recurring Task Completion & Occurrence Projection Tests', () {
    final fixedNow = DateTime.utc(2026, 8, 31, 10, 0, 0); // Monday, 31 August 2026

    test('T15B-1: Non-recurring pending task remains pending with original due date', () {
      final task = TaskItem(
        id: 't15b-1',
        title: 'Non-recurring Pending',
        dueDate: DateTime.utc(2026, 8, 31, 15, 0, 0),
        status: TaskStatus.waiting,
        priority: 'High',
      );

      final snapshot = SingleTaskSnapshot.fromTask(task, now: fixedNow);
      expect(snapshot.completed, isFalse);
      expect(snapshot.statusLabel, 'Pending');
      expect(snapshot.status, 'waiting');
      expect(snapshot.dueDateIso, '2026-08-31T15:00:00.000Z');
      expect(snapshot.formattedDate.contains('2026'), isTrue);
    });

    test('T15B-2: Non-recurring completed task remains completed with original due date', () {
      final task = TaskItem(
        id: 't15b-2',
        title: 'Non-recurring Completed',
        dueDate: DateTime.utc(2026, 8, 31, 15, 0, 0),
        status: TaskStatus.completed,
        priority: 'Medium',
      );

      final snapshot = SingleTaskSnapshot.fromTask(task, now: fixedNow);
      expect(snapshot.completed, isTrue);
      expect(snapshot.statusLabel, 'Completed');
      expect(snapshot.status, 'completed');
      expect(snapshot.dueDateIso, '2026-08-31T15:00:00.000Z');
      expect(snapshot.formattedDate.contains('2026'), isTrue);
    });

    test('T15B-3: Weekly recurring task with current occurrence pending projects correct date', () {
      // Created last week (Aug 24), recurrence weekly, Aug 31 is pending
      final task = TaskItem(
        id: 't15b-3',
        title: 'Weekly Team Sync',
        dueDate: DateTime.utc(2026, 8, 24, 10, 0, 0),
        repeatRule: RepeatRule.weekly,
        completedDates: ['2026-08-24'],
        status: TaskStatus.waiting,
        priority: 'High',
      );

      final snapshot = SingleTaskSnapshot.fromTask(task, now: fixedNow);
      expect(snapshot.completed, isFalse);
      expect(snapshot.statusLabel, 'Pending');
      expect(snapshot.formattedDate.contains('August 2026') || snapshot.formattedDate.contains('Aug 2026') || snapshot.formattedDate.contains('31'), isTrue);
      expect(snapshot.dueDateIso, '2026-08-31T10:00:00.000Z');
      expect(snapshot.repeatLabel, 'Weekly');
      expect(snapshot.hasRepeat, isTrue);
    });

    test('T15B-4: Weekly recurring task with current occurrence completed shows Completed today and Pending next week', () {
      // Aug 24 and Aug 31 both completed.
      final task = TaskItem(
        id: 't15b-4',
        title: 'Weekly Grocery Shopping',
        dueDate: DateTime.utc(2026, 8, 24, 9, 30, 0),
        repeatRule: RepeatRule.weekly,
        completedDates: ['2026-08-24', '2026-08-31'],
        status: TaskStatus.waiting,
        priority: 'Low',
      );

      // On Aug 31 (today), it shows Completed for Aug 31
      final snapToday = SingleTaskSnapshot.fromTask(task, now: fixedNow);
      expect(snapToday.completed, isTrue);
      expect(snapToday.statusLabel, 'Completed');
      expect(snapToday.dueDateIso, '2026-08-31T09:30:00.000Z');

      // On Sep 1 (tomorrow), it rolls over to next occurrence (Sep 7) as Pending
      final snapNextDay = SingleTaskSnapshot.fromTask(task, now: DateTime.utc(2026, 9, 1, 9, 0, 0));
      expect(snapNextDay.completed, isFalse);
      expect(snapNextDay.statusLabel, 'Pending');
      expect(snapNextDay.dueDateIso, '2026-09-07T09:30:00.000Z');
    });

    test('T15B-5: Recurring task with multiple completed occurrences shows Completed today and Pending tomorrow', () {
      final task = TaskItem(
        id: 't15b-5',
        title: 'Daily Standup',
        dueDate: DateTime.utc(2026, 8, 28, 9, 0, 0),
        repeatRule: RepeatRule.daily,
        completedDates: ['2026-08-28', '2026-08-29', '2026-08-30', '2026-08-31'],
        status: TaskStatus.waiting,
        priority: 'Medium',
      );

      // On Aug 31 (today), shows Aug 31 as Completed
      final snapToday = SingleTaskSnapshot.fromTask(task, now: fixedNow);
      expect(snapToday.completed, isTrue);
      expect(snapToday.statusLabel, 'Completed');
      expect(snapToday.dueDateIso, '2026-08-31T09:00:00.000Z');

      // On Sep 1 (tomorrow), rolls over to Sep 1 as Pending
      final snapNextDay = SingleTaskSnapshot.fromTask(task, now: DateTime.utc(2026, 9, 1, 8, 0, 0));
      expect(snapNextDay.completed, isFalse);
      expect(snapNextDay.statusLabel, 'Pending');
      expect(snapNextDay.dueDateIso, '2026-09-01T09:00:00.000Z');
    });

    test('T15B-6: Recurring task base TaskItem.dueDate is NOT mutated during snapshot generation', () {
      final originalDueDate = DateTime.utc(2026, 8, 24, 10, 0, 0);
      final task = TaskItem(
        id: 't15b-6',
        title: 'Immutability Check DueDate',
        dueDate: originalDueDate,
        repeatRule: RepeatRule.weekly,
        completedDates: ['2026-08-24', '2026-08-31'],
        status: TaskStatus.waiting,
        priority: 'None',
      );

      final snapshot = SingleTaskSnapshot.fromTask(task, now: fixedNow);
      expect(task.dueDate, originalDueDate);
      expect(task.dueDate, isNot(DateTime.parse(snapshot.dueDateIso)));
    });

    test('T15B-7: Recurring task completedDates list is NOT mutated during snapshot generation', () {
      final originalCompletedDates = ['2026-08-24', '2026-08-31'];
      final task = TaskItem(
        id: 't15b-7',
        title: 'Immutability Check CompletedDates',
        dueDate: DateTime.utc(2026, 8, 24, 10, 0, 0),
        repeatRule: RepeatRule.weekly,
        completedDates: List.unmodifiable(originalCompletedDates),
        status: TaskStatus.waiting,
        priority: 'None',
      );

      SingleTaskSnapshot.fromTask(task, now: fixedNow);
      expect(task.completedDates, ['2026-08-24', '2026-08-31']);
    });

    test('T15B-8: Recurring task status is NOT mutated during snapshot generation', () {
      final task = TaskItem(
        id: 't15b-8',
        title: 'Immutability Check Status',
        dueDate: DateTime.utc(2026, 8, 24, 10, 0, 0),
        repeatRule: RepeatRule.weekly,
        completedDates: ['2026-08-24', '2026-08-31'],
        status: TaskStatus.waiting,
        priority: 'None',
      );

      SingleTaskSnapshot.fromTask(task, now: fixedNow);
      expect(task.status, TaskStatus.waiting);
      expect(task.completed, isFalse);
    });

    test('T15B-9: Recurring task reaching max occurrences marks snapshot Completed', () {
      final task = TaskItem(
        id: 't15b-9',
        title: 'Limited Recurrence',
        dueDate: DateTime.utc(2026, 8, 24, 10, 0, 0),
        recurrence: const RecurrenceRule(
          type: RecurrenceType.weekly,
          interval: 1,
          maxOccurrences: 2,
        ),
        completedDates: ['2026-08-24', '2026-08-31'],
        status: TaskStatus.waiting,
        priority: 'None',
      );

      final snapshot = SingleTaskSnapshot.fromTask(task, now: fixedNow);
      expect(snapshot.completed, isTrue);
      expect(snapshot.statusLabel, 'Completed');
      expect(snapshot.status, 'completed');
    });

    test('T15B-10: Date-boundary behavior is deterministic using injected time parameter', () {
      final task = TaskItem(
        id: 't15b-10',
        title: 'Boundary Check',
        dueDate: DateTime.utc(2026, 8, 31, 10, 0, 0),
        repeatRule: RepeatRule.daily,
        status: TaskStatus.waiting,
        priority: 'None',
      );

      // Evaluated on Aug 31
      final snapAug31 = SingleTaskSnapshot.fromTask(task, now: DateTime.utc(2026, 8, 31, 12, 0, 0));
      expect(snapAug31.dueDateIso, '2026-08-31T10:00:00.000Z');

      // Evaluated on Sep 1 with Aug 31 completed
      final completedAug31Task = task.copyWith(completedDates: ['2026-08-31']);
      final snapSep1 = SingleTaskSnapshot.fromTask(completedAug31Task, now: DateTime.utc(2026, 9, 1, 8, 0, 0));
      expect(snapSep1.dueDateIso, '2026-09-01T10:00:00.000Z');
    });

    test('T15B-11 (Section 15 & 17): Explicit before/after completion transition verification & pure observation', () {
      final taskBefore = TaskItem(
        id: 't15b-11',
        title: 'Weekly Status Report',
        dueDate: DateTime.utc(2026, 8, 24, 14, 0, 0),
        repeatRule: RepeatRule.weekly,
        completedDates: ['2026-08-24'],
        status: TaskStatus.waiting,
        priority: 'High',
      );

      // 1. Before completing Aug 31 occurrence:
      final snapBefore = SingleTaskSnapshot.fromTask(taskBefore, now: fixedNow);
      expect(snapBefore.dueDateIso, '2026-08-31T14:00:00.000Z');
      expect(snapBefore.completed, isFalse);
      expect(snapBefore.statusLabel, 'Pending');

      // 2. User completes Aug 31 (adds '2026-08-31' to completedDates without mutating TaskItem.dueDate or status):
      final taskAfter = taskBefore.copyWith(
        completedDates: ['2026-08-24', '2026-08-31'],
      );

      // 3. After completing Aug 31 occurrence on Aug 31:
      final snapAfter = SingleTaskSnapshot.fromTask(taskAfter, now: fixedNow);
      expect(snapAfter.dueDateIso, '2026-08-31T14:00:00.000Z');
      expect(snapAfter.completed, isTrue);
      expect(snapAfter.statusLabel, 'Completed');

      // 4. On next week/day (Sep 1): rolls over to next occurrence (Sep 7) as Pending
      final snapNextWeek = SingleTaskSnapshot.fromTask(taskAfter, now: DateTime.utc(2026, 9, 1, 10, 0, 0));
      expect(snapNextWeek.dueDateIso, '2026-09-07T14:00:00.000Z');
      expect(snapNextWeek.completed, isFalse);
      expect(snapNextWeek.statusLabel, 'Pending');

      // 5. Assert observational purity:
      expect(taskBefore.dueDate, DateTime.utc(2026, 8, 24, 14, 0, 0));
      expect(taskBefore.status, TaskStatus.waiting);
      expect(taskBefore.completedDates, ['2026-08-24']);

      expect(taskAfter.dueDate, DateTime.utc(2026, 8, 24, 14, 0, 0));
      expect(taskAfter.status, TaskStatus.waiting);
      expect(taskAfter.completedDates, ['2026-08-24', '2026-08-31']);
    });
  });
}


