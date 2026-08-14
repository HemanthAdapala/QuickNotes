import 'dart:async';
import 'package:flutter/material.dart';
import '../models/task_item.dart';
import '../models/reminder_mode.dart';
import '../models/task_status.dart';
import '../models/notification_action.dart';
import '../services/notification_action_handler.dart';
import '../models/repeat_rule.dart';
import '../models/recurrence_rule.dart';
import '../models/task_engine_state.dart';
import '../services/task_engine.dart';
import '../repositories/tasks_repository.dart';

class TasksProvider with ChangeNotifier, WidgetsBindingObserver {
  final TaskEngine _engine;
  StreamSubscription? _eventSubscription;
  Future<void>? _initFuture;
  bool _isLoading = false;

  TasksProvider({TaskEngine? engine, TasksRepository? tasksRepository})
      : _engine = engine ?? TaskEngine(repository: tasksRepository) {
    WidgetsBinding.instance.addObserver(this);
    _initFuture = _initEngine();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refresh();
    }
  }

  Future<void> refresh() async {
    await _ensureEngineReady();
    await _engine.reloadFromRepository();
    notifyListeners();
  }

  void clearLocalState() {
    _engine.clearLocalState();
    notifyListeners();
  }

  TaskEngine get engine => _engine;
  List<TaskItem> get tasks => _engine.tasks;
  List<TaskItem> get activeTasks => _engine.tasks.where((t) => !t.completed).toList();
  List<TaskItem> get completedTasks => _engine.tasks.where((t) => t.completed).toList();
  List<TaskItem> get missedTasks => _engine.tasks.where((t) => t.isMissed).toList();
  bool get isLoading => _isLoading;

  String? _highlightedTaskId;
  StreamSubscription? _foregroundActionSubscription;

  String? get highlightedTaskId => _highlightedTaskId;

  void setHighlightedTask(String? id) {
    _highlightedTaskId = id;
    notifyListeners();
  }

  Future<void> _initEngine() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _engine.initialize();
      _eventSubscription = _engine.eventStream.listen((_) {
        notifyListeners();
      });

      _foregroundActionSubscription ??= NotificationActionHandler.foregroundStream.listen((payload) {
        if (payload.action == NotificationAction.done) {
          toggleTaskCompletion(payload.taskId);
        } else if (payload.action == NotificationAction.snooze) {
          snoozeTask(payload.taskId, const Duration(minutes: 15));
        } else {
          setHighlightedTask(payload.taskId);
        }
      });

      final pendingPayload = NotificationActionHandler.consumeLastLaunchedPayload();
      if (pendingPayload != null) {
        if (pendingPayload.action == NotificationAction.done) {
          toggleTaskCompletion(pendingPayload.taskId);
        } else if (pendingPayload.action == NotificationAction.snooze) {
          snoozeTask(pendingPayload.taskId, const Duration(minutes: 15));
        } else {
          setHighlightedTask(pendingPayload.taskId);
        }
      }
    } catch (e) {
      debugPrint('Error initializing TaskEngine in TasksProvider: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _ensureEngineReady() async {
    if (_engine.state != TaskEngineState.ready) {
      await (_initFuture ??= _initEngine());
    }
  }

  Future<void> loadTasks() async {
    if (_engine.state != TaskEngineState.ready) {
      await _ensureEngineReady();
    } else {
      await _engine.reconcileTaskStates();
      notifyListeners();
    }
  }

  Future<void> addTask({
    required String title,
    String description = '',
    String? folderId,
    String? categoryId,
    required DateTime dueDate,
    DateTime? startTime,
    DateTime? endTime,
    required String priority,
    DateTime? reminderTime,
    bool reminderEnabled = true,
    ReminderMode reminderMode = ReminderMode.alarm,
    RepeatRule repeatRule = RepeatRule.none,
    bool isRecurring = false,
    RecurrenceRule? recurrence,
    String? timezone,
  }) async {
    await _ensureEngineReady();
    try {
      await _engine.createTask(
        title: title,
        description: description,
        folderId: folderId,
        categoryId: categoryId,
        dueDate: dueDate,
        startTime: startTime,
        endTime: endTime,
        priority: priority,
        reminderTime: reminderTime,
        reminderEnabled: reminderEnabled,
        reminderMode: reminderMode,
        repeatRule: repeatRule,
        isRecurring: isRecurring || recurrence != null,
        recurrence: recurrence,
        timezone: timezone,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding task in TasksProvider: $e');
      rethrow;
    }
  }

  Future<void> toggleTaskCompletion(String id) async {
    await toggleTaskCompletionOnDate(id, DateTime.now());
  }

  Future<void> updateTask(TaskItem updatedTask) async {
    await _ensureEngineReady();
    try {
      await _engine.updateTask(updatedTask);
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating task in TasksProvider: $e');
      rethrow;
    }
  }

  String _getBaseId(String id) {
    final parts = id.split('_');
    if (parts.length >= 3 && parts[0] == 'task') {
      return '${parts[0]}_${parts[1]}';
    }
    if (parts.length >= 2 && parts[0] != 'task') {
      return parts[0];
    }
    return id;
  }

  Future<void> deleteTask(String id) async {
    await _ensureEngineReady();
    try {
      final String realId = _getBaseId(id);
      await _engine.deleteTask(realId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting task in TasksProvider: $e');
      rethrow;
    }
  }

  Future<void> snoozeTask(String id, Duration duration) async {
    await _ensureEngineReady();
    try {
      await _engine.snoozeTask(id, duration);
      notifyListeners();
    } catch (e) {
      debugPrint('Error snoozing task in TasksProvider: $e');
      rethrow;
    }
  }

  Future<void> deleteTaskOccurrence(String id, DateTime date) async {
    await _ensureEngineReady();
    try {
      final String realId = _getBaseId(id);
      final task = _engine.tasks.firstWhere(
        (t) => t.id == realId || t.id == id || id.startsWith(t.id),
        orElse: () => _engine.tasks.first,
      );
      if (!task.isRecurring && task.recurrence == null && task.repeatRule == RepeatRule.none) {
        await _engine.deleteTask(realId);
      } else {
        DateTime nextDue = task.dueDate;
        final type = task.recurrence?.type;
        final interval = task.recurrence?.interval ?? 1;

        if (type == RecurrenceType.daily || task.repeatRule == RepeatRule.daily) {
          nextDue = nextDue.add(Duration(days: 1 * interval));
        } else if (type == RecurrenceType.weekly || task.repeatRule == RepeatRule.weekly) {
          nextDue = nextDue.add(Duration(days: 7 * interval));
        } else if (type == RecurrenceType.monthly || task.repeatRule == RepeatRule.monthly) {
          nextDue = DateTime(nextDue.year, nextDue.month + interval, nextDue.day, nextDue.hour, nextDue.minute);
        } else if (type == RecurrenceType.yearly || task.repeatRule == RepeatRule.yearly) {
          nextDue = DateTime(nextDue.year + interval, nextDue.month, nextDue.day, nextDue.hour, nextDue.minute);
        } else {
          nextDue = nextDue.add(const Duration(days: 1));
        }

        final updated = task.copyWith(
          dueDate: nextDue,
          updatedAt: DateTime.now(),
        );
        await updateTask(updated);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting task occurrence in TasksProvider: $e');
      rethrow;
    }
  }

  Future<void> toggleTaskCompletionOnDate(String id, DateTime targetDate) async {
    await _ensureEngineReady();
    try {
      final String realId = _getBaseId(id);
      final task = _engine.tasks.firstWhere(
        (t) => t.id == realId || t.id == id || id.startsWith(t.id),
        orElse: () => _engine.tasks.firstWhere((t) => t.id.startsWith(realId)),
      );

      final bool isRecurring = task.isRecurring || task.recurrence != null || task.repeatRule != RepeatRule.none;

      if (!isRecurring) {
        await _engine.toggleCompletion(task.id);
      } else {
        final dateStr = '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';
        final newDates = List<String>.from(task.completedDates);
        if (newDates.contains(dateStr)) {
          newDates.remove(dateStr);
        } else {
          newDates.add(dateStr);
        }

        final updated = task.copyWith(
          completedDates: newDates,
          updatedAt: DateTime.now(),
        );
        await updateTask(updated);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling task completion on date in TasksProvider: $e');
      rethrow;
    }
  }

  List<TaskItem> getTasksForDate(DateTime date) {
    final target = DateTime(date.year, date.month, date.day);
    final result = <TaskItem>[];

    for (final t in _engine.tasks) {
      final localDue = t.dueDate.toLocal();
      final taskStart = DateTime(localDue.year, localDue.month, localDue.day);

      if (!t.isRecurring && t.recurrence == null && t.repeatRule == RepeatRule.none) {
        if (taskStart.isAtSameMomentAs(target)) {
          result.add(t);
        }
        continue;
      }

      // Recurring task projection logic (up to 6 months horizon)
      if (target.isBefore(taskStart)) continue;
      final daysDiff = target.difference(taskStart).inDays;
      if (daysDiff > 180) continue; // Maximum 6 months horizon

      final type = t.recurrence?.type;
      final interval = t.recurrence?.interval ?? 1;

      bool matches = false;
      if (type == RecurrenceType.daily || t.repeatRule == RepeatRule.daily) {
        matches = (daysDiff % interval) == 0;
      } else if (type == RecurrenceType.weekly || t.repeatRule == RepeatRule.weekly) {
        matches = (daysDiff % (7 * interval)) == 0;
      } else if (type == RecurrenceType.monthly || t.repeatRule == RepeatRule.monthly) {
        final monthsDiff = (target.year - taskStart.year) * 12 + (target.month - taskStart.month);
        final targetLastDay = DateTime(target.year, target.month + 1, 0).day;
        final expectedDay = taskStart.day > targetLastDay ? targetLastDay : taskStart.day;
        matches = (monthsDiff % interval == 0) && (target.day == expectedDay);
      } else if (type == RecurrenceType.yearly || t.repeatRule == RepeatRule.yearly) {
        final yearsDiff = target.year - taskStart.year;
        final targetLastDay = DateTime(target.year, target.month + 1, 0).day;
        final expectedDay = taskStart.day > targetLastDay ? targetLastDay : taskStart.day;
        matches = (yearsDiff % interval == 0) && (target.month == taskStart.month) && (target.day == expectedDay);
      }

      if (matches) {
        final targetDateStr = '${target.year}-${target.month.toString().padLeft(2, '0')}-${target.day.toString().padLeft(2, '0')}';
        final bool isCompletedOnThisDay = t.completedDates.contains(targetDateStr);

        if (taskStart.isAtSameMomentAs(target)) {
          result.add(t.copyWith(
            status: isCompletedOnThisDay ? TaskStatus.completed : TaskStatus.waiting,
          ));
        } else {
          result.add(t.copyWith(
            dueDate: DateTime(target.year, target.month, target.day, localDue.hour, localDue.minute),
            status: isCompletedOnThisDay ? TaskStatus.completed : TaskStatus.waiting,
          ));
        }
      }
    }

    return result;
  }

  List<TaskItem> getUncompletedTasksForFilter(String filter) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    final daysUntilEndOfWeek = 7 - now.weekday;
    final weekEnd = DateTime(now.year, now.month, now.day + daysUntilEndOfWeek, 23, 59, 59, 999);

    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0).day;
    final monthEnd = DateTime(now.year, now.month, lastDayOfMonth, 23, 59, 59, 999);

    final result = <TaskItem>[];

    for (final t in _engine.tasks) {
      final bool isRecurring = t.isRecurring || t.recurrence != null || t.repeatRule != RepeatRule.none;

      if (!isRecurring) {
        if (!t.completed) {
          final localDue = t.dueDate.toLocal();
          switch (filter) {
            case 'Missed':
              if (localDue.isBefore(today)) {
                result.add(t);
              }
              break;
            case 'Today':
              if ((localDue.isAfter(today.subtract(const Duration(milliseconds: 1))) || localDue.isAtSameMomentAs(today)) &&
                  (localDue.isBefore(todayEnd) || localDue.isAtSameMomentAs(todayEnd))) {
                result.add(t);
              }
              break;
            case 'Weekly':
              if (localDue.isBefore(weekEnd) || localDue.isAtSameMomentAs(weekEnd)) {
                result.add(t);
              }
              break;
            case 'Monthly':
              if (localDue.isBefore(monthEnd) || localDue.isAtSameMomentAs(monthEnd)) {
                result.add(t);
              }
              break;
            case 'All':
            default:
              result.add(t);
              break;
          }
        }
        continue;
      }

      // Recurring Tasks logic
      if (filter == 'Missed') {
        final localDue = t.dueDate.toLocal();
        if (localDue.isBefore(today) && !t.completed) {
          result.add(t);
        }
        continue;
      }

      final DateTime maxHorizon;
      switch (filter) {
        case 'Today':
          maxHorizon = todayEnd;
          break;
        case 'Weekly':
          maxHorizon = weekEnd;
          break;
        case 'Monthly':
          maxHorizon = monthEnd;
          break;
        case 'All':
        default:
          maxHorizon = today.add(const Duration(days: 180));
          break;
      }

      final localDue = t.dueDate.toLocal();
      final taskStart = DateTime(localDue.year, localDue.month, localDue.day);
      final type = t.recurrence?.type;
      final interval = t.recurrence?.interval ?? 1;

      final scanStart = today.isAfter(taskStart) ? today : taskStart;
      int daysOffset = scanStart.difference(taskStart).inDays;

      for (int i = 0; i <= 180; i++) {
        final currentDay = taskStart.add(Duration(days: daysOffset + i));
        final currentDayEnd = DateTime(currentDay.year, currentDay.month, currentDay.day, 23, 59, 59, 999);

        if (currentDayEnd.isAfter(maxHorizon) && filter != 'All') break;

        final daysDiff = currentDay.difference(taskStart).inDays;
        bool matches = false;

        if (type == RecurrenceType.daily || t.repeatRule == RepeatRule.daily) {
          matches = (daysDiff % interval) == 0;
        } else if (type == RecurrenceType.weekly || t.repeatRule == RepeatRule.weekly) {
          matches = (daysDiff % (7 * interval)) == 0;
        } else if (type == RecurrenceType.monthly || t.repeatRule == RepeatRule.monthly) {
          final monthsDiff = (currentDay.year - taskStart.year) * 12 + (currentDay.month - taskStart.month);
          final targetLastDay = DateTime(currentDay.year, currentDay.month + 1, 0).day;
          final expectedDay = taskStart.day > targetLastDay ? targetLastDay : taskStart.day;
          matches = (monthsDiff % interval == 0) && (currentDay.day == expectedDay);
        } else if (type == RecurrenceType.yearly || t.repeatRule == RepeatRule.yearly) {
          final yearsDiff = currentDay.year - taskStart.year;
          final targetLastDay = DateTime(currentDay.year, currentDay.month + 1, 0).day;
          final expectedDay = taskStart.day > targetLastDay ? targetLastDay : taskStart.day;
          matches = (yearsDiff % interval == 0) && (currentDay.month == taskStart.month) && (currentDay.day == expectedDay);
        }

        if (matches) {
          final dateStr = '${currentDay.year}-${currentDay.month.toString().padLeft(2, '0')}-${currentDay.day.toString().padLeft(2, '0')}';
          final isCompletedOnDay = t.completedDates.contains(dateStr);

          if (!isCompletedOnDay) {
            final projectedDue = DateTime(currentDay.year, currentDay.month, currentDay.day, localDue.hour, localDue.minute);
            result.add(t.copyWith(
              dueDate: projectedDue,
              status: TaskStatus.waiting,
            ));
            break; // Stop scanning further days for this task
          }
        }
      }
    }

    return result;
  }

  /// Seeding helper for QA Performance Stress Verification (Test 12.1)
  Future<void> seedTestTasks([int count = 55]) async {
    await _ensureEngineReady();
    final now = DateTime.now();

    final titles = [
      '⚡ Finalize Q3 System Architecture & Roadmap',
      '🛒 Buy Grocery Essentials & Weekly Supplies',
      '🏋️ Morning High-Intensity Interval Workout',
      '📞 Call Client Re: Mobile UI Design Review',
      '🚀 Launch Sprint 14 Production Deployment',
      '📖 Read Chapter 5 of Distributed Systems Patterns',
      '🎨 Refactor Liquid Glass Container Animations',
      '💼 Update Resume & Portfolio Highlights',
      '☕ Team Coffee Sync & Standup Alignment',
      '🧼 Clean Workspace & Organize Tech Accessories',
      '✈️ Book Flight Tickets & Hotel Reservations',
      '📊 Audit Monthly Subscription Expenses',
    ];

    final priorities = ['High', 'Medium', 'Low', 'None'];

    for (int i = 0; i < count; i++) {
      final titleIndex = i % titles.length;
      final priorityIndex = i % priorities.length;
      // Spread due dates across yesterday (-1), today (0), tomorrow (1), and next week (2..5)
      final dayOffset = (i % 7) - 1;
      final hourOffset = (8 + (i * 2)) % 24;

      final dueDate = DateTime(
        now.year,
        now.month,
        now.day + dayOffset,
        hourOffset,
        (i * 15) % 60,
      );

      await _engine.createTask(
        title: '${titles[titleIndex]} #$i',
        description: 'Automated QA stress test task #$i generated for Test 12.1 rendering performance benchmark.',
        dueDate: dueDate,
        priority: priorities[priorityIndex],
        reminderMode: ReminderMode.off,
      );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _eventSubscription?.cancel();
    _foregroundActionSubscription?.cancel();
    super.dispose();
  }
}
