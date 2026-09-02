# AndroidWidget Changelog

## 2026-08-29 — Android Native Widget Implementation (Phase W3)

### Changes
- Refactored `QuickCaptureWidget` in `android/app/src/main/kotlin/com/quicknotes/app/QuickCaptureWidget.kt` to extend `es.antonborri.home_widget.HomeWidgetProvider`.
- Integrated W2 sanitized snapshot consumption from `SharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)` under key `quicknotes_widget_snapshot`.
- Implemented robust JSON parsing with fallback to deterministic local dates and signed-out state display when `has_active_session` is false.
- Added deep-link `<intent-filter>` in `android/app/src/main/AndroidManifest.xml` for `quicknotes://` scheme on `MainActivity`.
- Wired `HomeWidgetLaunchIntent.getActivity` for all 3 click targets:
  - Root card ➔ `quicknotes://home`
  - New Note button ➔ `quicknotes://note/new`
  - New Checklist button ➔ `quicknotes://checklist/new`
- Redesigned `widget_layout.xml` for standard medium launcher footprint (targetCellWidth: 3, targetCellHeight: 2).
- Added `widget_button_background.xml` and `widget_pill_background.xml` shape drawables.
- Verified 100% Android Gradle debug APK build success (`assembleDebug`).

## 2026-08-29 — Android Widget RemoteViews Compatibility Fix (Phase W5A)

### Changes
- Investigated physical device layout inflation failure on Samsung Galaxy S23 Ultra launcher (`"Couldn't add widget."`).
- Resolved `RemoteViews` class whitelist violation by removing generic `<View>` horizontal spacers and replacing the vertical spacer with a whitelist-compliant `<FrameLayout>` container.
- Applied `android:layout_marginStart="8dp"` on sibling pills and action buttons for native spacing.
- Normalized compound padding attributes (`paddingHorizontal`, `paddingVertical`) to explicit `paddingLeft`, `paddingRight`, `paddingTop`, `paddingBottom` across all stat pills and containers.
- Removed `android:letterSpacing` from `@id/widget_app_label` to eliminate non-standard RemoteViews attribute parsing hazards.
- Confirmed zero changes to widget architecture, Kotlin logic, snapshot schema, view IDs, and click targets.

## 2026-08-29 — Configurable Single Note Widget Implementation (SingleNoteWidget & NoteWidgetConfigureActivity)

### Changes
- Implemented `SingleNoteWidget` (`es.antonborri.home_widget.HomeWidgetProvider`) in `android/app/src/main/kotlin/com/quicknotes/app/SingleNoteWidget.kt` representing a single user-selected Quick Notes note on the Android Home Screen.
- Implemented `NoteWidgetConfigureActivity` in `android/app/src/main/kotlin/com/quicknotes/app/NoteWidgetConfigureActivity.kt` providing a native Quick Notes-styled note selection screen (dark theme `#0F1117`, real-time search filtering, note title, preview snippet, and update date).
- Enforced per-instance configuration mapping (`note_widget_id_<appWidgetId>` and `note_widget_data_<appWidgetId>`) to guarantee multi-widget instance isolation.
- Created `single_note_widget_layout.xml` matching Figma visual authority:
  - Yellow top header (`#FFCC00`) with localized Date and Time.
  - Flush white inner card (`#FFFFFF`) with compound corner radii (`20dp` top / `24dp` bottom).
  - Bold note title and up to 5 clean checklist/numbered/text preview rows.
  - Safe fallback state for unconfigured, deleted, or locked notes.
- Declared minimum dimensions `150dp x 157dp` (`2x2` target cells) in `single_note_widget_info.xml`.
- Extended `WidgetDataAdapter.sync()` to serialize sanitized `quicknotes_notes_catalog` and `quicknotes_notes_map` with strict exclusion of locked (`isLocked == true`), deleted (`isDeleted == true`), and archived (`isArchived == true`) notes.
- Extended `DeepLinkCoordinator` to support `DeepLinkActionType.openNote` for `quicknotes://note/<noteId>`, routing safely into `NoteEditorScreen(note: note)` behind lock-state gating.
- Verified 32/32 unit tests passing, clean debug APK build (`assembleDebug`), and streamed installation to physical Samsung Galaxy S23 Ultra (SM-S918B).

## 2026-08-30 — Phase W6: Single-Note Widget Semantic Content Rendering & Responsive Sizing

