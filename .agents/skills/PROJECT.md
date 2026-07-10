Project Name: Quick Notes

This project is independent.

It is NOT Gravity Notes.

Although originally derived from Gravity Notes,
its architecture and future development are separate.

Any references to Gravity Notes should be treated as legacy and ignored unless explicitly requested.

Goal:
Fast minimal note-taking.

Design:
Apple-inspired.

Current Progress:
85%

## Functionalities

### 1. Rich Text & Note Editing
* **Single Document Editor (SDE) Architecture**: Monolithic text editing has been replaced with a unified rich text editing architecture (RichTextEditingController) supporting inline Headings, Paragraphs, Checklists, Quotes, Dividers, and Resizable Images in a single text view, which is the single source of truth.
* **Formatting & Markdown**: Supports structured inline text styling, including headers (`#` to `######`), highlight formatting, and list structures.
* **Living caret and typing**: Integrates a custom breathing caret/cursor and character-level spring animations as characters are typed.
* **Layout Alignment**: Supports left, center, and right alignment on text.
* **Metrics Dashboard**: Displays real-time word count, character count, and estimated reading time.
* **Zen Focus Mode**: Automatically hides secondary UI elements (app bars, toolbars, tags) during active typing to enable distraction-free writing.
* **Checklist Escaping**: Clean keyboard navigation to exit checklist mode by pressing Enter or Backspace on empty checklists.
* **Centralized Spacer System**: Visual spacing is managed centrally for an Apple Notes style aesthetic.

### 2. Multi-Media Attachments
* **Image Integration**: Users can snap images with the camera, import from the system gallery, or insert preset images from a library.
* **Interactive Resizing**: Handles on both left and right edges allow smooth drag resizing of inline images.
* **Gesture & Hero Image Viewer**: Single-tap to focus and reveal captioned settings/resize handles, and double-tap to open the fullscreen viewer featuring Hero transitions and interactive pinch-to-zoom.
* **Voice Recorder**: Built-in voice message recording, duration tracking, and playback interface directly inside the note.

### 3. Organization & Metadata
* **Custom Folder Hierarchy**: Group notes into a clean directory structure with nested subfolders.
* **Safeguarded Deletion**: Deleting a folder detaches notes and promotes child folders to prevent accidental data loss.
* **Flexible Categories**: Tag notes under preset categories (Personal, Work, Ideas, Study, Uncategorized).
* **Tagging System**: Add and delete custom tags to notes, with a dedicated tags filter bar.
* **Advanced Filtering & Sorting**: Filter notes by category, tag, or folder, and sort them alphabetically or chronologically (Newest/Oldest), with pinned notes prioritizing placement.

### 4. Security & Privacy (The Vault)
* **Secure Notes**: Encrypt sensitive note titles and content using AES encryption.
* **Authentication Lock**: Access-restricted folder ("Vault") that requires entering a Passcode PIN or Biometric verification to view.

### 5. Habit & Goal Tracking
* **Habit Checklists**: Designate checklist notes as habits with recurrence patterns (Daily/Weekly).
* **Streak Maintenance**: Automatically tracks streak counts and resets checklist items at the start of new daily/weekly cycles.

### 6. Personalization & Themes
* **Theme Options**: Support for a full light and dark mode palette.
* **Color Themes**: Select background color overlays from a premium Apple-inspired palette (Default, Coral, Peach, Lemon, Sage, Sky, Lavender, Blush) with text color auto-calibrating for contrast.
* **Typography**: Customizable typography using Outfit and Plus Jakarta Sans google fonts.
* **Tactile Micro-Animations**: Pop-style spring effects on buttons (FAB compression) and layout-preserving FLIP transitions when lists update.

### 7. Import & Export Engine
* **Export Options**: Export notes to Markdown (`.md`), HTML, PDF, JSON, or Plain Text.
* **Import Options**: Import notes from JSON back-ups or raw text.

### 8. Backup & System Integrations
* **Trash Recycler**: Deleted notes go to a Trash folder where they can be restored or permanently purged.
* **Home Screen Widget Sync**: Synchronizes with an Android home screen widget to display real-time pinned note counts.

