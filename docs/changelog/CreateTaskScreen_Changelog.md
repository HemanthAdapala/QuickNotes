# CreateTaskScreen_Changelog.md

## Version
v1.0.1

## Date
2026-08-27

## Author
Anti Gravity

## Type
- UI
- Responsive

## Summary
Constrained the width of the main form to improve readability on tablet and desktop viewports, while preserving the full-width outer Document Card structure.

## Detailed Changes
- Wrapped the internal `SingleChildScrollView` content with `Center` and `ConstrainedBox(maxWidth: 700.0)`.
- Reorganized the Widget tree around line 950 to ensure `Center` and `ConstrainedBox` encapsulate only the form content.
- Preserved the full viewport width of the blue sticky date-time header and the AppHeaderBar to ensure Hero transition safety.

## Why was this change made?
On large screens like tablets, the form fields and text areas stretched to the full width of the screen, creating uncomfortably long lines of text and excessively wide UI elements (like the Save/Cancel buttons). By introducing a 700px maximum width for the reading/editing area, we align with established typographical readability standards while maintaining the physical edge-to-edge "paper" visual.

## Architecture Impact
No architectural impact. Only local Widget geometry inside the existing scrolling boundaries was modified.

## Files Created
None.

## Files Modified
- `lib/views/screens/create_task_screen.dart`

## Dependencies Added
None.

## Breaking Changes
None.

## Migration Notes
None.

## Future Improvements
None.

## Known Issues
None.

## Testing Status
Manual Tests: Verified inferred viewport bounds up to 1024px.
Automated Tests: Passed Flutter static analysis (`flutter analyze`).
Pending Tests: Device/emulator visual verification.
Known Edge Cases: None.

## Final Result
The `CreateTaskScreen` now correctly bounds its form and button content to a maximum width of 700px when viewed on tablets or desktop, seamlessly adapting down to the edges on mobile devices.

---

## Version
v1.1.0

## Date
2026-09-19

## Author
Anti Gravity

## Type
- UI
- Improvement

## Summary
Migrated TaskEditorScreen and CreateTaskBottomSheet core shells and surfaces to Dark Mode as part of Phase D6-F1.

## Detailed Changes
- Added theme-awareness (`Theme.of(context).brightness == Brightness.dark`) to `TaskEditorScreen` in `lib/views/screens/create_task_screen.dart`.
- Root Scaffold background adapts to `#1E1E1E` in Dark Mode while preserving `Colors.white` in Light Mode.
- Main task content card background adapts to `#2C2C2C` in Dark Mode with shadow suppressed, preserving `Colors.white` and subtle shadow in Light Mode.
- `AppHeaderBar` action icons (back angle and more options) adapt to `Colors.white` in Dark Mode while preserving `#1C1C1E` in Light Mode.
- Secondary "Cancel" tactile button background adapts to `#3A3A3C` and foreground to `Colors.white` in Dark Mode, preserving `0x28787880` and `0x993C3C43` in Light Mode.
- Primary "Save" action button remains `#0088FF` with white text across both modes.
- Added theme-awareness to `CreateTaskBottomSheet` in `lib/views/widgets/create_task_bottom_sheet.dart`.
- Modal sheet container background adapts to `#2C2C2C` in Dark Mode, preserving `Colors.white` in Light Mode.
- Drag handle bar adapts to `#5A5A5A` in Dark Mode, preserving `0x4C3C3C43` in Light Mode.
- Close pill button adapts to container `#3A3A3C` and icon `Colors.white` in Dark Mode, preserving `0x19000000` container and `#1C1C1E` icon in Light Mode.
- All geometries, radii, padding, typography metrics, motion curves, and haptic feedbacks remain strictly locked and unchanged.
- Created `test/views/task_editor_shell_dark_mode_test.dart` containing 4 dedicated widget tests validating Light and Dark Mode shell palettes.

## Why was this change made?
Phase D6-F1 establishes the visual Dark Mode foundation for the Task Editor ecosystem without touching input controls, pickers, priority, reminder, or recurrence components (scheduled for subsequent phases D6-F2/F3).

## Architecture Impact
None. Strictly visual surface adaptation. No business logic, Riverpod/Provider state, database models, or scheduling architecture was modified.

## Files Created
- `test/views/task_editor_shell_dark_mode_test.dart`

## Files Modified
- `lib/views/screens/create_task_screen.dart`
- `lib/views/widgets/create_task_bottom_sheet.dart`
- `docs/changelog/CreateTaskScreen_Changelog.md`

## Dependencies Added
None.

## Breaking Changes
None.

## Migration Notes
None.

## Future Improvements
Implement Phase D6-F2 (Task Editor text fields & input controls) and Phase D6-F3 (property pickers, priority popup, reminder and recurrence controls).

## Known Issues
None.

