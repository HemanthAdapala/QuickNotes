import 'package:flutter/foundation.dart';
import '../models/task_item.dart';
import 'notification_id_manager.dart';

abstract class ReminderScheduler {
  Future<void> initialize();
  Future<bool> scheduleReminder(TaskItem task);
  Future<void> cancelReminder(int notificationId);
  Future<List<int>> getPendingNotificationIds();
}

class LoggingReminderScheduler implements ReminderScheduler {
  bool _initialized = false;
  final List<String> logHistory = [];
  final Set<int> _pendingIds = {};

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    const msg = 'SCHEDULER [Initialize]: LoggingReminderScheduler initialized.';
    logHistory.add(msg);
    if (kDebugMode) {
      debugPrint(msg);
    }
  }

  @override
  Future<bool> scheduleReminder(TaskItem task) async {
    await cancelReminder(task.notificationId);
    _pendingIds.add(task.notificationId);
    if (task.isRecurring &&
        task.recurrence != null &&
        task.recurrence!.interval > 1) {
      _pendingIds
          .add(NotificationIdManager.getHorizonId(task.notificationId, 1));
      _pendingIds
          .add(NotificationIdManager.getHorizonId(task.notificationId, 2));
    }
    final msg =
        'SCHEDULER [Schedule]: Task "${task.title}" (ID: ${task.id}, NotificationID: ${task.notificationId}) at ${task.reminderTime}';
    logHistory.add(msg);
    if (kDebugMode) {
      debugPrint(msg);
    }
    return true;
  }

  @override
  Future<void> cancelReminder(int notificationId) async {
    for (final id
        in NotificationIdManager.getAllAssociatedIds(notificationId)) {
      _pendingIds.remove(id);
    }
    final msg = 'SCHEDULER [Cancel]: NotificationID $notificationId';
    logHistory.add(msg);
    if (kDebugMode) {
      debugPrint(msg);
    }
  }

  @override
  Future<List<int>> getPendingNotificationIds() async {
    return _pendingIds.toList();
  }
}
