# UserIdentityRepository Changelog

---

## v1.7.1

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

Engineered `UserIdentityRepository` and `SqliteUserIdentityRepository` (`lib/repositories/user_identity_repository.dart`) for Phase 1.7.1 Canonical User Identity Unification. Provides atomic CRUD operations for `users` and `user_identities` SQLite tables, enforcing mapping between external provider account IDs (Google UID) and canonical Quick Notes user IDs (`usr_...`).

---

### Detailed Changes

- **Repository Interface & Implementation**:
  - `findIdentity(provider, providerUserId)`: Queries `user_identities` table for existing provider linkage.
  - `findUserById(id)`: Queries `users` table by canonical user ID.
  - `updateLastAuthenticatedAt(identityId, timestamp)`: Updates `lastAuthenticatedAt` timestamp.
  - `createCanonicalUserWithIdentity(...)`: Atomically creates `User` (`usr_<uuid>`), `UserIdentity`, and `UserProfile` inside `DatabaseService.instance.runInTransaction()`.

---

### Testing Status

- **Automated Tests**: Passed 100% of workspace tests (166/166 tests passed).

---

## v1.9.8.1

### Date
2026-08-18

### Author
Developer / Anti Gravity

### Type
- Feature
- Architecture
- Testing

---

### Summary

Implemented in-place identity linking infrastructure for `UserIdentityRepository` and `SqliteUserIdentityRepository` (`lib/repositories/user_identity_repository.dart`) and created `IdentityLinkResult` domain model (`lib/models/identity_link_result.dart`). Enables active offline users (`usr_local_A`) to link Google OAuth credentials (`google_uid_X`) in-place without data migration, re-keying, or canonical ID change, while enforcing strict collision rejection and transaction rollback safety.

---

### Detailed Changes

- **Domain Result Model (`lib/models/identity_link_result.dart`)**:
  - Defined `enum IdentityLinkStatus { linked, alreadyLinked, conflict, userNotFound, alreadyLinkedToDifferentIdentity, failure }`.
  - Added factory constructors: `IdentityLinkResult.linked(...)`, `IdentityLinkResult.alreadyLinked(...)`, `IdentityLinkResult.conflict(...)`, `IdentityLinkResult.userNotFound(...)`, `IdentityLinkResult.alreadyLinkedToDifferentIdentity(...)`, and `IdentityLinkResult.failure(...)`.
  - Added `isSuccess` and `isConflict` property getters.
- **Repository Interface & SQLite Implementation (`lib/repositories/user_identity_repository.dart`)**:
  - Added `findIdentityForUser(userId, provider)` to query existing provider credentials for a given user.
  - Implemented `linkIdentityToActiveUser(...)` with atomic SQLite transaction execution:
    1. Validates `activeUserId` exists in `users` table.
    2. Validates user is not already linked to a different provider identity.
    3. Detects identity collisions with other users and returns `IdentityLinkStatus.conflict` with 0 mutations.
    4. Handles idempotency: returns `IdentityLinkStatus.alreadyLinked` if the exact provider identity is already linked to the same user.
    5. Executes atomic transaction inserting `user_identities`, updating `users.isOffline: 1 -> 0`, and updating `user_profiles` while preserving custom display names.
    6. Complete transaction rollback if any step throws.

---

### Testing Status

- **Automated Tests**:
  - `test/services/offline_identity_linking_test.dart`: 10/10 PASS (100% GREEN)
  - `test/services/user_identity_unification_test.dart`: 8/8 PASS (100% GREEN)
  - `test/services/recovery/`: 36/36 PASS (100% GREEN)
  - `test/controllers/first_run_recovery_controller_test.dart`: 13/13 PASS (100% GREEN)
  - `test/views/first_run_recovery_screen_test.dart`: 15/15 PASS (100% GREEN)
  - Backup & Restore regression suite: 53/53 PASS (100% GREEN)
  - Static analysis (`flutter analyze`): 0 issues across all files.

