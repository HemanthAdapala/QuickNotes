# SearchScreen Changelog

All implementation details, visual design tokens, interaction mechanics, and architectural specifications for `SearchScreen` are documented in this changelog in accordance with `MasterChangelogDocumentationPolicy.md`.

---

## [v2.6.0] - 2026-08-12

### Author
Developer / Anti Gravity

### Type
- Bug Fix
- UI
- Refactor

---

### Summary
Fixed physical device focus stealing (Bug 1) and exact match scrolling offset (Bug 2) in `NoteEditorScreen` local search.

---

### Detailed Changes
- **Focus Stealing Prevention (Bug 1 Fix)**:
  - Added search focus guards to `_onTitleTextChanged` and `_onContentTextChanged` in [note_editor_screen.dart](file:///c:/Users/heman/.gemini/antigravity-ide/scratch/QuickNotes/lib/views/screens/note_editor_screen.dart#L1730): when `_isLocalSearchOpen && _localSearchFocusNode.hasFocus` is true, text change listeners ignore highlight notifications and bypass `setState()`, preventing editor focus listeners from stealing focus from `_localSearchFocusNode` and returning the cursor to the search bar.
- **Native Rendered Segment Match Scrolling (Bug 2 Fix)**:
  - Added `scrollToMatchOffset(int matchStart)` method to `NewSingleDocumentEditorState` in [new_single_document_editor.dart](file:///c:/Users/heman/.gemini/antigravity-ide/scratch/QuickNotes/lib/views/widgets/new_single_document_editor.dart#L1042): uses Flutter's native `Scrollable.ensureVisible` on the exact target `TextSegment`'s `GlobalKey` context with `alignment: 0.15`.
  - Every match (first match, next `▼`, previous `▲`) reliably scrolls to **15% from the top of the physical device viewport**, sitting comfortably above the RTF toolbar and soft keyboard.

---

## [v2.5.0] - 2026-08-12

### Author
Developer / Anti Gravity

### Type
- Feature
- Animation
- UI

---

### Summary
Implemented Apple iOS 18 Sheet Slide & In-Place Glass Expansion transition for `SearchScreen` with 100% pixel-locked header bar geometry, and added In-Editor Local Text Search inside `NoteEditorScreen`.

---

### Detailed Changes
- **Pixel-Locked Header Bar**: Locked top header bar padding in `SearchScreen` to `EdgeInsets.fromLTRB(24.0, 12.0, 24.0, 0.0)` matching all primary app screens, eliminating header icon shifting.
- **Apple iOS 18 Transition**: Added `TweenAnimationBuilder` slide (+36px -> 0px) and opacity fade for the Scope Pill Bar and Body Sheet Card under the fixed top glass header bar.
- **In-Editor Local Search (`NoteEditorScreen`)**:
  - Decoupled In-Editor Local Search completely from `SingleDocumentDragOverlay` and text selection mutations, preventing native selection handle glitches.
  - Isolated search bar state rebuilds with `ValueNotifier<int>` (`_localMatchNotifier`) and `ValueListenableBuilder`: typing in `_localSearchCtrl` zero-rebuilds parent `NoteEditorScreenState`, preserving soft keyboard and cursor focus 100% on physical Android and iOS devices.
  - Implemented exact physical device layout height calculation using Flutter `TextPainter` (`ui.TextDirection.ltr`): calculates physical screen width and font metrics to scroll every match line (first match, next `▼`, previous `▲`) to 80px below the top header, sitting at the top 15% of the viewport far above the soft keyboard and RTF toolbar.
  - Implemented pure Marker highlighting across Title (`_TitleTextEditingController`), Body (`RichTextEditingController`), and SDE segments (`RangeTextEditingController`):
    - All matches paint with a soft yellow marker pen background (`#FFF59D`).
    - Active match paints with a warm orange marker pen background (`#FFB74D`) and bold text.
  - Stepping Next (`▼`) / Previous (`▲`) performs smooth scroll navigation (`_scrollController`) without touching text selection or drag handles.

---

## [v2.4.0] - 2026-08-12

### Author
Developer / Anti Gravity

### Type
- Feature
- UI
- Refactor

---

### Summary
Made Search Screen universally accessible from all primary tabs (Home, Folders, Calendar) except Settings with standardized 44x44 liquid glass Search buttons, contextual default scope pills (`All` for Home, `Notes` for Folders, `Tasks` for Calendar), and relocated the 3-dots `MoreOptionsPopup` to the Settings Screen.

---

### Detailed Changes
- **Universal Search Glass Button**: Replaced the 3-dots header button in `HomeScreen` with a 44x44 liquid glass Search button (`BottomBarGlassSurface` + `TactileButton` + `Icons.search_rounded`).
- **Contextual Default Scope Pills**:
  - Home tab opens `SearchScreen(initialScope: 'all')` (default active scope pill: **All**).
  - Folders tab opens `SearchScreen(initialScope: 'notes')` (default active scope pill: **Notes**).
  - Calendar tab opens `SearchScreen(initialScope: 'tasks')` (default active scope pill: **Tasks**).
- **Settings Screen Header Action**: Relocated the 3-dots `MoreOptionsPopup` menu (with "Delete Data" and "Refresh Data" options) to `SettingsScreen`'s top-right header action bar. Settings Screen explicitly excludes the Search button.
- **Hero Tag Disambiguation**: Applied unique Hero tags (`hero_home_search`, `hero_folders_search`, `hero_settings_more`) across `IndexedStack` tabs to prevent Hero animation conflicts.

---

## [v2.3.0] - 2026-08-11

### Author
Developer / Anti Gravity

### Type
- Feature
- UI
- Refactor

---

### Summary
Replaced flat list tile `_FolderResultRow` in `SearchScreen` with the 3D `FolderGridCard` widget (`lib/views/widgets/folder_card.dart`) rendered in a 2-column grid (`SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 8.0, mainAxisSpacing: 16.0, childAspectRatio: 150.0 / 192.0)`), matching the Folder Screen (`FolderManagementScreen`) and Figma design specifications ("Global Search Screen Folders").

---

### Detailed Changes
- **3D Folder Card Integration**: Imported `FolderGridCard` from `lib/views/widgets/folder_card.dart` into `search_screen.dart`.
- **2-Column Grid Layout**: Replaced single-line list tile rows under `FOLDERS` search results with a 2-column `GridView.builder`.
- **Visual Parity with Folder Screen**: Rendered 3D folder flap graphics (`FolderBgPainter`, `FolderFgPainter`), peeking decorative note cards, sticker overlay, search query substring text highlighting (`#D49200`), and note count badge.
- **Removed Browse by Category**: Removed the "BROWSE BY CATEGORY" section and category chips from `_buildEmptyState()` in `search_screen.dart`.
- **Inter Typography Standardization**: Converted all section headers (`_SectionHeader`), count badges, and labels (`CREATE NEW`) from `GoogleFonts.jetBrainsMono` to `GoogleFonts.inter`.
- **Interactive Navigation**: Connected card tap gesture to navigate directly to `FolderNotesScreen` for the target folder.
- **Code Cleanup**: Removed legacy `_FolderResultRow` class from `search_screen.dart`.

---

## [v2.2.0] - 2026-08-11

### Author
Developer / Anti Gravity

### Type
- Feature
- UI
- Animation

---

### Summary
Implemented `SearchTaskCard` (`lib/views/widgets/search_task_card.dart`), a custom result card widget specifically for Task items in `SearchScreen` based on Figma specification ("Global Search Screen Tasks"). Features a dual-layer stack with a peeking top Electric Blue accent rim (`#0088FF`, 20px radius), a white front card sheet (`#FFFFFF`, 20px radius) shifted down by 8px, top metadata bar showing formatted Date (`Tue, 1 June 2026`) and Time (`02:00 AM`), Amber text match highlighting on task titles, and inline priority (`🚩 High`) and recurrence (`Daily`) pill badges.

---

### Detailed Changes
- **Dual-Layer Blue Peeking Card**: Implemented peeking 8px top Electric Blue accent rim using a 76px tall blue backing container and an 8px top-padded white front sheet card with `20px` corner radius.
- **Date & Time Meta Bar**: Rendered top row with `DateFormat('EEE, d MMMM yyyy')` on the left and history clock icon + `DateFormat('hh:mm a')` on the right.
- **Priority & Recurrence Pill Badges**: Rendered inline `#F2F2F7` pill badges with Red text (`#FF383C`, 10px Inter `w600`, radius 40px) for Task priority (`🚩 High`) and recurrence rule (`Daily`).
- **Title Match Highlighting**: Applied `_buildHighlightSpans` with Amber text spans (`#D49200`) for search query matches in task titles.
- **Widget Modularization**: Extracted `SearchTaskCard` into `lib/views/widgets/search_task_card.dart` and integrated into `SearchScreen`.

---

## [v2.1.0] - 2026-08-11

### Author
Developer / Anti Gravity

### Type
- Feature
- UI
- Animation

---

### Summary
Implemented `SearchNoteCard` (`lib/views/widgets/search_note_card.dart`), a custom result card widget specifically for Note items in `SearchScreen` based on Figma specification ("Global Search Screen Notes"). Features a dual-layer stack with a peeking top Accent Yellow rim (`#FFCC00`, 20px radius), a white front card sheet (`#FFFFFF`, 20px radius) shifted down by 8px, top metadata bar showing formatted Date (`Tue, 1 June 2026`) and Time (`02:00 AM`), and Amber text match highlighting on both note title and 2-line preview body text.

---

### Detailed Changes
- **Dual-Layer Accent Peeking Card**: Implemented peeking 8px top yellow accent rim using a 76px tall yellow backing container and an 8px top-padded white front sheet card with `20px` corner radius.
- **Date & Time Meta Bar**: Rendered top row with `DateFormat('EEE, d MMMM yyyy')` on the left and history clock icon + `DateFormat('hh:mm a')` on the right.
- **Title & Body Match Highlighting**: Applied `_buildHighlightSpans` with Amber text spans (`#D49200`) for search query matches in note titles and preview body lines.
- **Widget Modularization**: Extracted `SearchNoteCard` into `lib/views/widgets/search_note_card.dart` and integrated into `SearchScreen`.

---

## [v2.0.0] - 2026-08-11

### Author
Developer / Anti Gravity

### Type
- Feature
- UI
- Animation
- Architecture

---

### Summary
Redesigned `SearchScreen` into a liquid glass Apple-inspired Global Search screen based on Figma specifications ("Global Search Screen Basic"). Integrates a 44px liquid glass header bar (left `angle_left` back pill, expanded glass `TextField` search pill, right `close` pill), an animated horizontal Scope Selector Bar (`All`, `Notes`, `Tasks`, `Folders`, `Categories`) on grouped grey background (`#F2F2F7`), and a top-rounded 20px white sheet card with a top drop shadow (`BoxShadow(blurRadius: 16)`). Updated the right close button to immediately dismiss the screen when empty or clear query text when present, and updated `CalendarScreen` to default `initialScope` to `'all'`.

---

### Detailed Changes
- **Liquid Glass AppHeader Bar**: Added 44px left glass pill (`angle_left.svg`), expanded glass input pill (`TextField` autofocus), and right 44px glass pill (`close_rounded`).
- **Right Glass Button Logic**: Tapping `X` clears text if present, or immediately pops the search screen (`Navigator.of(context).pop()`) with haptics if empty.
- **Scope Pill Selector**: Rendered 40px tall scrollable pill bar on `#F2F2F7` background. Active pill uses Accent Yellow (`#FFCC00`) with white text; inactive pills use `Color(0x28787880)` with grey text (`Color(0x993C3C43)`).
- **Responsive Sheet Body Card**: Built a responsive `Expanded` container with `BorderRadius.vertical(top: Radius.circular(20.0))` and subtle top shadow.
- **Recent Searches Header**: Added `"Recent Searches"` and `"Clear all"` action row inside the white card sheet.
- **CalendarScreen Integration**: Updated top-right search button to launch `SearchScreen` with `initialScope: 'all'`.

---

## [v1.0.0] - 2026-08-11

### Author
Developer / Anti Gravity

### Type
- Feature
- UI
- Animation
- Architecture
- Performance
- Documentation

---

### Summary
`SearchScreen` provides a high-performance, unified, real-time search engine for QuickNotes. Accessible via the top-right search button on the Calendar Screen (`CalendarScreen`), as well as from Folder Details (`FolderNotesScreen`) and Category Details (`CategoryDetailsScreen`), it offers multi-domain query search across **Notes**, **Tasks**, **Folders**, and **Categories**. Built with a 4-state state machine (`empty`, `typing`, `results`, `noResults`), debounced typing, amber keyword highlighting, multi-dimensional filter pills, persistent recent searches via `SharedPreferences`, and liquid Apple-inspired spring animations (`SearchRoute`).

---

### Detailed Changes

#### 1. Four-State State Machine (`_UiState`)
`SearchScreen` transitions cleanly between four user states based on text length, query execution, and result count:
- **`empty` (`_UiState.empty`)**:
  - Displays persistent **Recent Searches** list (up to 8 deduplicated terms) with individual deletion (`X`) and a global **Clear all** trigger.
  - Displays a **Browse by Category** wrap grid of interactive category chips pre-populated with default and custom active note categories, formatted with category color dots.
  - Animated with entry fade transition (`_entryFade`).
- **`typing` (`_UiState.typing`)**:
  - Activated when input query length reaches 2 or more characters.
  - Features a **300ms Timer debounce** (`_debounce`) to prevent redundant query executions on fast keypresses.
  - Displays 5 animated shimmer skeleton placeholder rows (`_ShimmerRow`) driven by a pulsing opacity animation controller (`1200ms Curves.easeInOut`) alongside a central Amber `CircularProgressIndicator`.
- **`results` (`_UiState.results`)**:
  - Real-time client-side search executed against `NotesProvider.allActiveNotes`, `TasksProvider.tasks`, `NotesProvider.folders`, and system category lists.
  - Results are rendered in grouped, labelled sections: **NOTES**, **TASKS**, **FOLDERS**, and **CATEGORIES**.
  - Includes interactive result count badges (`_SectionHeader`) next to monospace section titles (`GoogleFonts.jetBrainsMono`).
  - Staggered list entrance animations utilizing `AnimatedListEntrance` keyed with result generation IDs (`_resultGeneration`).
  - Matching text strings in titles and preview snippets are dynamically highlighted using Amber background spans (`_buildHighlightSpans`).
  - Tapping a successful search automatically saves/prepends the query string into persistent recent searches (`RecentSearchesService`).
- **`noResults` (`_UiState.noResults`)**:
  - Displayed when no matching entities are found after filtering.
  - Features an empty-state search icon badge with a close indicator.
  - Offers immediate recovery actions via **Ghost Chips** (`_GhostChip`): `Clear filters` and `Search in all folders`.
  - Includes a **"CREATE NEW"** card allowing the user to instantly launch `NoteEditorScreen` pre-seeded with the search query as the new note title.

#### 2. Scope & Filter Engine
- **Horizontal Scope Pills (`_buildScopePills`)**:
  - Filters displayed entities by scope: `All`, `Notes`, `Tasks`, `Folders`, `Categories` (`_Scope` enum).
  - Tapping triggers tactile haptic feedback (`HapticFeedback.selectionClick()`) and updates state smoothly.
- **Contextual Pre-Filtering**:
  - Accepts initial configuration parameters: `initialScope` (e.g. `'tasks'` when launched from Calendar Screen), `presetFolder`, and `presetCategory`.
- **Secondary Multi-Dimensional Filter Bar (`_buildFilterBar`)**:
  - **Folder Filter**: Modal bottom-sheet (`_showFolderPicker`) to isolate search to specific user folders.
  - **Category Filter**: Modal bottom-sheet (`_showCategoryPicker`) to isolate search to specific categories.
  - **Date Range Filter**: Modal bottom-sheet (`_showDatePicker`) filtering notes/tasks by `allTime`, `today`, `thisWeek`, or `thisMonth`.

#### 3. Persistent Recent Searches (`RecentSearchesService`)
- Singleton service (`RecentSearchesService.instance`) managing `quick_notes_recent_searches` key in `SharedPreferences`.
- Deduplicates search terms, prepends most recent searches, and caps storage at 8 items.
- Provides atomic methods: `load()`, `addSearch(term)`, `removeSearch(term)`, and `clearAll()`.

#### 4. Navigation & Page Transition (`SearchRoute`)
- Customized page route (`SearchRoute`) extending `PageRouteBuilder`.
- Slide-up entrance from `Offset(0.0, 1.0)` to `Offset.zero` with `kCurveEnter` combined with fade transition over `kDurationNormal` (300ms).
- Quick reverse exit transition over `kDurationFast` (150ms).

#### 5. Visual & Design Tokens
- **Background**: `#FFFFFF` (`_kBg`).
- **Primary Ink**: `#333333` (`_kInk`).
- **Accent Amber**: `#FFCC00` / `#FFA322` (`_kAmber`).
- **Placeholder**: `#73333333` (`_kPlaceholder`).
- **Typography**: `GoogleFonts.inter` for body and inputs, `GoogleFonts.jetBrainsMono` for section labels, and `GoogleFonts.playfairDisplay` for titles.
- **Corner Radii**: `16.0px` (`_kBorderRadius`) for cards, `20.0px` for search bar and scope chips.

---

### Why Was This Change Made?
1. **Unified Search Experience**: Previously, note browsing and task lookups were fragmented across individual views. `SearchScreen` provides a single entry point for querying the entire application.
2. **Calendar Screen Integration**: Users viewing scheduled tasks on the Calendar Screen required a fast mechanism to locate specific tasks and related notes without returning to the home tab.
3. **UX Efficiency**: Debounced typing, recent searches history, and instant keyword highlighting minimize friction when locating notes and tasks.

---

### Architecture Impact
- **Navigation**: Uses custom `SearchRoute` slide-up transitions. Opened from Calendar Screen (`calendar_screen.dart`), Folder Screen (`folder_notes_screen.dart`), and Category Screen (`category_details_screen.dart`).
- **State Management**: Consumes `NotesProvider` and `TasksProvider` via Provider without mutating underlying note/task models.
- **Storage & Persistence**: Integrates `RecentSearchesService` backed by `SharedPreferences`.
- **Performance**: Client-side single-pass filtering with 300ms debounce prevents unnecessary CPU/re-render churn.

---

### Files Created
- `lib/views/screens/search_screen.dart`
- `lib/services/recent_searches_service.dart`
- `lib/core/animations/search_route.dart`
- `.agents/skills/ChangeLogs Folder/SearchScreen_Changelog.md`

---

### Files Modified
- `lib/views/screens/calendar_screen.dart`: Connected top-right search glass pill button to navigate to `SearchScreen(initialScope: 'tasks')`.
- `lib/views/screens/note_calendar_screen.dart`: Wired search navigation.
- `lib/views/screens/folder_notes_screen.dart`: Wired preset folder search navigation.
- `lib/views/screens/category_details_screen.dart`: Wired preset category search navigation.

---

### Dependencies Added
- `shared_preferences` (for recent searches storage)
- `intl` (for date formatting)
- `google_fonts` (for Inter & JetBrains Mono typography)
- `provider` (for reading `NotesProvider` and `TasksProvider` state)

---

### Breaking Changes
None.

---

### Migration Notes
None required.

---

### Future Improvements
- Add global full-text indexing for note body text inside SQLite DB (`FTS5`).
- Support voice query input integration.
- Include image attachment alt-text matching.

---

### Known Issues
None.

---

### Testing Status
- **Manual Tests**:
  - Opened search from Calendar Screen top-right search button (verified initial scope set to `tasks`).
  - Tested search queries across Notes, Tasks, Folders, and Categories.
  - Verified amber text highlight rendering.
  - Verified 300ms debounce and shimmer loading placeholders.
  - Tested adding, deleting, and clearing recent search items.
  - Tested "CREATE NEW" note action when search returns no results.
- **Automated Tests**: Verified via app build and test suite pass.

---

### Final Result
`SearchScreen` is fully operational, fully integrated with Calendar Screen and other views, and documented in detail in accordance with the project's master documentation policy.
