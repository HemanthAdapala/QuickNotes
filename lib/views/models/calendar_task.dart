import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CalendarTask — lightweight model used by CalendarScreen + TaskWidgetsContainer
// ─────────────────────────────────────────────────────────────────────────────

/// Priority level of a task — determines the left color strip.
enum TaskPriority { green, yellow, red }

/// Represents a single task shown in the CalendarScreen task panel.
class CalendarTask {
  final String id;
  final String title;
  final String subtitle;
  final TaskPriority priority;
  bool isCompleted;

  CalendarTask({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.priority,
    this.isCompleted = false,
  });

  /// Left-strip color from design:
  ///   Green  → Color(0x7F34C759)  — 50% opacity
  ///   Yellow → Color(0x7FFFCC00)  — 50% opacity
  ///   Red    → Color(0x7FFF383C)  — 50% opacity
  Color get priorityColor {
    switch (priority) {
      case TaskPriority.green:
        return const Color(0x7F34C759);
      case TaskPriority.yellow:
        return const Color(0x7FFFCC00);
      case TaskPriority.red:
        return const Color(0x7FFF383C);
    }
  }
}
