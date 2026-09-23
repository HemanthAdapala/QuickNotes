import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quick_notes/themes/quick_notes_theme.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/controllers/in_editor_local_search_controller.dart';
import 'package:quick_notes/views/widgets/in_editor_local_search_bar.dart';
import 'package:quick_notes/views/screens/folder_management_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('DM-F1 Production Input Field Dark Mode Tests', () {
    testWidgets('F1 — FolderManagementScreen Search field explicitly neutralizes all borders and fill in Dark Mode', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final notesProvider = NotesProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<NotesProvider>.value(
          value: notesProvider,
          child: MaterialApp(
            theme: QuickNotesTheme.lightTheme,
            darkTheme: QuickNotesTheme.darkTheme,
            themeMode: ThemeMode.dark,
            home: FolderManagementScreen(
              onMenuTap: () {},
              onNavigateToTab: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap search icon to expand search
      final searchBtnFinder = find.byKey(const ValueKey('search_inactive_header'));
      expect(searchBtnFinder, findsOneWidget);

      final rightButton = find.descendant(
        of: searchBtnFinder,
        matching: find.byType(GestureDetector),
      ).last;
      await tester.tap(rightButton);
      await tester.pumpAndSettle();

      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);

      final TextField textField = tester.widget<TextField>(textFieldFinder);
      final InputDecoration? decoration = textField.decoration;

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
    });

    testWidgets('F2 — InEditorLocalSearchBar explicitly neutralizes all borders and fill in Dark Mode', (tester) async {
      final searchController = InEditorLocalSearchController();

      await tester.pumpWidget(
        MaterialApp(
          theme: QuickNotesTheme.lightTheme,
          darkTheme: QuickNotesTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: Scaffold(
            body: InEditorLocalSearchBar(
              searchController: searchController,
              titleText: 'Test Note',
              bodyText: 'This is a test note body.',
              onMatchChanged: (_) {},
              onClose: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);

      final TextField textField = tester.widget<TextField>(textFieldFinder);
      final InputDecoration? decoration = textField.decoration;

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
    });

    testWidgets('F2 — InEditorLocalSearchBar Light Mode preserves light appearance', (tester) async {
      final searchController = InEditorLocalSearchController();

      await tester.pumpWidget(
        MaterialApp(
          theme: QuickNotesTheme.lightTheme,
          darkTheme: QuickNotesTheme.darkTheme,
          themeMode: ThemeMode.light,
          home: Scaffold(
            body: InEditorLocalSearchBar(
              searchController: searchController,
              titleText: 'Test Note',
              bodyText: 'This is a test note body.',
              onMatchChanged: (_) {},
              onClose: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);

      final TextField textField = tester.widget<TextField>(textFieldFinder);
      expect(textField.cursorColor, equals(const Color(0xFF1C1C1E)));
      expect(textField.style?.color, equals(const Color(0xFF1C1C1E)));
      expect(textField.decoration?.filled, isFalse);
      expect(textField.decoration?.border, equals(InputBorder.none));
    });

    testWidgets('F3 — Folder Notes Rename Folder dialog field neutralizes borders & fill in Dark Mode', (tester) async {
      final controller = TextEditingController(text: 'My Folder');

      await tester.pumpWidget(
        MaterialApp(
          theme: QuickNotesTheme.lightTheme,
          darkTheme: QuickNotesTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                const bool isDark = true;
                return AlertDialog(
                  backgroundColor: const Color(0xFF2C2C2C),
                  title: const Text('Rename Folder', style: TextStyle(color: Colors.white)),
                  content: TextField(
                    controller: controller,
                    autofocus: true,
                    cursorColor: isDark ? const Color(0xFFFFCC00) : null,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      filled: false,
                      fillColor: Colors.transparent,
                      hintText: "Folder Name",
                      hintStyle: const TextStyle(color: Color(0xFF757575)),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);

      final TextField textField = tester.widget<TextField>(textFieldFinder);
      final InputDecoration? decoration = textField.decoration;

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
    });

    testWidgets('F4 — Note Editor Add Tag dialog field neutralizes borders & fill in Dark Mode', (tester) async {
      final tagController = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          theme: QuickNotesTheme.lightTheme,
          darkTheme: QuickNotesTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                const bool isDark = true;
                return AlertDialog(
                  backgroundColor: const Color(0xFF2C2C2C),
                  title: const Text("Add Note Tag", style: TextStyle(color: Colors.white)),
                  content: TextField(
                    controller: tagController,
                    autofocus: true,
                    cursorColor: isDark ? const Color(0xFFFFCC00) : null,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      filled: false,
                      fillColor: Colors.transparent,
                      hintText: "Enter tag (e.g. urgent)",
                      hintStyle: const TextStyle(color: Color(0xFF757575)),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);

      final TextField textField = tester.widget<TextField>(textFieldFinder);
      final InputDecoration? decoration = textField.decoration;

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
    });

    testWidgets('F5 — Note Editor Setup PIN dialog fields neutralize borders & fill in Dark Mode', (tester) async {
      final pinController = TextEditingController();
      final confirmController = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          theme: QuickNotesTheme.lightTheme,
          darkTheme: QuickNotesTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                const bool isDark = true;
                return AlertDialog(
                  backgroundColor: const Color(0xFF2C2C2C),
                  title: const Text("Setup Secure PIN", style: TextStyle(color: Colors.white)),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: pinController,
                        autofocus: true,
                        cursorColor: isDark ? const Color(0xFFFFCC00) : null,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: "Enter 4-digit PIN",
                          labelStyle: const TextStyle(color: Color(0xFF8E8E93)),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          filled: false,
                          fillColor: Colors.transparent,
                          counterText: "",
                        ),
                      ),
                      TextFormField(
                        controller: confirmController,
                        cursorColor: isDark ? const Color(0xFFFFCC00) : null,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: "Confirm PIN",
                          labelStyle: const TextStyle(color: Color(0xFF8E8E93)),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          filled: false,
                          fillColor: Colors.transparent,
                          counterText: "",
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFieldsFinder = find.byType(TextField);
      expect(textFieldsFinder, findsNWidgets(2));

      for (int i = 0; i < 2; i++) {
        final TextField innerField = tester.widget<TextField>(textFieldsFinder.at(i));
        final InputDecoration? decoration = innerField.decoration;

        expect(decoration, isNotNull);
        expect(decoration!.border, equals(InputBorder.none));
        expect(decoration.enabledBorder, equals(InputBorder.none));
        expect(decoration.focusedBorder, equals(InputBorder.none));
        expect(decoration.errorBorder, equals(InputBorder.none));
        expect(decoration.focusedErrorBorder, equals(InputBorder.none));
        expect(decoration.disabledBorder, equals(InputBorder.none));
        expect(decoration.filled, isFalse);
        expect(decoration.fillColor, equals(Colors.transparent));
        expect(innerField.cursorColor, equals(const Color(0xFFFFCC00)));
      }
    });
  });
}
