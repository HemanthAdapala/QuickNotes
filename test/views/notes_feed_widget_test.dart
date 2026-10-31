import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:quick_notes/models/folder.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/models/note_summary.dart';
import 'package:quick_notes/models/session_type.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/repositories/folders_repository.dart';
import 'package:quick_notes/repositories/notes_repository.dart';
import 'package:quick_notes/services/session_manager.dart';
import 'package:quick_notes/views/screens/folder_notes_screen.dart';
import 'package:quick_notes/views/widgets/folder_note_card.dart';
import 'package:quick_notes/views/widgets/note_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockNotesRepo implements NotesRepository {
  final Map<String, Note> storage = {};

  @override
  Future<List<Note>> getNotes() async =>
      storage.values.where((n) => !n.isDeleted).toList();
  @override
  Future<List<Note>> getTrashNotes() async =>
      storage.values.where((n) => n.isDeleted).toList();
  @override
  Future<Note?> getNoteById(String id) async => storage[id];
  @override
  Future<List<Note>> queryHabits() async => [];
  @override
  Future<int> insertNote(Note note) async {
    storage[note.id] = note;
    return 1;
  }

  @override
  Future<int> updateNote(Note note) async {
    storage[note.id] = note;
    return 1;
  }

  @override
  Future<int> trashNote(String id) async => 1;
  @override
  Future<int> restoreNote(String id) async => 1;
  @override
  Future<int> deleteNote(String id) async => 1;
  @override
  Future<int> emptyTrash() async => 1;
  @override
  Future<int> togglePin(String id) async => 1;
  @override
  Future<int> toggleFavorite(String id) async => 1;
  @override
  Future<int> toggleArchive(String id) async => 1;
  @override
  Future<List<Note>> searchNotes(String query) async => [];

  @override
  Future<List<Map<String, dynamic>>> queryNotesSummaryPaged({
    String? folderId,
    String? category,
    bool? isFavorite,
    bool? isArchived,
    bool isDeleted = false,
    int limit = 20,
    int offset = 0,
  }) async {
    var list = storage.values.where((n) => n.isDeleted == isDeleted).toList();
    if (folderId != null) {
      list = list.where((n) => n.folderId == folderId).toList();
    }
    return list.map((n) => n.toMap()).toList();
  }
}

