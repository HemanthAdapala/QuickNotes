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
- Refactor

---
## Summary
Migrated the VaultScreen to use the canonical AppHeaderBar widget for project-wide Liquid Glass UI consistency.

---
## Detailed Changes
- Replaced the custom Row header with the standard AppHeaderBar widget.
- Retained the menu_rounded icon on the left (since it's a tab screen) while migrating it into the AppHeaderBar's leftChild.
- Integrated the Vault lock/unlock toggle into the AppHeaderBar's rightChild properly centering the title.
- Preserved padding and visual layout to match HomeScreen aesthetics.

---
## Why was this change made?
To enforce project-wide UI consistency across all headers (Liquid Glass style).

---
## Architecture Impact
None.

---
## Files Modified
- lib/views/screens/vault_screen.dart
