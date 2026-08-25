# Documentation Policy - Per Screen Changelog

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
Created a brand new `LegalDocumentScreen` to display text-heavy legal documents and FAQs using `flutter_markdown`.

---
## Detailed Changes
- Built a reusable "White Rounded Sheet" wrapper in `LegalDocumentScreen` to display markdown content.
- Integrated `flutter_markdown` to parse string markdown content directly into Flutter widgets.
- Used an overlapping floral `AppHeaderBar` design standard identical to the rest of the settings section.
- Bound font styling inside `MarkdownStyleSheet` to use the project-standard `GoogleFonts.inter` to guarantee identical typography representation.

---
## Why was this change made?
Generic `AlertDialog`s were not consistent with the premium Liquid Glass & White Rounded Sheet visual identity established in the rest of the application.

---
## Architecture Impact
Centralized markdown document rendering into a single reusable view.

---
## Files Modified
- `lib/views/screens/legal_document_screen.dart` (New)

---
## Testing Status
Manual verification of markdown parsing and UI consistency.
