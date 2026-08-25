# Documentation Policy - Per Component Changelog

## Version
v1.0.0

---
## Date
2026-08-25

---
## Author
Anti Gravity

---
## Type
- UI
- Feature

---
## Summary
Created `AboutBottomSheet`, a premium, glassmorphism-styled informational component for the QuickNotes app.

---
## Detailed Changes
- Built the bottom sheet to be presented using `showBlurredBottomSheet`.
- Displayed the bold "Q" logomark inside a glassmorphic blurred circle.
- Listed Version string, copyright, and developer credit with custom `Inter` typography.
- Designed it with deep visual depth and a frosted appearance matching the rest of the application's aesthetic.

---
## Why was this change made?
To replace the default `AlertDialog` About screen with a custom UI that perfectly follows the premium Liquid Glass standard.

---
## Architecture Impact
No major impact. Cleanly isolates the UI code for the About screen into a discrete widget.

---
## Files Modified
- `lib/views/widgets/about_bottom_sheet.dart` (New)

---
## Testing Status
Manually verified presentation and dismissal.
