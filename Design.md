# DESIGN.md – QuickNotes Design Language & Experience Guidelines

# Philosophy

QuickNotes is not just a note-taking application.

It is a calm, minimal, premium writing space designed to make capturing thoughts feel effortless.

The interface should disappear behind the user's ideas.

Every design decision must answer one question:

> Does this make writing feel easier, calmer, or more delightful?

If not, it should be simplified or removed.

---

# Source of Truth

The provided Figma designs are the primary visual reference.

Implementation should match the Figma layouts as closely as possible.

Do not reinterpret spacing, proportions, typography, hierarchy, or composition unless technically required.

If implementation constraints exist, preserve the overall feeling and visual balance before introducing changes.

---

# Overall Design Language

The application should feel inspired by:

* Apple Notes
* Apple Human Interface Guidelines
* Notion's minimalism
* Premium stationery
* Physical paper

The experience should feel soft, intentional, and free of visual noise.

Avoid anything that feels overly "Android material" or enterprise-oriented.

---

# Visual Principles

## Whitespace

Whitespace is an active design element.

Do not fill empty areas with unnecessary widgets or shortcuts.

Empty space creates focus.

Respect it.

---

## Typography

Typography should communicate hierarchy through weight rather than size whenever possible.

Use generous breathing room.

Titles should feel elegant.

Body text should feel effortless to read.

Avoid excessive boldness.

---

## Colors

Colors should remain subtle.

Use restrained palettes.

Accent colors should never overpower content.

The writing itself should always remain the visual focus.

### Core Color Palette

| Name            | Hex         | Usage                                                                                                                                                    |
| --------------- | ----------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Ink**         | `#333333`   | Primary dark color — used for main text, titles, icons, dividers, and structural elements.                                                               |
| **Amber**       | `#FFA322`   | Accent color — used for active highlights, today's date, selected states, and navigation indicators.                                                     |
| **Placeholder** | `#73333333` | Muted and disabled text — Ink at 45% opacity for placeholders and secondary information.                                                                 |
| **White**       | `#FFFFFF`   | Solid surfaces — editor sheets, cards, modals, and elevated content areas.                                                                               |
| **Background**  | `#F2F2EE`   | Soft warm stone background — designed specifically for frosted glass interfaces, providing subtle contrast while maintaining a calm, premium atmosphere. |

### Optional Supporting Colors (Recommended)

| Name              | Value                    | Usage                                            |
| ----------------- | ------------------------ | ------------------------------------------------ |
| **Glass Surface** | `rgba(255,255,255,0.55)` | Frosted cards, widgets, floating panels.         |
| **Glass Border**  | `rgba(255,255,255,0.65)` | Subtle glass outlines and edge highlights.       |
| **Divider**       | `rgba(51,51,51,0.08)`    | Layout separators and minimal boundaries.        |
| **Amber Soft**    | `#FFB84D`                | Hover states, gentle highlights, and animations. |

### Folder & Category Colors (Soft Pastel Collection)

| Name     | Hex       |
| -------- | --------- |
| Coral    | `#FFAAA6` |
| Peach    | `#FFDAB6` |
| Lemon    | `#FFF3A6` |
| Sage     | `#D4ECDD` |
| Sky      | `#A8DADC` |
| Lavender | `#D6C8FF` |
| Blush    | `#FFC6FF` |

The resulting identity becomes:
* **Ink**: `#333333`
* **Amber**: `#FFA322`
* **Background**: `#F2F2EE`
* **White**: `#FFFFFF`
* **Glass**: Frosted White (`55%` opacity)
* **Folders**: Soft Pastel Collection

---

## Shadows

Soft.

Low elevation.

Almost invisible.

Nothing should feel like floating plastic cards.

---

## Corners

Rounded where appropriate.

Never excessively rounded.

Prefer refinement over trendiness.

---

# Motion Philosophy

Motion is communication.

Animations should explain relationships between states.

