# AndroidReminderScheduler_Changelog.md

## Version
v1.0.0

## Date
2026-08-07

## Author
Developer & Anti Gravity AI Assistant

## Type
- Feature
- Architecture
- Bug Fix
- Optimization

## Summary
`AndroidReminderScheduler` manages local push notifications and system alarm alerts on Android devices using `flutter_local_notifications`. This update introduced dual notification channels for standard notifications vs loud alarms, absolute UTC `AlarmManager` scheduling, persistent notification ID generation, and automatic alarm cleanup on task completion/deletion.

---

## Detailed Changes
- Configured two distinct Android notification channels on startup:
  1. `quick_notes_notification_channel_v3`: `Importance.high`, standard notification chime on Notification volume stream.
  2. `quick_notes_alarm_channel_v3`: `Importance.max`, `UriAndroidNotificationSound('content://settings/system/alarm_alert')`, `AudioAttributesUsage.alarm`, `fullScreenIntent: true` on Alarm volume stream.
- Implemented dynamic channel routing based on `task.reminderMode` (`off`, `notification`, `alarm`).
- Applied absolute UTC timezone rule (`tz.TZDateTime.from(task.reminderTime!.toUtc(), tz.UTC)`) to prevent local timezone database resolution failures and 5.5-hour offset delays.
- Generated deterministic persistent notification IDs (`task.notificationId`).
- Added automatic cancellation of scheduled alarms when tasks are completed or deleted.

---

## Why was this change made?
- Previous implementations used a single notification channel, preventing users from selecting standard heads-up notifications versus loud system alarms. Local timezone resolution issues also caused offset delays.

---

## Architecture Impact
- **System Integration**: Interfaces with Android `AlarmManager` and `NotificationManager`.
- **State Management**: Listens to `TaskEngine` events to trigger schedule, cancel, and snooze actions automatically.

---

## Files Created
- `lib/services/android_reminder_scheduler.dart`

---

## Files Modified
- `lib/models/task_item.dart`
- `lib/models/reminder_mode.dart`
- `lib/services/task_engine.dart`

---

## Dependencies Added
None.

---

## Breaking Changes
None.

---

## Migration Notes
Existing scheduled notifications are cleanly updated or cancelled during database migration.

---

## Future Improvements
- Custom alarm sound picker.
- Dynamic snooze duration configuration.

---

## Known Issues
None.

---

## Testing Status
- **Manual Tests**: Verified on physical device (`SM S918B`) across `Off`, `🔔 Notification`, and `⏰ Alarm` modes.
- **Automated Tests**: 95/95 unit tests passing.

---

## Final Result
`AndroidReminderScheduler` delivers exact-minute notification and alarm dispatching with dual-channel flexibility.
