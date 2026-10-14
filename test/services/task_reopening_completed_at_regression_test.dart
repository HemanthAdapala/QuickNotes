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

  final fixedTime = DateTime(2026, 10, 10, 12, 0, 0);

  group('TASK-BUG-001 Regression Suite — Clear completedAt When Reopening a Task', () {
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

      testUserId = 'usr_task_reopen_test';
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

    test('Test A — TaskEngine completion and reopening clears completedAt in memory', () async {
      final clock = TestClock(fixedTime);
      final scheduler = LoggingReminderScheduler();
      final engine = TaskEngine(repository: tasksRepo, clock: clock, scheduler: scheduler);
      await engine.initialize();

      // 1. Create incomplete task
      final task = await engine.createTask(
        title: 'TaskEngine Reopen Test',
        dueDate: fixedTime,
      );
      expect(task.completed, isFalse);
      expect(task.status, equals(TaskStatus.waiting));
      expect(task.completedAt, isNull);

      // 2. Complete the task
      final completedTask = await engine.toggleCompletion(task.id);
      expect(completedTask.completed, isTrue);
      expect(completedTask.status, equals(TaskStatus.completed));
      expect(completedTask.completedAt, isNotNull);
      expect(completedTask.completedAt, equals(fixedTime.toUtc()));

      // 3. Reopen the task
      final reopenedTask = await engine.toggleCompletion(task.id);
      expect(reopenedTask.completed, isFalse);
      expect(reopenedTask.status, equals(TaskStatus.waiting));
      // Primary TASK-BUG-001 regression assertion: completedAt must be cleared to null
      expect(reopenedTask.completedAt, isNull,
          reason: 'TASK-BUG-001: completedAt must be null when reopened via TaskEngine.toggleCompletion');
    });

    test('Test B — SQLite persistence clears completedAt column upon reopening', () async {
      final clock = TestClock(fixedTime);
      final scheduler = LoggingReminderScheduler();
      final engine = TaskEngine(repository: tasksRepo, clock: clock, scheduler: scheduler);
      await engine.initialize();

      // 1. Persist incomplete task
      final task = await engine.createTask(
        title: 'SQLite Persistence Reopen Test',
        dueDate: fixedTime,
      );

      // 2. Complete through production path
      await engine.toggleCompletion(task.id);
      final taskAfterComplete = (await tasksRepo.getTasks()).firstWhere((t) => t.id == task.id);
      expect(taskAfterComplete.completed, isTrue);
      expect(taskAfterComplete.completedAt, isNotNull);

      // 3. Reopen through production path
      await engine.toggleCompletion(task.id);

      // 4. Reload from repository
      final reloadedTask = (await tasksRepo.getTasks()).firstWhere((t) => t.id == task.id);
      expect(reloadedTask.completed, isFalse);
      expect(reloadedTask.status, equals(TaskStatus.waiting));
      expect(reloadedTask.completedAt, isNull,
          reason: 'TASK-BUG-001: Repository reload must return null completedAt after reopening');

      // 5. Direct SQLite raw query inspection
      final db = await DatabaseService.instance.database;
      final rawRows = await db.query(
        'tasks',
        columns: ['id', 'status', 'completed', 'completedAt'],
        where: 'id = ?',
        whereArgs: [task.id],
      );
      expect(rawRows, isNotEmpty);
      expect(rawRows.first['completed'], equals(0));
      expect(rawRows.first['status'], equals('waiting'));
      expect(rawRows.first['completedAt'], isNull,
          reason: 'TASK-BUG-001: SQLite tasks table row must have NULL completedAt in disk storage');
    });

    test('Test C1 — TasksProvider.toggleTaskCompletionOnDate clears completedAt on reopening', () async {
      final clock = TestClock(fixedTime);
      final scheduler = LoggingReminderScheduler();
      final engine = TaskEngine(repository: tasksRepo, clock: clock, scheduler: scheduler);
      await engine.initialize();
      final provider = TasksProvider(engine: engine);

      final task = await engine.createTask(
        title: 'Provider Toggle Date Reopen Test',
        dueDate: fixedTime,
      );

      // Complete via provider
      await provider.toggleTaskCompletionOnDate(task.id, fixedTime);
      expect(provider.tasks.firstWhere((t) => t.id == task.id).completed, isTrue);
      expect(provider.tasks.firstWhere((t) => t.id == task.id).completedAt, isNotNull);

      // Reopen via provider
      await provider.toggleTaskCompletionOnDate(task.id, fixedTime);
      final reopened = provider.tasks.firstWhere((t) => t.id == task.id);
      expect(reopened.completed, isFalse);
      expect(reopened.status, equals(TaskStatus.waiting));
      expect(reopened.completedAt, isNull,
          reason: 'TASK-BUG-001: TasksProvider.toggleTaskCompletionOnDate must clear completedAt on reopen');
    });

    test('Test C2 — TasksProvider.uncompleteTaskOccurrence clears completedAt for non-recurring tasks', () async {
      final clock = TestClock(fixedTime);
      final scheduler = LoggingReminderScheduler();
      final engine = TaskEngine(repository: tasksRepo, clock: clock, scheduler: scheduler);
      await engine.initialize();
      final provider = TasksProvider(engine: engine);

      final task = await engine.createTask(
        title: 'Provider Uncomplete Occurrence Test',
        dueDate: fixedTime,
      );

      // Complete via engine so it has a valid completedAt
      await engine.toggleCompletion(task.id);
      expect(provider.tasks.firstWhere((t) => t.id == task.id).completed, isTrue);
      expect(provider.tasks.firstWhere((t) => t.id == task.id).completedAt, isNotNull);

      // Uncomplete via provider.uncompleteTaskOccurrence
      await provider.uncompleteTaskOccurrence(task.id, fixedTime);
      final uncompleted = provider.tasks.firstWhere((t) => t.id == task.id);
      expect(uncompleted.completed, isFalse);
      expect(uncompleted.status, equals(TaskStatus.waiting));
      expect(uncompleted.completedAt, isNull,
          reason: 'TASK-BUG-001: TasksProvider.uncompleteTaskOccurrence must clear completedAt when uncompleting');
    });

    test('Test D — Task can be completed, reopened, and re-completed recording fresh timestamp', () async {
      final clock = TestClock(fixedTime);
      final scheduler = LoggingReminderScheduler();
      final engine = TaskEngine(repository: tasksRepo, clock: clock, scheduler: scheduler);
      await engine.initialize();

      final task = await engine.createTask(
        title: 'Full Lifecycle Completion Test',
        dueDate: fixedTime,
      );

      // Cycle 1: Complete at fixedTime
      await engine.toggleCompletion(task.id);
      expect(engine.tasks.first.completedAt, equals(fixedTime.toUtc()));

      // Cycle 1: Reopen
      await engine.toggleCompletion(task.id);
      expect(engine.tasks.first.completed, isFalse);
      expect(engine.tasks.first.completedAt, isNull,
          reason: 'TASK-BUG-001: First reopen must clear completedAt');

      // Cycle 2: Advance clock by 2 hours and re-complete
      final secondTime = fixedTime.add(const Duration(hours: 2));
      clock.advance(const Duration(hours: 2));
      await engine.toggleCompletion(task.id);

      expect(engine.tasks.first.completed, isTrue);
      expect(engine.tasks.first.status, equals(TaskStatus.completed));
      expect(engine.tasks.first.completedAt, equals(secondTime.toUtc()),
          reason: 'Re-completing must record the fresh timestamp, not the initial one');
    });
  });
}
