Milestone: Transition QuickNotes from Prototype to Production Data Architecture
Objective

The application has reached a stage where the UI and major interactions are largely complete.

From this milestone onward, I want to transition QuickNotes from a UI prototype powered by mock data into a fully data-driven application with a scalable architecture suitable for long-term development.

This milestone is not simply about replacing mock data.

Its primary goal is to establish a clean, maintainable architecture where every piece of information displayed throughout the application originates from a single persistent source of truth.

This architecture should serve as the foundation for all future features.

Primary Goals

Please perform a complete audit of the project and replace all mock/demo data with real persistent data.

At the same time, ensure the architecture remains clean, modular, scalable, and future-proof.

The implementation should avoid quick fixes that may introduce technical debt.

Architecture Principles

The application should follow a clear separation of responsibilities.

Data Layer

Responsible only for:

SQLite
Local storage
CRUD operations
Repository logic
Data persistence

No UI logic should exist here.

State Layer

Providers should only expose application state.

Responsibilities include:

Loading data
Updating state
Notifying listeners
Managing reactive UI updates

Providers should not contain complex business logic whenever possible.

Business Logic Layer

Filtering, statistics, counters, summaries, and derived information should live in dedicated helper/service classes rather than inside UI widgets.

Examples:

Total Notes
Total Tasks
Today's Notes
Today's Tasks
Folder Counts
Category Counts
Weekly Statistics
Monthly Statistics
Search Results

This keeps the UI lightweight and reusable.

Presentation Layer

Screens should only display data.

They should never calculate statistics or own business logic.

The UI should consume data already prepared by Providers or Services.

Single Source of Truth

There must be only one authoritative source for application data.

Every screen should consume data from the same persistence layer.

Avoid duplicate caches or multiple independent data models that can become inconsistent.

Notes and Tasks Must Remain Independent

This is an important architectural requirement.

Please do not merge Notes, Checklist Items, and standalone Tasks into a single model.

Although they may appear similar, they represent different concepts.

Notes

A Note is a document.

It may contain:

Rich text
Images
Checklists
Drawings
Tables
Attachments

Checklist items inside a note are part of that note's content.

They should remain embedded within the note.

Checklist Items

Checklist items belong exclusively to their parent note.

They are not standalone Tasks.

Do not convert checklist items into task objects simply because they have a completed state.

The note editor should remain responsible for checklist management.

Standalone Tasks

Standalone Tasks are a separate feature.

They may eventually support:

Due dates
Reminder notifications
Priority
Recurring schedules
Calendar integration
Status tracking
Future synchronization

These should remain an independent data model.

Aggregation

If a screen needs to display information from both Notes and Tasks together, create a temporary aggregated view instead of merging the underlying models.

For example:

Home Screen

may display:

Recent Notes
Today's Tasks

without storing them inside the same collection.

Remove All Mock Data

Perform a complete audit and remove every remaining instance of:

Mock repositories
Placeholder models
Demo notes
Demo tasks
Fake counters
Sample statistics
Temporary generators
Hardcoded lists
Fallback demo content

Fresh installations should display meaningful empty states instead of sample content.

Home Screen

Convert the Home Screen into a fully reactive dashboard.

Everything displayed should originate from persistent storage.

Examples include:

Recent Notes
Recent Tasks
Total Notes
Total Tasks
Completed Tasks
Pending Tasks
Folder Counts
Category Counts
Calendar Indicators

All counters should update automatically whenever underlying data changes.

Folder Architecture

Folder note counts should never be stored manually.

Instead, calculate them dynamically from existing notes.

Example:

Folder A

↓

Count notes where folderId == Folder A

This guarantees counts always remain accurate.

Category Architecture

Category counts should also be calculated dynamically.

Avoid storing category totals inside the database unless absolutely necessary.

Calendar

The Calendar should display actual persisted data.

For every selected date:

Notes saved on that date
Tasks scheduled for that date
Calendar indicators
Counts
Badges

All information should be derived from stored data.

Search

Search should query the real persistence layer.

Remove any remaining mock search implementation.

Search results should always reflect current saved data.

Statistics

Statistics should not be calculated inside UI widgets.

Instead create reusable helper methods or services.

Examples:

totalNotes()

totalTasks()

completedTasks()

notesForDate()

tasksForDate()

notesForRange()

tasksForRange()

recentNotes()

recentTasks()

This allows every screen to reuse the same logic.

Empty States

Instead of displaying sample data, create polished empty states.

Examples:

No Notes Yet
No Tasks Yet
Empty Folder
No Search Results
Nothing Scheduled Today

Provide intuitive guidance encouraging the user to create content.

Reactive Updates

Whenever any data changes:

Home Screen
Folder Screen
Calendar
Search
Categories
Statistics
Dashboard
Recent Notes
Recent Tasks

should update automatically.

There should never be inconsistent information between screens.

Persistence

All user-created data must persist across:

Screen navigation
Closing the editor
App restart
Future sessions

The application should always restore the latest saved state.

Future Scalability

While implementing this milestone, please design the architecture so future features can be added without major refactoring.

Examples include:

Archive
Trash
Pinning
Favorites
Labels
Notifications
Cloud Sync
Backup & Restore
AI Features
Search Indexing
Shared Notes
Collaboration
Version History

The architecture should support these naturally.

Code Quality

Please:

Remove obsolete code.
Remove unused mock classes.
Remove duplicate repositories.
Remove placeholder providers.
Avoid duplicated business logic.
Create reusable services where appropriate.
Follow existing project architecture and naming conventions.

The resulting codebase should be easier to maintain than the current prototype.

Deliverables

Please complete the following:

Audit the entire project for mock or placeholder data.
Remove all remaining mock implementations.
Replace them with persistent storage.
Ensure every screen consumes the same data source.
Separate Notes, Checklist Items, and Tasks into independent domain models.
Implement reusable statistics and filtering services.
Verify reactive updates across all screens.
Test persistence across navigation and app restarts.
Remove technical debt introduced during the prototyping phase.
Document any architectural changes made during this milestone.
Success Criteria

This milestone will be considered complete when:

No mock or placeholder data remains.
Every displayed value originates from persistent storage.
Notes, Checklist Items, and Standalone Tasks remain separate domain models.
Folder and Category counts are dynamically derived.
Statistics are centralized and reusable.
All screens remain synchronized automatically.
Data persists reliably across app restarts.
The architecture is scalable enough to support future features without requiring significant redesign.
One Additional Recommendation

Since you've already completed most of the UI, I'd ask Antigravity to implement this milestone incrementally rather than all at once. Have it tackle the architecture in phases:

Phase 1: Data architecture audit and cleanup.
Phase 2: Replace mock Notes with persistent Notes.
Phase 3: Replace mock Tasks with persistent Tasks.
Phase 4: Connect Home, Calendar, Folders, and Categories to real data.
Phase 5: Centralize statistics and filtering.
Phase 6: Final cleanup, optimization, and regression testing.

This phased approach makes debugging far easier and reduces the risk of introducing regressions while transforming the app from a prototype into a production-ready application.