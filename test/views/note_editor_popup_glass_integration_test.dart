import 'dart:ui';
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
  });
}
