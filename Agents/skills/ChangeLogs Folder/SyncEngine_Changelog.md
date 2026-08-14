# SyncEngine Changelog

---

## v1.7.3

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

Engineered `SyncEngine` (`lib/services/sync_engine.dart`) as the central orchestration service responsible for pushing local durable outbox mutations (`sync_outbox`) through the provider-agnostic `SyncNetworkClient` boundary.

---

### Files Created & Modified

- **Files Created**:
  - `lib/services/sync_engine.dart` (`SyncEngine` orchestration service)
  - `test/services/sync_engine_test.dart` (10-scenario unit test suite)
- **Files Modified**:
  - `lib/repositories/outbox_repository.dart` (Added `acknowledgeOutboxItem` and `updateOutboxItemRetryStatus` methods)

---

### Architectural Specifications

1. **Queue Behavior**:
   - Queries `sync_outbox WHERE userId = activeUserId AND status = 'pending' ORDER BY localSequence ASC`.
   - Processes mutations sequentially (single-item FIFO).
2. **Retry Strategy & Backoff**:
   - Exponential backoff: $\text{delay} = \min(\text{initialDelay} \times 2^{\text{attemptCount}} + \text{jitter}, \text{maxDelay})$.
   - Parameters: `initialDelay` = 2s, `multiplier` = 2.0, `maximumDelay` = 300s, `maxAttempts` = 10.
   - When `attemptCount >= maxAttempts`, updates `status = 'failed'` without deleting row.
3. **ACK Behavior & Atomicity**:
   - On `SyncAckStatus.acknowledged` or `SyncAckStatus.stale`: Executes `outboxRepo.acknowledgeOutboxItem(...)` inside a single SQLite transaction (`DatabaseService.instance.runInTransaction()`), updating `lastSyncedVersion = localVersion` and deleting the outbox item atomically.
4. **Authentication Pause**:
   - On `SyncNetworkErrorType.authenticationFailure` (401/403): Transitions state to `pausedAuthentication`. Pauses queue immediately without incrementing attempt count or deleting outbox row.
5. **Session Isolation**:
   - Scopes queries strictly to `SessionManager.activeUserId` (`usr_...`).
   - Verifies `activeUserId` prior to every item dispatch. On logout or user switch, aborts active flush immediately.
6. **Crash Recovery & Idempotency**:
   - Preserves `SyncOutboxItem.operationId` immutably across retries, app restarts, and process crashes.
   - On app restart, picks up pending outbox items and resumes FIFO processing.

---

### Testing Results

- **Dedicated Phase 1.7.3 Unit Tests**: Passed 10/10 tests cleanly.
- **Full Workspace Test Suite**: Passed 186/186 tests (100% GREEN).
- **Static Analysis (`flutter analyze`)**: Passed without errors.

---

### Known Limitations & Explicit Phase 1.8 Deferrals

- **Push Only**: Pull change synchronization, remote change reconciliation, and conflict resolution are deferred to Phase 1.8.
- **No Platform Connectivity Listeners**: Automatic platform network monitoring is deferred.
- **No Concrete Cloud SDK**: Abstract `SyncNetworkClient` contract preserved; zero vendor SDKs (Firebase/Supabase/REST) introduced.
- **No Database Schema Migrations**: Database remains at Schema Version 18.
