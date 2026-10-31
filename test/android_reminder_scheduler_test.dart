import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/models/task_item.dart';
import 'package:quick_notes/models/task_status.dart';
import 'package:quick_notes/models/recurrence_rule.dart';
import 'package:quick_notes/services/task_engine.dart';
import 'package:quick_notes/services/clock_service.dart';
import 'package:quick_notes/services/reminder_scheduler.dart';
import 'package:quick_notes/services/notification_id_manager.dart';
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
      expect(
          scheduler.logHistory
              .where((l) => l.contains('SCHEDULER [Initialize]'))
              .length,
          equals(1));
    });

    test('scheduleReminder executes defensive cancellation before scheduling',
        () async {
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

      final cancels = scheduler.logHistory
          .where((l) => l.contains('SCHEDULER [Cancel]'))
          .toList();
      final schedules = scheduler.logHistory
          .where((l) => l.contains('SCHEDULER [Schedule]'))
          .toList();

      expect(cancels.length, greaterThanOrEqualTo(1));
      expect(schedules.length, equals(2));
    });

    test(
        'TaskEngine.initialize() reschedules all active future reminders on startup',
        () async {
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

    test('getPendingNotificationIds tracks active reminders accurately',
        () async {
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

    test(
        'reloadFromRepository() restores missing future reminders upon app resume',
        () async {
      await engine.initialize();

      final task = await engine.createTask(
        title: 'Resume Reconcile Test',
        dueDate: clock.now.add(const Duration(hours: 5)),
        priority: 'High',
        reminderTime: clock.now.add(const Duration(hours: 2)),
      );

      // Simulate alarms dropped by OS/AlarmManager loss
      await scheduler.cancelReminder(task.notificationId);
      expect(
          (await scheduler.getPendingNotificationIds())
              .contains(task.notificationId),
          isFalse);

      // App resumes and calls reloadFromRepository
      await engine.reloadFromRepository();

      // Missing alarm must be reliably restored
      final restoredPending = await scheduler.getPendingNotificationIds();
      expect(restoredPending.contains(task.notificationId), isTrue);
    });

    test(
        'reconcileAlarmsWithScheduler is idempotent and does not schedule duplicates',
        () async {
      await engine.initialize();

      await engine.createTask(
        title: 'Idempotency Test',
        dueDate: clock.now.add(const Duration(hours: 5)),
        priority: 'Medium',
        reminderTime: clock.now.add(const Duration(hours: 2)),
      );

      final initialSchedules = scheduler.logHistory
          .where((l) => l.contains('SCHEDULER [Schedule]'))
          .length;

      // Run reconciliation multiple times
      await engine.reconcileAlarmsWithScheduler();
      await engine.reconcileAlarmsWithScheduler();

      final subsequentSchedules = scheduler.logHistory
          .where((l) => l.contains('SCHEDULER [Schedule]'))
          .length;
      expect(subsequentSchedules, equals(initialSchedules));
    });

    test(
        'Completed, archived, and cancelled tasks are never rescheduled and have pending alarms cancelled',
        () async {
      await engine.initialize();

      final task = await engine.createTask(
        title: 'Task To Complete',
        dueDate: clock.now.add(const Duration(hours: 5)),
        priority: 'Medium',
        reminderTime: clock.now.add(const Duration(hours: 2)),
      );

      expect(
          (await scheduler.getPendingNotificationIds())
              .contains(task.notificationId),
          isTrue);

      // Complete the task
      await engine.toggleCompletion(task.id);

      // Alarm must be removed
      expect(
          (await scheduler.getPendingNotificationIds())
              .contains(task.notificationId),
          isFalse);

      // Reconciliation should NOT restore alarm for completed task
      await engine.reconcileAlarmsWithScheduler();
      expect(
          (await scheduler.getPendingNotificationIds())
              .contains(task.notificationId),
          isFalse);
    });
  });

  group(
      'Collision-safe notification ID ownership & overlapping custom-interval tasks',
      () {
    test(
        'NotificationIdManager guarantees strictly disjoint partitions for base and horizons',
        () {
      final baseIds = [1, 50, 1000, 500000, NotificationIdManager.maxBaseId];
      final seenIds = <int>{};

      for (final base in baseIds) {
        final h1 = NotificationIdManager.getHorizonId(base, 1);
        final h2 = NotificationIdManager.getHorizonId(base, 2);

        // Check range partitions
        expect(base >= 1 && base <= NotificationIdManager.maxBaseId, isTrue);
        expect(
            h1 > NotificationIdManager.maxBaseId &&
                h1 <= NotificationIdManager.horizonOffset2,
            isTrue);
        expect(h2 > NotificationIdManager.horizonOffset2 && h2 <= 2100000000,
            isTrue);

        // Check signed 32-bit integer safety
        expect(h1 <= 2147483647, isTrue);
        expect(h2 <= 2147483647, isTrue);

        // Check mutual exclusivity
        expect(seenIds.contains(base), isFalse);
        expect(seenIds.contains(h1), isFalse);
        expect(seenIds.contains(h2), isFalse);
        seenIds.addAll([base, h1, h2]);

        // Check resolution
        expect(NotificationIdManager.resolveBaseId(base), equals(base));
        expect(NotificationIdManager.resolveBaseId(h1), equals(base));
        expect(NotificationIdManager.resolveBaseId(h2), equals(base));
      }
    });

    test(
        'Two simultaneous custom-interval recurring tasks with overlapping horizons do not collide or cross-cancel',
        () async {
      final repository = MockTasksRepository();
      final clock = TestClock(DateTime.utc(2026, 7, 24, 10, 0));
      final scheduler = LoggingReminderScheduler();
      final engine = TaskEngine(
        repository: repository,
        clock: clock,
        scheduler: scheduler,
      );
      await engine.initialize();

      // Task A: interval 3 days (custom interval triggers horizon scheduling)
      final taskA = await engine.createTask(
        title: 'Task A (Every 3 Days)',
        dueDate: clock.now.add(const Duration(days: 3)),
        priority: 'High',
        reminderTime: clock.now.add(const Duration(days: 3)),
        isRecurring: true,
        recurrence: const RecurrenceRule(
          type: RecurrenceType.daily,
          interval: 3,
        ),
      );

      // Task B: interval 4 days
      final taskB = await engine.createTask(
        title: 'Task B (Every 4 Days)',
        dueDate: clock.now.add(const Duration(days: 4)),
        priority: 'Medium',
        reminderTime: clock.now.add(const Duration(days: 4)),
        isRecurring: true,
        recurrence: const RecurrenceRule(
          type: RecurrenceType.daily,
          interval: 4,
        ),
      );

      expect(taskA.notificationId != taskB.notificationId, isTrue);

      final taskAIds =
          NotificationIdManager.getAllAssociatedIds(taskA.notificationId);
      final taskBIds =
          NotificationIdManager.getAllAssociatedIds(taskB.notificationId);

      // Verify no intersection in associated IDs
      expect(taskAIds.toSet().intersection(taskBIds.toSet()), isEmpty);

      // Verify both tasks have primary and horizon alarms in scheduler
      final pendingAfterCreate = await scheduler.getPendingNotificationIds();
      for (final id in taskAIds) {
        expect(pendingAfterCreate.contains(id), isTrue,
            reason: 'Task A alarm $id must be pending');
      }
      for (final id in taskBIds) {
        expect(pendingAfterCreate.contains(id), isTrue,
            reason: 'Task B alarm $id must be pending');
      }

      // Action 1: Cancel / delete Task A
      await engine.deleteTask(taskA.id);

      final pendingAfterDeleteA = await scheduler.getPendingNotificationIds();
      // All Task A alarms cancelled
      for (final id in taskAIds) {
        expect(pendingAfterDeleteA.contains(id), isFalse,
            reason: 'Task A alarm $id should be cancelled');
      }
      // All Task B alarms MUST remain completely intact
      for (final id in taskBIds) {
        expect(pendingAfterDeleteA.contains(id), isTrue,
            reason: 'Task B alarm $id must remain intact');
      }

      // Action 2: Edit / Reschedule Task B
      final updatedTaskB = await engine.updateTask(taskB.copyWith(
        title: 'Task B Updated',
        reminderTime: clock.now.add(const Duration(days: 5)),
      ));

      final pendingAfterEditB = await scheduler.getPendingNotificationIds();
      final updatedBIds = NotificationIdManager.getAllAssociatedIds(
          updatedTaskB.notificationId);
      for (final id in updatedBIds) {
        expect(pendingAfterEditB.contains(id), isTrue,
            reason: 'Updated Task B alarm $id must be scheduled');
      }
    });
  });
}
