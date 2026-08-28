import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/notification_action.dart';
import '../models/notification_payload.dart';
import '../models/task_status.dart';
import '../repositories/tasks_repository.dart';
import 'clock_service.dart';
import 'database_service.dart';
import 'android_reminder_scheduler.dart';
import 'task_engine.dart';

/// Top-level background isolate entry point required by flutter_local_notifications
@pragma('vm:entry-point')
void notificationTapBackground(
    NotificationResponse notificationResponse) async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationActionHandler.handleBackgroundResponse(
      notificationResponse);
}

/// Standalone handler managing notification actions and background execution adapters
class NotificationActionHandler {
  static final StreamController<NotificationPayload>
      _foregroundActionController =
      StreamController<NotificationPayload>.broadcast();

  static NotificationPayload? _lastLaunchedPayload;

  /// Gets and consumes the last launch payload (useful for cold start launch handling)
  static NotificationPayload? consumeLastLaunchedPayload() {
    final payload = _lastLaunchedPayload;
    _lastLaunchedPayload = null;
    return payload;
  }

  /// Stream emitting foreground payload taps for deep-linking
  static Stream<NotificationPayload> get foregroundStream =>
      _foregroundActionController.stream;

  /// Handles foreground notification taps
  static void handleForegroundResponse(NotificationResponse response) {
    final rawPayload = response.payload;
    final actionFromId = NotificationAction.fromString(response.actionId);

    var payload = NotificationPayload.tryDecode(rawPayload);
    if (payload != null && actionFromId != null) {
      payload = NotificationPayload(
        version: payload.version,
        type: payload.type,
        taskId: payload.taskId,
        action: actionFromId,
      );
    } else if (payload == null &&
        response.actionId != null &&
        response.actionId!.isNotEmpty) {
      payload = NotificationPayload(
        taskId: response.actionId!,
        action: actionFromId ?? NotificationAction.open,
      );
    }

    if (payload != null) {
      _lastLaunchedPayload = payload;
      if (kDebugMode) {
        debugPrint(
            'NOTIFICATION ACTION [Foreground]: Task ${payload.taskId}, Action: ${payload.action?.toActionString()}');
      }
      _foregroundActionController.add(payload);
    }
  }

  /// Handles background notification action callbacks (runs in isolate when app is terminated/backgrounded)
  static Future<void> handleBackgroundResponse(
      NotificationResponse response) async {
    WidgetsFlutterBinding.ensureInitialized();

    final rawPayload = response.payload;
    final actionFromId = NotificationAction.fromString(response.actionId);

    var payload = NotificationPayload.tryDecode(rawPayload);
    if (payload != null && actionFromId != null) {
      payload = NotificationPayload(
        version: payload.version,
        type: payload.type,
        taskId: payload.taskId,
        action: actionFromId,
      );
    }

    if (payload == null || payload.taskId.isEmpty) {
      if (kDebugMode) {
        debugPrint(
            'NOTIFICATION ACTION [Background]: Missing or invalid payload. Ignoring.');
      }
      return;
    }

    final action = payload.action ?? actionFromId ?? NotificationAction.open;

    if (kDebugMode) {
      debugPrint(
          'NOTIFICATION ACTION [Background]: Task ${payload.taskId}, Action: ${action.toActionString()}');
    }

    // Only process background actions (Done / Snooze). Open action is handled when app comes to foreground.
    if (action == NotificationAction.open) {
      return;
    }

    try {
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.linux)) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }

      final repo = SqliteTasksRepository(dbService: DatabaseService.instance);
      final scheduler = AndroidReminderScheduler();
      await scheduler.initialize();

      final engine = TaskEngine(
        repository: repo,
        clock: SystemClock(),
        scheduler: scheduler,
      );

      await engine.initialize();
      await executeActionWithIdempotency(engine, payload.taskId, action);

      // Re-emit on foreground stream so if UI is running, it updates live
      _foregroundActionController.add(payload);
    } catch (e) {
      debugPrint('Error executing background notification action: $e');
    }
  }

  /// Pure state-based idempotent action execution logic
  static Future<bool> executeActionWithIdempotency(
    TaskEngine engine,
    String taskId,
    NotificationAction action, {
    Duration snoozeDuration = const Duration(minutes: 15),
  }) async {
    final task = engine.getTaskById(taskId);
    if (task == null) {
      if (kDebugMode) {
        debugPrint(
            'NOTIFICATION ACTION [Idempotency Guard]: Task $taskId no longer exists. Gracefully ignoring.');
      }
      return false;
    }

    switch (action) {
      case NotificationAction.done:
        // Pure State-Based Guard: If already completed, skip duplicate execution!
        if (task.completed || task.status == TaskStatus.completed) {
          if (kDebugMode) {
            debugPrint(
                'NOTIFICATION ACTION [Idempotency Guard]: Task $taskId is ALREADY completed. Skipping duplicate action.');
          }
          return false;
        }
        await engine.toggleCompletion(taskId);
        if (kDebugMode) {
          debugPrint(
              'NOTIFICATION ACTION [Execution]: Task $taskId successfully marked done via background action.');
        }
        return true;

      case NotificationAction.snooze:
        // Pure State-Based Guard: If task is completed or archived, skip snooze!
        if (task.completed ||
            task.status == TaskStatus.archived ||
            task.status == TaskStatus.cancelled) {
          if (kDebugMode) {
            debugPrint(
                'NOTIFICATION ACTION [Idempotency Guard]: Task $taskId cannot be snoozed in state ${task.status}. Skipping.');
          }
          return false;
        }
        await engine.snoozeTask(taskId, snoozeDuration);
        if (kDebugMode) {
          debugPrint(
              'NOTIFICATION ACTION [Execution]: Task $taskId successfully snoozed for $snoozeDuration.');
        }
        return true;

      case NotificationAction.open:
        return true;
    }
  }
}
