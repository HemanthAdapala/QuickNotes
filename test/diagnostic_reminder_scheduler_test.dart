import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/models/reminder_mode.dart';
import 'package:quick_notes/models/task_item.dart';
import 'package:quick_notes/models/task_status.dart';
import 'package:quick_notes/services/android_reminder_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AndroidFlutterLocalNotificationsPlugin.registerWith();

  final List<MethodCall> methodCalls = [];

  setUp(() {
    methodCalls.clear();
    const MethodChannel notificationsChannel =
        MethodChannel('dexterous.com/flutter/local_notifications');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, (MethodCall call) async {
      methodCalls.add(call);
      if (call.method == 'initialize') {
        return true;
      }
      if (call.method == 'pendingNotificationRequests') {
        return <Map<String, dynamic>>[];
      }
      return true;
    });
  });

  tearDown(() {
    const MethodChannel notificationsChannel =
        MethodChannel('dexterous.com/flutter/local_notifications');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, null);
  });

  test('Inspect zonedSchedule arguments for today, tomorrow, and future', () async {
    final scheduler = AndroidReminderScheduler();
    await scheduler.initialize();

    final now = DateTime.now();

    // 1. Task due later today (+2 hours)
    final taskToday = TaskItem(
      id: 'task-today',
      title: 'Task Today',
      dueDate: now.add(const Duration(hours: 2)),
      reminderTime: now.add(const Duration(hours: 2)),
      reminderEnabled: true,
      reminderMode: ReminderMode.notification,
      priority: 'High',
      notificationId: 101,
      status: TaskStatus.scheduled,
    );

    // 2. Task due tomorrow (+24 hours)
    final taskTomorrow = TaskItem(
      id: 'task-tomorrow',
      title: 'Task Tomorrow',
      dueDate: now.add(const Duration(hours: 24)),
      reminderTime: now.add(const Duration(hours: 24)),
      reminderEnabled: true,
      reminderMode: ReminderMode.alarm,
      priority: 'Medium',
      notificationId: 102,
      status: TaskStatus.scheduled,
    );

    // 3. Task due 5 days later
    final taskFuture = TaskItem(
      id: 'task-future',
      title: 'Task Future',
      dueDate: now.add(const Duration(days: 5)),
      reminderTime: now.add(const Duration(days: 5)),
      reminderEnabled: true,
      reminderMode: ReminderMode.notification,
      priority: 'Low',
      notificationId: 103,
      status: TaskStatus.scheduled,
    );

    await scheduler.scheduleReminder(taskToday);
    await scheduler.scheduleReminder(taskTomorrow);
    await scheduler.scheduleReminder(taskFuture);

    for (final call in methodCalls) {
      if (call.method == 'zonedSchedule') {
        final args = call.arguments as Map;
        print('DIAGNOSTIC_CALL zonedSchedule: id=${args['id']}, title=${args['title']}, timeZoneName=${args['timeZoneName']}, scheduledDateTime=${args['scheduledDateTime']}, scheduledDateTimeISO8601=${args['scheduledDateTimeISO8601']}');
      }
    }
  });
}