### Changes
- **Canonical Semantic Content Rendering:**
  - Implemented `NoteWidgetLine` model (`type`, `text`, `marker`, `checked`) in `lib/models/single_note_snapshot.dart` supporting:
    - **Normal Text:** Plain paragraphs with natural visual wrapping and explicit newline preservation (`marker: ""`).
    - **Bulleted Lists:** Preserves bullet marker (`marker: "•"`).
    - **Numbered Lists:** Preserves numbered sequence (`marker: "1."`, `"2."`, etc.).
    - **Checklists:** Preserves unchecked (`marker: "☐"`) and checked (`marker: "☑"`) states.
    - **Mixed Content:** Preserves arbitrary sequences of paragraphs, bullets, numbers, and checklists in their exact document order.
- **Natural Android TextView Wrapping:**
  - Refactored `single_note_widget_layout.xml` to use 10 semantic `TextView` rows (`note_line_1` to `note_line_10`) configured with `layout_width="match_parent"`, `singleLine="false"`, and `ellipsize="end"`.
  - Android's native text measurement engine naturally wraps continuous text based on measured widget width without inserting artificial line breaks.
- **Responsive Geometry & Progressive Expansion:**
  - Configured `single_note_widget_info.xml` with approved dimensions: `minWidth="150dp"`, `minHeight="157dp"`, `targetCellWidth="2"`, `targetCellHeight="2"`, `minResizeWidth="110dp"`, `minResizeHeight="110dp"`.
  - Widget acts as a viewport into the note: enlarging width reduces wrapping lines; enlarging height reveals additional semantic lines progressively without distortion.
- **Card Corner Radii (24dp):**
  - Unified corner radii to **24dp** on both outer yellow header (`widget_yellow_card_bg.xml`) and inner white card (`widget_white_card_body.xml`).
- **Privacy & Security Integrity:**
  - Maintained strict exclusion of locked (`isLocked == true`), deleted (`isDeleted == true`), and archived (`isArchived == true`) notes.
  - Deep linking strictly routes via `quicknotes://note/<noteId>` through `DeepLinkCoordinator` with authentication/lock gating.
- **Testing & Verification:**
  - Added test suite in `test/services/single_note_snapshot_test.dart` verifying all semantic types, continuous paragraphs, and mixed content notes.
  - 33/33 tests passing (100% green).
  - Clean static analysis (`flutter analyze` = 0 issues).
  - Debug APK built and installed via ADB to Samsung Galaxy S23 Ultra (`SM-S918B`).

## 2026-08-30 — Phase W7: Single Note Widget Naming & Tap-to-Open Note Editor Integration

### Changes
- **User-Facing Launcher Widget Naming:**
  - Updated `android/app/src/main/AndroidManifest.xml` receiver with `android:label="Single Note"`, ensuring the widget appears distinctly in the Android launcher / widget picker under Quick Notes as **"Single Note"**.
  - Retained internal provider identifier `SingleNoteWidget` and configure activity `NoteWidgetConfigureActivity`.
- **Tap-to-Open Direct Note Navigation:**
  - Configured click pending intent on `SingleNoteWidget` root (`widget_single_note_root`) targeting `quicknotes://note/<selectedNoteId>`.
  - Validated URI routing in `DeepLinkCoordinator` (`DeepLinkActionType.openNote` with `noteId`), rejecting malformed routes or arbitrary URI patterns.
- **Strict Security & Privacy Gating:**
  - Enforced `_isNavigationReady` authentication/passcode gate: cold-launch and background tap actions are buffered until the user completes passcode/biometric authentication.
  - Security resolution check: if the configured note has been deleted (`isDeleted == true`), archived (`isArchived == true`), or locked (`isLocked == true`), navigation safely redirects to `HomeScreen()` without opening or exposing private content.
- **Multi-Instance Isolation:**
  - Confirmed independent note ID routing per widget instance (`note_widget_id_<appWidgetId>`), allowing multiple Single Note widgets on the Home Screen to open their respective notes.
- **Testing & Verification:**
  - Added comprehensive unit tests in `test/services/deep_link_coordinator_test.dart` covering URI parsing, whitelist validation, active vs locked/deleted note resolution, cold/warm launch buffering, and multi-instance independence.
  - 28/28 test assertions passing.
  - Clean debug APK build (`assembleDebug`) and streamed ADB deployment to Samsung Galaxy S23 Ultra (`SM-S918B`).

## 2026-08-30 — Phase W8: Deep-Link Lifecycle Integration & Exact Note Resolution

