Task Engine Implementation (Milestone 1 — Core Task Lifecycle)
Objective

Implement the foundational Task Engine for QuickNotes.

The calendar UI, task cards, notification system, reminder scheduler, and future sync features must all interact with this engine.

The Task Engine becomes the single source of truth for every task.

The current UI should remain visually unchanged.

Only behavior should be implemented.

Architectural Goal

Separate

UI

↓

Task Engine

↓

Android Scheduler

↓

Notifications

Instead of

UI

↓

Notifications

Scope
IN

Task lifecycle

Task scheduling

Reminder scheduling

Persistence

State transitions

Notification scheduling

Notification cancellation

Task completion

Missed reminder detection

Timezone-safe scheduling

Recurring task foundation

Future actionable notifications

OUT

Cloud Sync

Shared Tasks

Collaboration

AI Scheduling

Natural language task creation

WearOS

Core Architecture

Create a dedicated TaskEngine.

The engine owns all task behavior.

No screen should schedule notifications directly.

The calendar should never know how reminders work.

It only displays task state.

Task Lifecycle

Every task has a lifecycle.

Created

↓

Scheduled

↓

Waiting

↓

Reminder Fired

↓

Completed

or

Created

↓

Scheduled

↓

Waiting

↓

Missed

↓

Completed

or

Created

↓

Cancelled
Task Model

Every task should contain

id

title

description

folderId

categoryId

createdAt

updatedAt

dueDate

startTime

endTime

priority

isCompleted

completedAt

reminderEnabled

reminderTime

notificationId

repeatRule

status

timezone

Notice

Notification ID

must already exist.

Future scheduling becomes trivial.

Reminder Scheduler

The Task Engine schedules reminders.

Never the UI.

Whenever

Create Task

↓

Edit Time

↓

Delete Task

↓

Complete Task

↓

Restore Task

↓

Repeat Task

The engine automatically updates Android reminders.

Reminder Rules

If reminder enabled

↓

Schedule notification.

If reminder disabled

↓

Cancel notification.

If task completed

↓

Cancel notification immediately.

If due time changes

↓

Cancel old reminder.

↓

Schedule new reminder.

Android Notification Behavior

Default reminder

🔔 QuickNotes

Design Meeting

Today • 4:00 PM

✓ Done

😴 Snooze

📖 Open

Actions

Mark Done

Snooze

Open

No custom alarm.

Use Android notification system.

Respect system sound settings.

Notification Actions
Mark Done

Immediately

Task Engine

↓

Task completed

↓

Cancel future reminder

↓

Update Calendar

↓

Update Home

↓

Dismiss notification

Snooze

Options

5 minutes

15 minutes

30 minutes

1 hour

Tomorrow

Engine updates reminder.

No duplicate notifications.

Open

Launch app.

Navigate directly to note.

Scroll to task.

Highlight task.

Keyboard remains closed.

Missed Reminders

When app launches

Task Engine scans

now > reminderTime

&&

task incomplete

&&

notification not fired

Mark

Missed

Optionally show

You missed

Doctor Appointment

Yesterday
Editing Tasks

Whenever

Title changes

↓

No notification reschedule.

Whenever

Reminder changes

↓

Reschedule.

Whenever

Date changes

↓

Reschedule.

Whenever

Time changes

↓

Reschedule.

Whenever

Delete

↓

Cancel reminder.

Task Completion

Completing a task should immediately

Update calendar indicators

Update task cards

Cancel reminder

Persist completion timestamp

Refresh notification state

Calendar Behavior

Calendar must never calculate task status.

It simply reads

Task Engine

↓

Task Status

Examples

Completed

Pending

Missed

Due Today

Overdue

Scheduled

Repeat Foundation

Store

None

Daily

Weekdays

Weekly

Monthly

Yearly

No implementation yet.

Only persistence.

Timezone Safety

Store all timestamps in UTC.

Convert only for display.

Never schedule using local string parsing.

Notification Channel

Create

QuickNotes Reminders

Importance

High

Default Android sound

Default vibration

Respect user settings.

Error Recovery

If Android kills app

↓

Reminder still fires.

If reboot

↓

Restore reminders.

If reminder exists but task deleted

↓

Cancel notification.

If notification tapped after task deleted

↓

Open app safely.

Future Compatibility

The Task Engine must already support

Recurring reminders

Location reminders

Widgets

WearOS

Cloud sync

Shared tasks

without architectural changes.

Verification Checklist

Creating a task schedules exactly one reminder.

Editing reminder reschedules exactly one reminder.

Completing task cancels reminder.

Deleting task cancels reminder.

Opening notification opens correct task.

Snoozing creates only one future reminder.

Calendar immediately reflects task completion.

Reboot restores reminders.

Timezone changes do not shift reminder incorrectly.

No duplicate reminders exist.

Task Engine is the only component scheduling reminders.

UI contains zero reminder logic.