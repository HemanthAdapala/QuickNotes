# Documentation Policy - Per Screen Changelog

## Version
v1.0.1

---
## Date
2026-08-25

---
## Author
Developer / Anti Gravity

---
## Type
- UI
- Feature

---
## Summary
Created a brand new StorageAndDataScreen and linked it to the Settings screen, replacing the static dialog.

---
## Detailed Changes
- Designed `StorageAndDataScreen` with a Liquid Glass `AppHeaderBar`.
- Added a visualizer component using `ClipRRect` and `Row` to proportionally display SQLite database size vs Offline cache size.
- Integrated `StorageService` to recursively calculate the size of the temporary directory and local `.db` file.
- Added actions to "Clear Cache" and "Compact Database" (VACUUM).
- Updated `SettingsScreen` to push the new screen.

---
## Why was this change made?
The user wanted a functional Storage management screen rather than a static info dialog.

---
## Architecture Impact
Created `StorageService` for disk-based calculations and SQLite maintenance.

---
## Files Modified
- `lib/views/screens/settings_screen.dart`
- `lib/views/screens/storage_and_data_screen.dart`
- `lib/services/storage_service.dart`
