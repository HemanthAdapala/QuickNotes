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
Migrated the PasscodeLockScreen to use the canonical AppHeaderBar widget for project-wide Liquid Glass UI consistency.

---
## Detailed Changes
- Replaced the standalone Cancel button (Align) with the standard AppHeaderBar widget.
- Set leftChild to a close icon if the action is cancelable, else null, allowing the glass surface to elegantly hide when not needed.
- Restructured PasscodeLockScreen layout with Expanded and Padding components to accommodate the new header without destroying the centered vertical layout of the keypad.

---
## Why was this change made?
To enforce project-wide UI consistency across all headers (Liquid Glass style).

---
## Architecture Impact
None.

---
## Files Modified
- lib/views/screens/passcode_lock_screen.dart
