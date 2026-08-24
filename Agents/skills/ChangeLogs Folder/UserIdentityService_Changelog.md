# UserIdentityService Changelog

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

Engineered `UserIdentityService` (`lib/services/user_identity_service.dart`) as the single authority for resolving external provider credentials (Google account ID) to canonical Quick Notes user IDs (`usr_...`).

---

### Detailed Changes

- **Canonical User Resolution**:
  - `getOrCreateCanonicalUser(...)`: Evaluates whether a mapping exists in `user_identities`.
  - **Case A (Existing Identity)**: Returns existing `userId` (canonical `usr_...`) and updates `lastAuthenticatedAt`.
  - **Case B (New Google Identity)**: Atomically creates a new `User` (`usr_<uuid>`), `UserIdentity`, and `UserProfile` inside `runInTransaction()` and returns the new canonical `userId`.

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

Added `linkGoogleIdentityToActiveUser(...)` to `UserIdentityService` (`lib/services/user_identity_service.dart`). Serves as the single domain authority for promoting active offline users (`usr_local_...`) to Google-authenticated users in-place without altering canonical user IDs, migrating data, or re-keying relational records.

---

### Detailed Changes

- **In-Place Identity Linking (`linkGoogleIdentityToActiveUser`)**:
  - Accepts `activeUserId`, `googleId`, `email`, `displayName`, and `photoUrl`.
  - Delegates to `UserIdentityRepository.linkIdentityToActiveUser(activeUserId: activeUserId, provider: 'google', providerUserId: googleId, ...)`.
  - Returns strongly-typed `IdentityLinkResult` preserving all core offline-to-online invariants.

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

