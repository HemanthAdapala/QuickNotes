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
