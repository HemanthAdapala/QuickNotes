# CalendarTaskCard Changelog

## Version

v1.0.1

---

## Date

2026-08-25

---

## Author

Anti Gravity

---

## Type

- UI
- Bug Fix

---

## Summary

Corrected a significant styling bug where the priority color overtook the entire task card background, and ensured the toggle circle and text strikethrough perfectly match the design spec.

---

## Detailed Changes

- Fixed bug where color: task.priorityColor was applied to the parent ShapeDecoration. It is now constrained exclusively to the 26px left edge strip.
- Restored pure white background to the main body of the card.
- Re-added the specified 16px blur drop shadow (Color(0x15000000)).
- Validated that the text strikethrough accurately responds to 	ask.isCompleted.
- Confirmed the toggle circle visually flips between a faint gray outline and a solid blue checkmark circle.

---

## Why was this change made?

The task card deviated wildly from the provided design spec due to an accidental styling leak (priority color flooding the whole card).

---

## Architecture Impact

No architectural impact.

---

## Files Created

None.

---

## Files Modified

- lib/views/widgets/calendar_task_card.dart

---

## Dependencies Added

None.

---

## Breaking Changes

None.

---

## Migration Notes

None.

---

## Future Improvements

None.

---

## Known Issues

None.

---

## Testing Status

Manual Tests: Verified UI successfully renders exactly identical to the reference screenshot provided by the user.

---

## Final Result

The CalendarTaskCard is now a beautiful, highly polished widget with clear interactive states.
