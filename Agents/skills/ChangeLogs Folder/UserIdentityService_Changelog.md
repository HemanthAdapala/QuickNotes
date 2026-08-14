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
