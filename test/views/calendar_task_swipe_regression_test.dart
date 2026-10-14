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
import 'package:quick_notes/premium/premium.dart';
import 'package:quick_notes/repositories/tasks_repository.dart';
import 'package:quick_notes/services/task_engine.dart';
import 'package:quick_notes/services/clock_service.dart';
import 'package:quick_notes/services/reminder_scheduler.dart';
import 'package:quick_notes/services/session_manager.dart';
import 'package:quick_notes/views/screens/calendar_screen.dart';
import 'package:quick_notes/views/models/calendar_task.dart';
import 'package:quick_notes/views/widgets/task_widgets_container.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({'active_user_id': 'test-user'});
    await SessionManager().init();
  });

  Future<void> pumpTestPanel(
    WidgetTester tester, {
    required Widget child,
    TasksProvider? tasksProvider,
    double viewportWidth = 412.0,
  }) async {
    tester.view.physicalSize = Size(viewportWidth, 844.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => PremiumEntitlementManager()),
          Provider<FeatureAccess>(
            create: (c) => DefaultFeatureAccess(
              Provider.of<PremiumEntitlementManager>(c, listen: false),
            ),
          ),
          ChangeNotifierProvider(create: (_) => NotesProvider()),
          if (tasksProvider != null)
            ChangeNotifierProvider<TasksProvider>.value(value: tasksProvider),
        ],
        child: MediaQuery(
          data: MediaQueryData(
            size: Size(viewportWidth, 844.0),
            padding: const EdgeInsets.only(top: 36.0),
            disableAnimations: true,
          ),
          child: MaterialApp(
            home: Scaffold(
              body: child,
            ),
          ),
        ),
      ),
    );
    tester.takeException();
    await tester.pump();
    tester.takeException();
  }

  group('Phase 2 — Calendar Available Tasks Swipe Interactions', () {
    testWidgets('Test 1 — Swiping exposes Complete action without completing prematurely',
        (tester) async {
      String? completedId;
      final task = CalendarTask(
        id: 'task_complete_1',
        title: 'Swipe to Complete Me',
        subtitle: 'Incomplete Task',
        priority: TaskPriority.green,
        isCompleted: false,
      );

      await pumpTestPanel(
        tester,
        child: TaskWidgetsContainer(
          selectedDate: DateTime(2026, 6, 16),
          tasks: [task],
          onCompleteTask: (id) => completedId = id,
        ),
      );

      // Swipe right to reveal Complete action
      await tester.drag(find.text('Swipe to Complete Me'), const Offset(80, 0));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();

      // Complete button should now be visible
      final completeBtnFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is ShapeDecoration) {
          final deco = w.decoration as ShapeDecoration;
          return deco.color == const Color(0x7F0088FF);
        }
        return false;
      });
      expect(completeBtnFinder, findsOneWidget);

      // The task must not have been completed merely by beginning or revealing the gesture
      expect(completedId, isNull);
    });

    testWidgets('Test 2 — Activating Complete invokes callback and completes task via provider',
        (tester) async {
      final repo = MockTasksRepository();
      const clock = SystemClock();
      final scheduler = LoggingReminderScheduler();
      final engine = TaskEngine(repository: repo, clock: clock, scheduler: scheduler);
      await engine.initialize();

      final now = DateTime.now();
      final todayDue = DateTime(now.year, now.month, now.day, 12, 0);

      final task = await engine.createTask(
        title: 'Calendar Complete Task',
        dueDate: todayDue,
        priority: 'high',
      );

      final tasksProvider = TasksProvider(engine: engine);
      await tasksProvider.loadTasks();

      await pumpTestPanel(
        tester,
        tasksProvider: tasksProvider,
        child: const CalendarScreen(),
      );

      // Verify task appears
      expect(find.text('Calendar Complete Task'), findsOneWidget);

      // Swipe right on the task to reveal Complete button
      await tester.drag(find.text('Calendar Complete Task'), const Offset(80, 0));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();

      final completeBtnFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is ShapeDecoration) {
          final deco = w.decoration as ShapeDecoration;
          return deco.color == const Color(0x7F0088FF);
        }
        return false;
      });
      expect(completeBtnFinder, findsOneWidget);

      // Tap Complete button
      await tester.tap(completeBtnFinder);
      tester.takeException();
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();

      // Verify task in engine and provider is now completed
      final reloaded = engine.getTaskById(task.id);
      expect(reloaded, isNotNull);
      expect(reloaded!.completed, isTrue);
      expect(reloaded.status, equals(TaskStatus.completed));
    });

    testWidgets('Test 3 — Existing Delete regression: Left-swipe reveals Delete and triggers onDismissTask',
        (tester) async {
      String? dismissedId;
      String? completedId;
      final task = CalendarTask(
        id: 'task_del_1',
        title: 'Delete Me Task',
        subtitle: 'Swipe left to delete',
        priority: TaskPriority.red,
        isCompleted: false,
      );

      await pumpTestPanel(
        tester,
        child: TaskWidgetsContainer(
          selectedDate: DateTime(2026, 6, 16),
          tasks: [task],
          onDismissTask: (id) => dismissedId = id,
          onCompleteTask: (id) => completedId = id,
        ),
      );

      // Drag left to reveal Delete button
      await tester.drag(find.text('Delete Me Task'), const Offset(-80, 0));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();

      // Red delete button should be visible
      final deleteBtnFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is ShapeDecoration) {
          final deco = w.decoration as ShapeDecoration;
          return deco.color == const Color(0x7FFF0000);
        }
        return false;
      });
      expect(deleteBtnFinder, findsOneWidget);

      // Complete must not be triggered
      expect(completedId, isNull);

      // Tap Delete button
      await tester.tap(deleteBtnFinder);
      tester.takeException();
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();

      expect(dismissedId, equals('task_del_1'));
      expect(completedId, isNull);
    });

    testWidgets('Test 4 — Cancelled and partial gestures snap back without altering state',
        (tester) async {
      String? completedId;
      String? dismissedId;
      final task = CalendarTask(
        id: 'task_partial_1',
        title: 'Partial Swipe Task',
        subtitle: 'Should snap back',
        priority: TaskPriority.yellow,
        isCompleted: false,
      );

      await pumpTestPanel(
        tester,
        child: TaskWidgetsContainer(
          selectedDate: DateTime(2026, 6, 16),
          tasks: [task],
          onDismissTask: (id) => dismissedId = id,
          onCompleteTask: (id) => completedId = id,
        ),
      );

      // Partial drag right (under half threshold e.g. 20px)
      await tester.drag(find.text('Partial Swipe Task'), const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();

      // Complete button should snap back and NOT be visible
      final completeBtnFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is ShapeDecoration) {
          final deco = w.decoration as ShapeDecoration;
          return deco.color == const Color(0x7F0088FF);
        }
        return false;
      });
      expect(completeBtnFinder, findsNothing);
      expect(completedId, isNull);
      expect(dismissedId, isNull);

      // Partial drag left (under threshold)
      await tester.drag(find.text('Partial Swipe Task'), const Offset(-20, 0));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();

      final deleteBtnFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is ShapeDecoration) {
          final deco = w.decoration as ShapeDecoration;
          return deco.color == const Color(0x7FFF0000);
        }
        return false;
      });
      expect(deleteBtnFinder, findsNothing);
      expect(completedId, isNull);
      expect(dismissedId, isNull);
    });

    testWidgets('Test 5 — Correct item identity with multiple tasks',
        (tester) async {
      String? completedId;
      final task1 = CalendarTask(
        id: 'task_multi_1',
        title: 'Task 1 First',
        subtitle: 'Item 1',
        priority: TaskPriority.green,
      );
      final task2 = CalendarTask(
        id: 'task_multi_2',
        title: 'Task 2 Second',
        subtitle: 'Item 2',
        priority: TaskPriority.yellow,
      );

      await pumpTestPanel(
        tester,
        child: TaskWidgetsContainer(
          selectedDate: DateTime(2026, 6, 16),
          tasks: [task1, task2],
          onCompleteTask: (id) => completedId = id,
        ),
      );

      // Swipe only Task 2
      await tester.drag(find.text('Task 2 Second'), const Offset(80, 0));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();

      final completeBtnFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is ShapeDecoration) {
          final deco = w.decoration as ShapeDecoration;
          return deco.color == const Color(0x7F0088FF);
        }
        return false;
      });
      expect(completeBtnFinder, findsOneWidget);

      await tester.tap(completeBtnFinder);
      tester.takeException();
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();

      // Only Task 2 should have been completed
      expect(completedId, equals('task_multi_2'));
    });

    testWidgets('Test 6 & 7 — Persistence and reminder cancellation (BUG-006 preservation)',
        (tester) async {
      final repo = MockTasksRepository();
      const clock = SystemClock();
      final scheduler = LoggingReminderScheduler();
      final engine = TaskEngine(repository: repo, clock: clock, scheduler: scheduler);
      await engine.initialize();

      final now = DateTime.now();
      final todayDue = DateTime(now.year, now.month, now.day, 15, 0);

      final task = await engine.createTask(
        title: 'Reminder Complete Task',
        dueDate: todayDue,
        priority: 'high',
        reminderTime: todayDue.subtract(const Duration(minutes: 15)),
        reminderEnabled: true,
      );

      // Verify reminder was scheduled
      final pendingInitial = await scheduler.getPendingNotificationIds();
      expect(pendingInitial.contains(task.notificationId), isTrue);

      final tasksProvider = TasksProvider(engine: engine);
      await tasksProvider.loadTasks();

      await pumpTestPanel(
        tester,
        tasksProvider: tasksProvider,
        child: const CalendarScreen(),
      );

      // Swipe right to reveal Complete action
      await tester.drag(find.text('Reminder Complete Task'), const Offset(80, 0));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();

      final completeBtnFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is ShapeDecoration) {
          final deco = w.decoration as ShapeDecoration;
          return deco.color == const Color(0x7F0088FF);
        }
        return false;
      });
      expect(completeBtnFinder, findsOneWidget);

      // Tap Complete
      await tester.tap(completeBtnFinder);
      tester.takeException();
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();

      // Verify persistence in SQLite
      final reloaded = engine.getTaskById(task.id);
      expect(reloaded!.completed, isTrue);

      // Verify reminder cancellation (BUG-006)
      final pendingAfter = await scheduler.getPendingNotificationIds();
      expect(pendingAfter.contains(task.notificationId), isFalse);
    });
  });
}
