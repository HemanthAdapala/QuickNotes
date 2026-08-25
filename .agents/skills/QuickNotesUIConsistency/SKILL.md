---
name: QuickNotes UI Consistency
description: Design system guidelines and UI consistency patterns for the QuickNotes project. Explains the structural layout for settings screens (White Rounded Sheets), destructive action confirmations (Action Sheets via showBlurredBottomSheet), and typography/shadow guidelines.
---

# QuickNotes UI Consistency Guidelines

This skill documents the evolving UI and design consistency standards for the QuickNotes project. Whenever you are adding new screens, widgets, or flows to QuickNotes, you **MUST** follow these guidelines to ensure the application maintains its polished, premium, and unified look.

This document should be treated as a living specification. As new UI patterns emerge, they should be added here.

## 1. The "Settings / Profile" Screen Structure (White Rounded Sheet)

Any screen that falls under the "Settings" or "Profile" category (e.g., Account Settings, Backup & Sync, Storage and Data, Vault) MUST follow a strict structural hierarchy.

Instead of rendering a list directly over a grey background, the main content area is wrapped in a "White Rounded Sheet" container that gives the illusion of a modal sheet pushed up over the background.

**Implementation Pattern:**
```dart
return Scaffold(
  backgroundColor: const Color(0xFFF2F2F7), // Grey background
  body: SafeArea(
    child: Column(
      children: [
        // 1. App Header Bar (with liquid glass and transparent background)
        Padding(
          padding: const EdgeInsets.fromLTRB(24.0, 12.0, 24.0, 0.0),
          child: AppHeaderBar(...),
        ),
        
        const SizedBox(height: 20.0), // Spacing

        // 2. Content Area (White Rounded Sheet)
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)), // Crucial for the "sheet" look
            ),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
               // Screen content goes here...
            ),
          ),
        ),
      ],
    ),
  ),
);
```

## 2. Action Confirmations (The "Bottom Sheet" Consistency)

Whenever a user initiates a destructive or significant action (e.g., "Clear Cache", "Delete Folder", "Compact Database"), the action **MUST NOT** execute instantly. 

Instead, prompt the user with a confirmation Bottom Sheet using the `showBlurredBottomSheet` function. Do not use standard centered `AlertDialog`s for these types of list-item actions unless explicitly requested.

**Implementation Pattern:**
```dart
import '../widgets/blurred_bottom_sheet.dart';

void _confirmDestructiveAction(BuildContext context, VoidCallback onConfirm) {
  showBlurredBottomSheet(
    context: context,
    child: Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Are you sure?", style: ...),
          // ... Buttons row with "Cancel" (Grey) and "Confirm" (Red/Blue depending on destructiveness)
        ],
      ),
    ),
  );
}
```

## 3. Typography & "The Invisible Editor"

- **Primary Font:** The app predominantly uses `GoogleFonts.inter`. Keep the editor feeling "invisible" by avoiding overly stylized fonts for basic text.
- **Offline Reliability:** If `GoogleFonts` throws an exception regarding missing assets offline, ensure `GoogleFonts.config.allowRuntimeFetching = true;` is set (usually in `main.dart`), or that the fonts are correctly bundled in the `/google_fonts` local directory.
- **Color Palette:** Avoid pure black (`#000000`). For dark text, use Ink (`Color(0xFF333333)` or `Color(0xFF1C1C1E)`).
- **Emojis:** Do not use emojis in system-generated placeholders like usernames (e.g., no "👋").

## 4. Drop Shadows

Drop shadows in QuickNotes are subtle, soft, and realistic. Avoid harsh, completely opaque black shadows.
- Standard subtle card shadow: `Color(0x0F000000)` with a blur radius of 10 and an offset of `Offset(0, 4)`.
- Heavier button/floating element shadow: `Color(0x3F000000)` or colored variants (like `Color(0x33007AFF)` for primary buttons) with a blur radius around 12 to 16.

## 5. Header Bars

Whenever possible, use the global `AppHeaderBar` widget (the "Liquid Glass" header). If you are implementing a new screen, always refer to `MasterChangelogDocumentationPolicy.md` regarding App Header Bar usage.
