# Navigation Changelog

This changelog acts as the permanent architectural knowledge base for the Navigation and Screen Transition subsystem in Quick Notes.

---

## v1.0.0

### Date
2026-09-04

### Author
Anti Gravity (Senior Flutter Architect)

### Type
- Architecture
- Animation
- Bug Fix
- Refactor

---

### Summary
Established Phase P4.1 — Global Motion Foundation. Centralized standard and note-opening page transition primitives onto authoritative `QuickNotesMotion` tokens and introduced global reduced-motion behavioral overrides across all custom page, morph, search, modal sheet, and dialog transitions. Resolved forensic findings P4-DEF-03, P4-DEF-04, and P4-DEF-05.

---

### Detailed Changes
- **QuickNotesPageRoute<T> Foundation**: Introduced minimal `QuickNotesPageRoute<T>` in `lib/core/animations/page_transitions.dart` encapsulating authoritative `QuickNotesMotion.kMotionPage` (340ms forward) and `QuickNotesMotion.kMotionPageReverse` (260ms reverse) with Apple-style easing (`QuickNotesMotion.kMotionAppleEase`).
- **Global Reduced-Motion Overrides (P4-DEF-03)**:
  - Overrode `transitionDuration` and `reverseTransitionDuration` getters in custom routes (`QuickNotesPageRoute`, `PixelAlignedSearchRoute`, `FabMorphPageRoute`, `FolderMorphPageRoute`, `AnimatedBottomSheetRoute`) to return `Duration.zero` whenever `MediaQuery.maybeDisableAnimationsOf(ctx) == true`.
  - Added immediate non-animated child presentation guards in `transitionsBuilder` across all custom route builders, `showBlurredBottomSheet`, and `showAnimatedDialog`.
- **Motion Token Centralization (P4-DEF-04)**:
  - Eliminated hardcoded duplicate literals (`340ms`, `260ms`, `Cubic(0.20, 0, 0, 1.0)`) in `buildNoteOpeningPageRoute` and `buildPageRoute` in favor of authoritative `QuickNotesMotion` tokens.
  - Standardized reverse easing on `Curves.easeInCubic`.
- **Settings Screen Route Unification (P4-DEF-05)**:
  - Migrated `SDEDragTestScreen` navigation from raw `MaterialPageRoute` to `buildPageRoute`.
- **Zero Firewall Invasions**:
  - Maintained 100% isolation from P2.6 Home Motion firewall (`notes_stack_widget.dart`, `task_widget.dart`, `filter_pill.dart`, `app_bottom_navigation_bar.dart`) and P3 Header firewalls (P3.3 geometry, P3.5 tactile motion/haptics, P3.7 expanded interaction, P3.9 focus containment).

---

### Why was this change made?
Phase P4.0 forensic audit revealed:
1. P4-DEF-03: Custom transitions bypassed `MediaQuery.disableAnimations`.
2. P4-DEF-04: Multiple route transitions duplicated inline duration and curve literals.
3. P4-DEF-05: Raw `MaterialPageRoute` was used in `SettingsScreen`.
P4.1 establishes the clean foundational layer for all subsequent P4 polish phases.

---

### Architecture Impact
- Standard page transitions now share a single token source of truth (`QuickNotesMotion`).
- When reduced motion is requested by the OS or user, transitions immediately present without animation lag or visual motion.
- Preserved specialized transitions' normal timings (e.g. FAB morph 400ms/350ms, folder morph 450ms/400ms, search 300ms/220ms, sheet 350ms/250ms).

---

### Files Created
- `Agents/skills/ChangeLogs Folder/Navigation_Changelog.md`
- `test/views/global_motion_foundation_p4_1_test.dart`

---

### Files Modified
- `lib/core/animations/page_transitions.dart`
- `lib/core/animations/search_transition_routes.dart`
- `lib/core/animations/bottom_sheet_transition.dart`
- `lib/core/animations/dialog_transition.dart`
- `lib/views/widgets/blurred_bottom_sheet.dart`
- `lib/views/widgets/living_writing_experience.dart`
- `lib/views/screens/settings_screen.dart`
- `Agents/skills/ChangeLogs Folder/SettingsScreen_Changelog.md`

---

### Dependencies Added
None.

---

### Breaking Changes
None. Public API signatures preserved.

---

### Migration Notes
All standard hierarchical page navigation continues to call `buildPageRoute(Widget page)`. Note opening continues to use `buildNoteOpeningPageRoute(Widget page)`.

