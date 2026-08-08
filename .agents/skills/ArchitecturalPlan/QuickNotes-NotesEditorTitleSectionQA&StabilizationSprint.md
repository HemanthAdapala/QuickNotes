# Quick Notes — NotesEditor Title Section QA & Stabilization Sprint

Today's objective is **NOT** to add new features.

Today's objective is to make the **NotesEditor Title Section production-ready** by performing a complete architectural verification, functional testing, edge-case testing, keyboard focus lifecycle analysis, database persistence sync, and visual stabilization.

I want this session to be treated as a dedicated **QA Sprint** focused strictly on the **Title Section** of the `NoteEditorScreen`.

---

# Overall Goal

By the end of this sprint I want confidence that:

* The Note Title input field behaves predictably across all interaction states.
* Focus transitions between Header, Title, and Body are liquid and zero-glitch.
* Auto-capitalization, IME actions (`Enter`, `Next`), and keyboard shortcuts operate flawlessly.
* Multi-line paste into Title handles newline stripping safely.
* Title changes sync in real-time with `AppHeaderBar` and persistent SQLite storage without data loss.
* Theme switches (Light, Dark, Custom Glass) render zero pixel overflows or contrast defects.
* Every completed test is documented.
* Every failure is fixed before moving to the next phase.

Do not assume something works.

Everything must be verified on a real device.

---

# Your Responsibilities

For every phase:

1. Inspect the implementation in [note_editor_screen.dart](file:///c:/Users/heman/.gemini/antigravity-ide/scratch/QuickNotes/lib/views/screens/note_editor_screen.dart).
2. Explain what should happen.
3. Generate exhaustive test cases.
4. Wait for me to test on a real device (`SM S918B` or emulator).
5. I will report:
   * ✅ Pass
   * ❌ Fail
   * ⚠️ Unexpected Behaviour
6. Investigate every failure to its exact root cause.
7. Fix the root cause.
8. Re-test.
9. Only after every test in a phase passes may we continue.

Never skip a phase.

---

# Testing Methodology

Each phase contains:

## Phase Overview

* **Purpose**
* **Components Involved** (`_titleController`, `_titleFocusNode`, `Focus`, `AppHeaderBar`, `NotesProvider`, `NotesRepository`)
* **Expected Behaviour**
* **Files Involved** ([note_editor_screen.dart](file:///c:/Users/heman/.gemini/antigravity-ide/scratch/QuickNotes/lib/views/screens/note_editor_screen.dart), [app_header_bar.dart](file:///c:/Users/heman/.gemini/antigravity-ide/scratch/QuickNotes/lib/views/widgets/app_header_bar.dart), [notes_provider.dart](file:///c:/Users/heman/.gemini/antigravity-ide/scratch/QuickNotes/lib/providers/notes_provider.dart))
* **Possible Risks**

---

## Phase Matrix

| Phase | Scope |
| --- | --- |
| **Phase 1** | Title Field Initialization, Autofocus & Focus Lifecycle |
| **Phase 2** | Text Input, Editing & Sentence Auto-Capitalization |
| **Phase 3** | Keyboard Navigation & Focus Transfer (`Enter` / `Next` / `Backspace`) |
| **Phase 4** | Multiline Copy-Paste, Formatting Stripping & Special Characters |
| **Phase 5** | Header Bar (`AppHeaderBar`) Real-Time Title Sync & Fallbacks |
| **Phase 6** | Auto-Save, Database Persistence & Debounce Integrity |
| **Phase 7** | Read-Only, Preview Mode & Security Lock States |
| **Phase 8** | Dynamic Themes, Dark Mode & High-Contrast Typography |
| **Phase 9** | Stress Testing, Rapid Focus Tapping & IME Churn |
| **Phase 10** | Regression Testing & Cross-Component Interaction |
| **Phase 11** | Final Production Validation & Sign-Off |

---

# Detailed Phase Specifications

## Phase 1: Title Field Initialization, Autofocus & Focus Lifecycle

### Purpose
Verify that opening the `NoteEditorScreen` initializes the Title field cleanly under all launch conditions (New Note, Existing Note, Draft Note, Deep-Linked Note).

### Components Involved
* `_titleController`
* `_titleFocusNode`
* `NoteEditorScreen.initState()`

### Test Cases

#### Test 1.1: New Note Launch Autofocus
* **Action**: Tap `+` (New Note) button from Home Screen.
* **Expected**: Note Editor opens; soft keyboard appears automatically; cursor is focused inside the Title field (`"Title"` placeholder visible).
* **Status**: Pass / Fail

#### Test 1.2: Existing Note Launch Focus State
* **Action**: Tap an existing note with title "Weekly Shopping List".
* **Expected**: Note Editor opens displaying "Weekly Shopping List"; Title field is NOT autofocused (keyboard hidden); cursor is not active until tapped.
* **Status**: Pass / Fail

#### Test 1.3: Untitled Note Launch Focus State
* **Action**: Tap an existing note with an empty title string `""`.
* **Expected**: Title field displays `"Title"` hint text with 30% opacity; layout does not shift.
* **Status**: Pass / Fail

---

## Phase 2: Text Input, Editing & Sentence Auto-Capitalization

### Purpose
Verify that typing inside the Title field enforces sentence capitalization, smooth cursor movement, and clean text editing.

### Components Involved
* `TextField` (`textCapitalization: TextCapitalization.sentences`)
* `_titleController`

### Test Cases

#### Test 2.1: Sentence Auto-Capitalization
* **Action**: Type `meeting notes for monday` in Title field.
* **Expected**: The soft keyboard automatically capitalizes the first letter `M` (`"Meeting notes for monday"`).
* **Status**: Pass / Fail

#### Test 2.2: Space & Backspace Cursor Stability
* **Action**: Type `"Project Alpha"`, move cursor between `"Project"` and `"Alpha"`, add spaces and backspace characters.
* **Expected**: Cursor position stays aligned with user touch point without jumping to end of string or resetting.
* **Status**: Pass / Fail

#### Test 2.3: Context Menu (Cut, Copy, Paste, Select All)
* **Action**: Long-press text in Title field; trigger Cut, Copy, Paste, and Select All.
* **Expected**: Native context menu appears cleanly using `_buildContextMenu`; text operations modify Title correctly.
* **Status**: Pass / Fail

---

## Phase 3: Keyboard Navigation & Focus Transfer (`Enter` / `Next` / `Backspace`)

### Purpose
Verify seamless focus handoff between Title field and Body WYSIWYG block editor when using IME action keys.

### Components Involved
* `Focus(onKeyEvent: ...)`
* `TextInputAction.next`
* `_focusContentArea()`

### Test Cases

#### Test 3.1: IME Enter / Next Key Focus Transfer
* **Action**: Type title `"Design Sync"`, tap soft keyboard `Enter` (or `Next` / `Done`) key.
* **Expected**: Title field loses focus; focus transfers smoothly to the first block in the body content editor; soft keyboard remains open.
* **Status**: Pass / Fail

#### Test 3.2: Physical Keyboard Numpad / Main Enter Key Handoff
* **Action**: Connect a physical/Bluetooth keyboard or emulator keyboard; press `Enter` or `Numpad Enter` inside Title field.
* **Expected**: `Focus(onKeyEvent: ...)` intercepts `KeyDownEvent` for `LogicalKeyboardKey.enter`/`numpadEnter`; focus moves to content area without adding a newline `\n` to the Title.
* **Status**: Pass / Fail

#### Test 3.3: Backspace Focus Handoff from Body to Title
* **Action**: Place cursor at index 0 of an empty first paragraph in body area; press `Backspace`.
* **Expected**: Focus moves back up to the Title field; cursor positions at the end of the Title text.
* **Status**: Pass / Fail

---

## Phase 4: Multiline Copy-Paste, Formatting Stripping & Special Characters

### Purpose
Ensure Title field maintains strict single-line integrity (`maxLines: 1`) when pasting complex formatted or multi-line clipboard text.

### Components Involved
* `_titleController`
* Clipboard Manager

### Test Cases

#### Test 4.1: Multiline Text Paste
* **Action**: Copy a 3-line paragraph containing newlines `\n` from another app; paste into Title field.
* **Expected**: Newlines are stripped or converted to single spaces; Title field remains single-line without growing vertically or breaking layout.
* **Status**: Pass / Fail

#### Test 4.2: Emoji & Unicode Character Support
* **Action**: Paste or type complex emojis (`🚀🔥📝✨`), non-Latin characters (`中文`, `العربية`, `हिन्दी`, `Accênted`), and mathematical symbols (`∑π∆`).
* **Expected**: All characters render clearly without box glyphs ``, layout clipping, or cursor offset calculation errors.
* **Status**: Pass / Fail

#### Test 4.3: Ultra-Long Title Input Handling
* **Action**: Type or paste a 300+ character string into the Title field.
* **Expected**: Text scrolls horizontally inside the `TextField` single-line viewport; no horizontal screen overflow or subpixel yellow-black overflow banners.
* **Status**: Pass / Fail

---

## Phase 5: Header Bar (`AppHeaderBar`) Real-Time Title Sync & Fallbacks

### Purpose
Verify that typing in the Title field updates the top `AppHeaderBar` navigation title dynamically with zero lag.

### Components Involved
* `_titleController.addListener(_onTitleTextChanged)`
* `AppHeaderBar` (`title` prop)

### Test Cases

#### Test 5.1: Real-Time Typing Sync with Header
* **Action**: Open Note Editor; type `"Q3 Financial Analysis"`.
* **Expected**: `AppHeaderBar` title updates character-by-character to match `"Q3 Financial Analysis"`.
* **Status**: Pass / Fail

#### Test 5.2: Empty Title Fallback in Header
* **Action**: Clear all text from Title field (`""`).
* **Expected**: `AppHeaderBar` gracefully falls back to displaying `"Untitled Note"` (or `"Edit Note"`), preventing empty space or broken header layout.
* **Status**: Pass / Fail

#### Test 5.3: Long Title Header Truncation
* **Action**: Type a long title `"Comprehensive Systems Architecture and Database Migration Strategy for 2026"`.
* **Expected**: `AppHeaderBar` cleanly truncates long title with ellipsis (`...`) without overflowing header action buttons.
* **Status**: Pass / Fail

---

## Phase 6: Auto-Save, Database Persistence & Debounce Integrity

### Purpose
Ensure changes to Note Title are auto-saved to persistent SQLite storage (`NotesRepository`) reliably without excessive DB writes.

### Components Involved
* `_onTitleTextChanged`
* `_hasChanges` flag
* `NotesProvider.updateNote()`
* SQLite Database v15

### Test Cases

#### Test 6.1: Auto-Save Trigger on Title Edit
* **Action**: Change title from `"Draft 1"` to `"Final Proposal"`; wait 1.5 seconds; tap Back button to exit editor.
* **Expected**: Note title is saved in SQLite database as `"Final Proposal"`; Home Screen / Folder Notes card displays `"Final Proposal"`.
* **Status**: Pass / Fail

#### Test 6.2: Rapid Typing DB Debounce
* **Action**: Rapidly type 50 characters in Title field.
* **Expected**: Database is not spammed with 50 individual write queries; debounce timer aggregates updates into clean single write.
* **Status**: Pass / Fail

#### Test 6.3: Cold Launch Title Persistence
* **Action**: Edit note title to `"Persisted Title Test"`; force close app from task switcher; relaunch app.
* **Expected**: Opening note displays `"Persisted Title Test"`.
* **Status**: Pass / Fail

---

## Phase 7: Read-Only, Preview Mode & Security Lock States

### Purpose
Verify Title field behavior under read-only, markdown preview, folder lock, or passcode locked conditions.

### Components Involved
* `_isPreviewMarkdown`
* `NoteEditorScreen` read-only state

### Test Cases

#### Test 7.1: Markdown Preview Mode Title Lock
* **Action**: Toggle Markdown Preview mode in Note Editor.
* **Expected**: Title field transitions to read-only state; soft keyboard does not open when tapping title in preview mode.
* **Status**: Pass / Fail

#### Test 7.2: Locked Note Title Protection
* **Action**: Open a passcode/biometric locked note after passing authentication.
* **Expected**: Title field renders accurately; locking app or sending to background re-secures title.
* **Status**: Pass / Fail

---

## Phase 8: Dynamic Themes, Dark Mode & High-Contrast Typography

### Purpose
Ensure Title field typography and hint text render with optimal contrast across light, dark, and custom glassmorphism themes.

### Components Involved
* `GoogleFonts.inter`
* `titleColor` resolution logic

### Test Cases

#### Test 8.1: System Light Mode Visual Check
* **Action**: Set device to Light Mode; open Note Editor.
* **Expected**: Title text renders in rich dark color (`#111111` / `#222222`, 24pt bold); hint text `"Title"` renders at 30% opacity with 100% legibility.
* **Status**: Pass / Fail

#### Test 8.2: System Dark Mode Visual Check
* **Action**: Set device to Dark Mode; open Note Editor.
* **Expected**: Title text renders in crisp white/off-white (`#FFFFFF`); hint text renders in subtle dark-mode muted white (`0.3` opacity); no black-on-black text bugs.
* **Status**: Pass / Fail

#### Test 8.3: Custom Note Color Background Contrast
* **Action**: Change note background color (e.g. Yellow, Blue, Purple, Dark Slate).
* **Expected**: `titleColor` dynamically adjusts to maintain WCAG compliant contrast against custom background.
* **Status**: Pass / Fail

---

## Phase 9: Stress Testing, Rapid Focus Tapping & IME Churn

### Purpose
Expose hidden race conditions, memory leaks, or focus loop crashes by subjecting Title field to stress interactions.

### Components Involved
* `_titleFocusNode`
* Soft Keyboard IME controller

### Test Cases

#### Test 9.1: Rapid Focus Tapping (Title ↔ Body ↔ Header)
* **Action**: Rapidly tap between Title field, Body area, and Header bar 30 times in 10 seconds.
* **Expected**: No focus loops, no `NullPointerException`, no keyboard flickering, no app crashes.
* **Status**: Pass / Fail

#### Test 9.2: Rapid Screen Rotation during Title Editing
* **Action**: Type text in Title field; rotate device between Portrait and Landscape 5 times while typing.
* **Expected**: Title text and cursor position remain preserved; layout re-renders without overflow.
* **Status**: Pass / Fail

#### Test 9.3: Rapid Clear and Undo/Redo Churn
* **Action**: Type title, clear completely, trigger Undo/Redo rapidly.
* **Expected**: Title state restores accurately without throwing state exception.
* **Status**: Pass / Fail

---

## Phase 10: Regression Testing & Cross-Component Interaction

### Purpose
Verify that Title field updates do not break search indexing, folder statistics, or task linking.

### Components Involved
* `SearchScreen` indexing
* `FolderNotesScreen` note summary list

### Test Cases

#### Test 10.1: Search Indexing Sync
* **Action**: Change note title to `"UniqueSearchToken2026"`; navigate immediately to Search screen; search for `"UniqueSearchToken2026"`.
* **Expected**: Note appears immediately in search results with matched title highlighted.
* **Status**: Pass / Fail

#### Test 10.2: Folder & Category List Sync
* **Action**: Change title of a note inside `"Work"` folder; navigate to `FolderNotesScreen` for `"Work"`.
* **Expected**: Folder note card reflects updated title immediately.
* **Status**: Pass / Fail

---

## Phase 11: Final Production Validation & Sign-Off

### Status: ✅ PASSED & APPROVED (PRODUCTION READY)

* **Execution Summary**: All 11 QA Sprint Phases executed successfully on physical device (`SM S918B`).
* **Test Results**: 100% test cases marked ✅ **Pass** / Verified.
* **Key Enhancements Built & Verified**:
  1. Liquid Glass frosted Context Menu Toolbar (`RichTextSelectionToolbar`) with title-case labels (`Select All`, `Copy`, `Cut`, `Paste`, `Duplicate`, `Highlight`) and Apple spring haptics (`ee40a2e`).
  2. Single-transaction focus handoff between Title and Body content editor (`_focusContentArea` & `_focusTitleArea`) without soft keyboard flickering (`e0f4149`, `48bbb71`, `8e62643`).
  3. Direct `focusFirstSegment()` delegation bypassing dummy container nodes to prevent keyboard dismissal (`c1eaebc`).
  4. Multi-line title clipboard sanitization, auto-capitalization, and cold-launch SQLite persistence.
* **Regresson Verification**: All 95 automated unit tests passed cleanly (`flutter test`).
* **Final Sign-Off Date**: 2026-08-08.

---

# Documentation & Reporting Protocol

After completing tests for each phase, produce:

## Passed Tests
* List every successful test.

## Failed Tests
* List failures with:
  1. Exact error traceback / behavior description.
  2. Root cause analysis.
  3. Code fix applied.
  4. Retest verification status.

## Exit Criteria
A phase is complete ONLY when:
* All test cases pass on physical device.
* Zero regressions occur.
* Architecture remains single-source-of-truth compliant.
* User explicitly approves moving to next phase.
