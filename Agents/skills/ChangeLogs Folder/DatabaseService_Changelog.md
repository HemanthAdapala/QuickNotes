# DatabaseService Changelog

---

## v1.6.0

### Date
2026-08-14

### Author
Anti Gravity

### Type
- Feature
- Database
- Architecture

---

### Summary

Engineered the Phase 1.6 Database Schema v18 Upgrade for `DatabaseService` (`lib/services/database_service.dart`). Introduced `version INTEGER NOT NULL DEFAULT 1` and `lastSyncedVersion INTEGER NOT NULL DEFAULT 0` columns to `notes`, `folders`, and `tasks` tables. Created the `sync_outbox` table with single SQLite rowid autoincrement primary key (`localSequence INTEGER PRIMARY KEY AUTOINCREMENT`) and unique constraints on `id` and `operationId`. Added performance indexes `idx_outbox_userId_status` and `idx_outbox_entity`.

---

### Detailed Changes

- **Schema Version Upgrade (v17 -> v18)**:
  - Added `version` and `lastSyncedVersion` columns to `notes`, `folders`, `tasks` via DDL `ALTER TABLE ... ADD COLUMN` in `_onUpgrade` and directly in `_onCreate`.
- **`sync_outbox` Table DDL**:
  - `localSequence INTEGER PRIMARY KEY AUTOINCREMENT`
  - `id TEXT NOT NULL UNIQUE`
  - `operationId TEXT NOT NULL UNIQUE`
  - `userId TEXT NOT NULL`, `entityType TEXT NOT NULL`, `entityId TEXT NOT NULL`, `operation TEXT NOT NULL`, `payload TEXT NOT NULL`, `localVersion INTEGER NOT NULL`, `createdAt TEXT NOT NULL`, `attemptCount INTEGER NOT NULL DEFAULT 0`, `status TEXT NOT NULL DEFAULT 'pending'`, `lastAttemptAt TEXT`, `nextAttemptAt TEXT`, `lastError TEXT`.
- **Outbox Performance Indexes**:
  - `CREATE INDEX IF NOT EXISTS idx_outbox_userId_status ON sync_outbox(userId, status)`
  - `CREATE INDEX IF NOT EXISTS idx_outbox_entity ON sync_outbox(entityType, entityId)`
- **Exception Passthrough**:
  - Updated `runInTransaction()` catch handler to rethrow `OwnershipException` directly without wrapping inside `DatabaseTransactionException`.

---

### Why was this change made?

To establish entity versioning counters and local mutation sequencing infrastructure required for offline-first operation and cloud synchronization (Phase 1.6).

---

### Architecture Impact

- **Database Layer**: SQLite schema v18 now stores local version counters on all content entities and hosts the append-only `sync_outbox` mutation queue.

---

### Breaking Changes

None. Non-destructive `ALTER TABLE` upgrades existing v17 databases to v18 automatically.

---

### Testing Status

- **Automated Tests**: 100% GREEN across workspace unit/integration test suite (158/158 tests passed).

---

## v1.5.0

### Date
2026-08-14

### Author
Anti Gravity

### Type
- Feature
- Refactor
- Architecture
- Database

---

### Summary

Engineered the Phase 1.1 through Phase 1.5 Database Safety & Repository Consistency Architecture for `DatabaseService` (`lib/services/database_service.dart`). Upgraded SQLite schema to v15 to support canonical `users`, `user_profiles`, and `user_identities` tables, implemented soft-delete tombstone cascading (`isDeleted`, `deletedAt`, `trashedByFolderId`), added atomic transaction wrapping via `runInTransaction()`, and enforced SQL-level user ownership scoping (`WHERE userId = ?`) across all data retrieval queries.

---

### Detailed Changes

- **SQLite Schema Migration to v15**:
  - Added `users` table (`id`, `createdAt`, `updatedAt`).
  - Added `user_profiles` table (`userId`, `fullName`, `username`, `email`, `avatarPath`, `createdAt`, `updatedAt`).
  - Added `user_identities` table (`id`, `userId`, `provider`, `providerUserId`, `createdAt`, `updatedAt`).
- **Data Lifecycle & Tombstone Columns**:
  - Added `isDeleted`, `deletedAt`, `trashedByFolderId` columns to `notes`, `folders`, and `tasks` tables.
- **SQL Ownership Scoping**:
  - Updated `queryNotesSummaryPaged()` and `queryHabits()` to accept `String? userId` and execute `WHERE userId = ?` directly inside SQLite queries.
- **Generic SQLite & Transaction Authority**:
  - Kept `DatabaseService` focused purely on generic SQLite query execution, DDL migrations, integrity checks, and atomic transactions via `runInTransaction()`.

---

### Why was this change made?

To establish a production-grade database foundation prior to multi-device sync and cloud persistence (Phase 1.6). Bypassing SQLite query scoping in memory or using direct database calls outside repository contracts compromised user data isolation and data mutation consistency.

---

### Architecture Impact

- **Database Layer**: SQLite remains the authoritative, single source of truth for all local data mutations.
- **Security & Multi-Tenancy**: Data queries enforce active user isolation at the SQL engine level.
- **Transaction Safety**: All multi-step or cascading mutations execute inside atomic SQLite transactions.

---

### Files Created

- `lib/models/user.dart`
- `lib/models/user_identity.dart`
- `lib/models/database_integrity_result.dart`
- `lib/services/database_exceptions.dart`

---

### Files Modified

- `lib/services/database_service.dart`
- `lib/models/note.dart`
- `lib/models/folder.dart`
- `lib/models/task_item.dart`

---

### Dependencies Added

None.

---

### Breaking Changes

None. Existing legacy databases auto-migrate to schema v15 seamlessly.

---

### Migration Notes

Automatic schema migration to v15 runs on database open. Upgrades legacy profiles and backfills canonical user records without data loss.

---

### Future Improvements

- Phase 1.6: Entity versioning, revision counters, and `sync_outbox` table.
- Phase 1.7: Change log stream and Sync Engine integration.

---

### Known Issues

None.

---

### Testing Status

- **Manual Tests**: Verified profile loading, notes summary pagination, and habit tracking.
- **Automated Tests**: 100% GREEN across workspace unit/integration test suite (151 tests passed).
- **Pending Tests**: None.
- **Known Edge Cases**: Handled null active sessions via `OwnershipException`.

---

### Final Result

`DatabaseService` provides a safe, user-scoped, atomic SQLite foundation fully verified for production use.
