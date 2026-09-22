# AccountProfileScreen Changelog

This document serves as the permanent historical record and knowledge base for `AccountProfileScreen` (`lib/views/screens/account/account_profile_screen.dart`).

---

## [Phase 1.9.8.3A] - 2026-08-18

### Component Type
Screen / View Layer (`AccountProfileScreen`)

### Status
Implemented & Verified Green (62 automated tests passing, 0 analyzer issues)

### Architectural Context
- **Single Canonical Implementation**: Replaces previous stub `AccountProfileScreen` and unifies with `ProfileScreen` into a single, cohesive Apple-styled profile screen.
- **Accessible from**:
  1. `Settings` -> `Account` -> `Profile`
  2. `Settings` -> `Profile`
  3. `HomeScreen` -> Avatar / User greeting (if applicable)

### Key Features Implemented

1. **Dual State Rendering**:
   - **Offline Account State**:
     - Displays character avatar from `AvatarRegistry`.
     - "Change Photo" button reveals expandable 5-column avatar grid (`AvatarRegistry.allIds`).
     - Editable display name input tile (`GroupedTile.input`).
     - Read-only `Account Type: Offline` tile (`GroupedTile.keyValue`).
     - Explanatory card with `terms-info.svg`: *"Your notes are stored locally on this device."*
     - **Safety Invariant**: Zero fake email address, zero fake verified check badge.
   - **Google-Connected Account State**:
     - Displays authenticated Google profile photo via `Image.network` with graceful fallback to `AvatarRegistry` character avatars.
     - "Change Photo" button reveals expandable avatar selector if user wants a custom avatar instead of Google photo.
     - Editable display name input tile.
     - Read-only Google email input tile with official green `assets/icons/check.png` verified badge.
     - Read-only `Account: Google Connected` status tile.

2. **Persistence & Data Model Safety**:
   - Updates `SqliteProfileRepository` (`user_profiles` table in SQLite).
   - Synchronizes `UserRepository.currentUser` in-memory session.
   - Updates legacy `SharedPreferences` cache keys (`profile_username`, `profile_avatar_path`, `profile_email`).
   - Displays floating feedback SnackBar with check icon: *"Profile saved successfully"*.
   - **Identity Safety Invariant**: Never mutates `activeUserId`, `sessionType`, or `users.id`. Zero database migrations required.

### Verification Matrix
- **T-1 & T-2**: Account -> Profile opens smoothly with matching Apple aesthetics.
- **T-3, T-12, T-13**: Identity state preserved; canonical user ID strictly invariant.
- **T-4, T-5, T-6**: Offline profile renders local identity without fake emails or badges.
- **T-7, T-8, T-9**: Google profile renders verified badge, display name, and email.
- **T-10, T-11**: Google photo URL and fallback avatar handling.
- **T-15**: Unified canonical wrapper in `ProfileScreen`.
- **T-16**: Name editing and avatar selection saves to ProfileRepository.

---

## [v1.1.0] - 2026-09-22

### Component Type
Screen / View Layer (`AccountProfileScreen`)

### Status
Implemented & Verified Green (7 automated tests passing, 0 analyzer issues)

### Author
Anti Gravity

### Type
- Bug Fix
- UI
- Architecture

---

### Summary
Surgical remediation of BUG-001 (BUG A) — First-frame rendering stability of the `AppHeaderBar` Back button on `AccountProfileScreen` during Google Login / Restore Backup / Setup flow.

---

### Detailed Changes
- **Synchronous Header & Sheet Skeleton Mounting (Frame 0)**:
  - Moved the `_isLoading` conditional rendering check from wrapping the entire `Column` down into the White Rounded Sheet container (`Expanded` content area).
  - `AppHeaderBar` (including `BottomBarGlassSurface` and back button) now mounts synchronously on frame 0 during the `QuickNotesPageRoute` route transition.
  - The loading indicator (`CircularProgressIndicator`) is cleanly contained within the White Rounded Sheet during profile data retrieval.
- **BackdropFilter Texture Lifecycle Resolution**:
  - Eliminated the race condition where `BottomBarGlassSurface` mounted only after the 340ms route transition had already settled (`_routeAnimation!.isCompleted == true`), which previously caused the backdrop filter to sample an uninitialized/intermediate texture resulting in a dark/metallic button appearance.
  - Button renders with canonical Quick Notes glass styling from the very first visible frame without requiring user interaction/rebuild to settle.

---

### Why was this change made?
During the post-login setup and backup recovery flow, `AccountProfileScreen` rendered an uncalibrated dark/metallic circular back button on initial display that only snapped to the correct glass look after a tap on another control. The root cause was delayed mounting of `AppHeaderBar` after asynchronous data loading, which bypassed the route transition backdrop refresh listener.

---

### Architecture Impact
- Strictly local to `AccountProfileScreen` (`lib/views/screens/account/account_profile_screen.dart`).
- Zero changes to shared glass presets (`GlassmorphismPresets`), zero changes to `AppHeaderBar`, and zero changes to `BottomBarGlassSurface` or `TactileButton`.
- Adheres strictly to `QuickNotesUIConsistency` design guidelines.

---

### Files Created
- `test/views/bug_001_profile_audit_test.dart`

---

### Files Modified
- `lib/views/screens/account/account_profile_screen.dart`
- `Agents/skills/ChangeLogs Folder/AccountProfileScreen_Changelog.md`

---

### Dependencies Added
None.

---

### Breaking Changes
None.

---

### Migration Notes
None.

---

### Testing Status
- Static analysis: `flutter analyze lib/views/screens/account/account_profile_screen.dart`: 0 issues found (100% clean).
- Automated tests: `flutter test test/views/bug_001_profile_audit_test.dart`: 7/7 tests PASS.
- Regression tests: `test/views/app_header_bar_test.dart` (12/12 PASS), `test/views/first_run_recovery_screen_test.dart` (15/15 PASS).

---

### Final Result
`AccountProfileScreen` mounts `AppHeaderBar` on the first visible frame with the canonical glass Back button properly textured immediately, eliminating visual popping or interaction dependency.

