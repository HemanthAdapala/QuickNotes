import 'dart:async';
import 'package:flutter/material.dart';
import '../models/task_item.dart';
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

  Future<void> deleteTask(String id) async {
    await _ensureEngineReady();
    try {
      final String realId = (id.contains('_') && !id.startsWith('task_')) ? id.split('_')[0] : id;
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
      final String realId = (id.contains('_') && !id.startsWith('task_')) ? id.split('_')[0] : id;
      final task = _engine.tasks.firstWhere(
        (t) => t.id == realId || t.id == id || id.startsWith(t.id),
        orElse: () => _engine.tasks.first,
      );
      if (!task.isRecurring && task.recurrence == null && task.repeatRule == RepeatRule.none) {
        await _engine.deleteTask(task.id);
      } else {
        await _engine.toggleCompletion(task.id);
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
      final task = _engine.tasks.firstWhere(
        (t) => t.id == id,
        orElse: () => _engine.tasks.firstWhere((t) => t.id.startsWith(id)),
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

    final result = <TaskItem>[];

    for (final t in _engine.tasks) {
      final bool isRecurring = t.isRecurring || t.recurrence != null || t.repeatRule != RepeatRule.none;

      if (!isRecurring) {
        if (!t.completed) {
          final localDue = t.dueDate.toLocal();
          if (filter == 'All' || localDue.isBefore(maxHorizon) || localDue.isAtSameMomentAs(maxHorizon)) {
            result.add(t);
          }
        }
        continue;
      }

      // For recurring tasks, find the FIRST uncompleted date starting from Today up to maxHorizon
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _eventSubscription?.cancel();
    _foregroundActionSubscription?.cancel();
    super.dispose();
  }
}
