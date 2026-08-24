import '../models/recurrence_rule.dart';

/// Pure deterministic recurrence date calculator service.
/// Calculates future occurrence dates anchored strictly to the original scheduled time.
class RecurrenceCalculator {
  /// Returns the next occurrence date/time anchored to [baseDate]'s original hour, minute, second.
  /// If [after] is provided (Catch-Up Policy), iterates until candidate is strictly > [after].
  /// Returns null if the recurrence expires ([endDate] or [maxOccurrences] reached).
  static DateTime? nextOccurrence(
    DateTime baseDate,
    RecurrenceRule rule, {
    DateTime? after,
    int currentOccurrenceCount = 1,
  }) {
    if (rule.maxOccurrences != null &&
        currentOccurrenceCount >= rule.maxOccurrences!) {
      return null;
    }

    DateTime candidate = _calculateSingleStep(baseDate, rule);

    if (after != null) {
      int occurrencesCalculated = currentOccurrenceCount;
      while (!candidate.isAfter(after)) {
        occurrencesCalculated++;
        if (rule.maxOccurrences != null &&
            occurrencesCalculated >= rule.maxOccurrences!) {
          return null;
        }
        candidate = _calculateSingleStep(candidate, rule);
      }
    }

    if (rule.endDate != null && candidate.isAfter(rule.endDate!)) {
      return null;
    }

    return candidate;
  }

  static DateTime _calculateSingleStep(DateTime current, RecurrenceRule rule) {
    final isUtc = current.isUtc;
    final year = current.year;
    final month = current.month;
    final day = current.day;
    final hour = current.hour;
    final minute = current.minute;
    final second = current.second;

    switch (rule.type) {
      case RecurrenceType.daily:
        return current.add(Duration(days: rule.interval));

      case RecurrenceType.weekly:
        return current.add(Duration(days: 7 * rule.interval));

      case RecurrenceType.monthly:
        int targetYear = year;
        int targetMonth = month + rule.interval;
        while (targetMonth > 12) {
          targetYear++;
          targetMonth -= 12;
        }
        final maxDaysInMonth = _daysInMonth(targetYear, targetMonth);
        final targetDay = day > maxDaysInMonth ? maxDaysInMonth : day;
        return isUtc
            ? DateTime.utc(
                targetYear, targetMonth, targetDay, hour, minute, second)
            : DateTime(
                targetYear, targetMonth, targetDay, hour, minute, second);

      case RecurrenceType.yearly:
        int targetYear = year + rule.interval;
        final maxDaysInMonth = _daysInMonth(targetYear, month);
        final targetDay = day > maxDaysInMonth ? maxDaysInMonth : day;
        return isUtc
            ? DateTime.utc(targetYear, month, targetDay, hour, minute, second)
            : DateTime(targetYear, month, targetDay, hour, minute, second);
    }
  }

  static int _daysInMonth(int year, int month) {
    if (month == 2) {
      final isLeap = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
      return isLeap ? 29 : 28;
    }
    const days = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return days[month];
  }
}
