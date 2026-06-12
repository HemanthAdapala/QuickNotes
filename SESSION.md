# SESSION

## Current Goal

# QuickNotes – 3-Layer Note Architecture & Premium Paper System

Implement a new editor architecture where every note is composed of **three independent visual layers** while preserving the existing block-based document model.

The goal is to make every note feel like writing on customizable paper rather than a blank digital canvas.

---

# Layer 1 — Background Layer

This is the bottom-most layer.

Responsibilities:

* Solid color backgrounds
* Theme-aware default paper color
* Future support for gradients
* Future support for custom paper textures
* Future support for subtle image backgrounds

Requirements:

* Does not interfere with editing.
* Scrolls together with the document.
* Can be customized per note.
* Supports both Light and Dark Mode naturally.

Example:

White Paper

Warm Cream

Midnight

Sepia

Minimal Gray

---

# Layer 2 — Paper Guide Layer (Toggleable)

This layer sits above the background but below all content.

It exists only to provide visual writing guidance.

The user can switch between different guide styles at any time.

Supported modes:

### Plain

No guides.

Clean writing canvas.

---

### Dots

Subtle notebook dots.

Low opacity.

Perfectly aligned.

Should resemble premium bullet journals.

---

### Grid

Fine square grid.

Useful for diagrams and planning.

Grid lines should never overpower content.

---

### Ruled Lines (Extra Tight Default)

This should become the default option.

Spacing should exactly follow Group 2-A (Extra Tight).

Target:

* Line height ≈ 1.05
* Very compact writing rhythm
* Designed to maximize information density without sacrificing readability

The ruled lines should align naturally with paragraph baselines.

Text should appear to sit directly on the paper.

---

### Wide Lines

For accessibility or larger handwriting feel.

---

### Engineering Grid (Future)

Very subtle blueprint-style grid.

---

### Music Staff (Future)

For musicians taking notes.

---

### Cornell Notes Template (Future)

Optional productivity layout.

---

## Behavior

The Paper Guide Layer is purely visual.

It must:

* Never intercept touches.
* Never affect text selection.
* Never affect cursor movement.
* Never interfere with gestures.
* Never export as part of copied text.

It simply sits beneath the content.

Users can toggle:

Plain ↔ Dots ↔ Grid ↔ Ruled ↔ Other templates instantly.

Transition between modes should softly fade rather than abruptly switch.

---

# Layer 3 — Content Layer

This is the actual editable document.

Contains:

* Title
* Paragraphs
* Headings
* Images
* Checklists
* Quotes
* Code Blocks
* Tables
* Dividers
* Future widgets
* Future embeds

All content remains fully editable regardless of Paper Guide choice.

The Paper Guide should never become part of the document data.

---

# Typography & Spacing

Adopt Group 2-A (Extra Tight) as the default writing experience.

Target spacing philosophy:

* Paragraph → Paragraph: extremely compact
* Text should feel continuous
* No oversized gaps
* Line height ≈ 1.05
* Text-to-image spacing: ~6px
* Image-to-checklist spacing: ~6px
* Checklist item spacing: ~2px

The note should resemble a premium paper notebook with efficient use of space.

---

# Scroll Behavior

All three layers should scroll together as one unified page.

The Paper Guide Layer should remain perfectly synchronized with text baselines.

The user should feel like moving one physical sheet of paper.

---

# Zoom & Scaling

If zoom is introduced in the future:

* Background scales naturally.
* Paper Guide scales proportionally.
* Content scales without breaking alignment.

Ruled lines should always remain synchronized with text.

---

# Persistence

Every note stores independently:

* Background style
* Paper Guide style
* Guide visibility
* Guide opacity
* Future paper preferences

Changing one note should not affect others.

---

# Performance

The Paper Guide should be rendered efficiently.

Avoid creating thousands of widgets.

Prefer custom painting or tiled rendering for lines, dots, and grids.

Rendering should remain smooth even for very long notes.

---

# Future Extensibility

The architecture should allow additional paper templates without modifying the editor core.

New templates should simply plug into the Paper Guide Layer.

Examples:

* Graph Paper
* Dot Grid
* Cornell Layout
* Daily Planner
* Calendar Pages
* Storyboard Sheets
* Hexagonal Grid
* Isometric Grid
* Music Manuscript
* Kanban Board
* Custom User Templates

---

# Design Philosophy

A note is no longer just text.

It is a sheet of paper with three independent layers:

1. Background → Defines atmosphere.
2. Paper Guide → Defines how the page feels.
3. Content → Holds the user's ideas.

The user should feel like choosing a physical notebook before they begin writing.

The experience should be subtle, elegant, and deeply customizable without adding complexity to the writing process.


## Priority

High

## Definition of Done

- Everything should be implemented

## Notes

Investigate before implementing.