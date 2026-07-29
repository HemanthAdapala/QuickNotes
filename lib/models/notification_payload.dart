import 'dart:convert';
import 'notification_action.dart';
import 'notification_type.dart';

/// Strongly-typed, versioned notification payload model for future-proof payload decoding
class NotificationPayload {
  final int version;
  final NotificationType type;
  final String taskId;
  final NotificationAction? action;

  const NotificationPayload({
    this.version = 1,
    this.type = NotificationType.task,
    required this.taskId,
    this.action,
  });

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'type': type.toTypeString(),
      'taskId': taskId,
      if (action != null) 'action': action!.toActionString(),
    };
  }

  factory NotificationPayload.fromJson(Map<String, dynamic> json) {
    return NotificationPayload(
      version: json['version'] as int? ?? 1,
      type: NotificationType.fromString(json['type'] as String?),
      taskId: json['taskId'] as String? ?? '',
      action: NotificationAction.fromString(json['action'] as String?),
    );
  }

  String jsonEncodePayload() {
    return jsonEncode(toJson());
  }

  static NotificationPayload? tryDecode(String? jsonString) {
    if (jsonString == null || jsonString.trim().isEmpty) return null;
    try {
      final Map<String, dynamic> map = jsonDecode(jsonString);
      return NotificationPayload.fromJson(map);
    } catch (_) {
      // Fallback for simple legacy payloads like `{"taskId": "..."}`
      try {
        final Map<String, dynamic> map = jsonDecode(jsonString);
        if (map.containsKey('taskId')) {
          return NotificationPayload(
            taskId: map['taskId'].toString(),
            action: NotificationAction.fromString(map['action']?.toString()),
          );
        }
      } catch (_) {}
      return null;
    }
  }
}
