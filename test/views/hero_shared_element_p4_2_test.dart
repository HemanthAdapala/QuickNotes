import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/models/note_summary.dart';
import 'package:quick_notes/premium/premium.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/providers/settings_provider.dart';
import 'package:quick_notes/providers/tasks_provider.dart';
import 'package:quick_notes/views/screens/category_details_screen.dart';
import 'package:quick_notes/views/screens/folder_management_screen.dart';
import 'package:quick_notes/views/screens/note_editor_screen.dart';
import 'package:quick_notes/views/widgets/app_bottom_navigation_bar.dart';
import 'package:quick_notes/views/widgets/app_header_bar.dart';
import 'package:quick_notes/views/widgets/folder_note_card.dart';
import 'package:quick_notes/views/widgets/note_card.dart';
import 'package:quick_notes/views/widgets/notes_stack_widget.dart';
import 'package:quick_notes/views/widgets/search_note_card.dart';

Note _createTestNote({
  required String id,
  String title = 'Test Note Title',
  String content = 'Test note body content',
  String category = 'Personal',
}) {
  return Note(
    id: id,
    title: title,
    content: content,
    category: category,
    createdAt: DateTime(2026, 1, 1, 10, 0),
    updatedAt: DateTime(2026, 1, 1, 12, 0),
    colorValue: 0xFFFFFF,
    tags: const [],
    attachments: const [],
  );
}

