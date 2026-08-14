# PullSync Changelog

---

## v1.8.0

### Date
2026-08-14

### Author
Anti Gravity

### Type
- Feature
- Architecture
- Testing

---

### Architectural Purpose

Engineered Phase 1.8 Pull Synchronization, Remote Change Application & Conflict Resolution. Establishes delta change ingestion, cursor-based pagination, topological dependency sorting, integer versioning conflict resolution, and crash-safe transaction boundaries.

---

### Files Created & Modified

- **Files Created**:
  - `lib/services/sync_conflict_resolver.dart` (Pure conflict matrix evaluation engine)
  - `lib/services/remote_change_applier.dart` (Topological batch sorting & atomic SQLite application bypassing outbox recording)
  - `lib/services/pull_sync_engine.dart` (Paginated pull loop & SharedPreferences cursor manager)
  - `test/services/remote_change_applier_test.dart` (6-scenario unit test suite)
  - `test/services/pull_sync_engine_test.dart` (4-scenario unit test suite)
  - `Agents/skills/ChangeLogs Folder/PullSync_Changelog.md`
- **Files Modified**:
  - `lib/services/sync_engine.dart` (Integrated PUSH -> PULL sequence in `flush()`)
  - `test/services/user_identity_unification_test.dart` (Updated test setup)

---

### Architectural Specifications

1. **Conflict Resolution Policy (`SyncConflictResolver`)**:
   - Clean local state: Apply remote payload directly. Set `version = remoteVersion` and `lastSyncedVersion = remoteVersion`.
   - Pending local create/update vs remote update: **Server Wins**. Apply remote payload, update `version` & `lastSyncedVersion`, and remove pending outbox item for `entityId`.
   - Pending local delete vs remote update: **Local Delete Wins**. Retain local outbox delete item. Ignore remote update.
   - Pending local update vs remote delete: **Server Delete Wins**. Mark local entity `isDeleted = 1` and remove pending outbox update row.
   - Stale remote change (`remoteVersion <= lastSyncedVersion`): Ignore (Idempotent No-op).
2. **Remote → Outbox Loop Prevention (`RemoteChangeApplier`)**:
   - Executes direct SQLite `runInTransaction((executor) => ...)` calls, completely bypassing standard repository mutation methods that record outbox events.
   - Zero `sync_outbox` items created during remote change application.
3. **Cursor Persistence (`PullSyncEngine`)**:
   - Cursor stored in `SharedPreferences` under `sync_cursor_<canonicalUserId>`.
   - Cursor key strictly isolated per canonical `usr_...` ID.
   - Cursor persisted **ONLY AFTER** SQLite transaction commits successfully.
   - Malformed response / HTTP 400 clears stored cursor and aborts cleanly.
4. **PUSH -> PULL Synchronization Sequence (`SyncEngine`)**:
   - `SyncEngine.flush()` executes Push phase first.
   - If Push phase completes without authentication failure, Pull phase runs immediately afterwards.

---

### Testing & Analysis Results

- **Dedicated Phase 1.8 Unit Tests**: Passed 10/10 tests cleanly.
- **Full Workspace Test Suite**: Passed 207/207 tests (100% GREEN).
- **Static Analysis (`flutter analyze`)**: Passed with zero errors.

---

### Explicit Scope Exclusions & Deferrals

- **No Database Schema Migrations**: Database remains at Schema Version 18.
- **No Concrete Cloud Backend**: Abstract `SyncNetworkClient` boundary preserved; zero vendor SDKs (Firebase/Supabase/REST/Dio/HTTP) introduced.
- **No Real-Time Sockets or Push Notifications**: Deferred to future real-time sync phases.
