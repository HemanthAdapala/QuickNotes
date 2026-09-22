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

---

## [v1.1.1] - 2026-09-22

### Component Type
Screen / View Layer (`AccountProfileScreen`)

### Status
Implemented & Verified Green (8/8 audit tests passing, 7/7 profile tests passing, 0 analyzer issues)

### Author
Anti Gravity

### Type
- UX / Navigation Clarification
- UI
- Bug Fix Follow-Up

---

### Summary
BUG-001 follow-up — Removed the Back button from `AccountProfileScreen` during the mandatory post-login setup flow (`isSetupFlow == true`), while strictly preserving the canonical glass Back button and pop navigation when accessed in standard flow (`isSetupFlow == false`).

---

### Detailed Changes
- **Conditional Back Button in AppHeaderBar**:
  - In `lib/views/screens/account/account_profile_screen.dart`, conditioned the leading slot parameters of `AppHeaderBar`:
    - `leftHeroTag: widget.isSetupFlow ? '' : 'hero_profile_back'`
    - `onLeftTap: widget.isSetupFlow ? null : ...`
    - `leftChild: widget.isSetupFlow ? null : SvgPicture.asset('assets/icons/angle_left.svg', ...)`
  - When `leftChild == null`, `AppHeaderBar` does not build or mount the `leftButton` or any `Hero` widget, leaving the left slot empty.
  - Symmetrical slot widths (`leftWidth: 44.0`, `rightWidth: 44.0`) ensure the "Profile" title remains centered without ad-hoc layout overrides.
- **Hero Tag Safety**:
  - Setting `leftHeroTag: ''` when `isSetupFlow == true` guarantees that no stale `Hero(tag: 'hero_profile_back')` widget is mounted in the widget tree, eliminating Hero collision or transition warnings.
- **Skip & Title Preservation**:
  - The right-aligned `Skip` button (`TactileButton`) and centered "Profile" title remain mounted on frame 0 and fully interactive during setup flow.
- **Normal Profile Flow Retention**:
  - When `isSetupFlow == false`, `leftChild`, `onLeftTap`, and `leftHeroTag: 'hero_profile_back'` remain intact, maintaining the canonical glass Back button.
- **BUG-A Workaround Evaluation**:
  - Back-button rendering complexity from BUG-001 is no longer applicable to setup flow because the button is not present.
  - The underlying synchronous `AppHeaderBar` mounting on frame 0 within `SafeArea` is retained because it stabilizes the "Profile" title, `Skip` button, sheet geometry, and normal flow Back button.

---

### Why was this change made?
During the mandatory linear onboarding flow (Google Login -> First Run Recovery -> Profile Setup), presenting a Back button is counter-intuitive and misleading because returning to the previous recovery/login step is not permitted. The intended UX for setup flow is `[no back button] Profile Skip`.

---

### Architecture Impact
- Strictly localized to `AccountProfileScreen` (`lib/views/screens/account/account_profile_screen.dart`).
- Zero changes to shared widgets (`AppHeaderBar`, `BottomBarGlassSurface`, `TactileButton`).
- Existing Google Connected layout resilience (single line, flush right, zero truncation) remains intact and verified.

---

### Files Modified
- `lib/views/screens/account/account_profile_screen.dart`
- `test/views/bug_001_profile_audit_test.dart`
- `test/views/account_profile_screen_test.dart`
- `Agents/skills/ChangeLogs Folder/AccountProfileScreen_Changelog.md`

---

### Dependencies Added
None.

---

### Breaking Changes
None.

---

### Testing Status
- Static analysis: `flutter analyze lib/views/screens/account/account_profile_screen.dart test/views/bug_001_profile_audit_test.dart test/views/account_profile_screen_test.dart`: 0 issues found (100% clean).
- Automated tests: `flutter test test/views/bug_001_profile_audit_test.dart`: 8/8 tests PASS.
- Regression tests:
  - `flutter test test/views/account_profile_screen_test.dart`: 7/7 tests PASS.
  - `flutter test test/views/app_header_bar_test.dart`: 12/12 tests PASS.
  - `flutter test test/views/first_run_recovery_screen_test.dart`: 15/15 tests PASS.

---

### Final Result
`AccountProfileScreen` displays `[no back button] Profile Skip` in setup flow without stale Hero tags, while preserving the canonical glass Back button and pop navigation in normal profile flows.


