import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/premium/premium.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/providers/settings_provider.dart';
import 'package:quick_notes/providers/tasks_provider.dart';
import 'package:quick_notes/themes/quick_notes_theme.dart';
import 'package:quick_notes/views/screens/note_editor_screen.dart';
import 'package:quick_notes/views/widgets/new_single_document_editor.dart';
import 'package:quick_notes/views/widgets/rich_text_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  Widget buildNoteEditorTestHarness({Note? note}) {
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
        theme: QuickNotesTheme.darkTheme,
        home: NoteEditorScreen(note: note),
      ),
    );
  }

  group('Note Editor Text Fields Dark Mode Decoration Tests', () {
    testWidgets(
        'NoteEditorScreen Title field has neutralized borders and transparent fill under darkTheme',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildNoteEditorTestHarness());
      await tester.pump(const Duration(milliseconds: 300));

      final textFields = tester.widgetList<TextField>(find.byType(TextField));
      expect(textFields, isNotEmpty);

      final titleField = textFields.first;
      final deco = titleField.decoration;
      expect(deco, isNotNull);

      // Verify all borders are neutralized
      expect(deco!.border, InputBorder.none);
      expect(deco.enabledBorder, InputBorder.none);
      expect(deco.focusedBorder, InputBorder.none);
      expect(deco.disabledBorder, InputBorder.none);
      expect(deco.errorBorder, InputBorder.none);
      expect(deco.focusedErrorBorder, InputBorder.none);

      // Verify fill is neutralized
      expect(deco.filled, isFalse);
      expect(deco.fillColor, Colors.transparent);

      // Verify no yellow focus stroke leakage
      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();

      final focusedTitleField =
          tester.widget<TextField>(find.byType(TextField).first);
      final focusedDeco = focusedTitleField.decoration;
      expect(focusedDeco!.focusedBorder, InputBorder.none);
    });

    testWidgets(
        'NoteEditorScreen Block fields have neutralized borders and transparent fill',
        (WidgetTester tester) async {
      final noteWithBlocks = Note(
        id: 'test_note',
        title: 'Test Title',
        content:
            '{"ops":[{"insert":"Hello World\\n"}]}',
        tags: const [],
        attachments: const [],
        colorValue: 0xFFFFFFFF,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Force standard block editor
      NoteEditorScreen.useSingleDocumentEditor = false;

      await tester.pumpWidget(buildNoteEditorTestHarness(note: noteWithBlocks));
      await tester.pump(const Duration(milliseconds: 300));

      final textFields = tester.widgetList<TextField>(find.byType(TextField));
      expect(textFields.length, greaterThan(1));

      // Check every TextField on screen (title + content blocks)
      for (final tf in textFields) {
        final deco = tf.decoration;
        expect(deco, isNotNull);
        expect(deco!.border, InputBorder.none);
        expect(deco.enabledBorder, InputBorder.none);
        expect(deco.focusedBorder, InputBorder.none);
        expect(deco.disabledBorder, InputBorder.none);
        expect(deco.errorBorder, InputBorder.none);
        expect(deco.focusedErrorBorder, InputBorder.none);
        expect(deco.filled, isFalse);
        expect(deco.fillColor, Colors.transparent);
      }

      // Reset
      NoteEditorScreen.useSingleDocumentEditor = true;
    });

    testWidgets(
        'NewSingleDocumentEditor segment TextField has neutralized borders and transparent fill',
        (WidgetTester tester) async {
      final controller = RichTextEditingController();
      controller.text = 'Hello Dark Mode';
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          theme: QuickNotesTheme.darkTheme,
          home: Scaffold(
            backgroundColor: const Color(0xFF1E1E1E),
            body: NewSingleDocumentEditor(
              controller: controller,
              focusNode: focusNode,
              textColor: const Color(0xFFFFFFFF),
              paperGuideHeight: 1.0,
              contextMenuBuilder: (context, state) => const SizedBox(),
              formattingToolbarHeight: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);

      final sdeField = tester.widget<TextField>(textFieldFinder);
      final deco = sdeField.decoration;
      expect(deco, isNotNull);

      // Verify all borders are neutralized
      expect(deco!.border, InputBorder.none);
      expect(deco.enabledBorder, InputBorder.none);
      expect(deco.focusedBorder, InputBorder.none);
      expect(deco.disabledBorder, InputBorder.none);
      expect(deco.errorBorder, InputBorder.none);
      expect(deco.focusedErrorBorder, InputBorder.none);

      // Verify fill is neutralized
      expect(deco.filled, isFalse);
      expect(deco.fillColor, Colors.transparent);

      // Tap to focus and verify no yellow focus border
      await tester.tap(textFieldFinder);
      await tester.pumpAndSettle();

      final focusedField = tester.widget<TextField>(textFieldFinder);
      expect(focusedField.decoration!.focusedBorder, InputBorder.none);

      controller.dispose();
      focusNode.dispose();
    });
  });
}
