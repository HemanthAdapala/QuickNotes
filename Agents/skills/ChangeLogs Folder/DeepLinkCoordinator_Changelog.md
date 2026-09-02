# DeepLinkCoordinator Changelog

## 2026-08-28 — Initial Implementation (Phase W2)

### Changes
- Implemented `DeepLinkCoordinator` singleton service in `lib/services/deep_link_coordinator.dart`.
- Defined strongly-typed `DeepLinkAction` model and `DeepLinkActionType` enum (`openHome`, `newNote`, `newChecklist`, `openTasks`).
- Built strict whitelist URI parser (`DeepLinkAction.parse`) rejecting non-quicknotes schemes and arbitrary external paths.
- Added support for cold launch capture (`HomeWidget.initiallyLaunchedFromHomeWidget`) with pending action memory buffering.
- Added support for warm launch stream listener (`HomeWidget.widgetClicked`).
- Built security & readiness gate (`markNavigationReady` / `markNavigationNotReady`) to prevent deep link execution while app is booting or behind PasscodeLock.
- Initialized coordinator in `lib/main.dart`.
- Created comprehensive unit tests in `test/services/deep_link_coordinator_test.dart`.

## 2026-08-30 — Phase W8: Deep-Link Lifecycle Integration & Exact Note Resolution

### Changes
- **Authoritative Exact Note Resolution:**
  - Refactored `DeepLinkCoordinator.executeAction` for `DeepLinkActionType.openNote` to resolve the exact note via `notesProvider.allActiveNotes` (unfiltered in-memory active collection) or direct asynchronous SQLite repository lookup `notesProvider.getNoteById(noteId)`.
  - Fully decoupled deep link resolution from active UI folder, category, tag, or page-cache filters.
- **Asynchronous Execution & Strict Security Validation:**
  - Made `executeAction` and `markNavigationReady` asynchronous (`Future<void>`).
  - Enforced strict note security filter: rejects navigation if `isDeleted == true`, `isArchived == true`, or `isLocked == true`, safely redirecting to `HomeScreen()`.
- **Application Lifecycle & Authentication Synchronization:**
  - In `HomeScreenState.initState()`, registered warm-launch deep-link action dispatcher callback `onActionDispatched` to execute incoming actions immediately when the app is running.
  - In `HomeScreenState.initState()` post-frame callback, synchronized folder/note loading with `DeepLinkCoordinator.instance.markNavigationReady(context: context)` to release buffered cold-launch actions after authentication and database initialization complete.
  - Preserved PasscodeLock integrity: deep links arriving while behind passcode lock remain buffered until the user successfully authenticates and transitions to `HomeScreen`.
- **Android Manifest Intent Filter Enhancement:**
  - Added `<action android:name="es.antonborri.home_widget.action.LAUNCH" />` to `MainActivity` intent filter in `android/app/src/main/AndroidManifest.xml` to ensure clean cold and warm launch resolution across all Android launchers and ADB intents.
- **Verification & Testing:**
  - Updated `test/services/deep_link_coordinator_test.dart` covering 11 comprehensive lifecycle and security tests.
  - All 45+ unit tests passing (100% green).
  - Clean static analysis (`flutter analyze` = 0 issues).
  - Verified on physical Samsung Galaxy S23 Ultra (`SM-S918B`) for both cold-launch and warm-launch widget navigation directly into `NoteEditorScreen`.

## 2026-08-30 — Phase T6: Native Task Widget Interaction & Safe Task Deep Linking

### Version
v1.2.0

### Author
Antigravity

### Type
- Feature
- Architecture
- Navigation
- Security

### Summary
Implemented safe, unidirectional task deep linking from native Android Task Home Screen Widgets (`SingleTaskWidget`, `SingleTaskLongWidget`, and `MultiTaskWidget`) into the existing Flutter Quick Notes task UI. The native Android widgets remain viewports without task-mutation logic; the Flutter application remains the sole authority for task resolution, lifecycle validation, and mutation.

### Detailed Changes
- **Task Deep Link Action Parsing:**
  - Added `openTask` to `DeepLinkActionType` enum in `lib/services/deep_link_coordinator.dart`.
  - Extended `DeepLinkAction.parse(Uri? uri)` to parse `quicknotes://task/<taskId>` (host: `task` with exact 1-segment task UUID).
  - Maintained strict distinction between `quicknotes://tasks` (overview / `openTasks`) and `quicknotes://task/<taskId>` (editor / `openTask`).
  - Whitelist validation safely rejects malformed URIs, empty task IDs, multi-segment subpaths, or unsupported URI schemes.
