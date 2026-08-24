# AccountController Changelog

---

## v1.0.0 — Phase 1.9.8.2

### Date
2026-08-18

### Author
Antigravity Engine

### Type
- Feature
- Architecture
- Security
- Integration
- Testing

---

### Summary

Implemented `AccountController` and integrated `AccountSettingsScreen` for Phase 1.9.8.2 (Offline User → Sign-In-Later Account Flow). Enables users who initially chose "Continue Offline" to sign in with Google later from Settings → Account, preserving all local notes, folders, and tasks in-place without re-keying or migration, while validating First-Run Recovery eligibility and handling identity collisions safely.

---

### Detailed Changes

- **AccountController (`lib/controllers/account_controller.dart`)**:
  - Implements `AccountUiState` (`idle`, `signingIn`, `conflict`, `error`).
  - Implements `AccountLinkResult` with `AccountLinkAction` (`success`, `navigateToRecovery`, `conflict`, `cancelled`, `error`).
  - `signInWithGoogle()`:
    - Protected by concurrency guard (`_isSigningIn`) to prevent double-tap race conditions.
    - Coordinates `AuthenticationService`, `UserIdentityService.linkGoogleIdentityToActiveUser()`, `SessionManager`, `UserRepository`, and `FirstRunRecoveryDetector`.
    - Handles Google sign-in cancellation and user cancellations cleanly.
    - Resolves identity conflict / collision without database mutations, returning `AccountLinkAction.conflict`.
    - Updates `SessionManager` and `UserRepository` on linking success (`SessionType.google`).
    - Executes fail-safe `FirstRunRecoveryDetector.checkEligibility()`; non-blocking on network errors.
  - `cancelConflict()`: Resets state to `AccountUiState.idle`, leaving active offline session intact.
  - `switchAccountToConflictingUser()`: Safely transitions active session to the existing Google account (`usr_google_B`) while preserving the offline user (`usr_local_A`) stored on disk.
  - Error sanitization: Sanitizes internal error messages preventing file paths, auth tokens, database credentials, or stack traces from reaching the UI.

- **AccountSettingsScreen (`lib/views/screens/account/account_settings_screen.dart`)**:
  - Supports dependency injection of `AccountController` for testing and production lifecycle.
  - Renders **State A (Offline Account)**:
    - Offline Account indicator banner with `CloudOff` badge.
    - Explanatory copy: *"Your notes are stored on this device. Sign in with Google to enable cloud backup and restore."*
    - Tactile "Sign in with Google" button with native Google G-logo and loading indicator state.
  - Renders **State B (Google Connected Account)**:
    - User avatar / profile image, display name, and verified email.
    - "Google Account Connected" badge with verified checkmark.
  - Implements modal conflict dialog on account collision with explicit `[ Switch Account ]` and `[ Cancel ]` actions.
  - Navigates to `FirstRunRecoveryFlow` on `AccountLinkAction.navigateToRecovery`.
  - Disables interactive triggers while signing in to prevent double-tap mutations.

- **Test Suite**:
  - `test/controllers/account_controller_test.dart` covering unit test scenarios T-1 through T-20.
  - `test/views/account_settings_screen_test.dart` covering widget test scenarios T-21 through T-32.

---

### Invariants & Guarantees

1. **Zero Data Migration / In-Place Preservation**: Canonical user ID (`usr_local_A`) is preserved across linking. Zero modifications to `notes`, `folders`, `tasks`, or `attachments` rows.
2. **Zero Cross-User Leakage**: Identity collisions do not overwrite or merge local notes. Conflicting Google identities present user confirmation dialog.
3. **Fail-Safe Non-Blocking Recovery**: Google Drive errors during eligibility check never block sign-in or trap users.
4. **Clean Navigation Decoupling**: Controller contains 0 Flutter widget / Navigator references.
