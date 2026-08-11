Do not implement notifications first.

Notifications are only the final output of the Task Engine.

We must first build a robust Task Engine responsible for task lifecycle, scheduling, state transitions, persistence, recurring logic, and notification generation.

The notification system must become a consumer of the Task Engine rather than containing business logic itself.

The calendar UI, task cards, notification actions, widgets, and future smartwatch integrations must all communicate exclusively through the Task Engine.


Task State Diagram:- 

Created
      │
      ▼
Scheduled
      │
      ▼
Waiting
      │
 ┌────┴────┐
 ▼         ▼
Completed  Missed
      │
      ▼
Archived

And define invalid transitions like:

Completed → Waiting ❌
Cancelled → Reminder Fired ❌
Missed → Waiting ❌ (unless edited)

Having this state machine documented makes the engine much easier to reason about and test.

Milestone 1: Task Engine & data lifecycle (no notifications yet).
Milestone 2: Android reminder scheduling and notification delivery.
Milestone 3: Actionable notifications (Done, Snooze, Open).
Milestone 4: Recurring tasks, reboot recovery, missed reminders, timezone handling.
Milestone 5: Polish (notification grouping, deep linking, widgets, Wear OS readiness).