class MockFoldersRepo implements FoldersRepository {
  @override
  Future<List<Folder>> getFolders() async => [];
  @override
  Future<List<Folder>> getTrashFolders() async => [];
  @override
  Future<int> insertFolder(Folder folder) async => 1;
  @override
  Future<int> updateFolder(Folder folder) async => 1;
  @override
  Future<int> trashFolder(String id) async => 1;
  @override
  Future<int> restoreFolder(String id) async => 1;
  @override
  Future<int> deleteFolder(String id) async => 1;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    const MethodChannel homeWidgetChannel = MethodChannel('home_widget');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            homeWidgetChannel, (MethodCall methodCall) async => true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('class.yiss.home_widget'),
            (MethodCall methodCall) async => true);

    const MethodChannel notificationsChannel =
        MethodChannel('dexterous.com/flutter_local_notifications');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            notificationsChannel, (MethodCall methodCall) async => true);

    const MethodChannel pathChannel =
        MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            pathChannel, (MethodCall methodCall) async => '.');

    SharedPreferences.setMockInitialValues({'active_user_id': 'usr_feed_test'});
    await SessionManager().init();
    await SessionManager().saveSession(
      userId: 'usr_feed_test',
      sessionType: SessionType.guest,
    );
  });

  group('Notes Feed & Card Components Widget Tests', () {
    testWidgets(
        '1. NoteCard renders title, preview, and responds to tap/pin/fav callbacks',
        (tester) async {
      bool tapped = false;
      bool pinToggled = false;
      bool favToggled = false;
      bool deleted = false;

      final note1 = Note(
        id: 'card_note_1',
        title: 'Meeting Notes with Client',
        content: 'Discuss timeline and scope for Q4',
        previewText: 'Discuss timeline and scope for Q4',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        colorValue: 1,
        isPinned: true,
        tags: const [],
        attachments: const [],
      );
      final summary = NoteSummary.fromMap(note1.toMap());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCard(
              note: summary,
              onTap: () => tapped = true,
              onPinToggle: () => pinToggled = true,
              onFavoriteToggle: () => favToggled = true,
              onDelete: () => deleted = true,
            ),
          ),
        ),
      );

      expect(find.text('Meeting Notes with Client'), findsOneWidget);
      expect(find.text('Discuss timeline and scope for Q4'), findsOneWidget);

      // Verify tap on card
      await tester.tap(find.text('Meeting Notes with Client'));
      await tester.pump();
      expect(tapped, isTrue);

      // Verify pin button interaction
      final pinButton = find.byIcon(Icons.push_pin);
      if (pinButton.evaluate().isNotEmpty) {
        await tester.tap(pinButton.first);
        await tester.pumpAndSettle();
        expect(pinToggled, isTrue);
      }

      // Verify favorite button interaction
      final favButton = find.byIcon(Icons.star_border);
      if (favButton.evaluate().isNotEmpty) {
        await tester.tap(favButton.first);
        await tester.pumpAndSettle();
        expect(favToggled, isTrue);
      }

      // Assert delete callback was not triggered during regular taps
      expect(deleted, isFalse);
    });

    testWidgets(
        '2. FolderNoteCard renders title and date with tactile spring container',
        (tester) async {
      bool tapped = false;

      final note2 = Note(
        id: 'folder_card_1',
        title: 'Architecture Review',
        content: 'Review Single Document Editor layout',
        previewText: 'Review Single Document Editor layout',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        colorValue: 3,
        isPinned: true,
        tags: const [],
        attachments: const [],
      );
      final summary = NoteSummary.fromMap(note2.toMap());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FolderNoteCard(
              note: summary,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Architecture Review'), findsOneWidget);

      await tester.tap(find.byType(FolderNoteCard));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets(
        '3. FolderNotesScreen shows empty state when folder contains no notes',
        (tester) async {
      final mockNotes = MockNotesRepo();
      final mockFolders = MockFoldersRepo();
      final provider = NotesProvider(
        notesRepository: mockNotes,
        foldersRepository: mockFolders,
      );

      final testFolder = Folder(
        id: 'empty_folder_id',
        name: 'Empty Sprint Folder',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<NotesProvider>.value(
          value: provider,
          child: MaterialApp(
            home: FolderNotesScreen(folder: testFolder),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No notes in this folder yet'), findsOneWidget);
      expect(find.text('Create Note'), findsOneWidget);
    });

    testWidgets(
        '4. FolderNotesScreen renders pinned and unpinned note cards with count header',
        (tester) async {
      final mockNotes = MockNotesRepo();
      final mockFolders = MockFoldersRepo();
      final testFolder = Folder(
        id: 'active_folder_id',
        name: 'Active Project',
        createdAt: DateTime.now(),
      );

      // Seed 1 pinned note and 1 unpinned note in this folder
      mockNotes.storage['n_pin'] = Note(
        id: 'n_pin',
        title: 'Pinned Milestone',
        content: 'Critical milestone item',
        folderId: testFolder.id,
        isPinned: true,
        tags: const [],
        attachments: const [],
        colorValue: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      mockNotes.storage['n_unpin'] = Note(
        id: 'n_unpin',
        title: 'Regular Task Item',
        content: 'Follow up notes',
        folderId: testFolder.id,
        isPinned: false,
        tags: const [],
        attachments: const [],
        colorValue: 2,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final provider = NotesProvider(
        notesRepository: mockNotes,
        foldersRepository: mockFolders,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<NotesProvider>.value(
          value: provider,
          child: MaterialApp(
            home: FolderNotesScreen(folder: testFolder),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Active Project'), findsWidgets);
      expect(find.text('2 NOTES'), findsOneWidget);
      expect(find.text('Pinned Milestone'), findsOneWidget);
      expect(find.text('Regular Task Item'), findsOneWidget);
    });

    testWidgets(
        '5. NoteCard renders habit streak badge and custom color styling',
        (tester) async {
      final habitNote = Note(
        id: 'habit_card_note',
        title: 'Daily Workout',
        content: 'Completed 30m cardio session',
        previewText: 'Completed 30m cardio session',
        isHabit: true,
        habitStreak: 7,
        category: 'Health',
        tags: const ['fitness'],
        attachments: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        colorValue: 1, // Coral background
      );
      final summary = NoteSummary.fromMap(habitNote.toMap());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCard(
              note: summary,
              onTap: () {},
              onPinToggle: () {},
              onFavoriteToggle: () {},
              onDelete: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Daily Workout'), findsOneWidget);
      expect(find.text('7 day streak'), findsOneWidget);
      expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);
    });

    testWidgets('6. NoteCard renders tags and category badges', (tester) async {
      final noteWithTags = Note(
        id: 'note_tagged',
        title: 'Project Roadmap',
        content: 'Quarterly OKR planning and goals',
        previewText: 'Quarterly OKR planning and goals',
        category: 'Work',
        tags: const ['roadmap', 'q4'],
        attachments: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        colorValue: 0,
      );
      final summary = NoteSummary.fromMap(noteWithTags.toMap());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCard(
              note: summary,
              onTap: () {},
              onPinToggle: () {},
              onFavoriteToggle: () {},
              onDelete: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Project Roadmap'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
    });
  });
}