Never animate purely for decoration.

Every movement should have purpose.

---

# Screen Transitions

Every navigation between screens should use a soft spring animation.

Transitions should feel like content settling into place rather than sliding mechanically.

Preferred characteristics:

* Smooth spring easing
* Slight overshoot (minimal)
* Natural deceleration
* Duration around 250–350ms

The user should subconsciously feel continuity between screens.

Navigation should never feel abrupt.

---

# Home → Editor Transition

When the user taps the writing prompt:

The editor should emerge naturally.

Avoid hard cuts.

Preferred feeling:

The page gently unfolds into the editor.

The destination should feel like an extension of the home screen rather than a completely different page.

---

# Folder Navigation

Opening a folder should feel like opening a physical folder.

The folder surface should expand naturally before revealing contents.

Avoid instant screen replacement whenever possible.

---

# Calendar Navigation

Calendar should softly settle into place.

No aggressive scaling or bouncing.

It should feel structured and stable.

---

# Micro Animations

Micro animations are mandatory.

Every interaction should provide subtle feedback.

Examples:

* Buttons compress slightly when pressed.
* Icons gently lift on selection.
* Cards settle after appearing.
* Images softly fade and scale into place.
* Toolbar buttons acknowledge touches with tiny spring motion.
* Checkboxes animate instead of instantly changing state.
* Pinned notes smoothly reposition rather than teleport.
* Rich formatting buttons softly highlight when active.
* Folder chips gently expand when selected.
* Category changes transition smoothly.

Animations should remain understated.

Users should notice the experience, not the animation itself.

---

# Haptic Feedback

Meaningful interactions should trigger haptic feedback.

Examples:

Light Haptic:

* Button presses
* Toolbar actions
* Folder selection
* Category selection

Medium Haptic:

* Pinning
* Unpinning
* Creating folders
* Completing checklists

Success Haptic:

* Successfully saving
* Import completed
* Export completed

Warning Haptic:

* Delete confirmation
* Permanent removal

Haptics should reinforce confidence without becoming repetitive.

---

# Editor Experience

The editor is the heart of QuickNotes.

It should always prioritize writing.

The writing surface must remain visually dominant.

Secondary controls should never distract from content.

Toolbar functionality should reveal itself progressively.

---

# Progressive Disclosure

Show advanced functionality only when it becomes relevant.

Examples:

Toolbar expands when editing.

Formatting options activate only when applicable.

Context should determine visibility.

Never overwhelm new users.

---

# Images

Images should feel integrated into the page.

Insertion should be smooth.

Resizing should animate naturally.

Dragging should feel magnetic.

Multiple images should intelligently align when positioned nearby.

Images should behave like objects placed on paper.

---

# Checklists

Checklist interactions should feel satisfying.

Checking an item should:

* Animate the checkbox
* Strike through text smoothly
* Slightly fade completed content
* Trigger subtle haptic feedback

Never instantly change state.

---

# Rich Text

Formatting should feel immediate.

Bold, italic, underline, alignment, and colors should apply visually rather than exposing markdown syntax.

The preview must always display rendered formatting.

Raw formatting markers should never leak into UI.

---

# Navigation Philosophy

Each screen has exactly one responsibility.

Home:
Capture.

Folders:
Browse.

Calendar:
Time.

Settings:
Personalization.

Avoid mixing responsibilities.

---

# Consistency

Every screen should feel like part of the same system.

Spacing.

Typography.

Animation.

Corner radius.

Elevation.

Motion.

Everything should follow one unified language.

Users should never feel like they entered a different application.

---

# Performance

Animation smoothness is more important than animation quantity.

Maintain 60fps or better.

If performance suffers, simplify effects before removing interactions.

Fluidity is part of the product.

---

# Final Principle

QuickNotes should never impress users by showing features.

It should impress them by how natural every interaction feels.

The best compliment should be:

"I didn't even think about the app. I just wrote."
