# SettingsScreen Changelog

---

## v2.9.0

### Date
2026-08-13

### Author
Anti Gravity

### Type
- Feature
- UI
- Refactor
- Architecture

---

### Summary

Redesigned the Settings Screen (`lib/views/screens/settings_screen.dart`) matching the new floral top header design mockup (`assets/Settings Screen/Background.svg`), featuring an overlapping circular Profile Avatar layout, user display name & handle header, and 4 clean `GroupedListContainer` card sections (including a dedicated 4th section for all testing/developer screens).

---

### Detailed Changes

- **Top Decorative Background**: Integrated `assets/Settings Screen/Background.svg` as top floral header banner behind `AppHeaderBar`.
- **Overlapping Profile Avatar & Static Header**: Positioned 90x90 white avatar circle directly over seam line, pinning floral header, avatar, name, and email handle in a static top header block.
- **Two-Line User Details**: Rendered display name (`Hemanth A`) on line 1, and handle/email (`@fakehemanth20@gmail.com`) on line 2.
- **Bottom Frosted Blur Edge**: Added glassmorphic gradient blur overlay (`BackdropFilter` + `LinearGradient`) at the bottom edge so cards dissolve smoothly when scrolling above navigation dock.
- **Fixed Asset Icons**: Resolved asset icon paths across all 4 `GroupedListContainer` sections.
- **Account Multi-Screen Navigation Flow**:
  - `AccountSettingsScreen`: Main Account menu container featuring `Profile >`, `Backup & Sync >`, and `Delete your data and account >`.
  - `AccountProfileScreen`: Displays `User Name` and `Email Address` grouped input/display fields.
  - `BackupAndSyncScreen`: Displays user details and Gmail backup caption at the bottom of the screen.
  - `DeleteAccountScreen`: Account closing warning, Username & Email confirmation, and primary blue **`Continue`** button.
- **Section 1 Card**: User & App Controls (`Account`, `General Settings`).
- **Section 2 Card**: Display & Storage (`Dark Mode` toggle, `Storage and Data`).
- **Section 3 Card**: Information & Legal (`FAQ`, `Terms of service`, `Privacy Policy`, `About`).
- **Section 4 Card (Testing Screens)**: Dedicated group for testing screens (`🧪 Test SDE Drag Selection`, `Glassmorphism Sandbox`, `Seed Long Note`, `Seed 50 Test Tasks`).

---

### Architecture Impact

- Keeps developer test utilities isolated in Section 4 while presenting a polished, production-ready Settings experience.
- Uses modular `GroupedListContainer` for 100% consistent card spacing, rounded corners, and hairline dividers across all 4 sections.

---

## v2.9.1

### Date
2026-08-14

### Author
Anti Gravity

### Type
- Refactor
- Bug Fix

---

### Summary

Refactored `SettingsScreen` user data loading to prefer `profile_full_name` over `profile_username`, allowed empty email displays without fallback text, and updated test suite back button finder for `AppHeaderBar`.

---

### Detailed Changes

- **User Data Display**: Prefer `profile_full_name` over `profile_username` in `_loadUserData()`.
- **Empty Email**: Allowed displaying empty email string when user profile email is unset.
- **Widget Test Fix**: Targeted left `AppHeaderBar` `TactileButton` in `test/bug_fixes_test.dart` to avoid avatar button hit test collision.

---

### Architecture Impact

No architectural impact.

---

### Files Modified

- `lib/views/screens/settings_screen.dart`
- `test/bug_fixes_test.dart`

---

### Testing Status

- Automated widget tests passed (100% GREEN).

---

## v3.0.0

### Date
2026-08-17

### Author
Anti Gravity

### Type
- Feature
- UI
- Refactor

---

### Summary

Restructured the Settings Screen (`lib/views/screens/settings_screen.dart`) tiles to match the exact order defined in `SettingsScreenUI` (1. Account, 2. Backup & Sync, 3. Dark Mode, 4. Storage & Data, 5. FAQ, 6. Terms of service, 7. Privacy Policy, 8. About). Preserved space and SVG icons for all item tiles.

---

### Detailed Changes

- **Tile Re-ordering**: Moved `Backup & Sync` to Section 1 directly under `Account`. Moved `Dark Mode` and `Storage & Data` to Section 2. Kept `FAQ`, `Terms of service`, `Privacy Policy`, and `About` in Section 3.
- **Icon Preservation**: Ensured all tiles maintain their leading SVG icons (`bottom_navigation/settings.svg`, `refresh.svg`, `night-day.svg`, `settings-sliders.svg`, `interrogation.svg`, `terms-info.svg`, `insurance.svg`).
- **Account Navigation**: Updated `AccountSettingsScreen` tile to push `BackupRestoreScreen`.

---

### Architecture Impact

No breaking architectural changes. Improves UX alignment with the application specification.

---

### Files Modified

- `lib/views/screens/settings_screen.dart`
- `lib/views/screens/account/account_settings_screen.dart`
- `Agents/skills/ChangeLogs Folder/SettingsScreen_Changelog.md`

---

### Testing Status

- Static analysis verified via `flutter analyze`.

---

## v3.1.0 — Phase 1.9.8.2

### Date
2026-08-18

### Author
Antigravity Engine

### Type
- Feature
- UI
- Integration
- Testing

---

### Summary

Integrated `AccountController` into `AccountSettingsScreen` (`lib/views/screens/account/account_settings_screen.dart`) allowing offline accounts to link Google identities in-place, handling account conflict modals, and navigating to First-Run Recovery when cloud backups exist.

---

### Detailed Changes

- **Offline / Authenticated State Support**: Added conditional rendering displaying State A (Offline banner + Sign in with Google button) when `sessionType == SessionType.offline`, and State B (Connected avatar, email, and verified badge) when `sessionType == SessionType.google`.
- **Conflict Resolution Modal**: Added `_showConflictDialog` to present collision details with `[ Cancel ]` (stay offline) and `[ Switch Account ]` (activate existing Google account).
- **First-Run Recovery Navigation**: On `AccountLinkAction.navigateToRecovery`, routes smoothly to `FirstRunRecoveryFlow`.
- **Interaction Guards**: Disabled double-tap and action triggers during authentication.

---

### Files Modified

- `lib/views/screens/account/account_settings_screen.dart`
- `test/views/account_settings_screen_test.dart`
- `Agents/skills/ChangeLogs Folder/SettingsScreen_Changelog.md`

---

### Testing Status

- 9/9 widget tests in `test/views/account_settings_screen_test.dart` PASS.
- 16/16 controller unit tests in `test/controllers/account_controller_test.dart` PASS.

---

## v3.2.0

### Date
2026-08-20

### Author
Anti Gravity

### Type
- Feature
- Testing

---

### Summary

Added `🧪 Test Welcome Screen` navigation tile to Section 4 (Developer & Testing Screens) of `SettingsScreen` (`lib/views/screens/settings_screen.dart`), routing to `TestWelcomeScreen`.

---

### Detailed Changes

- **TestWelcomeScreen Access**: Added a `GroupedTile.navigation` item for `🧪 Test Welcome Screen` in Section 4 of `SettingsScreen` using `assets/icons/bottom_navigation/home.svg`.
- **Haptic Feedback**: Wired `HapticFeedback.selectionClick()` on tap before pushing `TestWelcomeScreen`.

---

### Architecture Impact

No architectural impact.

---

### Files Modified

- `lib/views/screens/settings_screen.dart`
- `Agents/skills/ChangeLogs Folder/SettingsScreen_Changelog.md`

---

### Testing Status

- Widget tests in `test/views/test_welcome_screen_test.dart` PASS (100% GREEN).
