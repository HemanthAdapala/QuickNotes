import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/models/recurrence_rule.dart';
import 'package:quick_notes/models/repeat_rule.dart';
import 'package:quick_notes/models/single_task_snapshot.dart';
import 'package:quick_notes/models/task_item.dart';
import 'package:quick_notes/models/task_status.dart';
import 'package:quick_notes/providers/tasks_provider.dart';
import 'package:quick_notes/repositories/tasks_repository.dart';
import 'package:quick_notes/services/clock_service.dart';
import 'package:quick_notes/services/reminder_scheduler.dart';
import 'package:quick_notes/services/task_engine.dart';
import 'package:quick_notes/services/widget_data_adapter.dart';

class MockTasksRepository implements TasksRepository {
  final List<TaskItem> db = [];
  int _nextNotificationId = 1000;

  @override
  Future<List<TaskItem>> getTasks() async => List.from(db);

  @override
  Future<List<TaskItem>> getTasksForDate(DateTime date) async =>
      db.where((t) => t.dueDate.day == date.day).toList();

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
  Future<int> generateUniqueNotificationId() async => _nextNotificationId++;
}

class TestClock implements ClockService {
  final DateTime _fixed;
  TestClock(this._fixed);
  @override
  DateTime get now => _fixed;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TasksProvider Phase T15H Unit Tests', () {
    late MockTasksRepository repo;
    late TaskEngine engine;
    late TasksProvider provider;
    final fixedNow = DateTime(2026, 8, 31, 18, 5);

    setUp(() async {
      repo = MockTasksRepository();
      final clock = TestClock(fixedNow);
      final scheduler = LoggingReminderScheduler();
      engine = TaskEngine(repository: repo, clock: clock, scheduler: scheduler);
      await engine.initialize();
      provider = TasksProvider(engine: engine);
    });

    test('T15H-3: Explicit completeTaskOccurrence is strictly idempotent for recurring tasks', () async {
      final task = await engine.createTask(
        title: 'Daily Exercise',
        dueDate: fixedNow,
        isRecurring: true,
        recurrence: const RecurrenceRule(type: RecurrenceType.daily, interval: 1),
      );

      // Call 1
      await provider.completeTaskOccurrence(task.id, fixedNow);
      expect(provider.tasks.first.completedDates, ['2026-08-31']);

      // Call 2 with identical date
      await provider.completeTaskOccurrence(task.id, fixedNow);
      expect(provider.tasks.first.completedDates, ['2026-08-31']);

      // Call 3 with identical date
      await provider.completeTaskOccurrence(task.id, fixedNow);
      expect(provider.tasks.first.completedDates, ['2026-08-31']);
    });

    test('T15H-3 (Non-recurring): completeTaskOccurrence is strictly idempotent for non-recurring tasks', () async {
      final task = await engine.createTask(
        title: 'One-off report',
        dueDate: fixedNow,
      );

      // Call 1
      await provider.completeTaskOccurrence(task.id, fixedNow);
      expect(provider.tasks.first.completed, isTrue);
      expect(provider.tasks.first.status, TaskStatus.completed);

      // Call 2 with identical date
      await provider.completeTaskOccurrence(task.id, fixedNow);
      expect(provider.tasks.first.completed, isTrue);
      expect(provider.tasks.first.status, TaskStatus.completed);
    });

