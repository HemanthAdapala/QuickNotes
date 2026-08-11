---
name: hero-tags
description: >
  QuickNotes Hero Tag system guide for AppHeaderBar. Use this skill whenever you
  are adding a new screen that uses AppHeaderBar, debugging a "multiple heroes
  share the same tag" crash, or planning a Hero fly-in animation between screens.
  Covers leftHeroTag / rightHeroTag rules, the IndexedStack constraint, the
  current project-wide tag registry, and step-by-step instructions for new screens.
---

# Hero Tags in QuickNotes — Complete Guide

## 1. What is a Hero Tag?

A **Hero** is Flutter''s shared-element transition widget. It "flies" a widget
visually from one screen to another during a `Navigator.push` / `Navigator.pop`.

```
Home Tab                           Profile Screen
┌──────────────────────────────┐   ┌──────────────────────────────┐
│  [🧑]   Hemanth Adapala  [⋯] │   │  [←]   Profile           [⋯] │
│   ^                       ^  │   │   ^                       ^  │
│   Hero(''hero_profile_hdr'')   │──>│   Hero(''hero_profile_hdr'')   │
└──────────────────────────────┘   └──────────────────────────────┘
                press avatar → glass pill flies to back button on Profile
```

Flutter looks for **the same tag string on both the source and destination
screen**. When it finds a match it animates the widget between them. If the tag
exists twice in the same route simultaneously → crash.

---

## 2. How AppHeaderBar Uses Hero Tags

`AppHeaderBar` (`lib/views/widgets/app_header_bar.dart`) wraps its left and
right glass-pill buttons in individual `Hero` widgets:

```dart
// Left button
Hero(
  tag: leftHeroTag,          // default: ''hero_profile_header''
  child: BottomBarGlassSurface(
    width: leftWidth, height: 44,
    borderRadius: BorderRadius.circular(22),
    child: leftChild,
  ),
)

// Right button (only rendered when rightChild != null)
Hero(
  tag: rightHeroTag,         // default: ''hero_more_options''
  child: BottomBarGlassSurface(
    width: rightWidth, height: 44,
    borderRadius: BorderRadius.circular(22),
    child: rightChild,
  ),
)
```

Both parameters have **project-wide defaults**:

| Parameter      | Default value            |
|---------------|--------------------------|
| `leftHeroTag`  | `''hero_profile_header''`  |
| `rightHeroTag` | `''hero_more_options''`    |

---

## 3. The Golden Rule — IndexedStack vs Push/Pop

### ✅ SAFE — Hero tags shared between a push/pop pair

```
Screen A  (Navigator.push → Screen B)
  Hero(tag: ''hero_profile_header'') ── flies to ──> Hero(tag: ''hero_profile_header'')
```

Both screens are never alive **in the same route simultaneously** (A is covered
by B during the transition). Flutter animates the fly-in.

### 💥 CRASH — Hero tags shared inside an IndexedStack

`HomeScreen` uses `IndexedStack` to keep all 4 tab bodies alive simultaneously
(even when offstage). If Tab 0 and Tab 3 both have `Hero(tag: ''hero_profile_header'')`,
Flutter sees **two live Heroes with the same tag** → exception:

```
There are multiple heroes that share the same tag within a subtree.
```

**Rule: every screen embedded in the IndexedStack MUST have a unique Hero tag.**

---

## 4. HomeScreen IndexedStack Structure

```dart
// home_screen.dart — build()
IndexedStack(
  index: _activeNavIndex,
  children: [
    _buildHomeBody(),       // index 0 — HomePromptView
    _buildFoldersBody(),    // index 1 — FolderManagementScreen
    _buildCalendarBody(),   // index 2 — CalendarScreen
    _buildSettingsBody(),   // index 3 — SettingsScreen
  ],
)
```

All four children are **always in the widget tree** regardless of `_activeNavIndex`.

---

## 5. Project-Wide Hero Tag Registry

> **Always update this table when you add or modify a screen that uses AppHeaderBar.**

### Tab Screens (inside IndexedStack — all must be unique)

| Tab Index | Screen | Widget File | Left Tag | Right Tag |
|-----------|--------|-------------|----------|-----------|
| 0 | Home | `home_prompt_view.dart` | `''hero_profile_header''` ← default | `''hero_more_options''` ← default |
| 1 | Folders | `folder_management_screen.dart` | no AppHeaderBar | — |
| 2 | Calendar | `calendar_screen.dart` | no Hero (plain Row) | — |
| 3 | Settings | `settings_screen.dart` | `''hero_settings_back''` | no right button |

### Pushed Route Screens (can share tags with their source tab)

