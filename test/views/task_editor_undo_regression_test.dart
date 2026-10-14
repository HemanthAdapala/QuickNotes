import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:quick_notes/models/recurrence_rule.dart';
import 'package:quick_notes/models/reminder_mode.dart';
import 'package:quick_notes/models/task_item.dart';
import 'package:quick_notes/models/task_status.dart';
import 'package:quick_notes/providers/tasks_provider.dart';
import 'package:quick_notes/repositories/tasks_repository.dart';
import 'package:quick_notes/services/clock_service.dart';
import 'package:quick_notes/services/reminder_scheduler.dart';
import 'package:quick_notes/services/task_engine.dart';
import 'package:quick_notes/views/widgets/create_task_bottom_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockTasksRepository implements TasksRepository {
  final List<TaskItem> db = [];
  int _nextNotificationId = 1000;

  @override
  Future<List<TaskItem>> getTasks() async => List.from(db);

  @override
  Future<List<TaskItem>> getTasksForDate(DateTime date) async =>
      db.where((t) => t.dueDate.day == date.day).toList();

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
  Future<List<TaskItem>> getTrashTasks() async =>
      db.where((t) => t.isDeleted).toList();

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
  Future<int> generateUniqueNotificationId() async => _nextNotificationId++;
}

class TestClock implements ClockService {
  final DateTime _fixed;
  TestClock(this._fixed);
  @override
  DateTime get now => _fixed;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestHarness({
    required TasksProvider provider,
    required Widget child,
    bool isDark = false,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<TasksProvider>.value(value: provider),
      ],
      child: MaterialApp(
        theme: isDark ? ThemeData.dark() : ThemeData.light(),
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  group('Task Editor Undo Button Regression Tests', () {
    late MockTasksRepository repo;
    late TaskEngine engine;
    late TasksProvider provider;
    final fixedNow = DateTime(2026, 8, 31, 14, 0);

    setUp(() async {
      repo = MockTasksRepository();
      final clock = TestClock(fixedNow);
      final scheduler = LoggingReminderScheduler();
      engine = TaskEngine(repository: repo, clock: clock, scheduler: scheduler);
      await engine.initialize();
      provider = TasksProvider(engine: engine);
    });

    testWidgets('Test A — Incomplete task: circle is empty and inactive',
        (WidgetTester tester) async {
      final task = await engine.createTask(
        title: 'Review Documentation',
        dueDate: fixedNow,
        priority: 'high',
      );

      await tester.pumpWidget(
        buildTestHarness(
          provider: provider,
          child: CreateTaskBottomSheet(
            initialDate: task.dueDate,
            taskToEdit: task,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify no Undo icon is rendered in the header
      expect(find.byIcon(Icons.undo_rounded), findsNothing);
      expect(find.text('Undo'), findsNothing);

      // Verify circle has no accessible Undo semantics
      expect(find.bySemanticsLabel('Undo task completion'), findsNothing);

      // Verify rendering editor did not mutate task completion state
      expect(provider.tasks.first.completed, isFalse);
      expect(provider.tasks.first.status, TaskStatus.waiting);
    });

    testWidgets('Test B — Completed task: Undo icon visible with accessible label',
        (WidgetTester tester) async {
      final task = await engine.createTask(
        title: 'Audit Security Policies',
        dueDate: fixedNow,
        priority: 'medium',
      );
      await provider.completeTaskOccurrence(task.id, fixedNow);

      final completedTask = provider.tasks.first;
      expect(completedTask.completed, isTrue);

      await tester.pumpWidget(
        buildTestHarness(
          provider: provider,
          child: CreateTaskBottomSheet(
            initialDate: completedTask.dueDate,
            taskToEdit: completedTask,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Undo icon is visible in the header
      expect(find.byIcon(Icons.undo_rounded), findsOneWidget);

      // Verify accessible label exists
      expect(find.bySemanticsLabel('Undo task completion'), findsOneWidget);
    });

    testWidgets('Test C — Undo action: tapping circle reopens task and updates UI',
        (WidgetTester tester) async {
      final task = await engine.createTask(
        title: 'Finish Quarter Report',
        dueDate: fixedNow,
        priority: 'high',
      );
      await provider.completeTaskOccurrence(task.id, fixedNow);
      final completedTask = provider.tasks.first;
      expect(completedTask.completed, isTrue);

      await tester.pumpWidget(
        buildTestHarness(
          provider: provider,
          child: CreateTaskBottomSheet(
            initialDate: completedTask.dueDate,
            taskToEdit: completedTask,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the Undo button
      final undoFinder = find.bySemanticsLabel('Undo task completion');
      expect(undoFinder, findsOneWidget);
      await tester.tap(undoFinder);
      await tester.pumpAndSettle();

      // Verify task in provider and repo is now incomplete
      expect(provider.tasks.first.completed, isFalse);
      expect(provider.tasks.first.status, TaskStatus.waiting);
      expect(repo.db.first.completed, isFalse);
      expect(repo.db.first.status, TaskStatus.waiting);

      // Verify UI has reverted: Undo icon is no longer present
      expect(find.byIcon(Icons.undo_rounded), findsNothing);
      expect(find.bySemanticsLabel('Undo task completion'), findsNothing);
    });

    testWidgets('Test D — Task identity: targets edited task and updates when switching tasks',
        (WidgetTester tester) async {
      final task1 = await engine.createTask(
        title: 'Task 1 Active',
        dueDate: fixedNow,
        priority: 'low',
      );
      final task2 = await engine.createTask(
        title: 'Task 2 Completed',
        dueDate: fixedNow,
        priority: 'high',
      );
      await provider.completeTaskOccurrence(task2.id, fixedNow);

      // Render with completed task2
      await tester.pumpWidget(
        buildTestHarness(
          provider: provider,
          child: CreateTaskBottomSheet(
            initialDate: task2.dueDate,
            taskToEdit: provider.tasks.firstWhere((t) => t.id == task2.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.undo_rounded), findsOneWidget);

      // Re-render harness switching to incomplete task1
      await tester.pumpWidget(
        buildTestHarness(
          provider: provider,
          child: CreateTaskBottomSheet(
            initialDate: task1.dueDate,
            taskToEdit: provider.tasks.firstWhere((t) => t.id == task1.id),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Undo icon disappeared for task 1
      expect(find.byIcon(Icons.undo_rounded), findsNothing);
    });

    testWidgets('Test E — Lifecycle preservation: clearing completedAt and restoring reminders',
        (WidgetTester tester) async {
      // 1. Non-recurring task with reminder
      final reminderTime = fixedNow.add(const Duration(hours: 2));
      final task = await engine.createTask(
        title: 'Doctor Appointment',
        dueDate: fixedNow,
        reminderTime: reminderTime,
        reminderMode: ReminderMode.notification,
      );
      await engine.toggleCompletion(task.id);

      final completedTask = provider.tasks.first;
      expect(completedTask.completed, isTrue);
      expect(completedTask.completedAt, isNotNull);

      await tester.pumpWidget(
        buildTestHarness(
          provider: provider,
          child: CreateTaskBottomSheet(
            initialDate: completedTask.dueDate,
            taskToEdit: completedTask,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Undo task completion'));
      await tester.pumpAndSettle();

      final reopened = provider.tasks.first;
      expect(reopened.completed, isFalse);
      expect(reopened.status, TaskStatus.waiting);
      expect(reopened.completedAt, isNull, reason: 'completedAt must be cleared on reopen (BUG-004)');
      expect(reopened.reminderMode, ReminderMode.notification, reason: 'Reminder mode preserved (BUG-007)');

      // 2. Recurring task occurrence reopening
      final recurringTask = await engine.createTask(
        title: 'Daily Standup',
        dueDate: fixedNow,
        isRecurring: true,
        recurrence: const RecurrenceRule(type: RecurrenceType.daily, interval: 1),
      );
      await provider.completeTaskOccurrence(recurringTask.id, fixedNow);
      expect(provider.tasks.firstWhere((t) => t.id == recurringTask.id).completedDates, contains('2026-08-31'));

      final completedOccurrence = provider.tasks.firstWhere((t) => t.id == recurringTask.id);

      await tester.pumpWidget(
        buildTestHarness(
          provider: provider,
          child: CreateTaskBottomSheet(
            initialDate: fixedNow,
            taskToEdit: completedOccurrence,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Undo task completion'));
      await tester.pumpAndSettle();

      final reopenedRecurring = provider.tasks.firstWhere((t) => t.id == recurringTask.id);
      expect(reopenedRecurring.completedDates, isNot(contains('2026-08-31')));
    });
  });
}
