What Milestone 3 should focus on

I would keep Milestone 3 focused on Actionable Notifications and Deep Linking.

Goal

Transform a passive notification into an interactive assistant.

Instead of:

🔔 Design Meeting

Today • 4:00 PM

Users should get:

🔔 Design Meeting

Today • 4:00 PM

✓ Mark Done

😴 Snooze

📖 Open
Scope
✅ In Scope
1. Open Task

Notification Tap

↓

Launch QuickNotes

↓

Open correct note

↓

Scroll to task

↓

Highlight task briefly

↓

Keyboard remains closed

2. Mark Done

Notification

↓

Tap ✓ Done

↓

TaskEngine.completeTask()

↓

Update database

↓

Update calendar

↓

Cancel notification

↓

Dismiss notification

No UI should be required.

3. Snooze

Options

5 minutes

15 minutes

30 minutes

1 hour

Tomorrow

Engine should

Cancel current reminder

↓

Update reminder time

↓

Schedule exactly one new reminder

4. Notification dismissal

If user swipes notification away

↓

Nothing happens

Task remains

Waiting

5. Deep Link

Notification payload

↓

Task ID

↓

Engine locates task

↓

Navigate safely

Even if the task no longer exists, the app should fail gracefully.

6. Foreground / Background behavior

Handle all cases:

App closed
App in background
App already open
Phone locked

Behavior should remain consistent.

❌ Out of Scope

Leave these for later milestones:

Recurring tasks
Smart snooze
Widgets
Wear OS
AI scheduling
Notification grouping
Rich attachments in notifications
Verification Checklist

Before calling Milestone 3 complete, I would test:

Notification tap opens the correct task.
Task is highlighted briefly.
"Mark Done" completes the task without opening the app.
"Snooze" creates exactly one new reminder.
Swiping away a notification leaves the task unchanged.
Multiple simultaneous notifications behave independently.
Notifications work whether the app is open, backgrounded, or closed.
Invalid or deleted task payloads are handled without crashes.