    test('uncompleteTaskOccurrence is idempotent for recurring and non-recurring tasks', () async {
      // 1. Recurring task
      final recurringTask = await engine.createTask(
        title: 'Recurring task to uncomplete',
        dueDate: fixedNow,
        isRecurring: true,
        recurrence: const RecurrenceRule(type: RecurrenceType.daily, interval: 1),
      );
      await provider.completeTaskOccurrence(recurringTask.id, fixedNow);
      expect(provider.tasks.first.completedDates, ['2026-08-31']);

      // Uncomplete 1
      await provider.uncompleteTaskOccurrence(recurringTask.id, fixedNow);
      expect(provider.tasks.first.completedDates, isEmpty);

      // Uncomplete 2 (idempotent)
      await provider.uncompleteTaskOccurrence(recurringTask.id, fixedNow);
      expect(provider.tasks.first.completedDates, isEmpty);

      // 2. Non-recurring task
      final oneOffTask = await engine.createTask(
        title: 'One-off to uncomplete',
        dueDate: fixedNow,
      );
      await provider.completeTaskOccurrence(oneOffTask.id, fixedNow);
      final completedOneOff = provider.tasks.firstWhere((t) => t.id == oneOffTask.id);
      expect(completedOneOff.completed, isTrue);

      // Uncomplete 1
      await provider.uncompleteTaskOccurrence(oneOffTask.id, fixedNow);
      final uncompletedOneOff = provider.tasks.firstWhere((t) => t.id == oneOffTask.id);
      expect(uncompletedOneOff.completed, isFalse);
      expect(uncompletedOneOff.status, TaskStatus.waiting);

      // Uncomplete 2 (idempotent)
      await provider.uncompleteTaskOccurrence(oneOffTask.id, fixedNow);
      final stillUncompleted = provider.tasks.firstWhere((t) => t.id == oneOffTask.id);
      expect(stillUncompleted.completed, isFalse);
      expect(stillUncompleted.status, TaskStatus.waiting);
    });

    test('T15H-8: True toggle semantics preserved in toggleTaskCompletionOnDate', () async {
      final task = await engine.createTask(
        title: 'Daily Checklist',
        dueDate: fixedNow,
        isRecurring: true,
        recurrence: const RecurrenceRule(type: RecurrenceType.daily, interval: 1),
      );

      // Toggle 1: absent -> added
      await provider.toggleTaskCompletionOnDate(task.id, fixedNow);
      expect(provider.tasks.first.completedDates, ['2026-08-31']);

      // Toggle 2: present -> removed
      await provider.toggleTaskCompletionOnDate(task.id, fixedNow);
      expect(provider.tasks.first.completedDates, isEmpty);

      // Toggle 3: absent -> added again
      await provider.toggleTaskCompletionOnDate(task.id, fixedNow);
      expect(provider.tasks.first.completedDates, ['2026-08-31']);
    });

    test('T15H-9 & T15H-10: SingleTaskSnapshot & WidgetDataAdapter reflect correct progressive occurrence and same-day completed state', () async {
      final savedData = <String, dynamic>{};
      final adapter = WidgetDataAdapter.custom(
        saveData: (key, value) async {
          savedData[key] = value;
          return true;
        },
        updateWidget: ({name, androidName, iOSName, qualifiedAndroidName}) async => true,
      );

      final task = await engine.createTask(
        title: 'Daily Progress Snapshot Test',
        dueDate: fixedNow,
        isRecurring: true,
        recurrence: const RecurrenceRule(type: RecurrenceType.daily, interval: 1),
      );

      // 1. Initial state (Aug 31 uncompleted on Aug 31)
      var snapshot = SingleTaskSnapshot.fromTask(task, now: fixedNow);
      expect(snapshot.formattedDate, 'Mon, 31 August 2026');
      expect(snapshot.completed, isFalse);
      expect(snapshot.statusLabel, 'Pending');

      // 2. Complete Aug 31 on Aug 31 -> Widget displays Aug 31 as Completed
      await provider.completeTaskOccurrence(task.id, fixedNow);
      final updatedTask1 = provider.tasks.first;
      snapshot = SingleTaskSnapshot.fromTask(updatedTask1, now: fixedNow);
      expect(snapshot.formattedDate, 'Mon, 31 August 2026');
      expect(snapshot.completed, isTrue);
      expect(snapshot.statusLabel, 'Completed');

      // 3. Sync to adapter on Aug 31
      await adapter.sync(tasks: [updatedTask1], now: fixedNow, hasActiveSession: true);
      expect(savedData[WidgetDataAdapter.tasksCatalogKey], contains('Mon, 31 August 2026'));

      // 4. Next day arrives (Sep 1): Widget automatically rolls over to Sep 1 as Pending
      final sep1Now = DateTime(2026, 9, 1, 10, 0);
      snapshot = SingleTaskSnapshot.fromTask(updatedTask1, now: sep1Now);
      expect(snapshot.formattedDate, 'Tue, 1 September 2026');
      expect(snapshot.completed, isFalse);
      expect(snapshot.statusLabel, 'Pending');

      // 5. Complete Sep 1 on Sep 1 -> Widget displays Sep 1 as Completed
      final sep1 = DateTime(2026, 9, 1, 18, 5);
      await provider.completeTaskOccurrence(task.id, sep1);
      final updatedTask2 = provider.tasks.first;
      snapshot = SingleTaskSnapshot.fromTask(updatedTask2, now: sep1Now);
      expect(snapshot.formattedDate, 'Tue, 1 September 2026');
      expect(snapshot.completed, isTrue);
      expect(snapshot.statusLabel, 'Completed');

      // 6. Day after (Sep 2) arrives: Widget rolls over to Sep 2 as Pending
      final sep2Now = DateTime(2026, 9, 2, 8, 0);
      snapshot = SingleTaskSnapshot.fromTask(updatedTask2, now: sep2Now);
      expect(snapshot.formattedDate, 'Wed, 2 September 2026');
      expect(snapshot.completed, isFalse);
      expect(snapshot.statusLabel, 'Pending');
    });

