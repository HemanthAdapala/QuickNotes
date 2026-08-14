# FoldersRepository Changelog

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

Engineered Phase 1.6 Entity Versioning & Sync Outbox Infrastructure in `SqliteFoldersRepository` (`lib/repositories/folders_repository.dart`). Wrapped all folder operations (`insertFolder`, `updateFolder`, `trashFolder`, `restoreFolder`, `deleteFolder`) inside atomic transactions (`runInTransaction()`). Implemented topological cascade traversal for folder hierarchy mutations, incrementing version counters for all mutated folders and descendant notes while appending corresponding outbox events in strict parent-to-child sequence.

---

### Detailed Changes

- **Atomic Folder Mutations**:
  - `insertFolder`: Sets `version = 1` and records `create` outbox event.
  - `updateFolder`: Increments `version = version + 1` and records `update` outbox event.
- **Topological Cascade Mutations**:
  - `trashFolder`: Traverses descendant folders via breadth-first search (BFS). Updates target folder, descendant subfolders, and active child notes inside `runInTransaction()`, assigning incremented version counters and creating topological outbox events (`Folder A` -> `Folder B` -> `Folder C` -> `Note X`).
  - `restoreFolder`: Restores target folder, descendant subfolders, and child notes where `trashedByFolderId == id`, assigning incremented version counters and creating outbox events.
- **Hard Delete Rule**:
  - `deleteFolder`: Evaluates `lastSyncedVersion` for each folder and child note. If `lastSyncedVersion == 0`, silently purges entity and pending outbox records; if `lastSyncedVersion > 0`, records a `delete` outbox event.

---

### Testing Status

- **Automated Tests**: Passed 100% of workspace tests (158/158 tests passed).
