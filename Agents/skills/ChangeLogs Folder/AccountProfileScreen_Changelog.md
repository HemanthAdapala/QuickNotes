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
