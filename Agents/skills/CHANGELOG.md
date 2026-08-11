# Changelog

All notable changes to this project will be documented in this file.

## [1.5.1] - 2026-07-20

### Fixed
- **Checklist Editing Cursor Integrity**:
  - Fixed a character index mismatch bug in `RangeTextEditingController.buildTextSpan` where list prefix characters (`\u2610`, `\u2611`, `•`, `›`, `\u2008`) were removed from the rendered `TextSpan` tree, causing `RenderEditable` to report offsets off by 1.
  - Preserved exact 1:1 character index mapping between `RenderEditable` and `RangeTextEditingController.text` by including prefix characters in `buildTextSpan` with zero visual width (`fontSize: 0.001`, `color: Colors.transparent`).
  - Resolved text corruption and unexpected character movement/deletion when editing existing checklist items or pressing Enter.

- **Checklist Completion State Persistence**:
  - Fixed a state loss bug in `NewSingleDocumentEditor._toggleCheckbox` where toggling a checklist item updated the symbol char (`\u2611`) without updating `checked: true` and `strikethrough: true` in character styles, causing `generateMarkdownFromStyledChars` to write `- [ ]` instead of `- [x]`.
  - Updated `generateMarkdownFromStyledChars` to verify both `style.checked` and `\u2611` symbol when serializing checklist lines to markdown (`- [x]`).
  - Ensured checklist completion state is fully persisted and restored across editor exit/reopen, note saves, database reloads, and app restarts.

## [1.5.0] - 2026-06-22

### Added
- **Unified Header Alignment**: Standardized all screen headers to a fixed height of 38px, horizontal margins of 30px, and top spacing of 24.0px below SafeArea.
- **Standardized Back Buttons**: Replaced default AppBars and custom icons with a unified 38x38px `TactileButton` enclosing the `assets/icons/angle_left.svg` SVG icon. Back button SVG colors adapt automatically based on light/dark themes.
- **Ignored/Disabled NoteEditor Folder Picker**: Wrapped the black folder picker button on `NoteEditorScreen` in an `IgnorePointer` and reduced its opacity to 0.5 when in editing mode.

### Fixed
- **Note Calendar Screen Compilation**: Fixed bracket mismatch and duplicate layout rendering blocks inside `note_calendar_screen.dart`.
- **TactileButton Hit-Testing**: Set `behavior: HitTestBehavior.opaque` on the `GestureDetector` inside `TactileButton` to fix hit-testing on buttons with transparent/SVG children.
- **Settings Screen Test Suite Integration**: Awaited dialog transitions using `pumpAndSettle()` in `bug_fixes_test.dart` to ensure modal barrier removal.

## [1.4.0] - 2026-06-13

### Changed
- **Home Screen Redesign** (matches Figma "Starting Screen" design):
  - Replaced `NotesListScreen` as the Home tab with a new dedicated `HomeScreen`.
  - Displays current date, day name in large bold Outfit typeface, and "Today" label in orange accent (`#F97316`).
  - Animated breathing bullet with a rotating writing prompt taps to open a fresh `NoteEditorScreen` via `FabMorphPageRoute`.
  - Subtle recent-note teaser chip at the bottom shows note count and last title.
  - Fade + slide-up entrance animation on screen load.
- **Navigation Shell Redesign** (4-tab structure: Home → Folders → Calendar → Settings):
  - Dark pill bottom navigation bar with floating orange `+` FAB centered above it.
  - Spring micro-animations on each tab icon press.
  - Calendar tab is a clean stub for future implementation.
  - Desktop sidebar updated to match new 4-tab structure.
  - All changes on `feature/home-redesign` branch.

## [1.3.0] - 2026-06-12

### Fixed
- **Clean Plain-Text Previews**:
  - Implemented plain-text preview generation to strip all raw Markdown styling markers (`**`, `*`, `__`, `_`, `~~`, `==`), HTML tags, checklist prefixes, links, and image block syntax.
  - Added SQLite database migration (Schema version 6) to cache the generated preview text in a new `previewText` column for optimal rendering performance.
  - Updated note cards to display the clean cached preview with a consistent maximum height of 3 lines.

## [1.2.0] - 2026-06-11

### Added
- **Rich Inline Image Insertion**:
  - Treats images as text blocks that reside inline at the current cursor position.
  - Custom gallery bottom-sheet with grid layouts, system picker actions, and fallback network samples.
  - Multi-image selection with sequenced badges (1, 2, 3) indicating insertion order.
  - Sequential cascading insertion animations with delayed drops.
  - Smooth fade and scale-up entrance animations for paragraph reflow.
  - Interactive pinch-to-resize gesture handler on the inline images.
  - Optional captions below each image, fully integrated with Markdown alt-texts.
  - Transparent Hero transitions from inline note editor positions to full-screen view.
  - Double shadow, scale-up lift, and spring elastic animations on long-press.
  - Drag-and-drop mechanics to reposition images inline dynamically across paragraphs.
  - Downsampled memory loading (`ResizeImage`) and crossfading loading placeholders.
  - Shrink-and-fade exit transitions on image deletions.
