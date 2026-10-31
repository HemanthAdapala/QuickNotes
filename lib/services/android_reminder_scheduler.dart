import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../models/task_item.dart';
import '../models/reminder_mode.dart';
import '../models/notification_action.dart';
import '../models/notification_payload.dart';
import '../models/recurrence_rule.dart';
import 'notification_action_handler.dart';
import 'reminder_scheduler.dart';
import 'recurrence_calculator.dart';
import 'notification_id_manager.dart';

/// Concrete implementation of ReminderScheduler using flutter_local_notifications
class AndroidReminderScheduler implements ReminderScheduler {
  static final AndroidReminderScheduler _instance =
      AndroidReminderScheduler._internal();
  factory AndroidReminderScheduler() => _instance;

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String channelId = 'quick_notes_alarm_channel_v3';
  static const String channelName = 'Task System Alarms';
  static const String channelDescription =
      'Full alarm ringtone notifications for task reminders';

  bool _isInitialized = false;
  String? _lastError;

  AndroidReminderScheduler._internal();

  bool get isInitialized => _isInitialized;
  String? get lastError => _lastError;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    if (kIsWeb) {
      _isInitialized = true;
      return;
    }

    try {
      // 1. Initialize timezone database
      tz_data.initializeTimeZones();

      // 2. Configure Android initialization settings
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse:
            NotificationActionHandler.handleForegroundResponse,
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );

      // 3. Set local timezone location matching device timeZoneOffset
      try {
        final now = DateTime.now();
        final offset = now.timeZoneOffset;
        final sysZoneName = now.timeZoneName;
        if (tz.timeZoneDatabase.locations.containsKey(sysZoneName)) {
          tz.setLocalLocation(tz.getLocation(sysZoneName));
        } else {
          for (final location in tz.timeZoneDatabase.locations.values) {
            final tzNow = tz.TZDateTime.now(location);
            if (tzNow.timeZoneOffset == offset) {
              tz.setLocalLocation(location);
              break;
            }
          }
        }
      } catch (_) {}

      // 4. Create Notification & Alarm Channels
      const notificationChannel = AndroidNotificationChannel(
        'quick_notes_notification_channel_v3',
        'Task Notifications',
        description: 'Standard notifications for task reminders',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      const alarmChannel = AndroidNotificationChannel(
        'quick_notes_alarm_channel_v3',
        'Task Alarms',
        description: 'Full alarm ringtone notifications for task reminders',
        importance: Importance.max,
        playSound: true,
        sound: UriAndroidNotificationSound(
            'content://settings/system/alarm_alert'),
        enableVibration: true,
      );

      final androidPlugin =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        try {
          await androidPlugin.deleteNotificationChannel(
              channelId: 'quick_notes_tasks');
          await androidPlugin.deleteNotificationChannel(
              channelId: 'quick_notes_alarm_channel_v2');
        } catch (_) {}

        await androidPlugin.createNotificationChannel(notificationChannel);
        await androidPlugin.createNotificationChannel(alarmChannel);

        // Request POST_NOTIFICATIONS on Android 13+ (API 33+)
        await androidPlugin.requestNotificationsPermission();

        // Request exact alarm permission on Android 12+ (API 31+)
        await androidPlugin.requestExactAlarmsPermission();
      }

      _isInitialized = true;
      if (kDebugMode) {
        debugPrint(
            'AndroidReminderScheduler successfully initialized for timezone ${tz.local.name}.');
      }

