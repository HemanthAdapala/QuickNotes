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

