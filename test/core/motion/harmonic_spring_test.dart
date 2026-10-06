import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/core/motion/harmonic_spring.dart';

void main() {
  group('QuickNotesHarmonicSpring', () {
    test('initial state matches constructed value with zero velocity', () {
      final spring = QuickNotesHarmonicSpring(100.0);
      expect(spring.position, 100.0);
      expect(spring.target, 100.0);
      expect(spring.velocity, 0.0);
      expect(spring.isMoving, isFalse);
    });

    test('aimAt updates target while preserving live position and velocity', () {
      final spring = QuickNotesHarmonicSpring(0.0);
      spring.advance(0.016, stiffness: 195.0, damping: 19.5);
      expect(spring.isMoving, isFalse);

      spring.aimAt(200.0);
      expect(spring.position, 0.0);
      expect(spring.target, 200.0);
      expect(spring.velocity, 0.0);
      expect(spring.isMoving, isTrue);

      // Advance a few steps to build velocity
      spring.advance(0.016, stiffness: 195.0, damping: 19.5);
      final double midPos = spring.position;
      final double midVel = spring.velocity;
      expect(midPos, greaterThan(0.0));
      expect(midVel, greaterThan(0.0));

      // Interrupt mid-flight to new target
      spring.aimAt(50.0);
      expect(spring.position, midPos);
      expect(spring.velocity, midVel);
      expect(spring.target, 50.0);
    });

    test('setPositionAndTarget shifts coordinates while preserving velocity', () {
      final spring = QuickNotesHarmonicSpring(0.0);
      spring.aimAt(100.0);
      spring.advance(0.032, stiffness: 195.0, damping: 19.5);
      final double liveVel = spring.velocity;
      expect(liveVel, isNonZero);

      spring.setPositionAndTarget(50.0, 150.0);
      expect(spring.position, 50.0);
      expect(spring.target, 150.0);
      expect(spring.velocity, liveVel);
    });

    test('snapTo teleports position, target, and clears velocity', () {
      final spring = QuickNotesHarmonicSpring(0.0);
      spring.aimAt(100.0);
      spring.advance(0.016, stiffness: 195.0, damping: 19.5);
      expect(spring.velocity, isNonZero);

      spring.snapTo(42.0);
      expect(spring.position, 42.0);
      expect(spring.target, 42.0);
      expect(spring.velocity, 0.0);
      expect(spring.isMoving, isFalse);
    });

    test('settles cleanly at target within reasonable time', () {
      final spring = QuickNotesHarmonicSpring(0.0);
      spring.aimAt(100.0);

      // Advance for 1.0 second (60 frames at 16.6ms)
      for (int i = 0; i < 60; i++) {
        spring.advance(1.0 / 60.0, stiffness: 195.0, damping: 19.5);
      }

      expect(spring.isMoving, isFalse);
      expect(spring.position, closeTo(100.0, 0.01));
      expect(spring.velocity, 0.0);
    });

    test('handles small, normal, and large frame deltas without diverging', () {
      // Very small delta
      final springSmall = QuickNotesHarmonicSpring(0.0);
      springSmall.aimAt(100.0);
      for (int i = 0; i < 500; i++) {
        springSmall.advance(0.002, stiffness: 195.0, damping: 19.5);
      }
      expect(springSmall.position, closeTo(100.0, 0.01));

      // Normal 60fps delta
      final springNorm = QuickNotesHarmonicSpring(0.0);
      springNorm.aimAt(100.0);
      for (int i = 0; i < 60; i++) {
        springNorm.advance(1.0 / 60.0, stiffness: 195.0, damping: 19.5);
      }
      expect(springNorm.position, closeTo(100.0, 0.01));

      // Larger 30fps clamped delta
      final springLarge = QuickNotesHarmonicSpring(0.0);
      springLarge.aimAt(100.0);
      for (int i = 0; i < 35; i++) {
        springLarge.advance(1.0 / 30.0, stiffness: 195.0, damping: 19.5);
      }
      expect(springLarge.position, closeTo(100.0, 0.01));
    });

    test('guards against non-positive dt and non-finite values', () {
      final spring = QuickNotesHarmonicSpring(50.0);
      spring.advance(0.0, stiffness: 195.0, damping: 19.5);
      expect(spring.position, 50.0);

      spring.advance(-0.016, stiffness: 195.0, damping: 19.5);
      expect(spring.position, 50.0);

      // Force extreme acceleration to test finite guard
      spring.aimAt(1e12);
      spring.advance(10.0, stiffness: 1e12, damping: 0.0);
      expect(spring.position.isFinite, isTrue);
      expect(spring.velocity.isFinite, isTrue);
    });
  });
}