### Changes
- **Authoritative Exact Note Resolution:**
  - Refactored `DeepLinkCoordinator.executeAction` for `DeepLinkActionType.openNote` to resolve the exact note via `notesProvider.allActiveNotes` or direct asynchronous SQLite repository lookup `notesProvider.getNoteById(noteId)`.
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
- **Testing & Verification:**
  - Updated `test/services/deep_link_coordinator_test.dart` covering 11 comprehensive lifecycle and security tests.
  - All 45+ unit tests passing (100% green).
  - Clean static analysis (`flutter analyze` = 0 issues).
  - Verified on physical Samsung Galaxy S23 Ultra (`SM-S918B`) for both cold-launch and warm-launch widget navigation directly into `NoteEditorScreen`.

## 2026-08-30 — Phase T2: Single Task Short Widget (Pending + Completed States)

### Changes
- **SingleTaskWidget Implementation:**
  - Implemented `SingleTaskWidget` (`es.antonborri.home_widget.HomeWidgetProvider`) in `android/app/src/main/kotlin/com/quicknotes/app/SingleTaskWidget.kt` representing a single user-selected task on the Android Home Screen (Short 2x2).
  - Dual visual state support: Renders **Pending** (clock icon + "Pending") vs **Completed** (blue checkmark circle icon + "Completed") states dynamically from `SingleTaskSnapshot`.
  - Multi-instance isolation: Reads task ID mapping from `task_widget_id_<appWidgetId>` with fallback to `quicknotes_tasks_map` or instance cache.
  - Resilient error handling: Displays clean fallback container ("Tap to choose a task" / "Task unavailable") if snapshot is missing or task is deleted.
- **RemoteViews Safe Layout (`single_task_widget_layout.xml`):**
  - Outer container: Blue header background (`widget_task_blue_bg.xml`, `#0088FF`, `24dp` corner radius) with localized Date and Time.
  - Inner card body: Flush white card (`widget_white_card_body.xml`, `#FFFFFF`, `24dp` corner radius).
  - Badges: Priority pill (`High` red, `Medium` yellow/orange, `Low` blue) and Recurrence pill (`Daily`, `Everyday`, `Weekly`, `Monthly`, `Yearly`), hidden when absent.
  - Title: Bold `15sp` `#222222` with natural Android TextView wrapping and max 3 lines.
  - Strict RemoteViews compliance: Only whitelist-compliant views (`LinearLayout`, `FrameLayout`, `TextView`, `ImageView`), explicit padding attributes, zero generic `<View>` spacers.
- **AppWidgetProviderInfo Metadata (`single_task_widget_info.xml`):**
  - Minimum geometry: `minWidth="150dp"`, `minHeight="157dp"`, `targetCellWidth="2"`, `targetCellHeight="2"`, `resizeMode="horizontal|vertical"`.
- **Launcher Registration:**
  - Registered `SingleTaskWidget` receiver with `android:label="Single Task"` in `android/app/src/main/AndroidManifest.xml`.

## 2026-08-30 — Phase T3: Single Task Long Widget (Horizontal 4x1 Footprint)

### Changes
- **SingleTaskLongWidget Implementation:**
  - Implemented `SingleTaskLongWidget` (`es.antonborri.home_widget.HomeWidgetProvider`) in `android/app/src/main/kotlin/com/quicknotes/app/SingleTaskLongWidget.kt` representing a single user-selected task in a horizontal layout on the Android Home Screen (Long 4x1).
  - Dual visual state support: Renders **Pending** (clock icon + "Pending") vs **Completed** (green checkmark circle icon + "Completed") states dynamically from `SingleTaskSnapshot`.
  - Multi-instance isolation: Reads task ID mapping from `task_widget_id_<appWidgetId>` with fallback to `quicknotes_tasks_map` or instance cache.
  - Resilient error handling: Displays clean fallback container ("Tap to choose a task" / "Task unavailable") if snapshot is missing or task is deleted.
- **RemoteViews Safe Layout (`single_task_long_widget_layout.xml`):**
  - Outer container: Blue header background (`widget_task_blue_bg.xml`, `#0088FF`, `24dp` top corner radius) with localized Date on the left and Time on the right.
  - Inner card body: Flush white card (`widget_white_card_body.xml`, `#FFFFFF`, `24dp` corner radius).
  - Badges column (Left): Priority badge (`High` red, `Medium` orange, `Low` blue) and Recurrence badge (`Daily`, `Weekly`, `Monthly`, `Custom`), stacked vertically and hidden when absent.
  - Title (Center): Bold `15sp` `#111827` Inter typography with natural Android TextView wrapping (`maxLines="2"`, `singleLine="false"`, `ellipsize="end"`).
  - Status pill (Right): Status badge container dynamically switching between Pending (`#0088FF` background with clock icon) and Completed (`#12B76A` / `#D1FADF` background with checkmark icon).
  - Strict RemoteViews compliance: Only whitelist-compliant views (`LinearLayout`, `FrameLayout`, `TextView`, `ImageView`), explicit padding attributes (`paddingLeft`, `paddingTop`, `paddingRight`, `paddingBottom`), zero generic `<View>` spacers.
