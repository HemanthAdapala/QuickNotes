import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/models/recurrence_rule.dart';
import 'package:quick_notes/models/repeat_rule.dart';
import 'package:quick_notes/models/task_item.dart';
import 'package:quick_notes/models/task_status.dart';
import 'package:quick_notes/providers/tasks_provider.dart';
import 'package:quick_notes/repositories/tasks_repository.dart';
import 'package:quick_notes/services/clock_service.dart';
import 'package:quick_notes/services/reminder_scheduler.dart';
import 'package:quick_notes/services/task_engine.dart';

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
    final count = db.where((t) => t.isDeleted).length;
    db.removeWhere((t) => t.isDeleted);
    return count;
  }

  @override
  Future<int> generateUniqueNotificationId() async => _nextNotificationId++;
}

class FixedClock extends ClockService {
  final DateTime _fixed;
  FixedClock(this._fixed);
  @override
  DateTime get now => _fixed;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Task Completion & Completed Filter Tests', () {
    late MockTasksRepository repo;
    late FixedClock clock;
    late TaskEngine engine;
    late TasksProvider provider;
    final fixedNow = DateTime(2026, 10, 29, 10, 0);

    setUp(() async {
      repo = MockTasksRepository();
      clock = FixedClock(fixedNow);
      engine = TaskEngine(
        repository: repo,
        clock: clock,
        scheduler: LoggingReminderScheduler(),
      );
      await engine.initialize();
      provider = TasksProvider(engine: engine);
    });

    test('1. Completing a Never task persists completed status and completedAt', () async {
      await provider.addTask(
        title: 'Submit Expense Report',
        dueDate: fixedNow,
        priority: 'High',
        repeatRule: RepeatRule.none,
        isRecurring: false,
        recurrence: null,
      );

      final task = provider.tasks.first;
      expect(task.isRecurring, isFalse);
      expect(task.completed, isFalse);

      await provider.completeTaskOccurrence(task.id, task.dueDate);

      final completedTask = provider.tasks.first;
      expect(completedTask.completed, isTrue);
      expect(completedTask.status, TaskStatus.completed);
      expect(completedTask.completedAt, isNotNull);
      expect(completedTask.completedDates, isEmpty,
          reason: 'Never tasks must not record occurrence strings in completedDates');
    });

    test('2. Completed Never task disappears from Today and All', () async {
      await provider.addTask(
        title: 'Review PR #42',
        dueDate: fixedNow,
        priority: 'Medium',
      );

      final task = provider.tasks.first;
      expect(provider.getUncompletedTasksForFilter('Today'), hasLength(1));
      expect(provider.getUncompletedTasksForFilter('All'), hasLength(1));

      await provider.completeTaskOccurrence(task.id, task.dueDate);

      expect(provider.getUncompletedTasksForFilter('Today'), isEmpty);
      expect(provider.getUncompletedTasksForFilter('All'), isEmpty);
    });

    test('3. Completed Never task appears in Completed filter', () async {
      await provider.addTask(
        title: 'Sign agreement',
        dueDate: fixedNow,
        priority: 'Low',
      );

      final task = provider.tasks.first;
      expect(provider.getCompletedTasksForFilter(), isEmpty);

      await provider.completeTaskOccurrence(task.id, task.dueDate);

      final completedList = provider.getCompletedTasksForFilter();
      expect(completedList, hasLength(1));
      expect(completedList.first.id, task.id);
      expect(completedList.first.completed, isTrue);
      expect(completedList.first.status, TaskStatus.completed);
    });

    test('4. Never task with contradictory recurrence flags completes as one-time', () async {
      // Simulate raw map from SQLite where isRecurring: 1 but repeatRule: "none" and recurrenceRule: null
      final rawMap = {
        'id': 'contradictory-task-1',
        'title': 'Legacy Drift Task',
        'dueDate': fixedNow.toIso8601String(),
        'priority': 'None',
        'status': 'waiting',
        'completed': 0,
        'repeatRule': 'none',
        'isRecurring': 1, // Contradictory flag
        'recurrenceRule': null,
      };

      final deserialized = TaskItem.fromMap(rawMap);
      expect(deserialized.isRecurring, isFalse,
          reason: 'A task with null recurrence and repeatRule none must resolve isRecurring to false');

      await engine.createTask(task: deserialized);
      await provider.completeTaskOccurrence(deserialized.id, deserialized.dueDate);

      final inMemory = provider.tasks.firstWhere((t) => t.id == 'contradictory-task-1');
      expect(inMemory.completed, isTrue);
      expect(inMemory.status, TaskStatus.completed);
      expect(provider.getUncompletedTasksForFilter('All'), isEmpty);
      expect(provider.getCompletedTasksForFilter(), hasLength(1));
    });

