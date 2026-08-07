# TaskWidget_Changelog.md

## Version
v1.0.1

## Date
2026-08-07

## Author
Developer & Anti Gravity AI Assistant

## Type
- UI
- Animation
- Refactor
- Bug Fix

## Summary
Refactored `TaskWidget` card gesture hierarchy by moving `GestureDetector` to wrap the top-level front card, matching `NotesStackWidget` architecture. Resolves card swipe cycling unresponsiveness on physical devices while maintaining independent horizontal completion slider drags.

---

## Detailed Changes
- Aligned gesture structure 100% with `NotesStackWidget`: `GestureDetector(onPanUpdate: _handleCardPanUpdate, onPanEnd: _handleCardPanEnd, child: Center(...))`.
- Elevated outer card drag handling above internal stack containers.
- Disambiguated inner `onHorizontalDragUpdate` for the Liquid Glass completion slider track.
- Verified smooth 60fps card cycling and particle slider completions on physical device (`SM S918B`).

---

## Why was this change made?
- The previous implementation placed `GestureDetector` inside an internal child `Positioned` layer of the card `Stack`, where upper visual containers intercepted hit-testing and blocked card swipe cycling.

---

## Architecture Impact
- **UI & Animation**: Top-level gesture architecture for 3D card stack rotation and translation.

---

## Files Created
None.

---

## Files Modified
- `lib/views/widgets/task_widget.dart`

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
- Custom swipe physics configuration option in Settings.

---

## Known Issues
None.

---

## Testing Status
- **Manual Tests**: Verified card cycling and slider completion on physical device (`SM S918B`).
- **Automated Tests**: 95/95 unit tests passing cleanly.

---

## Final Result
`TaskWidget` supports smooth 3D card deck swiping and liquid glass slider completion simultaneously with zero gesture conflicts.

---

# Previous Versions

## Version
v1.0.0

## Date
2026-08-07

## Author
Developer & Anti Gravity AI Assistant

## Type
- UI
- Animation
- Refactor
- Feature
- Performance

## Summary
`TaskWidget` is the primary interactive card deck component on the Home Screen. This update introduced spring-physics swipe completion slider gestures, recurrence pill badges, dedicated Missed tasks filter deck integration, and multi-tier sorting.
