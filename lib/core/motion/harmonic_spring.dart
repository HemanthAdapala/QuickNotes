/// Minimal, isolated 1D damped harmonic oscillator for Quick Notes Liquid Glass Morph.
///
/// Represents an animated physical spring dimension tracking a target value.
/// Uses semi-implicit (symplectic) Euler integration with velocity conservation:
/// when a target changes mid-flight (live interruption or retargeting), the current
/// position and velocity are preserved continuously without snapping or resetting.
class QuickNotesHarmonicSpring {
  QuickNotesHarmonicSpring(double initialValue)
      : _position = initialValue,
        _target = initialValue,
        _velocity = 0.0;

  double _position;
  double _target;
  double _velocity;

  /// Distance threshold below which position is considered settled at target.
  static const double kPositionRestThreshold = 0.25;

  /// Velocity threshold below which movement is considered negligible.
  static const double kVelocityRestThreshold = 2.0;

  /// Current live position of the spring.
  double get position => _position;

  /// Current destination target of the spring.
  double get target => _target;

  /// Current live velocity of the spring (units per second).
  double get velocity => _velocity;

  /// Whether the spring is still moving toward its target.
  bool get isMoving =>
      (_position - _target).abs() > kPositionRestThreshold ||
      _velocity.abs() > kVelocityRestThreshold;

  /// Rebinds the current live position and target without resetting velocity.
  ///
  /// Used during anchor rebasing to shift coordinate reference frames continuously.
  void setPositionAndTarget(double pos, double tgt) {
    _position = pos;
    _target = tgt;
  }

  /// Retargets the spring to [newTarget] while keeping live position and velocity.
  ///
  /// This ensures continuous, non-teleporting motion when destinations change mid-flight.
  void aimAt(double newTarget) {
    _target = newTarget;
  }

  /// Instantly teleports the spring to [value] and halts all motion.
  void snapTo(double value) {
    _position = value;
    _target = value;
    _velocity = 0.0;
  }

  /// Advances the spring simulation by [dtSeconds] using semi-implicit Euler integration.
  ///
  /// Guarded against non-finite values (NaN, Infinity) and degenerate time steps.
  void advance(
    double dtSeconds, {
    required double stiffness,
    required double damping,
  }) {
    if (dtSeconds <= 0.0) return;

    if (!isMoving) {
      _position = _target;
      _velocity = 0.0;
      return;
    }

    final double displacement = _position - _target;
    final double acceleration =
        (-stiffness * displacement) - (damping * _velocity);

    _velocity += acceleration * dtSeconds;
    _position += _velocity * dtSeconds;

    if (!_position.isFinite || !_velocity.isFinite) {
      _position = _target;
      _velocity = 0.0;
      return;
    }

    if (!isMoving) {
      _position = _target;
      _velocity = 0.0;
    }
  }
}
