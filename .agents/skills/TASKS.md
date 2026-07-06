# Project Tasks & Roadmap

## Inline Image Insertion Feature [Completed]

- [x] Add `imageCaption` string support to `Style` class and serialization helpers.
- [x] Create `fullscreen_image_viewer.dart` with Hero transitions and pinch-to-zoom.
- [x] Refactor `ResizableImageWidget` with mount animation (fade and scale).
- [x] Implement direct pinch-to-resize gesture in `ResizableImageWidget`.
- [x] Add editable caption display in `ResizableImageWidget` controls.
- [x] Implement fullscreen zoom trigger and Hero transition inside `ResizableImageWidget`.
- [x] Add delete transition (shrink/fade) inside `ResizableImageWidget`.
- [x] Build custom Gallery bottom-sheet in `note_editor_screen.dart` with fallback previews.
- [x] Implement sequential insertion logic for multi-selected images.
- [x] Implement long-press lift animation (shadow, spring) & drag-to-reorder mechanics.
- [x] Write unit tests for captions, resizing, and drag-and-drop.
- [x] Verify build and run all tests successfully.

## Home Screen Redesign [Completed]

- [x] Create `home_screen.dart` matching the Figma "Starting Screen" design.
  - [x] Date label (e.g. "Jun 13") in muted grey
  - [x] Day name (e.g. "Monday") in large bold Outfit type
  - [x] "Today" label in orange accent (#F97316)
  - [x] Animated breathing bullet + writing prompt text
  - [x] Tapping prompt opens fresh NoteEditor via FabMorphPageRoute
  - [x] Recent-note teaser chip at the bottom
  - [x] Fade + slide-up entrance animation
- [x] Rewrite `navigation_shell.dart` with new 4-tab structure (Home/Folders/Calendar/Settings).
  - [x] Figma-style dark pill bottom nav bar
  - [x] Floating orange + FAB centered above the pill
  - [x] Spring micro-animation on each tab icon
  - [x] Calendar placeholder (stub) for future implementation
  - [x] Desktop sidebar retained and updated
- [x] Analyze with `flutter analyze` — 0 issues.
- [x] Commit on `feature/home-redesign` branch and push to remote.