---

### Future Improvements (Deferred to Later P4 Phases)
- P4.2: Note card Hero tag unification and search orphan Hero cleanup.
- P4.3: Document opening choreography & visual hierarchy harmonization.
- P4.4: Primary bottom navigation tab crossfade.
- P4.5: Bottom sheet transition harmonization.
- P4.6: Global rapid navigation debounce and haptic consolidation.

---

### Testing Status
- Automated tests: All 12 tests in `test/views/global_motion_foundation_p4_1_test.dart` passing.
- P3 regression tests: All 46 tests in `header_motion_haptics_test.dart`, `header_expanded_interaction_test.dart`, and `header_transition_geometry_test.dart` passing.
- P2.6 regression tests: All 36 tests in `card_stack_motion_test.dart`, `home_filter_motion_test.dart`, and `home_screen_motion_test.dart` passing.
- `flutter analyze` reports zero new issues.

---

## [1.1.0] - 2026-09-04 (Phase P4.2: Hero & Shared-Element Polish)

### Summary
Surgical hygiene and correctness pass on Hero and shared-element transitions:
1. Removed orphan `Hero(tag: 'hero_folders_search')` wrapper in `FolderManagementScreen`.
2. Assigned explicit screen-specific Hero tags (`hero_category_details_back`, `hero_category_details_search`) to `AppHeaderBar` in `CategoryDetailsScreen`.
3. Harmonized legacy `NoteCard` Hero tag to `'hero_note_card_${widget.note.id}'` for architectural consistency.
4. Preserved existing locked Home → NoteEditor Hero flight (`hero_note_card_${note.id}`) and protected standard page transitions (`buildPageRoute`) across Folders, Categories, and Search.

---

### Detailed Changes

#### 1. Orphan Hero Removal (`lib/views/screens/folder_management_screen.dart`)
- Stripped the unused `Hero(tag: 'hero_folders_search')` wrapper around the trailing search glass button.
- Preserved all surrounding layout, geometry (44x44px), `BottomBarGlassSurface`, `TactileButton`, semantics, and navigation to `SearchScreen`.

#### 2. Screen-Specific Header Hero Tags (`lib/views/screens/category_details_screen.dart`)
- Replaced fallback `hero_header_leading` and `hero_header_trailing` with explicit `hero_category_details_back` and `hero_category_details_search`.
- Maintained clean separation preventing accidental cross-screen Hero morphing.
- Safely cached `ModalRoute` reference in `didChangeDependencies` to prevent deactivated ancestor lookup assertion during widget disposal.

#### 3. Legacy NoteCard Tag Harmonization (`lib/views/widgets/note_card.dart`)
- Updated tag from `'note_card_${widget.note.id}'` to `'hero_note_card_${widget.note.id}'`.

---

### Hero Architecture & Flight Audit
- **Active Shared-Element Flights**:
  - `HomeScreen` (`NotesStackWidget`) → `NoteEditorScreen` via `hero_note_card_${id}` (LOCKED P2.6 interaction).
- **Intentionally Standard Horizontal Transitions (No Hero)**:
  - Folders (`FolderNoteCard`) → `NoteEditorScreen`: standard page route.
  - Categories (`_CategoryNoteCard`) → `NoteEditorScreen`: standard page route.
  - Search (`SearchNoteCard`) → `NoteEditorScreen`: standard page route.
- **Header Morph Policy**: Screen-specific controls remain distinct; cross-screen morphs between semantically disparate elements (e.g. avatar → back chevron) are strictly forbidden.

---

### Files Created
- `test/views/hero_shared_element_p4_2_test.dart`

---

### Files Modified
- `lib/views/screens/folder_management_screen.dart`
- `lib/views/screens/category_details_screen.dart`
- `lib/views/widgets/note_card.dart`
- `Agents/skills/ChangeLogs Folder/Navigation_Changelog.md`

---

### Testing Status
- Automated tests: All 5 tests in `test/views/hero_shared_element_p4_2_test.dart` passing.
- Combined P4 tests: All 17 tests in `test/views/hero_shared_element_p4_2_test.dart` and `test/views/global_motion_foundation_p4_1_test.dart` passing.
- P3 regression tests: All 56 tests in `app_header_bar_test.dart`, `header_motion_haptics_test.dart`, `header_expanded_interaction_test.dart`, and `header_transition_geometry_test.dart` passing.
- P2.6 regression tests: All 36 tests in `card_stack_motion_test.dart`, `home_filter_motion_test.dart`, and `home_screen_motion_test.dart` passing.
- `flutter analyze` reports zero new issues.

