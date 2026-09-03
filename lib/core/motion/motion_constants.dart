import 'dart:math';
import 'package:flutter/animation.dart';

/// Phase P1 — Home Screen Motion Lab Tokens
///
/// Refined physical motion constants calibrated for tactile responsiveness,
/// physical coherence, subtle overshoot, and rapid settling.
class QuickNotesMotion {
  QuickNotesMotion._();

  // ── Durations ─────────────────────────────────────────────────────────────
  /// Micro interaction duration (touch-down compression, button depress).
  static const Duration kMotionMicro = Duration(milliseconds: 90);

  /// Fast tactile release and return duration.
  static const Duration kMotionRelease = Duration(milliseconds: 190);

  /// Navigation indicator and segmented switcher transit duration.
  static const Duration kMotionSelection = Duration(milliseconds: 260);

  /// Note opening route transition duration.
  static const Duration kMotionPage = Duration(milliseconds: 340);

  /// Note opening reverse route transition duration.
  static const Duration kMotionPageReverse = Duration(milliseconds: 260);

  // ── Curves ───────────────────────────────────────────────────────────────
  /// Apple-style emphasized ease-out for document surface navigation.
  static const Curve kMotionAppleEase = Cubic(0.20, 0.0, 0.0, 1.0);

  /// Snappy cubic curve with gentle overshoot for magnetic switching.
  static const Curve kMotionSnappy = Cubic(0.20, 1.12, 0.40, 1.0);

  /// Physics-based damped spring curve (zeta ≈ 0.80, 1.5% subtle overshoot).
  static const Curve kMotionSpring = DampedSpringCurve();
}

/// A closed-form damped harmonic oscillator curve.
///
/// Implements the exact physics of an underdamped spring with damping ratio [damping]
/// and natural angular frequency [stiffness].
///
/// Produces a subtle, physical arrival overshoot (~1.5%) that settles cleanly
/// to 1.0 without visible lingering oscillations or long tails.
class DampedSpringCurve extends Curve {
  final double damping;
  final double stiffness;

  const DampedSpringCurve({
    this.damping = 0.80,
    this.stiffness = 11.5,
  })  : assert(damping > 0.0 && damping < 1.0, 'Damping must be underdamped (0 < zeta < 1)'),
        assert(stiffness > 0.0, 'Stiffness must be positive');

  @override
  double transformInternal(double t) {
    if (t <= 0.0) return 0.0;
    if (t >= 1.0) return 1.0;

    final double omegaD = stiffness * sqrt(1.0 - damping * damping);
    final double decay = exp(-damping * stiffness * t);
    final double sinTerm = (damping / sqrt(1.0 - damping * damping)) * sin(omegaD * t);
    final double cosTerm = cos(omegaD * t);

    final double value = 1.0 - decay * (cosTerm + sinTerm);
    return value;
  }
}
