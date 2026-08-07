enum ReminderMode {
  off,
  notification,
  alarm,
}

extension ReminderModeExtension on ReminderMode {
  String toDbString() {
    switch (this) {
      case ReminderMode.off:
        return 'off';
      case ReminderMode.notification:
        return 'notification';
      case ReminderMode.alarm:
        return 'alarm';
    }
  }

  static ReminderMode fromDbString(String? val) {
    switch (val?.toLowerCase()) {
      case 'notification':
        return ReminderMode.notification;
      case 'alarm':
        return ReminderMode.alarm;
      case 'off':
      default:
        return ReminderMode.off;
    }
  }
}
