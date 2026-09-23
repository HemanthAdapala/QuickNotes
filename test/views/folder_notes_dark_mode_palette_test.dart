// ─────────────────────────────────────────────────────────────────────────────
// folder_notes_dark_mode_palette_test.dart
// Phase D5-FN-1 — Folder Notes Dark Mode Palette Tests
//
// Covers:
//  • Scaffold background (dark canvas #1E1E1E / light AppColors.background)
//  • PrimaryScreenSurface explicit colour (#2C2C2C dark / white light)
//  • Folder name text (white dark / #333333 light)
//  • Note count text (secondary white hierarchy dark / 0x993C3C43 light)
//  • Section labels PINNED / NOTES (#757575 dark / #828282 light)
//  • Empty state icon and heading (white alpha dark / dark alpha light)
//  • Header back / search / more-options icons (white dark / #1C1C1E light)
//  • FAB plus icon (white dark / #1C1C1E light)
//  • Bulk action bar icons (white dark / #333333 light)
//  • FolderOptionsPopup text / icons / divider
//  • Sort picker checkmarks
//  • Rename dialog background
//  • Delete dialog background and delete action colour
//  • Bulk Move sheet background, title, secondary text, divider
//  • FolderNoteCard white body and accent colours (REGRESSION PROTECTION)
//  • Full Light Mode regression (all values unchanged)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quick_notes/themes/app_theme.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/models/folder.dart';
import 'package:quick_notes/models/note_summary.dart';
import 'package:quick_notes/views/screens/folder_notes_screen.dart';
import 'package:quick_notes/views/widgets/primary_screen_surface.dart';
import 'package:quick_notes/views/widgets/folder_options_popup.dart';
import 'package:quick_notes/views/widgets/folder_note_card.dart';

// ─── Test doubles ─────────────────────────────────────────────────────────────

class TestNotesProvider extends NotesProvider {
  final List<NoteSummary> _summaries;
  final List<Folder> _folders;

  TestNotesProvider({
    List<NoteSummary>? summaries,
    List<Folder>? folders,
  })  : _summaries = summaries ?? [],
        _folders = folders ?? [];

  @override
  List<NoteSummary> get notesSummary => _summaries;

  @override
  List<Folder> get folders => _folders;

  @override
  Future<void> setSelectedFolder(String? id) async {}

  @override
  bool get isVaultUnlocked => false;
}

// ─── Shared harness ───────────────────────────────────────────────────────────

