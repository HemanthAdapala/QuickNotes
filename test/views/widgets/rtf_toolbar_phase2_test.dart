// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';
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

    late final MessageHandler fontHandler;
    fontHandler = (ByteData? message) async {
      if (message == null) return null;
      final Uint8List list = message.buffer
          .asUint8List(message.offsetInBytes, message.lengthInBytes);
      final String key = utf8.decode(list);
      if (key.startsWith('google_fonts/')) {
        return ByteData(16);
      }
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null);
      try {
        return await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .send('flutter/assets', message);
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler('flutter/assets', fontHandler);
      }
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', fontHandler);

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

  group('RTF-005: Mixed-Format Selection State (Controller Unit Tests)', () {
    test('Correctly reports uniformly active, uniformly inactive, and mixed states for bold', () {
      final controller = RichTextEditingController();
      controller.text = 'Hello World';
      for (int i = 0; i < 5; i++) {
        controller.styledChars[i] = StyledChar(
          char: controller.styledChars[i].char,
          style: const Style(bold: true),
        );
      }

      // 1. Uniformly bold selection: [0..5]
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
      expect(controller.getFormatState('bold'), equals(FormatState.active));

      // 2. Uniformly non-bold selection: [6..11]
      controller.selection = const TextSelection(baseOffset: 6, extentOffset: 11);
      expect(controller.getFormatState('bold'), equals(FormatState.inactive));

      // 3. Mixed selection: [0..11] ("Hello World")
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 11);
      expect(controller.getFormatState('bold'), equals(FormatState.mixed));

      // 4. Mixed selection: [3..8] ("lo Wo")
      controller.selection = const TextSelection(baseOffset: 3, extentOffset: 8);
      expect(controller.getFormatState('bold'), equals(FormatState.mixed));
    });

    test('Reports three states for italic, underline, and strikethrough', () {
      final controller = RichTextEditingController();
      controller.text = 'ABCDEF';
      for (int i = 0; i < 3; i++) {
        controller.styledChars[i] = StyledChar(
          char: controller.styledChars[i].char,
          style: const Style(italic: true, underline: true, strikethrough: true),
        );
      }

      for (final attr in ['italic', 'underline', 'strikethrough']) {
        // Uniform active
        controller.selection = const TextSelection(baseOffset: 0, extentOffset: 3);
        expect(controller.getFormatState(attr), equals(FormatState.active), reason: '$attr active');

        // Uniform inactive
        controller.selection = const TextSelection(baseOffset: 3, extentOffset: 6);
        expect(controller.getFormatState(attr), equals(FormatState.inactive), reason: '$attr inactive');

        // Mixed
        controller.selection = const TextSelection(baseOffset: 1, extentOffset: 5);
        expect(controller.getFormatState(attr), equals(FormatState.mixed), reason: '$attr mixed');
      }
    });

    test('Collapsed cursor respects insertion-style semantics and toggling', () {
      final controller = RichTextEditingController();
      controller.text = 'Hello';

      // 1. Position collapsed cursor at offset 2 (pointing to unformatted text)
      controller.selection = const TextSelection.collapsed(offset: 2);
      expect(controller.getFormatState('bold'), equals(FormatState.inactive));
      expect(controller.getFormatState('italic'), equals(FormatState.inactive));

      // 2. Toggle bold for upcoming typed text at cursor
      controller.toggleStyleAttribute('bold');
      expect(controller.getFormatState('bold'), equals(FormatState.active));
      expect(controller.getFormatState('italic'), equals(FormatState.inactive));

      // 3. Toggle italic for upcoming typed text at cursor
      controller.toggleStyleAttribute('italic');
      expect(controller.getFormatState('bold'), equals(FormatState.active));
      expect(controller.getFormatState('italic'), equals(FormatState.active));

      // 4. Toggle bold off
      controller.toggleStyleAttribute('bold');
      expect(controller.getFormatState('bold'), equals(FormatState.inactive));
      expect(controller.getFormatState('italic'), equals(FormatState.active));
    });

    test('Toggling formatting on a mixed selection produces uniformly active, then inactive state', () {
      final controller = RichTextEditingController();
      controller.text = 'MixedText';
      for (int i = 0; i < 4; i++) {
        controller.styledChars[i] = StyledChar(
          char: controller.styledChars[i].char,
          style: const Style(bold: true),
        );
      }

      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 9);
      expect(controller.getFormatState('bold'), equals(FormatState.mixed));

      // Toggle 1: Since not all have bold, it should make ALL bold
      controller.toggleStyleAttribute('bold');
      expect(controller.getFormatState('bold'), equals(FormatState.active));
      for (int i = 0; i < 9; i++) {
        expect(controller.styledChars[i].style.bold, isTrue, reason: 'Char $i should be bold');
      }

      // Toggle 2: Since all have bold, it should make ALL non-bold
      controller.toggleStyleAttribute('bold');
      expect(controller.getFormatState('bold'), equals(FormatState.inactive));
      for (int i = 0; i < 9; i++) {
        expect(controller.styledChars[i].style.bold, isFalse, reason: 'Char $i should be non-bold');
      }

      // Verify text content and selection bounds are preserved
      expect(controller.text, equals('MixedText'));
      expect(controller.selection, equals(const TextSelection(baseOffset: 0, extentOffset: 9)));
    });
  });

  group('RTF Phase 2 Correction: Mixed Highlighter State', () {
    test('Correctly reports active, inactive, and mixed states for highlight', () {
      final controller = RichTextEditingController();
      controller.text = 'Highlight Sample';
      const yellowHighlight = Color(0xFFFFFF00);

      for (int i = 0; i < 9; i++) {
        controller.styledChars[i] = StyledChar(
          char: controller.styledChars[i].char,
          style: const Style(highlight: yellowHighlight),
        );
      }

      // 1. Uniformly highlighted: [0..9] ("Highlight")
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 9);
      expect(controller.getFormatState('highlight'), equals(FormatState.active));

      // 2. Uniformly unhighlighted: [10..16] ("Sample")
      controller.selection = const TextSelection(baseOffset: 10, extentOffset: 16);
      expect(controller.getFormatState('highlight'), equals(FormatState.inactive));

      // 3. Mixed highlight: [0..16] ("Highlight Sample")
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 16);
      expect(controller.getFormatState('highlight'), equals(FormatState.mixed));

      // 4. Mixed highlight partial overlap: [5..12]
      controller.selection = const TextSelection(baseOffset: 5, extentOffset: 12);
      expect(controller.getFormatState('highlight'), equals(FormatState.mixed));
    });

    test('Collapsed-cursor highlighter behavior respects insertion styling', () {
      final controller = RichTextEditingController();
      controller.text = 'Plain text';

      controller.selection = const TextSelection.collapsed(offset: 3);
      expect(controller.getFormatState('highlight'), equals(FormatState.inactive));

      // Toggle highlight on collapsed cursor
      controller.toggleStyleAttribute('highlight', value: const Color(0xFFFFFF00));
      expect(controller.getFormatState('highlight'), equals(FormatState.active));

      // Toggle highlight off
      controller.toggleStyleAttribute('highlight', value: const Color(0xFFFFFF00));
      expect(controller.getFormatState('highlight'), equals(FormatState.inactive));
    });

    test('Toggling highlight on a mixed selection highlights all, then removes all', () {
      final controller = RichTextEditingController();
      controller.text = 'PartialHighlight';
      const yellow = Color(0xFFFFFF00);

      // Highlight first 7 characters
      for (int i = 0; i < 7; i++) {
        controller.styledChars[i] = StyledChar(
          char: controller.styledChars[i].char,
          style: const Style(highlight: yellow),
        );
      }

      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 16);
      expect(controller.getFormatState('highlight'), equals(FormatState.mixed));

      // Toggle 1: applies highlight to all characters
      controller.toggleStyleAttribute('highlight', value: yellow);
      expect(controller.getFormatState('highlight'), equals(FormatState.active));
      for (int i = 0; i < 16; i++) {
        expect(controller.styledChars[i].style.highlight, equals(yellow));
      }

      // Toggle 2: removes highlight from all characters
      controller.toggleStyleAttribute('highlight', value: yellow);
      expect(controller.getFormatState('highlight'), equals(FormatState.inactive));
      for (int i = 0; i < 16; i++) {
        expect(controller.styledChars[i].style.highlight, isNull);
      }
    });
  });

  group('RTF Phase 2 Correction: Mixed Paragraph Alignment State', () {
    test('Single paragraph reports correct alignment', () {
      final controller = RichTextEditingController();
      controller.text = 'Single left paragraph';
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 6);

      expect(controller.getAlignmentFormatState(TextAlign.left), equals(FormatState.active));
      expect(controller.getAlignmentFormatState(TextAlign.center), equals(FormatState.inactive));
      expect(controller.getAlignmentFormatState(TextAlign.right), equals(FormatState.inactive));
      expect(controller.getAlignmentFormatState(TextAlign.justify), equals(FormatState.inactive));
    });

    test('Selection spanning paragraphs all aligned left reports Left as active', () {
      final controller = RichTextEditingController();
      controller.text = 'First paragraph\nSecond paragraph\nThird paragraph';
      // Selection spans all three paragraphs
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 47);

      expect(controller.getAlignmentFormatState(TextAlign.left), equals(FormatState.active));
      expect(controller.getAlignmentFormatState(TextAlign.center), equals(FormatState.inactive));
      expect(controller.getAlignmentFormatState(TextAlign.right), equals(FormatState.inactive));
      expect(controller.getAlignmentFormatState(TextAlign.justify), equals(FormatState.inactive));
    });

    test('Selection spanning paragraphs all aligned center reports Center as active', () {
      final controller = RichTextEditingController();
      controller.text = 'Para One\nPara Two';
      // Set all to center
      for (int i = 0; i < controller.styledChars.length; i++) {
        controller.styledChars[i] = StyledChar(
          char: controller.styledChars[i].char,
          style: const Style(align: TextAlign.center),
        );
      }
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 17);

      expect(controller.getAlignmentFormatState(TextAlign.center), equals(FormatState.active));
      expect(controller.getAlignmentFormatState(TextAlign.left), equals(FormatState.inactive));
      expect(controller.getAlignmentFormatState(TextAlign.right), equals(FormatState.inactive));
    });

    test('Selection spanning differing alignments does NOT falsely report Left as active', () {
      final controller = RichTextEditingController();
      controller.text = 'Left paragraph\nCenter paragraph';

      // Line 1: left (default)
      // Line 2 (index 15..31): center
      for (int i = 15; i < controller.styledChars.length; i++) {
        controller.styledChars[i] = StyledChar(
          char: controller.styledChars[i].char,
          style: const Style(align: TextAlign.center),
        );
      }

      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 31);

      // Critical check: Left must NOT be reported as uniformly active!
      expect(controller.getAlignmentFormatState(TextAlign.left), equals(FormatState.mixed));
      // Center must also be reported as mixed
      expect(controller.getAlignmentFormatState(TextAlign.center), equals(FormatState.mixed));
      // Right and Justify are completely inactive
      expect(controller.getAlignmentFormatState(TextAlign.right), equals(FormatState.inactive));
      expect(controller.getAlignmentFormatState(TextAlign.justify), equals(FormatState.inactive));
    });

    test('Collapsed cursor alignment reports the alignment of the containing paragraph', () {
      final controller = RichTextEditingController();
      controller.text = 'Line One\nLine Two';
      // Line Two is right aligned
      for (int i = 9; i < controller.styledChars.length; i++) {
        controller.styledChars[i] = StyledChar(
          char: controller.styledChars[i].char,
          style: const Style(align: TextAlign.right),
        );
      }

      // Cursor in Line One
      controller.selection = const TextSelection.collapsed(offset: 3);
      expect(controller.getAlignmentFormatState(TextAlign.left), equals(FormatState.active));
      expect(controller.getAlignmentFormatState(TextAlign.right), equals(FormatState.inactive));

      // Cursor in Line Two
      controller.selection = const TextSelection.collapsed(offset: 12);
      expect(controller.getAlignmentFormatState(TextAlign.right), equals(FormatState.active));
      expect(controller.getAlignmentFormatState(TextAlign.left), equals(FormatState.inactive));
    });

    test('Applying alignment to mixed paragraphs applies to all paragraphs', () {
      final controller = RichTextEditingController();
      controller.text = 'First line\nSecond line';
      // First line left, second line right
      for (int i = 11; i < controller.styledChars.length; i++) {
        controller.styledChars[i] = StyledChar(
          char: controller.styledChars[i].char,
          style: const Style(align: TextAlign.right),
        );
      }

      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 22);
      expect(controller.getAlignmentFormatState(TextAlign.center), equals(FormatState.inactive));
      expect(controller.getAlignmentFormatState(TextAlign.left), equals(FormatState.mixed));
      expect(controller.getAlignmentFormatState(TextAlign.right), equals(FormatState.mixed));

      // Apply Center alignment across the selection
      controller.toggleParagraphStyle('align-center');

      // Now all paragraphs are Center
      expect(controller.getAlignmentFormatState(TextAlign.center), equals(FormatState.active));
      expect(controller.getAlignmentFormatState(TextAlign.left), equals(FormatState.inactive));
      expect(controller.getAlignmentFormatState(TextAlign.right), equals(FormatState.inactive));
    });
  });

  group('RTF-013: Markdown Parser Safety (Serialization & Parsing Integrity)', () {
    test('Literal <span> and </span> tags survive serialization and deserialization intact', () {
      const input = 'This is an HTML <span> and a closing </span> tag.';
      final parsed = parseMarkdownToStyledChars(input);
      final textResult = parsed.map((sc) => sc.char).join();
      expect(textResult, equals(input));

      final serialized = generateMarkdownFromStyledChars(parsed);
      expect(serialized, equals(input));

      // Repeated round-trip (2nd pass)
      final roundTrip2 = parseMarkdownToStyledChars(serialized);
      final serialized2 = generateMarkdownFromStyledChars(roundTrip2);
      expect(serialized2, equals(input));
    });

    test('Literal <span style="..."> survives save/reopen without loss', () {
      const input = 'Use <span style="font-weight: bold;"> for custom styling.';
      final parsed = parseMarkdownToStyledChars(input);
      final textResult = parsed.map((sc) => sc.char).join();
      expect(textResult, equals(input));

      final serialized = generateMarkdownFromStyledChars(parsed);
      expect(serialized, equals(input));
    });

    test('Unclosed <span and HTML-like comparisons survive correctly', () {
      const input = 'Comparison: <span and x > y and a < b';
      final parsed = parseMarkdownToStyledChars(input);
      final textResult = parsed.map((sc) => sc.char).join();
      expect(textResult, equals(input));

      final serialized = generateMarkdownFromStyledChars(parsed);
      expect(serialized, equals(input));
    });

    test('Literal brackets and parentheses adjacent to HTML text survive', () {
      const input = '[note] (<span class="alert">) and {literal}';
      final parsed = parseMarkdownToStyledChars(input);
      final textResult = parsed.map((sc) => sc.char).join();
      expect(textResult, equals(input));

      final serialized = generateMarkdownFromStyledChars(parsed);
      expect(serialized, equals(input));
    });

    test('Existing valid rich-text color and highlight spans continue to work correctly', () {
      const input = '<span color="0xffff0000" highlight="0xffffff00">Colored and Highlighted</span>';
      final parsed = parseMarkdownToStyledChars(input);
      final textResult = parsed.map((sc) => sc.char).join();
      expect(textResult, equals('Colored and Highlighted'));
      for (final sc in parsed) {
        expect(sc.style.color, equals(const Color(0xffff0000)));
        expect(sc.style.highlight, equals(const Color(0xffffff00)));
      }

      final serialized = generateMarkdownFromStyledChars(parsed);
      expect(serialized, contains('color="0xffff0000"'));
      expect(serialized, contains('highlight="0xffffff00"'));
      expect(serialized, contains('</span>'));
    });

    test('Rich-text links adjacent to literal span markup round-trip cleanly', () {
      const input = '[QuickNotes Link](https://quicknotes.app) and literal <span>tag</span>';
      final parsed = parseMarkdownToStyledChars(input);
      final textResult = parsed.map((sc) => sc.char).join();
      expect(textResult, equals('QuickNotes Link and literal <span>tag</span>'));

      final serialized = generateMarkdownFromStyledChars(parsed);
      expect(serialized, equals(input));

      // 2nd cycle
      final parsed2 = parseMarkdownToStyledChars(serialized);
      final serialized2 = generateMarkdownFromStyledChars(parsed2);
      expect(serialized2, equals(input));
    });

    test('Empty strings and boundary text parse without errors', () {
      expect(parseMarkdownToStyledChars('').isEmpty, isTrue);
      expect(generateMarkdownFromStyledChars([]), equals(''));

      const boundarySpan = '<span>';
      final parsed = parseMarkdownToStyledChars(boundarySpan);
      expect(parsed.map((sc) => sc.char).join(), equals('<span>'));
      expect(generateMarkdownFromStyledChars(parsed), equals('<span>'));
    });
  });

  group('RTF-005 & Corrections: Toolbar Mixed State UI Representation in NoteEditorScreen', () {
    late _MockNotesRepository notesRepo;
    late _MockFoldersRepository foldersRepo;
    late NotesProvider notesProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues(
          {'active_user_id': 'test-user-rtf-phase2'});
      await SessionManager().init();
      await SessionManager().saveSession(
        userId: 'test-user-rtf-phase2',
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

    testWidgets('Aa toolbar buttons display mixed indicator when selection has mixed formatting',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final note = createTestNote(
        id: 'mixed-test-1',
        title: 'Mixed Formatting Note',
        content: '**Hello** World',
      );
      await notesRepo.insertNote(note);

      await tester.pumpWidget(createTestEditorApp(note: note));
      await tester.pumpAndSettle();

      final sdeFinder = find.byType(NewSingleDocumentEditor);
      expect(sdeFinder, findsOneWidget);

      final sdeWidget = tester.widget<NewSingleDocumentEditor>(sdeFinder);
      final controller = sdeWidget.controller;

      // Tap Aa category icon in PageView to open Aa subsection
      final aaCategoryBtn = find.descendant(
        of: find.byType(PageView),
        matching: find.text('Aa'),
      );
      expect(aaCategoryBtn, findsOneWidget);
      await tester.tap(aaCategoryBtn);
      await tester.pumpAndSettle();

      // Case 1: Select "Hello" (indices 0..5, uniformly bold)
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
      await tester.pumpAndSettle();

      expect(controller.getFormatState('bold'), equals(FormatState.active));
      final boldButtonActive = find.byTooltip('Bold');
      expect(boldButtonActive, findsOneWidget);

      // Case 2: Select "Hello World" (indices 0..11, mixed bold)
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 11);
      await tester.pumpAndSettle();

      expect(controller.getFormatState('bold'), equals(FormatState.mixed));
      final boldButtonMixed = find.byTooltip('Bold (Mixed)');
      expect(boldButtonMixed, findsOneWidget);

      // Verify visual indicator for mixed state: container decoration has a border
      final containerFinder = find.descendant(
        of: boldButtonMixed,
        matching: find.byType(Container),
      );
      expect(containerFinder, findsOneWidget);
      final Container containerWidget = tester.widget<Container>(containerFinder);
      final BoxDecoration decoration = containerWidget.decoration as BoxDecoration;
      expect(decoration.border, isNotNull, reason: 'Mixed button must have a distinguishing border');

      // Case 3: Select " World" (indices 5..11, uniformly unbolded)
      controller.selection = const TextSelection(baseOffset: 5, extentOffset: 11);
      await tester.pumpAndSettle();

      expect(controller.getFormatState('bold'), equals(FormatState.inactive));
      final boldButtonInactive = find.byTooltip('Bold');
      expect(boldButtonInactive, findsOneWidget);
    });

    testWidgets('Category page 1 highlighter button renders mixed indicator for partially highlighted text',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final note = createTestNote(
        id: 'mixed-highlighter-test',
        title: 'Highlighter Note',
        content: '<span highlight="0xffffff00">Highlighted</span> Plain',
      );
      await notesRepo.insertNote(note);

      await tester.pumpWidget(createTestEditorApp(note: note));
      await tester.pumpAndSettle();

      final sdeFinder = find.byType(NewSingleDocumentEditor);
      final sdeWidget = tester.widget<NewSingleDocumentEditor>(sdeFinder);
      final controller = sdeWidget.controller;

      // Select full text ("Highlighted Plain", indices 0..17, mixed highlight)
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 17);
      await tester.pumpAndSettle();

      expect(controller.getFormatState('highlight'), equals(FormatState.mixed));

      // Verify Category Page 1 highlighter button shows mixed tooltip and border
      final mixedHighlightBtn = find.byTooltip('Highlight (Mixed)');
      expect(mixedHighlightBtn, findsOneWidget);

      final containerFinder = find.descendant(
        of: mixedHighlightBtn,
        matching: find.byType(Container),
      );
      expect(containerFinder, findsOneWidget);
      final Container containerWidget = tester.widget<Container>(containerFinder);
      final BoxDecoration decoration = containerWidget.decoration as BoxDecoration;
      expect(decoration.border, isNotNull, reason: 'Category highlighter button must show border when mixed');

      // Select only highlighted part ("Highlighted", indices 0..11)
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 11);
      await tester.pumpAndSettle();

      expect(controller.getFormatState('highlight'), equals(FormatState.active));
      expect(find.byTooltip('Highlight'), findsOneWidget);

      // Select unhighlighted part ("Plain", indices 12..17)
      controller.selection = const TextSelection(baseOffset: 12, extentOffset: 17);
      await tester.pumpAndSettle();

      expect(controller.getFormatState('highlight'), equals(FormatState.inactive));
      expect(find.byTooltip('Highlight'), findsOneWidget);
    });

    testWidgets('Alignment subsection renders mixed indicator when paragraphs have differing alignments',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final note = createTestNote(
        id: 'mixed-align-test',
        title: 'Alignment Note',
        content: 'Left paragraph\n<p align="center">Center paragraph</p>',
      );
      await notesRepo.insertNote(note);

      await tester.pumpWidget(createTestEditorApp(note: note));
      await tester.pumpAndSettle();

      final sdeFinder = find.byType(NewSingleDocumentEditor);
      final sdeWidget = tester.widget<NewSingleDocumentEditor>(sdeFinder);
      final controller = sdeWidget.controller;

      // Open Alignment subsection
      final alignCategoryBtn = find.descendant(
        of: find.byType(PageView),
        matching: find.byIcon(Icons.format_align_left_rounded),
      );
      expect(alignCategoryBtn, findsOneWidget);
      await tester.tap(alignCategoryBtn);
      await tester.pumpAndSettle();

      // Select spanning both paragraphs
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 31);
      await tester.pumpAndSettle();

      // Critical assertion: Neither Left nor Center should be uniformly active!
      expect(controller.getAlignmentFormatState(TextAlign.left), equals(FormatState.mixed));
      expect(controller.getAlignmentFormatState(TextAlign.center), equals(FormatState.mixed));

      // Verify the UI buttons render mixed state tooltips
      expect(find.byTooltip('Align Left (Mixed)'), findsOneWidget);
      expect(find.byTooltip('Align Center (Mixed)'), findsOneWidget);

      // Align Right and Align Justify must be inactive
      expect(find.byTooltip('Align Right'), findsOneWidget);
      expect(find.byTooltip('Align Justify'), findsOneWidget);
    });
  });
}
