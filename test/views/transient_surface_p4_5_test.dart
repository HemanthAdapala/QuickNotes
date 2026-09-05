import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/views/widgets/blurred_bottom_sheet.dart';
import 'package:quick_notes/views/widgets/celebration_overlay.dart';
import 'package:quick_notes/views/widgets/delete_confirmation_dialog.dart';
import 'package:quick_notes/views/widgets/delete_task_confirmation_dialog.dart';

void main() {
  group('P4.5 — Group A: CelebrationOverlay Reduced-Motion Accessibility', () {
    testWidgets('TEST A1: CelebrationOverlay skips particle physics when disableAnimations is true', (tester) async {
      bool doneCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: CelebrationOverlay(
              message: '🎉 All tasks done!',
              onDone: () => doneCalled = true,
            ),
          ),
        ),
      );

      await tester.pump();

      // Semantic completion acknowledgement is immediately visible
      expect(find.text('🎉 All tasks done!'), findsOneWidget);

      // Particle physics painter is NOT in the tree
      final customPaintFinder = find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter != null,
      );
      expect(customPaintFinder, findsNothing);

      // After 1600ms, the completion lifecycle triggers without error
      await tester.pump(const Duration(milliseconds: 1600));
      expect(doneCalled, isTrue);
    });

    testWidgets('TEST A2: CelebrationOverlay preserves normal particle animation when disableAnimations is false', (tester) async {
      bool doneCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: false),
            child: child!,
          ),
          home: Scaffold(
            body: CelebrationOverlay(
              message: '🎉 All tasks done!',
              onDone: () => doneCalled = true,
            ),
          ),
        ),
      );

      await tester.pump();

      // Particles CustomPaint IS present in normal motion
      final customPaintFinder = find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter != null,
      );
      expect(customPaintFinder, findsOneWidget);

      // Animation runs for full 1600ms duration before completing
      await tester.pump(const Duration(milliseconds: 1599));
      expect(doneCalled, isFalse);

      await tester.pump(const Duration(milliseconds: 10));
      expect(doneCalled, isTrue);
    });
  });

  group('P4.5 — Group B: showBlurredBottomSheet Asymmetric Reverse & Synchronization', () {
    test('TEST B1: BlurredBottomSheetRoute timing constants and curve contracts', () {
      final route = BlurredBottomSheetRoute(child: const SizedBox());

      expect(route.transitionDuration, const Duration(milliseconds: 350));
      expect(route.reverseTransitionDuration, const Duration(milliseconds: 260));
      expect(route.barrierDismissible, isTrue);
      expect(route.barrierLabel, 'Dismiss');
      expect(route.barrierColor, const Color(0xFF333333).withValues(alpha: 0.20));
    });

    testWidgets('TEST B2: Forward transition runs for 350ms with synchronized blur & slide', (tester) async {
      late BuildContext savedContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                savedContext = context;
                return const Text('Home');
              },
            ),
          ),
        ),
      );

      showBlurredBottomSheet(
        context: savedContext,
        child: const Text('Sheet Body'),
      );

      await tester.pump();

      // At t=0+, sheet is entering
      expect(find.text('Sheet Body'), findsOneWidget);

      // Mid-transition at 175ms
      await tester.pump(const Duration(milliseconds: 175));
      final backdropFilter = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
      final filter = backdropFilter.filter;
      expect(filter, isNotNull);

      // Completed at 350ms
      await tester.pump(const Duration(milliseconds: 175));
      final slideFinder = find.descendant(
        of: find.byType(BackdropFilter),
        matching: find.byType(SlideTransition),
      );
      expect(slideFinder, findsOneWidget);
      final slide = tester.widget<SlideTransition>(slideFinder);
      expect(slide.position.value, Offset.zero);
    });

    testWidgets('TEST B3: Reverse transition runs for 260ms and dismisses cleanly', (tester) async {
      late BuildContext savedContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                savedContext = context;
                return const Text('Home');
              },
            ),
          ),
        ),
      );

      showBlurredBottomSheet(
        context: savedContext,
        child: const Text('Sheet Body'),
      );

      // Complete forward presentation (350ms)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Sheet Body'), findsOneWidget);

      // Begin dismissal
      Navigator.of(savedContext).pop();
      await tester.pump();

      // At 130ms (halfway through 260ms reverse), still visible and dismissing
      await tester.pump(const Duration(milliseconds: 130));
      expect(find.text('Sheet Body'), findsOneWidget);

      // Advance through 260ms reverse duration and finalize
      await tester.pump(const Duration(milliseconds: 130));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Sheet Body'), findsNothing);
    });

    testWidgets('TEST B4: Reduced motion presents and dismisses immediately without animation', (tester) async {
      late BuildContext savedContext;

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                savedContext = context;
                return const Text('Home');
              },
            ),
          ),
        ),
      );

      showBlurredBottomSheet(
        context: savedContext,
        child: const Text('Sheet Body'),
      );

      // Immediate presentation with single pump (0ms duration)
      await tester.pump();
      expect(find.text('Sheet Body'), findsOneWidget);

      // Immediate dismissal with single pump (0ms reverse duration)
      Navigator.of(savedContext).pop();
      await tester.pump();
      expect(find.text('Sheet Body'), findsNothing);
    });
  });

  group('P4.5 — Group C: Modal Barrier Visual Consistency', () {
    testWidgets('TEST C1: showBlurredBottomSheet uses established 20% ink barrier', (tester) async {
      late BuildContext savedContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                savedContext = context;
                return const Text('Home');
              },
            ),
          ),
        ),
      );

      showBlurredBottomSheet(
        context: savedContext,
        child: const Text('Sheet Body'),
      );
      // Advance entrance animation to complete barrier fade-in
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final modalBarrierFinder = find.byType(ModalBarrier);
      expect(modalBarrierFinder, findsWidgets);
      final barrier = tester.widget<ModalBarrier>(modalBarrierFinder.last);
      expect(barrier.color, const Color(0xFF333333).withValues(alpha: 0.20));
      expect(barrier.dismissible, isTrue);
    });

    testWidgets('TEST C2: Delete confirmation dialogs preserve explicit 40% ink barrier', (tester) async {
      late BuildContext savedContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                savedContext = context;
                return const Text('Home');
              },
            ),
          ),
        ),
      );

      // Open Delete Note Dialog and complete entrance animation
      showDeleteNoteDialog(savedContext, message: 'Delete note?');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final modalBarrierFinder = find.byType(ModalBarrier);
      expect(modalBarrierFinder, findsWidgets);
      final barrier = tester.widget<ModalBarrier>(modalBarrierFinder.last);
      expect(barrier.color, const Color(0xFF333333).withValues(alpha: 0.40));

      // Dismiss dialog
      Navigator.of(savedContext).pop();
      await tester.pumpAndSettle();

      // Open Delete Task Dialog and complete entrance animation
      showDeleteTaskDialog(savedContext, message: 'Delete task?');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final taskBarrierFinder = find.byType(ModalBarrier);
      expect(taskBarrierFinder, findsWidgets);
      final taskBarrier = tester.widget<ModalBarrier>(taskBarrierFinder.last);
      expect(taskBarrier.color, const Color(0xFF333333).withValues(alpha: 0.40));
    });
  });
}