    test('Weekly Recurrence Principle: Same-day Completed -> Next-cycle Pending rollover', () async {
      // Weekly task due on Friday Aug 28
      final fridayAug28 = DateTime(2026, 8, 28, 14, 0);
      final task = await engine.createTask(
        title: 'Weekly Friday Report',
        dueDate: fridayAug28,
        isRecurring: true,
        recurrence: const RecurrenceRule(type: RecurrenceType.weekly, interval: 1),
      );

      // 1. On Friday Aug 28 before completion -> Pending
      var snapshot = SingleTaskSnapshot.fromTask(task, now: fridayAug28);
      expect(snapshot.formattedDate, 'Fri, 28 August 2026');
      expect(snapshot.completed, isFalse);
      expect(snapshot.statusLabel, 'Pending');

      // 2. Completed on Friday Aug 28 -> Completed today
      await provider.completeTaskOccurrence(task.id, fridayAug28);
      final completedFridayTask = provider.tasks.first;
      snapshot = SingleTaskSnapshot.fromTask(completedFridayTask, now: fridayAug28);
      expect(snapshot.formattedDate, 'Fri, 28 August 2026');
      expect(snapshot.completed, isTrue);
      expect(snapshot.statusLabel, 'Completed');

      // 3. Next day (Saturday Aug 29) -> Rolls over to next Friday (Sep 4) as Pending
      final saturdayAug29 = DateTime(2026, 8, 29, 9, 0);
      snapshot = SingleTaskSnapshot.fromTask(completedFridayTask, now: saturdayAug29);
      expect(snapshot.formattedDate, 'Fri, 4 September 2026');
      expect(snapshot.completed, isFalse);
      expect(snapshot.statusLabel, 'Pending');
    });

