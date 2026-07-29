Milestone 2 — Android Notification Integration
Goal

Replace the LoggingReminderScheduler with a real Android implementation.

When a task is created:

TaskEngine
        ↓
ReminderScheduler
        ↓
AndroidReminderScheduler
        ↓
flutter_local_notifications
        ↓
Android Notification

The TaskEngine should remain completely unchanged.

Scope
✅ In Scope
1. AndroidReminderScheduler

Implement:

scheduleReminder(TaskItem)

cancelReminder(notificationId)

initialize()
2. Notification permissions

Android 13+

Request notification permission only once.

3. Notification channels

Example

QuickNotes Tasks

Importance.high

Default sound

Vibration
4. Exact scheduling

Support

July 16

5:30 PM

↓

notification at exactly 5:30 PM
5. Cancel notification

Deleting task

↓

cancel notification

6. Editing reminder

Old notification

↓

cancel

↓

new notification

7. Boot persistence

After reboot

Engine.initialize()

↓

load tasks

↓

schedule future reminders

Only future reminders.

Not missed ones.

8. Timezone support

Milestone 1 already stores

timezone

Now actually use it.

Out of Scope

Do NOT implement

❌ Snooze

❌ Action buttons

❌ Complete button

❌ Mark done

❌ Repeat

❌ Alarm UI

❌ Widgets

❌ Background sync

Keep Milestone 2 laser-focused.

Manual Verification

The milestone isn't complete until all of these pass:

Create a reminder for 2 minutes in the future → notification appears exactly on time.
Edit the reminder time → old notification is cancelled, new one is scheduled.
Delete the task → notification never appears.
Complete the task → notification is cancelled.
Restart the app → future reminders are rescheduled.
Restart the phone → reminders are restored (if boot receiver support is included in this milestone).
Multiple reminders scheduled for different times all fire correctly.
Notifications respect the device's local timezone.