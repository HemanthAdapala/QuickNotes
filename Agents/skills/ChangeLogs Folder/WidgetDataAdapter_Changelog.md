# WidgetDataAdapter Changelog

## 2026-08-28 — Initial Implementation (Phase W2)

### Changes
- Implemented `WidgetDataAdapter` singleton service in `lib/services/widget_data_adapter.dart`.
- Built sanitized aggregate snapshot generator (`buildSnapshot`) adhering to strict data minimization.
- Implemented security filters: unconditionally excluding locked notes (`isLocked == true`), deleted notes (`isDeleted == true`), and archived notes (`isArchived == true`).
- Implemented task aggregation calculations: calculating active tasks due today and overdue tasks using local timezone windows.
- Integrated `home_widget` platform bridge for writing `quicknotes_widget_snapshot` JSON payload and triggering native widget timeline reloads.
- Built error isolation ensuring widget synchronization failures never disrupt database mutations or throw exceptions to callers.
- Added `clearSnapshot()` for immediate reset on user logout / account wipe.
- Hooked `WidgetDataAdapter.instance.sync` into `NotesProvider` and `TasksProvider`.
- Created comprehensive unit tests in `test/services/widget_data_adapter_test.dart`.

## 2026-08-30 — Phase T1: Task Widget Snapshot Model & Serialization

### Changes
- **SingleTaskSnapshot Model Implementation:**
  - Implemented immutable `SingleTaskSnapshot` model in `lib/models/single_task_snapshot.dart`.
  - Preserved exact task data fidelity (title, description, status, due date, due time, priority, recurrence) without artificial content mutation.
  - Derived canonical completion (`completed` boolean, `statusLabel` `'Completed'` vs `'Pending'`) from `TaskStatus`.
  - Formatted localized date (`"Tue, 1 June 2026"`) and localized time (`"02:00 AM"`) with time resolution hierarchy (`reminderTime > startTime > dueDate`).
  - Normalized priority levels (`'High'`, `'Medium'`, `'Low'`, `'None'`) and human-readable recurrence labels (`'Daily'`, `'Weekdays'`, `'Weekly'`, `'Monthly'`, `'Yearly'`).
  - Added lightweight catalog serializer `toCatalogEntry()` for configuration screens and full JSON map serialization.
- **WidgetDataAdapter Extension:**
  - Extended `WidgetDataAdapter.sync()` to serialize `quicknotes_tasks_catalog` and `quicknotes_tasks_map` into `HomeWidgetPreferences`.
  - Enforced strict privacy and security filtering: excluded deleted (`isDeleted == true`) and archived (`status == TaskStatus.archived`) tasks.
  - Extended `clearSnapshot()` to wipe task catalog and map upon user logout or session reset.
  - Added trigger updates for upcoming `SingleTaskWidget` and `MultiTaskWidget`.
- **Testing & Verification:**
  - Created comprehensive test suite in `test/services/task_widget_snapshot_test.dart` (8 tests covering snapshot creation, title preservation, status derivation, date/time resolution hierarchy, priority normalization, recurrence mapping, round-trip JSON serialization, and catalog generation).
  - Updated `test/services/widget_data_adapter_test.dart` verifying task catalog & map synchronization and session clearing.
  - 54/54 automated tests passing (100% green).
  - Clean static analysis (`flutter analyze` = 0 issues).

## 2026-08-30 — Phase T3: Single Task Long Widget Provider Integration

### Changes
- **Provider Registration & Timeline Updates:**
  - Added `singleTaskLongWidgetName = 'SingleTaskLongWidget'` constant to `lib/services/widget_data_adapter.dart`.
  - Extended `WidgetDataAdapter.sync()` and `clearSnapshot()` to include `SingleTaskLongWidget` in native platform widget update broadcasts.
- **Testing & Verification:**
  - Updated `test/services/widget_data_adapter_test.dart` to verify `SingleTaskLongWidget` is included in all widget update calls.
  - 39/39 focused tests passing (100% green).
  - Clean static analysis (`flutter analyze` = 0 issues).

