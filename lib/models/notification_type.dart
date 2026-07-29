/// Payload entity types supported by notification payloads
enum NotificationType {
  task,
  note,
  calendar;

  String toTypeString() {
    return switch (this) {
      NotificationType.task => 'task',
      NotificationType.note => 'note',
      NotificationType.calendar => 'calendar',
    };
  }

  static NotificationType fromString(String? val) {
    if (val == null) return NotificationType.task;
    return switch (val.toLowerCase()) {
      'task' => NotificationType.task,
      'note' => NotificationType.note,
      'calendar' => NotificationType.calendar,
      _ => NotificationType.task,
    };
  }
}
