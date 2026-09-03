# Documentation Policy - Per Screen Changelog

From this point forward, every screen, controller, service, widget, or major feature introduced into the project must maintain its own dedicated Markdown changelog.

This changelog acts as the permanent knowledge base for that component throughout the lifetime of the project.

---

## File Naming Convention

Use the following naming convention:

<HomeScreen>_Changelog.md
<SplashScreen>_Changelog.md
<LoginScreen>_Changelog.md
<EditorScreen>_Changelog.md
<TaskScreen>_Changelog.md
<TaskCard>_Changelog.md
<FAB>_Changelog.md
<Settings>_Changelog.md
<Search>_Changelog.md
<FloatingTaskCard>_Changelog.md
<Navigation>_Changelog.md
<TaskCard>_Changelog.md

If the component is not a screen:

<AuthenticationService>_Changelog.md
<SessionManager>_Changelog.md
<EditorController>_Changelog.md

The changelog file should always live alongside the feature documentation (or inside a dedicated `/docs/changelog/` folder if the project structure prefers central documentation).

---

# Documentation Rules

This document must be updated after every implementation, refactor, optimization, bug fix, or architectural change related to that component.

Never overwrite previous entries.

Always append new entries in chronological order.

The changelog must become the single historical record of that component.

---

# Each Entry Must Contain

## Version

Example

v1.0.0

---

## Date

YYYY-MM-DD

---

## Author

Developer / Anti Gravity

---

## Type

Choose one or more:

- Feature
- Improvement
- Refactor
- Bug Fix
- Optimization
- Architecture
- Breaking Change
- UI
- Animation
- Performance
- Documentation

---

## Summary

A short one-paragraph explanation describing the change.

---

## Detailed Changes

List every significant modification.

Example:

- Added Google Sign In button.
- Added Continue Offline flow.
- Added Loading Overlay.
- Added Error Snackbar.
- Refactored navigation.
- Extracted SignInOptions widget.

---

## Why was this change made?

Explain the reasoning.

Example:

Previous implementation mixed UI and business logic.

Authentication responsibilities were moved into AuthenticationService to improve maintainability.

---

## Architecture Impact

Explain whether this affects:

- Navigation
- Session Management
- State Management
- Database
- Storage
- Authentication
- Animation
- Performance

If none, state:

No architectural impact.

---

## Files Created

List all newly created files.

---

## Files Modified

List every modified file.

---

## Dependencies Added

List any new packages.

If none:

None.

---

## Breaking Changes

Document anything that could affect existing code.

If none:

None.

---

## Migration Notes

Explain how future developers should migrate from older implementations.

If unnecessary:

None.

---

## Future Improvements

List ideas intentionally postponed.

Example:

- Apple Sign In
- Email Authentication
- Cloud Sync
- Session Expiration

---

## Known Issues

Document remaining issues.

If none:

None.

---

## Testing Status

Manual Tests

Automated Tests

Pending Tests

Known Edge Cases

---

## Final Result

Describe the completed state of the component after this version.

---

# Documentation Standards

The changelog must:

- Never delete historical entries.
- Never rewrite previous versions.
- Always append new versions.
- Remain concise but technically complete.
- Explain both WHAT changed and WHY it changed.
- Focus on architectural decisions, not only code changes.

---

This changelog is considered part of the production documentation and must always stay synchronized with the implementation.