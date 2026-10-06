import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quick_notes/themes/quick_notes_theme.dart';
import 'package:quick_notes/views/widgets/app_bottom_navigation_bar.dart';
import 'package:quick_notes/views/widgets/app_header_bar.dart';
import 'package:quick_notes/views/widgets/note_editor_options_popup.dart';
import 'package:quick_notes/views/widgets/tactile_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('Note Editor More Options Glass Integration Tests', () {
    testWidgets(
        'AppHeaderBar hosts NoteEditorOptionsPopup inside BottomBarGlassSurface with BackdropFilter in Dark Mode',
        (WidgetTester tester) async {
      bool pinTapped = false;
      bool deleteTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: QuickNotesTheme.darkTheme,
          home: Scaffold(
            backgroundColor: const Color(0xFF1E1E1E),
            body: Stack(
              children: [
                Positioned(
                  top: 12.0,
                  left: 24.0,
                  right: 24.0,
                  child: AppHeaderBar(
                    onCollapse: () {},
                    onLeftTap: () {},
                    leftChild: const Icon(Icons.arrow_back),
                    isExpanded: true,
                    expandedWidth: 192.0,
                    expandedHeight: 250.0,
                    expandedChild: NoteEditorOptionsPopup(
                      isPinned: false,
                      isFavorite: false,
                      onTogglePin: () => pinTapped = true,
                      onToggleFavorite: () {},
                      onFindInNote: () {},
                      onExportAndShare: () {},
                      onDeleteNote: () => deleteTapped = true,
                    ),
                    rightChild: TactileButton(
                      onTap: () {},
                      child: const Icon(Icons.more_horiz),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // 1. Verify NoteEditorOptionsPopup is mounted
      final popupFinder = find.byType(NoteEditorOptionsPopup);
      expect(popupFinder, findsOneWidget);

      // 2. Verify NoteEditorOptionsPopup is a descendant of BottomBarGlassSurface
      final glassSurfaceFinder = find.ancestor(
        of: popupFinder,
        matching: find.byType(BottomBarGlassSurface),
      );
      expect(glassSurfaceFinder, findsWidgets);

      // 3. Verify BackdropFilter is present in the hierarchy providing blur
      final backdropFinder = find.descendant(
        of: glassSurfaceFinder.first,
        matching: find.byType(BackdropFilter),
      );
      expect(backdropFinder, findsOneWidget);

      final backdrop = tester.widget<BackdropFilter>(backdropFinder);
      expect(backdrop.filter, isNotNull);

      // 4. Verify no opaque #2C2C2C layer is between BottomBarGlassSurface and NoteEditorOptionsPopup content
      final containersInPopup = tester.widgetList<Container>(
        find.descendant(of: popupFinder, matching: find.byType(Container)),
      );
      for (final container in containersInPopup) {
        expect(container.color, isNot(const Color(0xFF2C2C2C)));
        if (container.decoration is BoxDecoration) {
          final deco = container.decoration as BoxDecoration;
          expect(deco.color, isNot(const Color(0xFF2C2C2C)));
        }
      }

      // 5. Verify all 5 actions are visible and interactive
      expect(find.text('Pin Note'), findsOneWidget);
      expect(find.text('Add Favorite'), findsOneWidget);
      expect(find.text('Find in Note'), findsOneWidget);
      expect(find.text('Export & Share'), findsOneWidget);
      expect(find.text('Delete Note'), findsOneWidget);

      // Tap Pin Note
      await tester.tap(find.text('Pin Note'));
      await tester.pump();
      expect(pinTapped, isTrue);

      // Tap Delete Note
      await tester.tap(find.text('Delete Note'));
      await tester.pump();
      expect(deleteTapped, isTrue);
    });

    testWidgets(
        'NoteEditorScreen complete 192x44 pill morphs into 192x250 options popup and preserves individual controls in collapsed state',
        (WidgetTester tester) async {
      bool undoTapped = false;
      bool redoTapped = false;
      bool folderTapped = false;
      bool isOptionsOpen = false;

      final fiveElementRow = Row(
        children: [
          Expanded(
            child: TactileButton(
              onTap: () => undoTapped = true,
              child: const Icon(Icons.undo_rounded, key: ValueKey('test_undo')),
            ),
          ),
          Expanded(
            child: TactileButton(
              onTap: () => redoTapped = true,
              child: const Icon(Icons.redo_rounded, key: ValueKey('test_redo')),
            ),
          ),
          Container(width: 1.0, height: 18.0, color: Colors.white24),
          Expanded(
            child: TactileButton(
              onTap: () => folderTapped = true,
              child: const Icon(Icons.folder_open, key: ValueKey('test_folder')),
            ),
          ),
          Expanded(
            child: TactileButton(
              onTap: () {
                isOptionsOpen = !isOptionsOpen;
              },
              child: const Icon(Icons.more_horiz_rounded, key: ValueKey('test_options')),
            ),
          ),
        ],
      );

      Widget buildHarness({required bool expanded}) {
        return MaterialApp(
          theme: QuickNotesTheme.darkTheme,
          home: Scaffold(
            backgroundColor: const Color(0xFF1E1E1E),
            body: Stack(
              children: [
                Positioned(
                  top: 12.0,
                  left: 24.0,
                  right: 24.0,
                  child: AppHeaderBar(
                    onCollapse: () => isOptionsOpen = false,
                    leftChild: const Icon(Icons.arrow_back),
                    isExpanded: expanded,
                    rightWidth: 192.0,
                    expandedWidth: 192.0,
                    expandedHeight: 250.0,
                    expandedChild: NoteEditorOptionsPopup(
                      isPinned: false,
                      isFavorite: false,
                      onTogglePin: () {},
                      onToggleFavorite: () {},
                      onFindInNote: () {},
                      onExportAndShare: () {},
                      onDeleteNote: () {},
                    ),
                    rightChild: fiveElementRow,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      await tester.pumpWidget(buildHarness(expanded: false));
      await tester.pumpAndSettle();

      // 1. Verify collapsed pill is 192x44
      final glassFinder = find.byType(BottomBarGlassSurface);
      expect(glassFinder, findsWidgets);
      final trailingGlass = glassFinder.last;
      final Size collapsedSize = tester.getSize(trailingGlass);
      expect(collapsedSize.width, closeTo(192.0, 0.5));
      expect(collapsedSize.height, closeTo(44.0, 0.5));

      // 2. Verify independent controls function in collapsed state without opening popup
      await tester.tap(find.byKey(const ValueKey('test_undo')));
      await tester.pump();
      expect(undoTapped, isTrue);
      expect(isOptionsOpen, isFalse);

      await tester.tap(find.byKey(const ValueKey('test_redo')));
      await tester.pump();
      expect(redoTapped, isTrue);
      expect(isOptionsOpen, isFalse);

      await tester.tap(find.byKey(const ValueKey('test_folder')));
      await tester.pump();
      expect(folderTapped, isTrue);
      expect(isOptionsOpen, isFalse);

      // 3. Tap 3-dots trigger to morph the entire pill
      await tester.tap(find.byKey(const ValueKey('test_options')));
      await tester.pump();
      expect(isOptionsOpen, isTrue);

      // Rebuild with expanded = true
      await tester.pumpWidget(buildHarness(expanded: true));

      // Step mid-flight: observe vertical expansion while width stays 192
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      final Size midSize = tester.getSize(find.byType(BottomBarGlassSurface).last);
      expect(midSize.width, closeTo(192.0, 0.5));
      expect(midSize.height, greaterThan(44.0));

      // Complete expansion
      await tester.pumpAndSettle();
      final Size expandedSize = tester.getSize(find.byType(BottomBarGlassSurface).last);
      expect(expandedSize.width, closeTo(192.0, 0.5));
      expect(expandedSize.height, closeTo(250.0, 0.5));

      // Options popup items are mounted and visible
      expect(find.text('Pin Note'), findsOneWidget);
      expect(find.text('Delete Note'), findsOneWidget);

      // Reverse: collapse back to 192x44 pill
      await tester.pumpWidget(buildHarness(expanded: false));
      await tester.pumpAndSettle();

      final Size returnSize = tester.getSize(find.byType(BottomBarGlassSurface).last);
      expect(returnSize.width, closeTo(192.0, 0.5));
      expect(returnSize.height, closeTo(44.0, 0.5));
    });
  });
}
