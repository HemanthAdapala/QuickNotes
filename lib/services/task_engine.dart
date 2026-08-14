import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/task_item.dart';
import '../models/reminder_mode.dart';
import '../models/task_status.dart';
import '../models/repeat_rule.dart';
import '../models/recurrence_rule.dart';
import '../models/task_engine_state.dart';
import '../models/task_event.dart';
import '../repositories/tasks_repository.dart';
import 'clock_service.dart';
import 'reminder_scheduler.dart';
import 'recurrence_calculator.dart';

class EngineNotReadyException implements Exception {
  final String message;
  EngineNotReadyException([this.message = 'TaskEngine is not in ready state.']);

  @override
  String toString() => 'EngineNotReadyException: $message';
}

class InvalidStateTransitionException implements Exception {
  final TaskStatus from;
  final TaskStatus to;
  InvalidStateTransitionException(this.from, this.to);

  @override
  String toString() => 'InvalidStateTransitionException: Cannot transition from $from to $to';
}

class TaskEngine {
  final TasksRepository _repository;
  final ClockService _clock;
  final ReminderScheduler _scheduler;
  final Uuid _uuid = const Uuid();

  TaskEngineState _state = TaskEngineState.idle;
  List<TaskItem> _tasks = [];
  final StreamController<TaskEvent> _eventController = StreamController<TaskEvent>.broadcast();

  TaskEngine({
    TasksRepository? repository,
    ClockService? clock,
    ReminderScheduler? scheduler,
  })  : _repository = repository ?? SqliteTasksRepository(),
        _clock = clock ?? const SystemClock(),
        _scheduler = scheduler ?? LoggingReminderScheduler();

  TaskEngineState get state => _state;
  ClockService get clock => _clock;
  ReminderScheduler get scheduler => _scheduler;
  Stream<TaskEvent> get eventStream => _eventController.stream;
  List<TaskItem> get tasks => List.unmodifiable(_tasks);

  void clearLocalState() {
    _tasks.clear();
    _state = TaskEngineState.idle;
  }