    test('Monthly Recurrence Principle: Same-day Completed -> Next-month Pending rollover', () async {
      // Monthly task due on 1st of month (Sep 1)
      final sep1 = DateTime(2026, 9, 1, 9, 0);
      final task = await engine.createTask(
        title: 'Monthly Rent Payment',
        dueDate: sep1,
        isRecurring: true,
        recurrence: const RecurrenceRule(type: RecurrenceType.monthly, interval: 1),
      );

      // 1. On Sep 1 before completion -> Pending
      var snapshot = SingleTaskSnapshot.fromTask(task, now: sep1);
      expect(snapshot.formattedDate, 'Tue, 1 September 2026');
      expect(snapshot.completed, isFalse);
      expect(snapshot.statusLabel, 'Pending');

      // 2. Completed on Sep 1 -> Completed today
      await provider.completeTaskOccurrence(task.id, sep1);
      final completedSep1Task = provider.tasks.first;
      snapshot = SingleTaskSnapshot.fromTask(completedSep1Task, now: sep1);
      expect(snapshot.formattedDate, 'Tue, 1 September 2026');
      expect(snapshot.completed, isTrue);
      expect(snapshot.statusLabel, 'Completed');

      // 3. Next day (Sep 2) -> Rolls over to 1st of Next Month (Oct 1) as Pending
      final sep2 = DateTime(2026, 9, 2, 8, 0);
      snapshot = SingleTaskSnapshot.fromTask(completedSep1Task, now: sep2);
      expect(snapshot.formattedDate, 'Thu, 1 October 2026');
      expect(snapshot.completed, isFalse);
      expect(snapshot.statusLabel, 'Pending');
    });
  });

  group('BUG-003: deleteTaskOccurrence Regression Tests', () {
    late MockTasksRepository repo;
    late TaskEngine engine;
    late TasksProvider provider;
    final fixedNow = DateTime(2026, 8, 31, 10, 0);

    setUp(() async {
      repo = MockTasksRepository();
      final clock = TestClock(fixedNow);
      final scheduler = LoggingReminderScheduler();
      engine = TaskEngine(repository: repo, clock: clock, scheduler: scheduler);
      await engine.initialize();
      provider = TasksProvider(engine: engine);
    });

    test('1. Non-recurring task deletion: Deleting a normal task removes that task', () async {
      final task = await engine.createTask(
        title: 'Single Task',
        dueDate: fixedNow,
      );
      expect(provider.tasks.length, 1);

      await provider.deleteTaskOccurrence(task.id, fixedNow);

      expect(provider.tasks.where((t) => t.id == task.id), isEmpty);
      expect(provider.getTasksForDate(fixedNow), isEmpty);
    });

    test('2. Specific recurring occurrence: Deleting Day 5 excludes Day 5 without changing series anchor or removing Days 1-4 and Day 6+', () async {
      final day1 = DateTime(2026, 9, 1, 10, 0);
      final day2 = DateTime(2026, 9, 2, 10, 0);
      final day3 = DateTime(2026, 9, 3, 10, 0);
      final day4 = DateTime(2026, 9, 4, 10, 0);
      final day5 = DateTime(2026, 9, 5, 10, 0);
      final day6 = DateTime(2026, 9, 6, 10, 0);

      final task = await engine.createTask(
        title: 'Daily Medication',
        dueDate: day1,
        isRecurring: true,
        recurrence: const RecurrenceRule(type: RecurrenceType.daily, interval: 1),
      );

      // Verify initial projections
      expect(provider.getTasksForDate(day1), isNotEmpty);
      expect(provider.getTasksForDate(day5), isNotEmpty);

      // Action: Delete only Day 5
      await provider.deleteTaskOccurrence(task.id, day5);

      final updatedTask = provider.tasks.firstWhere((t) => t.id == task.id);

      // Anchor must be preserved
      expect(updatedTask.dueDate, day1.toUtc(), reason: 'Anchor dueDate must not be altered when deleting a future occurrence');

      // Day 5 must be excluded
      expect(provider.getTasksForDate(day5), isEmpty, reason: 'Day 5 occurrence must be excluded from getTasksForDate');

      // Days 1-4 and Day 6 must remain intact
      expect(provider.getTasksForDate(day1), isNotEmpty, reason: 'Day 1 occurrence must remain present');
      expect(provider.getTasksForDate(day2), isNotEmpty, reason: 'Day 2 occurrence must remain present');
      expect(provider.getTasksForDate(day3), isNotEmpty, reason: 'Day 3 occurrence must remain present');
      expect(provider.getTasksForDate(day4), isNotEmpty, reason: 'Day 4 occurrence must remain present');
      expect(provider.getTasksForDate(day6), isNotEmpty, reason: 'Day 6 occurrence must remain present');
    });

    test('3. Base occurrence deletion: Deleting the first occurrence excludes that date while later occurrences remain available', () async {
      final day1 = DateTime(2026, 9, 1, 10, 0);
      final day2 = DateTime(2026, 9, 2, 10, 0);
      final day3 = DateTime(2026, 9, 3, 10, 0);

      final task = await engine.createTask(
        title: 'Morning Yoga',
        dueDate: day1,
        isRecurring: true,
        recurrence: const RecurrenceRule(type: RecurrenceType.daily, interval: 1),
      );

      // Action: Delete Day 1 (base occurrence)
      await provider.deleteTaskOccurrence(task.id, day1);

      // Anchor must be preserved
      expect(provider.tasks.first.dueDate, day1.toUtc(), reason: 'Base occurrence deletion must not mutate the series anchor dueDate');

      // Day 1 must be excluded
      expect(provider.getTasksForDate(day1), isEmpty, reason: 'Base occurrence on Day 1 must be excluded');

      // Subsequent occurrences must remain available
      expect(provider.getTasksForDate(day2), isNotEmpty, reason: 'Day 2 occurrence must remain available');
      expect(provider.getTasksForDate(day3), isNotEmpty, reason: 'Day 3 occurrence must remain available');
    });

    test('4. Completion cleanup: Deleting a completed occurrence removes that date\'s completion record without affecting other completed dates', () async {
      final day1 = DateTime(2026, 9, 1, 10, 0);
      final day2 = DateTime(2026, 9, 2, 10, 0);

      final task = await engine.createTask(
        title: 'Drink Water',
        dueDate: day1,
        isRecurring: true,
        recurrence: const RecurrenceRule(type: RecurrenceType.daily, interval: 1),
      );

      // Complete Day 1 and Day 2
      await provider.completeTaskOccurrence(task.id, day1);
      await provider.completeTaskOccurrence(task.id, day2);

      var currentTask = provider.tasks.firstWhere((t) => t.id == task.id);
      expect(currentTask.completedDates, containsAll(['2026-09-01', '2026-09-02']));

      // Action: Delete occurrence on Day 2
      await provider.deleteTaskOccurrence(task.id, day2);

      currentTask = provider.tasks.firstWhere((t) => t.id == task.id);

      // Day 2 must not be completed or present
      expect(currentTask.completedDates, isNot(contains('2026-09-02')), reason: 'Deleted occurrence date must be removed from completedDates');
      expect(currentTask.completedDates, contains('2026-09-01'), reason: 'Other completed dates must remain unaffected');
      expect(provider.getTasksForDate(day2), isEmpty, reason: 'Deleted occurrence on Day 2 must not appear');
      expect(provider.getTasksForDate(day1), isNotEmpty, reason: 'Day 1 occurrence must remain present');
      expect(provider.getTasksForDate(day1).first.completed, isTrue, reason: 'Day 1 must still be completed');
    });

    test('5. Idempotency: Deleting the same occurrence twice does not create duplicate exclusions or additional unintended changes', () async {
      final day1 = DateTime(2026, 9, 1, 10, 0);
      final day3 = DateTime(2026, 9, 3, 10, 0);

      final task = await engine.createTask(
        title: 'Daily Journal',
        dueDate: day1,
        isRecurring: true,
        recurrence: const RecurrenceRule(type: RecurrenceType.daily, interval: 1),
      );

      // First deletion of Day 3
      await provider.deleteTaskOccurrence(task.id, day3);
      final stateAfterFirstDelete = provider.tasks.firstWhere((t) => t.id == task.id);

      // Second deletion of Day 3
      await provider.deleteTaskOccurrence(task.id, day3);
      final stateAfterSecondDelete = provider.tasks.firstWhere((t) => t.id == task.id);

      expect(stateAfterSecondDelete.dueDate, stateAfterFirstDelete.dueDate, reason: 'Duplicate delete must not shift dueDate further');
      expect(provider.getTasksForDate(day3), isEmpty);
      expect(provider.getTasksForDate(day1), isNotEmpty);
    });

    test('6. Unknown ID safety: An unmatched ID must not mutate or delete any unrelated task', () async {
      final day1 = DateTime(2026, 9, 1, 10, 0);

      final validTask = await engine.createTask(
        title: 'Important Unrelated Task',
        dueDate: day1,
        isRecurring: true,
        recurrence: const RecurrenceRule(type: RecurrenceType.daily, interval: 1),
      );

      final initialDue = validTask.dueDate;
      final initialTitle = validTask.title;

      // Attempt deleting an occurrence for a non-existent task ID
      // Current defect: orElse: () => _engine.tasks.first mutates validTask!
      try {
        await provider.deleteTaskOccurrence('completely_unknown_id_9999', DateTime(2026, 9, 5));
      } catch (_) {
        // Safe rejection/exception is acceptable
      }

      final checkTask = provider.tasks.firstWhere((t) => t.id == validTask.id);
      expect(checkTask.dueDate, initialDue, reason: 'Unrelated task dueDate must not be corrupted by unmatched ID deletion');
      expect(checkTask.title, initialTitle, reason: 'Unrelated task must remain unchanged');
      expect(provider.getTasksForDate(day1), isNotEmpty, reason: 'Valid task Day 1 must still be projected');
    });

    test('7. Projection consistency: A deleted occurrence must not reappear through getTasksForDate() or getUncompletedTasksForFilter()', () async {
      // Setup task starting yesterday so Today is occurrence #2
      final yesterday = fixedNow.subtract(const Duration(days: 1));
      final task = await engine.createTask(
        title: 'Daily Routine',
        dueDate: yesterday,
        isRecurring: true,
        recurrence: const RecurrenceRule(type: RecurrenceType.daily, interval: 1),
      );

      // Prior to deletion, today's occurrence shows in Today filter
      final beforeDelete = provider.getUncompletedTasksForFilter('Today');
      expect(beforeDelete.any((t) => t.id == task.id), isTrue, reason: 'Task should appear in Today filter before deletion');

      // Delete Today's occurrence
      await provider.deleteTaskOccurrence(task.id, fixedNow);

      // Deleted occurrence must not appear in getTasksForDate
      expect(provider.getTasksForDate(fixedNow), isEmpty, reason: 'Deleted occurrence must not appear in getTasksForDate');

      // Deleted occurrence must not appear in getUncompletedTasksForFilter('Today')
      final afterDelete = provider.getUncompletedTasksForFilter('Today');
      expect(afterDelete.any((t) => t.id == task.id), isFalse, reason: 'Deleted occurrence must not appear in Today uncompleted filter');
    });

    test('8. Legacy repeatRule compatibility: Deleting occurrence on a legacy recurring task with repeatRule and null recurrence', () async {
      final day1 = DateTime(2026, 9, 1, 10, 0);
      final day2 = DateTime(2026, 9, 2, 10, 0);
      final day3 = DateTime(2026, 9, 3, 10, 0);

      // Create a task that uses legacy repeatRule without a RecurrenceRule
      final legacyTask = TaskItem(
        id: 'legacy-recurring-123',
        title: 'Legacy Daily Habit',
        dueDate: day1,
        priority: 'Medium',
        repeatRule: RepeatRule.daily,
        recurrence: null,
        isRecurring: true,
      );
      await engine.createTask(task: legacyTask);

      expect(provider.getTasksForDate(day1), isNotEmpty);
      expect(provider.getTasksForDate(day2), isNotEmpty);

      // Delete Day 2 on legacy task
      await provider.deleteTaskOccurrence(legacyTask.id, day2);

      expect(provider.getTasksForDate(day2), isEmpty, reason: 'Day 2 on legacy recurring task must be excluded');
      expect(provider.getTasksForDate(day1), isNotEmpty, reason: 'Day 1 on legacy recurring task must remain present');
      expect(provider.getTasksForDate(day3), isNotEmpty, reason: 'Day 3 on legacy recurring task must remain present');
    });
  });
}
