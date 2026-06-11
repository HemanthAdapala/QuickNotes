# Changelog

All notable changes to this project will be documented in this file.

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