---

## [1.2.0] - 2026-09-04 (Phase P4.3: Screen & Document Transition Visual Polish)

### Date
2026-09-04

### Author
Anti Gravity (Senior Flutter Architect)

### Type
- Bug Fix
- UI
- Animation

---

### Summary
Surgical visual transition polish pass resolving production defect P4-DEF-10. Replaced the unanchored `FolderMorphPageRoute` with `cardBounds: Rect.zero` in `SearchScreen._openFolder` with the authoritative standard page transition `buildPageRoute(FolderNotesScreen(folder: folder))`. Preserved the entire existing Quick Notes motion language without redesign, protecting valid measured folder morphs in `FolderManagementScreen`, standard transitions across collections, and the Home → NoteEditor Hero choreography.

---

### Detailed Changes

#### 1. Search Folder Navigation Route Correction (P4-DEF-10)
- **File**: `lib/views/screens/search_screen.dart`
- **Target**: `_openFolder(Folder folder)`
- **Change**: Replaced `FolderMorphPageRoute(cardBounds: Rect.zero, builder: (_) => FolderNotesScreen(folder: folder))` with `buildPageRoute(FolderNotesScreen(folder: folder))`.
- **Result**:
  - Eliminates the unanchored diagonal expansion / top-left zoom from coordinate (0,0).
  - Replaces it with the clean, established horizontal slide + fade language.
  - Inherits authoritative motion tokens: 340ms forward (`QuickNotesMotion.kMotionPage`), 260ms reverse (`QuickNotesMotion.kMotionPageReverse`), `QuickNotesMotion.kMotionAppleEase`, and `Curves.easeInCubic`.
  - Automatically inherits global reduced-motion behavior (`Duration.zero` when `disableAnimations: true`).

#### 2. Architecture & Transition Language Preservation
- **Search Result Consistency**: All search results (Note, Task, Category, Folder) now strictly adhere to the standard `QuickNotesPageRoute` contract.
- **Valid Folder Morph Preserved**: Protected the legitimate `FolderMorphPageRoute` invocation in `FolderManagementScreen`, which continues to use measured screen bounds (`Rect`).
- **Home Document Opening Preserved**: Protected `buildNoteOpeningPageRoute` and the active `hero_note_card_${note.id}` flight between `HomeScreen` and `NoteEditorScreen`.
- **Zero Firewall Invasions**: Preserved all locked firewalls (P2.6 Home Motion, P3.3 Header Geometry, P3.5 Header Motion/Haptics, P3.7 Header Expanded Interaction, P3.9 Focus Containment, P4.1 Global Motion Foundation, P4.2 Hero decisions).

---

### Why was this change made?
Forensic audit P4.3 identified P4-DEF-10 as the only production motion defect: when a user tapped a Folder in Search results, `SearchScreen` instantiated `FolderMorphPageRoute` with `Rect.zero`. Because the route had no geometry to expand from, it expanded diagonally across the screen from coordinate (0,0), creating an unanchored visual anomaly. Replacing it with `buildPageRoute` unifies the Search motion experience with the rest of the app.

---

### Architecture Impact
- Standardized Search result navigation on `buildPageRoute`.
- Eliminated defective `Rect.zero` route allocations.
- Maintained intentional motion diversity (Hero scale/fade on Home, measured morph on Folder Management, standard slide+fade elsewhere).

---

### Files Created
- `test/views/screen_transition_visual_p4_3_test.dart`

---

### Files Modified
- `lib/views/screens/search_screen.dart`
- `Agents/skills/ChangeLogs Folder/Navigation_Changelog.md`

---

### Dependencies Added
None.

---

### Breaking Changes
None.

---

### Testing Status
- Automated tests: All 5 tests in `test/views/screen_transition_visual_p4_3_test.dart` passing.
- Full P4 suite: All 22 tests passing across P4.1 (12), P4.2 (5), and P4.3 (5).
- P3 regression tests: All 56 tests in `app_header_bar_test.dart`, `header_motion_haptics_test.dart`, `header_expanded_interaction_test.dart`, and `header_transition_geometry_test.dart` passing.
- P2.6 regression tests: All 36 tests in `card_stack_motion_test.dart`, `home_filter_motion_test.dart`, and `home_screen_motion_test.dart` passing.
- `flutter analyze` reports zero issues across all modified and created files.