| Screen | File | Left Tag | Right Tag | Flies from |
|--------|------|----------|-----------|------------|
| Profile | `profile_screen.dart` | `''hero_profile_header''` | `''hero_more_options''` | Home (Tab 0) |
| Note Editor | `note_editor_screen.dart` | `''hero_profile_header''` | `''hero_more_options''` | Home (Tab 0) |
| Folder Notes | `folder_notes_screen.dart` | `''hero_profile_header''` | `''hero_more_options''` | Folders (Tab 1) |
| Export/Import | `export_import_screen.dart` | `''hero_profile_header''` | `''hero_more_options''` | Settings (Tab 3) |
| Appearance | `appearance_screen.dart` | `''hero_profile_header''` | `''hero_more_options''` | Settings (Tab 3) |
| Create Task | `create_task_screen.dart` | `''hero_profile_header''` | `''hero_more_options''` | Home / Calendar |
| Category Details | `category_details_screen.dart` | `''hero_profile_header''` | `''hero_more_options''` | Folders |

> **Note on Settings sub-screens**: Settings uses `''hero_settings_back''`.
> Screens pushed FROM Settings (Export/Import, Appearance) still use the default
> `''hero_profile_header''` — no fly animation fires (tag mismatch), but no crash
> since they are pushed routes, not in the IndexedStack.
> To enable Hero animation for those screens, change their left tag to
> `''hero_settings_back''` to match Settings.

---

## 6. How to Add a New Screen Safely

### Case A — New TAB added to IndexedStack

1. Pick a **new unique tag** following the naming pattern `hero_<screenname>_<side>`
2. Pass it explicitly to AppHeaderBar:

```dart
AppHeaderBar(
  leftHeroTag:  ''hero_myscreen_back'',   // unique, never used elsewhere in IndexedStack
  rightHeroTag: ''hero_myscreen_action'', // unique, only if you have a right button
  leftWidth: 44.0,
  onLeftTap: () { ... },
  leftChild: ...,
)
```

3. **Add the new row to the registry table in Section 5.**

### Case B — New PUSHED ROUTE screen (Navigator.push from a tab)

For a Hero fly-in animation, use the **same tag as the source tab**:

```dart
// Source tab (Home) uses: leftHeroTag = ''hero_profile_header'' (default)

// Destination pushed screen — use the SAME tag:
AppHeaderBar(
  // leftHeroTag defaults to ''hero_profile_header'' → matches source → animates ✅
  leftWidth: 44.0,
  onLeftTap: () => Navigator.of(context).pop(),
  leftChild: Icon(Icons.arrow_back),
)
```

If the source tab uses a custom left tag (e.g. Settings → `''hero_settings_back''`),
the destination screen must match:

```dart
AppHeaderBar(
  leftHeroTag: ''hero_settings_back'', // matches Settings tab → fly animates ✅
  ...
)
```

---

## 7. Special Case — CalendarScreen (No Hero at All)

CalendarScreen uses a **plain Row** instead of AppHeaderBar (Tab 2):

**Why:** AppHeaderBar wraps buttons in `Hero > BottomBarGlassSurface >
RepaintBoundary > BackdropFilter`. In a Stack layout, BackdropFilter creates
a hard-edged gray compositing rectangle behind MonthContainer (the white pill).
The Row layout avoids this artifact entirely.

```dart
// calendar_screen.dart header — Row, no Hero, no BackdropFilter overlap
Row(
  children: [
    BottomBarGlassSurface(44, 44, circle) { back button }
    Expanded(Center(child: MonthContainer(...)))
    BottomBarGlassSurface(44, 44, circle) { search button }
  ],
)
```

Since there are no Hero widgets, there are no tags — no conflict possible.

---

## 8. Quick Diagnostic — "Multiple heroes" crash

If you see:
```
There are multiple heroes that share the same tag within a subtree.
```

Step-by-step fix:
1. Search for all AppHeaderBar usages: `grep -r "AppHeaderBar(" lib/`
2. Identify which files are in the `IndexedStack` (see `home_screen.dart` build()).
3. For each tab screen, check `leftHeroTag` and `rightHeroTag` values.
4. Find the duplicate tag — assign a unique tag to the offending screen.
5. Update the registry table in Section 5 of this skill.

---

## 9. Naming Convention

```
hero_<screen-identifier>_<side>

Side values:
  back     → left button that navigates back / to home tab
  profile  → left button showing user avatar
  action   → right button with a primary action (search, more, save)
  more     → right button with overflow menu / options

Examples:
  hero_settings_back       ← Settings tab back button
  hero_folders_action      ← hypothetical Folders right button
  hero_profile_header      ← legacy default, Home tab left (avatar)
  hero_more_options         ← legacy default, Home tab right (⋯ menu)
```