- **AppWidgetProviderInfo Metadata (`single_task_long_widget_info.xml`):**
  - Minimum geometry: `minWidth="270dp"`, `minHeight="100dp"`, `targetCellWidth="4"`, `targetCellHeight="1"`, `resizeMode="horizontal|vertical"`.
- **Launcher Registration:**
  - Registered `SingleTaskLongWidget` receiver with `android:label="Single Task — Long"` in `android/app/src/main/AndroidManifest.xml`.
- **Physical Device Verification:**
  - Verified on Samsung Galaxy S23 Ultra (`SM-S918B`, Android 16 / One UI 8).
  - Confirmed 4x1 launcher placement, dynamic Pending/Completed state updates, and multi-line title wrapping.

## 2026-08-30 — Phase T4: Multi-Task Long Widget (Responsive Stack & Overview)

### Changes
- **MultiTaskWidget Implementation:**
  - Implemented `MultiTaskWidget` (`es.antonborri.home_widget.HomeWidgetProvider`) in `android/app/src/main/kotlin/com/quicknotes/app/MultiTaskWidget.kt` representing active tasks in a responsive vertical stack (Launcher label: `"Tasks"`).
  - Responsive Viewport Expansion: Listens to `onAppWidgetOptionsChanged` and dynamically calculates visible task capacity based on `OPTION_APPWIDGET_MIN_HEIGHT` (Default 4x3 -> 2 tasks + Add Task; 4x4 -> 3 tasks + Add Task; 4x5+ -> 4 tasks + Add Task) without scaling typography or distorting card dimensions.
  - Multi-Task Data Binding: Consumes `quicknotes_tasks_catalog` and `quicknotes_tasks_map` from `HomeWidgetPreferences` in canonical TaskEngine order, rendering full dates, times, priority badges, recurrence pills, and wrapped titles.
  - Dual Visual States: Renders Pending (clock icon + "Pending") vs Completed (blue checkmark + "Completed" + strikethrough title) cleanly from snapshot models.
  - Empty State Handling: Displays an "All Caught Up! You have no pending tasks." card alongside the Add Task button when zero tasks exist.
- **RemoteViews Safe Layout (`multi_task_widget_layout.xml`):**
  - Vertically stacked task cards (`multi_task_card_1` through `multi_task_card_4`), each with a top blue header strip (`widget_task_blue_bg.xml`, `#0088FF`) and white card body (`widget_white_card_body.xml`, `#FFFFFF`).
  - Add Task Card (`multi_task_add_card`): Flush white card with centered circular plus vector drawable (`ic_task_add_circle.xml`).
  - Strict RemoteViews compliance: Only whitelist-compliant views (`LinearLayout`, `FrameLayout`, `TextView`, `ImageView`), explicit padding attributes (`paddingLeft`, `paddingTop`, `paddingRight`, `paddingBottom`), zero generic `<View>` spacers.
- **AppWidgetProviderInfo Metadata (`multi_task_widget_info.xml`):**
  - Geometry: `minWidth="270dp"`, `minHeight="200dp"`, `targetCellWidth="4"`, `targetCellHeight="3"`, `resizeMode="horizontal|vertical"`.
- **Launcher Registration:**
  - Registered `MultiTaskWidget` receiver with `android:label="Tasks"` in `android/app/src/main/AndroidManifest.xml`.
- **Physical Device Verification:**
  - Verified on Samsung Galaxy S23 Ultra (`SM-S918B`, Android 16 / One UI 8).
  - Confirmed 4x3 default footprint placement, "All Caught Up!" empty state, and multi-card stacked display with active tasks.

## 2026-08-30 — Phase T6: Native Task Widget Interaction & Safe Task Deep Linking

### Version
v1.3.0

### Author
Antigravity

### Type
- Feature
- Architecture
- Navigation
- Security

### Summary
Attached explicit `quicknotes://task/<taskId>` pending intents to native Android task widgets (`SingleTaskWidget`, `SingleTaskLongWidget`, and `MultiTaskWidget`), enabling seamless tap-to-open navigation into the Flutter `TaskEditorScreen` while preserving strict RemoteViews safety and keeping all task mutation authority within Flutter.

