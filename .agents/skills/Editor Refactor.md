📖 Quick Notes — Single Document Editor Roadmap (v2)
🏗️ Milestone 0 — Architecture Foundation ✅

Status: Complete

Goal

Replace the legacy Block-Based Editor with a Single Document Editor (SDE).

Deliverables
Single source of truth (RichTextEditingController)
Markdown persistence
Undo/Redo
Document model
Renderer abstraction
Remove Block Editor dependencies
🖼️ Milestone 1 — Renderer Foundation ✅

Status: Complete & Device Verified

Goal

Build Renderer V2 and separate rendering from editing logic.

Deliverables
Paragraph → Image → Paragraph rendering
Standalone image widgets
Renderer parses document segments
Document remains unchanged
Save/load compatibility
Not Included
Cursor logic
Scrolling
Layout polish
Image interactions
✏️ Milestone 2 — Cursor Engine

Status: Planned

Goal

Make editing feel natural.

Deliverables
Automatic cursor placement after image insertion
Intelligent focus routing
Arrow key navigation
Tap-to-place cursor
Paragraph traversal
Cursor restoration
Caret synchronization
Not Included
Auto scrolling
Image controls
Layout
📜 Milestone 3 — Viewport & Scrolling Engine

Status: Planned

Goal

Keep the active writing area comfortably visible.

Deliverables
Smart auto-scroll
Keyboard avoidance
RTF toolbar avoidance
ensureVisible() improvements
Scroll to active paragraph
Dynamic bottom padding
Smooth viewport transitions
Not Included
Layout
Rich content interactions
🎨 Milestone 4 — Layout Engine

Status: Approved

Goal

Transform the document into a structured, visually balanced editor.

Deliverables
Centralized LayoutEngine
Dynamic vertical rhythm
Consistent horizontal margins
Line-level segmentation
Heading typography
Quote styling
Static checklist/bullet/number layouts
Image spacing
Hidden prefix rendering
Focus traversal across layout
Not Included
Interactive checkboxes
Rich block mutations
Image resizing
🧩 Milestone 5 — Rich Content Engine

Status: Next

Goal

Bring every document block to life.

Deliverables
Images
Resize handles
Drag resizing
Replace image
Delete image
Image toolbar
Aspect ratio locking
Maximum width rules
Lists
Interactive checkboxes
Toggle completion
Smart numbering
Indentation
Rich Blocks
Tables
Code blocks
Attachments
Audio blocks (future-ready)
Drawing placeholders
Not Included
AI features
Premium animations
🧠 Milestone 6 — Editor Intelligence
Goal

Make the editor feel "smart."

Deliverables
Smart Enter behavior
Smart Backspace
Intelligent list continuation
Auto heading continuation
Smart checklist continuation
Paste normalization
Rich paste handling
Automatic paragraph creation
Context-aware formatting
Selection improvements
Multi-paragraph operations

This is where the editor starts feeling like Apple Notes or Samsung Notes.

✨ Milestone 7 — Premium Polish
Goal

Deliver a world-class editing experience.

Deliverables
Animations
Spring animations
Image insertion animation
Smooth toolbar transitions
Keyboard transitions
Micro Interactions
Haptic feedback
Selection animations
Toolbar highlights
Floating cursor polish
Performance
Lazy rendering
Incremental updates
Rendering optimization
Memory optimization
Visual Polish
Pixel-perfect spacing
Typography refinement
Motion tuning
Accessibility improvements
🚀 Milestone 8 — Advanced Features (Future)

This milestone isn't necessary for your MVP, but it's where Quick Notes can grow.

Possible features
Apple Pencil / stylus support
Freehand drawing
OCR (scan text from images)
PDF annotations
Voice notes
Audio transcription
Document links
Backlinks
Smart tags
AI summaries
AI formatting
AI search
Version history
Real-time collaboration
Cross-note linking