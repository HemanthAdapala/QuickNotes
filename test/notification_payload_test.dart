import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/models/notification_action.dart';
import 'package:quick_notes/models/notification_type.dart';
import 'package:quick_notes/models/notification_payload.dart';

void main() {
  group('NotificationPayload & Enum Unit Tests', () {
    test('NotificationAction enum string parsing and serialization', () {
      expect(NotificationAction.fromString('done'), equals(NotificationAction.done));
      expect(NotificationAction.fromString('action_done'), equals(NotificationAction.done));
      expect(NotificationAction.fromString('snooze'), equals(NotificationAction.snooze));
      expect(NotificationAction.fromString('open'), equals(NotificationAction.open));
      expect(NotificationAction.fromString('unknown'), isNull);

      expect(NotificationAction.done.toActionString(), equals('done'));
      expect(NotificationAction.snooze.toActionString(), equals('snooze'));
      expect(NotificationAction.open.toActionString(), equals('open'));
    });

    test('NotificationType enum string parsing and serialization', () {
      expect(NotificationType.fromString('task'), equals(NotificationType.task));
      expect(NotificationType.fromString('note'), equals(NotificationType.note));
      expect(NotificationType.fromString('calendar'), equals(NotificationType.calendar));
      expect(NotificationType.fromString('invalid'), equals(NotificationType.task));

      expect(NotificationType.task.toTypeString(), equals('task'));
    });

    test('NotificationPayload JSON roundtrip encoding and decoding', () {
      const payload = NotificationPayload(
        version: 1,
        type: NotificationType.task,
        taskId: 'task-123',
        action: NotificationAction.done,
      );

      final encoded = payload.jsonEncodePayload();
      final decoded = NotificationPayload.tryDecode(encoded);

      expect(decoded, isNotNull);
      expect(decoded!.version, equals(1));
      expect(decoded.type, equals(NotificationType.task));
      expect(decoded.taskId, equals('task-123'));
      expect(decoded.action, equals(NotificationAction.done));
    });

    test('NotificationPayload fallback for legacy JSON format', () {
      const legacyJson = '{"taskId": "task-456"}';
      final decoded = NotificationPayload.tryDecode(legacyJson);

      expect(decoded, isNotNull);
      expect(decoded!.taskId, equals('task-456'));
      expect(decoded.version, equals(1));
      expect(decoded.type, equals(NotificationType.task));
    });

    test('NotificationPayload tryDecode returns null for invalid string', () {
      expect(NotificationPayload.tryDecode(null), isNull);
      expect(NotificationPayload.tryDecode(''), isNull);
      expect(NotificationPayload.tryDecode('invalid json string'), isNull);
    });
  });
}
