# Implementation Plan — Gesture-Level Focus Gating for Production Note Editor

## Objective

Refactor the interaction pipeline so that the software keyboard is **never requested** while the gesture is still being resolved.

This is **not** a visual fix.

This is **not** another `_hideKeyboard()` implementation.

This is an architectural change to eliminate the keyboard race condition at its source.

---

# Current Problem

Current timeline:

```
PointerDown
      │
      ▼
FocusNode.requestFocus()
      │
      ▼
TextInput.attach()
      │
      ▼
Keyboard starts opening
      │
      ▼
GestureArena resolves LongPress (~200ms)
      │
      ▼
_hideKeyboard()
```

The keyboard is already opening before the drag recognizer wins.

The overlay then hides it.

This produces:

* keyboard flashing
* keyboard showing then hiding
* keyboard hiding then showing
* unnecessary IME attach/detach
* extra FocusNode transitions
* unnecessary TextInputClient creation

This is fundamentally a gesture-ordering problem, **not** a keyboard problem.

---

# Desired Architecture

The Gesture Arena must decide the interaction **before** any editor focus request is allowed.

The new order should become:

```
PointerDown
      │
      ▼
Gesture enters pending state
      │
      ▼
Focus requests temporarily blocked
      │
      ▼
GestureArena resolves
      │
      ├─────────────► Single Tap
      │                    │
      │                    ▼
      │             requestFocus()
      │                    │
      │                    ▼
      │             TextInput.attach()
      │                    │
      │                    ▼
      │               Keyboard opens
      │
      └─────────────► Long Press
                           │
                           ▼
                Drag Selection starts
                           │
                           ▼
                 Keyboard never requested
```

There should never be a situation where the keyboard opens simply because the finger touched the editor.

---

# Core Architectural Rule

The overlay becomes the interaction coordinator.

The editor remains purely responsible for editing.

Interaction policy must not live inside:

* NewSingleDocumentEditor
* Renderer V2
* Cursor Engine
* RichTextEditingController

The overlay decides whether the user intends to:

* edit

or

* select

Only after that decision is made may focus be granted.

---

# Focus Gating

Introduce a temporary focus gate during the unresolved gesture period.

Conceptually:

```
PointerDown
↓

Disable editor focus eligibility

↓

Gesture pending (~200ms)

↓

Gesture resolves

↓

IF Tap:
    enable focus
    requestFocus()

ELSE IF LongPress:
    remain unfocused
    start drag selection
```

No call to:

```
FocusNode.requestFocus()
```

may occur while the gesture is still unresolved.

---

# Responsibilities

## SingleDocumentDragOverlay

Owns the interaction policy.

Responsible for:

* entering pending gesture state
* temporarily blocking focus
* deciding tap vs long press
* releasing focus gate
* initiating drag selection

The overlay becomes the single authority for gesture intent.

---

## NewSingleDocumentEditor

No gesture policy.

No keyboard suppression.

No drag-selection decisions.

No knowledge of pending gestures.

Its responsibility remains:

* rendering
* editing
* cursor
* layout

Nothing else.

---

## RichTextEditingController

No modifications.

No keyboard logic.

No gesture logic.

No focus logic.

---

## Cursor Engine

Must remain untouched.

---

## Renderer V2

Must remain untouched.

---

# Keyboard Rules

### Tap

```
PointerDown

↓

Arena resolves TAP

↓

Enable focus

↓

requestFocus()

↓

Keyboard opens
```

Expected behavior.

---

### Long Press

```
PointerDown

↓

Arena pending

↓

Focus blocked

↓

Arena resolves LONG PRESS

↓

Selection begins

↓

Keyboard never opens
```

No hide animation.

No flicker.

No IME attach.

No IME detach.

---

### Handle Drag

Keyboard remains hidden.

No focus requests.

---

### Auto Scroll

Keyboard state unchanged.

---

### Selection Toolbar

Keyboard state unchanged.

---

### Contextual Toolbar

Keyboard state unchanged.

---

# Explicitly Forbidden

Do NOT solve this by:

* calling `_hideKeyboard()` earlier
* adding delays
* Timer hacks
* Future.delayed
* post-frame suppression
* repeated unfocus()
* repeatedly calling TextInput.hide()
* overlaying invisible widgets
* rebuilding EditableText
* modifying Renderer V2
* modifying Cursor Engine
* modifying RichTextEditingController

Those approaches only hide symptoms.

The keyboard must simply never be requested.

---

# Files Expected to Change

Primary:

* single_document_drag_overlay.dart

Possibly:

* note_editor_screen.dart

Only if required for focus gating.

---

# Files That Must Remain Untouched

* new_single_document_editor.dart
* rich_text_controller.dart
* renderer_v2
* cursor engine
* image engine
* formatting engine
* undo/redo
* milestone implementations

---

# Verification

## Single Tap

* Keyboard opens immediately.

## Long Press

* Keyboard never appears.

## Drag Selection

* No keyboard animation.

## Handle Dragging

* Keyboard stays hidden.

## Auto Scroll

* No keyboard changes.

## Selection Toolbar

* Works normally.

## Editing

* Tap after selection restores keyboard normally.

## Regression

Verify:

* typing
* images
* checklist
* formatting
* undo/redo
* cursor engine
* renderer
* drag overlay
* experimental screen

must all behave exactly as before.

---

# Success Criteria

The implementation is complete only if:

* Long-press drag selection never creates a TextInputClient.
* `TextInput.attach()` is never reached during pending gesture resolution.
* The software keyboard is never requested for drag-selection gestures.
* `_hideKeyboard()` is no longer responsible for preventing flicker during drag initiation.
* The drag overlay becomes the sole interaction coordinator while the editor remains a pure editing component.
