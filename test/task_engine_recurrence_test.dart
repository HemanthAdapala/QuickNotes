import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/models/task_item.dart';
import 'package:quick_notes/models/task_status.dart';
import 'package:quick_notes/models/recurrence_rule.dart';
import 'package:quick_notes/services/task_engine.dart';
import 'package:quick_notes/repositories/tasks_repository.dart';
import 'package:quick_notes/services/clock_service.dart';
import 'package:quick_notes/services/reminder_scheduler.dart';

class MockTasksRepository implements TasksRepository {
  final Map<String, TaskItem> _db = {};
  int _idCounter = 1;

  @override
  Future<int> insertTask(TaskItem task) async {
    _db[task.id] = task;
    return 1;
  }

  @override
  Future<int> updateTask(TaskItem task) async {
    _db[task.id] = task;
    return 1;
  }

  @override
  Future<int> deleteTask(String id) async {
    _db.remove(id);
    return 1;
  }

  Future<TaskItem?> getTaskById(String id) async {
    return _db[id];
  }

  @override
  Future<List<TaskItem>> getTasks() async {
    return _db.values.toList();
  }

  @override
  Future<List<TaskItem>> getTasksForDate(DateTime date) async {
    return _db.values.where((t) => t.dueDate.day == date.day).toList();
  }

  @override
  Future<int> generateUniqueNotificationId() async {
    return _idCounter++;
  }

  @override
  Future<List<TaskItem>> getTrashTasks() async {
    return _db.values.where((t) => t.isDeleted).toList();
  }

  @override
  Future<int> trashTask(String id) async {
    final task = _db[id];
    if (task != null) {
      _db[id] = task.copyWith(isDeleted: true, deletedAt: DateTime.now());
      return 1;
    }
    return 0;
  }

  @override
  Future<int> restoreTask(String id) async {
    final task = _db[id];
    if (task != null) {
      _db[id] = task.copyWith(isDeleted: false, clearDeletedAt: true);
      return 1;
    }
    return 0;
  }

  @override
  Future<int> emptyTrash() async {
    _db.removeWhere((id, task) => task.isDeleted);
    return 1;
  }
}

class MockReminderScheduler implements ReminderScheduler {
  final List<TaskItem> scheduled = [];
  final List<int> cancelled = [];

  @override
  Future<void> initialize() async {}

  @override
  Future<void> scheduleReminder(TaskItem task) async {
    scheduled.add(task);
  }

  @override
  Future<void> cancelReminder(int notificationId) async {
    cancelled.add(notificationId);
  }

  @override
  Future<List<int>> getPendingNotificationIds() async {
    return scheduled.map((t) => t.notificationId).toList();
  }
}