- **Exact Task Resolution & Security/Lifecycle Filtering:**
  - In `DeepLinkCoordinator.executeAction`, resolved authoritative task by UUID via `Provider.of<TasksProvider>(context, listen: false).loadTasks()`.
  - Enforced strict lifecycle and security filtering: tasks marked as deleted (`isDeleted == true`) or archived (`status == TaskStatus.archived`) are rejected from deep linking and redirect gracefully to `HomeScreen()`. Active pending, waiting, and completed tasks are eligible.
  - Pushes `TaskEditorScreen(initialDate: targetTask.dueDate, taskToEdit: targetTask)` using existing navigator.
  - Zero accidental mutation: tapping a task card opens the editor without toggling completion status.
- **Application Boot & Lifecycle Readiness:**
  - Synchronized `HomeScreen` lifecycle: in `initState()` post-frame callback, ensured `await tasksProvider.loadTasks()` executes prior to `DeepLinkCoordinator.instance.markNavigationReady(context: context)`.
  - Cold-launch intents arriving while app is booting or behind passcode lock buffer in memory and release only when navigation is verified ready.
  - Warm-launch intents dispatch immediately via `onActionDispatched` callback.
- **Multi-Instance & Multi-Card Isolation:**
  - Each task card on `MultiTaskWidget` generates an independent PendingIntent with `quicknotes://task/<taskId>`.
  - Empty card, Add Task card, and fallback containers attach safe generic launch intents without deep-linking into specific tasks.
- **Automated Testing Suite:**
  - Added 8 comprehensive unit tests (TEST 12 to TEST 19) in `test/services/deep_link_coordinator_test.dart` covering URI parsing, malformed rejection, plural vs singular route isolation, cold-launch buffering, warm-launch dispatch, multi-task card isolation, security filters, and repeated non-stale deep links.
  - 47/47 tests passing (100% green).
  - Clean static analysis (`flutter analyze` = 0 issues).
- **Physical Device Verification:**
  - Verified on Samsung Galaxy S23 Ultra (`SM-S918B`, Android 16 / One UI 8).
  - Tested cold-launch via ADB intent, warm-launch via ADB intent, MultiTaskWidget card tap, and SingleTaskWidget tap.

### Final Result
Safe, reliable, and secure deep linking from all native Android task widgets into the authoritative Flutter `TaskEditorScreen`.

## 2026-08-31 — Phase T10: Task Creation Deep Linking & Multi-Widget Interaction Completion

### Version
v1.3.0

### Author
Antigravity

### Type
- Feature
- Navigation
- Hardening

### Summary
Completed the remaining widget interaction routes by implementing dedicated `quicknotes://task/new` (and alias `quicknotes://tasks/new`) task creation deep linking into `TaskEditorScreen()` (creation mode), wiring the Multi-Task widget `+ Add Task` card, and routing the QuickCapture widget tasks stat pill (`@id/widget_tasks_count` / `@id/widget_tasks_pill`) directly to `quicknotes://tasks` (Tasks tab).

### Detailed Changes
- **New Task Deep Link Parsing (`quicknotes://task/new`):**
  - Added `newTask` to `DeepLinkActionType` enum in `lib/services/deep_link_coordinator.dart`.
  - Updated `DeepLinkAction.parse` to cleanly differentiate `quicknotes://task/new` from `quicknotes://task/<taskId>`, ensuring literal `"new"` is never treated as a task UUID.
  - Added alias support for `quicknotes://tasks/new`.
  - Added double-slash guard rejecting malformed paths like `quicknotes://task//new`.
- **New Task Execution:**
  - In `DeepLinkCoordinator.executeAction`, handled `DeepLinkActionType.newTask` by pushing `TaskEditorScreen()` (with `taskToEdit: null`) to open pristine blank task creation mode without touching SQLite or creating premature entities.
  - Updated `DeepLinkActionType.openTasks` to route to `HomeScreen(initialShowTasks: true)` to highlight the Tasks tab directly.
- **Automated Tests:**
  - Added 9 unit tests (TEST A to TEST I) in `test/services/deep_link_coordinator_test.dart` verifying canonical parsing, UUID differentiation, non-regression, malformed rejection, warm-launch dispatch, cold-launch buffering, action clearing, alias parsing, and sequential deep link state hygiene.
  - 81/81 focused tests passing across all 5 widget test suites.
