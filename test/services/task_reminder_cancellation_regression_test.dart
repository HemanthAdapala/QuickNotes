import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quick_notes/models/task_status.dart';
import 'package:quick_notes/models/session_type.dart';
import 'package:quick_notes/services/database_service.dart';
import 'package:quick_notes/services/session_manager.dart';
import 'package:quick_notes/repositories/tasks_repository.dart';
import 'package:quick_notes/services/task_engine.dart';
import 'package:quick_notes/services/clock_service.dart';
import 'package:quick_notes/services/reminder_scheduler.dart';
import 'package:quick_notes/providers/tasks_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fixedNow = DateTime(2026, 10, 10, 8, 0, 0);

  group('TASK-BUG-003 Regression Suite — Reminder Cancellation When Completing a Task', () {
    late SqliteTasksRepository tasksRepo;
    late String testUserId;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall methodCall) async => '.',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (MethodCall methodCall) async => null,
      );

      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;

      testUserId = 'usr_task_reminder_cancel_test';
      final session = SessionManager();
      await session.init();
      await session.saveSession(
        userId: testUserId,
        sessionType: SessionType.offline,
      );
    });

    setUp(() async {
      final db = await DatabaseService.instance.database;
      await db.delete('tasks');
      await db.delete('sync_outbox');
      tasksRepo = SqliteTasksRepository();
    });

    test('Test A1 — Completing a task via TasksProvider.completeTaskOccurrence cancels its pending reminder', () async {
      final clock = TestClock(fixedNow);
      final scheduler = LoggingReminderScheduler();
      final engine = TaskEngine(repository: tasksRepo, clock: clock, scheduler: scheduler);
      await engine.initialize();
      final provider = TasksProvider(engine: engine);

      final futureDue = DateTime(2026, 10, 10, 15, 0, 0);
      final futureReminder = DateTime(2026, 10, 10, 14, 0, 0);

      final task = await engine.createTask(
        title: 'Project Presentation',
        dueDate: futureDue,
        priority: 'High',
        reminderEnabled: true,
        reminderTime: futureReminder,
      );

      // Verify reminder is initially scheduled in scheduler
      final initialPending = await scheduler.getPendingNotificationIds();
      expect(initialPending, contains(task.notificationId));

      // Complete task through TasksProvider.completeTaskOccurrence (entry point used by HomeScreen focused overlay)
      await provider.completeTaskOccurrence(task.id, futureDue);

      // Verify task completion state
      final completedTask = engine.getTaskById(task.id);
      expect(completedTask, isNotNull);
      expect(completedTask!.completed, isTrue);
      expect(completedTask.status, equals(TaskStatus.completed));

      // Primary TASK-BUG-003 assertion: Pending reminder MUST be cancelled
      final pendingAfterCompletion = await scheduler.getPendingNotificationIds();
      expect(
        pendingAfterCompletion,
        isNot(contains(task.notificationId)),
        reason: 'TASK-BUG-003: Completing a task via completeTaskOccurrence must cancel its pending reminder',
      );
    });

    test('Test A2 — Updating a task to completed in TaskEngine.updateTask cancels its pending reminder', () async {
      final clock = TestClock(fixedNow);
      final scheduler = LoggingReminderScheduler();
      final engine = TaskEngine(repository: tasksRepo, clock: clock, scheduler: scheduler);
      await engine.initialize();

      final futureDue = DateTime(2026, 10, 10, 16, 0, 0);
      final futureReminder = DateTime(2026, 10, 10, 15, 30, 0);

      final task = await engine.createTask(
        title: 'Dentist Appointment',
        dueDate: futureDue,
        priority: 'Medium',
        reminderEnabled: true,
        reminderTime: futureReminder,
      );

      expect(await scheduler.getPendingNotificationIds(), contains(task.notificationId));

      // Update task to completed via TaskEngine.updateTask
      final updatedCompleted = task.copyWith(
        status: TaskStatus.completed,
        completed: true,
      );
      await engine.updateTask(updatedCompleted);

      // Primary assertion: Reminder must be cancelled upon completion
      final pendingAfterUpdate = await scheduler.getPendingNotificationIds();
      expect(
        pendingAfterUpdate,
        isNot(contains(task.notificationId)),
        reason: 'TASK-BUG-003: Transitioning a task to completed via updateTask must cancel its pending reminder',
      );
    });

    test('Test B — Completing one task cancels only its reminder and preserves others', () async {
      final clock = TestClock(fixedNow);
      final scheduler = LoggingReminderScheduler();
      final engine = TaskEngine(repository: tasksRepo, clock: clock, scheduler: scheduler);
      await engine.initialize();
      final provider = TasksProvider(engine: engine);

      final task1 = await engine.createTask(
        title: 'Task Alpha',
        dueDate: DateTime(2026, 10, 10, 12, 0, 0),
        priority: 'High',
        reminderEnabled: true,
        reminderTime: DateTime(2026, 10, 10, 11, 0, 0),
      );

      final task2 = await engine.createTask(
        title: 'Task Beta',
        dueDate: DateTime(2026, 10, 10, 18, 0, 0),
        priority: 'Low',
        reminderEnabled: true,
        reminderTime: DateTime(2026, 10, 10, 17, 0, 0),
      );

      final initialPending = await scheduler.getPendingNotificationIds();
      expect(initialPending, contains(task1.notificationId));
      expect(initialPending, contains(task2.notificationId));

      // Complete Task Alpha only
      await provider.completeTaskOccurrence(task1.id, task1.dueDate);

      final pendingAfterAlpha = await scheduler.getPendingNotificationIds();
      expect(
        pendingAfterAlpha,
        isNot(contains(task1.notificationId)),
        reason: 'TASK-BUG-003: Task Alpha reminder must be cancelled',
      );
      expect(
        pendingAfterAlpha,
        contains(task2.notificationId),
        reason: 'TASK-BUG-003: Task Beta reminder must remain scheduled',
      );
    });

    test('Test C — Repeated completion calls are idempotent and keep reminder cancelled', () async {
      final clock = TestClock(fixedNow);
      final scheduler = LoggingReminderScheduler();
      final engine = TaskEngine(repository: tasksRepo, clock: clock, scheduler: scheduler);
      await engine.initialize();
      final provider = TasksProvider(engine: engine);

      final task = await engine.createTask(
        title: 'Pay Electricity Bill',
        dueDate: DateTime(2026, 10, 10, 20, 0, 0),
        priority: 'High',
        reminderEnabled: true,
        reminderTime: DateTime(2026, 10, 10, 19, 0, 0),
      );

      expect(await scheduler.getPendingNotificationIds(), contains(task.notificationId));

      // Complete first time
      await provider.completeTaskOccurrence(task.id, task.dueDate);
      expect(await scheduler.getPendingNotificationIds(), isNot(contains(task.notificationId)));

      final cancelLogCountFirst = scheduler.logHistory
          .where((l) => l.contains('NotificationID ${task.notificationId}'))
          .length;

      // Complete second time (idempotent call)
      await provider.completeTaskOccurrence(task.id, task.dueDate);
      expect(await scheduler.getPendingNotificationIds(), isNot(contains(task.notificationId)));

      final cancelLogCountSecond = scheduler.logHistory
          .where((l) => l.contains('NotificationID ${task.notificationId}'))
          .length;
      expect(cancelLogCountSecond, equals(cancelLogCountFirst));

      final completedTask = engine.getTaskById(task.id);
      expect(completedTask?.completed, isTrue);
      expect(completedTask?.status, equals(TaskStatus.completed));
    });

    test('Test D — Persisted SQLite state and reminder cancellation integrity', () async {
      final clock = TestClock(fixedNow);
      final scheduler = LoggingReminderScheduler();
      final engine = TaskEngine(repository: tasksRepo, clock: clock, scheduler: scheduler);
      await engine.initialize();
      final provider = TasksProvider(engine: engine);

      final task = await engine.createTask(
        title: 'Database Persistence Task',
        dueDate: DateTime(2026, 10, 10, 22, 0, 0),
        priority: 'Medium',
        reminderEnabled: true,
        reminderTime: DateTime(2026, 10, 10, 21, 0, 0),
      );

      await provider.completeTaskOccurrence(task.id, task.dueDate);

      // Verify cancellation at scheduler level
      expect(await scheduler.getPendingNotificationIds(), isNot(contains(task.notificationId)));

      // Reload task from SQLite repository
      final allTasks = await tasksRepo.getTasks();
      final reloadedTask = allTasks.firstWhere((t) => t.id == task.id);
      expect(reloadedTask.completed, isTrue);
      expect(reloadedTask.status, equals(TaskStatus.completed));
    });
  });
}
