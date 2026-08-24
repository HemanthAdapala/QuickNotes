import 'package:flutter/material.dart';
import 'calendar_day_cell.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CalendarGridWidget
//
// A 7-column calendar grid for [currentMonth].
// ─────────────────────────────────────────────────────────────────────────────
class CalendarGridWidget extends StatelessWidget {
  final DateTime currentMonth;

  /// Map of day-of-month (1–31) to DayTaskState.
  final Map<int, DayTaskState> taskStates;

  /// The currently selected day of month (null = nothing selected).
  final int? selectedDay;

  /// Fired when a day is tapped; receives the day-of-month number.
  final ValueChanged<int>? onDayTap;

  const CalendarGridWidget({
    super.key,
    required this.currentMonth,
    this.taskStates = const {},
    this.selectedDay,
    this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final int daysInMonth =
        DateTime(currentMonth.year, currentMonth.month + 1, 0).day;

    final int rawWeekday =
        DateTime(currentMonth.year, currentMonth.month, 1).weekday;
    final int offset = rawWeekday == 7 ? 0 : rawWeekday;

    final List<Widget> cells = [];

    for (int i = 0; i < offset; i++) {
      cells.add(const SizedBox(width: 32, height: 48));
    }

    for (int day = 1; day <= daysInMonth; day++) {
      cells.add(CalendarDayCell(
        day: day,
        taskState: taskStates[day] ?? DayTaskState.none,
        isSelected: selectedDay == day,
        onTap: () => onDayTap?.call(day),
      ));
    }

    while (cells.length % 7 != 0) {
      cells.add(const SizedBox(width: 32, height: 48));
    }

    final List<List<Widget>> rows = [];
    for (int i = 0; i < cells.length; i += 7) {
      rows.add(cells.sublist(i, i + 7));
    }

    return Column(
      children: [
        for (int r = 0; r < rows.length; r++) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: rows[r],
          ),
          if (r < rows.length - 1) const SizedBox(height: 14),
        ],
      ],
    );
  }
}