### Detailed Changes
- **SingleTaskWidget PendingIntent Integration:**
  - In `SingleTaskWidget.kt`, attached `HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("quicknotes://task/$taskId"))` to `@id/widget_single_task_root` when a valid task ID exists.
  - Attached default safe launch intent without deep link in fallback/unconfigured state.
- **SingleTaskLongWidget PendingIntent Integration:**
  - In `SingleTaskLongWidget.kt`, attached `HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("quicknotes://task/$taskId"))` to `@id/widget_single_task_long_root` when a valid task ID exists.
  - Attached default safe launch intent without deep link in fallback/unconfigured state.
- **MultiTaskWidget Per-Card PendingIntent Isolation:**
  - In `MultiTaskWidget.kt`, attached independent per-card `quicknotes://task/$taskId` PendingIntents to `@id/multi_task_card_1`, `@id/multi_task_card_2`, `@id/multi_task_card_3`, and `@id/multi_task_card_4`.
  - Attached default safe launcher intent (without URI) to `@id/multi_task_add_card`, `@id/multi_task_empty_card`, and `@id/widget_multi_task_root` to ensure the Add Task action does not inherit a task deep link.
- **Physical Device Verification:**
  - Verified on Samsung Galaxy S23 Ultra (`SM-S918B`, Android 16 / One UI 8).
  - Confirmed tapping Card 1 opens `TaskEditorScreen` with exact task details (title, due date, time, priority, recurrence, reminder mode).
  - Confirmed tapping Card 2 opens `TaskEditorScreen` for Card 2 task independently.
  - Confirmed cold-launch from dead process reliably opens the requested task editor.
  - Confirmed warm-launch reliably delivers to top-most activity.
  - Confirmed tapping Add Task button opens `HomeScreen` without opening an editor.

## 2026-08-30 — Phase T7: Native Task Widget Configuration & Per-Instance Task Selection

### Version
v1.4.0

### Author
Antigravity

### Type
- Feature
- UI/UX
- Architecture
- Android AppWidget

### Summary
Implemented native Android Task Widget configuration flow (`TaskWidgetConfigureActivity`) for `SingleTaskWidget` and `SingleTaskLongWidget`. Enables users to select which task from the authoritative `quicknotes_tasks_catalog` is displayed on each home screen widget instance with per-instance isolation, live search filtering, preselection of existing mappings, and instant RemoteViews update upon confirmation.

### Detailed Changes
- **TaskWidgetConfigureActivity Implementation (`TaskWidgetConfigureActivity.kt`):**
  - Consumes `quicknotes_tasks_catalog` and `quicknotes_tasks_map` from `HomeWidgetPreferences` (`Context.MODE_PRIVATE`) with zero direct SQLite access.
  - Manages single-choice selection with active card highlighting and custom radio button indicator.
  - Provides real-time instant search filtering across title, due date, priority, and recurrence label.
  - Handles initial `RESULT_CANCELED` contract; only commits selected task ID (`task_widget_id_<appWidgetId>`) and cached payload (`task_widget_data_<appWidgetId>`) upon tapping `[ Select ]`.
  - Automatically preselects existing task mappings when re-configuring an active widget instance.
  - Safely falls back to empty state ("No tasks available / Create a task in Quick Notes first") with disabled confirmation button when catalog is empty.
  - Immediately updates target widget instance via `AppWidgetManager.getInstance(this)` before returning `RESULT_OK` with `EXTRA_APPWIDGET_ID`.
- **Native Layouts & Styling:**
  - `activity_task_widget_configure.xml`: Clean white theme (`#FFFFFF`), bold header typography, Quick Notes Blue accent (`#0088FF`), rounded search bar, single-choice ListView, and full-width `[ Select ]` button.
  - `item_task_select.xml`: Rounded task card (`task_configure_card_bg.xml` with `#F0F7FF` activated tint), custom radio indicator (`task_configure_radio_checked.xml`), title, date/time, priority badge, and recurrence pill.
- **Provider Metadata & Manifest Registration:**
  - Added `android:configure="com.quicknotes.app.TaskWidgetConfigureActivity"` to `single_task_widget_info.xml` and `single_task_long_widget_info.xml`.
  - Registered `TaskWidgetConfigureActivity` in `android/app/src/main/AndroidManifest.xml` with `android:exported="true"`, `APPWIDGET_CONFIGURE` intent-filter, and `@android:style/Theme.DeviceDefault.Light.NoActionBar`.
