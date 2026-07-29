import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/models/task_item.dart';
import 'package:quick_notes/models/notification_action.dart';
import 'package:quick_notes/models/task_status.dart';
import 'package:quick_notes/repositories/tasks_repository.dart';
import 'package:quick_notes/services/database_service.dart';
import 'package:quick_notes/services/clock_service.dart';
import 'package:quick_notes/services/notification_action_handler.dart';
import 'package:quick_notes/services/reminder_scheduler.dart';
import 'package:quick_notes/services/task_engine.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

class TestTasksRepository implements TasksRepository {
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
  Future<int> deleteTask(String id) async {
    db.removeWhere((t) => t.id == id);
    return 1;
  }

  @override
  Future<int> generateUniqueNotificationId() async {
    return _nextNotificationId++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TasksRepository repository;
  late TestClock clock;
  late LoggingReminderScheduler scheduler;
  late TaskEngine engine;

  setUp(() async {
    repository = TestTasksRepository();
    clock = TestClock(DateTime.utc(2026, 7, 24, 10, 0, 0));
    scheduler = LoggingReminderScheduler();
    engine = TaskEngine(
      repository: repository,
      clock: clock,
      scheduler: scheduler,
    );

    await engine.initialize();
  });

  group('NotificationActionHandler & Idempotency Guard Tests', () {
    test('Mark Done action completes task cleanly', () async {
      final task = await engine.createTask(
        title: 'Background Task',
        dueDate: clock.now.add(const Duration(hours: 1)),
        priority: 'High',
      );

      final executed = await NotificationActionHandler.executeActionWithIdempotency(
        engine,
        task.id,
        NotificationAction.done,
      );

      expect(executed, isTrue);
      final updated = engine.getTaskById(task.id);
      expect(updated!.completed, isTrue);
      expect(updated.status, equals(TaskStatus.completed));
    });

    test('Mark Done action on ALREADY completed task is idempotent (No-op)', () async {
      final task = await engine.createTask(
        title: 'Already Completed Task',
        dueDate: clock.now.add(const Duration(hours: 1)),
        priority: 'High',
      );

      await engine.toggleCompletion(task.id);
      expect(engine.getTaskById(task.id)!.completed, isTrue);

      // Execute duplicate Done action
      final executed = await NotificationActionHandler.executeActionWithIdempotency(
        engine,
        task.id,
        NotificationAction.done,
      );

      expect(executed, isFalse); // Skipped cleanly by state-based guard
      expect(engine.getTaskById(task.id)!.completed, isTrue);
    });

    test('Snooze action reschedules reminder by given duration', () async {
      final reminder = clock.now.add(const Duration(hours: 1));
      final task = await engine.createTask(
        title: 'Snooze Task',
        dueDate: clock.now.add(const Duration(hours: 2)),
        priority: 'Medium',
        reminderTime: reminder,
      );

      final executed = await NotificationActionHandler.executeActionWithIdempotency(
        engine,
        task.id,
        NotificationAction.snooze,
        snoozeDuration: const Duration(minutes: 15),
      );

      expect(executed, isTrue);
      final updated = engine.getTaskById(task.id);
      expect(updated!.reminderTime, equals(clock.now.add(const Duration(minutes: 15))));
      expect(updated.status, equals(TaskStatus.waiting));
    });

    test('Snooze action on completed task is idempotent (No-op)', () async {
      final task = await engine.createTask(
        title: 'Completed Task Snooze Test',
        dueDate: clock.now.add(const Duration(hours: 1)),
        priority: 'Low',
      );

      await engine.toggleCompletion(task.id);

      final executed = await NotificationActionHandler.executeActionWithIdempotency(
        engine,
        task.id,
        NotificationAction.snooze,
      );

      expect(executed, isFalse); // Skipped cleanly by state-based guard
    });

    test('Handling action for non-existent / deleted task returns false gracefully', () async {
      final executed = await NotificationActionHandler.executeActionWithIdempotency(
        engine,
        'non-existent-task-id',
        NotificationAction.done,
      );

      expect(executed, isFalse); // No crash, handles missing task safely
    });
  });
}