- **Physical Device Verification:**
  - Verified on Samsung Galaxy S23 Ultra (`SM-S918B` / API 36 / One UI 8):
    - Cold-launch & warm-launch `quicknotes://task/new` ➔ opens `TaskEditorScreen` in creation mode.
    - Cold-launch & warm-launch `quicknotes://tasks` ➔ opens `HomeScreen` in Tasks tab.
    - Existing task deep link `quicknotes://task/<id>` ➔ opens `TaskEditorScreen` with preloaded task.
    - Sequential launches maintain clean non-stale state.

### Final Result
Unidirectional navigation loop between native widgets and Flutter task creation/overview is 100% complete and verified.

## 2026-08-31 — Phase T14: Task Deep-Link Routing Migration (Widget Task Tap → HomeScreen Focused Task Overlay)

### Version
v1.4.0

### Author
Antigravity

### Type
- Migration
- Navigation
- Architecture

### Summary
Migrated task deep-link routing (`quicknotes://task/<taskId>`) from automatically opening `TaskEditorScreen` to navigating directly to `HomeScreen(initialShowTasks: true, focusedTaskId: targetTask.id)`, mounting the Focused Task Overlay with the mature "Drag to mark done" slider.

### Detailed Changes
- **Routing Migration in DeepLinkCoordinator:**
  - Updated `DeepLinkCoordinator.executeAction` for `DeepLinkActionType.openTask`:
    - Previous destination: `Navigator.push(TaskEditorScreen(taskToEdit: targetTask))`
    - New destination: `Navigator.pushAndRemoveUntil(HomeScreen(initialShowTasks: true, focusedTaskId: targetTask.id))`
    - Fallback on deleted, archived, or unknown task: `HomeScreen(initialShowTasks: true)` with `focusedTaskId: null`.
- **Architectural Invariants Preserved:**
  - Authoritative task resolution through `TasksProvider` / `TaskEngine` without native task reconstruction.
  - Zero changes to native Android Kotlin or XML layouts.
  - `quicknotes://task/new` and `quicknotes://tasks/new` continue to route to `TaskEditorScreen()` in creation mode.
  - `quicknotes://tasks` continues to route to `HomeScreen(initialShowTasks: true)`.
  - Note deep links (`quicknotes://note/<id>`, `quicknotes://note/new`, `quicknotes://checklist/new`, `quicknotes://home`) remain 100% untouched.
  - Zero task mutation occurs on widget tap.
- **Automated Tests:**
  - Added 11 tests (TEST T14-1 through TEST T14-11) in `test/services/deep_link_coordinator_test.dart` covering valid active tasks, completed tasks, deleted/archived fallback, unknown task fallback, creation regression, tasks overview regression, note deep link regression, sequential task isolation, and mutation immutability.
  - 97 / 97 tests passing across all 6 test suites (100% green).
- **Verification:**
  - Static analysis: 0 issues (`flutter analyze` clean).
  - APK build: `flutter build apk --debug` succeeded in 32.3s.

### Final Result
Phase T14 completed and verified green. Task widget tap navigates seamlessly to the Focused Task Overlay.

---

## 2026-09-02 — Phase T15: Focused Task Overlay Viewport Centering, Launcher Intent Sanitization & Dismiss UX

### Version
v1.5.0

### Author
Antigravity

### Type
- UI / UX Enhancement
- Bug Fix
- Architecture

### Summary
Enhanced the Focused Task Overlay with consistent viewport vertical centering, relocated the dismiss badge above the card for effortless thumb reachability, and implemented Android launcher intent clearing (`clearInitialIntent`) to prevent unwanted overlay re-popping when returning to the app from the home launcher.

### Detailed Changes
- **Viewport Centering & Relocated Dismiss Badge (`home_screen.dart`):**
  - Converted the Focused Task Overlay position from scroll-dependent coordinate matching to fixed viewport vertical centering (`MainAxisAlignment.center`).
  - Positioned the dismiss helper badge (`"Tap anywhere or swipe to close"`) floating above the card instead of below, maintaining optimal thumb reachability and visual clarity.
- **Launcher Intent Sanitization (`MainActivity.kt` & `DeepLinkCoordinator.dart`):**
  - Added MethodChannel `com.quicknotes.app/deep_link_clear` and native intent sanitization in `MainActivity.kt`.
  - When the app is opened normally via the home launcher, lingering widget deep-link URLs are cleared so the app opens directly to the normal note/task lists without mounting a stale overlay.
- **Automated Tests:**
  - Expanded `test/views/home_screen_focused_task_overlay_test.dart` and `test/services/deep_link_coordinator_test.dart` with full coverage for overlay centering, dismiss lifecycle, and intent replay prevention.
  - 143/143 tests passing.

### Architecture Impact
- **Navigation**: Deterministic overlay mounting and clean lifecycle transitions between home launcher and home screen.