- **Per-Instance Resolution Alignment in Widget Providers:**
  - Updated `SingleTaskWidget.kt` and `SingleTaskLongWidget.kt` to resolve task by `task_widget_id_<appWidgetId>` with fallback container if unmapped or deleted.
- **Physical Device Verification:**
  - Verified on Samsung Galaxy S23 Ultra (`SM-S918B`, Android 16 / One UI 8).
  - Confirmed initial configuration launch, task list population, live search filtering, item selection highlighting, confirmation persistence, and preselection on re-configuration.

## 2026-08-31 — Phase T8: Native Android Task Widget System — End-to-End Hardening, Lifecycle Synchronization & Regression Verification

### Version
v1.4.1

### Author
Antigravity

### Type
- Hardening
- Reliability
- Lifecycle & Synchronization
- Regression Verification
- Android AppWidget

### Summary
Completed comprehensive architectural audit, end-to-end hardening, lifecycle cleanup, stale-mapping protection, and non-regression verification across the complete Quick Notes native Android Task Widget subsystem (`SingleTaskWidget`, `SingleTaskLongWidget`, `MultiTaskWidget`, `TaskWidgetConfigureActivity`, and `WidgetDataAdapter`).

### Audit Findings & Exact Hardening Fixes
1. **Stale Single-Task Mapping Protection:**
   - **Finding:** If a configured widget was mapped to `task_widget_id_<appWidgetId>`, deleting/archiving the task caused `tasksMapRaw` to omit the task, but subsequent fallback to `task_widget_data_<appWidgetId>` could display stale deleted task content.
   - **Fix:** In `SingleTaskWidget.kt` and `SingleTaskLongWidget.kt`, updated resolution to treat `quicknotes_tasks_map` as authoritative whenever present. If `quicknotes_tasks_map` exists but lacks the configured task ID, the widget strictly resolves to `taskJson = null`, immediately rendering the "Task unavailable" fallback container rather than reviving deleted data.
   - **Parity Fix:** Applied identical authoritative map validation to `SingleNoteWidget.kt` for `quicknotes_notes_map` vs `note_widget_data_<appWidgetId>`.
2. **AppWidget Instance Lifecycle Cleanup (`onDeleted`):**
   - **Finding:** Removing widget instances from the launcher left orphan `task_widget_id_<id>`, `task_widget_data_<id>`, `note_widget_id_<id>`, and `note_widget_data_<id>` keys in `HomeWidgetPreferences`.
   - **Fix:** Implemented `onDeleted(context: Context, appWidgetIds: IntArray)` in `SingleTaskWidget.kt`, `SingleTaskLongWidget.kt`, and `SingleNoteWidget.kt` to actively clean up per-instance keys upon widget removal from launcher.
3. **Configuration Catalog Deduplication:**
   - **Finding:** In `TaskWidgetConfigureActivity.kt`, malformed catalog arrays with duplicate task IDs could render duplicate selectable cards.
   - **Fix:** Added deduplication guard `if (id.isNotEmpty() && allTasks.none { it.id == id })` during catalog loading.
4. **Authoritative Synchronization Verification:**
   - Confirmed `TaskEngine` mutation events (`TaskCreatedEvent`, `TaskUpdatedEvent`, `TaskCompletedEvent`, `TaskDeletedEvent`, `ReminderSnoozedEvent`, `TasksReconciledEvent`) trigger `WidgetDataAdapter.instance.sync(tasks: _engine.tasks)` via `TasksProvider`.
   - Confirmed `WidgetDataAdapter.instance.sync()` broadcasts widget timeline updates across all 5 widget targets (`QuickCaptureWidget`, `SingleNoteWidget`, `SingleTaskWidget`, `SingleTaskLongWidget`, `MultiTaskWidget`).
   - Confirmed `WidgetDataAdapter.instance.clearSnapshot()` purges shared preferences and resets catalogs to `'[]'` on session logout / account deletion.
5. **Deep Link Security & Non-Regression:**
   - Verified `DeepLinkCoordinator` strict validation for `quicknotes://task/<taskId>`: rejects deleted (`isDeleted == true`) and archived (`status == TaskStatus.archived`) tasks, routing safely to `HomeScreen` fallback with zero state mutation.
   - Verified non-regression of all note deep links (`quicknotes://note/<id>`, `quicknotes://note/new`, `quicknotes://checklist/new`, `quicknotes://home`, `quicknotes://tasks`).
6. **RemoteViews Safety & One UI Compliance:**
   - Re-verified all layouts (`single_task_widget_layout.xml`, `single_task_long_widget_layout.xml`, `multi_task_widget_layout.xml`, `single_note_widget_layout.xml`, `widget_layout.xml`) use only standard whitelist views (`LinearLayout`, `FrameLayout`, `TextView`, `ImageView`), explicit padding attributes, and no unsupported properties.

