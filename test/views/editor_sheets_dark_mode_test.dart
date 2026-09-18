import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/premium/premium.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/providers/settings_provider.dart';
import 'package:quick_notes/providers/tasks_provider.dart';
import 'package:quick_notes/views/screens/note_editor_screen.dart';
import 'package:quick_notes/views/widgets/category_selection_sheet.dart';
import 'package:quick_notes/views/widgets/export_dialog.dart';
import 'package:quick_notes/views/widgets/folder_selection_sheet.dart';

Note _createTestNote({
  required String id,
  String title = 'Test Note',
  String content = 'Test Content',
}) {
  return Note(
    id: id,
    title: title,
    content: content,
    createdAt: DateTime(2026, 1, 1, 10, 0),
    updatedAt: DateTime(2026, 1, 1, 12, 0),
    colorValue: 0xFFFFFF,
    tags: const [],
    attachments: const [],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  Widget buildTestWidget({
    required ThemeData theme,
    required Widget child,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PremiumEntitlementManager()),
        ProxyProvider<PremiumEntitlementManager, FeatureAccess>(
          update: (_, manager, __) => DefaultFeatureAccess(manager),
        ),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => NotesProvider()),
        ChangeNotifierProvider(create: (_) => TasksProvider()),
      ],
      child: MaterialApp(
        theme: theme,
        home: Scaffold(body: child),
      ),
    );
  }

  group('D6-D4 FolderSelectionSheet Dark Mode Contract Tests', () {
    testWidgets('FolderSelectionSheet styling in Dark Mode',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(
        theme: ThemeData(brightness: Brightness.dark),
        child: FolderSelectionSheet(
          currentFolderId: null, // Root selected
          onFolderSelected: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      // 1. Dark surface: #2C2C2C
      final sheetContainerFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final deco = w.decoration as BoxDecoration;
          return deco.color == const Color(0xFF2C2C2C);
        }
        return false;
      });
      expect(sheetContainerFinder, findsOneWidget);

      // 2. Muted Handle: #5A5A5A
      final handleFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final deco = w.decoration as BoxDecoration;
          return deco.color == const Color(0xFF5A5A5A);
        }
        return false;
      });
      expect(handleFinder, findsOneWidget);

      // 3. Title: White
      final titleText = tester.widget<Text>(find.text('Move to Folder'));
      expect(titleText.style?.color, Colors.white);

      // 4. Subtitle: #8E8E93
      final subtitleText =
          tester.widget<Text>(find.text('Choose where this note belongs'));
      expect(subtitleText.style?.color, const Color(0xFF8E8E93));

      // 5. Close control: #3A3A3C background + white icon
      final closeBtnContainerFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final deco = w.decoration as BoxDecoration;
          return deco.color == const Color(0xFF3A3A3C) &&
              deco.shape == BoxShape.circle;
        }
        return false;
      });
      expect(closeBtnContainerFinder, findsOneWidget);
      final closeIcon = tester.widget<Icon>(find.byIcon(Icons.close));
      expect(closeIcon.color, Colors.white);

      // 6. Selected folder item: #3A3A3C background, white text, #0088FF check
      final selectedItemContainerFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final deco = w.decoration as BoxDecoration;
          return deco.color == const Color(0xFF3A3A3C) &&
              deco.borderRadius == BorderRadius.circular(20);
        }
        return false;
      });
      expect(selectedItemContainerFinder, findsOneWidget);

      final checkIconFinder = find.byIcon(Icons.check);
      expect(checkIconFinder, findsOneWidget);
      final checkIcon = tester.widget<Icon>(checkIconFinder);
      expect(checkIcon.color, const Color(0xFF0088FF));

      // 7. New Folder footer: divider white @ 15%, white text and icon
      final footerDividerFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final deco = w.decoration as BoxDecoration;
          final border = deco.border;
          if (border != null &&
              border.top.color == Colors.white.withValues(alpha: 0.15)) {
            return true;
          }
        }
        return false;
      });
      expect(footerDividerFinder, findsOneWidget);

      final newFolderText = tester.widget<Text>(find.text('New Folder'));
      expect(newFolderText.style?.color, Colors.white);

      // 8. Create Folder Dialog: dark surface #3A3A3C, white text, #0088FF create action
      await tester.tap(find.text('New Folder'));
      await tester.pumpAndSettle();

      final alertDialogFinder = find.byType(AlertDialog);
      expect(alertDialogFinder, findsOneWidget);
      final alertDialog = tester.widget<AlertDialog>(alertDialogFinder);
      expect(alertDialog.backgroundColor, const Color(0xFF3A3A3C));

      final dialogTitle = tester.widget<Text>(find.descendant(
          of: find.byType(AlertDialog), matching: find.text('New Folder')));
      expect(dialogTitle.style?.color, Colors.white);

      final createBtn = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Create'));
      expect(createBtn.style?.backgroundColor?.resolve({}),
          const Color(0xFF0088FF));
      expect(createBtn.style?.foregroundColor?.resolve({}), Colors.white);

      final cancelText = tester.widget<Text>(find.descendant(
          of: find.widgetWithText(TextButton, 'Cancel'),
          matching: find.byType(Text)));
      expect(cancelText.style?.color, const Color(0xFF8E8E93));

      // Dismiss dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets(
        'FolderSelectionSheet styling in Light Mode preserves cream palette',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(
        theme: ThemeData.light(),
        child: FolderSelectionSheet(
          currentFolderId: null,
          onFolderSelected: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      // Light surface: #F2F2EE
      final sheetContainerFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final deco = w.decoration as BoxDecoration;
          return deco.color == const Color(0xFFF2F2EE);
        }
        return false;
      });
      expect(sheetContainerFinder, findsOneWidget);

      // Title: #333333
      final titleText = tester.widget<Text>(find.text('Move to Folder'));
      expect(titleText.style?.color, const Color(0xFF333333));

      // Close control: #EBE9D8
      final closeBtnContainerFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final deco = w.decoration as BoxDecoration;
          return deco.color == const Color(0xFFEBE9D8);
        }
        return false;
      });
      expect(closeBtnContainerFinder, findsOneWidget);

      // Selected item: #222222
      final selectedItemContainerFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final deco = w.decoration as BoxDecoration;
          return deco.color == const Color(0xFF222222);
        }
        return false;
      });
      expect(selectedItemContainerFinder, findsOneWidget);
    });
  });

  group('D6-D4 CategorySelectionSheet Dark Mode Contract Tests', () {
    testWidgets('CategorySelectionSheet styling & semantic colors in Dark Mode',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(
        theme: ThemeData(brightness: Brightness.dark),
        child: CategorySelectionSheet(
          currentCategory: 'Personal',
          onCategorySelected: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      // 9. Dark surface: #2C2C2C
      final sheetContainerFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final deco = w.decoration as BoxDecoration;
          return deco.color == const Color(0xFF2C2C2C);
        }
        return false;
      });
      expect(sheetContainerFinder, findsOneWidget);

      // Handle: #5A5A5A
      final handleFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final deco = w.decoration as BoxDecoration;
          return deco.color == const Color(0xFF5A5A5A);
        }
        return false;
      });
      expect(handleFinder, findsOneWidget);

      // 10. Title: White
      final titleText = tester.widget<Text>(find.text('Category'));
      expect(titleText.style?.color, Colors.white);

      // 11. Secondary text: #8E8E93
      final subtitleText = tester.widget<Text>(find.text('Organize this note'));
      expect(subtitleText.style?.color, const Color(0xFF8E8E93));

      // 12. Selected state: #3A3A3C surface, white text, #0088FF check
      final selectedCategoryFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final deco = w.decoration as BoxDecoration;
          return deco.color == const Color(0xFF3A3A3C) &&
              deco.borderRadius == BorderRadius.circular(20);
        }
        return false;
      });
      expect(selectedCategoryFinder, findsOneWidget);

      final checkIcon = tester.widget<Icon>(find.byIcon(Icons.check));
      expect(checkIcon.color, const Color(0xFF0088FF));

      // 13. Semantic Category Colors PRESERVED:
      // Personal -> 0xFF78C291
      final personalDotFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final deco = w.decoration as BoxDecoration;
          return deco.color == const Color(0xFF78C291) &&
              deco.shape == BoxShape.circle;
        }
        return false;
      });
      expect(personalDotFinder, findsOneWidget);

      // Work -> 0xFF4A90E2
      final workDotFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final deco = w.decoration as BoxDecoration;
          return deco.color == const Color(0xFF4A90E2) &&
              deco.shape == BoxShape.circle;
        }
        return false;
      });
      expect(workDotFinder, findsOneWidget);

      // Ideas -> 0xFFF5D44A
      final ideasDotFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final deco = w.decoration as BoxDecoration;
          return deco.color == const Color(0xFFF5D44A) &&
              deco.shape == BoxShape.circle;
        }
        return false;
      });
      expect(ideasDotFinder, findsOneWidget);

      // Study -> 0xFFA388E8
      final studyDotFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final deco = w.decoration as BoxDecoration;
          return deco.color == const Color(0xFFA388E8) &&
              deco.shape == BoxShape.circle;
        }
        return false;
      });
      expect(studyDotFinder, findsOneWidget);

      // Unselected item border: white @ 15%
      final unselectedBorderFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final deco = w.decoration as BoxDecoration;
          final border = deco.border;
          if (border != null &&
              border.top.color == Colors.white.withValues(alpha: 0.15)) {
            return true;
          }
        }
        return false;
      });
      expect(unselectedBorderFinder, findsWidgets);

      // Create Category Dialog: dark surface #3A3A3C, white title, #0088FF action
      await tester.tap(find.text('+ Create Category'));
      await tester.pumpAndSettle();

      final alertDialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(alertDialog.backgroundColor, const Color(0xFF3A3A3C));

      final dialogTitle = tester.widget<Text>(find.descendant(
          of: find.byType(AlertDialog), matching: find.text('New Category')));
      expect(dialogTitle.style?.color, Colors.white);

      final createBtn = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Create'));
      expect(createBtn.style?.backgroundColor?.resolve({}),
          const Color(0xFF0088FF));

      // Dismiss dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets(
        'CategorySelectionSheet styling in Light Mode preserves cream palette',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(
        theme: ThemeData.light(),
        child: CategorySelectionSheet(
          currentCategory: 'Personal',
          onCategorySelected: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      // Light surface: #F2F2EE
      final sheetContainerFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final deco = w.decoration as BoxDecoration;
          return deco.color == const Color(0xFFF2F2EE) &&
              deco.borderRadius ==
                  const BorderRadius.vertical(top: Radius.circular(20));
        }
        return false;
      });
      expect(sheetContainerFinder, findsOneWidget);

      // Selected category: #222222
      final selectedCategoryFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final deco = w.decoration as BoxDecoration;
          return deco.color == const Color(0xFF222222);
        }
        return false;
      });
      expect(selectedCategoryFinder, findsOneWidget);
    });
  });

  group('D6-D4 Gallery Bottom Sheet Dark Mode Tests', () {
    testWidgets('Gallery Bottom Sheet chrome in Dark Mode',
        (WidgetTester tester) async {
      final note = _createTestNote(id: 'gallery_test_note');

      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => PremiumEntitlementManager()),
          ProxyProvider<PremiumEntitlementManager, FeatureAccess>(
            update: (_, manager, __) => DefaultFeatureAccess(manager),
          ),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => NotesProvider()),
          ChangeNotifierProvider(create: (_) => TasksProvider()),
        ],
        child: MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: NoteEditorScreen(note: note),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      // Page 1 is already selected by default (initialPage: 1).
      // Tap the attachment/link icon to show the attachment subsection
      final linkIconFinder = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == 'RichTextFormattingPillIcon',
      );
      expect(linkIconFinder, findsWidgets);
      await tester.tap(linkIconFinder.last);
      await tester.pumpAndSettle();

      // Tap Attach Image (Icons.camera_alt_outlined) in the subsection
      final cameraIconFinder = find.byIcon(Icons.camera_alt_outlined);
      expect(cameraIconFinder, findsOneWidget);
      await tester.tap(cameraIconFinder);
      await tester.pumpAndSettle();

      // 14. Dark surface: #2C2C2C (modal bottom sheet background)
      final bottomSheetFinder = find.byType(BottomSheet);
      expect(bottomSheetFinder, findsOneWidget);
      final bottomSheet = tester.widget<BottomSheet>(bottomSheetFinder);
      expect(bottomSheet.backgroundColor, const Color(0xFF2C2C2C));

      // Handle: #5A5A5A
      final handleFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final deco = w.decoration as BoxDecoration;
          return deco.color == const Color(0xFF5A5A5A);
        }
        return false;
      });
      expect(handleFinder, findsOneWidget);

      // 15. Primary text: White
      final insertPhotoText = tester.widget<Text>(find.text('Insert Photo'));
      expect(insertPhotoText.style?.color, Colors.white);

      // 16. Secondary text: #8E8E93 (Camera label)
      final cameraLabel = tester.widget<Text>(find.text('Camera'));
      expect(cameraLabel.style?.color, const Color(0xFF8E8E93));

      // 17. Elevated option controls: #3A3A3C
      final elevatedControlsFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final deco = w.decoration as BoxDecoration;
          return deco.color == const Color(0xFF3A3A3C);
        }
        return false;
      });
      expect(elevatedControlsFinder, findsWidgets);

      // 18. Dividers/borders: white @ 15%
      final borderFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final deco = w.decoration as BoxDecoration;
          final border = deco.border;
          if (border != null &&
              border.top.color == Colors.white.withValues(alpha: 0.15)) {
            return true;
          }
        }
        return false;
      });
      expect(borderFinder, findsWidgets);

      // Dismiss sheet
      Navigator.pop(tester.element(find.text('Insert Photo')));
      await tester.pumpAndSettle();
    });

    testWidgets(
        'Gallery Bottom Sheet chrome in Light Mode preserves light styling',
        (WidgetTester tester) async {
      final note = _createTestNote(id: 'gallery_light_test_note');

      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => PremiumEntitlementManager()),
          ProxyProvider<PremiumEntitlementManager, FeatureAccess>(
            update: (_, manager, __) => DefaultFeatureAccess(manager),
          ),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => NotesProvider()),
          ChangeNotifierProvider(create: (_) => TasksProvider()),
        ],
        child: MaterialApp(
          theme: ThemeData(brightness: Brightness.light),
          home: NoteEditorScreen(note: note),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      // Page 1 is already selected by default (initialPage: 1).
      // Tap the attachment/link icon to show the attachment subsection
      final linkIconFinder = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == 'RichTextFormattingPillIcon',
      );
      expect(linkIconFinder, findsWidgets);
      await tester.tap(linkIconFinder.last);
      await tester.pumpAndSettle();

      // Tap Attach Image (Icons.camera_alt_outlined) in the subsection
      final cameraIconFinder = find.byIcon(Icons.camera_alt_outlined);
      expect(cameraIconFinder, findsOneWidget);
      await tester.tap(cameraIconFinder);
      await tester.pumpAndSettle();

      // Light sheet: background is null (falls back to theme default light)
      final bottomSheetFinder = find.byType(BottomSheet);
      expect(bottomSheetFinder, findsOneWidget);
      final bottomSheet = tester.widget<BottomSheet>(bottomSheetFinder);
      expect(bottomSheet.backgroundColor, isNot(const Color(0xFF2C2C2C)));

      // Handle: black with 20% alpha (Light Mode)
      final handleFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final deco = w.decoration as BoxDecoration;
          return deco.color == Colors.black.withValues(alpha: 0.2);
        }
        return false;
      });
      expect(handleFinder, findsOneWidget);

      // Dismiss sheet
      Navigator.pop(tester.element(find.text('Insert Photo')));
      await tester.pumpAndSettle();
    });
  });

  group('D6-D4 ExportDialog Dark Mode Verification Tests', () {
    testWidgets('ExportDialog renders theme-aware Dark Mode correctly',
        (WidgetTester tester) async {
      final note = _createTestNote(id: 'export_test_note');

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: const ColorScheme.dark(
            surface: Color(0xFF1E1C2E),
            onSurface: Color(0xFFFAF8F5),
            onSurfaceVariant: Color(0xFF8E8E93),
            primary: Color(0xFF818CF8),
          ),
        ),
        home: Scaffold(
          body: ExportDialog(note: note),
        ),
      ));
      await tester.pumpAndSettle();

      // 21. Dark dialog surface
      final dialogFinder = find.byType(Dialog);
      expect(dialogFinder, findsOneWidget);
      final dialog = tester.widget<Dialog>(dialogFinder);
      expect(dialog.backgroundColor, const Color(0xFF1E1C2E));

      // 22. White / light primary text
      final exportTitle = tester.widget<Text>(find.text('Export & Share'));
      expect(exportTitle.style?.color, const Color(0xFFFAF8F5));

      // 23. Muted secondary text
      final formatLabel = tester.widget<Text>(find.text('Format'));
      expect(formatLabel.style?.color, const Color(0xFF8E8E93));

      // 24. Action buttons rendered
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Export'), findsOneWidget);
    });
  });
}