---

## [1.3.0] - 2026-09-04 (Phase P4.4: Primary Navigation & Tab Motion)

### Date
2026-09-04

### Author
Anti Gravity (Senior Flutter Architect)

### Type
- Bug Fix
- Accessibility
- Animation

---

### Summary
Surgical tactile accessibility fix resolving defect P4.4-DEF-01 in `AppBottomNavigationBar`. Moved semantic haptic dispatch ahead of the reduced-motion early exit in `_NavigationButton._handleTap`, restoring tactile confirmation when switching tabs under `MediaQuery.disableAnimations == true`. Explicitly affirmed and locked the existing primary navigation architecture (instant body switching via `IndexedStack` paired with 260ms liquid spring indicator travel) without introducing body-level crossfade, slide, or layout disruption.

---

### Detailed Changes

#### 1. Reduced-Motion Navigation Haptic Restoration (P4.4-DEF-01)
- **File**: `lib/views/widgets/app_bottom_navigation_bar.dart`
- **Target**: `_NavigationButton._handleTap(bool reduceMotion)`
- **Change**: Reordered semantic haptic execution (`QuickNotesHaptics.navigationSelection()`) ahead of `if (reduceMotion) { widget.onDestinationSelected(widget.index); return; }`.
- **Result**:
  - Inactive tab selection under reduced motion now fires exactly ONE `navigationSelection` haptic.
  - Active tab re-tap under reduced motion continues to fire ZERO haptics.
  - FAB `buttonPress` haptic continues to fire under both normal and reduced motion.
  - Visual animations (scale compression, indicator spring travel, liquid stretch) remain completely suppressed when `disableAnimations: true`.

#### 2. Architectural Preservation & Lock
- **Instant Body Switching Preserved**: Reaffirmed `IndexedStack` as the authoritative destination host; zero artificial latency, zero body crossfade/slide, zero false spatial hierarchy, and zero raster jank.
- **State Retention**: 100% state preservation across Folders, Calendar, and Settings guaranteed by persistent Element subtrees.
- **Element Identity**: Preserved `ValueKey('home_bottom_navigation_bar_positioned')` persistent Element identity.
- **Firewall Integrity**: 100% isolation maintained across P2.6 Home Motion, P3 Header Geometry/Motion, and P4.1-P4.3 foundations.

---

### Why was this change made?
Forensic audit P4.4 identified that `_NavigationButton._handleTap` previously returned early when `reduceMotion` was true before reaching the semantic haptics block. Accessibility standards dictate that reduced-motion settings should eliminate visual motion triggers (vestibular sensitivity), not tactile confirmation. Reordering the checks ensures tactile feedback is preserved for all users.

---

### Architecture Impact
- Restored tactile accessibility parity.
- Preserved existing primary navigation motion tokens (`kMotionSelection` = 260ms, `kMotionSpring`, `kMotionMicro` = 90ms, `kMotionRelease` = 190ms).
- Maintained zero-jank GPU performance by avoiding dual-layer blur compositing.

---

### Files Created
- `test/views/primary_navigation_p4_4_test.dart`

---

### Files Modified
- `lib/views/widgets/app_bottom_navigation_bar.dart`
- `Agents/skills/ChangeLogs Folder/Navigation_Changelog.md`

---

### Dependencies Added
None.

---

### Breaking Changes
None.

---

### Testing Status
- Automated tests: All 6 tests in `test/views/primary_navigation_p4_4_test.dart` passing.
- Combined P4 suites: All 28 tests passing across P4.1 (12), P4.2 (5), P4.3 (5), and P4.4 (6).
- P3 regression tests: All 56 tests in `app_header_bar_test.dart`, `header_motion_haptics_test.dart`, `header_expanded_interaction_test.dart`, and `header_transition_geometry_test.dart` passing.
- P2.6 regression tests: All 36 tests in `card_stack_motion_test.dart`, `home_filter_motion_test.dart`, and `home_screen_motion_test.dart` passing.
- `flutter analyze` reports zero errors and zero new warnings.

---

## [1.4.0] - 2026-09-04 (Phase P4.5: Modal, Sheet & Transient Surface Motion)

### Date
2026-09-04

### Author
Anti Gravity (Senior Flutter Architect)

### Type
- Accessibility
- Animation
- Polish
- Bug Fix

---

