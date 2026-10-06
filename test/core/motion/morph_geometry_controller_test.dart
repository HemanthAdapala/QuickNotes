import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/core/motion/morph_geometry_config.dart';
import 'package:quick_notes/core/motion/morph_geometry_controller.dart';

void main() {
  const config = QuickNotesMorphGeometryConfig();

  group('QuickNotesMorphGeometryController', () {
    test('initial state seeds 4 springs accurately', () {
      const initial = Rect.fromLTWH(20, 40, 100, 100);
      final controller = QuickNotesMorphGeometryController(
        initialRect: initial,
        initialAnchor: Alignment.center,
      );

      expect(controller.isSeeded, isTrue);
      expect(controller.isAnimating, isFalse);
      expect(controller.currentRect, initial);
      expect(controller.anchorXSpring.position, 70.0);
      expect(controller.anchorYSpring.position, 90.0);
      expect(controller.widthSpring.position, 100.0);
      expect(controller.heightSpring.position, 100.0);
    });

    test('Circle -> Square (Growing) exhibits asymmetric lead-follow', () {
      const circleRect = Rect.fromLTWH(50, 50, 56, 56);
      const squareRect = Rect.fromLTWH(20, 20, 240, 240);

      final controller = QuickNotesMorphGeometryController(
        initialRect: circleRect,
        initialAnchor: Alignment.center,
      );

      controller.transitionToRect(squareRect, config: config);
      expect(controller.isGrowing, isTrue);
      expect(controller.sizeHoldRemaining, config.followDelaySeconds);
      expect(controller.anchorHoldRemaining, 0.0);

      // Advance by one frame (16ms < 40ms followDelay)
      controller.step(0.016, config);
      // Size spring was held, so size shouldn't have expanded yet
      expect(controller.widthSpring.position, closeTo(56.0, 0.5));
      expect(controller.heightSpring.position, closeTo(56.0, 0.5));
      // Anchor was NOT held, so it should have moved toward destination
      expect(controller.anchorXSpring.position, isNot(circleRect.center.dx));

      // Advance until settled
      for (int i = 0; i < 90; i++) {
        controller.step(1.0 / 60.0, config);
      }

      expect(controller.isAnimating, isFalse);
      expect(controller.currentRect.left, closeTo(squareRect.left, 0.1));
      expect(controller.currentRect.top, closeTo(squareRect.top, 0.1));
      expect(controller.currentRect.width, closeTo(squareRect.width, 0.1));
      expect(controller.currentRect.height, closeTo(squareRect.height, 0.1));
    });

    test('Square -> Circle (Shrinking) collapses size first', () {
      const squareRect = Rect.fromLTWH(20, 20, 240, 240);
      const circleRect = Rect.fromLTWH(100, 100, 56, 56);

      final controller = QuickNotesMorphGeometryController(
        initialRect: squareRect,
        initialAnchor: Alignment.center,
      );

      controller.transitionToRect(circleRect, config: config);
      expect(controller.isGrowing, isFalse);
      expect(controller.anchorHoldRemaining, config.followDelaySeconds);
      expect(controller.sizeHoldRemaining, 0.0);

      // Advance by one frame (16ms < 40ms followDelay)
      controller.step(0.016, config);
      // Anchor was held, so center should remain approximately at square center
      expect(controller.anchorXSpring.position, closeTo(squareRect.center.dx, 0.5));
      // Size was NOT held, so width and height should have begun collapsing
      expect(controller.widthSpring.position, lessThan(240.0));

      // Advance until settled
      for (int i = 0; i < 90; i++) {
        controller.step(1.0 / 60.0, config);
      }

      expect(controller.isAnimating, isFalse);
      expect(controller.currentRect.left, closeTo(circleRect.left, 0.1));
      expect(controller.currentRect.top, closeTo(circleRect.top, 0.1));
      expect(controller.currentRect.width, closeTo(circleRect.width, 0.1));
      expect(controller.currentRect.height, closeTo(circleRect.height, 0.1));
    });

    test('Round trip A -> B -> A settles back to initial geometry', () {
      const rectA = Rect.fromLTWH(30, 40, 60, 60);
      const rectB = Rect.fromLTWH(10, 10, 200, 150);

      final controller = QuickNotesMorphGeometryController(
        initialRect: rectA,
        initialAnchor: Alignment.center,
      );

      controller.transitionToRect(rectB, config: config);
      for (int i = 0; i < 90; i++) {
        controller.step(1.0 / 60.0, config);
      }
      expect(controller.currentRect.width, closeTo(rectB.width, 0.1));

      controller.transitionToRect(rectA, config: config);
      for (int i = 0; i < 90; i++) {
        controller.step(1.0 / 60.0, config);
      }

      expect(controller.currentRect.left, closeTo(rectA.left, 0.1));
      expect(controller.currentRect.top, closeTo(rectA.top, 0.1));
      expect(controller.currentRect.width, closeTo(rectA.width, 0.1));
      expect(controller.currentRect.height, closeTo(rectA.height, 0.1));
    });

    test('Mid-flight interruption A -> B -> A preserves continuity with no teleportation', () {
      const rectA = Rect.fromLTWH(20, 20, 60, 60);
      const rectB = Rect.fromLTWH(100, 100, 220, 180);

      final controller = QuickNotesMorphGeometryController(
        initialRect: rectA,
        initialAnchor: Alignment.center,
      );

      controller.transitionToRect(rectB, config: config);
      // Advance ~100ms mid-flight
      for (int i = 0; i < 6; i++) {
        controller.step(1.0 / 60.0, config);
      }

      final Rect liveBefore = controller.currentRect;
      expect(controller.isAnimating, isTrue);

      // Interrupt mid-flight back to A
      controller.transitionToRect(rectA, config: config);
      final Rect liveAfter = controller.currentRect;

      // Crucial: No teleportation on the frame of interruption
      expect(liveAfter.left, closeTo(liveBefore.left, 0.001));
      expect(liveAfter.top, closeTo(liveBefore.top, 0.001));
      expect(liveAfter.width, closeTo(liveBefore.width, 0.001));
      expect(liveAfter.height, closeTo(liveBefore.height, 0.001));

      // Settle back to A
      for (int i = 0; i < 90; i++) {
        controller.step(1.0 / 60.0, config);
      }
      expect(controller.currentRect.left, closeTo(rectA.left, 0.1));
      expect(controller.currentRect.top, closeTo(rectA.top, 0.1));
      expect(controller.currentRect.width, closeTo(rectA.width, 0.1));
      expect(controller.currentRect.height, closeTo(rectA.height, 0.1));
    });

    test('Live retargeting A -> B -> C transitions smoothly to C', () {
      const rectA = Rect.fromLTWH(10, 10, 50, 50);
      const rectB = Rect.fromLTWH(150, 150, 200, 200);
      const rectC = Rect.fromLTWH(50, 250, 120, 80);

      final controller = QuickNotesMorphGeometryController(
        initialRect: rectA,
        initialAnchor: Alignment.center,
      );

      controller.transitionToRect(rectB, config: config);
      for (int i = 0; i < 5; i++) {
        controller.step(1.0 / 60.0, config);
      }

      final Rect live = controller.currentRect;
      controller.transitionToRect(rectC, config: config);
      expect(controller.currentRect.left, closeTo(live.left, 0.001));

      for (int i = 0; i < 90; i++) {
        controller.step(1.0 / 60.0, config);
      }
      expect(controller.currentRect.left, closeTo(rectC.left, 0.1));
      expect(controller.currentRect.top, closeTo(rectC.top, 0.1));
      expect(controller.currentRect.width, closeTo(rectC.width, 0.1));
      expect(controller.currentRect.height, closeTo(rectC.height, 0.1));
    });

    test('Rapid transition bursts A -> B -> A -> B remain stable and finite', () {
      const rectA = Rect.fromLTWH(10, 10, 60, 60);
      const rectB = Rect.fromLTWH(100, 80, 200, 160);

      final controller = QuickNotesMorphGeometryController(
        initialRect: rectA,
        initialAnchor: Alignment.center,
      );

      for (int burst = 0; burst < 10; burst++) {
        controller.transitionToRect(burst.isEven ? rectB : rectA, config: config);
        controller.step(0.016, config);
        controller.step(0.016, config);

        final Rect current = controller.currentRect;
        expect(current.left.isFinite, isTrue);
        expect(current.top.isFinite, isTrue);
        expect(current.width.isFinite, isTrue);
        expect(current.height.isFinite, isTrue);
        expect(current.width, greaterThanOrEqualTo(1.0));
        expect(current.height, greaterThanOrEqualTo(1.0));
      }

      // Allow final settle
      for (int i = 0; i < 120; i++) {
        controller.step(1.0 / 60.0, config);
      }
      expect(controller.isAnimating, isFalse);
    });

    test('All 5 native spatial anchors settle with coincident anchor placement', () {
      const origins = [
        Alignment.center,
        Alignment.topLeft,
        Alignment.topRight,
        Alignment.bottomLeft,
        Alignment.bottomRight,
      ];

      const fromRect = Rect.fromLTWH(50, 50, 56, 56);
      const toRect = Rect.fromLTWH(20, 20, 260, 180);

      for (final anchor in origins) {
        final anchorConfig = config.copyWith(anchor: anchor);
        final controller = QuickNotesMorphGeometryController(
          initialRect: fromRect,
          initialAnchor: anchor,
        );

        controller.transitionToRect(toRect, config: anchorConfig);

        for (int i = 0; i < 100; i++) {
          controller.step(1.0 / 60.0, anchorConfig);
        }

        expect(controller.isAnimating, isFalse);
        final Offset actualAnchorPt = anchor.withinRect(controller.currentRect);
        final Offset expectedAnchorPt = anchor.withinRect(toRect);

        expect(actualAnchorPt.dx, closeTo(expectedAnchorPt.dx, 0.1),
            reason: 'Anchor $anchor X mismatch');
        expect(actualAnchorPt.dy, closeTo(expectedAnchorPt.dy, 0.1),
            reason: 'Anchor $anchor Y mismatch');
      }
    });

    test('Ticker self-stopping stops animation loop cleanly', () {
      const fromRect = Rect.fromLTWH(10, 10, 50, 50);
      const toRect = Rect.fromLTWH(20, 20, 100, 100);

      final controller = QuickNotesMorphGeometryController(
        initialRect: fromRect,
        initialAnchor: Alignment.center,
      );

      controller.transitionToRect(toRect, config: config);
      expect(controller.isAnimating, isTrue);

      bool stillAnimating = true;
      int frames = 0;
      while (stillAnimating && frames < 200) {
        stillAnimating = controller.step(1.0 / 60.0, config);
        frames++;
      }

      expect(stillAnimating, isFalse);
      expect(controller.isAnimating, isFalse);
      // Further steps return false without drift
      final Rect settledRect = controller.currentRect;
      expect(controller.step(1.0 / 60.0, config), isFalse);
      expect(controller.currentRect, settledRect);
    });
  });
}
