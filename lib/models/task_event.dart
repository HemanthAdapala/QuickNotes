import 'task_item.dart';

/// Sealed hierarchy for all events emitted by TaskEngine
sealed class TaskEvent {
  final String eventId;
  final String taskId;
  final DateTime timestamp;

  TaskEvent({
    required this.eventId,
    required this.taskId,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class TaskCreatedEvent extends TaskEvent {
  final TaskItem task;

  TaskCreatedEvent({
    required String eventId,
    required this.task,
    DateTime? timestamp,
  }) : super(eventId: eventId, taskId: task.id, timestamp: timestamp);
}

class TaskUpdatedEvent extends TaskEvent {
  final TaskItem oldTask;
  final TaskItem newTask;

  TaskUpdatedEvent({
    required String eventId,
    required this.oldTask,
    required this.newTask,
    DateTime? timestamp,
  }) : super(eventId: eventId, taskId: newTask.id, timestamp: timestamp);
}

class TaskCompletedEvent extends TaskEvent {
  final TaskItem task;

  TaskCompletedEvent({
    required String eventId,
    required this.task,
    DateTime? timestamp,
  }) : super(eventId: eventId, taskId: task.id, timestamp: timestamp);
}

class ReminderFiredEvent extends TaskEvent {
  final TaskItem task;

  ReminderFiredEvent({
    required String eventId,
    required this.task,
    DateTime? timestamp,
  }) : super(eventId: eventId, taskId: task.id, timestamp: timestamp);
}

class ReminderSnoozedEvent extends TaskEvent {
  final TaskItem task;
  final DateTime newReminderTime;

  ReminderSnoozedEvent({
    required String eventId,
    required this.task,
    required this.newReminderTime,
    DateTime? timestamp,
  }) : super(eventId: eventId, taskId: task.id, timestamp: timestamp);
}

class TaskDeletedEvent extends TaskEvent {
  final int notificationId;

  TaskDeletedEvent({
    required String eventId,
    required String taskId,
    required this.notificationId,
    DateTime? timestamp,
  }) : super(eventId: eventId, taskId: taskId, timestamp: timestamp);
}

class TasksReconciledEvent extends TaskEvent {
  final List<TaskItem> reconciledTasks;

  TasksReconciledEvent({
    required String eventId,
    required this.reconciledTasks,
    DateTime? timestamp,
  }) : super(
            eventId: eventId, taskId: 'SYSTEM_RECONCILE', timestamp: timestamp);
}