    test('5. Undo restores completed Never task to unfinished filters', () async {
      await provider.addTask(
        title: 'Water Plants',
        dueDate: fixedNow,
        priority: 'None',
      );

      final task = provider.tasks.first;
      await provider.completeTaskOccurrence(task.id, task.dueDate);
      expect(provider.getUncompletedTasksForFilter('Today'), isEmpty);
      expect(provider.getCompletedTasksForFilter(), hasLength(1));

      // Undo
      await provider.uncompleteTaskOccurrence(task.id, task.dueDate);

      expect(provider.getCompletedTasksForFilter(), isEmpty);
      expect(provider.getUncompletedTasksForFilter('Today'), hasLength(1));
      expect(provider.getUncompletedTasksForFilter('All'), hasLength(1));
      final restored = provider.tasks.first;
      expect(restored.completed, isFalse);
      expect(restored.status, TaskStatus.waiting);
      expect(restored.completedAt, isNull);
    });

    test('6. Recurring task completion: Today occurrence removed, next occurrence projected in All', () async {
      await provider.addTask(
        title: 'Daily Standup',
        dueDate: fixedNow,
        priority: 'High',
        isRecurring: true,
        recurrence: const RecurrenceRule(type: RecurrenceType.daily, interval: 1),
        repeatRule: RepeatRule.daily,
      );

      final task = provider.tasks.first;
      expect(task.isRecurring, isTrue);
      expect(provider.getUncompletedTasksForFilter('Today'), hasLength(1));
      expect(provider.getUncompletedTasksForFilter('All'), hasLength(1));

      // Complete today's occurrence
      await provider.completeTaskOccurrence(task.id, task.dueDate);

      // Removed from Today
      expect(provider.getUncompletedTasksForFilter('Today'), isEmpty);

      // Present in Completed filter as done for today
      final completedList = provider.getCompletedTasksForFilter();
      expect(completedList, hasLength(1));
      expect(completedList.first.id, task.id);
      expect(completedList.first.completed, isTrue);

      // All filter projects tomorrow's uncompleted occurrence
      final allList = provider.getUncompletedTasksForFilter('All');
      expect(allList, hasLength(1));
      expect(allList.first.id, task.id);
      expect(allList.first.status, TaskStatus.waiting);
      expect(allList.first.dueDate.day, fixedNow.day + 1);

      // Recurring task itself is NOT permanently completed
      expect(provider.tasks.first.completed, isFalse);
    });

    test('7. Undo correctly restores recurring occurrence for today', () async {
      await provider.addTask(
        title: 'Daily Workout',
        dueDate: fixedNow,
        priority: 'Medium',
        isRecurring: true,
        recurrence: const RecurrenceRule(type: RecurrenceType.daily, interval: 1),
        repeatRule: RepeatRule.daily,
      );

      final task = provider.tasks.first;
      await provider.completeTaskOccurrence(task.id, task.dueDate);
      expect(provider.getUncompletedTasksForFilter('Today'), isEmpty);
      expect(provider.getCompletedTasksForFilter(), hasLength(1));

      // Undo today's occurrence
      await provider.uncompleteTaskOccurrence(task.id, task.dueDate);

      expect(provider.getCompletedTasksForFilter(), isEmpty);
      expect(provider.getUncompletedTasksForFilter('Today'), hasLength(1));
      expect(provider.tasks.first.completedDates, isEmpty);
    });

    test('8. Completed filter count matches displayed tasks and avoids duplicates', () async {
      // 1 One-time task
      await provider.addTask(
        title: 'One-off Task',
        dueDate: fixedNow,
        priority: 'None',
      );
      // 1 Recurring task
      await provider.addTask(
        title: 'Recurring Task',
        dueDate: fixedNow,
        isRecurring: true,
        recurrence: const RecurrenceRule(type: RecurrenceType.daily),
        priority: 'None',
      );

      final tasks = provider.tasks;
      await provider.completeTaskOccurrence(tasks[0].id, tasks[0].dueDate);
      await provider.completeTaskOccurrence(tasks[1].id, tasks[1].dueDate);

      final completedTasks = provider.getCompletedTasksForFilter();
      expect(completedTasks, hasLength(2));
      final ids = completedTasks.map((t) => t.id).toSet();
      expect(ids, hasLength(2), reason: 'Each completed task must be unique');
    });
  });
}

