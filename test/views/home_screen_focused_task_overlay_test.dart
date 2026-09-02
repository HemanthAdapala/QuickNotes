import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quick_notes/models/task_item.dart';
import 'package:quick_notes/models/task_status.dart';
import 'package:quick_notes/models/recurrence_rule.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/providers/tasks_provider.dart';
import 'package:quick_notes/repositories/tasks_repository.dart';
import 'package:quick_notes/services/task_engine.dart';
import 'package:quick_notes/services/clock_service.dart';
import 'package:quick_notes/services/reminder_scheduler.dart';
import 'package:quick_notes/views/screens/home_screen.dart';
import 'package:quick_notes/views/widgets/task_widget.dart';

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
  Future<int> generateUniqueNotificationId() async {
    return _nextNotificationId++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;

    late final MessageHandler fontHandler;
    fontHandler = (ByteData? message) async {
      if (message == null) return null;
      final Uint8List list = message.buffer.asUint8List(message.offsetInBytes, message.lengthInBytes);
      final String key = utf8.decode(list);
      if (key.startsWith('google_fonts/')) {
        return ByteData(16);
      }
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null);
      try {
        return await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .send('flutter/assets', message);
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler('flutter/assets', fontHandler);
      }
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', fontHandler);

    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => '.',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('es.antonborri.home_widget'),
      (MethodCall methodCall) async => null,
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestableHomeScreen({
    required TasksProvider tasksProvider,
    required NotesProvider notesProvider,
    String? focusedTaskId,
    bool initialShowTasks = false,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<NotesProvider>.value(value: notesProvider),
        ChangeNotifierProvider<TasksProvider>.value(value: tasksProvider),
      ],
      child: MaterialApp(
        home: HomeScreen(
          initialShowTasks: initialShowTasks,
          focusedTaskId: focusedTaskId,
        ),
      ),
    );
  }

  group('HomeScreen Phase T13 Focused Task Overlay Widget Tests', () {
    testWidgets('TEST 1 — Active task displays focused overlay when focusedTaskId is passed', (tester) async {
      final repo = MockTasksRepository();
      final clock = SystemClock();
      final scheduler = LoggingReminderScheduler();
      final engine = TaskEngine(repository: repo, clock: clock, scheduler: scheduler);
      await engine.initialize();

      final task = await engine.createTask(
        title: 'Review Quarterly Budget',
        dueDate: DateTime.now(),
        priority: 'High',
      );

      final tasksProvider = TasksProvider(engine: engine);
      final notesProvider = NotesProvider();

      await tester.pumpWidget(
        buildTestableHomeScreen(
          tasksProvider: tasksProvider,
          notesProvider: notesProvider,
          focusedTaskId: task.id,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      // Focused overlay with the task's title should be present
      expect(find.byKey(ValueKey('focused_task_overlay_${task.id}')), findsOneWidget);
      expect(find.byKey(ValueKey('focused_task_widget_${task.id}')), findsOneWidget);
      expect(find.text('Review Quarterly Budget'), findsWidgets);
    });

    testWidgets('TEST 2 — Deleted task does NOT display focused overlay', (tester) async {
      final repo = MockTasksRepository();
      final clock = SystemClock();
      final scheduler = LoggingReminderScheduler();
      final engine = TaskEngine(repository: repo, clock: clock, scheduler: scheduler);
      await engine.initialize();

      final task = await engine.createTask(
        title: 'Deleted Task Item',
        dueDate: DateTime.now(),
        priority: 'Medium',
      );
      // Mark deleted in repository
      final idx = repo.db.indexWhere((t) => t.id == task.id);
      repo.db[idx] = repo.db[idx].copyWith(isDeleted: true, deletedAt: DateTime.now());
      await engine.reloadFromRepository();

      final tasksProvider = TasksProvider(engine: engine);
      final notesProvider = NotesProvider();

      await tester.pumpWidget(
        buildTestableHomeScreen(
          tasksProvider: tasksProvider,
          notesProvider: notesProvider,
          focusedTaskId: task.id,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      // Focused overlay should NOT be rendered
      expect(find.byKey(ValueKey('focused_task_overlay_${task.id}')), findsNothing);
    });

    testWidgets('TEST 3 — Archived task does NOT display focused overlay', (tester) async {
      final repo = MockTasksRepository();
      final clock = SystemClock();
      final scheduler = LoggingReminderScheduler();
      final engine = TaskEngine(repository: repo, clock: clock, scheduler: scheduler);
      await engine.initialize();

      final task = await engine.createTask(
        title: 'Archived Task Item',
        dueDate: DateTime.now(),
        priority: 'Low',
      );
      // Manually set status to archived in repo
      final idx = repo.db.indexWhere((t) => t.id == task.id);
      repo.db[idx] = repo.db[idx].copyWith(status: TaskStatus.archived);
      await engine.reloadFromRepository();

      final tasksProvider = TasksProvider(engine: engine);
      final notesProvider = NotesProvider();

      await tester.pumpWidget(
        buildTestableHomeScreen(
          tasksProvider: tasksProvider,
          notesProvider: notesProvider,
          focusedTaskId: task.id,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(ValueKey('focused_task_overlay_${task.id}')), findsNothing);
    });

    testWidgets('TEST 4 — Tapping outside (backdrop) dismisses focused overlay', (tester) async {
      final repo = MockTasksRepository();
      final clock = SystemClock();
      final scheduler = LoggingReminderScheduler();
      final engine = TaskEngine(repository: repo, clock: clock, scheduler: scheduler);
      await engine.initialize();

      final task = await engine.createTask(
        title: 'Dismissable Task Item',
        dueDate: DateTime.now(),
        priority: 'High',
      );

      final tasksProvider = TasksProvider(engine: engine);
      final notesProvider = NotesProvider();

      await tester.pumpWidget(
        buildTestableHomeScreen(
          tasksProvider: tasksProvider,
          notesProvider: notesProvider,
          focusedTaskId: task.id,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(ValueKey('focused_task_overlay_${task.id}')), findsOneWidget);

      // Tap at the top-left area (outside centered card)
      await tester.tapAt(const Offset(20, 40));
      await tester.pumpAndSettle();

      // Overlay is now dismissed
      expect(find.byKey(ValueKey('focused_task_overlay_${task.id}')), findsNothing);
    });

    testWidgets('TEST 5 — Missing / non-existent task ID falls back cleanly without overlay', (tester) async {
      final repo = MockTasksRepository();
      final clock = SystemClock();
      final scheduler = LoggingReminderScheduler();
      final engine = TaskEngine(repository: repo, clock: clock, scheduler: scheduler);
      await engine.initialize();

      final tasksProvider = TasksProvider(engine: engine);
      final notesProvider = NotesProvider();

      await tester.pumpWidget(
        buildTestableHomeScreen(
          tasksProvider: tasksProvider,
          notesProvider: notesProvider,
          focusedTaskId: 'non-existent-task-id',
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('focused_task_overlay_non-existent-task-id')), findsNothing);
    });
  });

  group('Phase T15H — Canonical Recurrence Projection & Explicit Completion Tests', () {
    testWidgets('T15H-1: Recurring overlay uses canonical projected occurrence when today is completed', (tester) async {
      final repo = MockTasksRepository();
      final clock = SystemClock();
      final scheduler = LoggingReminderScheduler();
      final engine = TaskEngine(repository: repo, clock: clock, scheduler: scheduler);
      await engine.initialize();

      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day, 18, 5);
      final todayDateStr =
          '${todayDate.year}-${todayDate.month.toString().padLeft(2, '0')}-${todayDate.day.toString().padLeft(2, '0')}';

      final task = await engine.createTask(
        title: 'Daily Meditation',
        dueDate: todayDate,
        isRecurring: true,
        recurrence: const RecurrenceRule(type: RecurrenceType.daily, interval: 1),
        priority: 'High',
      );

      // Complete today's occurrence
      final updatedTask = task.copyWith(completedDates: [todayDateStr]);
      await engine.updateTask(updatedTask);

      final tasksProvider = TasksProvider(engine: engine);
      final notesProvider = NotesProvider();

      await tester.pumpWidget(
        buildTestableHomeScreen(
          tasksProvider: tasksProvider,
          notesProvider: notesProvider,
          focusedTaskId: task.id,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      final expectedDateStr = DateFormat('EEE, d MMMM').format(todayDate.toLocal());

      // Overlay should project today's date with completed state
      expect(find.text(expectedDateStr), findsWidgets);
    });

    testWidgets('T15H-2 & T15H-4: Overlay completion targets today date and does not toggle off', (tester) async {
      final repo = MockTasksRepository();
      final clock = SystemClock();
      final scheduler = LoggingReminderScheduler();
      final engine = TaskEngine(repository: repo, clock: clock, scheduler: scheduler);
      await engine.initialize();

      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day, 18, 5);
      final todayDateStr =
          '${todayDate.year}-${todayDate.month.toString().padLeft(2, '0')}-${todayDate.day.toString().padLeft(2, '0')}';

      final task = await engine.createTask(
        title: 'Daily Workout',
        dueDate: todayDate,
        isRecurring: true,
        recurrence: const RecurrenceRule(type: RecurrenceType.daily, interval: 1),
        priority: 'Medium',
      );

      final tasksProvider = TasksProvider(engine: engine);
      final notesProvider = NotesProvider();

      await tester.pumpWidget(
        buildTestableHomeScreen(
          tasksProvider: tasksProvider,
          notesProvider: notesProvider,
          focusedTaskId: task.id,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      // Find the TaskWidget and trigger completion
      final taskWidgetFinder = find.byKey(ValueKey('focused_task_widget_${task.id}'));
      expect(taskWidgetFinder, findsOneWidget);
      final taskWidget = tester.widget<TaskWidget>(taskWidgetFinder);
      taskWidget.onComplete?.call(task.id);
      await tester.pumpAndSettle();

      // Check that completedDates has todayDateStr
      final afterComplete = tasksProvider.tasks.firstWhere((t) => t.id == task.id);
      expect(afterComplete.completedDates, contains(todayDateStr));

      // T15H-4: Trigger completion a second time -> should NOT toggle off / remove today
      await tasksProvider.completeTaskOccurrence(task.id, todayDate);
      final afterSecondComplete = tasksProvider.tasks.firstWhere((t) => t.id == task.id);
      expect(afterSecondComplete.completedDates, contains(todayDateStr));
    });

    testWidgets('T15H-5 & T15H-6: Full recurring progression advances forward (today Completed -> rolls over on next day)', (tester) async {
      final repo = MockTasksRepository();
      final clock = SystemClock();
      final scheduler = LoggingReminderScheduler();
      final engine = TaskEngine(repository: repo, clock: clock, scheduler: scheduler);
      await engine.initialize();

      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day, 18, 5);
      final todayDateStr =
          '${todayDate.year}-${todayDate.month.toString().padLeft(2, '0')}-${todayDate.day.toString().padLeft(2, '0')}';
      final tomorrow = todayDate.add(const Duration(days: 1));
      final tomorrowDateStr =
          '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';

      final task = await engine.createTask(
        title: 'Daily Progress Check',
        dueDate: todayDate,
        isRecurring: true,
        recurrence: const RecurrenceRule(type: RecurrenceType.daily, interval: 1),
      );

      final tasksProvider = TasksProvider(engine: engine);
      final notesProvider = NotesProvider();

      // 1. Complete Today
      await tasksProvider.completeTaskOccurrence(task.id, todayDate);
      expect(tasksProvider.tasks.first.completedDates, [todayDateStr]);

      // 2. Complete Tomorrow
      await tasksProvider.completeTaskOccurrence(task.id, tomorrow);
      expect(tasksProvider.tasks.first.completedDates, [todayDateStr, tomorrowDateStr]);

      // 3. Open Overlay on today -> Shows today
      await tester.pumpWidget(
        buildTestableHomeScreen(
          tasksProvider: tasksProvider,
          notesProvider: notesProvider,
          focusedTaskId: task.id,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      final todayStr = DateFormat('EEE, d MMMM').format(todayDate.toLocal());
      expect(find.text(todayStr), findsWidgets);
    });

    testWidgets('T15H-7: Non-recurring task completes normally and idempotently', (tester) async {
      final repo = MockTasksRepository();
      final clock = SystemClock();
      final scheduler = LoggingReminderScheduler();
      final engine = TaskEngine(repository: repo, clock: clock, scheduler: scheduler);
      await engine.initialize();

      final task = await engine.createTask(
        title: 'Non-Recurring Task Item',
        dueDate: DateTime.now(),
        priority: 'Low',
      );

      final tasksProvider = TasksProvider(engine: engine);
      final notesProvider = NotesProvider();

      await tester.pumpWidget(
        buildTestableHomeScreen(
          tasksProvider: tasksProvider,
          notesProvider: notesProvider,
          focusedTaskId: task.id,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      final taskWidgetFinder = find.byKey(ValueKey('focused_task_widget_${task.id}'));
      final taskWidget = tester.widget<TaskWidget>(taskWidgetFinder);
      taskWidget.onComplete?.call(task.id);
      await tester.pumpAndSettle();

      final completedTask = tasksProvider.tasks.firstWhere((t) => t.id == task.id);
      expect(completedTask.completed, isTrue);
      expect(completedTask.status, TaskStatus.completed);

      // Second completion call maintains completed state
      await tasksProvider.completeTaskOccurrence(task.id, task.dueDate);
      final stillCompleted = tasksProvider.tasks.firstWhere((t) => t.id == task.id);
      expect(stillCompleted.completed, isTrue);
    });

    testWidgets('T15I-1: Completed recurring task renders "Done for today" and tapping "Undo" restores pending slider', (tester) async {
      final repo = MockTasksRepository();
      final clock = SystemClock();
      final scheduler = LoggingReminderScheduler();
      final engine = TaskEngine(repository: repo, clock: clock, scheduler: scheduler);
      await engine.initialize();

      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day, 18, 5);
      final todayDateStr =
          '${todayDate.year}-${todayDate.month.toString().padLeft(2, '0')}-${todayDate.day.toString().padLeft(2, '0')}';

      final task = await engine.createTask(
        title: 'Daily Meditation',
        dueDate: todayDate,
        isRecurring: true,
        recurrence: const RecurrenceRule(type: RecurrenceType.daily, interval: 1),
        priority: 'High',
      );

      // Complete today
      final updatedTask = task.copyWith(completedDates: [todayDateStr]);
      await engine.updateTask(updatedTask);

      final tasksProvider = TasksProvider(engine: engine);
      final notesProvider = NotesProvider();

      await tester.pumpWidget(
        buildTestableHomeScreen(
          tasksProvider: tasksProvider,
          notesProvider: notesProvider,
          focusedTaskId: task.id,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      final overlayFinder = find.byKey(ValueKey('focused_task_overlay_${task.id}'));

      // 1. Assert "Done for today" and "Undo" are visible, "Drag to mark done" is NOT visible in overlay
      expect(find.descendant(of: overlayFinder, matching: find.text("Done for today")), findsOneWidget);
      expect(find.descendant(of: overlayFinder, matching: find.text("Undo")), findsOneWidget);
      expect(find.descendant(of: overlayFinder, matching: find.text("Drag to mark done")), findsNothing);

      // 2. Tap "Undo"
      await tester.tap(find.descendant(of: overlayFinder, matching: find.text("Undo")));
      await tester.pumpAndSettle();

      // 3. Verify task is uncompleted in TasksProvider
      final uncompletedTask = tasksProvider.tasks.firstWhere((t) => t.id == task.id);
      expect(uncompletedTask.completedDates, isEmpty);

      // 4. Verify overlay refreshed to show "Drag to mark done" slider
      expect(find.descendant(of: overlayFinder, matching: find.text("Drag to mark done")), findsOneWidget);
      expect(find.descendant(of: overlayFinder, matching: find.text("Done for today")), findsNothing);
    });

    testWidgets('T15I-2: Completed non-recurring task renders "Completed" and tapping "Undo" restores pending slider', (tester) async {
      final repo = MockTasksRepository();
      final clock = SystemClock();
      final scheduler = LoggingReminderScheduler();
      final engine = TaskEngine(repository: repo, clock: clock, scheduler: scheduler);
      await engine.initialize();

      final task = await engine.createTask(
        title: 'Submit Tax Forms',
        dueDate: DateTime.now().add(const Duration(hours: 3)),
        priority: 'High',
      );

      // Mark completed
      final completedTask = task.copyWith(
        completed: true,
        status: TaskStatus.completed,
      );
      await engine.updateTask(completedTask);

      final tasksProvider = TasksProvider(engine: engine);
      final notesProvider = NotesProvider();

      await tester.pumpWidget(
        buildTestableHomeScreen(
          tasksProvider: tasksProvider,
          notesProvider: notesProvider,
          focusedTaskId: task.id,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      final overlayFinder = find.byKey(ValueKey('focused_task_overlay_${task.id}'));

      // 1. Assert "Completed" and "Undo" are visible in overlay
      expect(find.descendant(of: overlayFinder, matching: find.text("Completed")), findsOneWidget);
      expect(find.descendant(of: overlayFinder, matching: find.text("Undo")), findsOneWidget);
      expect(find.descendant(of: overlayFinder, matching: find.text("Drag to mark done")), findsNothing);

      // 2. Tap "Undo"
      await tester.tap(find.descendant(of: overlayFinder, matching: find.text("Undo")));
      await tester.pumpAndSettle();

      // 3. Verify task is uncompleted
      final uncompleted = tasksProvider.tasks.firstWhere((t) => t.id == task.id);
      expect(uncompleted.completed, isFalse);
      expect(uncompleted.status, TaskStatus.waiting);

      // 4. Verify overlay refreshed to show "Drag to mark done" slider
      expect(find.descendant(of: overlayFinder, matching: find.text("Drag to mark done")), findsOneWidget);
      expect(find.descendant(of: overlayFinder, matching: find.text("Done for today")), findsNothing);
    });

    testWidgets('T15J-1: Backgrounding/pausing app dismisses focused overlay so launcher resume is clean', (tester) async {
      final repo = MockTasksRepository();
      final clock = SystemClock();
      final scheduler = LoggingReminderScheduler();
      final engine = TaskEngine(repository: repo, clock: clock, scheduler: scheduler);
      await engine.initialize();

      final task = await engine.createTask(
        title: 'Background Test Task',
        dueDate: DateTime.now(),
        priority: 'High',
      );

      final tasksProvider = TasksProvider(engine: engine);
      final notesProvider = NotesProvider();

      await tester.pumpWidget(
        buildTestableHomeScreen(
          tasksProvider: tasksProvider,
          notesProvider: notesProvider,
          focusedTaskId: task.id,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      final overlayFinder = find.byKey(ValueKey('focused_task_overlay_${task.id}'));
      expect(overlayFinder, findsOneWidget);

      // Simulate user backgrounding app / pressing Home button
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();

      // Verify overlay is dismissed and not rendered
      expect(find.byKey(ValueKey('focused_task_overlay_${task.id}')), findsNothing);

      // Simulate user resuming app from Launcher Icon
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      // Verify still no overlay on normal resume
      expect(find.byKey(ValueKey('focused_task_overlay_${task.id}')), findsNothing);
    });
  });
}
