# Gravity Notes - Full Feature Documentation 🚀

Gravity Notes is a premium, high-performance Android note-taking application built with Flutter using Clean Architecture, Material 3 design, SQLite local persistence, and Provider state management. 

This document details all features, architectural services, database schemas, and workflows implemented in Gravity Notes.

---

## 📖 Table of Contents
1. [Core Note-Taking & Rich Text Editing](#1-core-note-taking--rich-text-editing)
2. [Note Types (Text & Interactive Checklists)](#2-note-types-text--interactive-checklists)
3. [Hierarchical Folder Structure](#3-hierarchical-folder-structure)
4. [Habits & Routines Engine](#4-habits--routines-engine)
5. [Secure Vault (AES-256-CBC Encryption & Biometrics)](#5-secure-vault-aes-256-cbc-encryption--biometrics)
6. [Rich Media Attachments (Images & Audio)](#6-rich-media-attachments-images--audio)
7. [Reminders & Local Notifications](#7-reminders--local-notifications)
8. [Advanced Export & Sharing Framework](#8-advanced-export--sharing-framework)
9. [Android Home Screen Widgets & Deep Linking](#9-android-home-screen-widgets--deep-linking)
10. [Database Architecture & Migrations](#10-database-architecture--migrations)

---

## 1. Core Note-Taking & Rich Text Editing
Gravity Notes offers a modern and responsive user interface following Material 3 guidelines.

* **Full CRUD Operations**: Create, read, update, and delete notes instantly.
* **Smart Sorting**: Sort notes dynamically from a bottom-sheet:
  * *Newest First*: Notes updated recently appear first.
  * *Oldest First*: Oldest notes appear first.
  * *Alphabetical*: Sorted A-Z based on the note title.
* **Categorization**: Group notes into predefined default categories:
  * `Personal`
  * `Work`
  * `Ideas`
  * `Study`
  * `Uncategorized`
* **Custom Color Palette**: Personalize note cards with 8 premium color index options:
  * 0: `Default` (Dynamic Theme-based card color)
  * 1: `Coral` (Light Pastel Coral / Dark Mahogany)
  * 2: `Peach` (Light Pastel Peach / Dark Terracotta)
  * 3: `Lemon` (Light Pastel Yellow / Dark Olive Green)
  * 4: `Sage` (Light Pastel Sage / Dark Forest Green)
  * 5: `Sky` (Light Pastel Sky Blue / Dark Navy Blue)
  * 6: `Lavender` (Light Pastel Lavender / Dark Royal Purple)
  * 7: `Blush` (Light Pastel Pink / Dark Burgundy)
  * Note text and category badge colors adapt automatically to the background color for maximum contrast and readability.
* **Tagging System**: Add custom `#tags` to any note. Filter notes instantly by tapping any tag in the navigation drawer.
* **Real-time Statistics**: Inside the editor, a status bar displays live character and word counts.
* **Draft Auto-save**: Editor changes are automatically saved when navigating backward, avoiding accidental data loss.
* **Undo SnackBar**: Deleting a note displays a SnackBar with an "Undo" action, allowing users to restore notes and reschedule active reminder alarms.

---

## 2. Note Types (Text & Interactive Checklists)
Notes are divided into two main formats:
* **Standard Text Notes**:
  * Rich Text Editing that supports **Markdown** syntax rendering.
  * Easy edit/preview toggle button (`menu_book` / `text_snippet`) in the app bar to switch between raw text editing and parsed Markdown viewing.
* **Interactive Checklist Notes**:
  * Structured checklist fields with add/remove buttons.
  * Real-time checkbox state toggle (automatically updates progress).
  * Note cards on the main feed show a **3-item checklist preview** with a "+ X more tasks" indicator, along with a fraction and percentage progress indicator (e.g., "2 of 5 items completed | 40%").

---

## 3. Hierarchical Folder Structure
For organization, Gravity Notes supports a nested folder directory tree.
* **Infinite Nesting**: Folders can reference a `parentId` to support multiple levels of subfolders.
* **Visual Representation**:
  * Dropdowns and drawer listings use indentations and connectors (e.g., `└─ Subfolder`) built via Depth-First Search (DFS) in `FolderUtils.getHierarchicalFolders`.
  * Open folder icons represent subfolders, while closed folder icons represent root-level folders.
* **Note Assignment**: Easily move a note between different folders or back to "Root (No Folder)" from a dropdown menu.
* **Safe Deletion Handling**: Deleting a folder does **NOT** delete its internal notes or subfolders. Gravity Notes automatically detaches notes and moves them to the root level. Child folders are likewise moved to the root level as independent folders to prevent orphaned database records.

---

## 4. Habits & Routines Engine
Gravity Notes turns simple checklists into recurring habits.
* **Habit Activation**: Toggle any checklist note as a habit and configure a Daily or Weekly reset interval.
* **Habits & Routines Dashboard**: A dedicated grid visualization screen displaying active habits, current streaks, completion progress, and progress bars.
* **Periodic Reset Engine**: Every time notes are loaded, the app runs a reset check (`_checkAndResetHabits`):
  * Checks if the reset interval has passed since `habitLastCompleted`.
  * If the checklist is **fully completed (100%)**, it increments the **Streak Counter** by 1.
  * If the checklist was **not completed**, it resets the streak to **0** (streak miss penalty).
  * Automatically unchecks all checklist items, resets status, and stamps `habitLastCompleted` with the current time.
* **Streak Indicators**: Streaks are represented by a flame icon on note cards and dashboards (colors orange when streak is > 0).

---

## 5. Secure Vault (AES-256-CBC Encryption & Biometrics)
Gravity Notes provides high-grade security for sensitive information.
* **AES-256-CBC Encryption**: 
  * Secured notes are encrypted locally before being stored in the SQLite database.
  * A random 256-bit secure Master Key is generated upon setup and stored inside `FlutterSecureStorage`.
  * A 16-byte random Initialization Vector (IV) is generated for each encryption call. The ciphertext is saved in the format `iv_base64:ciphertext_base64` so that identical text values encrypt to different outputs.
* **Lock Settings**: Set a custom 4-digit PIN (default passcode is `1234` if not configured).
* **Biometric Authentication**: If available on the device and enabled in Vault settings, users can unlock the vault using Face ID or Fingerprint scanning.
* **In-Memory Protection**:
  * Note titles and contents are scrubbed in memory (displayed as "🔐 Locked Note" and "[Unlocked with authentication]") until successfully unlocked.
  * Re-locking the vault immediately clears all decrypted models from the app state.
  * When search is conducted with a locked vault, the app queries only the database of unencrypted notes. When unlocked, it performs in-memory decrypted searches.

---

## 6. Rich Media Attachments (Images & Audio)
Users can attach media directly to their notes.
* **Image Attachments**: 
  * Pick images from the device gallery or take photos directly using the camera.
  * Displayed in a swipeable horizontal layout at the top of the editor and as a top banner on the note cards.
* **Voice Recording**: 
  * Capture audio memos using the device microphone.
  * Recorded in AAC format and saved as `.m4a` files.
  * Displays a live recording panel with a duration timer (`mm:ss`).
* **Integrated Audio Player**:
  * Audio recordings are rendered inside a custom panel within the editor.
  * Features play, pause, seek, and delete actions directly from the notes view.

---

## 7. Reminders & Local Notifications
Set alarms to stay organized and receive timely notifications.
* **Timezone-Aware Alarms**: Alarms are set relative to the device's local timezone using the `timezone` package.
* **Zoned Scheduling**: Uses `zonedSchedule` from `flutter_local_notifications` with `AndroidScheduleMode.exactAllowWhileIdle` to fire alarms precisely even when the device is in low-power idle mode (Doze).
* **Permission Requests**: Prompts for notification permissions dynamically using `permission_handler`.
* **Alarm Badge**: Note cards display an alarm icon if a reminder is set. The editor allows changing or removing reminders via an `InputChip`.

---

## 8. Advanced Export & Sharing Framework
Export notes to share with friends, colleagues, or print them.
* **File Formats**: Export notes as PDF Documents (`.pdf`), HTML Webpages (`.html`), or Markdown Files (`.md`).
* **Curated Layout Templates**:
  1. *Minimalist Modern*: Sleek sans-serif typography, clean container, and subtle blue-grey styling.
  2. *Academic Journal (Serif)*: Centered serif (Times New Roman) headers, formal lines, and justified text.
  3. *Creative Gradient*: Rounded card layout, custom gradient top accent bar, and playful typography.
  4. *Meeting Minutes*: Dark blue banner headers with organized metadata tables (workspace, date, tags).
* **Formatting Adaptations**: Checklist notes automatically convert to interactive checklist bullet points in HTML, Markdown, and custom checkbox boxes in PDF.
* **Sharing Integrations**: Seamlessly share the exported files to external applications via the native system share sheet.

---

## 9. Android Home Screen Widgets & Deep Linking
Sync notes to your home screen for quick capture.
* **Pinned Note Counter**: Gravity Notes syncs with a home screen widget (`QuickCaptureWidget`) to display the current number of pinned notes in real-time.
* **Quick Capture Deep Linking**: 
  * Clicking the Home Widget sends a custom deep link URI to the app (e.g., `gravitynotes://capture?type=text` or `gravitynotes://capture?type=checklist`).
  * Gravity Notes handles these deep links to instantly open a new note editor pre-configured for either text or checklists.

---

## 10. Database Architecture & Migrations
Local storage is managed by a structured SQLite database.
* **Single Source of Truth**: The app uses `sqflite` for all data operations.
* **Schema Upgrade Migrations**: Database versioning supports seamless upgrades:
  * **Version 1**: Initial release (basic fields: `id`, `title`, `content`, `isPinned`, `colorValue`, `createdAt`, `updatedAt`).
  * **Version 2**: Introduced note organization (`isFavorite`, `isArchived`, `category`).
  * **Version 3**: Added advanced options (`noteType`, `tags`, `attachments`, `isLocked`, `reminderTime`).
  * **Version 4**: Expanded for productivity (adds `folderId` column, habits columns: `isHabit`, `habitRecurrence`, `habitStreak`, `habitLastCompleted`, and creates `folders` table).

### Database Schema Definition:
```sql
CREATE TABLE notes(
  id TEXT PRIMARY KEY,
  title TEXT,
  content TEXT,
  isPinned INTEGER,
  isFavorite INTEGER DEFAULT 0,
  isArchived INTEGER DEFAULT 0,
  category TEXT DEFAULT "Uncategorized",
  noteType TEXT DEFAULT "text",
  tags TEXT,                     -- Stringified JSON array of tags
  attachments TEXT,              -- Stringified JSON array of attachment metadata
  isLocked INTEGER DEFAULT 0,
  reminderTime TEXT,
  createdAt TEXT,
  updatedAt TEXT,
  colorValue INTEGER,
  folderId TEXT,
  isHabit INTEGER DEFAULT 0,
  habitRecurrence TEXT,          -- 'daily', 'weekly', 'none'
  habitStreak INTEGER DEFAULT 0,
  habitLastCompleted TEXT
);

CREATE TABLE folders(
  id TEXT PRIMARY KEY,
  name TEXT,
  parentId TEXT,                 -- Self-referencing link for nested folders
  createdAt TEXT
);
```
