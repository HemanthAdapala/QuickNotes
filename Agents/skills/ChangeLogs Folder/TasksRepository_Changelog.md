# TasksRepository Changelog

---

## v1.6.0

### Date
2026-08-14

### Author
Anti Gravity

### Type
- Feature
- Architecture
- Testing

---

### Summary

Engineered Phase 1.6 Entity Versioning & Sync Outbox Infrastructure in `SqliteTasksRepository` (`lib/repositories/tasks_repository.dart`). Wrapped all task write mutations (`insertTask`, `updateTask`, `trashTask`, `restoreTask`, `deleteTask`, `emptyTrash`) inside atomic transactions (`runInTransaction()`), enforcing `version = version + 1` increments, `updatedAt = DateTime.now()` freshness, and outbox event recording.

---

### Detailed Changes

- **Atomic Task Mutations**:
  - `insertTask`: Sets `version = 1`, `lastSyncedVersion = task.lastSyncedVersion`, updates `updatedAt`, and records `create` outbox event.
  - `updateTask`, `trashTask`, `restoreTask`: Increments `version = version + 1`, updates `updatedAt`, and records `update` outbox event.
- **Hard Delete Rule**:
  - `deleteTask` & `emptyTrash`: Evaluates `lastSyncedVersion`. If `lastSyncedVersion == 0`, purges task and removes pending outbox events; if `lastSyncedVersion > 0`, records `delete` outbox event.

---

### Testing Status

- **Automated Tests**: Passed 100% of workspace tests (158/158 tests passed).
