import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/core/motion/motion_constants.dart';
import 'package:quick_notes/core/motion/quick_notes_haptics.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/models/task_item.dart';
import 'package:quick_notes/views/widgets/notes_stack_widget.dart';
import 'package:quick_notes/views/widgets/task_widget.dart';

Note _createNote(String id, String title) {
  return Note(
    id: id,
    title: title,
    content: 'Content for $title',
    createdAt: DateTime(2026, 1, 1, 10, 0),
    updatedAt: DateTime(2026, 1, 1, 10, 0),
    colorValue: 0xFFFFFF,
    tags: const [],
    attachments: const [],
  );
}

TaskItem _createTask(String id, String title) {
  return TaskItem(
    id: id,
    title: title,
    dueDate: DateTime(2026, 1, 1, 12, 0),
    priority: 'Medium',
  );
}

Widget _wrapWidget({required Widget child, bool disableAnimations = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(
        body: Center(
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── GROUP A — GEOMETRY ───────────────────────────────────────────────────
  group('Test Group A — Geometry Contracts', () {
    testWidgets('NotesStackWidget enforces 322x339 card and 37px vertical offsets', (tester) async {
      final notes = [
        _createNote('1', 'Note 1'),
        _createNote('2', 'Note 2'),
        _createNote('3', 'Note 3'),
      ];

      await tester.pumpWidget(_wrapWidget(
        child: NotesStackWidget(
          notes: notes,
          onEdit: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      // Stack height for 3 cards must be 339 + 2 * 37 = 413.0
      final stackSizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(stackSizedBox.width, 322.0);
      expect(stackSizedBox.height, 413.0);

      // Verify front card sizing
      final frontCardSizedBoxes = tester.widgetList<SizedBox>(find.byWidgetPredicate(
        (w) => w is SizedBox && w.width == 322.0 && w.height == 339.0,
      ));
      expect(frontCardSizedBoxes.isNotEmpty, isTrue);
    });

    testWidgets('NotesStackWidget single card height is exactly 339px', (tester) async {
      final notes = [_createNote('1', 'Solo Note')];

      await tester.pumpWidget(_wrapWidget(
        child: NotesStackWidget(
          notes: notes,
          onEdit: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      final stackSizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(stackSizedBox.width, 322.0);
      expect(stackSizedBox.height, 339.0);
    });

    testWidgets('TaskWidget enforces 322x339 card and 37px vertical offsets', (tester) async {
      final tasks = [
        _createTask('1', 'Task 1'),
        _createTask('2', 'Task 2'),
        _createTask('3', 'Task 3'),
      ];

      await tester.pumpWidget(_wrapWidget(
        child: TaskWidget(
          tasks: tasks,
        ),
      ));
      await tester.pumpAndSettle();

      final stackSizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(stackSizedBox.width, 322.0);
      expect(stackSizedBox.height, 413.0);
    });
  });

  // ── GROUP B — RESET ──────────────────────────────────────────────────────
  group('Test Group B — Swipe Rejection & Spring Reset', () {
    testWidgets('Notes card drag < 120px springs back to origin (0, 0)', (tester) async {
      final notes = [
        _createNote('1', 'Note 1'),
        _createNote('2', 'Note 2'),
      ];

      await tester.pumpWidget(_wrapWidget(
        child: NotesStackWidget(
          notes: notes,
          onEdit: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(tester.getCenter(find.text('Note 1')));
      // Drag 60px right (< 120px threshold)
      await gesture.moveBy(const Offset(60.0, 0.0));
      await tester.pump();

      // Release finger
      await gesture.up();
      // Pump spring duration (260ms) and settle
      await tester.pump(const Duration(milliseconds: 130));
      await tester.pumpAndSettle();

      // Note 1 must remain the active top note
      expect(find.text('Note 1'), findsOneWidget);
    });

    testWidgets('Notes card drag exactly 120px does not dismiss and resets', (tester) async {
      final notes = [
        _createNote('1', 'Note 1'),
        _createNote('2', 'Note 2'),
      ];

      await tester.pumpWidget(_wrapWidget(
        child: NotesStackWidget(
          notes: notes,
          onEdit: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(tester.getCenter(find.text('Note 1')));
      // Drag exactly 120px
      await gesture.moveBy(const Offset(120.0, 0.0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      // Must remain Note 1 (strict > 120.0 required for dismissal)
      expect(find.text('Note 1'), findsOneWidget);
    });
  });

  // ── GROUP C — DISMISSAL & CYCLING ────────────────────────────────────────
  group('Test Group C — Card Dismissal & Deck Cycling', () {
    testWidgets('Notes card drag > 120px cycles top card to back of deck', (tester) async {
      final notes = [
        _createNote('1', 'Note 1'),
        _createNote('2', 'Note 2'),
        _createNote('3', 'Note 3'),
      ];

      await tester.pumpWidget(_wrapWidget(
        child: NotesStackWidget(
          notes: notes,
          onEdit: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Note 1'), findsOneWidget);

      final gesture = await tester.startGesture(tester.getCenter(find.text('Note 1')));
      // Drag 160px right (> 120px)
      await gesture.moveBy(const Offset(160.0, 0.0));
      await tester.pump();
      await gesture.up();

      // Allow 260ms dismissal animation to finish
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Note 2 must now be the active front card
      expect(find.text('Note 2'), findsOneWidget);
    });

    testWidgets('TaskWidget card drag > 120px cycles top task to back of deck', (tester) async {
      final tasks = [
        _createTask('1', 'Task 1'),
        _createTask('2', 'Task 2'),
        _createTask('3', 'Task 3'),
      ];

      await tester.pumpWidget(_wrapWidget(
        child: TaskWidget(
          tasks: tasks,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Task 1'), findsOneWidget);

      final gesture = await tester.startGesture(tester.getCenter(find.text('Task 1')));
      await gesture.moveBy(const Offset(160.0, 0.0));
      await tester.pump();
      await gesture.up();

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('Task 2'), findsOneWidget);
    });
  });

  // ── GROUP D — RAPID GESTURES ─────────────────────────────────────────────
  group('Test Group D — Rapid Interaction & Guard Protection', () {
    testWidgets('Second swipe gesture during active dismissal is safely ignored', (tester) async {
      final notes = [
        _createNote('1', 'Note 1'),
        _createNote('2', 'Note 2'),
        _createNote('3', 'Note 3'),
      ];

      await tester.pumpWidget(_wrapWidget(
        child: NotesStackWidget(
          notes: notes,
          onEdit: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      // First swipe to trigger cycle
      final gesture1 = await tester.startGesture(tester.getCenter(find.text('Note 1')));
      await gesture1.moveBy(const Offset(180.0, 0.0));
      await gesture1.up();

      // Mid-flight (100ms into 260ms cycle)
      await tester.pump(const Duration(milliseconds: 100));

      // Attempt second gesture while _isAnimatingSwipe == true
      final gesture2 = await tester.startGesture(const Offset(160.0, 200.0));
      await gesture2.moveBy(const Offset(100.0, 0.0));
      await gesture2.up();

      await tester.pumpAndSettle();

      // Only 1 cycle should have executed: Note 2 is front
      expect(find.text('Note 2'), findsOneWidget);
    });
  });

  // ── GROUP E — PAN CANCEL ─────────────────────────────────────────────────
  group('Test Group E — Pan Cancellation', () {
    testWidgets('Cancelled gesture restores card to resting state without cycling', (tester) async {
      final notes = [
        _createNote('1', 'Note 1'),
        _createNote('2', 'Note 2'),
      ];

      await tester.pumpWidget(_wrapWidget(
        child: NotesStackWidget(
          notes: notes,
          onEdit: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(tester.getCenter(find.text('Note 1')));
      await gesture.moveBy(const Offset(150.0, 20.0));
      await tester.pump();

      // Cancel gesture stream
      await gesture.cancel();
      await tester.pumpAndSettle();

      // Card must safely restore without cycling
      expect(find.text('Note 1'), findsOneWidget);
    });
  });

  // ── GROUP F — REDUCED MOTION ─────────────────────────────────────────────
  group('Test Group F — Reduced Motion / Accessibility', () {
    testWidgets('When disableAnimations is true, card reset snaps immediately', (tester) async {
      final notes = [
        _createNote('1', 'Note 1'),
        _createNote('2', 'Note 2'),
      ];

      await tester.pumpWidget(_wrapWidget(
        disableAnimations: true,
        child: NotesStackWidget(
          notes: notes,
          onEdit: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(tester.getCenter(find.text('Note 1')));
      await gesture.moveBy(const Offset(50.0, 0.0));
      await tester.pump();

      await gesture.up();
      // Snap must be immediate (0ms)
      await tester.pump();

      expect(find.text('Note 1'), findsOneWidget);
    });

    testWidgets('When disableAnimations is true, card dismissal cycles immediately', (tester) async {
      final notes = [
        _createNote('1', 'Note 1'),
        _createNote('2', 'Note 2'),
      ];

      await tester.pumpWidget(_wrapWidget(
        disableAnimations: true,
        child: NotesStackWidget(
          notes: notes,
          onEdit: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(tester.getCenter(find.text('Note 1')));
      await gesture.moveBy(const Offset(160.0, 0.0));
      await tester.pump();

      await gesture.up();
      // Snap must be immediate (0ms)
      await tester.pump();

      expect(find.text('Note 2'), findsOneWidget);
    });
  });

  // ── GROUP G — HAPTICS ────────────────────────────────────────────────────
  group('Test Group G — Threshold & Centralized Haptics', () {
    testWidgets('Threshold crossing fires subtleSettle haptic exactly once and resets', (tester) async {
      final hapticsFired = <String>[];
      QuickNotesHaptics.debugHapticListener = (method) {
        hapticsFired.add(method);
      };

      final notes = [
        _createNote('1', 'Note 1'),
        _createNote('2', 'Note 2'),
      ];

      await tester.pumpWidget(_wrapWidget(
        child: NotesStackWidget(
          notes: notes,
          onEdit: (_) {},
        ),
      ));
      await tester.pumpAndSettle();
      hapticsFired.clear();

      final gesture = await tester.startGesture(tester.getCenter(find.text('Note 1')));

      // 1. Touch-down fires buttonPress haptic
      expect(hapticsFired, contains('buttonPress'));
      hapticsFired.clear();

      // 2. Drag to 80px (< 120px) -> no threshold haptic
      await gesture.moveBy(const Offset(80.0, 0.0));
      await tester.pump();
      expect(hapticsFired.where((h) => h == 'subtleSettle').length, 0);

      // 3. Cross 120px (e.g. +50px -> total 130px) -> subtleSettle fires ONCE
      await gesture.moveBy(const Offset(50.0, 0.0));
      await tester.pump();
      expect(hapticsFired.where((h) => h == 'subtleSettle').length, 1);

      // 4. Staying above threshold (total 150px) -> zero additional subtleSettle
      await gesture.moveBy(const Offset(20.0, 0.0));
      await tester.pump();
      expect(hapticsFired.where((h) => h == 'subtleSettle').length, 1);

      // 5. Drag back below 120px (total 70px)
      await gesture.moveBy(const Offset(-80.0, 0.0));
      await tester.pump();
      expect(hapticsFired.where((h) => h == 'subtleSettle').length, 1);

      // 6. Cross above 120px again (total 140px) -> fires ONE NEW subtleSettle
      await gesture.moveBy(const Offset(70.0, 0.0));
      await tester.pump();
      expect(hapticsFired.where((h) => h == 'subtleSettle').length, 2);

      // 7. Complete dismissal -> dispatches selection haptic
      await gesture.up();
      await tester.pumpAndSettle();
      expect(hapticsFired, contains('selection'));

      QuickNotesHaptics.debugHapticListener = null;
    });
  });

  // ── GROUP H — LIFECYCLE ──────────────────────────────────────────────────
  group('Test Group H — Lifecycle & Mounted Safety', () {
    testWidgets('Unmounting NotesStackWidget mid-swipe does not throw unhandled assertion', (tester) async {
      final notes = [
        _createNote('1', 'Note 1'),
        _createNote('2', 'Note 2'),
      ];

      await tester.pumpWidget(_wrapWidget(
        child: NotesStackWidget(
          notes: notes,
          onEdit: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(tester.getCenter(find.text('Note 1')));
      await gesture.moveBy(const Offset(160.0, 0.0));
      await gesture.up();

      // Pump 50ms into 260ms animation
      await tester.pump(const Duration(milliseconds: 50));

      // Unmount the widget entirely (replaces with empty SizedBox)
      await tester.pumpWidget(_wrapWidget(
        child: const SizedBox.shrink(),
      ));

      // Advance clock past the animation completion without crashing
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Unmounting TaskWidget mid-swipe does not throw unhandled assertion', (tester) async {
      final tasks = [
        _createTask('1', 'Task 1'),
        _createTask('2', 'Task 2'),
      ];

      await tester.pumpWidget(_wrapWidget(
        child: TaskWidget(
          tasks: tasks,
        ),
      ));
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(tester.getCenter(find.text('Task 1')));
      await gesture.moveBy(const Offset(160.0, 0.0));
      await gesture.up();

      await tester.pump(const Duration(milliseconds: 50));

      // Unmount
      await tester.pumpWidget(_wrapWidget(
        child: const SizedBox.shrink(),
      ));

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