void main() {
  late MockTasksRepository repo;
  late MockReminderScheduler scheduler;
  late TestClock clock;
  late TaskEngine engine;

  setUp(() async {
    repo = MockTasksRepository();
    scheduler = MockReminderScheduler();
    clock = TestClock(DateTime(2026, 7, 24, 17, 0, 0));
    engine = TaskEngine(repository: repo, clock: clock, scheduler: scheduler);
    await engine.initialize();
  });

  group('TaskEngine Recurrence Tests', () {
    test('Completing a recurring task creates next occurrence and preserves history', () async {
      final initialDueDate = DateTime(2026, 7, 24, 9, 0, 0);
      final initialReminder = DateTime(2026, 7, 24, 9, 0, 0);

      final task = TaskItem(
        id: 'task-1',
        title: 'Daily Workout',
        dueDate: initialDueDate,
        priority: 'High',
        reminderEnabled: true,
        reminderTime: initialReminder,
        isRecurring: true,
        recurrence: const RecurrenceRule(type: RecurrenceType.daily, interval: 1),
      );

      await engine.createTask(task: task);
      expect(engine.tasks.length, equals(1));

      // Complete the task at 5 PM
      await engine.toggleCompletion('task-1');

      // Check in-place completion: Task 1 toggles completed without spawning extra task row
      final task1 = engine.getTaskById('task-1');
      expect(task1, isNotNull);
      expect(task1!.completed, isTrue);
      expect(task1.status, equals(TaskStatus.completed));

      // Single task row maintained in-place
      expect(engine.tasks.length, equals(1));
    });

    test('Startup reconciliation generates missing next occurrence after app restart', () async {
      final initialDueDate = DateTime(2026, 7, 24, 9, 0, 0);

      final task = TaskItem(
        id: 'task-completed-alone',
        title: 'Daily Reading',
        dueDate: initialDueDate,
        priority: 'Medium',
        status: TaskStatus.completed,
        completed: true,
        isRecurring: true,
        recurrence: const RecurrenceRule(type: RecurrenceType.daily, interval: 1),
        recurringSeriesId: 'series-reading-1',
      );

      // Save completed task directly to repo (simulating app killed after completing task)
      await repo.insertTask(task);

      // Re-initialize a fresh engine
      final newEngine = TaskEngine(repository: repo, clock: clock, scheduler: scheduler);
      await newEngine.initialize();

      // Reconciliation should detect missing next occurrence and generate it
      expect(newEngine.tasks.length, equals(2));
      final newOccurrence = newEngine.tasks.firstWhere((t) => t.id != 'task-completed-alone');
      expect(newOccurrence.recurringSeriesId, equals('series-reading-1'));
      expect(newOccurrence.dueDate, equals(DateTime(2026, 7, 25, 9, 0, 0)));
    });

    test('Mutating recurrence cycle between Never, Daily, Weekly, and back to Never', () async {
      // 1. Create a non-recurring task
      final task = await engine.createTask(
        title: 'Recurrence Mutation Task',
        dueDate: DateTime(2026, 8, 31, 10, 0),
      );
      expect(task.isRecurring, isFalse);
      expect(task.recurrence, isNull);

      // 2. Edit from Never -> Daily
      final updatedDaily = task.copyWith(
        isRecurring: true,
        recurrence: const RecurrenceRule(type: RecurrenceType.daily, interval: 1),
      );
      final savedDaily = await engine.updateTask(updatedDaily);
      expect(savedDaily.isRecurring, isTrue);
      expect(savedDaily.recurrence?.type, RecurrenceType.daily);
      expect(savedDaily.toMap()['recurrenceRule'], isNotNull);

      // 3. Edit from Daily -> Never
      final updatedNever = savedDaily.copyWith(
        isRecurring: false,
        recurrence: null,
        clearRecurrence: true,
      );
      final savedNever = await engine.updateTask(updatedNever);
      expect(savedNever.isRecurring, isFalse);
      expect(savedNever.recurrence, isNull);
      expect(savedNever.toMap()['recurrenceRule'], isNull);

      // 4. Edit from Never -> Weekly
      final updatedWeekly = savedNever.copyWith(
        isRecurring: true,
        recurrence: const RecurrenceRule(type: RecurrenceType.weekly, interval: 1),
      );
      final savedWeekly = await engine.updateTask(updatedWeekly);
      expect(savedWeekly.isRecurring, isTrue);
      expect(savedWeekly.recurrence?.type, RecurrenceType.weekly);
      expect(savedWeekly.toMap()['recurrenceRule'], isNotNull);

      // 5. Edit from Weekly -> Never without explicit clearRecurrence (isRecurring: false, recurrence: null)
      final updatedNeverImplicit = savedWeekly.copyWith(
        isRecurring: false,
        recurrence: null,
      );
      final savedNeverImplicit = await engine.updateTask(updatedNeverImplicit);
      expect(savedNeverImplicit.isRecurring, isFalse);
      expect(savedNeverImplicit.recurrence, isNull);
      expect(savedNeverImplicit.toMap()['recurrenceRule'], isNull);
    });
  });
}
