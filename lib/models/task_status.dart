enum TaskStatus {
  created,
  scheduled,
  waiting,
  reminderFired,
  completed,
  missed,
  cancelled,
  archived,
}

extension TaskStatusExtension on TaskStatus {
  /// Validates state machine transitions according to QuickNotes Task Engine rules.
  bool canTransitionTo(TaskStatus newStatus) {
    if (this == newStatus) return true;

    switch (this) {
      case TaskStatus.created:
        return newStatus == TaskStatus.scheduled ||
            newStatus == TaskStatus.waiting ||
            newStatus == TaskStatus.cancelled;

      case TaskStatus.scheduled:
        return newStatus == TaskStatus.waiting ||
            newStatus == TaskStatus.completed ||
            newStatus == TaskStatus.cancelled;

      case TaskStatus.waiting:
        return newStatus == TaskStatus.reminderFired ||
            newStatus == TaskStatus.completed ||
            newStatus == TaskStatus.missed ||
            newStatus == TaskStatus.cancelled;

      case TaskStatus.reminderFired:
        return newStatus == TaskStatus.waiting || // Snoozed
            newStatus == TaskStatus.completed ||
            newStatus == TaskStatus.missed ||
            newStatus == TaskStatus.archived;

      case TaskStatus.completed:
        // Cannot transition from completed to waiting unless explicitly restored
        return newStatus == TaskStatus.waiting ||
            newStatus == TaskStatus.archived;

      case TaskStatus.missed:
        // Transition from missed to waiting is valid only when edited/rescheduled
        return newStatus == TaskStatus.waiting ||
            newStatus == TaskStatus.completed ||
            newStatus == TaskStatus.archived;

      case TaskStatus.cancelled:
        return newStatus == TaskStatus.waiting ||
            newStatus == TaskStatus.archived;

      case TaskStatus.archived:
        return newStatus == TaskStatus.waiting;
    }
  }

  String toDbString() => name;

  static TaskStatus fromDbString(String? value) {
    if (value == null || value.isEmpty) return TaskStatus.waiting;
    return TaskStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => TaskStatus.waiting,
    );
  }
}