  TaskItem? getTaskById(String id) {
    for (final task in _tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  void _checkReady() {
    if (_state != TaskEngineState.ready) {
      throw EngineNotReadyException('TaskEngine state is $_state. Call initialize() first.');
    }
  }

  /// Single entry point for engine startup
  Future<void> initialize() async {
    if (_state == TaskEngineState.initializing || _state == TaskEngineState.ready) {
      return;
    }

    _state = TaskEngineState.initializing;

    try {
      await _scheduler.initialize();
      _tasks = await _repository.getTasks();
      await reconcileTaskStates();

      final now = _clock.now;

      // Startup Reconciliation: Generate missing next occurrence for completed recurring tasks
      for (final task in List<TaskItem>.from(_tasks)) {
        if (task.isRecurring && task.completed) {
          await _generateNextOccurrence(task, now);
        }
      }

      // Reschedule active future reminders on startup/reboot
      for (final task in _tasks) {
        if (!task.completed &&
            (task.status == TaskStatus.waiting || task.status == TaskStatus.scheduled) &&
            task.reminderEnabled &&
            task.reminderTime != null &&
            task.reminderTime!.isAfter(now)) {
          await _scheduler.scheduleReminder(task);
        }
      }

      _state = TaskEngineState.ready;
    } catch (e) {
      debugPrint('Error initializing TaskEngine: $e');
      _state = TaskEngineState.idle;
      rethrow;
    }
  }

  /// Reloads tasks from SQLite repository and reconciles state (e.g. when app resumes)
  Future<void> reloadFromRepository() async {
    _tasks = await _repository.getTasks();
    await reconcileTaskStates();
    final now = _clock.now;

    for (final task in List<TaskItem>.from(_tasks)) {
      if (task.isRecurring && task.completed) {
        await _generateNextOccurrence(task, now);
      }
    }
  }

  /// Scans and reconciles task states based on clock, due dates, and reminders
  Future<List<TaskItem>> reconcileTaskStates() async {
    final now = _clock.now;
    final List<TaskItem> updatedList = [];

    for (int i = 0; i < _tasks.length; i++) {
      final task = _tasks[i];

      if (task.completed || task.status == TaskStatus.archived || task.status == TaskStatus.cancelled) {
        continue;
      }

      // Check if task reminder or due date has passed without completion
      final isReminderMissed = task.reminderTime != null && now.isAfter(task.reminderTime!);
      final isDueDateMissed = now.isAfter(task.dueDate);

      if ((isReminderMissed || isDueDateMissed) && task.status != TaskStatus.missed) {
        final missedTask = task.copyWith(
          status: TaskStatus.missed,
          updatedAt: now,
        );
        _tasks[i] = missedTask;
        await _repository.updateTask(missedTask);
        updatedList.add(missedTask);
        if (kDebugMode) {
          debugPrint('TASK ENGINE [Reconcile]: Task "${missedTask.title}" (ID: ${missedTask.id}) transitioned to TaskStatus.missed.');
        }
      }
    }

    if (updatedList.isNotEmpty) {
      _eventController.add(TasksReconciledEvent(
        eventId: _uuid.v4(),
        reconciledTasks: updatedList,
        timestamp: now,
      ));
    }

    return updatedList;
  }

  /// Creates a new task and schedules reminder if enabled.
  /// Supports passing a full [TaskItem] object (`task: item`) OR named parameters (`title: '...'`).
  Future<TaskItem> createTask({
    TaskItem? task,
    String? title,
    String description = '',
    String? folderId,
    String? categoryId,
    DateTime? dueDate,
    DateTime? startTime,
    DateTime? endTime,
    String priority = 'None',
    DateTime? reminderTime,
    bool reminderEnabled = true,
    ReminderMode reminderMode = ReminderMode.alarm,
    RepeatRule repeatRule = RepeatRule.none,
    bool isRecurring = false,
    RecurrenceRule? recurrence,
    String? recurringSeriesId,
    String? timezone,
  }) async {
    _checkReady();
    final now = _clock.now;

    final TaskItem newTask;
    if (task != null) {
      final seriesId = task.isRecurring
          ? (task.recurringSeriesId ?? _uuid.v4())
          : task.recurringSeriesId;
      newTask = task.copyWith(
        createdAt: now,
        updatedAt: now,
        recurringSeriesId: seriesId,
      );
    } else {
      final String resolvedTitle = title ?? '';
      if (resolvedTitle.isEmpty && task == null) {
        throw ArgumentError('createTask requires a TaskItem or title string.');
      }
      final notificationId = await _repository.generateUniqueNotificationId();
      final isReminderActive = reminderEnabled && reminderMode != ReminderMode.off && reminderTime != null;
      final initialStatus = isReminderActive ? TaskStatus.scheduled : TaskStatus.waiting;
      final seriesId = (isRecurring || recurrence != null)
          ? (recurringSeriesId ?? _uuid.v4())
          : recurringSeriesId;

      newTask = TaskItem(
        id: _uuid.v4(),
        title: resolvedTitle,
        description: description,
        folderId: folderId,
        categoryId: categoryId,
        dueDate: (dueDate ?? now).toUtc(),
        startTime: startTime?.toUtc(),
        endTime: endTime?.toUtc(),
        priority: priority,
        status: initialStatus,
        createdAt: now,
        updatedAt: now,
        reminderEnabled: isReminderActive,
        reminderMode: isReminderActive ? reminderMode : ReminderMode.off,
        reminderTime: isReminderActive ? reminderTime.toUtc() : null,
        notificationId: notificationId,
        repeatRule: repeatRule,
        isRecurring: isRecurring || recurrence != null,
        recurrence: recurrence,
        recurringSeriesId: seriesId,
        timezone: timezone,
      );
    }

    _tasks.insert(0, newTask);
    await _repository.insertTask(newTask);

    if (newTask.reminderEnabled && newTask.reminderTime != null && newTask.reminderTime!.isAfter(now)) {
      await _scheduler.scheduleReminder(newTask);
    }

    _eventController.add(TaskCreatedEvent(
      eventId: _uuid.v4(),
      task: newTask,
      timestamp: now,
    ));

    return newTask;
  }

  Future<TaskItem> updateTask(TaskItem updatedTask) async {
    _checkReady();

    final index = _tasks.indexWhere((t) => t.id == updatedTask.id);
    if (index == -1) {
      throw ArgumentError('Task with ID ${updatedTask.id} not found.');
    }

    final oldTask = _tasks[index];

    // Validate state machine transition
    if (!oldTask.status.canTransitionTo(updatedTask.status)) {
      throw InvalidStateTransitionException(oldTask.status, updatedTask.status);
    }

    final now = _clock.now;
    final finalUpdatedTask = updatedTask.copyWith(updatedAt: now);

    _tasks[index] = finalUpdatedTask;
    await _repository.updateTask(finalUpdatedTask);

    // Reschedule reminder if reminderTime, dueDate, reminderEnabled, or reminderMode changed
    final timeChanged = oldTask.reminderTime != finalUpdatedTask.reminderTime ||
        oldTask.dueDate != finalUpdatedTask.dueDate ||
        oldTask.reminderEnabled != finalUpdatedTask.reminderEnabled ||
        oldTask.reminderMode != finalUpdatedTask.reminderMode;

    if (timeChanged) {
      await _scheduler.cancelReminder(oldTask.notificationId);
      if (finalUpdatedTask.reminderEnabled && finalUpdatedTask.reminderTime != null && !finalUpdatedTask.completed) {
        await _scheduler.scheduleReminder(finalUpdatedTask);
      }
    }

    _eventController.add(TaskUpdatedEvent(
      eventId: _uuid.v4(),
      oldTask: oldTask,
      newTask: finalUpdatedTask,
      timestamp: now,
    ));

    return finalUpdatedTask;
  }

  Future<TaskItem> toggleCompletion(String id) async {
    _checkReady();

    final index = _tasks.indexWhere((t) => t.id == id);
    if (index == -1) {
      throw ArgumentError('Task with ID $id not found.');
    }

    final oldTask = _tasks[index];
    final now = _clock.now;

    final TaskStatus newStatus = oldTask.completed ? TaskStatus.waiting : TaskStatus.completed;
    final DateTime? newCompletedAt = newStatus == TaskStatus.completed ? now : null;

    final seriesId = oldTask.isRecurring ? (oldTask.recurringSeriesId ?? _uuid.v4()) : oldTask.recurringSeriesId;

    final updatedTask = oldTask.copyWith(
      status: newStatus,
      completedAt: newCompletedAt,
      updatedAt: now,
      recurringSeriesId: seriesId,
    );

    _tasks[index] = updatedTask;
    await _repository.updateTask(updatedTask);

    if (updatedTask.completed) {
      await _scheduler.cancelReminder(updatedTask.notificationId);
    } else if (updatedTask.reminderEnabled && updatedTask.reminderTime != null && updatedTask.reminderTime!.isAfter(now)) {
      await _scheduler.scheduleReminder(updatedTask);
    }

    _eventController.add(TaskCompletedEvent(
      eventId: _uuid.v4(),
      task: updatedTask,
      timestamp: now,
    ));

    return updatedTask;
  }

  /// Generates the next occurrence for a recurring task if not already generated
  Future<TaskItem?> _generateNextOccurrence(TaskItem completedTask, DateTime now) async {
    if (!completedTask.isRecurring || completedTask.recurrence == null) {
      return null;
    }

    final seriesId = completedTask.recurringSeriesId ?? _uuid.v4();

    // Idempotency check: Ensure no active non-completed task exists in this recurring series
    final hasActiveChild = _tasks.any((t) =>
        !t.completed &&
        t.id != completedTask.id &&
        t.recurringSeriesId == seriesId);

    if (hasActiveChild) {
      return null;
    }

    final seriesCount = _tasks.where((t) => t.recurringSeriesId == seriesId).length;

    final nextDueDate = RecurrenceCalculator.nextOccurrence(
      completedTask.dueDate,
      completedTask.recurrence!,
      after: now,
      currentOccurrenceCount: seriesCount,
    );

    if (nextDueDate == null) {
      return null;
    }

    DateTime? nextReminderTime;
    if (completedTask.reminderTime != null) {
      nextReminderTime = RecurrenceCalculator.nextOccurrence(
        completedTask.reminderTime!,
        completedTask.recurrence!,
        after: now,
        currentOccurrenceCount: seriesCount,
      );
    }

    final String nextId = _uuid.v4();
    final int nextNotificationId = _uuid.v4().hashCode.abs() % 2147483647;

    final nextTask = completedTask.copyWith(
      id: nextId,
      status: TaskStatus.waiting,
      completed: false,
      createdAt: now,
      updatedAt: now,
      completedAt: null,
      dueDate: nextDueDate,
      reminderTime: nextReminderTime,
      reminderEnabled: nextReminderTime != null,
      notificationId: nextNotificationId,
      recurringSeriesId: seriesId,
    );

    _tasks.insert(0, nextTask);
    await _repository.insertTask(nextTask);

    if (nextTask.reminderEnabled && nextTask.reminderTime != null && nextTask.reminderTime!.isAfter(now)) {
      await _scheduler.scheduleReminder(nextTask);
    }

    _eventController.add(TaskCreatedEvent(
      eventId: _uuid.v4(),
      task: nextTask,
      timestamp: now,
    ));

    return nextTask;
  }

  Future<void> deleteTask(String id) async {
    _checkReady();

    final index = _tasks.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final removedTask = _tasks.removeAt(index);
    final now = _clock.now;

    await _repository.deleteTask(id);
    await _scheduler.cancelReminder(removedTask.notificationId);

    _eventController.add(TaskDeletedEvent(
      eventId: _uuid.v4(),
      taskId: id,
      notificationId: removedTask.notificationId,
      timestamp: now,
    ));
  }

  Future<TaskItem> snoozeTask(String id, Duration snoozeDuration) async {
    _checkReady();

    final index = _tasks.indexWhere((t) => t.id == id);
    if (index == -1) {
      throw ArgumentError('Task with ID $id not found.');
    }

    final oldTask = _tasks[index];
    final now = _clock.now;
    final newReminderTime = now.add(snoozeDuration);

    final snoozedTask = oldTask.copyWith(
      status: TaskStatus.waiting,
      reminderEnabled: true,
      reminderTime: newReminderTime,
      updatedAt: now,
    );

    _tasks[index] = snoozedTask;
    await _repository.updateTask(snoozedTask);

    await _scheduler.cancelReminder(oldTask.notificationId);
    await _scheduler.scheduleReminder(snoozedTask);

    _eventController.add(ReminderSnoozedEvent(
      eventId: _uuid.v4(),
      task: snoozedTask,
      newReminderTime: newReminderTime,
      timestamp: now,
    ));

    return snoozedTask;
  }

  Future<void> dispose() async {
    _state = TaskEngineState.disposed;
    await _eventController.close();
  }
}
