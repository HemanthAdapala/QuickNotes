import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/models/widget_snapshot_payload.dart';

void main() {
  group('WidgetSnapshotPayload Model Tests', () {
    final fixedTime = DateTime.utc(2026, 8, 28, 12, 30, 0);

    test('constructs with default and required values', () {
      final payload = WidgetSnapshotPayload(
        version: 1,
        updatedAt: fixedTime,
        dateDayName: 'Friday',
        dateFormatted: '28 Aug',
        pinnedNotesCount: 4,
        pendingTasksCount: 3,
        overdueTasksCount: 1,
        hasActiveSession: true,
      );

      expect(payload.version, 1);
      expect(payload.updatedAt, fixedTime);
      expect(payload.dateDayName, 'Friday');
      expect(payload.dateFormatted, '28 Aug');
      expect(payload.pinnedNotesCount, 4);
      expect(payload.pendingTasksCount, 3);
      expect(payload.overdueTasksCount, 1);
      expect(payload.hasActiveSession, isTrue);
    });

    test('serializes to JSON with canonical snake_case keys', () {
      final payload = WidgetSnapshotPayload(
        version: 1,
        updatedAt: fixedTime,
        dateDayName: 'Friday',
        dateFormatted: '28 Aug',
        pinnedNotesCount: 5,
        pendingTasksCount: 2,
        overdueTasksCount: 0,
        hasActiveSession: true,
      );

      final jsonMap = payload.toJson();

      expect(jsonMap['version'], 1);
      expect(jsonMap['updated_at'], '2026-08-28T12:30:00.000Z');
      expect(jsonMap['date_day_name'], 'Friday');
      expect(jsonMap['date_formatted'], '28 Aug');
      expect(jsonMap['pinned_notes_count'], 5);
      expect(jsonMap['pending_tasks_count'], 2);
      expect(jsonMap['overdue_tasks_count'], 0);
      expect(jsonMap['has_active_session'], true);

      // Verify no sensitive keys exist
      expect(jsonMap.containsKey('title'), isFalse);
      expect(jsonMap.containsKey('content'), isFalse);
      expect(jsonMap.containsKey('email'), isFalse);
      expect(jsonMap.containsKey('user_id'), isFalse);
      expect(jsonMap.containsKey('pin'), isFalse);
    });

    test('roundtrips toJson and fromJson correctly', () {
      final payload = WidgetSnapshotPayload(
        version: 1,
        updatedAt: fixedTime,
        dateDayName: 'Wednesday',
        dateFormatted: '15 Jul',
        pinnedNotesCount: 10,
        pendingTasksCount: 7,
        overdueTasksCount: 2,
        hasActiveSession: true,
      );

      final jsonMap = payload.toJson();
      final deserialized = WidgetSnapshotPayload.fromJson(jsonMap);

      expect(deserialized, equals(payload));
      expect(deserialized.hashCode, equals(payload.hashCode));
    });

    test('roundtrips JSON string serialization', () {
      final payload = WidgetSnapshotPayload(
        version: 1,
        updatedAt: fixedTime,
        dateDayName: 'Monday',
        dateFormatted: '1 Jan',
        pinnedNotesCount: 1,
        pendingTasksCount: 0,
        overdueTasksCount: 0,
        hasActiveSession: true,
      );

      final jsonStr = payload.toJsonString();
      final deserialized = WidgetSnapshotPayload.fromJsonString(jsonStr);

      expect(deserialized, equals(payload));
    });

    test('WidgetSnapshotPayload.empty() creates sanitized empty state', () {
      final emptyPayload = WidgetSnapshotPayload.empty(now: fixedTime);

      expect(emptyPayload.version, 1);
      expect(emptyPayload.updatedAt, fixedTime);
      expect(emptyPayload.dateDayName, '');
      expect(emptyPayload.dateFormatted, '');
      expect(emptyPayload.pinnedNotesCount, 0);
      expect(emptyPayload.pendingTasksCount, 0);
      expect(emptyPayload.overdueTasksCount, 0);
      expect(emptyPayload.hasActiveSession, isFalse);
    });

    test('fromJson handles missing and null fields gracefully', () {
      final partialJson = <String, dynamic>{
        'version': 1,
        'date_day_name': 'Sunday',
      };

      final payload = WidgetSnapshotPayload.fromJson(partialJson);

      expect(payload.version, 1);
      expect(payload.dateDayName, 'Sunday');
      expect(payload.dateFormatted, '');
      expect(payload.pinnedNotesCount, 0);
      expect(payload.pendingTasksCount, 0);
      expect(payload.overdueTasksCount, 0);
      expect(payload.hasActiveSession, isTrue);
    });

    test('fromJsonString handles corrupted string safely without crashing', () {
      const malformed = '{ invalid: json ]';
      final payload = WidgetSnapshotPayload.fromJsonString(malformed);

      expect(payload.hasActiveSession, isFalse);
      expect(payload.pinnedNotesCount, 0);
      expect(payload.pendingTasksCount, 0);
    });

    test('toString returns readable representation', () {
      final payload = WidgetSnapshotPayload.empty(now: fixedTime);
      expect(payload.toString(), contains('WidgetSnapshotPayload'));
      expect(payload.toString(), contains('pinned: 0'));
    });
  });
}
