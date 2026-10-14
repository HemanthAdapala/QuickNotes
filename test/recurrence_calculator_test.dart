import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/models/recurrence_rule.dart';
import 'package:quick_notes/services/recurrence_calculator.dart';

void main() {
  group('RecurrenceCalculator Date Math Tests', () {
    test('Daily recurrence adds 1 day and preserves exact hour/minute', () {
      final base = DateTime(2026, 7, 24, 9, 0, 0);
      const rule = RecurrenceRule(type: RecurrenceType.daily, interval: 1);

      final next = RecurrenceCalculator.nextOccurrence(base, rule);
      expect(next, equals(DateTime(2026, 7, 25, 9, 0, 0)));
    });

    test('Daily recurrence with interval 3 adds 3 days', () {
      final base = DateTime(2026, 7, 24, 14, 30, 0);
      const rule = RecurrenceRule(type: RecurrenceType.daily, interval: 3);

      final next = RecurrenceCalculator.nextOccurrence(base, rule);
      expect(next, equals(DateTime(2026, 7, 27, 14, 30, 0)));
    });

    test('Weekly recurrence adds 7 days', () {
      final base = DateTime(2026, 7, 20, 10, 15, 0); // Monday
      const rule = RecurrenceRule(type: RecurrenceType.weekly, interval: 1);

      final next = RecurrenceCalculator.nextOccurrence(base, rule);
      expect(next, equals(DateTime(2026, 7, 27, 10, 15, 0))); // Next Monday
    });

    test('Monthly recurrence clamps month-end dates (Jan 31 -> Feb 28)', () {
      final jan31 = DateTime(2026, 1, 31, 9, 0, 0);
      const rule = RecurrenceRule(type: RecurrenceType.monthly, interval: 1);

      final febNext = RecurrenceCalculator.nextOccurrence(jan31, rule);
      expect(febNext, equals(DateTime(2026, 2, 28, 9, 0, 0)));

      final marNext = RecurrenceCalculator.nextOccurrence(febNext!, rule);
      expect(marNext, equals(DateTime(2026, 3, 28, 9, 0, 0)));
    });

    test('Yearly recurrence handles leap year (Feb 29 -> Feb 28)', () {
      final leapFeb29 = DateTime(2024, 2, 29, 8, 0, 0);
      const rule = RecurrenceRule(type: RecurrenceType.yearly, interval: 1);

      final next = RecurrenceCalculator.nextOccurrence(leapFeb29, rule);
      expect(next, equals(DateTime(2025, 2, 28, 8, 0, 0)));
    });

    test('Catch-Up Policy skips 10 missed days and produces single next future occurrence', () {
      final base = DateTime(2026, 7, 1, 9, 0, 0);
      const rule = RecurrenceRule(type: RecurrenceType.daily, interval: 1);
      final currentNow = DateTime(2026, 7, 11, 17, 0, 0); // 10 days later at 5 PM

      final next = RecurrenceCalculator.nextOccurrence(base, rule, after: currentNow);
      expect(next, equals(DateTime(2026, 7, 12, 9, 0, 0))); // Tomorrow 9 AM relative to now
    });

    test('End date stops recurrence calculation', () {
      final base = DateTime(2026, 7, 24, 9, 0, 0);
      final endDate = DateTime(2026, 7, 24, 23, 59, 59);
      final rule = RecurrenceRule(type: RecurrenceType.daily, interval: 1, endDate: endDate);

      final next = RecurrenceCalculator.nextOccurrence(base, rule);
      expect(next, isNull);
    });

    test('Max occurrences stops recurrence calculation', () {
      final base = DateTime(2026, 7, 24, 9, 0, 0);
      const rule = RecurrenceRule(type: RecurrenceType.daily, interval: 1, maxOccurrences: 3);

      final next = RecurrenceCalculator.nextOccurrence(base, rule, currentOccurrenceCount: 3);
      expect(next, isNull);
    });
  });

  group('RecurrenceRule Model Serialization & Compatibility Tests', () {
    test('RecurrenceRule with excludedDates serializes toMap and fromMap with dates intact', () {
      final rule = RecurrenceRule(
        type: RecurrenceType.daily,
        interval: 2,
        endDate: DateTime.utc(2026, 12, 31),
        maxOccurrences: 10,
        excludedDates: const ['2026-09-02', '2026-09-04'],
      );

      final map = rule.toMap();
      expect(map['type'], equals('daily'));
      expect(map['interval'], equals(2));
      expect(map['excludedDates'], equals(['2026-09-02', '2026-09-04']));

      final restored = RecurrenceRule.fromMap(map);
      expect(restored, equals(rule));
      expect(restored.excludedDates, equals(['2026-09-02', '2026-09-04']));
    });

    test('Older recurrence JSON without excludedDates deserializes successfully and defaults to empty list', () {
      final olderMap = {
        'version': 1,
        'type': 'weekly',
        'interval': 1,
      };

      final restored = RecurrenceRule.fromMap(olderMap);
      expect(restored.type, equals(RecurrenceType.weekly));
      expect(restored.interval, equals(1));
      expect(restored.excludedDates, isEmpty);
      expect(restored.excludedDates, isA<List<String>>());

      final fromString = RecurrenceRule.tryDecode('{"type":"monthly","interval":1}');
      expect(fromString, isNotNull);
      expect(fromString!.type, equals(RecurrenceType.monthly));
      expect(fromString.excludedDates, isEmpty);
    });

    test('RecurrenceRule equality and copyWith respect excludedDates', () {
      const r1 = RecurrenceRule(
        type: RecurrenceType.daily,
        excludedDates: ['2026-09-01'],
      );
      const r2 = RecurrenceRule(
        type: RecurrenceType.daily,
        excludedDates: ['2026-09-01'],
      );
      const r3 = RecurrenceRule(
        type: RecurrenceType.daily,
        excludedDates: ['2026-09-02'],
      );

      expect(r1, equals(r2));
      expect(r1, isNot(equals(r3)));

      final updated = r1.copyWith(excludedDates: ['2026-09-01', '2026-09-02']);
      expect(updated.excludedDates, equals(['2026-09-01', '2026-09-02']));
    });
  });
}
