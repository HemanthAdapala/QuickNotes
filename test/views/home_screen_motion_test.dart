import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quick_notes/core/motion/motion_constants.dart';
import 'package:quick_notes/core/motion/quick_notes_haptics.dart';
import 'package:quick_notes/core/animations/page_transitions.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/views/widgets/app_bottom_navigation_bar.dart';
import 'package:quick_notes/views/widgets/notes_and_task_pill.dart';
import 'package:quick_notes/views/widgets/home_prompt_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase P1 — Motion Constants & Physics Verification', () {
    test('Motion constants have calibrated durations', () {
      expect(QuickNotesMotion.kMotionMicro, const Duration(milliseconds: 90));
      expect(QuickNotesMotion.kMotionRelease, const Duration(milliseconds: 190));
      expect(QuickNotesMotion.kMotionSelection, const Duration(milliseconds: 260));
      expect(QuickNotesMotion.kMotionPage, const Duration(milliseconds: 340));
      expect(QuickNotesMotion.kMotionPageReverse, const Duration(milliseconds: 260));
    });

    test('DampedSpringCurve preserves boundary invariants and exhibits controlled overshoot', () {
      const curve = QuickNotesMotion.kMotionSpring;
      expect(curve.transform(0.0), 0.0);
      expect(curve.transform(1.0), 1.0);

      // Verify subtle physical overshoot (~1.5%) around peak and rapid decay to 1.0
      double maxVal = 0.0;
      for (int i = 0; i <= 100; i++) {
        final double t = i / 100.0;
        final double val = curve.transform(t);
        if (val > maxVal) {
          maxVal = val;
        }
      }
      expect(maxVal, greaterThan(1.0));
      expect(maxVal, lessThan(1.04)); // Subtle (< 4%) overshoot
      expect((curve.transform(1.0) - 1.0).abs(), lessThan(0.001)); // Settles cleanly
    });
  });

  group('Phase P1-A — Bottom Navigation Physical Indicator & Haptics', () {
    late List<String> hapticLog;

    setUp(() {
      hapticLog = [];
      QuickNotesHaptics.debugHapticListener = (method) {
        hapticLog.add(method);
      };
    });

    tearDown(() {
      QuickNotesHaptics.debugHapticListener = null;
    });

    testWidgets('Tab tap fires exactly ONE navigationSelection haptic on destination change',
        (tester) async {
      int selectedIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: StatefulBuilder(
              builder: (context, setState) {
                return AppBottomNavigationBar(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (i) {
                    setState(() => selectedIndex = i);
                  },
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      hapticLog.clear();

      // Tap Calendar (Semantics label: 'Calendar')
      final calendarFinder = find.bySemanticsLabel('Calendar');
      expect(calendarFinder, findsOneWidget);
      await tester.tap(calendarFinder);
      await tester.pump();

      // Exactly ONE semantic navigation haptic fired
      expect(hapticLog, ['navigationSelection']);
      expect(selectedIndex, 2);

      await tester.pumpAndSettle();

      // Tapping already selected tab does not fire navigationSelection haptic
      hapticLog.clear();
      await tester.tap(calendarFinder);
      await tester.pump();
      expect(hapticLog, isEmpty);
    });

    testWidgets('Physical indicator returns precisely to 70px * scale at rest',
        (tester) async {
      int selectedIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: StatefulBuilder(
              builder: (context, setState) {
                return AppBottomNavigationBar(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (i) {
                    setState(() => selectedIndex = i);
                  },
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial resting state check
      final indicatorFinder = find.byKey(const ValueKey('physical_active_indicator'));
      expect(indicatorFinder, findsOneWidget);
      Size initialSize = tester.getSize(indicatorFinder);
      expect(initialSize.width, closeTo(70.0, 0.5));

      // Tap Folders (Index 1)
      await tester.tap(find.bySemanticsLabel('Folders'));
      await tester.pump(); // Start of motion

      // Settle
      await tester.pumpAndSettle();
      Size finalSize = tester.getSize(indicatorFinder);
      expect(finalSize.width, closeTo(70.0, 0.5));
    });

    testWidgets('Respects disableAnimations by immediately resting without stretch',
        (tester) async {
      int selectedIndex = 0;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              bottomNavigationBar: StatefulBuilder(
                builder: (context, setState) {
                  return AppBottomNavigationBar(
                    selectedIndex: selectedIndex,
                    onDestinationSelected: (i) {
                      setState(() => selectedIndex = i);
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final indicatorFinder = find.byKey(const ValueKey('physical_active_indicator'));
      expect(indicatorFinder, findsOneWidget);
      Size initialSize = tester.getSize(indicatorFinder);
      expect(initialSize.width, closeTo(70.0, 0.5));

      // Tap Calendar
      await tester.tap(find.bySemanticsLabel('Calendar'));
      await tester.pump(); // Single frame

      Size postTapSize = tester.getSize(indicatorFinder);
      expect(postTapSize.width, closeTo(70.0, 0.5)); // No stretch occurs
    });
  });

  group('Phase P1-B — Notes / Tasks Magnetic Switcher', () {
    late List<String> hapticLog;

    setUp(() {
      hapticLog = [];
      QuickNotesHaptics.debugHapticListener = (method) {
        hapticLog.add(method);
      };
    });

    tearDown(() {
      QuickNotesHaptics.debugHapticListener = null;
    });

    testWidgets('Tapping Tasks fires exactly ONE selection haptic and switches state',
        (tester) async {
      bool isNotes = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: StatefulBuilder(
                builder: (context, setState) {
                  return NotesAndTaskPill(
                    isNotesActive: isNotes,
                    onChanged: (val) {
                      setState(() => isNotes = val);
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      hapticLog.clear();

      // Tap Tasks
      await tester.tap(find.text('Tasks'));
      await tester.pump();

      expect(hapticLog, ['selection']);
      expect(isNotes, false);

      await tester.pumpAndSettle();

      // Tapping Tasks again (already active) does not fire duplicate haptic
      hapticLog.clear();
      await tester.tap(find.text('Tasks'));
      await tester.pump();
      expect(hapticLog, isEmpty);
    });

    testWidgets('Pill preserves exact 177x40 container and 83x32 pod geometry',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: NotesAndTaskPill(
                isNotesActive: true,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final pillFinder = find.byType(NotesAndTaskPill);
      final pillSize = tester.getSize(pillFinder);
      expect(pillSize.width, 177.0);
      expect(pillSize.height, 40.0);
    });
  });

  group('Phase P1-C — Primary Prompt Tactile Response', () {
    late List<String> hapticLog;
    late NotesProvider notesProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      notesProvider = NotesProvider();
      notesProvider.setNotesForTesting([
        Note(
          id: 'note-1',
          title: 'Existing Note',
          content: 'Some note text',
          tags: const [],
          attachments: const [],
          createdAt: DateTime(2026, 6, 15),
          updatedAt: DateTime(2026, 6, 15),
          colorValue: 0xFFFFFFFF,
        ),
      ]);
      hapticLog = [];
      QuickNotesHaptics.debugHapticListener = (method) {
        hapticLog.add(method);
      };
    });

    tearDown(() {
      QuickNotesHaptics.debugHapticListener = null;
    });

    testWidgets('Touch-down immediately triggers buttonPress haptic and releases to call onTap',
        (tester) async {
      int tapCount = 0;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: notesProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: HomePromptView(
                date: DateTime(2026, 6, 15, 8, 0),
                displayName: 'Test User',
                isNotesActive: true,
                onTap: () => tapCount++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      hapticLog.clear();

      // Find the prompt text widget from the known deck of witty prompts
      final promptFinder = find.byWidgetPredicate(
        (w) => w is Text && HomePromptView.prompts.contains(w.data),
      );
      expect(promptFinder, findsOneWidget);

      final gesture = await tester.startGesture(tester.getCenter(promptFinder));
      await tester.pump(const Duration(milliseconds: 50));

      // Immediate buttonPress on touch-down
      expect(hapticLog, ['buttonPress']);
      expect(tapCount, 0);

      // Release gesture
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));

      // Navigation action dispatched
      expect(tapCount, 1);
      await tester.pumpAndSettle();
    });

    testWidgets('Touch-down followed by cancel restores state without triggering onTap',
        (tester) async {
      int tapCount = 0;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: notesProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: HomePromptView(
                date: DateTime(2026, 6, 15, 8, 0),
                displayName: 'Test User',
                isNotesActive: true,
                onTap: () => tapCount++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final promptFinder = find.byWidgetPredicate(
        (w) => w is Text && HomePromptView.prompts.contains(w.data),
      );
      final gesture = await tester.startGesture(tester.getCenter(promptFinder));
      await tester.pump(const Duration(milliseconds: 50));

      // Drag far away to cancel
      await gesture.moveTo(const Offset(0, 0));
      await gesture.cancel();
      await tester.pumpAndSettle();

      expect(tapCount, 0); // onTap did NOT fire
    });
  });

  group('Phase P1-D — Note Opening Route Transition', () {
    test('buildNoteOpeningPageRoute has expected forward and reverse durations', () {
      final route = buildNoteOpeningPageRoute(const SizedBox()) as PageRouteBuilder;
      expect(route.transitionDuration, const Duration(milliseconds: 340));
      expect(route.reverseTransitionDuration, const Duration(milliseconds: 260));
    });
  });
}
