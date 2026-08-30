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
