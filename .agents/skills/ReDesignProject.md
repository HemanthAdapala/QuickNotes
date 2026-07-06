# QuickNotes Redesign – Project Reset Instructions

## Context

We are **not creating a new application**.

We are **redesigning the existing QuickNotes project** while preserving all stable, working functionality wherever possible.

Do **not** rewrite the project from scratch.

Do **not** replace working systems simply because a new UI is being introduced.

The goal is to evolve the application into a cleaner, more focused experience while reusing the mature editor, document model, and existing infrastructure.

---

# Design Philosophy

QuickNotes is a **minimal notes application**.

It is **not**:

* A journaling app
* A productivity suite
* A project manager
* A second brain

Its primary purpose is:

> Capture ideas quickly, organize them naturally, and retrieve them effortlessly.

Every design decision should support this philosophy.

---

# Redesign Strategy

Follow these principles:

1. Preserve stable functionality whenever possible.
2. Replace only the presentation layer if the underlying logic is already correct.
3. Refactor instead of rewriting.
4. Hide or disable obsolete features before deleting them.
5. Maintain backward compatibility with existing notes and data whenever practical.

---

# New Navigation Structure

Bottom Navigation:

* Home
* Folders
* Calendar
* Settings

Each tab has one clear responsibility.

## Home

The app always launches here.

Display:

* Current date
* Current day
* "Today"
* A simple invitation to begin writing

Example:

Monday

Apr 13 • Today

Start writing...

Tapping this area opens a **new note editor**.

It should always create a fresh note.

It should not reopen previous notes.

---

## Folders

Folders are the primary browsing experience.

Users can:

* View recent notes
* View pinned notes
* Browse folders
* Open existing notes

Notes may optionally belong to folders.

Default folder behavior should be simple and unobtrusive.

---

## Calendar

Calendar is dedicated to time-based organization.

It should support:

* Tasks
* Checklists
* Viewing notes by creation date
* Assigning notes to dates
* Future planning features

Calendar is not a replacement for folders.

It is a complementary timeline.

---

## Settings

Contains personalization and application preferences only.

---

# Editor Philosophy

The editor remains the most powerful part of the application.

Keep existing capabilities where possible:

* Rich text
* Images
* Checklists
* Formatting
* Categories
* Colors
* Typography
* Block architecture

However, present them progressively.

The writing surface should remain the primary focus.

---

# Data Model

Every note should include:

* Title
* Content
* Created Date
* Modified Date
* Folder (optional)
* Category (default: Uncategorized)
* Color
* Pinned State
* Attachments

Created Date should always exist.

Calendar functionality should derive from this information.

---

# Categories vs Folders

Folders answer:

"Where does this note belong?"

Categories answer:

"What type of note is this?"

These concepts should remain independent.

Example:

Folder:
Cooking

Category:
Vegetarian

---

# UI Principles

Prioritize:

* Minimalism
* Whitespace
* Clear typography
* Calm interactions
* Fast capture
* Progressive disclosure

Avoid overwhelming users with controls.

The app should feel welcoming rather than technical.

---

# Motion Principles

Animations should be subtle.

Every transition should reinforce continuity.

Nothing should animate purely for decoration.

Interactions should feel like manipulating paper rather than widgets.

---

# Legacy Cleanup

Audit all existing functionality.

If a feature does not support the new philosophy:

* First remove it from the UI.
* Ensure nothing depends on it.
* Then safely remove its implementation if appropriate.

Never break stable systems unnecessarily.

---

# Development Priority

1. Preserve working code.
2. Refactor architecture where needed.
3. Replace UI incrementally.
4. Validate after every major change.
5. Maintain a stable build throughout the redesign.

The objective is not to build a different app.

The objective is to make the current app feel intentional, minimal, and cohesive while retaining its strongest capabilities.
