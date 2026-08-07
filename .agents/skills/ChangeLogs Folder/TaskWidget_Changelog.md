# TaskWidget_Changelog.md

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
`TaskWidget` is the primary interactive card deck component on the Home Screen. This update introduced spring-physics swipe completion slider gestures, recurrence pill badges, dedicated Missed tasks filter deck integration, and multi-tier sorting (overdue tasks first, earlier due times first).

---

## Detailed Changes
- Integrated `TactileButton` and Liquid Glass card container styling.
- Added interactive swipe completion slider with tactile haptic feedback.
- Added recurrence badge pill displaying repeat frequency (`Daily`, `Weekly`, `Monthly`, `Yearly`).
- Integrated dynamic filter section headers (`Today`, `Weekly`, `Monthly`, `Missed`, `All`).
- Resolved double-counting bugs where past uncompleted tasks appeared in both Today and Missed sections.
- Verified 60fps card stack rendering performance under high task volumes (55+ tasks).

---

## Why was this change made?
- To provide users with an engaging, tactile card completion experience while ensuring accurate task filtering and clear visual indicators for recurring tasks.

---

## Architecture Impact
- **UI & Animation**: Custom gesture detector and animated offset transition for card slider completion.
- **State Management**: Listens reactively to `TasksProvider.activeTasks` and filter stream changes.

---

## Files Created
None.

---

## Files Modified
- `lib/views/widgets/task_widget.dart`
- `lib/providers/tasks_provider.dart`

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
- Customizable swipe gestures (e.g., swipe left to delete, swipe right to complete).
- Drag-and-drop manual task reordering.

---

## Known Issues
None.

---

## Testing Status
- **Manual Tests**: Verified on physical device (`SM S918B`) for card completions, deck switching, and high task volumes.
- **Automated Tests**: 95/95 unit tests passing.

---

## Final Result
`TaskWidget` provides a fluid, responsive, 60fps interactive card deck experience.
