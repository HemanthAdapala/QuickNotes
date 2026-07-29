import 'package:flutter/foundation.dart';
import '../models/task_item.dart';

abstract class ReminderScheduler {
  Future<void> initialize();
  Future<void> scheduleReminder(TaskItem task);
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
  Future<void> scheduleReminder(TaskItem task) async {
    await cancelReminder(task.notificationId);
    _pendingIds.add(task.notificationId);
    final msg =
        'SCHEDULER [Schedule]: Task "${task.title}" (ID: ${task.id}, NotificationID: ${task.notificationId}) at ${task.reminderTime}';
    logHistory.add(msg);
    if (kDebugMode) {
      debugPrint(msg);
    }
  }

  @override
  Future<void> cancelReminder(int notificationId) async {
    _pendingIds.remove(notificationId);
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
