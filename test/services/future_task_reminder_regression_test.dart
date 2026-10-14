import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quick_notes/models/task_status.dart';
import 'package:quick_notes/models/reminder_mode.dart';
import 'package:quick_notes/models/session_type.dart';
import 'package:quick_notes/services/database_service.dart';
import 'package:quick_notes/services/session_manager.dart';
import 'package:quick_notes/repositories/tasks_repository.dart';
import 'package:quick_notes/services/task_engine.dart';
import 'package:quick_notes/services/clock_service.dart';
import 'package:quick_notes/services/reminder_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Reference initial time: 10:00 AM on Oct 10, 2026
  final initialNow = DateTime.utc(2026, 10, 10, 10, 0, 0);

  group('P0 Future Task Reminder & Alarm Regression Suite', () {
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

      testUserId = 'usr_future_reminder_test';
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

    test('Test 1: Schedulers accept reminders for today, tomorrow, and multi-day future', () async {
      final clock = TestClock(initialNow);
      final scheduler = LoggingReminderScheduler();
      final engine = TaskEngine(repository: tasksRepo, clock: clock, scheduler: scheduler);
      await engine.initialize();

      // Today reminder (+3 hours)
      final todayDue = DateTime.utc(2026, 10, 10, 13, 0, 0);
      final todayTask = await engine.createTask(
        title: 'Task Later Today',
        dueDate: todayDue,
        reminderEnabled: true,
        reminderTime: todayDue,
      );

      // Tomorrow reminder (+24 hours)
      final tomorrowDue = DateTime.utc(2026, 10, 11, 10, 0, 0);
      final tomorrowTask = await engine.createTask(
        title: 'Task Tomorrow Morning',
        dueDate: tomorrowDue,
        reminderEnabled: true,
        reminderTime: tomorrowDue,
      );

      // Multi-day future (+5 days)
      final futureDue = DateTime.utc(2026, 10, 15, 10, 0, 0);
      final futureTask = await engine.createTask(
        title: 'Task 5 Days Later',
        dueDate: futureDue,
        reminderEnabled: true,
        reminderTime: futureDue,
      );

      final pendingIds = await scheduler.getPendingNotificationIds();
      expect(pendingIds, contains(todayTask.notificationId), reason: 'Today task must be scheduled');
      expect(pendingIds, contains(tomorrowTask.notificationId), reason: 'Tomorrow task must be scheduled');
      expect(pendingIds, contains(futureTask.notificationId), reason: 'Future task must be scheduled');
    });

    test('Test 2: Startup & Reboot reconciliation preserves tomorrow and future reminders', () async {
      final clock = TestClock(initialNow);
      final scheduler = LoggingReminderScheduler();
      final engine = TaskEngine(repository: tasksRepo, clock: clock, scheduler: scheduler);
      await engine.initialize();

      final tomorrowDue = DateTime.utc(2026, 10, 11, 10, 0, 0);
      final tomorrowTask = await engine.createTask(
        title: 'Tomorrow Important Meeting',
        dueDate: tomorrowDue,
        reminderEnabled: true,
        reminderTime: tomorrowDue,
      );

      // Simulate app restart / reboot: create fresh engine with clean scheduler
      final rebootScheduler = LoggingReminderScheduler();
      final rebootEngine = TaskEngine(repository: tasksRepo, clock: clock, scheduler: rebootScheduler);

      // Before initialize, reboot scheduler has no notifications
      expect(await rebootScheduler.getPendingNotificationIds(), isEmpty);

      // Startup reconciliation
      await rebootEngine.initialize();

      // Tomorrow task must be rescheduled on boot/init
      final rebootPending = await rebootScheduler.getPendingNotificationIds();
      expect(
        rebootPending,
        contains(tomorrowTask.notificationId),
        reason: 'Reboot/startup must reschedule active future reminder for tomorrow',
      );

      final loadedTask = rebootEngine.getTaskById(tomorrowTask.id);
      expect(loadedTask?.status, isNot(equals(TaskStatus.missed)),
        reason: 'Future task must NOT be marked missed on startup reconciliation',
      );
    });

    test('Test 3: Editing a future task date and time normalizes to UTC and updates reminder schedule', () async {
      final clock = TestClock(initialNow);
      final scheduler = LoggingReminderScheduler();
      final engine = TaskEngine(repository: tasksRepo, clock: clock, scheduler: scheduler);
      await engine.initialize();

      final tomorrowDue = DateTime(2026, 10, 11, 9, 0, 0); // Local DateTime
      final task = await engine.createTask(
        title: 'Dentist Appointment',
        dueDate: tomorrowDue,
        reminderEnabled: true,
        reminderTime: tomorrowDue,
      );

      expect(await scheduler.getPendingNotificationIds(), contains(task.notificationId));

      // Edit task with local DateTime representation (simulating CreateTaskBottomSheet)
      final updatedDueLocal = DateTime(2026, 10, 12, 14, 30, 0);
      final editedTask = task.copyWith(
        title: 'Dentist Appointment Rescheduled',
        dueDate: updatedDueLocal,
        reminderTime: updatedDueLocal,
        reminderEnabled: true,
        reminderMode: ReminderMode.alarm,
      );

      await engine.updateTask(editedTask);

      final updatedTaskInEngine = engine.getTaskById(task.id)!;
      // Invariant: dueDate and reminderTime in storage and memory must be UTC
      expect(updatedTaskInEngine.dueDate.isUtc, isTrue, reason: 'Engine updateTask must ensure dueDate is UTC');
      expect(updatedTaskInEngine.reminderTime?.isUtc, isTrue, reason: 'Engine updateTask must ensure reminderTime is UTC');

      final pendingAfterEdit = await scheduler.getPendingNotificationIds();
      expect(pendingAfterEdit, contains(task.notificationId), reason: 'Updated reminder must remain scheduled');
    });

    test('Test 4: Repository getTasksForDate accurately finds tomorrow tasks regardless of timezone offset', () async {
      final clock = TestClock(initialNow);
      final scheduler = LoggingReminderScheduler();
      final engine = TaskEngine(repository: tasksRepo, clock: clock, scheduler: scheduler);
      await engine.initialize();

      // Suppose local date is tomorrow (Oct 11) early morning at 03:00 AM IST (+5:30)
      // In UTC, this is Oct 10, 21:30:00Z!
      final tomorrowLocal = DateTime(2026, 10, 11, 3, 0, 0);
      await engine.createTask(
        title: 'Early Morning Flight Tomorrow',
        dueDate: tomorrowLocal,
        reminderEnabled: true,
        reminderTime: tomorrowLocal,
      );

      // Querying repository for tomorrow's date
      final tomorrowQueryDate = DateTime(2026, 10, 11);
      final results = await tasksRepo.getTasksForDate(tomorrowQueryDate);

      expect(results.length, equals(1),
        reason: 'Repository getTasksForDate must match task by local calendar day even when UTC date is previous day',
      );
      expect(results.first.title, equals('Early Morning Flight Tomorrow'));
    });

    test('Test 5: reconcileTaskStates does not prematurely mark tomorrow task as missed when reminderTime is after clock', () async {
      final clock = TestClock(initialNow);
      final scheduler = LoggingReminderScheduler();
      final engine = TaskEngine(repository: tasksRepo, clock: clock, scheduler: scheduler);
      await engine.initialize();

      // Task tomorrow at 18:00 UTC
      final tomorrowDue = DateTime.utc(2026, 10, 11, 18, 0, 0);
      final task = await engine.createTask(
        title: 'Late Evening Study Session',
        dueDate: tomorrowDue,
        reminderEnabled: true,
        reminderTime: tomorrowDue,
      );

      // Advance clock into tomorrow morning (before task due/reminder time)
      clock.setTime(DateTime.utc(2026, 10, 11, 9, 0, 0));

      final missedList = await engine.reconcileTaskStates();
      expect(missedList.any((t) => t.id == task.id), isFalse);

      final currentTask = engine.getTaskById(task.id)!;
      expect(currentTask.status, isNot(equals(TaskStatus.missed)));
      expect(currentTask.completed, isFalse);

      // Advance clock past task reminder time
      clock.setTime(DateTime.utc(2026, 10, 11, 19, 0, 0));
      final missedAfterPass = await engine.reconcileTaskStates();
      expect(missedAfterPass.any((t) => t.id == task.id), isTrue);
      expect(engine.getTaskById(task.id)!.status, equals(TaskStatus.missed));
    });

    test('Test 6: Task with due date at start of day and reminder later in the day is NOT marked missed before reminderTime', () async {
      final clock = TestClock(initialNow);
      final scheduler = LoggingReminderScheduler();
      final engine = TaskEngine(repository: tasksRepo, clock: clock, scheduler: scheduler);
      await engine.initialize();

      // Suppose user creates a task for tomorrow with date Oct 11 (midnight 00:00) and reminder at 18:00
      final tomorrowStartOfDay = DateTime.utc(2026, 10, 11, 0, 0, 0);
      final tomorrowReminder = DateTime.utc(2026, 10, 11, 18, 0, 0);

      final task = await engine.createTask(
        title: 'Project Submission Tomorrow Evening',
        dueDate: tomorrowStartOfDay,
        reminderEnabled: true,
        reminderTime: tomorrowReminder,
      );

      // Advance clock to tomorrow noon (12:00 PM), which is after tomorrowStartOfDay (00:00) but BEFORE reminderTime (18:00)
      clock.setTime(DateTime.utc(2026, 10, 11, 12, 0, 0));

      final missedList = await engine.reconcileTaskStates();
      expect(
        missedList.any((t) => t.id == task.id),
        isFalse,
        reason: 'Task with future reminder later today/tomorrow must not be marked missed while reminder is still pending in future',
      );

      final current = engine.getTaskById(task.id)!;
      expect(current.status, isNot(equals(TaskStatus.missed)));
    });
  });
}
