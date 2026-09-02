import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/models/recurrence_rule.dart';
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
}