### Automated Tests & Quality Gates
- **Focused Unit & Regression Tests:** 72/72 tests passing across all widget test suites:
  - `test/services/task_widget_snapshot_test.dart` (33 tests including 12 dedicated T8 hardening tests)
  - `test/services/widget_data_adapter_test.dart` (7 tests)
  - `test/services/deep_link_coordinator_test.dart` (19 tests)
  - `test/services/single_note_snapshot_test.dart` (6 tests)
  - `test/services/widget_snapshot_payload_test.dart` (7 tests)
- **Static Analysis:** 0 issues found across all 10 widget subsystem files (`flutter analyze`).
- **Build Verification:** 100% Gradle debug APK build success (`assembleDebug` in 77.7s).
- **Physical Device Verification:** Deployed and verified on Samsung Galaxy S23 Ultra (`SM-S918B`, Android 16 / One UI 8, API 36).

## 2026-08-31 — Phase T10: Task Creation Deep Linking & Multi-Widget Interaction Completion

### Version
v1.5.0

### Author
Antigravity

### Type
- Feature
- Widget Interaction
- Navigation
- Hardening

### Summary
Completed the remaining widget interaction routes across native Android widgets and Flutter navigation:
1. Wired the `+ Add Task` card on `MultiTaskWidget` (`@id/multi_task_add_card`) to launch `quicknotes://task/new`, directly opening the authoritative Flutter `TaskEditorScreen` in task creation mode.
2. Routed the QuickCapture widget tasks stat pill (`@id/widget_tasks_pill` & `@id/widget_tasks_count`) to launch `quicknotes://tasks`, opening `HomeScreen` with the Tasks tab directly active.
3. Expanded `DeepLinkCoordinator` with `DeepLinkActionType.newTask` to safely parse and execute `quicknotes://task/new` and `quicknotes://tasks/new` without premature database or state mutations.

### Detailed Changes
- **Multi-Task Widget Add Task Interaction (`MultiTaskWidget.kt`):**
  - Replaced generic launch intent on `R.id.multi_task_add_card` with `HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("quicknotes://task/new"))`.
  - Maintained safe generic launch intent for root container and empty "All Caught Up" card.
- **QuickCapture Widget Tasks Stat Pill Interaction (`QuickCaptureWidget.kt` & `widget_layout.xml`):**
  - Added `@id/widget_tasks_pill` to the Due Today tasks stat pill container in `widget_layout.xml`.
  - Attached `quicknotes://tasks` PendingIntent to `R.id.widget_tasks_pill` and `R.id.widget_tasks_count` in `QuickCaptureWidget.kt`.
- **Flutter Navigation & Deep Link Execution (`DeepLinkCoordinator.dart` & `HomeScreen.dart`):**
  - Added `newTask` to `DeepLinkActionType` enum.
  - In `DeepLinkAction.parse`, cleanly differentiated `quicknotes://task/new` from task UUIDs (`quicknotes://task/<id>`).
  - Added `initialShowTasks` parameter to `HomeScreen` to toggle `_isNotesActive = false` when deep-linked via `quicknotes://tasks`.
  - In `DeepLinkCoordinator.executeAction`, routed `newTask` to `TaskEditorScreen()` (with `taskToEdit: null`) and `openTasks` to `HomeScreen(initialShowTasks: true)`.
- **Automated Tests:**
  - Added 9 new unit tests in `test/services/deep_link_coordinator_test.dart` (TEST A through TEST I).
  - 81/81 focused tests passing across all 5 widget test suites.
- **Static Analysis & Build:**
  - 0 analyzer issues found (`flutter analyze`).
  - Debug APK built and installed to physical device (`assembleDebug` in 86.6s).
- **Physical Device Verification (Samsung Galaxy S23 Ultra / SM-S918B / API 36 / One UI 8):**
  - Verified cold-launch & warm-launch `quicknotes://task/new` ➔ opens blank `TaskEditorScreen`.
  - Verified cold-launch & warm-launch `quicknotes://tasks` ➔ opens `HomeScreen` with Tasks tab.
  - Verified non-regression of existing task deep links (`quicknotes://task/<id>`).

---

## 2026-09-02 — Phase T16: Widget Visual Redesign, 2x2 Grid Compliance, Uniform Heights & Native Midnight Rollover

### Version
v1.6.0

### Author
Antigravity

