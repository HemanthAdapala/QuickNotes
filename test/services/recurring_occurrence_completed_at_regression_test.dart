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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final initialTime = DateTime(2026, 7, 24, 10, 0, 0);

  group('TASK-BUG-002 Regression Suite — Prevent Recurring Occurrences from Inheriting completedAt', () {
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

      testUserId = 'usr_task_recurrence_bug002_test';
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

    test('Test A — New occurrence clears completion metadata in memory', () async {
      final clock = TestClock(initialTime);
      final scheduler = LoggingReminderScheduler();
      final engine = TaskEngine(repository: tasksRepo, clock: clock, scheduler: scheduler);
      await engine.initialize();

      // 1. Create a daily recurring task due today at 9:00 AM
      final initialDueDate = DateTime(2026, 7, 24, 9, 0, 0);
      final createdTask = await engine.createTask(
        title: 'Daily Standup',
        dueDate: initialDueDate,
        priority: 'High',
        isRecurring: true,
        recurrence: const RecurrenceRule(type: RecurrenceType.daily, interval: 1),
      );

      expect(createdTask.completed, isFalse);
      expect(createdTask.completedAt, isNull);

      // 2. Complete the task at 10:00 AM
      final completedPredecessor = await engine.toggleCompletion(createdTask.id);
      expect(completedPredecessor.completed, isTrue);
      expect(completedPredecessor.status, equals(TaskStatus.completed));
      expect(completedPredecessor.completedAt, equals(clock.now));

      // 3. Trigger recurrence generation path (reload / reconciliation)
      await engine.reloadFromRepository();

      // 4. Locate newly generated occurrence
      expect(engine.tasks.length, equals(2));
      final nextOccurrence = engine.tasks.firstWhere((t) => t.id != createdTask.id);

      // 5-9. Verify invariants
      expect(nextOccurrence.id, isNot(equals(createdTask.id)));
      expect(nextOccurrence.recurringSeriesId, equals(completedPredecessor.recurringSeriesId));
      expect(nextOccurrence.completed, isFalse);
      expect(nextOccurrence.status, equals(TaskStatus.waiting));
      expect(nextOccurrence.dueDate.toLocal(), equals(DateTime(2026, 7, 25, 9, 0, 0)));

      // Primary TASK-BUG-002 assertion: Incomplete next occurrence MUST have null completedAt
      expect(
        nextOccurrence.completedAt,
        isNull,
        reason: 'TASK-BUG-002: Newly generated occurrence must not inherit predecessor completedAt in memory',
      );
    });

    test('Test B — Persisted next occurrence has NULL completedAt in SQLite', () async {
      final clock = TestClock(initialTime);
      final scheduler = LoggingReminderScheduler();
      final engine = TaskEngine(repository: tasksRepo, clock: clock, scheduler: scheduler);
      await engine.initialize();

      // 1. Create and persist recurring task
      final initialDueDate = DateTime(2026, 7, 24, 9, 0, 0);
      final createdTask = await engine.createTask(
        title: 'Weekly Report',
        dueDate: initialDueDate,
        priority: 'Medium',
        isRecurring: true,
        recurrence: const RecurrenceRule(type: RecurrenceType.weekly, interval: 1),
      );

      // 2. Complete through engine
      await engine.toggleCompletion(createdTask.id);

      // 3. Allow recurrence generation to persist next occurrence
      await engine.reloadFromRepository();

      final nextOccurrence = engine.tasks.firstWhere((t) => t.id != createdTask.id);

      // 4. Reload next occurrence from SQLite repository
      final allRepoTasks = await tasksRepo.getTasks();
      final reloadedNext = allRepoTasks.firstWhere((t) => t.id == nextOccurrence.id);
      expect(reloadedNext.completed, isFalse);
      expect(reloadedNext.status, equals(TaskStatus.waiting));

      // 5. Assert repository reload has null completedAt
      expect(
        reloadedNext.completedAt,
        isNull,
        reason: 'TASK-BUG-002: Repository reload of next occurrence must return null completedAt',
      );

      // 6. Direct SQL query on SQLite tasks table row
      final db = await DatabaseService.instance.database;
      final rows = await db.query(
        'tasks',
        columns: ['id', 'title', 'completed', 'status', 'completedAt'],
        where: 'id = ?',
        whereArgs: [nextOccurrence.id],
      );

      expect(rows.length, equals(1));
      expect(rows.first['completed'], equals(0));
      expect(rows.first['status'], equals('waiting'));
      expect(
        rows.first['completedAt'],
        isNull,
        reason: 'TASK-BUG-002: SQLite tasks table row for new occurrence must have NULL completedAt in disk storage',
      );
    });

    test('Test C — Repeated recurrence transitions preserve independent timestamps', () async {
      final clock = TestClock(initialTime);
      final scheduler = LoggingReminderScheduler();
      final engine = TaskEngine(repository: tasksRepo, clock: clock, scheduler: scheduler);
      await engine.initialize();

      // Cycle 1: Create daily task
      final task1 = await engine.createTask(
        title: 'Daily Medication',
        dueDate: DateTime(2026, 7, 24, 8, 0, 0),
        priority: 'High',
        isRecurring: true,
        recurrence: const RecurrenceRule(type: RecurrenceType.daily, interval: 1),
      );

      // Complete cycle 1 at 10:00 AM on July 24
      final completed1 = await engine.toggleCompletion(task1.id);
      final completedAt1 = completed1.completedAt;
      expect(completedAt1, equals(clock.now));

      // Generate cycle 2
      await engine.reloadFromRepository();
      expect(engine.tasks.length, equals(2));
      final task2 = engine.tasks.firstWhere((t) => t.id != task1.id);

      expect(
        task2.completedAt,
        isNull,
        reason: 'TASK-BUG-002: Occurrence 2 must start with null completedAt',
      );

      // Advance clock to July 25, 11:30 AM
      final time2 = DateTime(2026, 7, 25, 11, 30, 0);
      clock.setTime(time2);

      // Complete cycle 2
      final completed2 = await engine.toggleCompletion(task2.id);
      expect(completed2.completedAt, equals(clock.now));

      // Generate cycle 3
      await engine.reloadFromRepository();
      expect(engine.tasks.length, equals(3));
      final task3 = engine.tasks.firstWhere((t) => t.id != task1.id && t.id != task2.id);

      expect(
        task3.completedAt,
        isNull,
        reason: 'TASK-BUG-002: Occurrence 3 must start with null completedAt',
      );

      // Verify history integrity: Occurrence 1 retained historical timestamp
      final historicalTask1 = engine.getTaskById(task1.id);
      expect(historicalTask1?.completedAt, equals(completedAt1));
      expect(historicalTask1?.completedAt, isNot(equals(clock.now)));
    });

    test('Test D — Recurrence generation after complete -> reopen -> re-complete cycle', () async {
      final clock = TestClock(initialTime);
      final scheduler = LoggingReminderScheduler();
      final engine = TaskEngine(repository: tasksRepo, clock: clock, scheduler: scheduler);
      await engine.initialize();

      final task = await engine.createTask(
        title: 'Nightly Backup',
        dueDate: DateTime(2026, 7, 24, 23, 0, 0),
        priority: 'Low',
        isRecurring: true,
        recurrence: const RecurrenceRule(type: RecurrenceType.daily, interval: 1),
      );

      // 1. Complete task
      await engine.toggleCompletion(task.id);
      expect(engine.getTaskById(task.id)?.completedAt, isNotNull);

      // 2. Reopen task (BUG-004 verification)
      await engine.toggleCompletion(task.id);
      expect(engine.getTaskById(task.id)?.completedAt, isNull);

      // 3. Re-complete task at time2
      final time2 = DateTime(2026, 7, 24, 23, 45, 0);
      clock.setTime(time2);
      final recompleted = await engine.toggleCompletion(task.id);
      expect(recompleted.completedAt, equals(clock.now));

      // 4. Generate next occurrence
      await engine.reloadFromRepository();
      expect(engine.tasks.length, equals(2));
      final nextOcc = engine.tasks.firstWhere((t) => t.id != task.id);

      expect(
        nextOcc.completedAt,
        isNull,
        reason: 'TASK-BUG-002: Next occurrence must have null completedAt after re-completion cycle',
      );
    });
  });
}
