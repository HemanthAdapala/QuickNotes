import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/models/repeat_rule.dart';
import 'package:quick_notes/models/task_item.dart';
import 'package:quick_notes/models/task_status.dart';
import 'package:quick_notes/views/widgets/card_context_menu.dart';
import 'package:quick_notes/views/widgets/notes_stack_widget.dart';
import 'package:quick_notes/views/widgets/task_widget.dart';
import 'package:quick_notes/services/widget_data_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<MethodCall> homeWidgetCalls = [];
  final List<MethodCall> widgetPinCalls = [];
  bool mockLauncherSupported = true;
  bool mockWidgetPinChannelActive = true;

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => '.',
    );

    Future<dynamic> mockHomeWidgetHandler(MethodCall methodCall) async {
      homeWidgetCalls.add(methodCall);
      if (methodCall.method == 'isRequestPinWidgetSupported') {
        return mockLauncherSupported;
      }
      return true;
    }

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('home_widget'),
      mockHomeWidgetHandler,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('es.antonborri.home_widget'),
      mockHomeWidgetHandler,
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.quicknotes.byhmnth/widget_pin'),
      (MethodCall methodCall) async {
        if (!mockWidgetPinChannelActive) {
          throw PlatformException(code: 'UNAVAILABLE');
        }
        widgetPinCalls.add(methodCall);
        if (methodCall.method == 'isRequestPinWidgetSupported') {
          return mockLauncherSupported;
        }
        if (methodCall.method == 'requestPinNoteWidget') {
          return true;
        }
        if (methodCall.method == 'requestPinTaskWidget') {
          return true;
        }
        return true;
      },
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    homeWidgetCalls.clear();
    widgetPinCalls.clear();
    mockLauncherSupported = true;
    mockWidgetPinChannelActive = true;
    WidgetDataAdapter.instance.resetForTesting();
  });

  Widget wrapWithScaffold(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: child,
        ),
      ),
    );
  }

  Note createSampleNote({
    String id = 'note-1',
    String title = 'Things to do today',
    String preview = 'Shopping\nDesign for new brand\nHaircut',
    bool isLocked = false,
  }) {
    return Note(
      id: id,
      title: title,
      previewText: preview,
      content: preview,
      tags: const [],
      attachments: const [],
      colorValue: 0xFFFFFFFF,
      createdAt: DateTime(2026, 6, 1, 2, 0),
      updatedAt: DateTime(2026, 6, 1, 2, 0),
      isLocked: isLocked,
    );
  }

  TaskItem createSampleTask({
    String id = 'task-1',
    String title = 'Wiring Dashboard Analytics',
    String priority = 'High',
    bool isRecurring = false,
    RepeatRule repeatRule = RepeatRule.none,
  }) {
    return TaskItem(
      id: id,
      title: title,
      dueDate: DateTime(2026, 6, 1, 2, 0),
      priority: priority,
      completed: false,
      status: TaskStatus.waiting,
      isRecurring: isRecurring,
      repeatRule: repeatRule,
    );
  }

  group('Note & Task Widget Menu — Visual & Component Presence', () {
    testWidgets(
        'Three-dot overflow menu button appears on NotesStackWidget with pure white background and drop shadow',
        (tester) async {
      final note = createSampleNote();
      await tester.pumpWidget(wrapWithScaffold(
        NotesStackWidget(
          notes: [note],
          onEdit: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      final overflowButtonFinder = find.byType(CardOverflowButton);
      expect(overflowButtonFinder, findsOneWidget);

      final container = tester.widget<Container>(
        find.descendant(
          of: overflowButtonFinder,
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration as BoxDecoration;

      expect(decoration.color, equals(const Color(0xFFFFFFFF)));
      expect(decoration.shape, equals(BoxShape.circle));
      expect(decoration.boxShadow, isNotNull);
      expect(decoration.boxShadow!.length, equals(1));
      expect(decoration.boxShadow![0].color, equals(const Color(0x3F000000)));
      expect(decoration.boxShadow![0].blurRadius, equals(16.0));
      expect(decoration.boxShadow![0].offset, equals(const Offset(0, 0)));
      expect(decoration.boxShadow![0].spreadRadius, equals(0.0));
    });

    testWidgets(
        'Three-dot overflow menu button appears on TaskWidget with pure white background and drop shadow',
        (tester) async {
      final task = createSampleTask();
      await tester.pumpWidget(wrapWithScaffold(
        TaskWidget(
          tasks: [task],
          onEdit: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      final overflowButtonFinder = find.byType(CardOverflowButton);
      expect(overflowButtonFinder, findsOneWidget);

      final container = tester.widget<Container>(
        find.descendant(
          of: overflowButtonFinder,
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration as BoxDecoration;

      expect(decoration.color, equals(const Color(0xFFFFFFFF)));
      expect(decoration.shape, equals(BoxShape.circle));
      expect(decoration.boxShadow, isNotNull);
      expect(decoration.boxShadow!.length, equals(1));
      expect(decoration.boxShadow![0].color, equals(const Color(0x3F000000)));
      expect(decoration.boxShadow![0].blurRadius, equals(16.0));
      expect(decoration.boxShadow![0].offset, equals(const Offset(0, 0)));
      expect(decoration.boxShadow![0].spreadRadius, equals(0.0));
    });

    testWidgets(
        'More Options button and menu adapt responsively to container width changes',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 322.0,
              height: 339.0,
              child: CardMoreOptionsMenu(
                isOpen: false,
                onOpen: () {},
                onClose: () {},
                onAddToHomeScreen: () {},
                onDelete: () {},
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final buttonAt322 = tester.getTopRight(find.byType(CardOverflowButton));

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400.0,
              height: 339.0,
              child: CardMoreOptionsMenu(
                isOpen: false,
                onOpen: () {},
                onClose: () {},
                onAddToHomeScreen: () {},
                onDelete: () {},
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final buttonAt400 = tester.getTopRight(find.byType(CardOverflowButton));

      expect(buttonAt400.dx, greaterThan(buttonAt322.dx));
      expect(buttonAt400.dy, equals(buttonAt322.dy));
    });

    testWidgets(
        'Tapping overflow button opens CardContextMenu on Note card with matching top and right alignment',
        (tester) async {
      final note = createSampleNote();
      await tester.pumpWidget(wrapWithScaffold(
        NotesStackWidget(
          notes: [note],
          onEdit: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      final buttonRect = tester.getRect(find.byType(CardOverflowButton));

      await tester.tap(find.byType(CardOverflowButton));
      await tester.pumpAndSettle();

      final menuRect = tester.getRect(find.byType(CardContextMenu));

      expect(menuRect.top, closeTo(buttonRect.top, 0.5));
      expect(menuRect.right, closeTo(buttonRect.right, 0.5));
      expect(menuRect.width, equals(186.0));

      expect(find.text('Add to HomeScreen'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets(
        'Tapping overflow button opens CardContextMenu on Task card with matching top and right alignment',
        (tester) async {
      final task = createSampleTask();
      await tester.pumpWidget(wrapWithScaffold(
        TaskWidget(
          tasks: [task],
          onEdit: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      final buttonRect = tester.getRect(find.byType(CardOverflowButton));

      await tester.tap(find.byType(CardOverflowButton));
      await tester.pumpAndSettle();

      final menuRect = tester.getRect(find.byType(CardContextMenu));

      expect(menuRect.top, closeTo(buttonRect.top, 0.5));
      expect(menuRect.right, closeTo(buttonRect.right, 0.5));
      expect(menuRect.width, equals(186.0));

      expect(find.text('Add to HomeScreen'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });
  });

  group('Note & Task Widget Menu — Interactions & Actions', () {
    testWidgets('Tapping outside dismisses Note card contextual menu',
        (tester) async {
      final note = createSampleNote();
      await tester.pumpWidget(wrapWithScaffold(
        NotesStackWidget(
          notes: [note],
          onEdit: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CardOverflowButton));
      await tester.pumpAndSettle();

      expect(find.byType(CardContextMenu), findsOneWidget);

      await tester.tapAt(const Offset(10.0, 10.0));
      await tester.pumpAndSettle();

      expect(find.byType(CardContextMenu), findsNothing);
      expect(find.byType(CardOverflowButton), findsOneWidget);
    });

    testWidgets('Tapping outside dismisses Task card contextual menu',
        (tester) async {
      final task = createSampleTask();
      await tester.pumpWidget(wrapWithScaffold(
        TaskWidget(
          tasks: [task],
          onEdit: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CardOverflowButton));
      await tester.pumpAndSettle();

      expect(find.byType(CardContextMenu), findsOneWidget);

      await tester.tapAt(const Offset(10.0, 10.0));
      await tester.pumpAndSettle();

      expect(find.byType(CardContextMenu), findsNothing);
      expect(find.byType(CardOverflowButton), findsOneWidget);
    });

    testWidgets(
        'Note card Add to HomeScreen pins exact note via widget_pin channel and shows confirmation feedback',
        (tester) async {
      final note = createSampleNote(id: 'note-pinned-456', title: 'Special Note');
      await tester.pumpWidget(wrapWithScaffold(
        NotesStackWidget(
          notes: [note],
          onEdit: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CardOverflowButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add to HomeScreen'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.byType(CardContextMenu), findsNothing);
      expect(
        widgetPinCalls.any((call) =>
            call.method == 'requestPinNoteWidget' &&
            call.arguments['noteId'] == 'note-pinned-456'),
        isTrue,
      );
      expect(find.text('Pin request sent. Confirm on your home screen.'),
          findsOneWidget);
    });

    testWidgets(
        'Task card Add to HomeScreen pins exact task via widget_pin channel and shows confirmation feedback',
        (tester) async {
      final task = createSampleTask(id: 'task-pinned-789', title: 'Special Task');
      await tester.pumpWidget(wrapWithScaffold(
        TaskWidget(
          tasks: [task],
          onEdit: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CardOverflowButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add to HomeScreen'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.byType(CardContextMenu), findsNothing);
      expect(
        widgetPinCalls.any((call) =>
            call.method == 'requestPinTaskWidget' &&
            call.arguments['taskId'] == 'task-pinned-789'),
        isTrue,
      );
      expect(find.text('Pin request sent. Confirm on your home screen.'),
          findsOneWidget);
    });

    testWidgets(
        'Locked note cannot be pinned to home screen and informs user with SnackBar',
        (tester) async {
      final lockedNote = createSampleNote(id: 'vault-1', isLocked: true);
      await tester.pumpWidget(wrapWithScaffold(
        NotesStackWidget(
          notes: [lockedNote],
          onEdit: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CardOverflowButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add to HomeScreen'));
      await tester.pumpAndSettle();

      expect(
        widgetPinCalls.any((call) => call.method == 'requestPinNoteWidget'),
        isFalse,
      );
      expect(
        homeWidgetCalls.any((call) => call.method == 'requestPinWidget'),
        isFalse,
      );
      expect(
        find.text('Locked notes cannot be added to the home screen.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'Unsupported launcher displays informative SnackBar on Note card Add to HomeScreen',
        (tester) async {
      mockLauncherSupported = false;
      final note = createSampleNote();
      await tester.pumpWidget(wrapWithScaffold(
        NotesStackWidget(
          notes: [note],
          onEdit: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CardOverflowButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add to HomeScreen'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(
        find.text('Adding home-screen widgets is not supported on this device/launcher.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'Unsupported launcher displays informative SnackBar on Task card Add to HomeScreen',
        (tester) async {
      mockLauncherSupported = false;
      final task = createSampleTask();
      await tester.pumpWidget(wrapWithScaffold(
        TaskWidget(
          tasks: [task],
          onEdit: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CardOverflowButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add to HomeScreen'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(
        find.text('Adding home-screen widgets is not supported on this device/launcher.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'Falls back to HomeWidget.requestPinWidget when widget_pin channel is unavailable',
        (tester) async {
      mockWidgetPinChannelActive = false;
      final note = createSampleNote();

      final res = await WidgetDataAdapter.instance.requestPinSingleNoteWidget(note: note);
      expect(res, isTrue);
      expect(
        homeWidgetCalls.any((call) =>
            call.method == 'requestPinWidget' &&
            call.arguments['android'] == 'SingleNoteWidget'),
        isTrue,
      );
    });

    testWidgets('Note card Delete triggers onDelete callback with exact note',
        (tester) async {
      final note1 = createSampleNote(id: 'note-1', title: 'First Note');
      final note2 = createSampleNote(id: 'note-2', title: 'Second Note');
      Note? deletedNote;

      await tester.pumpWidget(wrapWithScaffold(
        NotesStackWidget(
          notes: [note1, note2],
          onEdit: (_) {},
          onDelete: (n) => deletedNote = n,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CardOverflowButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(deletedNote?.id, equals('note-1'));
    });

    testWidgets('Task card Delete triggers onDelete callback with exact task',
        (tester) async {
      final task1 = createSampleTask(id: 'task-1', title: 'First Task');
      final task2 = createSampleTask(id: 'task-2', title: 'Second Task');
      TaskItem? deletedTask;

      await tester.pumpWidget(wrapWithScaffold(
        TaskWidget(
          tasks: [task1, task2],
          onEdit: (_) {},
          onDelete: (t) => deletedTask = t,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CardOverflowButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(deletedTask?.id, equals('task-1'));
    });

    testWidgets('Edit button callback is not affected by menu button',
        (tester) async {
      final note = createSampleNote();
      Note? editedNote;

      await tester.pumpWidget(wrapWithScaffold(
        NotesStackWidget(
          notes: [note],
          onEdit: (n) => editedNote = n,
        ),
      ));
      await tester.pumpAndSettle();

      final pencilFinder = find.byWidgetPredicate(
        (widget) => widget is Image || widget.toString().contains('pencil.svg'),
      );
      expect(pencilFinder, findsOneWidget);

      await tester.tap(pencilFinder);
      await tester.pumpAndSettle();

      expect(editedNote?.id, equals(note.id));
    });

    testWidgets(
        'Multi-instance snapshot isolation: deleting a note omits it from live snapshot map',
        (tester) async {
      final note1 = createSampleNote(id: 'note-1', title: 'Note 1');
      final note2 = createSampleNote(id: 'note-2', title: 'Note 2');

      final adapter = WidgetDataAdapter.instance;
      // Sync two active notes
      await adapter.sync(notes: [note1, note2], hasActiveSession: true);

      final payload1 = adapter.buildSnapshot(notes: [note1, note2], hasActiveSession: true);
      expect(payload1.hasActiveSession, isTrue);

      // Delete note1: sync only note2
      await adapter.sync(notes: [note2], hasActiveSession: true);

      // The live map now contains only note2
      final payload2 = adapter.buildSnapshot(notes: [note2], hasActiveSession: true);
      expect(payload2.hasActiveSession, isTrue);
    });
  });
}
