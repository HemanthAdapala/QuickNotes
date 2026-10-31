// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:quick_notes/models/folder.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/models/session_type.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/repositories/folders_repository.dart';
import 'package:quick_notes/repositories/notes_repository.dart';
import 'package:quick_notes/services/session_manager.dart';
import 'package:quick_notes/views/screens/note_editor_screen.dart';
import 'package:quick_notes/views/widgets/new_single_document_editor.dart';
import 'package:quick_notes/views/widgets/rich_text_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestAudioplayersPlatform extends AudioplayersPlatformInterface {
  final Map<String, StreamController<AudioEvent>> _eventControllers = {};

  @override
  Future<void> create(String playerId) async {
    _eventControllers[playerId] = StreamController<AudioEvent>.broadcast();
  }

  @override
  Future<void> dispose(String playerId) async {
    _eventControllers[playerId]?.close();
    _eventControllers.remove(playerId);
  }

  @override
  Future<void> emitError(String playerId, String code, String message) async {}
  @override
  Future<void> emitLog(String playerId, String message) async {}
  @override
  Future<int?> getCurrentPosition(String playerId) async => 0;
  @override
  Future<int?> getDuration(String playerId) async => 0;
  @override
  Future<void> pause(String playerId) async {}
  @override
  Future<void> release(String playerId) async {}
  @override
  Future<void> resume(String playerId) async {}
  @override
  Future<void> seek(String playerId, Duration position) async {}
  @override
  Future<void> setAudioContext(
      String playerId, AudioContext audioContext) async {}
  @override
  Future<void> setBalance(String playerId, double balance) async {}
  @override
  Future<void> setPlaybackRate(String playerId, double playbackRate) async {}
  @override
  Future<void> setPlayerMode(String playerId, PlayerMode playerMode) async {}
  @override
  Future<void> setReleaseMode(String playerId, ReleaseMode releaseMode) async {}
  @override
  Future<void> setSourceBytes(String playerId, Uint8List bytes,
      {String? mimeType}) async {}
  @override
  Future<void> setSourceUrl(String playerId, String url,
      {bool? isLocal, String? mimeType}) async {
    _eventControllers[playerId]?.add(
      const AudioEvent(eventType: AudioEventType.prepared, isPrepared: true),
    );
  }

  @override
  Future<void> setVolume(String playerId, double volume) async {}
  @override
  Future<void> stop(String playerId) async {}
  @override
  Stream<AudioEvent> getEventStream(String playerId) {
    return _eventControllers
        .putIfAbsent(playerId, () => StreamController<AudioEvent>.broadcast())
        .stream;
  }
}

class _TestGlobalAudioplayersPlatform
    extends GlobalAudioplayersPlatformInterface {
  final StreamController<GlobalAudioEvent> _globalEventController =
      StreamController<GlobalAudioEvent>.broadcast();

  @override
  Future<void> init() async {}
  @override
  Future<void> setGlobalAudioContext(AudioContext ctx) async {}
  @override
  Future<void> emitGlobalLog(String message) async {}
  @override
  Future<void> emitGlobalError(String code, String message) async {}
  @override
  Stream<GlobalAudioEvent> getGlobalEventStream() =>
      _globalEventController.stream;
}

class _MockNotesRepository implements NotesRepository {
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
  Future<int> updateNote(Note note) async {
    storage[note.id] = note;
    return 1;
  }
  @override
  Future<int> insertNote(Note note) async {
    storage[note.id] = note;
    return 1;
  }
  @override
  Future<List<Map<String, dynamic>>> queryNotesSummaryPaged({
    String? folderId,
    String? category,
    bool? isFavorite,
    bool? isArchived,
    bool isDeleted = false,
    int limit = 20,
    int offset = 0,
  }) async =>
      storage.values.map((n) => n.toMap()).toList();
  @override
  Future<List<Note>> searchNotes(String query) async => [];
  @override
  Future<int> togglePin(String id) async => 1;
  @override
  Future<int> toggleFavorite(String id) async => 1;
  @override
  Future<int> toggleArchive(String id) async => 1;
  @override
  Future<int> trashNote(String id) async => 1;
  @override
  Future<int> restoreNote(String id) async => 1;
  @override
  Future<int> deleteNote(String id) async => 1;
  @override
  Future<int> emptyTrash() async => 1;
}

class _MockFoldersRepository implements FoldersRepository {
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

  setUpAll(() {
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

    AudioplayersPlatformInterface.instance = _TestAudioplayersPlatform();
    GlobalAudioplayersPlatformInterface.instance =
        _TestGlobalAudioplayersPlatform();
  });

