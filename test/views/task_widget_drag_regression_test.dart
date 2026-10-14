import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quick_notes/models/task_item.dart';
import 'package:quick_notes/models/task_status.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/providers/tasks_provider.dart';
import 'package:quick_notes/providers/settings_provider.dart';
import 'package:quick_notes/repositories/tasks_repository.dart';
import 'package:quick_notes/services/task_engine.dart';
import 'package:quick_notes/services/clock_service.dart';
import 'package:quick_notes/services/reminder_scheduler.dart';
import 'package:quick_notes/services/session_manager.dart';
import 'package:quick_notes/views/screens/home_screen.dart';
import 'package:quick_notes/views/widgets/task_widget.dart';
import 'package:quick_notes/views/widgets/tactile_button.dart';

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
  Future<int> trashTask(String id) async => 1;

  @override
  Future<int> restoreTask(String id) async => 1;

  @override
  Future<int> deleteTask(String id) async {
    db.removeWhere((t) => t.id == id);
    return 1;
  }

  @override
  Future<int> emptyTrash() async => 1;

  @override
  Future<int> generateUniqueNotificationId() async => _nextNotificationId++;
}

Widget _wrapTaskWidget({required Widget child}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 322.0,
          child: child,
        ),
      ),
    ),
  );
}

Widget _buildHomeScreen({
  required TasksProvider tasksProvider,
  required NotesProvider notesProvider,
  required SettingsProvider settingsProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<TasksProvider>.value(value: tasksProvider),
      ChangeNotifierProvider<NotesProvider>.value(value: notesProvider),
      ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
    ],
    child: const MaterialApp(
      home: HomeScreen(
        initialShowTasks: true,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({'active_user_id': 'test-user'});
    await SessionManager().init();
  });

  group('Phase 1 — TaskWidget & HomeScreen "Drag to Mark done" Regression Tests', () {
    testWidgets('Test 1 — Successful drag completion triggers onComplete and completes task on HomeScreen',
        (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = MockTasksRepository();
      const clock = SystemClock();
      final scheduler = LoggingReminderScheduler();
      final engine = TaskEngine(repository: repo, clock: clock, scheduler: scheduler);
      await engine.initialize();

      final now = DateTime.now();
      final todayDue = DateTime(now.year, now.month, now.day, 16, 0);

      final task = await engine.createTask(
        title: 'Drag Success Task',
        dueDate: todayDue,
        priority: 'high',
        reminderTime: todayDue.add(const Duration(hours: 1)),
        reminderEnabled: true,
      );

      final tasksProvider = TasksProvider(engine: engine);
      await tasksProvider.loadTasks();

      final notesProvider = NotesProvider();
      final settingsProvider = SettingsProvider();

      await tester.pumpWidget(
        _buildHomeScreen(
          tasksProvider: tasksProvider,
          notesProvider: notesProvider,
          settingsProvider: settingsProvider,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Drag Success Task'), findsOneWidget);
      expect(find.text('Drag to mark done'), findsOneWidget);

      final dragTarget = find.text('Drag to mark done');
      final center = tester.getCenter(dragTarget);

      // Drag across completion threshold
      final gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(30.0, 0.0));
      await tester.pump();
      await gesture.moveBy(const Offset(220.0, 0.0));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      final completedTask = tasksProvider.tasks.firstWhere((t) => t.id == task.id);
      expect(completedTask.completed, isTrue);
      expect(completedTask.status, equals(TaskStatus.completed));
    });

    testWidgets('Test 2 — Incomplete drag releases before threshold without completing and resets resting state',
        (tester) async {
      String? completedId;
      final task = TaskItem(
        id: 'partial-task-1',
        title: 'Incomplete Drag Task',
        dueDate: DateTime.now().add(const Duration(hours: 3)),
        priority: 'Medium',
        status: TaskStatus.waiting,
        completed: false,
      );

      await tester.pumpWidget(_wrapTaskWidget(
        child: TaskWidget(
          tasks: [task],
          onComplete: (id) => completedId = id,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Drag to mark done'), findsOneWidget);
      final dragTarget = find.text('Drag to mark done');

      // Drag only 60px (threshold is 90% = ~185px)
      final gesture = await tester.startGesture(tester.getCenter(dragTarget));
      await gesture.moveBy(const Offset(30.0, 0.0));
      await tester.pump();
      await gesture.moveBy(const Offset(30.0, 0.0));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Must NOT have completed
      expect(completedId, isNull);
      expect(find.text('Drag to mark done'), findsOneWidget);
    });

    testWidgets('Test 3 — State and persistence: Completed task persists in SQLite repository',
        (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = MockTasksRepository();
      const clock = SystemClock();
      final scheduler = LoggingReminderScheduler();
      final engine = TaskEngine(repository: repo, clock: clock, scheduler: scheduler);
      await engine.initialize();

      final now = DateTime.now();
      final todayDue = DateTime(now.year, now.month, now.day, 17, 0);

      final task = await engine.createTask(
        title: 'Persistent Task',
        dueDate: todayDue,
        priority: 'low',
      );

      final tasksProvider = TasksProvider(engine: engine);
      await tasksProvider.loadTasks();

      final notesProvider = NotesProvider();
      final settingsProvider = SettingsProvider();

      await tester.pumpWidget(
        _buildHomeScreen(
          tasksProvider: tasksProvider,
          notesProvider: notesProvider,
          settingsProvider: settingsProvider,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      final dragTarget = find.text('Drag to mark done');
      final gesture = await tester.startGesture(tester.getCenter(dragTarget));
      await gesture.moveBy(const Offset(30.0, 0.0));
      await tester.pump();
      await gesture.moveBy(const Offset(220.0, 0.0));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      // Check in repository directly
      final repoTasks = await repo.getTasks();
      final persistedTask = repoTasks.firstWhere((t) => t.id == task.id);
      expect(persistedTask.completed, isTrue);
      expect(persistedTask.status, equals(TaskStatus.completed));
    });

    testWidgets('Test 4 — Existing interactions: Card swipe, edit, and undo callbacks remain intact',
        (tester) async {
      TaskItem? editedTask;
      TaskItem? undidTask;

      final task1 = TaskItem(
        id: 'deck-1',
        title: 'Deck Task 1',
        dueDate: DateTime.now().add(const Duration(hours: 1)),
        priority: 'high',
        status: TaskStatus.waiting,
        completed: false,
      );

      final task2 = TaskItem(
        id: 'deck-2',
        title: 'Deck Task 2',
        dueDate: DateTime.now().add(const Duration(hours: 2)),
        priority: 'low',
        status: TaskStatus.waiting,
        completed: false,
      );

      await tester.pumpWidget(_wrapTaskWidget(
        child: TaskWidget(
          tasks: [task1, task2],
          onEdit: (t) => editedTask = t,
          onUndo: (t) => undidTask = t,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Deck Task 1'), findsOneWidget);

      // 1. Verify Edit button
      final editButton = find.byType(TactileButton);
      expect(editButton, findsOneWidget);
      await tester.tap(editButton);
      await tester.pumpAndSettle();
      expect(editedTask?.id, equals('deck-1'));

      // 2. Verify Card swipe away (> 120px) cycles to next card
      final cardCenter = tester.getCenter(find.text('Deck Task 1'));
      final swipeGesture = await tester.startGesture(cardCenter);
      await swipeGesture.moveBy(const Offset(180.0, 0.0));
      await tester.pump();
      await swipeGesture.up();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('Deck Task 2'), findsOneWidget);

      // 3. Verify Undo button on completed task
      final completedTask = task1.copyWith(completed: true, status: TaskStatus.completed);
      await tester.pumpWidget(_wrapTaskWidget(
        child: TaskWidget(
          tasks: [completedTask],
          onUndo: (t) => undidTask = t,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Undo'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(undidTask?.id, equals('deck-1'));
    });
  });
}
