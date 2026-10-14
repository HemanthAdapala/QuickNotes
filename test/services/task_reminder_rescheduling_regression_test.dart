import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quick_notes/models/task_status.dart';
import 'package:quick_notes/models/recurrence_rule.dart';
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

  final initialNow = DateTime(2026, 10, 10, 8, 0, 0);

  group('TASK-BUG-004-CANDIDATE Regression Suite — Reminder Rescheduling When Reopening a Task', () {
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

      testUserId = 'usr_task_reminder_reschedule_test';
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

    test('Test A — Complete then reopen an eligible task via TasksProvider.uncompleteTaskOccurrence reschedules reminder', () async {
      final clock = TestClock(initialNow);
      final scheduler = LoggingReminderScheduler();
      final engine = TaskEngine(repository: tasksRepo, clock: clock, scheduler: scheduler);
      await engine.initialize();
      final provider = TasksProvider(engine: engine);

      final futureDue = DateTime(2026, 10, 10, 16, 0, 0);
      final futureReminder = DateTime(2026, 10, 10, 15, 0, 0);

      // 1. Create task with valid enabled future reminder
      final task = await engine.createTask(
        title: 'Team Retrospective',
        dueDate: futureDue,
        priority: 'High',
        reminderEnabled: true,
        reminderTime: futureReminder,
      );

      // 2. Establish reminder is scheduled
      expect(await scheduler.getPendingNotificationIds(), contains(task.notificationId));

      // 3. Complete task via completeTaskOccurrence and verify Bug 03 cancellation intact
      await provider.completeTaskOccurrence(task.id, futureDue);
      expect(await scheduler.getPendingNotificationIds(), isNot(contains(task.notificationId)));
      expect(engine.getTaskById(task.id)?.completed, isTrue);

      // 4. Reopen task through production reopening path (used by HomeScreen onUndo)
      await provider.uncompleteTaskOccurrence(task.id, futureDue);

      // 5. Verify task becomes incomplete
      final reopened = engine.getTaskById(task.id);
      expect(reopened, isNotNull);
      expect(reopened!.completed, isFalse);
      expect(reopened.status, equals(TaskStatus.waiting));

      // 6-7. Primary Bug 04 assertion: Eligible reminder must be rescheduled
      final pendingAfterReopen = await scheduler.getPendingNotificationIds();
      expect(
        pendingAfterReopen,
        contains(task.notificationId),
        reason: 'Bug 04: Reopening an eligible task must reschedule its pending reminder',
      );
    });

    test('Test A2 — Complete then reopen an eligible task via TaskEngine.updateTask reschedules reminder', () async {
      final clock = TestClock(initialNow);
      final scheduler = LoggingReminderScheduler();
      final engine = TaskEngine(repository: tasksRepo, clock: clock, scheduler: scheduler);
      await engine.initialize();

      final futureDue = DateTime(2026, 10, 10, 18, 0, 0);
      final futureReminder = DateTime(2026, 10, 10, 17, 0, 0);

      final task = await engine.createTask(
        title: 'Client Demo',
        dueDate: futureDue,
        priority: 'High',
        reminderEnabled: true,
        reminderTime: futureReminder,
      );

      // Complete via updateTask
      final completed = task.copyWith(
        status: TaskStatus.completed,
        completed: true,
      );
      await engine.updateTask(completed);
      expect(await scheduler.getPendingNotificationIds(), isNot(contains(task.notificationId)));

      // Reopen via updateTask
      final reopened = completed.copyWith(
        status: TaskStatus.waiting,
        completed: false,
        clearCompletedAt: true,
      );
      await engine.updateTask(reopened);

      expect(
        await scheduler.getPendingNotificationIds(),
        contains(task.notificationId),
        reason: 'Bug 04: Reopening an eligible task via updateTask must reschedule its pending reminder',
      );
    });

    test('Test B — Reopening one task does not affect unrelated tasks', () async {
      final clock = TestClock(initialNow);
      final scheduler = LoggingReminderScheduler();
      final engine = TaskEngine(repository: tasksRepo, clock: clock, scheduler: scheduler);
      await engine.initialize();
      final provider = TasksProvider(engine: engine);

      final task1 = await engine.createTask(
        title: 'Primary Task',
        dueDate: DateTime(2026, 10, 10, 14, 0, 0),
        priority: 'High',
        reminderEnabled: true,
        reminderTime: DateTime(2026, 10, 10, 13, 0, 0),
      );

      final task2 = await engine.createTask(
        title: 'Secondary Task',
        dueDate: DateTime(2026, 10, 10, 20, 0, 0),
        priority: 'Medium',
        reminderEnabled: true,
        reminderTime: DateTime(2026, 10, 10, 19, 0, 0),
      );

      expect(await scheduler.getPendingNotificationIds(), contains(task1.notificationId));
      expect(await scheduler.getPendingNotificationIds(), contains(task2.notificationId));

      // Complete and reopen task1
      await provider.completeTaskOccurrence(task1.id, task1.dueDate);
      expect(await scheduler.getPendingNotificationIds(), isNot(contains(task1.notificationId)));
      expect(await scheduler.getPendingNotificationIds(), contains(task2.notificationId));

      await provider.uncompleteTaskOccurrence(task1.id, task1.dueDate);

      final pendingAfterReopen = await scheduler.getPendingNotificationIds();
      expect(pendingAfterReopen, contains(task1.notificationId));
      expect(pendingAfterReopen, contains(task2.notificationId));
    });

    test('Test C — Reminder disabled: Reopening does not schedule reminder', () async {
      final clock = TestClock(initialNow);
      final scheduler = LoggingReminderScheduler();
      final engine = TaskEngine(repository: tasksRepo, clock: clock, scheduler: scheduler);
      await engine.initialize();
      final provider = TasksProvider(engine: engine);

      final task = await engine.createTask(
        title: 'Quiet Task',
        dueDate: DateTime(2026, 10, 10, 17, 0, 0),
        priority: 'Low',
        reminderEnabled: false,
        reminderTime: DateTime(2026, 10, 10, 16, 0, 0),
      );

      expect(await scheduler.getPendingNotificationIds(), isNot(contains(task.notificationId)));

      await provider.completeTaskOccurrence(task.id, task.dueDate);
      await provider.uncompleteTaskOccurrence(task.id, task.dueDate);

      expect(
        await scheduler.getPendingNotificationIds(),
        isNot(contains(task.notificationId)),
        reason: 'Bug 04: Disabled reminder must not be scheduled upon reopening',
      );
    });

    test('Test D — Past reminder: Reopening does not schedule overdue reminder', () async {
      final clock = TestClock(initialNow);
      final scheduler = LoggingReminderScheduler();
      final engine = TaskEngine(repository: tasksRepo, clock: clock, scheduler: scheduler);
      await engine.initialize();
      final provider = TasksProvider(engine: engine);

      final reminderTime = DateTime(2026, 10, 10, 9, 0, 0);
      final task = await engine.createTask(
        title: 'Morning Sync',
        dueDate: DateTime(2026, 10, 10, 10, 0, 0),
        priority: 'Medium',
        reminderEnabled: true,
        reminderTime: reminderTime,
      );

      // Complete while in future (at 8:00 AM)
      await provider.completeTaskOccurrence(task.id, task.dueDate);
      expect(await scheduler.getPendingNotificationIds(), isNot(contains(task.notificationId)));

      // Advance clock past reminderTime (to 9:30 AM)
      clock.setTime(DateTime(2026, 10, 10, 9, 30, 0));

      // Reopen task after reminder time has already passed
      await provider.uncompleteTaskOccurrence(task.id, task.dueDate);

      expect(
        await scheduler.getPendingNotificationIds(),
        isNot(contains(task.notificationId)),
        reason: 'Bug 04: Overdue/past reminder must not be scheduled upon reopening',
      );
    });

    test('Test E — Persistence consistency across SQLite reload after reopening', () async {
      final clock = TestClock(initialNow);
      final scheduler = LoggingReminderScheduler();
      final engine = TaskEngine(repository: tasksRepo, clock: clock, scheduler: scheduler);
      await engine.initialize();
      final provider = TasksProvider(engine: engine);

      final task = await engine.createTask(
        title: 'Persistent Architecture Task',
        dueDate: DateTime(2026, 10, 10, 19, 0, 0),
        priority: 'High',
        reminderEnabled: true,
        reminderTime: DateTime(2026, 10, 10, 18, 0, 0),
      );

      await provider.completeTaskOccurrence(task.id, task.dueDate);
      await provider.uncompleteTaskOccurrence(task.id, task.dueDate);

      // Verify scheduler has reminder
      expect(await scheduler.getPendingNotificationIds(), contains(task.notificationId));

      // Reload from SQLite repository
      final allTasks = await tasksRepo.getTasks();
      final reloaded = allTasks.firstWhere((t) => t.id == task.id);
      expect(reloaded.completed, isFalse);
      expect(reloaded.status, equals(TaskStatus.waiting));
      expect(reloaded.reminderEnabled, isTrue);
      expect(reloaded.reminderTime, isNotNull);
    });

    test('Test F — Repeated reopening calls remain idempotent without corrupting reminder state', () async {
      final clock = TestClock(initialNow);
      final scheduler = LoggingReminderScheduler();
      final engine = TaskEngine(repository: tasksRepo, clock: clock, scheduler: scheduler);
      await engine.initialize();
      final provider = TasksProvider(engine: engine);

      final task = await engine.createTask(
        title: 'Idempotent Reopen Task',
        dueDate: DateTime(2026, 10, 10, 21, 0, 0),
        priority: 'Medium',
        reminderEnabled: true,
        reminderTime: DateTime(2026, 10, 10, 20, 0, 0),
      );

      await provider.completeTaskOccurrence(task.id, task.dueDate);

      // First reopen
      await provider.uncompleteTaskOccurrence(task.id, task.dueDate);
      expect(await scheduler.getPendingNotificationIds(), contains(task.notificationId));

      final countFirst = scheduler.logHistory
          .where((l) => l.contains('Task "${task.title}"'))
          .length;

      // Second idempotent reopen call
      await provider.uncompleteTaskOccurrence(task.id, task.dueDate);
      expect(await scheduler.getPendingNotificationIds(), contains(task.notificationId));

      final countSecond = scheduler.logHistory
          .where((l) => l.contains('Task "${task.title}"'))
          .length;
      expect(countSecond, equals(countFirst));
    });

    test('Test G — Recurring task occurrence reopening preserves recurrence boundary', () async {
      final clock = TestClock(initialNow);
      final scheduler = LoggingReminderScheduler();
      final engine = TaskEngine(repository: tasksRepo, clock: clock, scheduler: scheduler);
      await engine.initialize();
      final provider = TasksProvider(engine: engine);

      final targetDate = DateTime(2026, 10, 10);
      final recurringTask = await engine.createTask(
        title: 'Daily Workout',
        dueDate: targetDate,
        priority: 'High',
        isRecurring: true,
        recurrence: const RecurrenceRule(type: RecurrenceType.daily, interval: 1),
      );

      // Complete and uncomplete occurrence on targetDate
      await provider.completeTaskOccurrence(recurringTask.id, targetDate);
      expect(
        engine.getTaskById(recurringTask.id)?.completedDates,
        contains('2026-10-10'),
      );

      await provider.uncompleteTaskOccurrence(recurringTask.id, targetDate);
      expect(
        engine.getTaskById(recurringTask.id)?.completedDates,
        isNot(contains('2026-10-10')),
      );
    });
  });
}
