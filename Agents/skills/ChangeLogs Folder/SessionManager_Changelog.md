# SessionManager Changelog

---

## v1.2.1

### Date
2026-08-14

### Author
Anti Gravity

### Type
- Architecture
- Refactor
- Security

---

### Summary

Established `SessionManager` (`lib/services/session_manager.dart`) as the single active user ownership authority across the entire Quick Notes application. Removed synthetic default fallbacks (`usr_local_default`) and enforced strict canonical `OwnershipException` throwing on any unauthenticated or cross-user repository invocation.

---

### Detailed Changes

- **Canonical Active User Ownership Authority**:
  - `SessionManager.activeUserId` is established as the sole authority for active user identity.
- **Removed Synthetic Fallback**:
  - Completely eliminated implicit default fallbacks (`'usr_local_default'`) when `activeUserId` is null.
- **Ownership Exception Guard**:
  - Unauthenticated repository access now immediately throws domain `OwnershipException` / `NoActiveUserException`.
- **Session Lifecycle Cleardown**:
  - Logging out or switching sessions resets `SessionManager` state and clears in-memory provider caches cleanly.

---

### Why was this change made?

Implicit fallbacks silently allowed unauthenticated database operations to manipulate local user data. Hardening the ownership boundary guarantees that all reads and writes are explicitly associated with an active canonical user.

---

### Architecture Impact

- **Session Management**: Session state is strictly bounded and authoritative.
- **Security**: Cross-user data leakage is prevented at the repository layer.

---

### Files Created

None.

---

### Files Modified

- `lib/services/session_manager.dart`
- `lib/data/sqlite_profile_repository.dart`

---

### Dependencies Added

None.

---

### Breaking Changes

None.

---

### Migration Notes

All repositories resolve `SessionManager().activeUserId`. Tests and runtime flows initialize active sessions via `SessionManager().saveSession(...)`.

---

### Future Improvements

- Phase 1.6: Multi-account session switching and cloud auth integration.

---

### Known Issues

None.

---

### Testing Status

- **Manual Tests**: Verified login, logout, and session state persistence.
- **Automated Tests**: Passed dedicated test suite (`test/services/user_ownership_test.dart`).
- **Pending Tests**: None.
- **Known Edge Cases**: Session switch during active sync handled via exception guards.

---

### Final Result

`SessionManager` acts as the verified, secure ownership authority for all local persistence operations.
