import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/models/task_item.dart';
import 'package:quick_notes/models/task_status.dart';
import 'package:quick_notes/services/task_engine.dart';
import 'package:quick_notes/services/clock_service.dart';
import 'package:quick_notes/services/reminder_scheduler.dart';
import 'package:quick_notes/repositories/tasks_repository.dart';

class MockTasksRepository implements TasksRepository {
  final List<TaskItem> db = [];
  int _nextNotificationId = 2000;

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
  Future<int> deleteTask(String id) async {
    db.removeWhere((t) => t.id == id);
    return 1;
  }

  @override
  Future<int> generateUniqueNotificationId() async {
    return _nextNotificationId++;
  }

  @override
  Future<List<TaskItem>> getTrashTasks() async {
    return db.where((t) => t.isDeleted).toList();
  }

  @override
  Future<int> trashTask(String id) async {
    final idx = db.indexWhere((t) => t.id == id);
    if (idx != -1) {
      db[idx] = db[idx].copyWith(isDeleted: true, deletedAt: DateTime.now());
      return 1;
    }
    return 0;
  }

  @override
  Future<int> restoreTask(String id) async {
    final idx = db.indexWhere((t) => t.id == id);
    if (idx != -1) {
      db[idx] = db[idx].copyWith(isDeleted: false, clearDeletedAt: true);
      return 1;
    }
    return 0;
  }

  @override
  Future<int> emptyTrash() async {
    db.removeWhere((t) => t.isDeleted);
    return 1;
  }
}

void main() {
  group('TaskEngine Milestone 2 Tests (ReminderScheduler Integration)', () {
    late MockTasksRepository repository;
    late TestClock clock;
    late LoggingReminderScheduler scheduler;
    late TaskEngine engine;

    setUp(() {
      repository = MockTasksRepository();
      clock = TestClock(DateTime.utc(2026, 7, 24, 10, 0));
      scheduler = LoggingReminderScheduler();
      engine = TaskEngine(
        repository: repository,
        clock: clock,
        scheduler: scheduler,
      );
    });

    test('Scheduler initialization is idempotent', () async {
      await scheduler.initialize();
      await scheduler.initialize();
      expect(scheduler.logHistory.where((l) => l.contains('SCHEDULER [Initialize]')).length, equals(1));
    });

    test('scheduleReminder executes defensive cancellation before scheduling', () async {
      await engine.initialize();

      final task = await engine.createTask(
        title: 'Defensive Cancel Test',
        dueDate: clock.now.add(const Duration(hours: 3)),
        priority: 'High',
        reminderTime: clock.now.add(const Duration(hours: 1)),
      );

      // Reschedule task
      await engine.updateTask(task.copyWith(
        reminderTime: clock.now.add(const Duration(hours: 2)),
      ));

      final cancels = scheduler.logHistory.where((l) => l.contains('SCHEDULER [Cancel]')).toList();
      final schedules = scheduler.logHistory.where((l) => l.contains('SCHEDULER [Schedule]')).toList();

      expect(cancels.length, greaterThanOrEqualTo(1));
      expect(schedules.length, equals(2));
    });

    test('TaskEngine.initialize() reschedules all active future reminders on startup', () async {
      final task1 = TaskItem(
        id: 'task-1',
        title: 'Future Task 1',
        dueDate: clock.now.add(const Duration(hours: 5)),
        priority: 'High',
        reminderTime: clock.now.add(const Duration(hours: 2)),
        notificationId: 5001,
        status: TaskStatus.waiting,
      );

      final task2 = TaskItem(
        id: 'task-2',
        title: 'Past Task 2',
        dueDate: clock.now.subtract(const Duration(hours: 5)),
        priority: 'Low',
        reminderTime: clock.now.subtract(const Duration(hours: 3)),
        notificationId: 5002,
        status: TaskStatus.waiting,
      );

      repository.db.addAll([task1, task2]);

      await engine.initialize();

      // Only task1 (future reminder) should be scheduled
      final pendingIds = await scheduler.getPendingNotificationIds();
      expect(pendingIds.contains(5001), isTrue);
      expect(pendingIds.contains(5002), isFalse);

      // task2 should be reconciled as missed
      final reconciledTask2 = engine.tasks.firstWhere((t) => t.id == 'task-2');
      expect(reconciledTask2.status, equals(TaskStatus.missed));
    });

    test('getPendingNotificationIds tracks active reminders accurately', () async {
      await engine.initialize();

      final task = await engine.createTask(
        title: 'Pending ID Test',
        dueDate: clock.now.add(const Duration(hours: 4)),
        priority: 'Medium',
        reminderTime: clock.now.add(const Duration(hours: 1)),
      );

      var pending = await scheduler.getPendingNotificationIds();
      expect(pending.contains(task.notificationId), isTrue);

      await engine.deleteTask(task.id);
      pending = await scheduler.getPendingNotificationIds();
      expect(pending.contains(task.notificationId), isFalse);
    });
  });
}
