/// Action types supported by notifications
enum NotificationAction {
  open,
  done,
  snooze;

  String toActionString() {
    return switch (this) {
      NotificationAction.open => 'open',
      NotificationAction.done => 'done',
      NotificationAction.snooze => 'snooze',
    };
  }

  static NotificationAction? fromString(String? val) {
    if (val == null) return null;
    return switch (val.toLowerCase()) {
      'open' || 'action_open' => NotificationAction.open,
      'done' || 'action_done' => NotificationAction.done,
      'snooze' || 'action_snooze' => NotificationAction.snooze,
      _ => null,
    };
  }
}