      // Check if cold start app launch was triggered by a notification tap
      try {
        final launchDetails =
            await _notificationsPlugin.getNotificationAppLaunchDetails();
        if (launchDetails != null &&
            launchDetails.didNotificationLaunchApp &&
            launchDetails.notificationResponse != null) {
          if (kDebugMode) {
            debugPrint(
                'NOTIFICATION COLD LAUNCH: payload=${launchDetails.notificationResponse?.payload}');
          }
          NotificationActionHandler.handleForegroundResponse(
              launchDetails.notificationResponse!);
        }
      } catch (e) {
        debugPrint('Error checking notification app launch details: $e');
      }
    } catch (e) {
      debugPrint('Error initializing AndroidReminderScheduler: $e');
      _isInitialized = true; // Fallback ready state to prevent blocking engine
    }
  }

  @override
  Future<bool> scheduleReminder(TaskItem task) async {
    if (kIsWeb) return true;
    if (!_isInitialized) {
      await initialize();
    }

    if (!task.reminderEnabled ||
        task.reminderMode == ReminderMode.off ||
        task.reminderTime == null) {
      return true;
    }

    final reminderUtc = task.reminderTime!.toUtc();
    final nowUtc = DateTime.now().toUtc();

    // Do not schedule past reminders
    if (reminderUtc.isBefore(nowUtc)) {
      return false;
    }

    // Defensive cancellation before scheduling to prevent duplicate notifications
    await cancelReminder(task.notificationId);

    try {
      final tzScheduledTime = tz.TZDateTime.from(reminderUtc, tz.UTC);

      final String targetChannelId;
      final Importance targetImportance;
      final Priority targetPriority;
      final AndroidNotificationSound? targetSound;
      final AndroidNotificationCategory targetCategory;
      final bool isFullScreen;

      if (task.reminderMode == ReminderMode.notification) {
        targetChannelId = 'quick_notes_notification_channel_v3';
        targetImportance = Importance.high;
        targetPriority = Priority.high;
        targetSound = null; // Standard notification chime
        targetCategory = AndroidNotificationCategory.reminder;
        isFullScreen = false;
      } else {
        targetChannelId = 'quick_notes_alarm_channel_v3';
        targetImportance = Importance.max;
        targetPriority = Priority.max;
        targetSound = const UriAndroidNotificationSound(
            'content://settings/system/alarm_alert');
        targetCategory = AndroidNotificationCategory.alarm;
        isFullScreen = true;
      }

      final androidDetails = AndroidNotificationDetails(
        targetChannelId,
        targetChannelId == 'quick_notes_notification_channel_v3'
            ? 'Task Notifications'
            : 'Task Alarms',
        channelDescription:
            targetChannelId == 'quick_notes_notification_channel_v3'
                ? 'Standard notifications for task reminders'
                : 'Full alarm ringtone notifications for task reminders',
        importance: targetImportance,
        priority: targetPriority,
        playSound: true,
        sound: targetSound,
        enableVibration: true,
        fullScreenIntent: isFullScreen,
        visibility: NotificationVisibility.public,
        category: targetCategory,
        actions: <AndroidNotificationAction>[
          const AndroidNotificationAction(
            'action_done',
            '✓ Mark Done',
            showsUserInterface: false,
            cancelNotification: true,
          ),
          const AndroidNotificationAction(
            'action_snooze',
            '😴 Snooze',
            showsUserInterface: false,
            cancelNotification: true,
          ),
          const AndroidNotificationAction(
            'action_open',
            '📖 Open',
            showsUserInterface: true,
            cancelNotification: true,
          ),
        ],
      );

      final notificationDetails = NotificationDetails(android: androidDetails);
      final payload = NotificationPayload(
        taskId: task.id,
        action: NotificationAction.open,
      ).jsonEncodePayload();

      // Recurrence matching components for standard intervals
      DateTimeComponents? matchComponents;
      if (task.isRecurring && task.recurrence != null) {
        final rec = task.recurrence!;
        if (rec.interval == 1) {
          switch (rec.type) {
            case RecurrenceType.daily:
              matchComponents = DateTimeComponents.time;
              break;
            case RecurrenceType.weekly:
              matchComponents = DateTimeComponents.dayOfWeekAndTime;
              break;
            case RecurrenceType.monthly:
              matchComponents = DateTimeComponents.dayOfMonthAndTime;
              break;
            case RecurrenceType.yearly:
              matchComponents = DateTimeComponents.dateAndTime;
              break;
          }
        }
      }

      await _notificationsPlugin.zonedSchedule(
        id: task.notificationId,
        title: task.title,
        body: task.description.isNotEmpty ? task.description : 'Task Reminder',
        scheduledDate: tzScheduledTime,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
        matchDateTimeComponents: matchComponents,
      );

      // For custom intervals (interval > 1) which native repeating cannot express:
      // Schedule a bounded forward horizon (next 2 occurrences) so alarms fire even if app is closed
      if (task.isRecurring &&
          task.recurrence != null &&
          task.recurrence!.interval > 1) {
        final rec = task.recurrence!;
        DateTime nextCandidate = reminderUtc;
        for (int step = 1; step <= 2; step++) {
          final nextStep =
              RecurrenceCalculator.nextOccurrence(nextCandidate, rec);
          if (nextStep == null) break;
          nextCandidate = nextStep;
          final tzHorizonTime = tz.TZDateTime.from(nextCandidate, tz.UTC);
          final horizonId =
              NotificationIdManager.getHorizonId(task.notificationId, step);
          await _notificationsPlugin.zonedSchedule(
            id: horizonId,
            title: task.title,
            body: task.description.isNotEmpty
                ? task.description
                : 'Task Reminder',
            scheduledDate: tzHorizonTime,
            notificationDetails: notificationDetails,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            payload: payload,
          );
        }
      }

      _lastError = null;
      if (kDebugMode) {
        debugPrint(
            'SCHEDULER ZONED [Success]: Task "${task.title}" (NotificationID: ${task.notificationId}) scheduled for $tzScheduledTime (match: $matchComponents)');
      }
      return true;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('Error in zonedSchedule for task ${task.id}: $e');
      return false;
    }
  }

  @override
  Future<void> cancelReminder(int notificationId) async {
    if (kIsWeb) return;
    if (!_isInitialized) {
      await initialize();
    }

    try {
      for (final id
          in NotificationIdManager.getAllAssociatedIds(notificationId)) {
        await _notificationsPlugin.cancel(id: id);
      }
      if (kDebugMode) {
        debugPrint(
            'SCHEDULER CANCEL [Success]: NotificationID $notificationId (and horizon) cancelled.');
      }
    } catch (e) {
      debugPrint('Error cancelling notification $notificationId: $e');
    }
  }

  @override
  Future<List<int>> getPendingNotificationIds() async {
    if (kIsWeb) return [];
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final pendingRequests =
          await _notificationsPlugin.pendingNotificationRequests();
      return pendingRequests.map((req) => req.id).toList();
    } catch (e) {
      debugPrint('Error fetching pendingNotificationRequests: $e');
      return [];
    }
  }
}
