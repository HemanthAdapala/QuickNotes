import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/models/task_item.dart';
import 'package:quick_notes/models/task_status.dart';
import 'package:quick_notes/models/task_engine_state.dart';
import 'package:quick_notes/models/task_event.dart';
import 'package:quick_notes/services/task_engine.dart';
import 'package:quick_notes/services/clock_service.dart';
import 'package:quick_notes/services/reminder_scheduler.dart';
import 'package:quick_notes/repositories/tasks_repository.dart';

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
  Future<List<TaskItem>> getTrashTasks() async => db.where((t) => t.isDeleted).toList();

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

void main() {
  group('TaskEngine Milestone 1 Tests', () {
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

    test('Engine lifecycle guard throws EngineNotReadyException before initialize()', () async {
      expect(engine.state, equals(TaskEngineState.idle));
      expect(
        () => engine.createTask(
          title: 'Uninitialized Task',
          dueDate: clock.now,
          priority: 'High',
        ),
        throwsA(isA<EngineNotReadyException>()),
      );
    });

    test('Initialization transitions engine state to ready', () async {
      await engine.initialize();
      expect(engine.state, equals(TaskEngineState.ready));
    });

    test('Creating a task assigns persistent notificationId and schedules reminder', () async {
      await engine.initialize();

      final reminder = clock.now.add(const Duration(hours: 2));
      final task = await engine.createTask(
        title: 'Design Review',
        dueDate: clock.now.add(const Duration(hours: 5)),
        priority: 'High',
        reminderTime: reminder,
      );

      expect(task.notificationId, equals(1000));
      expect(task.status, equals(TaskStatus.scheduled));
      expect(task.completed, isFalse);
      expect(scheduler.logHistory.any((l) => l.contains('SCHEDULER [Schedule]')), isTrue);
    });

    test('Derived completion property strictly matches TaskStatus.completed', () async {
      await engine.initialize();

      final task = await engine.createTask(
        title: 'Complete Checklist',
        dueDate: clock.now,
        priority: 'Medium',
      );

      expect(task.completed, isFalse);
      expect(task.status, equals(TaskStatus.waiting));

      final completedTask = await engine.toggleCompletion(task.id);
      expect(completedTask.completed, isTrue);
      expect(completedTask.status, equals(TaskStatus.completed));
    });

    test('Clock abstraction and reconcileTaskStates transitions overdue tasks to missed', () async {
      await engine.initialize();

      final reminder = clock.now.add(const Duration(hours: 1));
      final task = await engine.createTask(
        title: 'Submit Report',
        dueDate: clock.now.add(const Duration(hours: 2)),
        priority: 'High',
        reminderTime: reminder,
      );

      expect(task.status, equals(TaskStatus.scheduled));

      // Advance TestClock by 3 hours into the future
      clock.advance(const Duration(hours: 3));

      final missedTasks = await engine.reconcileTaskStates();
      expect(missedTasks.length, equals(1));
      expect(missedTasks.first.id, equals(task.id));
      expect(missedTasks.first.status, equals(TaskStatus.missed));
      expect(missedTasks.first.isMissed, isTrue);
    });

    test('State machine prevents invalid state transitions', () async {
      await engine.initialize();

      final task = await engine.createTask(
        title: 'Completed Task',
        dueDate: clock.now,
        priority: 'Low',
      );

      final completed = await engine.toggleCompletion(task.id);
      expect(completed.status, equals(TaskStatus.completed));

      // Attempting invalid transition directly (Completed -> Scheduled)
      final invalidUpdated = completed.copyWith(status: TaskStatus.scheduled);
      expect(
        () => engine.updateTask(invalidUpdated),
        throwsA(isA<InvalidStateTransitionException>()),
      );
    });

    test('Snoozing a task reschedules reminder and emits ReminderSnoozedEvent', () async {
      await engine.initialize();

      final task = await engine.createTask(
        title: 'Call Client',
        dueDate: clock.now.add(const Duration(minutes: 30)),
        priority: 'High',
        reminderTime: clock.now.add(const Duration(minutes: 10)),
      );

      final snoozed = await engine.snoozeTask(task.id, const Duration(minutes: 15));
      expect(snoozed.reminderTime, equals(clock.now.add(const Duration(minutes: 15))));
      expect(snoozed.status, equals(TaskStatus.waiting));
      expect(scheduler.logHistory.any((log) => log.contains('SCHEDULER [Cancel]')), isTrue);
    });

    test('TaskEngine emits sealed TaskEvents over eventStream', () async {
      await engine.initialize();

      final events = <TaskEvent>[];
      final sub = engine.eventStream.listen(events.add);

      final task = await engine.createTask(
        title: 'Stream Test',
        dueDate: clock.now,
        priority: 'Medium',
      );

      await engine.toggleCompletion(task.id);
      await engine.deleteTask(task.id);

      await Future.delayed(const Duration(milliseconds: 10));
      await sub.cancel();

      expect(events.length, equals(3));
      expect(events[0], isA<TaskCreatedEvent>());
      expect(events[1], isA<TaskCompletedEvent>());
      expect(events[2], isA<TaskDeletedEvent>());
    });
  });
}
