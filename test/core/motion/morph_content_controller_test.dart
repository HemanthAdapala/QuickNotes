import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/core/motion/morph_content_controller.dart';

enum TestContentState {
  circle,
  square,
  banner,
}

void main() {
  const config = QuickNotesMorphContentConfig();
  const double stiffness = 195.0;

  group('QuickNotesMorphContentController', () {
    test('initial state seeds cleanly at rest', () {
      final controller = QuickNotesMorphContentController<TestContentState>(
        initialState: TestContentState.circle,
        initialRect: const Rect.fromLTWH(0, 0, 56, 56),
      );

      expect(controller.isSeeded, isTrue);
      expect(controller.incomingState, TestContentState.circle);
      expect(controller.outgoingState, isNull);
      expect(controller.secondaryOutgoingState, isNull);
      expect(controller.isAnimating, isFalse);
      expect(controller.progress, 1.0);
    });

    test('calculates nominal duration from spring stiffness', () {
      final double duration = QuickNotesMorphContentController.durationForStiffness(stiffness);
      expect(duration, closeTo(0.4499, 0.01));
    });

    test('evaluates outgoing and incoming opacity timing curves accurately', () {
      final controller = QuickNotesMorphContentController<TestContentState>();
      controller.seedInitialState(
        stateId: TestContentState.circle,
        stateRect: const Rect.fromLTWH(0, 0, 56, 56),
      );

      controller.transitionToState(
        targetState: TestContentState.square,
        targetRect: const Rect.fromLTWH(0, 0, 200, 200),
        liveGlassRect: const Rect.fromLTWH(0, 0, 56, 56),
        config: config,
        stiffness: stiffness,
      );

      // t = 0.0: Outgoing is full (1.0), Incoming is zero (0.0)
      expect(controller.evaluateOutgoingLevel(0.0, config), closeTo(1.0, 0.001));
      expect(controller.evaluateIncomingLevel(0.0, config), closeTo(0.0, 0.001));

      // t = 0.20: Outgoing has begun fading, Incoming has not started yet (contentInStart = 0.30)
      final double outAt02 = controller.evaluateOutgoingLevel(0.20, config);
      expect(outAt02, lessThan(1.0));
      expect(outAt02, greaterThan(0.0));
      expect(controller.evaluateIncomingLevel(0.20, config), closeTo(0.0, 0.001));

      // t = 0.35: In overlap window (outgoing > 0 and incoming > 0)
      final double outAt035 = controller.evaluateOutgoingLevel(0.35, config);
      final double inAt035 = controller.evaluateIncomingLevel(0.35, config);
      expect(outAt035, greaterThan(0.0));
      expect(inAt035, greaterThan(0.0));

      // t = 0.40: Outgoing has reached 0.0 (contentOutEnd = 0.40)
      expect(controller.evaluateOutgoingLevel(0.40, config), closeTo(0.0, 0.001));

      // t = 0.80: Incoming has reached 1.0 (contentInEnd = 0.80)
      expect(controller.evaluateIncomingLevel(0.80, config), closeTo(1.0, 0.001));
      expect(controller.evaluateIncomingLevel(1.0, config), closeTo(1.0, 0.001));
    });

    test('evaluateAt generates valid scale, blur, and snapshot properties', () {
      final controller = QuickNotesMorphContentController<TestContentState>();
      controller.seedInitialState(
        stateId: TestContentState.circle,
        stateRect: const Rect.fromLTWH(0, 0, 56, 56),
      );

      controller.transitionToState(
        targetState: TestContentState.square,
        targetRect: const Rect.fromLTWH(100, 100, 200, 200),
        liveGlassRect: const Rect.fromLTWH(0, 0, 56, 56),
        config: config,
        stiffness: stiffness,
      );

      // Evaluate at mid-flight t = 0.35
      final snapshot = controller.evaluateAt(
        t: 0.35,
        currentGlassRect: const Rect.fromLTWH(35, 35, 100, 100),
        config: config,
      );

      expect(snapshot.isInOverlapWindow, isTrue);
      expect(snapshot.incoming.scale, greaterThanOrEqualTo(config.newScaleFrom));
      expect(snapshot.incoming.scale, lessThanOrEqualTo(1.0));
      expect(snapshot.incoming.blurSigma, greaterThan(0.0));
      expect(snapshot.outgoing, isNotNull);
      expect(snapshot.outgoing!.scale, lessThanOrEqualTo(1.0));
      expect(snapshot.outgoing!.scale, greaterThanOrEqualTo(config.oldScaleTo));

      // Evaluate settled t = 1.0
      final settledSnapshot = controller.evaluateAt(
        t: 1.0,
        currentGlassRect: const Rect.fromLTWH(100, 100, 200, 200),
        config: config,
      );

      expect(settledSnapshot.incoming.opacity, closeTo(1.0, 0.001));
      expect(settledSnapshot.incoming.scale, closeTo(1.0, 0.001));
      expect(settledSnapshot.incoming.blurSigma, 0.0);
    });

    test('Mid-flight interruption A -> B -> A reverses smoothly without opacity flash', () {
      final controller = QuickNotesMorphContentController<TestContentState>();
      controller.seedInitialState(
        stateId: TestContentState.circle,
        stateRect: const Rect.fromLTWH(0, 0, 56, 56),
      );

      controller.transitionToState(
        targetState: TestContentState.square,
        targetRect: const Rect.fromLTWH(100, 100, 200, 200),
        liveGlassRect: const Rect.fromLTWH(0, 0, 56, 56),
        config: config,
        stiffness: stiffness,
      );

      // Step until t ≈ 0.35 (overlap window)
      for (int i = 0; i < 10; i++) {
        controller.step(0.016, config);
      }

      final double midProgress = controller.progress;
      expect(midProgress, greaterThan(0.30));
      expect(midProgress, lessThan(0.40));

      final double liveOutLevel = controller.evaluateOutgoingLevel(midProgress, config);
      final double liveInLevel = controller.evaluateIncomingLevel(midProgress, config);
      expect(liveOutLevel, greaterThan(0.0));
      expect(liveInLevel, greaterThan(0.0));

      // Interrupt back to Circle
      controller.transitionToState(
        targetState: TestContentState.circle,
        targetRect: const Rect.fromLTWH(0, 0, 56, 56),
        liveGlassRect: const Rect.fromLTWH(35, 35, 100, 100),
        config: config,
        stiffness: stiffness,
      );

      expect(controller.incomingState, TestContentState.circle);
      expect(controller.outgoingState, TestContentState.square);

      // Circle (incoming) resumes from previous live outgoing level (not 0.0!)
      expect(controller.dstFrom, closeTo(liveOutLevel, 0.01));
      // Square (outgoing) leaves from previous live incoming level (not 1.0!)
      expect(controller.srcFrom, closeTo(liveInLevel, 0.01));

      // At t = 0 of the reversal, opacity must match exactly the interrupted frame
      final double reversedInAt0 = controller.evaluateIncomingLevel(0.0, config);
      final double reversedOutAt0 = controller.evaluateOutgoingLevel(0.0, config);
      expect(reversedInAt0, closeTo(liveOutLevel, 0.01));
      expect(reversedOutAt0, closeTo(liveInLevel, 0.01));
    });

    test('Retargeting A -> B -> C retains secondary outgoing during overlap', () {
      final controller = QuickNotesMorphContentController<TestContentState>();
      controller.seedInitialState(
        stateId: TestContentState.circle,
        stateRect: const Rect.fromLTWH(0, 0, 56, 56),
      );

      controller.transitionToState(
        targetState: TestContentState.square,
        targetRect: const Rect.fromLTWH(100, 100, 200, 200),
        liveGlassRect: const Rect.fromLTWH(0, 0, 56, 56),
        config: config,
        stiffness: stiffness,
      );

      // Advance to overlap window
      for (int i = 0; i < 10; i++) {
        controller.step(0.016, config);
      }

      // Retarget to Banner
      controller.transitionToState(
        targetState: TestContentState.banner,
        targetRect: const Rect.fromLTWH(50, 50, 150, 80),
        liveGlassRect: const Rect.fromLTWH(35, 35, 100, 100),
        config: config,
        stiffness: stiffness,
      );

      expect(controller.incomingState, TestContentState.banner);
      expect(controller.outgoingState, TestContentState.square);
      expect(controller.secondaryOutgoingState, TestContentState.circle);
    });

    test('step finishes cleanly and deactivates animation clock', () {
      final controller = QuickNotesMorphContentController<TestContentState>();
      controller.seedInitialState(
        stateId: TestContentState.circle,
        stateRect: const Rect.fromLTWH(0, 0, 56, 56),
      );

      controller.transitionToState(
        targetState: TestContentState.square,
        targetRect: const Rect.fromLTWH(0, 0, 200, 200),
        liveGlassRect: const Rect.fromLTWH(0, 0, 56, 56),
        config: config,
        stiffness: stiffness,
      );

      expect(controller.isAnimating, isTrue);

      bool stillAnimating = true;
      int steps = 0;
      while (stillAnimating && steps < 100) {
        stillAnimating = controller.step(1.0 / 60.0, config);
        steps++;
      }

      expect(stillAnimating, isFalse);
      expect(controller.isAnimating, isFalse);
      expect(controller.outgoingState, isNull);
      expect(controller.progress, 1.0);
    });
  });
}
