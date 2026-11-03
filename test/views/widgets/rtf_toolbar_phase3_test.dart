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

  group('RTF-015: Toolbar Accessibility Improvements', () {
    late _MockNotesRepository notesRepo;
    late _MockFoldersRepository foldersRepo;
    late NotesProvider notesProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues(
          {'active_user_id': 'test-user-rtf-phase3'});
      await SessionManager().init();
      await SessionManager().saveSession(
        userId: 'test-user-rtf-phase3',
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

    testWidgets('Collapsed formatting entry button exposes accessible label and button semantics',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final note = createTestNote(
        id: 'a11y-entry-test',
        title: 'Entry Button A11y',
        content: 'Sample text',
      );
      await notesRepo.insertNote(note);

      await tester.pumpWidget(createTestEditorApp(note: note));
      await tester.pumpAndSettle();

      // Navigate to Page 2 and collapse the toolbar
      final nextFinder = find.byTooltip('Next page');
      expect(nextFinder, findsOneWidget);
      await tester.tap(nextFinder);
      await tester.pumpAndSettle();

      final collapseFinder = find.byTooltip('Collapse Toolbar');
      expect(collapseFinder, findsOneWidget);
      await tester.tap(collapseFinder);
      await tester.pumpAndSettle();

      // Verify tooltip and semantics on entry button
      final entryFinder = find.byTooltip('Open formatting toolbar');
      expect(entryFinder, findsOneWidget);

      final semanticsFinder = find.byWidgetPredicate((w) =>
          w is Semantics &&
          w.properties.button == true &&
          w.properties.label == 'Open formatting toolbar');
      expect(semanticsFinder, findsOneWidget);
    });

    testWidgets('Category page navigation arrows expose accessible tooltips and enabled/button semantics',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final note = createTestNote(
        id: 'a11y-arrows-test',
        title: 'Arrows A11y',
        content: 'Sample text',
      );
      await notesRepo.insertNote(note);

      await tester.pumpWidget(createTestEditorApp(note: note));
      await tester.pumpAndSettle();

      // On initial load, currentPage = 1. Both Previous and Next page arrows are visible and enabled.
      final prevFinder = find.byTooltip('Previous page');
      expect(prevFinder, findsOneWidget);

      final nextFinder = find.byTooltip('Next page');
      expect(nextFinder, findsOneWidget);

      // Verify semantics
      final prevSemantics = find.byWidgetPredicate((w) =>
          w is Semantics &&
          w.properties.button == true &&
          w.properties.label == 'Previous page');
      expect(prevSemantics, findsOneWidget);

      final nextSemantics = find.byWidgetPredicate((w) =>
          w is Semantics &&
          w.properties.button == true &&
          w.properties.label == 'Next page');
      expect(nextSemantics, findsOneWidget);
    });

    testWidgets('Page 0 selection buttons expose accessible tooltips and semantics',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final note = createTestNote(
        id: 'a11y-page0-test',
        title: 'Page 0 Selection Actions',
        content: 'Sample text',
      );
      await notesRepo.insertNote(note);

      await tester.pumpWidget(createTestEditorApp(note: note));
      await tester.pumpAndSettle();

      // Navigate to Page 0 using the Previous page arrow
      final prevBtn = find.byTooltip('Previous page');
      expect(prevBtn, findsOneWidget);
      await tester.tap(prevBtn);
      await tester.pumpAndSettle();

      // Verify Cut, Copy, Select All, Delete have tooltips and semantics
      for (final label in ['Cut', 'Copy', 'Select All', 'Delete']) {
        final btnFinder = find.byTooltip(label);
        expect(btnFinder, findsOneWidget, reason: '$label button must have tooltip');

        final semanticsFinder = find.byWidgetPredicate((w) =>
            w is Semantics &&
            w.properties.button == true &&
            w.properties.label == label);
        expect(semanticsFinder, findsOneWidget, reason: '$label button must have semantics');
      }
    });

    testWidgets('Page 1 category buttons expose accessible tooltips and selection state',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final note = createTestNote(
        id: 'a11y-page1-test',
        title: 'Page 1 Categories',
        content: 'Sample text',
      );
      await notesRepo.insertNote(note);

      await tester.pumpWidget(createTestEditorApp(note: note));
      await tester.pumpAndSettle();

      // Page 1 is active by default
      expect(find.byTooltip('Text Formatting'), findsOneWidget);
      expect(find.byTooltip('Paragraph Alignment'), findsOneWidget);
      expect(find.byTooltip('Lists and Tasks'), findsOneWidget);
      expect(find.byTooltip('Highlight'), findsOneWidget);
      expect(find.byTooltip('Attachments and Links'), findsOneWidget);

      // Tap "Text Formatting" (Aa) to open its drawer
      await tester.tap(find.byTooltip('Text Formatting'));
      await tester.pumpAndSettle();

      // Verify "Text Formatting" button now has selected: true in Semantics
      final aaSemantics = find.byWidgetPredicate((w) =>
          w is Semantics &&
          w.properties.button == true &&
          w.properties.label == 'Text Formatting' &&
          w.properties.selected == true);
      expect(aaSemantics, findsOneWidget);
    });

    testWidgets('Page 2 category buttons expose accessible tooltips and semantics',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final note = createTestNote(
        id: 'a11y-page2-test',
        title: 'Page 2 Utilities',
        content: 'Sample text',
      );
      await notesRepo.insertNote(note);

      await tester.pumpWidget(createTestEditorApp(note: note));
      await tester.pumpAndSettle();

      // Navigate to Page 2 using the Next page arrow
      final nextBtn = find.byTooltip('Next page');
      expect(nextBtn, findsOneWidget);
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();

      for (final label in ['Headings', 'Paper Settings', 'Hide Keyboard', 'Collapse Toolbar']) {
        final btnFinder = find.byTooltip(label);
        expect(btnFinder, findsOneWidget, reason: '$label button must have tooltip');

        final semanticsFinder = find.byWidgetPredicate((w) =>
            w is Semantics &&
            w.properties.button == true &&
            w.properties.label == label);
        expect(semanticsFinder, findsOneWidget, reason: '$label button must have semantics');
      }
    });

    testWidgets('Subsection formatting buttons convey active, inactive, and mixed states accessibly',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final note = createTestNote(
        id: 'a11y-subsection-states',
        title: 'Subsection States A11y',
        content: '**BoldWord** NormalWord',
      );
      await notesRepo.insertNote(note);

      await tester.pumpWidget(createTestEditorApp(note: note));
      await tester.pumpAndSettle();

      final sdeFinder = find.byType(NewSingleDocumentEditor);
      final sdeWidget = tester.widget<NewSingleDocumentEditor>(sdeFinder);
      final controller = sdeWidget.controller;

      // Open Aa subsection
      await tester.tap(find.byTooltip('Text Formatting'));
      await tester.pumpAndSettle();

      // Case 1: Select "BoldWord" (indices 0..8, uniformly bold)
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 8);
      await tester.pumpAndSettle();

      // Bold button should have selected == true
      final boldActiveSemantics = find.byWidgetPredicate((w) =>
          w is Semantics &&
          w.properties.button == true &&
          w.properties.label == 'Bold' &&
          w.properties.selected == true);
      expect(boldActiveSemantics, findsOneWidget);

      // Case 2: Select "BoldWord NormalWord" (indices 0..19, mixed bold)
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 19);
      await tester.pumpAndSettle();

      // Bold button should convey mixed state accessibly via label: 'Bold (Mixed)'
      final boldMixedSemantics = find.byWidgetPredicate((w) =>
          w is Semantics &&
          w.properties.button == true &&
          w.properties.label == 'Bold (Mixed)' &&
          w.properties.selected == false);
      expect(boldMixedSemantics, findsOneWidget);

      // Case 3: Select "NormalWord" (indices 9..19, inactive bold)
      controller.selection = const TextSelection(baseOffset: 9, extentOffset: 19);
      await tester.pumpAndSettle();

      final boldInactiveSemantics = find.byWidgetPredicate((w) =>
          w is Semantics &&
          w.properties.button == true &&
          w.properties.label == 'Bold' &&
          w.properties.selected == false);
      expect(boldInactiveSemantics, findsOneWidget);
    });

    testWidgets('Alignment subsection buttons convey active and mixed states accessibly',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final note = createTestNote(
        id: 'a11y-align-states',
        title: 'Alignment States A11y',
        content: 'Left line\n<p align="center">Center line</p>',
      );
      await notesRepo.insertNote(note);

      await tester.pumpWidget(createTestEditorApp(note: note));
      await tester.pumpAndSettle();

      final sdeFinder = find.byType(NewSingleDocumentEditor);
      final sdeWidget = tester.widget<NewSingleDocumentEditor>(sdeFinder);
      final controller = sdeWidget.controller;

      // Open Alignment subsection
      await tester.tap(find.byTooltip('Paragraph Alignment'));
      await tester.pumpAndSettle();

      // Select spanning both paragraphs
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 21);
      await tester.pumpAndSettle();

      // Both Left and Center must convey mixed state accessibly without visual-only cues
      final leftMixedSemantics = find.byWidgetPredicate((w) =>
          w is Semantics &&
          w.properties.button == true &&
          w.properties.label == 'Align Left (Mixed)' &&
          w.properties.selected == false);
      expect(leftMixedSemantics, findsOneWidget);

      final centerMixedSemantics = find.byWidgetPredicate((w) =>
          w is Semantics &&
          w.properties.button == true &&
          w.properties.label == 'Align Center (Mixed)' &&
          w.properties.selected == false);
      expect(centerMixedSemantics, findsOneWidget);

      // Align Right must be inactive
      final rightInactiveSemantics = find.byWidgetPredicate((w) =>
          w is Semantics &&
          w.properties.button == true &&
          w.properties.label == 'Align Right' &&
          w.properties.selected == false);
      expect(rightInactiveSemantics, findsOneWidget);
    });
  });

  group('RTF-006: Dead Formatting Toolbar Removal Safety Verification', () {
    late _MockNotesRepository notesRepo;
    late _MockFoldersRepository foldersRepo;
    late NotesProvider notesProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues(
          {'active_user_id': 'test-user-rtf-phase3-deadcode'});
      await SessionManager().init();
      await SessionManager().saveSession(
        userId: 'test-user-rtf-phase3-deadcode',
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

    testWidgets('Active toolbar operations execute normally after obsolete toolbar removal',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final note = createTestNote(
        id: 'dead-code-safety-test',
        title: 'Safety Test',
        content: 'Testing active toolbar execution',
      );
      await notesRepo.insertNote(note);

      await tester.pumpWidget(createTestEditorApp(note: note));
      await tester.pumpAndSettle();

      final sdeFinder = find.byType(NewSingleDocumentEditor);
      final sdeWidget = tester.widget<NewSingleDocumentEditor>(sdeFinder);
      final controller = sdeWidget.controller;

      // Select "Testing"
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 7);
      await tester.pumpAndSettle();

      // Open Aa subsection
      await tester.tap(find.byTooltip('Text Formatting'));
      await tester.pumpAndSettle();

      // Tap Bold
      await tester.tap(find.byTooltip('Bold'));
      await tester.pumpAndSettle();

      // Verify bold was applied
      expect(controller.styledChars[0].style.bold, isTrue);

      // Tap Italic
      await tester.tap(find.byTooltip('Italic'));
      await tester.pumpAndSettle();
      expect(controller.styledChars[0].style.italic, isTrue);

      // Collapse toolbar via Page 2
      final nextBtn = find.byTooltip('Next page');
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();

      final collapseBtn = find.byTooltip('Collapse Toolbar');
      await tester.tap(collapseBtn);
      await tester.pumpAndSettle();

      // Toolbar is now collapsed, showing entry button
      expect(find.byTooltip('Open formatting toolbar'), findsOneWidget);
    });
  });
}
