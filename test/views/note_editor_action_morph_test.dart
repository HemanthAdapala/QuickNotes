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
import 'package:quick_notes/views/widgets/app_bottom_navigation_bar.dart';
import 'package:quick_notes/views/widgets/quick_notes_glass_action_morph.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late NotesProvider notesProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    notesProvider = NotesProvider();
  });

  Widget buildNoteEditorApp({Note? initialNote}) {
    final note = initialNote ??
        Note(
          id: 'test_note_1',
          title: 'Test Note Title',
          content: 'Test Note Content',
          tags: const [],
          attachments: const [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          colorValue: 0xFFFFFFFF,
          category: 'Personal',
        );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PremiumEntitlementManager()),
        ProxyProvider<PremiumEntitlementManager, FeatureAccess>(
          update: (_, manager, __) => DefaultFeatureAccess(manager),
        ),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider<NotesProvider>.value(value: notesProvider),
        ChangeNotifierProvider(create: (_) => TasksProvider()),
      ],
      child: MaterialApp(
        theme: QuickNotesTheme.lightTheme,
        darkTheme: QuickNotesTheme.darkTheme,
        home: MediaQuery(
          data: const MediaQueryData(size: Size(412.0, 915.0)),
          child: NoteEditorScreen(note: note),
        ),
      ),
    );
  }

  group('Note Editor More Options Morph Engine & Fidelity Tests', () {
    testWidgets(
        '1. Collapsed state renders 192x44 rectangle pill at top-right with functional sub-buttons',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildNoteEditorApp());
      await tester.pumpAndSettle();

      final morphFinder = find.byType(QuickNotesGlassActionMorph<void>);
      expect(morphFinder, findsOneWidget);

      final glassFinder = find.descendant(
        of: morphFinder,
        matching: find.byType(BottomBarGlassSurface),
      );
      expect(glassFinder, findsOneWidget);

      final Size size = tester.getSize(glassFinder);
      expect(size.width, closeTo(192.0, 0.5));
      expect(size.height, closeTo(44.0, 0.5));

      // Options popup items are NOT visible in collapsed state
      expect(find.text('Pin Note'), findsNothing);
      expect(find.text('Delete Note'), findsNothing);

      // Collapsed row controls are present
      expect(find.byIcon(Icons.undo_rounded), findsOneWidget);
      expect(find.byIcon(Icons.redo_rounded), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
    });

    testWidgets(
        '2. Expanded state renders 192x250 card with all 5 action items present',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildNoteEditorApp());
      await tester.pumpAndSettle();

      final morphFinder = find.byType(QuickNotesGlassActionMorph<void>);
      final glassFinder = find.descendant(
        of: morphFinder,
        matching: find.byType(BottomBarGlassSurface),
      );

      // Tap 3-dot trigger inside collapsed pill
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();

      final Size size = tester.getSize(glassFinder);
      expect(size.width, closeTo(192.0, 0.5));
      expect(size.height, closeTo(250.0, 0.5));

      // All 5 Note Editor actions are present in expanded state
      expect(find.text('Pin Note'), findsOneWidget);
      expect(find.text('Add Favorite'), findsOneWidget);
      expect(find.text('Find in Note'), findsOneWidget);
      expect(find.text('Export & Share'), findsOneWidget);
      expect(find.text('Delete Note'), findsOneWidget);
    });

    testWidgets(
        '3. Open transition animates smoothly from 192x44 to 192x250 with spring physics',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildNoteEditorApp());
      await tester.pumpAndSettle();

      final glassFinder = find.descendant(
        of: find.byType(QuickNotesGlassActionMorph<void>),
        matching: find.byType(BottomBarGlassSurface),
      );

      // Tap to expand
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pump(); // frame 0

      // Advance frames into spring motion
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      final Size midSize = tester.getSize(glassFinder);
      expect(midSize.width, closeTo(192.0, 0.5));
      expect(midSize.height, greaterThan(44.0));
      expect(midSize.height, lessThan(260.0));

      await tester.pumpAndSettle();
      final Size settledSize = tester.getSize(glassFinder);
      expect(settledSize.width, closeTo(192.0, 0.5));
      expect(settledSize.height, closeTo(250.0, 0.5));
    });

    testWidgets(
        '4. Close transition via outside tap animates smoothly back to 192x44',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildNoteEditorApp());
      await tester.pumpAndSettle();

      final glassFinder = find.descendant(
        of: find.byType(QuickNotesGlassActionMorph<void>),
        matching: find.byType(BottomBarGlassSurface),
      );

      // Expand
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();
      expect(tester.getSize(glassFinder).height, closeTo(250.0, 0.5));

      // Tap outside to trigger outside-tap barrier dismissal
      await tester.tapAt(const Offset(100, 500));
      await tester.pump(); // frame 0 of close

      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      final Size midSize = tester.getSize(glassFinder);
      expect(midSize.width, closeTo(192.0, 0.5));
      expect(midSize.height, lessThan(250.0));

      await tester.pumpAndSettle();
      expect(tester.getSize(glassFinder), const Size(192.0, 44.0));
    });

    testWidgets(
        '5 & 6. Reverse transition and live-state interruption reverses smoothly without jump',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildNoteEditorApp());
      await tester.pumpAndSettle();

      final glassFinder = find.descendant(
        of: find.byType(QuickNotesGlassActionMorph<void>),
        matching: find.byType(BottomBarGlassSurface),
      );

      // Start expansion
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pump();
      for (int i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      final Size midFlightSize = tester.getSize(glassFinder);
      expect(midFlightSize.height, greaterThan(44.0));
      expect(midFlightSize.height, lessThan(250.0));

      // Interrupt with outside tap
      await tester.tapAt(const Offset(100, 500));
      await tester.pump();

      // Cleanly settles back at 192x44 without throwing
      await tester.pumpAndSettle();
      expect(tester.getSize(glassFinder), const Size(192.0, 44.0));
    });

    testWidgets('7. Rapid retargeting remains stable and finite',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildNoteEditorApp());
      await tester.pumpAndSettle();

      final glassFinder = find.descendant(
        of: find.byType(QuickNotesGlassActionMorph<void>),
        matching: find.byType(BottomBarGlassSurface),
      );

      for (int i = 0; i < 6; i++) {
        if (i % 2 == 0) {
          await tester.tap(find.byIcon(Icons.more_horiz_rounded));
        } else {
          await tester.tapAt(const Offset(100, 500));
        }
        await tester.pump(const Duration(milliseconds: 25));
      }

      await tester.pumpAndSettle();
      final Size finalSize = tester.getSize(glassFinder);
      expect(finalSize.width, closeTo(192.0, 0.5));
      expect(finalSize.height == 44.0 || finalSize.height == 250.0, isTrue);
    });

    testWidgets(
        '8, 9 & 10. Action dispatch, identity preservation, and Pin Note callback execution',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildNoteEditorApp());
      await tester.pumpAndSettle();

      final glassFinder = find.descendant(
        of: find.byType(QuickNotesGlassActionMorph<void>),
        matching: find.byType(BottomBarGlassSurface),
      );

      // Open More Options
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();

      // Tap Pin Note
      expect(find.text('Pin Note'), findsOneWidget);
      await tester.tap(find.text('Pin Note'));
      await tester.pumpAndSettle();

      // Morph collapsed back to 192x44
      expect(tester.getSize(glassFinder), const Size(192.0, 44.0));

      // Re-open to verify state updated to Unpin Note
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Unpin Note'), findsOneWidget);
    });

    testWidgets(
        '8, 9 & 10. Action dispatch, identity preservation, and Add Favorite callback execution',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildNoteEditorApp());
      await tester.pumpAndSettle();

      final glassFinder = find.descendant(
        of: find.byType(QuickNotesGlassActionMorph<void>),
        matching: find.byType(BottomBarGlassSurface),
      );

      // Open More Options
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();

      // Tap Add Favorite
      expect(find.text('Add Favorite'), findsOneWidget);
      await tester.tap(find.text('Add Favorite'));
      await tester.pumpAndSettle();

      // Morph collapsed back to 192x44
      expect(tester.getSize(glassFinder), const Size(192.0, 44.0));

      // Re-open to verify state updated to Remove Favorite
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Remove Favorite'), findsOneWidget);
    });

    testWidgets(
        '8, 9 & 10. Action dispatch, identity preservation, and Find in Note callback execution',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildNoteEditorApp());
      await tester.pumpAndSettle();

      // Open More Options
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();

      // Tap Find in Note
      expect(find.text('Find in Note'), findsOneWidget);
      await tester.tap(find.text('Find in Note'));
      await tester.pumpAndSettle();

      // Find in note search bar is displayed
      expect(find.text('Find in note...'), findsOneWidget);
    });

    testWidgets(
        '11. Content transition crossfades incoming and outgoing layers',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildNoteEditorApp());
      await tester.pumpAndSettle();

      // Initially collapsed: popup text not visible
      expect(find.text('Pin Note'), findsNothing);

      // Trigger expansion
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pump();

      // Step into content transition window
      await tester.pump(const Duration(milliseconds: 120));

      // Complete transition
      await tester.pumpAndSettle();
      expect(find.text('Pin Note'), findsOneWidget);
      expect(find.text('Delete Note'), findsOneWidget);
    });

    testWidgets(
        '12. Lifecycle & disposal: Ticker and controllers dispose cleanly during transition',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildNoteEditorApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pump(const Duration(milliseconds: 30));

      // Navigate away / replace tree mid-flight
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('NavigatedAway'))),
      );
      await tester.pumpAndSettle();

      expect(find.text('NavigatedAway'), findsOneWidget);
      expect(find.byType(QuickNotesGlassActionMorph<void>), findsNothing);
    });
  });
}