NoteSummary _createTestNoteSummary({
  required String id,
  String title = 'Test Note Summary',
  String category = 'Personal',
}) {
  return NoteSummary(
    id: id,
    title: title,
    previewText: 'Preview text for summary',
    colorValue: 1,
    categoryName: category,
    categoryId: category.toLowerCase(),
    createdAt: DateTime(2026, 1, 1, 10, 0),
    updatedAt: DateTime(2026, 1, 1, 12, 0),
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
}

Widget _buildHarness({
  required Widget child,
  NotesProvider? notesProvider,
  SettingsProvider? settingsProvider,
  PremiumEntitlementManager? entitlementManager,
}) {
  final entMgr = entitlementManager ?? PremiumEntitlementManager();
  final stgPrv = settingsProvider ?? SettingsProvider();
  final ntsPrv = notesProvider ?? NotesProvider();

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<PremiumEntitlementManager>.value(value: entMgr),
      ProxyProvider<PremiumEntitlementManager, FeatureAccess>(
        update: (_, manager, __) => DefaultFeatureAccess(manager),
      ),
      ChangeNotifierProvider<SettingsProvider>.value(value: stgPrv),
      ChangeNotifierProvider<NotesProvider>.value(value: ntsPrv),
      ChangeNotifierProvider<TasksProvider>(create: (_) => TasksProvider()),
    ],
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase P4.2 — Hero & Shared-Element Polish Tests', () {
    // ── TEST 1: Existing Home Note Hero Tag Contract ──────────────────────────
    testWidgets('TEST 1: Home note Hero tag matches NoteEditor destination tag',
        (tester) async {
      const testId = 'home_card_p4_2_001';
      final note = _createTestNote(id: testId, title: 'Hero Source Note');

      // Verify source tag in NotesStackWidget
      await tester.pumpWidget(
        _buildHarness(
          child: Scaffold(
            body: Center(
              child: NotesStackWidget(
                notes: [note],
                onEdit: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      final sourceHeroFinder = find.byWidgetPredicate(
        (w) => w is Hero && w.tag == 'hero_note_card_$testId',
      );
      expect(
        sourceHeroFinder,
        findsOneWidget,
        reason: 'NotesStackWidget must declare hero_note_card_$testId',
      );

      // Verify destination tag in NoteEditorScreen
      await tester.pumpWidget(
        _buildHarness(
          child: NoteEditorScreen(note: note),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final destinationHeroFinder = find.byWidgetPredicate(
        (w) => w is Hero && w.tag == 'hero_note_card_$testId',
      );
      expect(
        destinationHeroFinder,
        findsOneWidget,
        reason: 'NoteEditorScreen destination must match hero_note_card_$testId',
      );
    });

    // ── TEST 2: Orphan hero_folders_search Hero Removal ────────────────────────
    testWidgets(
        'TEST 2: Orphan hero_folders_search Hero is removed from FolderManagementScreen',
        (tester) async {
      await tester.pumpWidget(
        _buildHarness(
          child: FolderManagementScreen(
            onMenuTap: () {},
            onNavigateToTab: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The orphan Hero tag must not exist
      final orphanHeroFinder = find.byWidgetPredicate(
        (w) => w is Hero && w.tag == 'hero_folders_search',
      );
      expect(
        orphanHeroFinder,
        findsNothing,
        reason:
            'FolderManagementScreen must not wrap search button in orphan Hero',
      );

      // The search button control itself must be preserved
      final searchGlassFinder = find.ancestor(
        of: find.byIcon(Icons.search_rounded),
        matching: find.byType(BottomBarGlassSurface),
      );
      expect(
        searchGlassFinder,
        findsOneWidget,
        reason: 'Search control BottomBarGlassSurface must remain intact',
      );

      final searchIconFinder = find.byIcon(Icons.search_rounded);
      expect(
        searchIconFinder,
        findsOneWidget,
        reason: 'Search icon within bottom bar glass surface must remain intact',
      );
    });

    // ── TEST 3: CategoryDetailsScreen Explicit Hero Tags ─────────────────────
    testWidgets(
        'TEST 3: CategoryDetailsScreen provides explicit screen-specific Hero tags',
        (tester) async {
      await tester.pumpWidget(
        _buildHarness(
          child: const CategoryDetailsScreen(category: 'Personal'),
        ),
      );
      await tester.pumpAndSettle();

      final headerFinder = find.byType(AppHeaderBar);
      expect(headerFinder, findsOneWidget);

      final appHeaderBar = tester.widget<AppHeaderBar>(headerFinder);
      expect(
        appHeaderBar.leftHeroTag,
        equals('hero_category_details_back'),
        reason: 'CategoryDetailsScreen must declare hero_category_details_back',
      );
      expect(
        appHeaderBar.rightHeroTag,
        equals('hero_category_details_search'),
        reason:
            'CategoryDetailsScreen must declare hero_category_details_search',
      );

      // Verify that generic fallback tags are absent
      final genericLeadingFinder = find.byWidgetPredicate(
        (w) => w is Hero && w.tag == 'hero_header_leading',
      );
      final genericTrailingFinder = find.byWidgetPredicate(
        (w) => w is Hero && w.tag == 'hero_header_trailing',
      );
      expect(genericLeadingFinder, findsNothing);
      expect(genericTrailingFinder, findsNothing);

      // Verify that the explicit tags are mounted
      final backHeroFinder = find.byWidgetPredicate(
        (w) => w is Hero && w.tag == 'hero_category_details_back',
      );
      final searchHeroFinder = find.byWidgetPredicate(
        (w) => w is Hero && w.tag == 'hero_category_details_search',
      );
      expect(backHeroFinder, findsOneWidget);
      expect(searchHeroFinder, findsOneWidget);
    });

    // ── TEST 4: NoteCard Hero Tag Consistency ────────────────────────────────
    testWidgets('TEST 4: NoteCard uses hero_note_card_id format',
        (tester) async {
      const cardId = 'note_card_arch_sync_042';
      final noteSummary = _createTestNoteSummary(id: cardId, title: 'Architecture Note');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCard(
              note: noteSummary,
              onTap: () {},
              onPinToggle: () {},
              onFavoriteToggle: () {},
              onDelete: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      final updatedHeroFinder = find.byWidgetPredicate(
        (w) => w is Hero && w.tag == 'hero_note_card_$cardId',
      );
      expect(
        updatedHeroFinder,
        findsOneWidget,
        reason: 'NoteCard must use the hero_note_card_ prefix',
      );

      final legacyHeroFinder = find.byWidgetPredicate(
        (w) => w is Hero && w.tag == 'note_card_$cardId',
      );
      expect(
        legacyHeroFinder,
        findsNothing,
        reason: 'NoteCard must no longer use the old note_card_ tag prefix',
      );
    });

    // ── TEST 5: Absence of Forced Hero Flights in Secondary Screens / Collections
    testWidgets('TEST 5: Secondary collection cards declare no Hero widgets',
        (tester) async {
      final noteSummary = _createTestNoteSummary(id: 'folder_note_007');
      final fullNote = _createTestNote(id: 'search_note_008');

      // 5A: FolderNoteCard must contain no Hero
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FolderNoteCard(
              note: noteSummary,
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      final folderCardHeroFinder = find.descendant(
        of: find.byType(FolderNoteCard),
        matching: find.byType(Hero),
      );
      expect(
        folderCardHeroFinder,
        findsNothing,
        reason:
            'FolderNoteCard must not contain Hero widgets (standard page route transition)',
      );

      // 5B: SearchNoteCard must contain no Hero
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchNoteCard(
              note: fullNote,
              query: 'test',
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      final searchCardHeroFinder = find.descendant(
        of: find.byType(SearchNoteCard),
        matching: find.byType(Hero),
      );
      expect(
        searchCardHeroFinder,
        findsNothing,
        reason:
            'SearchNoteCard must not contain Hero widgets (standard page route transition)',
      );
    });
  });
}
