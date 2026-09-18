import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:quick_notes/controllers/editor_auto_scroll_controller.dart';
import 'package:quick_notes/controllers/in_editor_local_search_controller.dart';
import 'package:quick_notes/premium/premium.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/providers/settings_provider.dart';
import 'package:quick_notes/providers/tasks_provider.dart';
import 'package:quick_notes/views/screens/note_editor_screen.dart';
import 'package:quick_notes/views/widgets/editor_quick_scroll_pill.dart';
import 'package:quick_notes/views/widgets/in_editor_local_search_bar.dart';
import 'package:quick_notes/views/widgets/note_editor_options_popup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('D6-B Note Editor Shell Dark Mode Contract Tests', () {
    testWidgets('NoteEditorOptionsPopup in Light Mode',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: Center(
              child: NoteEditorOptionsPopup(
                isPinned: false,
                isFavorite: false,
                onTogglePin: () {},
                onToggleFavorite: () {},
                onFindInNote: () {},
                onExportAndShare: () {},
                onDeleteNote: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the direct root Container of NoteEditorOptionsPopup
      final popupFinder = find.byType(NoteEditorOptionsPopup);
      final containerFinder = find
          .descendant(
            of: popupFinder,
            matching: find.byType(Container),
          )
          .first;
      final popupContainer = tester.widget<Container>(containerFinder);
      final boxDeco = popupContainer.decoration as BoxDecoration?;
      expect(boxDeco?.color, Colors.transparent);

      final pinText = tester.widget<Text>(find.text('Pin Note'));
      expect(pinText.style?.color, const Color(0xFF333333));

      final deleteText = tester.widget<Text>(find.text('Delete Note'));
      expect(deleteText.style?.color, Colors.redAccent);
    });

    testWidgets('NoteEditorOptionsPopup in Dark Mode',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: Scaffold(
            body: Center(
              child: NoteEditorOptionsPopup(
                isPinned: false,
                isFavorite: false,
                onTogglePin: () {},
                onToggleFavorite: () {},
                onFindInNote: () {},
                onExportAndShare: () {},
                onDeleteNote: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final popupFinder = find.byType(NoteEditorOptionsPopup);
      final containerFinder = find
          .descendant(
            of: popupFinder,
            matching: find.byType(Container),
          )
          .first;
      final popupContainer = tester.widget<Container>(containerFinder);
      final boxDeco = popupContainer.decoration as BoxDecoration?;
      expect(boxDeco?.color, const Color(0xFF2C2C2C));

      final pinText = tester.widget<Text>(find.text('Pin Note'));
      expect(pinText.style?.color, const Color(0xFFFFFFFF));

      final deleteText = tester.widget<Text>(find.text('Delete Note'));
      expect(deleteText.style?.color, Colors.redAccent);
    });

    testWidgets('InEditorLocalSearchBar in Light Mode',
        (WidgetTester tester) async {
      final searchCtrl = InEditorLocalSearchController();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: InEditorLocalSearchBar(
              searchController: searchCtrl,
              titleText: 'Test Title',
              bodyText: 'Test Body',
              onMatchChanged: (_) {},
              onClose: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.style?.color, const Color(0xFF1C1C1E));
      expect(textField.decoration?.hintStyle?.color, const Color(0xFF8E8E93));

      searchCtrl.dispose();
    });

    testWidgets('InEditorLocalSearchBar in Dark Mode',
        (WidgetTester tester) async {
      final searchCtrl = InEditorLocalSearchController();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: Scaffold(
            body: InEditorLocalSearchBar(
              searchController: searchCtrl,
              titleText: 'Test Title',
              bodyText: 'Test Body',
              onMatchChanged: (_) {},
              onClose: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.style?.color, const Color(0xFFFFFFFF));
      expect(textField.decoration?.hintStyle?.color, const Color(0xFF8E8E93));

      searchCtrl.dispose();
    });

    testWidgets('EditorQuickScrollPill in Light Mode',
        (WidgetTester tester) async {
      final scrollCtrl =
          EditorAutoScrollController(scrollController: ScrollController());

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: EditorQuickScrollPill(controller: scrollCtrl),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final upIconFinder = find.byIcon(Icons.keyboard_arrow_up_rounded);
      final upIcon = tester.widget<Icon>(upIconFinder);
      // When canScrollToTop is false, it uses alpha 0.25
      expect(upIcon.color, const Color(0xFF1C1C1E).withValues(alpha: 0.25));

      scrollCtrl.dispose();
    });

    testWidgets('EditorQuickScrollPill in Dark Mode',
        (WidgetTester tester) async {
      final scrollCtrl =
          EditorAutoScrollController(scrollController: ScrollController());

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: Scaffold(
            body: EditorQuickScrollPill(controller: scrollCtrl),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final upIconFinder = find.byIcon(Icons.keyboard_arrow_up_rounded);
      final upIcon = tester.widget<Icon>(upIconFinder);
      // In Dark Mode when canScrollToTop is false, it uses Colors.white.withValues(alpha: 0.25)
      expect(upIcon.color, Colors.white.withValues(alpha: 0.25));

      scrollCtrl.dispose();
    });

    testWidgets('NoteEditorScreen root canvas and note sheet in Light Mode',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
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
            theme: ThemeData.light(),
            home: const NoteEditorScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final scaffoldFinder = find.byType(Scaffold).first;
      final scaffold = tester.widget<Scaffold>(scaffoldFinder);
      expect(scaffold.backgroundColor, Colors.white);

      final titleTextField =
          tester.widget<TextField>(find.byType(TextField).first);
      expect(titleTextField.style?.color, const Color(0xFF1C1C1E));
      expect(titleTextField.decoration?.hintStyle?.color,
          const Color(0xFF1C1C1E).withValues(alpha: 0.3));
    });

    testWidgets('NoteEditorScreen root canvas and note sheet in Dark Mode',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
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
            home: const NoteEditorScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final scaffoldFinder = find.byType(Scaffold).first;
      final scaffold = tester.widget<Scaffold>(scaffoldFinder);
      expect(scaffold.backgroundColor, const Color(0xFF1E1E1E));

      final titleTextField =
          tester.widget<TextField>(find.byType(TextField).first);
      expect(titleTextField.style?.color, const Color(0xFFFFFFFF));
      expect(
          titleTextField.decoration?.hintStyle?.color, const Color(0xFF8E8E93));
    });
  });
}