### Type
- UI / Visual Redesign
- Bug Fix
- Architecture
- Android Native

### Summary
Redesigned the entire suite of Android Task Widgets (2x2 Short Task, 4x1 Long Task, and 4x3 Multi-Task) to match updated modern design specifications, resolved Android RemoteViews inflation crash on home screens, fixed grid dimension metadata for strict 2x2 display on Samsung One UI, enforced uniform card heights across multi-task cards, and implemented native offline midnight task rollover with exact `AlarmManager` ticks.

### Detailed Changes
- **2x2 Short Task Widget Redesign (`single_task_widget_layout.xml` & `SingleTaskWidget.kt`):**
  - Reordered visual hierarchy inside the white card body to Title-First (`[Title -> Badges -> Centered Status Pill]`).
  - Positioned Task Title at the top in bold 16sp high-contrast typography (`#222222`).
  - Arranged Priority (`High` with red flag) and Recurrence (`Everyday`/`Daily`) chips horizontally below the title.
  - Anchored a stadium status pill at the bottom (`#F2F4F7`, 20dp radius) with `Pending` (history clock icon) vs `Completed` (solid `#0088FF` blue circle with white checkmark).
- **4x1 Long Task Widget Redesign (`single_task_long_widget_layout.xml` & `SingleTaskLongWidget.kt`):**
  - Implemented horizontal split layout with Title (top) and Badges (bottom) in the left column.
  - Placed centered status pill vertically aligned on the right column.
- **4x3 Multi-Task Widget Uniform Height Fix (`multi_task_widget_layout.xml` & `MultiTaskWidget.kt`):**
  - Updated all 4 task card slots to use the new horizontal split card architecture.
  - Eliminated height discrepancies by placing badges in a horizontal row rather than vertically stacked, ensuring every card in the vertical stack maintains an identical, uniform height.
  - Standardized margins and padding across all cards and the bottom Add Task action card.
- **Android RemoteViews Compliance & 2x2 Sizing Fix:**
  - Replaced illegal `<View>` flexible spacers with compliant `<FrameLayout>` across widget layouts, resolving the `InflateException` / *"Couldn't add widget"* error.
  - Updated `minWidth` and `minHeight` in `single_task_widget_info.xml` and `single_note_widget_info.xml` to `110dp`, preventing Samsung One UI from mapping 2x2 widgets to 2x3.
- **Native Dynamic Day Rollover & Midnight Alarms (`TaskWidgetDateHelper.kt` & `MidnightWidgetUpdateReceiver.kt`):**
  - Created `TaskWidgetDateHelper.resolveTaskState()` in Kotlin to dynamically evaluate recurring task rollover directly during widget rendering if `currentDate > taskDate`.
  - Implemented `MidnightWidgetUpdateReceiver` registered for `ACTION_DATE_CHANGED`, `ACTION_TIME_SET`, `ACTION_TIMEZONE_CHANGED`, `ACTION_BOOT_COMPLETED`, and scheduled exact alarms via `AlarmManager.setExactAndAllowWhileIdle()` at `00:00:01 AM` every night.
  - Guaranteed live midnight widget rollover without requiring the Flutter app to be opened.

### Architecture Impact
- **Native Android**: Autonomous offline widget rendering and live midnight date evaluation independent of Dart isolate lifecycle.
- **Zero Battery Impact**: AlarmManager only wakes briefly at midnight for a lightweight widget refresh.

### Files Created
- `android/app/src/main/kotlin/com/quicknotes/app/TaskWidgetDateHelper.kt`
- `android/app/src/main/kotlin/com/quicknotes/app/MidnightWidgetUpdateReceiver.kt`

### Files Modified
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/kotlin/com/quicknotes/app/MainActivity.kt`
- `android/app/src/main/kotlin/com/quicknotes/app/SingleTaskWidget.kt`
- `android/app/src/main/kotlin/com/quicknotes/app/SingleTaskLongWidget.kt`
- `android/app/src/main/kotlin/com/quicknotes/app/MultiTaskWidget.kt`
- `android/app/src/main/res/layout/single_task_widget_layout.xml`
- `android/app/src/main/res/layout/single_task_long_widget_layout.xml`
- `android/app/src/main/res/layout/multi_task_widget_layout.xml`
- `android/app/src/main/res/xml/single_task_widget_info.xml`
- `android/app/src/main/res/xml/single_note_widget_info.xml`
- `android/app/src/main/res/drawable/ic_task_clock_pending.xml`
- `android/app/src/main/res/drawable/ic_task_check_completed.xml`

### Breaking Changes
None. Fully backwards-compatible.
