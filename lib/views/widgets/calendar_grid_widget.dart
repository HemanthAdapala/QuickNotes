import 'package:flutter/material.dart';
import 'calendar_day_cell.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CalendarGridWidget
//
// A 7-column calendar grid for [currentMonth].
//
// Layout:
//   • Week starts on Sunday (consistent with note_calendar_screen.dart)
//   • Rows: Row(mainAxisAlignment.spaceBetween, 7 cells)
//           so cell spacing adapts to screen width automatically
//   • Empty leading / trailing slots are invisible SizedBox(32, 48)
//   • [daysWithTasks]  — day numbers with notes/tasks → blue check circle
//   • [selectedDay]    — currently selected day → blue border + blue number
//   • [onDayTap]       — callback when a day cell is tapped
// ─────────────────────────────────────────────────────────────────────────────
class CalendarGridWidget extends StatelessWidget {
  final DateTime currentMonth;

  /// Set of day-of-month integers (1–31) that have notes / tasks.
  final Set<int> daysWithTasks;

  /// The currently selected day of month (null = nothing selected).
  final int? selectedDay;

  /// Fired when a day is tapped; receives the day-of-month number.
  final ValueChanged<int>? onDayTap;

  const CalendarGridWidget({
    super.key,
    required this.currentMonth,
    this.daysWithTasks = const {},
    this.selectedDay,
    this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final int daysInMonth =
        DateTime(currentMonth.year, currentMonth.month + 1, 0).day;

    // Flutter weekday: Mon=1 … Sat=6, Sun=7
    // Sun → column 0, Mon → column 1, …, Sat → column 6
    final int rawWeekday =
        DateTime(currentMonth.year, currentMonth.month, 1).weekday;
    final int offset = rawWeekday == 7 ? 0 : rawWeekday;

    // Build flat list: empty slots + day cells + trailing empties
    final List<Widget> cells = [];

    for (int i = 0; i < offset; i++) {
      cells.add(const SizedBox(width: 32, height: 48));
    }

    for (int day = 1; day <= daysInMonth; day++) {
      cells.add(CalendarDayCell(
        day: day,
        hasTask: daysWithTasks.contains(day),
        isSelected: selectedDay == day,
        onTap: () => onDayTap?.call(day),
      ));
    }

    while (cells.length % 7 != 0) {
      cells.add(const SizedBox(width: 32, height: 48));
    }

    // Group into rows of 7
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