## Testing Status
Manual Tests: Verified automated widget tests for Light and Dark modes.
Automated Tests: Passed 111/111 tests (`test/views/task_editor_shell_dark_mode_test.dart`, `test/providers/tasks_provider_test.dart`, `test/task_engine_test.dart`, `test/task_engine_recurrence_test.dart`, `test/views/calendar_dark_mode_palette_test.dart`). Passed static analysis with 0 errors.
Pending Tests: Physical device verification.
Known Edge Cases: None.

## Final Result
Both `TaskEditorScreen` and `CreateTaskBottomSheet` shells seamlessly adapt to `#1E1E1E` and `#2C2C2C` Dark Mode foundations while 100% preserving existing Light Mode visual aesthetics and geometry.

---

## Version
v1.2.0

## Date
2026-09-19

## Author
Anti Gravity

## Type
- UI
- Improvement
- Bug Fix

## Summary
Migrated Task Editor fields, labels, due date & time controls, and native date/time pickers to Dark Mode as part of Phase D6-F2. Resolves the hardcoded `ColorScheme.light` dialog theme leak identified in D6-F0, bringing full brightness-awareness to native Material `DatePicker` and `TimePicker`.

## Detailed Changes
- **Native Pickers Theme Leak Resolution**: Replaced the hardcoded `const ColorScheme.light(...)` builder wrappers in `create_task_screen.dart` (`_selectDate` and `_selectTime`) and added matching theme-aware builders to `create_task_bottom_sheet.dart` (`_pickDate` and `_pickStartTime`).
  - In Dark Mode: dynamically applies `ColorScheme.dark` with primary `#0088FF`, onPrimary `#FFFFFF`, surface `#2C2C2C`, and onSurface `#FFFFFF`.
  - In Light Mode: preserves the exact original `ColorScheme.light` appearance with primary `#0088FF` and onSurface `#333333`.
- **Title Field**:
  - Title input container adapts from `0x28787880` to `#242426` in Dark Mode.
  - Entered title text adapts from `#333333` to `#FFFFFF`.
  - Placeholder / hint adapts from `0x993C3C43` to `#8E8E93`.
- **Description Field**:
  - Description input container adapts from `0x28787880` to `#242426` in Dark Mode.
  - Entered description text adapts from `#333333` to `#FFFFFF`.
  - Placeholder / hint adapts from `0x993C3C43` to `#8E8E93`.
- **Field Labels**:
  - Primary field labels ('Task Title', 'Due Date', 'Time', 'Priority', 'Task Description (Optional)') adapt from `#333333` to `#FFFFFF` in Dark Mode.
- **Due Date & Due Time Controls**:
  - Container backgrounds adapt from `0x28787880` to `#242426` in Dark Mode.
  - Formatted date & time texts adapt from `0x993C3C43` to `#FFFFFF`.
  - Calendar and alarm clock icons adapt from `0x993C3C43` / `0xFF888888` to `#8E8E93`.
- **Locked Boundaries Maintained**:
  - Priority option list, priority popup, reminder segmented control, and recurrence chips remain strictly untouched (scheduled for Phase D6-F3).
  - All geometries, radii (20px/16px/14px), font sizes, weights, haptics, and task persistence semantics are locked and unchanged.
- **Tests**:
  - Created `test/views/task_editor_fields_dark_mode_test.dart` containing 5 comprehensive widget tests verifying Light and Dark Mode fields, labels, date/time chips, and native dialog picker themes.

## Why was this change made?
Phase D6-F2 delivers legible, high-contrast, theme-consistent text inputs and date/time controls while eliminating the glaring white native picker dialogs in Dark Mode.

## Architecture Impact
None. Presentation-level styling and local picker builder adaptation only.

## Files Created
- `test/views/task_editor_fields_dark_mode_test.dart`

## Files Modified
- `lib/views/screens/create_task_screen.dart`
- `lib/views/widgets/create_task_bottom_sheet.dart`
- `docs/changelog/CreateTaskScreen_Changelog.md`

## Dependencies Added
None.

## Breaking Changes
None.

## Migration Notes
None.

## Future Improvements
Implement Phase D6-F3 (Priority selector & popup, Reminder segmented pill, and Recurrence chips).

## Known Issues
None.

## Testing Status
Manual Tests: Verified automated widget tests for inputs, labels, and pickers.
Automated Tests: Passed 116/116 tests across the full task regression suite (`task_editor_fields_dark_mode_test.dart`, `task_editor_shell_dark_mode_test.dart`, `tasks_provider_test.dart`, `task_engine_test.dart`, `task_engine_recurrence_test.dart`, `calendar_dark_mode_palette_test.dart`). Passed static analysis with 0 errors.
Pending Tests: Physical device verification.
Known Edge Cases: None.

## Final Result
All Task Editor input fields, labels, date/time chips, and native date/time pickers seamlessly adapt to the D6 Dark Mode contract while 100% preserving Light Mode visual fidelity and data integrity.


