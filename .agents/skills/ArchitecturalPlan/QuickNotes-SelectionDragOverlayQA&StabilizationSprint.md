# Quick Notes — SelectionDragOverlay QA & Stabilization Sprint (10,000+ Character Long Note Focus)

Today's objective is **NOT** to add new features.

Today's objective is to make the entire **SingleDocumentDragOverlay & Text Selection Engine production-ready and high-performance**, specifically optimized for **Long Notes exceeding 10,000+ characters (100+ paragraphs / 500+ text lines)**.

We will conduct a complete architectural verification, performance profiling, gesture disambiguation analysis, keyboard focus lifecycle check, handle painting accuracy, auto-scroll responsiveness, and visual stabilization.

I want this session to be treated as a dedicated **QA & Performance Sprint** focused strictly on the `SingleDocumentDragOverlay` widget, high-volume document text selection, and render pipeline optimization.

---

# Overall Goal

By the end of this sprint I want absolute confidence that:

* Long-press gesture recognition triggers word boundary selection instantly on 10,000+ character notes with zero UI jank or main thread stutter.
* Selection drag handles (Start/End handles) move at **60fps / 120fps** on long documents without frame drops or touch input lag.
* The optical magnifier (`RawMagnifier`) tracks touch coordinates fluidly across 10,000+ character documents.
* Multi-segment character offset resolution ([_getGlobalOffsetFromPosition](file:///c:/Users/heman/.gemini/antigravity-ide/scratch/QuickNotes/lib/views/widgets/single_document_drag_overlay.dart#L303-L390)) executes in `< 2ms` per drag update without linear O(N) rendering overhead across 200+ document segments.
* Custom selection highlight painting ([_SDESelectionHighlightPainter](file:///c:/Users/heman/.gemini/antigravity-ide/scratch/QuickNotes/lib/views/widgets/single_document_drag_overlay.dart#L1056-L1263)) avoids executing `getBoxesForSelection()` on off-screen segments in 10,000+ character notes, clipping painting strictly to the visible viewport.
* Edge auto-scrolling on 10,000+ character notes accelerates smoothly near screen boundaries without viewport jumps, position drift, or memory leaks.
* "Select All" on a 10,000+ character note highlights the entire document instantaneously without canvas rendering overload or UI freeze.
* Soft keyboard suppression and focus gating operate cleanly in both focused (Mode 1) and unfocused (Mode 2) states without IME flickering.
* Every completed test and benchmark is documented.
* Every failure or performance jank bottleneck is fixed before moving to the next phase.

Do not assume something works.

Everything must be verified on a real device.

---

# Your Responsibilities

For every phase:

1. Inspect the implementation in [single_document_drag_overlay.dart](file:///c:/Users/heman/.gemini/antigravity-ide/scratch/QuickNotes/lib/views/widgets/single_document_drag_overlay.dart), [new_single_document_editor.dart](file:///c:/Users/heman/.gemini/antigravity-ide/scratch/QuickNotes/lib/views/widgets/new_single_document_editor.dart), [rich_text_controller.dart](file:///c:/Users/heman/.gemini/antigravity-ide/scratch/QuickNotes/lib/views/widgets/rich_text_controller.dart), and [rich_text_selection_toolbar.dart](file:///c:/Users/heman/.gemini/antigravity-ide/scratch/QuickNotes/lib/views/widgets/rich_text_selection_toolbar.dart).
2. Explain what should happen.
3. Generate exhaustive functional, edge-case, and performance benchmark test cases.
4. Wait for me to test on a real device (`SM S918B` or emulator).
5. I will report:
   * ✅ Pass
   * ❌ Fail
   * ⚠️ Unexpected Behaviour / Performance Jank
6. Investigate every failure to its exact root cause.
7. Fix the root cause.
8. Re-test and re-profile.
9. Only after every test in a phase passes may we continue.

Never skip a phase.

---

# Testing Methodology

Each phase contains:

## Phase Overview

* **Purpose**
* **Components Involved** (`SingleDocumentDragOverlay`, `_LongPressDragGestureRecognizer`, `_SDESelectionHighlightPainter`, `RawMagnifier`, `RichTextEditingController`, `NewSingleDocumentEditor`)
* **Expected Behaviour & Target Metrics** (Target: `< 16.6ms` frame budget for 60fps, `< 8.3ms` for 120fps)
* **Files Involved** ([single_document_drag_overlay.dart](file:///c:/Users/heman/.gemini/antigravity-ide/scratch/QuickNotes/lib/views/widgets/single_document_drag_overlay.dart), [new_single_document_editor.dart](file:///c:/Users/heman/.gemini/antigravity-ide/scratch/QuickNotes/lib/views/widgets/new_single_document_editor.dart), [rich_text_controller.dart](file:///c:/Users/heman/.gemini/antigravity-ide/scratch/QuickNotes/lib/views/widgets/rich_text_controller.dart), [rich_text_selection_toolbar.dart](file:///c:/Users/heman/.gemini/antigravity-ide/scratch/QuickNotes/lib/views/widgets/rich_text_selection_toolbar.dart))
* **Possible Risks & Performance Bottlenecks**

---

## Phase Matrix

| Phase | Scope | Target Benchmark |
| --- | --- | --- |
| **Phase 1** | Long-Press Gesture Detection & Word Boundary Expansion | 10,000+ char note word isolation < 16ms |
| **Phase 2** | Selection Drag Handles (Touch, Inversion & Dragging) | 60fps fluid handle dragging on 10,000+ chars |
| **Phase 3** | Optical Magnifier Overlay (`RawMagnifier`) Lifecycle | Zero lag follower positioning on 10,000+ chars |
| **Phase 4** | Global Character Offset Resolution (10,000+ Char Mapping) | Spatial segment lookup / O(log N) offset resolution |
| **Phase 5** | Selection Highlight & Handle Painting (Viewport Optimization) | Visible viewport clipping, 0 offscreen `getBoxes` calls |
| **Phase 6** | Keyboard Suppression, IME Attach/Detach & Dual Focus Gating | Zero IME attach/detach thrashing on long notes |
| **Phase 7** | Viewport Edge Auto-Scrolling on Long Documents (10,000+ Chars) | Smooth 60fps scroll across 500+ text lines |
| **Phase 8** | Contextual Selection Toolbar & High-Volume Operations | "Select All" on 10,000+ chars in < 30ms |
| **Phase 9** | Multi-Segment & Image Segment Spanning in Long Notes | Spanning 50+ mixed text & image blocks |
| **Phase 10** | Tap Disambiguation, Caret Repositioning & Selection Clearing | Instant selection clear on 10,000+ char document |
| **Phase 11** | 10,000+ Character Performance Profiling & Frame Budget Analysis | Frame time profiling: < 16.6ms frame budget |
| **Phase 12** | Stress Testing, Screen Rotation & Memory Leak Audit | 100+ rapid handle drags, zero memory growth |
| **Phase 13** | Regression Testing & System Integration Verification | Zero breakage in editor features, title, or tasks |
| **Phase 14** | Real Device Final Production Validation & Sign-Off | Physical hardware sign-off on 10,000+ char note |

---

# Detailed Phase Specifications

## Phase 1: Long-Press Gesture Detection & Word Boundary Expansion (10,000+ Chars)

### Purpose
Verify that long-press gestures on a 10,000+ character document trigger word boundary text selection instantly (200ms threshold) with medium impact haptic feedback and zero UI thread stutter.

### Components Involved
* `_LongPressDragGestureRecognizer`
* `_onLongPressDetected()`
* `_getWordBoundaryAtOffset()`
* `HapticFeedback.mediumImpact()`

### Test Cases

#### Test 1.1: 10,000+ Character Document Word Selection
* **Action**: Open a note containing **10,000+ characters** (e.g. 100 paragraphs); scroll to paragraph 50; long-press on a word for 200ms.
* **Expected**: Medium impact haptic plays; target word is highlighted in semi-transparent selection blue (`Color(0x503B82F6)`); start and end handles appear in `< 16ms`.
* **Status**: Pass / Fail

#### Test 1.2: Scroll vs Long-Press Gesture Disambiguation on Long Note
* **Action**: Perform rapid vertical scrolling gestures on a 10,000+ character document.
* **Expected**: `_LongPressDragGestureRecognizer` rejects gesture clean; viewport scrolls smoothly at 60fps/120fps; selection overlay does not trigger mistakenly.
* **Status**: Pass / Fail

#### Test 1.3: Unicode & Multi-Byte Character Parsing Speed
* **Action**: Long-press on a word inside a 10,000+ character document containing mixed emojis, non-Latin scripts (Chinese, Arabic, Devanagari), and accented characters.
* **Expected**: `_getWordBoundaryAtOffset` isolates word boundary accurately in `< 1ms` without freezing the main thread.
* **Status**: Pass / Fail

---

## Phase 2: Selection Drag Handles (Start/End Handle Touch & Dragging on 10,000+ Chars)

### Purpose
Verify that dragging start or end circular handles across a 10,000+ character document updates text selection extent smoothly at 60fps, supporting handle cross-over inversion without layout jank.

### Components Involved
* `_isTouchOnHandle()`
* `_handlePanStart()` / `_handlePanUpdate()`
* `_updateSelectionForStartHandle()` / `_updateSelectionForEndHandle()`

### Test Cases

#### Test 2.1: 60fps Handle Dragging across 1,000+ Lines
* **Action**: Touch down on End Handle in a 10,000+ character note; drag horizontally and vertically across 20 text lines.
* **Expected**: Handle follows finger with zero latency; selection updates smoothly on every frame (60fps); selection click haptics fire cleanly.
* **Status**: Pass / Fail

#### Test 2.2: Handle Cross-Over Inversion on High-Volume Selection
* **Action**: Rapidly drag Start Handle to the right past End Handle across 5,000 characters.
* **Expected**: Handle roles invert instantly (`_isDraggingStartHandle` ↔ `_isDraggingEndHandle`); selection range remains valid without index overflow errors.
* **Status**: Pass / Fail

---

## Phase 3: Optical Magnifier Overlay (`RawMagnifier`) Lifecycle & Positioning

### Purpose
Ensure that active handle dragging on a 10,000+ character note displays the floating optical magnifier (`RawMagnifier`) centered 85px above touch coordinates with smooth tracking and zero visual artifacts.

### Components Involved
* `RawMagnifier` (`size: 90x50`, `magnificationScale: 1.25`, `focalPointOffset: Offset(0, 60)`)
* `localMagnifierPos` calculation
* `isDragging` state

### Test Cases

#### Test 3.1: Magnifier Smooth Tracking on Long Note
* **Action**: Drag selection handle continuously up and down a 10,000+ character note.
* **Expected**: Magnifier tracks finger position smoothly without micro-stutter or frame drops.
* **Status**: Pass / Fail

#### Test 3.2: Instant Magnifier Dismissal
* **Action**: Release touch drag on a long note.
* **Expected**: Magnifier disappears instantly without lingering in overlay stack.
* **Status**: Pass / Fail

---

## Phase 4: Global Character Offset Resolution (10,000+ Char Mapping Optimization)

### Purpose
Verify that [_getGlobalOffsetFromPosition](file:///c:/Users/heman/.gemini/antigravity-ide/scratch/QuickNotes/lib/views/widgets/single_document_drag_overlay.dart#L303-L390) calculates character offsets efficiently across 200+ text segments without linear O(N) performance degradation on every drag frame.

### Components Involved
* `_findRenderEditable()`
* `RenderEditable.getPositionForPoint()`
* `_getGlobalOffsetFromPosition()` (Performance Profiling)

### Test Cases

#### Test 4.1: Offset Resolution Benchmark on 200+ Segments
* **Action**: Profile execution time of `_getGlobalOffsetFromPosition` during active drag on a 10,000+ character note with 200 text segments.
* **Expected**: Offset resolution completes in `< 2ms` per frame (utilizing Y-coordinate spatial clipping to bypass off-screen RenderBox checks).
* **Status**: Pass / Fail

#### Test 4.2: Top and Bottom Document Boundary Touch Resolution
* **Action**: Drag handle above highest visible segment or below lowest visible segment in a 10,000+ character note.
* **Expected**: Accurately resolves to `highestMountedStart` (0) or `lowestMountedEnd` (10,000) without crashing.
* **Status**: Pass / Fail

---

## Phase 5: Selection Highlight & Handle Painting (Viewport Optimization for 10,000+ Chars)

### Purpose
Ensure [_SDESelectionHighlightPainter](file:///c:/Users/heman/.gemini/antigravity-ide/scratch/QuickNotes/lib/views/widgets/single_document_drag_overlay.dart#L1056-L1263) paints selection highlights exclusively for segments visible in the viewport, avoiding expensive `getBoxesForSelection()` calls on off-screen lines in 10,000+ character notes.

### Components Involved
* `_SDESelectionHighlightPainter`
* Viewport clipping logic
* `canvas.drawRRect()` / `canvas.drawCircle()`

### Test Cases

#### Test 5.1: Visible Viewport Paint Clipping Profile
* **Action**: Select 5,000 characters spanning 50 paragraphs in a 10,000+ character note; profile canvas paint execution time.
* **Expected**: Painter skips `getBoxesForSelection()` for off-screen segments; total paint time per frame is `< 3ms`.
* **Status**: Pass / Fail

#### Test 5.2: Pixel-Perfect Handle & Highlight Rendering
* **Action**: Inspect active selection highlights on a long note under high zoom.
* **Expected**: Semi-transparent blue highlights (`Color(0x503B82F6)`) and handles paint accurately with zero visual tearing or sub-pixel alignment errors.
* **Status**: Pass / Fail

---

## Phase 6: Keyboard Suppression, IME Attach/Detach & Dual Focus Gating Modes

### Purpose
Verify focus gating ([_setFocusGated](file:///c:/Users/heman/.gemini/antigravity-ide/scratch/QuickNotes/lib/views/widgets/single_document_drag_overlay.dart#L841-L849)) on long notes to prevent soft keyboard flickering or IME attach/detach thrashing during high-volume selection dragging.

### Components Involved
* `_wasEditorFocusedOnDown`
* `_setFocusGated(bool gated)`
* `_hideKeyboard()`
* `PointerDownEvent` / `PointerUpEvent`

### Test Cases

#### Test 6.1: Mode 1 (Editor Focused) Selection Drag on Long Note
* **Action**: Open 10,000+ character note with keyboard visible; long-press and drag selection across 10 paragraphs.
* **Expected**: Keyboard suppresses cleanly; focus gating preserves node focus state without IME thrashing.
* **Status**: Pass / Fail

#### Test 6.2: Mode 2 (Editor Unfocused) Selection Drag on Long Note
* **Action**: Long-press text on a 10,000+ character note when keyboard is hidden.
* **Expected**: Focus is gated (`canRequestFocus = false`); soft keyboard does not flash open during long-press gesture detection.
* **Status**: Pass / Fail

---

## Phase 7: Viewport Edge Auto-Scrolling on Long Documents (10,000+ Chars)

### Purpose
Verify that dragging selection handles near top (140px threshold) or bottom (150px threshold) screen edges in a 10,000+ character note triggers smooth auto-scrolling across hundreds of text lines with quadratic velocity scaling.

### Components Involved
* `_calculateScrollDelta()`
* `_startAutoScrollIfNeeded()`
* `_autoScrollTimer` (16ms periodic loop)

### Test Cases

#### Test 7.1: Continuous 5,000+ Character Auto-Scroll
* **Action**: Hold selection handle near bottom screen threshold in a 10,000+ character note for 5 seconds.
* **Expected**: Document auto-scrolls down smoothly across 50+ paragraphs; selection extent updates continuously at 60fps without jank or scroll jump.
* **Status**: Pass / Fail

#### Test 7.2: Velocity Acceleration Profile
* **Action**: Push handle closer to screen edge on a long note.
* **Expected**: Scroll velocity scales smoothly up to ~50px/frame; timer stops cleanly the instant finger moves back to viewport center or lifts.
* **Status**: Pass / Fail

---

## Phase 8: Contextual Selection Toolbar & High-Volume Operations ("Select All" on 10,000+ Chars)

### Purpose
Verify that floating contextual toolbar (`ContextualBar` / `RichTextSelectionToolbar`) actions execute reliably on high-volume selections (10,000+ characters) without UI freeze or memory overflow.

### Components Involved
* `ContextualBar`
* `RichTextSelectionToolbar`
* "Select All" operation (0 to 10,000+ offset range)

### Test Cases

#### Test 8.1: "Select All" on 10,000+ Character Document Benchmark
* **Action**: Tap **Select All** on a 10,000+ character document.
* **Expected**: Full selection (0 to 10,000+) highlights in `< 30ms`; handles position at document start and end; contextual toolbar remains responsive.
* **Status**: Pass / Fail

#### Test 8.2: High-Volume Copy-Paste Operation
* **Action**: Select 10,000 characters; tap **Copy**; paste into a new note.
* **Expected**: System clipboard receives full text instantly without truncation or memory crash.
* **Status**: Pass / Fail

---

## Phase 9: Multi-Segment & Image Segment Spanning in Long Notes

### Purpose
Ensure selection drag can span continuously across mixed document content in long notes containing text paragraphs, headings, checklists, and multiple inline `ImageSegment` widgets.

### Components Involved
* `ImageSegment` selection rect painting
* `sdeKey.currentState.allSegments`
* `_SDESelectionHighlightPainter.paint()`

### Test Cases

#### Test 9.1: Multi-Image & Multi-Paragraph Spanning Drag
* **Action**: In a 10,000+ character note containing 5 inline images, drag selection across 30 paragraphs and 3 images.
* **Expected**: Text paragraphs display standard text selection boxes; inline images display 8px rounded selection overlay boxes; dragging remains smooth.
* **Status**: Pass / Fail

---

## Phase 10: Tap Disambiguation, Caret Repositioning & Selection Clearing

### Purpose
Verify that quick taps outside active selection on a 10,000+ character note clear selection instantly and reposition collapsed caret cleanly without lingering handle artifacts.

### Components Involved
* `PointerUpEvent` handling
* `TextSelection.collapsed(offset: rawOffset)`

### Test Cases

#### Test 10.1: Quick Tap Selection Clear on Long Note
* **Action**: With 5,000 characters selected on a long note, quick tap (< 300ms) on unselected text area.
* **Expected**: Active selection clears instantly in `< 16ms`; caret positions at tapped character offset; contextual toolbar dismisses cleanly.
* **Status**: Pass / Fail

---

## Phase 11: 10,000+ Character Performance Profiling & Frame Budget Analysis

### Purpose
Execute systematic performance profiling of `SingleDocumentDragOverlay` on 2,000, 5,000, and 10,000+ character documents to guarantee frame times remain within target budgets (< 16.6ms for 60fps, < 8.3ms for 120fps).

### Baseline Benchmark Matrix

| Document Size | Target Frame Time | Target Drag Latency | Target "Select All" Time | Status |
| --- | --- | --- | --- | --- |
| **2,000 chars** | `< 8.3ms` (120fps) | `< 10ms` | `< 15ms` | Pending Benchmark |
| **5,000 chars** | `< 16.6ms` (60fps) | `< 16ms` | `< 25ms` | Pending Benchmark |
| **10,000+ chars** | `< 16.6ms` (60fps) | `< 16ms` | `< 30ms` | Pending Benchmark |

### Test Cases

#### Test 11.1: 10,000+ Character Frame Budget Profiling
* **Action**: Attach Flutter DevTools Performance Overlay; perform 10-second continuous selection handle drag on a 10,000+ character document.
* **Expected**: Zero raster/UI thread frame spikes above 16.6ms (0 red jank bars on DevTools performance chart).
* **Status**: Pass / Fail

---

## Phase 12: Stress Testing, Screen Rotation & Memory Leak Audit

### Purpose
Subject selection drag overlay on long notes to extreme interaction patterns, rapid touch churn, and device rotations to expose memory leaks, ghost timers, or state desynchronization.

### Components Involved
* `_autoScrollTimer` disposal
* `State.dispose()`
* Memory profiler

### Test Cases

#### Test 12.1: 100+ Rapid Drag Handle Churn on Long Note
* **Action**: Rapidly tap, drag, release start and end handles 100 times in 30 seconds on a 10,000+ character note.
* **Expected**: Zero memory leaks; active memory remains constant; no ghost auto-scroll timers remain running.
* **Status**: Pass / Fail

#### Test 12.2: Screen Rotation during 10,000+ Character Selection
* **Action**: Select 3,000 characters in a long note; rotate device between Portrait and Landscape 5 times.
* **Expected**: Overlay re-computes handle coordinates accurately for new layout bounds; selection text range is preserved without crash.
* **Status**: Pass / Fail

---

## Phase 13: Regression Testing & System Integration Verification

### Purpose
Ensure optimizations in `SingleDocumentDragOverlay` for long notes do not regress standard editor features, title section editing, or task checklist toggling.

### Components Involved
* `NoteEditorScreen`
* `NewSingleDocumentEditor`
* `RichTextEditingController`

### Test Cases

#### Test 13.1: Title Section & Editor Body Handoff
* **Action**: Select text in a 10,000+ character body; tap Note Title field.
* **Expected**: Body selection overlay clears cleanly; focus transfers to Title field without soft keyboard overlap bugs.
* **Status**: Pass / Fail

#### Test 13.2: Checklist Item Checkbox Toggling
* **Action**: Tap checklist checkbox in a 10,000+ character note while drag overlay is active.
* **Expected**: Checkbox toggles state without drag overlay intercepting pointer events.
* **Status**: Pass / Fail

---

## Phase 14: Real Device Final Production Validation & Sign-Off

### Purpose
Final verification phase across physical Android/iOS hardware (`SM S918B` or similar flagship device) to confirm 60fps/120fps fluid rendering on 10,000+ character documents and sign off for production deployment.

### Exit Checklist
* [ ] 100% test cases across Phases 1–13 marked ✅ **Pass**.
* [ ] Frame budget verified on physical hardware: `< 16.6ms` per frame on 10,000+ character documents.
* [ ] Zero `RenderEditable` or layout bounds exceptions in `flutter logs`.
* [ ] "Select All" on 10,000+ character document completes in `< 30ms`.
* [ ] Full regression test suite passed (`flutter test`).

---

# Documentation & Reporting Protocol

After completing tests for each phase, produce:

## Passed Tests
* List every successful test and recorded performance benchmark.

## Failed Tests & Bottlenecks
* List failures with:
  1. Exact error traceback / performance jank description.
  2. Root cause analysis (e.g. O(N) RenderBox traversal, unnecessary `getBoxesForSelection` calls).
  3. Code fix applied.
  4. Retest & re-profile verification status.

## Remaining Risks
* List any hardware-specific or OS-level behaviors requiring ongoing monitoring.

---

# Exit Criteria

A phase is complete ONLY when:
* All functional and performance benchmark tests pass on physical device.
* All edge cases pass.
* No regressions remain.
* Performance target (< 16.6ms frame budget on 10,000+ char notes) is achieved.
* User explicitly approves the phase.

Only then may we proceed to the next phase.

---

# Sprint Execution & Architectural Fix Log

## Phase 1 Execution & Stabilization Log

### 1. Issue: Double Blue Selection Color Artifact (Test 1.1)
* **Symptom**: Dark blue and light blue double-stacked selection highlights appeared over selected text.
* **Root Cause**: Segment `TextField` instances in [`new_single_document_editor.dart`](file:///c:/Users/heman/.gemini/antigravity-ide/scratch/QuickNotes/lib/views/widgets/new_single_document_editor.dart) painted native `TextSelectionTheme` blue selection backgrounds underneath [`_SDESelectionHighlightPainter`](file:///c:/Users/heman/.gemini/antigravity-ide/scratch/QuickNotes/lib/views/widgets/single_document_drag_overlay.dart)'s custom selection blue overlay, causing stacked color opacity.
* **Fix Applied**: Wrapped segment `TextField` instances in `TextSelectionTheme(data: TextSelectionThemeData(selectionColor: Colors.transparent))`. Native selection background is now disabled; selection highlights are rendered exclusively by `_SDESelectionHighlightPainter`.

### 2. Issue: Selection Dragging Capped/Stopped on 10,000+ Character Notes (Test 1.2)
* **Symptom**: Handle dragging stopped advancing at ~2,500 characters on 10,000+ character notes.
* **Root Cause**: `_getGlobalOffsetFromPosition` in [`single_document_drag_overlay.dart`](file:///c:/Users/heman/.gemini/antigravity-ide/scratch/QuickNotes/lib/views/widgets/single_document_drag_overlay.dart) returned `lowestMountedEnd` when touch `dy` moved past `lowestMountedBottom`. This capped selection extent at the bottom edge of mounted visible text lines on screen.
* **Fix Applied**: Updated `_getGlobalOffsetFromPosition` boundary logic: when `globalPosition.dy > lowestMountedBottom`, it now returns `sdeState.textSegments.last.end` (total document end), allowing selection to expand continuously across unmounted segments during downward auto-scroll.

### 3. Issue: Soft Keyboard Flickering/Popping Mid-Drag
* **Symptom**: Soft keyboard popped up and collapsed repeatedly ("coming and hiding") while dragging handles across text segments.
* **Root Cause**: Segment `TextField` instances had `readOnly: false`. Whenever selection updated on a `readOnly: false` field as handles moved across segment boundaries, Flutter's native `EditableTextState` dispatched `TextInput.show()` / `TextInput.attach()` to Android OS, competing with `SingleDocumentDragOverlay`'s `unfocus()` calls.
* **Fix Applied**: Added dynamic `effectiveReadOnly = widget.readOnly || (widget.controller.selection.isValid && !widget.controller.selection.isCollapsed)` in [`new_single_document_editor.dart`](file:///c:/Users/heman/.gemini/antigravity-ide/scratch/QuickNotes/lib/views/widgets/new_single_document_editor.dart). While selection handles are active or dragging, all segment `TextField`s dynamically switch to `readOnly: true`, completely bypassing Flutter's native OS keyboard request calls. Also added `SystemChannels.textInput.invokeMethod('TextInput.hide')` in `SingleDocumentDragOverlay`.
* **Editor Safeguard**: When selection is cleared by a single tap, `effectiveReadOnly` automatically reverts to `false`, restoring normal caret typing focus without regressing any `NoteEditor` typing functionality.