### Summary
Surgical polish and accessibility pass across transient modal surfaces:
1. **P4.5-DEF-01 (CelebrationOverlay Accessibility Bypass)**: Fixed reduced-motion contract in `CelebrationOverlay`. When `MediaQuery.disableAnimations` is enabled, particle physics simulation is completely skipped and replaced with an immediate, static completion acknowledgement badge ("🎉 All tasks done!") that preserves semantic reward and overlay lifecycle (1600ms) without vestibular motion triggers.
2. **P4.5-POLISH-01 (Modal Barrier Consistency)**: Inspected candidate dialog surfaces (`delete_confirmation_dialog.dart` and `delete_task_confirmation_dialog.dart`). Verified both already utilize explicit `#333333` ink barriers at 40% alpha for destructive contrast, while operational sheets utilize the established 20% alpha barrier (`Color(0xFF333333).withValues(alpha: 0.20)`). Per barrier migration rules, no raw Material surfaces were modified.
3. **P4.5-POLISH-02 (Asymmetric Reverse Dismissal for showBlurredBottomSheet)**: Upgraded `showBlurredBottomSheet` to `BlurredBottomSheetRoute` extending `PopupRoute<T>`. Implemented asymmetric timing with 350ms entrance (`Curves.easeOutCubic`) and 260ms exit (`Curves.easeInCubic`). Ensured 100% frame-by-frame synchronization of foreground slide, backdrop tint, and blur sigma filter via `AnimatedBuilder`, while retaining immediate 0ms presentation/dismissal when `disableAnimations: true`.

---

### Detailed Changes

#### 1. CelebrationOverlay Reduced-Motion Fix (P4.5-DEF-01)
- **File**: `lib/views/widgets/celebration_overlay.dart`
- **Change**: Added `MediaQuery.maybeDisableAnimationsOf(context)` detection in `didChangeDependencies`. Under reduced motion, `AnimationController.forward()` is omitted, particle painter is excluded from the widget tree, and a static completion badge is displayed immediately before invoking `widget.onDone()` via `Timer(1600ms)`. Under normal motion, the 50-particle physics simulation and animated badge pop-in remain 100% unchanged.

#### 2. Blurred Bottom Sheet Asymmetric Timing (P4.5-POLISH-02)
- **File**: `lib/views/widgets/blurred_bottom_sheet.dart`
- **Change**: Introduced `BlurredBottomSheetRoute<T> extends PopupRoute<T>` overriding `transitionDuration` (350ms) and `reverseTransitionDuration` (260ms). Applied `CurvedAnimation(curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic)` driving both `BackdropFilter` sigma blur and `SlideTransition` offset in lockstep. Maintained `Duration.zero` bypass when `disableAnimations: true`.

#### 3. Preserved Architecture & Deferred Items
- **Sheet Architecture**: Preserved strict separation between visually rich `showBlurredBottomSheet` (action sheets) and lightweight `showAnimatedBottomSheet` (operational sheets).
- **Dialog Architecture**: Preserved `showAnimatedDialog` (250ms forward/reverse).
- **Deferred Items**: P4.5-POLISH-03 (legacy token alignment in transition constants) and dead transition code (`GlassPopupPageRoute`, `buildFadePageRoute`, dormant Home overlay) remain intentionally untouched.
- **Motion Tokens**: Zero modifications to `lib/core/motion/motion_constants.dart`.
- **Firewall Integrity**: Zero touches to P2.6 Home Motion, P3 Header Geometry/Motion/Focus, and P4.1-P4.4 foundations.

---

### Files Created
- `test/views/transient_surface_p4_5_test.dart`

---

### Files Modified
- `lib/views/widgets/celebration_overlay.dart`
- `lib/views/widgets/blurred_bottom_sheet.dart`
- `Agents/skills/ChangeLogs Folder/Navigation_Changelog.md`

---

### Dependencies Added
None.

---

### Breaking Changes
None. Public API signatures preserved.

---

### Testing Status
- Focused P4.5 tests: All 8 tests in `test/views/transient_surface_p4_5_test.dart` passing.
- Full P4 suite: All 36 tests passing across P4.1 (12), P4.2 (5), P4.3 (5), P4.4 (6), and P4.5 (8).
- P3 regression suite: All 46 tests passing.
- P2.6 regression suite: All 36 tests passing.
- Total passing tests: 118 passing, 0 failing.
- `flutter analyze` reports zero errors and zero new warnings.