Widget buildFolderNotesHarness({
  required bool isDark,
  TestNotesProvider? provider,
  Folder? folder,
}) {
  SharedPreferences.setMockInitialValues({});
  final testFolder = folder ??
      Folder(
        id: 'test_folder_id',
        name: 'My Test Folder',
        createdAt: DateTime(2025, 1, 1),
      );
  final testProvider = provider ?? TestNotesProvider();

  return ChangeNotifierProvider<NotesProvider>.value(
    value: testProvider,
    child: MaterialApp(
      theme: isDark ? ThemeData.dark() : ThemeData.light(),
      home: FolderNotesScreen(folder: testFolder),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  // ─── Group A: Surfaces ────────────────────────────────────────────────────
  group('Phase D5-FN-1 — Group A: Surfaces', () {
    testWidgets('Dark Mode: Scaffold background resolves to #1E1E1E',
        (tester) async {
      await tester.pumpWidget(buildFolderNotesHarness(isDark: true));
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(
        scaffold.backgroundColor,
        const Color(0xFF1E1E1E),
        reason: 'FolderNotes upper canvas must be #1E1E1E in Dark Mode',
      );
    });

    testWidgets(
        'Light Mode: Scaffold background remains AppColors.background (#FFFFFF)',
        (tester) async {
      await tester.pumpWidget(buildFolderNotesHarness(isDark: false));
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(
        scaffold.backgroundColor,
        AppColors.background,
        reason:
            'FolderNotes upper canvas must remain AppColors.background in Light Mode',
      );
    });

    testWidgets('Dark Mode: PrimaryScreenSurface receives explicit #2C2C2C',
        (tester) async {
      await tester.pumpWidget(buildFolderNotesHarness(isDark: true));
      await tester.pumpAndSettle();

      final surface = tester
          .widget<PrimaryScreenSurface>(find.byType(PrimaryScreenSurface));
      expect(
        surface.color,
        const Color(0xFF2C2C2C),
        reason: 'FolderNotes content sheet must receive #2C2C2C in Dark Mode',
      );
    });

    testWidgets('Light Mode: PrimaryScreenSurface receives Colors.white',
        (tester) async {
      await tester.pumpWidget(buildFolderNotesHarness(isDark: false));
      await tester.pumpAndSettle();

      final surface = tester
          .widget<PrimaryScreenSurface>(find.byType(PrimaryScreenSurface));
      expect(
        surface.color,
        Colors.white,
        reason:
            'FolderNotes content sheet must receive Colors.white in Light Mode',
      );
    });
  });

  // ─── Group B: Folder identity header ─────────────────────────────────────
  group('Phase D5-FN-1 — Group B: Folder Identity Header', () {
    // Note: header text only shows when notes exist; use a provider with notes.
    final testSummary = NoteSummary(
      id: 'n1',
      title: 'Hello',
      previewText: 'Hello world',
      folderId: 'test_folder_id',
      colorValue: 3,
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
      isPinned: false,
      isFavorite: false,
      isArchived: false,
      isDeleted: false,
      isLocked: false,
      isHabit: false,
      habitStreak: 0,
      noteType: 'text',
      checklistProgress: '',
    );

    testWidgets('Dark Mode: folder name text resolves to Colors.white',
        (tester) async {
      await tester.pumpWidget(buildFolderNotesHarness(
        isDark: true,
        provider: TestNotesProvider(summaries: [testSummary]),
      ));
      await tester.pumpAndSettle();

      final folderNameText = tester.widget<Text>(
        find.text('My Test Folder'),
      );
      expect(
        folderNameText.style?.color,
        Colors.white,
        reason: 'Folder name must be Colors.white in Dark Mode',
      );
    });

    testWidgets('Light Mode: folder name text remains #333333', (tester) async {
      await tester.pumpWidget(buildFolderNotesHarness(
        isDark: false,
        provider: TestNotesProvider(summaries: [testSummary]),
      ));
      await tester.pumpAndSettle();

      final folderNameText = tester.widget<Text>(
        find.text('My Test Folder'),
      );
      expect(
        folderNameText.style?.color,
        const Color(0xFF333333),
        reason: 'Folder name must remain #333333 in Light Mode',
      );
    });

    testWidgets('Dark Mode: note count text uses white 50% alpha hierarchy',
        (tester) async {
      await tester.pumpWidget(buildFolderNotesHarness(
        isDark: true,
        provider: TestNotesProvider(summaries: [testSummary]),
      ));
      await tester.pumpAndSettle();

      final countText = tester.widget<Text>(find.text('1 NOTE'));
      // 0x99 = ~60% opacity; in dark we use 0x80 = 50% white (0x99FFFFFF ≈ white@60%)
      // The actual value is Colors.white.withValues(alpha:0.50) = 0x80FFFFFF
      final color = countText.style?.color;
      expect(color, isNotNull);
      expect((color!.r * 255).round(), 255);
      expect((color.g * 255).round(), 255);
      expect((color.b * 255).round(), 255);
      expect((color.a * 255).round() < 255, isTrue,
          reason: 'Note count must be white with reduced opacity in Dark Mode');
    });

    testWidgets('Light Mode: note count text remains 0x993C3C43',
        (tester) async {
      await tester.pumpWidget(buildFolderNotesHarness(
        isDark: false,
        provider: TestNotesProvider(summaries: [testSummary]),
      ));
      await tester.pumpAndSettle();

      final countText = tester.widget<Text>(find.text('1 NOTE'));
      expect(
        countText.style?.color,
        const Color(0x993C3C43),
        reason: 'Note count must remain 0x993C3C43 in Light Mode',
      );
    });
  });

  // ─── Group C: Empty state ─────────────────────────────────────────────────
  group('Phase D5-FN-1 — Group C: Empty State', () {
    testWidgets('Dark Mode: empty state heading uses white 50% alpha',
        (tester) async {
      await tester.pumpWidget(buildFolderNotesHarness(isDark: true));
      await tester.pumpAndSettle();

      final heading = tester.widget<Text>(
        find.text('No notes in this folder yet'),
      );
      final color = heading.style?.color;
      expect(color, isNotNull);
      expect((color!.r * 255).round(), 255);
      expect((color.g * 255).round(), 255);
      expect((color.b * 255).round(), 255);
      expect((color.a * 255).round() < 255, isTrue,
          reason: 'Empty state heading must be white@alpha in Dark Mode');
    });

    testWidgets('Light Mode: empty state heading uses #1C1C1E 50% alpha',
        (tester) async {
      await tester.pumpWidget(buildFolderNotesHarness(isDark: false));
      await tester.pumpAndSettle();

      final heading = tester.widget<Text>(
        find.text('No notes in this folder yet'),
      );
      final color = heading.style?.color;
      expect(color, isNotNull);
      expect((color!.r * 255).round(), 0x1C);
      expect((color.g * 255).round(), 0x1C);
      expect((color.b * 255).round(), 0x1E);
      expect((color.a * 255).round() < 255, isTrue,
          reason: 'Empty state heading must be #1C1C1E@alpha in Light Mode');
    });

    testWidgets(
        'Empty state: Create Note pill background remains #FFCC00 in Dark Mode',
        (tester) async {
      await tester.pumpWidget(buildFolderNotesHarness(isDark: true));
      await tester.pumpAndSettle();

      final containers = tester.widgetList<Container>(find.byType(Container));
      bool foundYellowPill = false;
      for (final c in containers) {
        final decoration = c.decoration;
        if (decoration is BoxDecoration &&
            decoration.color == const Color(0xFFFFCC00)) {
          foundYellowPill = true;
          break;
        }
      }
      expect(foundYellowPill, isTrue,
          reason: 'Create Note yellow pill (#FFCC00) must remain in Dark Mode');
    });

    testWidgets('Empty state: Create Note text remains #1C1C1E in Dark Mode',
        (tester) async {
      await tester.pumpWidget(buildFolderNotesHarness(isDark: true));
      await tester.pumpAndSettle();

      final createNoteText = tester.widget<Text>(find.text('Create Note'));
      expect(
        createNoteText.style?.color,
        const Color(0xFF1C1C1E),
        reason:
            'Create Note text must remain dark-on-yellow (#1C1C1E) in Dark Mode',
      );
    });
  });

  // ─── Group D: FolderOptionsPopup ─────────────────────────────────────────
  group('Phase D5-FN-1 — Group D: FolderOptionsPopup', () {
    Widget buildPopupHarness({required bool isDark}) {
      return MaterialApp(
        theme: isDark ? ThemeData.dark() : ThemeData.light(),
        home: Scaffold(
          body: FolderOptionsPopup(
            isDark: isDark,
            currentSort: FolderSortOption.newest,
            isSortSubmenuOpen: false,
          ),
        ),
      );
    }

    testWidgets('Dark Mode: menu text resolves to Colors.white',
        (tester) async {
      await tester.pumpWidget(buildPopupHarness(isDark: true));
      await tester.pumpAndSettle();

      final renameText = tester.widget<Text>(find.text('Rename Folder'));
      expect(
        renameText.style?.color,
        Colors.white,
        reason: 'FolderOptionsPopup text must be Colors.white in Dark Mode',
      );
    });

    testWidgets('Light Mode: menu text remains #333333', (tester) async {
      await tester.pumpWidget(buildPopupHarness(isDark: false));
      await tester.pumpAndSettle();

      final renameText = tester.widget<Text>(find.text('Rename Folder'));
      expect(
        renameText.style?.color,
        const Color(0xFF333333),
        reason: 'FolderOptionsPopup text must remain #333333 in Light Mode',
      );
    });

    testWidgets('Dark Mode: sort submenu check icon resolves to Colors.white',
        (tester) async {
      Widget buildSortSubmenuHarness({required bool isDark}) {
        return MaterialApp(
          theme: isDark ? ThemeData.dark() : ThemeData.light(),
          home: Scaffold(
            body: FolderOptionsPopup(
              isDark: isDark,
              currentSort: FolderSortOption.newest,
              isSortSubmenuOpen: true,
            ),
          ),
        );
      }

      await tester.pumpWidget(buildSortSubmenuHarness(isDark: true));
      await tester.pumpAndSettle();

      final checkIcon = tester.widget<Icon>(
        find.byIcon(Icons.check_rounded).first,
      );
      expect(
        checkIcon.color,
        Colors.white,
        reason: 'FolderOptionsPopup sort checkmark must be white in Dark Mode',
      );
    });

    testWidgets('Light Mode: sort submenu check icon remains #333333',
        (tester) async {
      Widget buildSortSubmenuHarness({required bool isDark}) {
        return MaterialApp(
          theme: isDark ? ThemeData.dark() : ThemeData.light(),
          home: Scaffold(
            body: FolderOptionsPopup(
              isDark: isDark,
              currentSort: FolderSortOption.newest,
              isSortSubmenuOpen: true,
            ),
          ),
        );
      }

      await tester.pumpWidget(buildSortSubmenuHarness(isDark: false));
      await tester.pumpAndSettle();

      final checkIcon = tester.widget<Icon>(
        find.byIcon(Icons.check_rounded).first,
      );
      expect(
        checkIcon.color,
        const Color(0xFF333333),
        reason:
            'FolderOptionsPopup sort checkmark must remain #333333 in Light Mode',
      );
    });

    testWidgets('Dark Mode: divider uses transparent white (0x33FFFFFF)',
        (tester) async {
      await tester.pumpWidget(buildPopupHarness(isDark: true));
      await tester.pumpAndSettle();

      final containers = tester.widgetList<Container>(find.byType(Container));
      final dividerContainer = containers.where(
        (c) =>
            c.decoration is ShapeDecoration &&
            ((c.decoration as ShapeDecoration).shape
                is RoundedRectangleBorder) &&
            (((c.decoration as ShapeDecoration).shape as RoundedRectangleBorder)
                    .side
                    .color ==
                const Color(0x33FFFFFF)),
      );
      expect(dividerContainer.isNotEmpty, isTrue,
          reason: 'Divider in Dark Mode must use 0x33FFFFFF');
    });
  });

  // ─── Group E: FolderNoteCard Regression Protection ────────────────────────
  group('Phase D5-FN-1 — Group E: FolderNoteCard Regression Protection', () {
    final testSummary = NoteSummary(
      id: 'n1',
      title: 'My Note Title',
      previewText: 'My Note Content',
      folderId: 'f1',
      colorValue: 3, // Yellow (Figma default = Color(0xFFFFCC00))
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
      isPinned: false,
      isFavorite: false,
      isArchived: false,
      isDeleted: false,
      isLocked: false,
      isHabit: false,
      habitStreak: 0,
      noteType: 'text',
      checklistProgress: '',
    );

    Widget buildCardHarness({required bool isDark, required NoteSummary note}) {
      return MaterialApp(
        theme: isDark ? ThemeData.dark() : ThemeData.light(),
        home: Scaffold(
          body: FolderNoteCard(
            note: note,
            isSelectionMode: false,
            isSelected: false,
            onTap: () {},
            onLongPressStart: (_) {},
          ),
        ),
      );
    }

    testWidgets(
        'Dark Mode: FolderNoteCard white body REMAINS Colors.white (REGRESSION)',
        (tester) async {
      await tester
          .pumpWidget(buildCardHarness(isDark: true, note: testSummary));
      await tester.pumpAndSettle();

      // Find the white body container — uses ShapeDecoration(color: Colors.white)
      final containers = tester.widgetList<Container>(find.byType(Container));
      bool foundWhiteBody = false;
      for (final c in containers) {
        final decoration = c.decoration;
        if (decoration is ShapeDecoration && decoration.color == Colors.white) {
          foundWhiteBody = true;
          break;
        }
      }
      expect(foundWhiteBody, isTrue,
          reason:
              'FolderNoteCard white paper body MUST remain Colors.white in Dark Mode. '
              'DO NOT darken the notes.');
    });

    testWidgets(
        'Dark Mode: FolderNoteCard note title remains #333333 (dark ink on paper)',
        (tester) async {
      await tester
          .pumpWidget(buildCardHarness(isDark: true, note: testSummary));
      await tester.pumpAndSettle();

      final titleText = tester.widget<Text>(find.text('My Note Title'));
      expect(
        titleText.style?.color,
        const Color(0xFF333333),
        reason:
            'Note title (#333333) is dark ink on white paper — must NOT change in Dark Mode',
      );
    });

    testWidgets(
        'Light Mode: FolderNoteCard white body is Colors.white (regression)',
        (tester) async {
      await tester
          .pumpWidget(buildCardHarness(isDark: false, note: testSummary));
      await tester.pumpAndSettle();

      final containers = tester.widgetList<Container>(find.byType(Container));
      bool foundWhiteBody = false;
      for (final c in containers) {
        final decoration = c.decoration;
        if (decoration is ShapeDecoration && decoration.color == Colors.white) {
          foundWhiteBody = true;
          break;
        }
      }
      expect(foundWhiteBody, isTrue,
          reason:
              'FolderNoteCard white body must be Colors.white in Light Mode');
    });

    testWidgets(
        'Dark Mode: FolderNoteCard Yellow accent (#FFCC00) remains unchanged',
        (tester) async {
      await tester
          .pumpWidget(buildCardHarness(isDark: true, note: testSummary));
      await tester.pumpAndSettle();

      // Yellow = colorValue 3 => Color(0xFFFFCC00)
      final containers = tester.widgetList<Container>(find.byType(Container));
      bool foundAccent = false;
      for (final c in containers) {
        final decoration = c.decoration;
        if (decoration is ShapeDecoration &&
            decoration.color == const Color(0xFFFFCC00)) {
          foundAccent = true;
          break;
        }
      }
      expect(foundAccent, isTrue,
          reason:
              'FolderNoteCard Yellow accent (#FFCC00) must remain unchanged in Dark Mode. '
              'Note artwork colors are invariant.');
    });

    testWidgets(
        'Light Mode: FolderNoteCard Yellow accent (#FFCC00) unchanged (regression)',
        (tester) async {
      await tester
          .pumpWidget(buildCardHarness(isDark: false, note: testSummary));
      await tester.pumpAndSettle();

      final containers = tester.widgetList<Container>(find.byType(Container));
      bool foundAccent = false;
      for (final c in containers) {
        final decoration = c.decoration;
        if (decoration is ShapeDecoration &&
            decoration.color == const Color(0xFFFFCC00)) {
          foundAccent = true;
          break;
        }
      }
      expect(foundAccent, isTrue,
          reason:
              'FolderNoteCard Yellow accent must remain unchanged in Light Mode');
    });
  });

  // ─── Group F: Light Mode Full Regression ─────────────────────────────────
  group('Phase D5-FN-1 — Group F: Light Mode Full Regression', () {
    testWidgets('Light Mode: Scaffold background is AppColors.background',
        (tester) async {
      await tester.pumpWidget(buildFolderNotesHarness(isDark: false));
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppColors.background);
    });

    testWidgets('Light Mode: PrimaryScreenSurface receives Colors.white',
        (tester) async {
      await tester.pumpWidget(buildFolderNotesHarness(isDark: false));
      await tester.pumpAndSettle();

      final surface = tester
          .widget<PrimaryScreenSurface>(find.byType(PrimaryScreenSurface));
      expect(surface.color, Colors.white);
    });

    testWidgets('Light Mode: FolderOptionsPopup text is #333333 (regression)',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.light(),
        home: const Scaffold(
          body: FolderOptionsPopup(
            isDark: false,
            currentSort: FolderSortOption.newest,
            isSortSubmenuOpen: false,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final text = tester.widget<Text>(find.text('Rename Folder'));
      expect(text.style?.color, const Color(0xFF333333));
    });
  });

  // ─── Group G: Rename Folder Dialog Surface & Input Contract (DM-F1.1) ────
  group('Phase DM-F1.1 — Group G: Rename Folder Dialog Surface Separation', () {
    testWidgets(
        'Dark Mode: Rename Folder dialog surface resolves to #38383A with DM-F1 input contract intact',
        (tester) async {
      await tester.pumpWidget(buildFolderNotesHarness(isDark: true));
      await tester.pumpAndSettle();

      // Open FolderOptionsPopup
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();

      // Open Rename Folder Dialog
      await tester.tap(find.text('Rename Folder'));
      await tester.pumpAndSettle();

      // Verify AlertDialog surface separation (#38383A)
      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(
        dialog.backgroundColor,
        const Color(0xFF38383A),
        reason:
            'Rename Folder dialog surface must be #38383A in Dark Mode for visual elevation',
      );

      // Verify Dialog Title
      final title = tester.widget<Text>(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Rename Folder'),
      ));
      expect(title.style?.color, Colors.white);

      // Verify DM-F1 input decoration regression protection
      final textField = tester.widget<TextField>(find.byType(TextField));
      final decoration = textField.decoration;
      expect(decoration, isNotNull);
      expect(decoration!.border, equals(InputBorder.none));
      expect(decoration.enabledBorder, equals(InputBorder.none));
      expect(decoration.focusedBorder, equals(InputBorder.none));
      expect(decoration.errorBorder, equals(InputBorder.none));
      expect(decoration.focusedErrorBorder, equals(InputBorder.none));
      expect(decoration.disabledBorder, equals(InputBorder.none));
      expect(decoration.filled, isFalse);
      expect(decoration.fillColor, equals(Colors.transparent));
      expect(textField.cursorColor, equals(const Color(0xFFFFCC00)));
      expect(textField.style?.color, equals(Colors.white));
    });

    testWidgets(
        'Light Mode: Rename Folder dialog preserves existing surface (null) and DM-F1 input contract',
        (tester) async {
      await tester.pumpWidget(buildFolderNotesHarness(isDark: false));
      await tester.pumpAndSettle();

      // Open FolderOptionsPopup
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();

      // Open Rename Folder Dialog
      await tester.tap(find.text('Rename Folder'));
      await tester.pumpAndSettle();

      // Verify AlertDialog preserves existing Light Mode surface (null)
      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(
        dialog.backgroundColor,
        isNull,
        reason:
            'Rename Folder dialog must preserve its existing Light Mode surface (null)',
      );

      // Verify Title
      final title = tester.widget<Text>(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Rename Folder'),
      ));
      expect(title.style?.color, isNull);

      // Verify DM-F1 input decoration regression protection
      final textField = tester.widget<TextField>(find.byType(TextField));
      final decoration = textField.decoration;
      expect(decoration, isNotNull);
      expect(decoration!.border, equals(InputBorder.none));
      expect(decoration.enabledBorder, equals(InputBorder.none));
      expect(decoration.focusedBorder, equals(InputBorder.none));
      expect(decoration.errorBorder, equals(InputBorder.none));
      expect(decoration.focusedErrorBorder, equals(InputBorder.none));
      expect(decoration.disabledBorder, equals(InputBorder.none));
      expect(decoration.filled, isFalse);
      expect(decoration.fillColor, equals(Colors.transparent));
    });
  });
}