  Widget buildTestableEditor({
    required RichTextEditingController controller,
    required FocusNode focusNode,
    GlobalKey<NewSingleDocumentEditorState>? sdeKey,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: NewSingleDocumentEditor(
          key: sdeKey,
          controller: controller,
          focusNode: focusNode,
          textColor: Colors.black,
          paperGuideHeight: 1.0,
          formattingToolbarHeight: 0.0,
          contextMenuBuilder: (context, editableTextState) {
            return AdaptiveTextSelectionToolbar.editableText(
              editableTextState: editableTextState,
            );
          },
        ),
      ),
    );
  }

  group('RTF-001: Focus Restoration Targets Active Document Segment', () {
    late RichTextEditingController controller;
    late FocusNode parentFocusNode;

    setUp(() {
      controller = RichTextEditingController();
      parentFocusNode = FocusNode();
    });

    tearDown(() {
      controller.dispose();
      parentFocusNode.dispose();
    });

    testWidgets(
        'Focus restoration targets the segment containing the cursor, not segment 0',
        (tester) async {
      final sdeKey = GlobalKey<NewSingleDocumentEditorState>();
      controller.setMarkdown('First Line\nSecond Line\nThird Line');

      await tester.pumpWidget(
        buildTestableEditor(
          controller: controller,
          focusNode: parentFocusNode,
          sdeKey: sdeKey,
        ),
      );
      await tester.pumpAndSettle();

      final state = sdeKey.currentState!;
      expect(state.textSegments.length, equals(3));
      expect(state.textSegments[0].type, equals('paragraph'));
      expect(state.textSegments[1].type, equals('paragraph'));
      expect(state.textSegments[2].type, equals('paragraph'));

      // Position cursor inside segment 2 ("Third Line", offset 26)
      controller.selection = const TextSelection.collapsed(offset: 26);

      // Trigger parent focus request
      parentFocusNode.requestFocus();
      await tester.pump();

      // The focused node MUST be segment 2, NOT segment 0
      final focusNodes = state.focusNodes;
      expect(focusNodes[2]?.hasFocus, isTrue,
          reason: 'Segment 2 focus node should have focus');
      expect(focusNodes[0]?.hasFocus, isFalse,
          reason: 'Segment 0 focus node must NOT hijack focus');
    });

    testWidgets(
        'Focus restoration targets segment containing non-collapsed selection endpoint',
        (tester) async {
      final sdeKey = GlobalKey<NewSingleDocumentEditorState>();
      controller.setMarkdown('First Header\nMiddle Paragraph\nFinal Line');

      await tester.pumpWidget(
        buildTestableEditor(
          controller: controller,
          focusNode: parentFocusNode,
          sdeKey: sdeKey,
        ),
      );
      await tester.pumpAndSettle();

      final state = sdeKey.currentState!;
      expect(state.textSegments.length, equals(3));

      // Select text in segment 1 ("Middle Paragraph", offset 13 to 22)
      controller.selection =
          const TextSelection(baseOffset: 13, extentOffset: 22);

      parentFocusNode.requestFocus();
      await tester.pump();

      final focusNodes = state.focusNodes;
      expect(focusNodes[1]?.hasFocus, isTrue,
          reason: 'Segment 1 focus node should have focus');
      expect(focusNodes[0]?.hasFocus, isFalse,
          reason: 'Segment 0 focus node must NOT hijack focus');
      expect(controller.selection.baseOffset, equals(13));
      expect(controller.selection.extentOffset, equals(22));
    });
  });

  group('RTF-003: Inline Formatting & Selection Preservation', () {
    late RichTextEditingController controller;

    setUp(() {
      controller = RichTextEditingController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('Toggling bold on selection preserves selection bounds', () {
      controller.setMarkdown('Quick Notes Rich Text Editor');
      const targetSelection =
          TextSelection(baseOffset: 12, extentOffset: 21);
      controller.selection = targetSelection;

      controller.toggleStyleAttribute('bold');

      expect(controller.selection, equals(targetSelection));
      for (int i = 12; i < 21; i++) {
        expect(controller.styledChars[i].style.bold, isTrue);
      }
      expect(controller.styledChars[0].style.bold, isFalse);
    });

    test('Consecutive formatting operations accumulate without losing selection',
        () {
      controller.setMarkdown('Formatted sample text');
      const targetSelection =
          TextSelection(baseOffset: 10, extentOffset: 16);
      controller.selection = targetSelection;

      controller.toggleStyleAttribute('bold');
      controller.toggleStyleAttribute('italic');
      controller.toggleStyleAttribute('underline');

      expect(controller.selection, equals(targetSelection));
      for (int i = 10; i < 16; i++) {
        expect(controller.styledChars[i].style.bold, isTrue);
        expect(controller.styledChars[i].style.italic, isTrue);
        expect(controller.styledChars[i].style.underline, isTrue);
      }
    });

    test('Strikethrough toggles cleanly on selected text', () {
      controller.setMarkdown('Task to be cancelled');
      controller.selection =
          const TextSelection(baseOffset: 0, extentOffset: 4);

      controller.toggleStyleAttribute('strikethrough');
      expect(controller.styledChars[0].style.strikethrough, isTrue);
      expect(controller.selection,
          equals(const TextSelection(baseOffset: 0, extentOffset: 4)));
    });
  });

  group('RTF-012: Rich-Text Link Insertion & Persistence', () {
    late RichTextEditingController controller;

    setUp(() {
      controller = RichTextEditingController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('setLinkForSelection applies linkUrl without inserting raw markdown syntax',
        () {
      const originalText = 'Visit our website for documentation';
      controller.setMarkdown(originalText);

      const sel = TextSelection(baseOffset: 10, extentOffset: 17);
      controller.selection = sel;

      controller.setLinkForSelection('https://flutter.dev');

      expect(controller.text, equals(originalText),
          reason: 'Plain text must not be corrupted with raw markdown syntax');

      for (int i = 10; i < 17; i++) {
        expect(controller.styledChars[i].style.linkUrl,
            equals('https://flutter.dev'));
      }
      expect(controller.styledChars[9].style.linkUrl, isNull);
      expect(controller.styledChars[17].style.linkUrl, isNull);
      expect(controller.selection, equals(sel));
    });

    test('setLinkForSelection preserves existing inline styles (e.g. Bold & Italic)',
        () {
      controller.setMarkdown('Important styled reference');
      controller.selection =
          const TextSelection(baseOffset: 10, extentOffset: 16);
      controller.toggleStyleAttribute('bold');
      controller.toggleStyleAttribute('italic');

      controller.setLinkForSelection('https://quicknotes.app');

      for (int i = 10; i < 16; i++) {
        expect(controller.styledChars[i].style.bold, isTrue,
            reason: 'Bold must be preserved');
        expect(controller.styledChars[i].style.italic, isTrue,
            reason: 'Italic must be preserved');
        expect(controller.styledChars[i].style.linkUrl,
            equals('https://quicknotes.app'),
            reason: 'linkUrl must be applied');
      }
    });

    test('removeLinkForSelection clears linkUrl while preserving other styles',
        () {
      controller.setMarkdown('Styled linked text');
      controller.selection =
          const TextSelection(baseOffset: 0, extentOffset: 6);
      controller.toggleStyleAttribute('bold');
      controller.setLinkForSelection('https://example.com');

      expect(controller.styledChars[0].style.bold, isTrue);
      expect(controller.styledChars[0].style.linkUrl, isNotNull);

      controller.removeLinkForSelection();
      expect(controller.styledChars[0].style.bold, isTrue,
          reason: 'Bold must be preserved after link removal');
      expect(controller.styledChars[0].style.linkUrl, isNull,
          reason: 'linkUrl must be cleared');
    });

    test('Collapsed selection insertion inserts text and applies link', () {
      controller.setMarkdown('Prefix  suffix');
      controller.selection = const TextSelection.collapsed(offset: 7);

      controller.setLinkForSelection('https://dart.dev', text: 'Dart');

      expect(controller.text, equals('Prefix Dart suffix'));
      expect(controller.selection,
          equals(const TextSelection.collapsed(offset: 11)));

      for (int i = 7; i < 11; i++) {
        expect(controller.styledChars[i].style.linkUrl,
            equals('https://dart.dev'));
      }
    });

    test('Link round-trips cleanly through Markdown serialization and parsing',
        () {
      controller.setMarkdown('Check the link here');
      controller.selection =
          const TextSelection(baseOffset: 10, extentOffset: 14);
      controller.setLinkForSelection('https://example.com');

      final markdown = generateMarkdownFromStyledChars(controller.styledChars);
      expect(markdown, contains('[link](https://example.com)'));

      final roundTripController = RichTextEditingController();
      roundTripController.setMarkdown(markdown);

      expect(roundTripController.text, equals('Check the link here'));
      for (int i = 10; i < 14; i++) {
        expect(roundTripController.styledChars[i].style.linkUrl,
            equals('https://example.com'),
            reason: 'linkUrl must survive round trip');
      }
      roundTripController.dispose();
    });
  });

  group('RTF-002 & RTF-004: Toolbar Navigation & Drawer Persistence in NoteEditorScreen', () {
    late _MockNotesRepository notesRepo;
    late _MockFoldersRepository foldersRepo;
    late NotesProvider notesProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues(
          {'active_user_id': 'test-user-rtf'});
      await SessionManager().init();
      await SessionManager().saveSession(
        userId: 'test-user-rtf',
        sessionType: SessionType.guest,
      );

      notesRepo = _MockNotesRepository();
      foldersRepo = _MockFoldersRepository();
      notesProvider = NotesProvider(
        notesRepository: notesRepo,
        foldersRepository: foldersRepo,
      );
    });

    Widget createTestEditorApp({Note? note}) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<NotesProvider>.value(value: notesProvider),
        ],
        child: MaterialApp(
          home: NoteEditorScreen(note: note),
        ),
      );
    }

    Note createTestNote({
      required String id,
      required String title,
      required String content,
    }) {
      return Note(
        id: id,
        title: title,
        content: content,
        tags: const [],
        attachments: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        colorValue: 0,
      );
    }

    testWidgets(
        'RTF-002: Selecting text does NOT automatically navigate toolbar PageView to Page 0',
        (tester) async {
      final note = createTestNote(
        id: 'test_note_rtf_002',
        title: 'Title',
        content: 'This is editable sample text inside the editor',
      );

      await tester.pumpWidget(createTestEditorApp(note: note));
      await tester.pumpAndSettle();

      // Find the PageView
      final pageViewFinder = find.byType(PageView);
      expect(pageViewFinder, findsOneWidget);
      final pageView = tester.widget<PageView>(pageViewFinder);
      final pageController = pageView.controller!;

      // Initial page is Page 1 (formatting tools)
      expect(pageController.page?.round() ?? pageController.initialPage, equals(1));

      // Select text in the document
      final sdeFinder = find.byType(NewSingleDocumentEditor);
      expect(sdeFinder, findsOneWidget);
      final sdeWidget = tester.widget<NewSingleDocumentEditor>(sdeFinder);
      sdeWidget.controller.selection =
          const TextSelection(baseOffset: 8, extentOffset: 16);
      await tester.pumpAndSettle();

      // After selection, page MUST remain at Page 1, NOT animated to 0
      expect(pageController.page?.round() ?? pageController.initialPage, equals(1),
          reason: 'Selecting text must not auto-navigate toolbar to Page 0');
    });

    testWidgets(
        'RTF-004: Formatting drawer remains open across document mutations, supports consecutive operations, switching, and explicit dismissal',
        (tester) async {
      final note = createTestNote(
        id: 'test_note_rtf_004',
        title: 'Title',
        content: 'Formatted paragraph text',
      );

      await tester.pumpWidget(createTestEditorApp(note: note));
      await tester.pumpAndSettle();

      // Tap Alignment category icon in PageView to open Alignment subsection
      final alignmentCategoryBtn = find.descendant(
        of: find.byType(PageView),
        matching: find.byIcon(Icons.format_align_left_rounded),
      );
      expect(alignmentCategoryBtn, findsOneWidget);
      await tester.tap(alignmentCategoryBtn);
      await tester.pumpAndSettle();

      // Verify Alignment subsection is open (shows Align Center, Align Left, etc.)
      final alignCenterBtn = find.byTooltip('Align Center');
      expect(alignCenterBtn, findsOneWidget,
          reason: 'Alignment subsection should be open');

      // Select "Formatted" (indices 0..9)
      final sdeFinder = find.byType(NewSingleDocumentEditor);
      final sdeWidget = tester.widget<NewSingleDocumentEditor>(sdeFinder);
      sdeWidget.controller.selection =
          const TextSelection(baseOffset: 0, extentOffset: 9);
      await tester.pumpAndSettle();

      // 1. Apply first formatting operation (Align Center)
      await tester.tap(alignCenterBtn);
      await tester.pumpAndSettle();

      // 2. Confirm the category remains open (Align Center & Align Left are still visible!)
      expect(find.byTooltip('Align Center'), findsOneWidget,
          reason: 'Drawer must remain open after first formatting operation');
      expect(find.byTooltip('Align Left'), findsOneWidget);

      // 3. Apply a second operation without reopening the category (Align Left)
      await tester.tap(find.byTooltip('Align Left'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Align Center'), findsOneWidget,
          reason: 'Drawer remains open after consecutive formatting operation');

      // 4. Switch between categories: Tap List category icon in PageView
      final listCategoryBtn = find.descendant(
        of: find.byType(PageView),
        matching: find.byIcon(Icons.add_task_rounded),
      );
      expect(listCategoryBtn, findsOneWidget);
      await tester.tap(listCategoryBtn);
      await tester.pumpAndSettle();

      // Alignment subsection is dismissed, and List subsection is now active
      expect(find.byTooltip('Align Center'), findsNothing);
      expect(find.byTooltip('Bullet List'), findsOneWidget,
          reason: 'List subsection is now open after switching categories');

      // 5. Explicitly dismiss the drawer: Tap List category icon again
      await tester.tap(listCategoryBtn);
      await tester.pumpAndSettle();

      expect(find.byTooltip('Bullet List'), findsNothing,
          reason: 'Explicitly tapping active category icon dismisses the drawer');
    });
  });
}
