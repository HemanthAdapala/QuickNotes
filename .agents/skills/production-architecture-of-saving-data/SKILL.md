---
name: production-architecture-of-saving-data
description: >-
  Architectural guidelines and 6-phase migration protocol for transitioning Flutter mobile apps
  from UI prototypes powered by mock data into a production-ready 4-tier data architecture
  (SQLite Data Source -> Repository Layer -> Reactive Providers -> UI Presentation). Enforces strict
  model independence, explicit non-destructive DB migrations, centralized statistics calculation,
  and comprehensive test verification.
---

# Production Architecture of Saving Data

## Overview
Use this skill whenever you need to convert a Flutter prototype (with hardcoded sample notes, mock tasks, or fake counters) into a production-ready, data-driven application backed by persistent storage.

It enforces a clean **4-Tier Architecture**, explicit **Database Migration Strategies**, independent **Domain Models**, and **Centralized Statistics Services**.

---

## Architectural Principles

```
┌─────────────────────────────────────────────────────────────┐
│                   Presentation Layer                        │
│   (Screens & Widgets: UI rendering & user interactions)     │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│                    State & Logic Layer                      │
│   (NotesProvider, TasksProvider, AppStatisticsService)      │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│                     Repository Layer                        │
│   (NotesRepository, TasksRepository, FoldersRepository)     │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│                      Data Source Layer                      │
│     (DatabaseService / SQLite DB, SharedPreferences)        │
└─────────────────────────────────────────────────────────────┘
```

1. **4-Tier Layer Separation**:
   - **Data Layer** (`DatabaseService`, `SharedPreferences`): Owns raw SQLite queries, table definitions, and migrations. Zero UI logic.
   - **Repository Layer** (`NotesRepository`, `TasksRepository`): Abstract interface and concrete SQLite repository classes between database and state providers. Allows future Cloud Sync, Backup/Restore, or AI Search Indexing.
   - **State Layer** (`NotesProvider`, `TasksProvider`): Exposes reactive application state, handles loading, and notifies listeners.
   - **Business Logic & Statistics Layer** (`AppStatisticsService`): Pure functions for calculating counts, totals, pending items, and date filtering outside of UI widgets.
   - **Presentation Layer**: UI widgets render prepared state. Zero business logic or statistics calculation inside build methods.

2. **Domain Model Independence**:
   - **Notes & Embedded Checklists**: Documents containing text, formatting, images, and inline checklist items. Inline checklist items remain embedded inside their parent `Note` document.
   - **Standalone Tasks**: Independent `TaskItem` objects (due dates, priority, completed state, reminder notifications) stored in a dedicated `tasks` SQLite table.
   - **Aggregation**: UI screens (e.g., `HomeScreen`) aggregate notes and tasks temporarily for display without blending underlying data models.

3. **Explicit Database Migration Strategy (vN → vN+1)**:
   - Always perform non-destructive incremental schema upgrades in `DatabaseService._onUpgrade`:
     ```dart
     if (oldVersion < 10) {
       await db.execute('''
         CREATE TABLE IF NOT EXISTS tasks(
           id TEXT PRIMARY KEY,
           title TEXT,
           description TEXT,
           dueDate TEXT,
           priority TEXT,
           completed INTEGER DEFAULT 0,
           createdAt TEXT,
           updatedAt TEXT,
           reminderTime TEXT
         )
       ''');
       await db.execute('CREATE INDEX IF NOT EXISTS idx_tasks_dueDate ON tasks(dueDate)');
       await db.execute('CREATE INDEX IF NOT EXISTS idx_tasks_completed ON tasks(completed)');
     }
     ```

---

## 6-Phase Migration Protocol

### Phase 1: Database Migration & Repository Layer Setup
1. Update `DatabaseService` to increment DB version and add explicit non-destructive `_onUpgrade` block.
2. Create repository interface and concrete classes in `lib/repositories/`:
   - `NotesRepository` (`getNotes()`, `insertNote()`, `updateNote()`, `deleteNote()`).
   - `TasksRepository` (`getTasks()`, `getTasksForDate()`, `insertTask()`, `updateTask()`, `deleteTask()`).
   - `FoldersRepository` (`getFolders()`, `insertFolder()`, `updateFolder()`, `deleteFolder()`).
3. Create `TasksProvider` in `lib/providers/tasks_provider.dart` for standalone task state and register in `MultiProvider` (`main.dart`).

### Phase 2: Replace Mock Notes & Dynamic Metrics
1. Connect `HomeScreen` and `SearchScreen` directly to `NotesRepository` & `NotesProvider`.
2. Compute folder note counts (`notes.where((n) => n.folderId == folder.id).length`) and category counts dynamically from live provider state.
3. Replace hardcoded fallback lists (`baseNotes = notesProvider.allActiveNotes;`) with clean empty states.

### Phase 3: Replace Mock Tasks with Persistent Tasks
1. Connect task views (e.g. `HomeScreen` task cards) to `TasksProvider`.
2. Wire task creation forms (`CreateTaskBottomSheet`, `CreateTaskScreen`) to call `tasksProvider.addTask(...)`.
3. Connect task completion checkboxes to `tasksProvider.toggleTaskCompletion(id)` with immediate SQLite persistence.

### Phase 4: Multi-Screen & Calendar Synchronization
1. Connect `CalendarScreen` to `tasksProvider.getTasksForDate(date)` and `notesProvider.allActiveNotes`.
2. Clean up mock task fallback models (`MockTask`, `_mockTasks`) across all calendar views.

### Phase 5: Centralized Statistics & Business Logic Service
1. Create `AppStatisticsService` (`lib/services/app_statistics_service.dart`) with static helper methods:
   - `calculateTotalNotes(List<Note> notes)`
   - `calculateTotalTasks(List<TaskItem> tasks)`
   - `calculateCompletedTasks(List<TaskItem> tasks)`
   - `calculatePendingTasks(List<TaskItem> tasks)`
   - `filterNotesByDateRange(List<Note> notes, String filter)`
   - `filterTasksByDateRange(List<TaskItem> tasks, String filter)`
2. Refactor UI screens to delegate filter and count logic to `AppStatisticsService`.

### Phase 6: Code Cleanup & Regression Verification
1. Delete obsolete mock classes, hardcoded initializers, and sample URL placeholders.
2. Execute test suite (`flutter test`) to verify 100% passing tests across state management, persistence, and UI rendering.

---

## Common Mistakes to Avoid

1. **Blending Notes and Standalone Tasks**: Never merge inline checklist items and standalone tasks into a single model.
2. **Calculating Statistics in UI Widgets**: Never calculate counts or filter lists directly inside `build()` methods or widget bodies; use `AppStatisticsService`.
3. **Hardcoding Fallback Lists**: Avoid `final notes = provider.notes.isEmpty ? _mockNotes : provider.notes;`. Display clean empty states when data is empty.
4. **Direct Database Calls in Providers**: Providers should depend on Repositories (`NotesRepository`, `TasksRepository`) rather than calling `DatabaseService` methods directly.
