import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Immutable configuration for the Quick Notes 4D Liquid Glass Morph Geometry Engine.
///
/// Contains the physically validated parameters frozen in Phase 8D-R2:
/// - `stiffness = 195.0`
/// - `damping = 19.5`
/// - `stretch = 0.75`
/// - `leadBounce = 0.10`
/// - `followDelaySeconds = 0.04` (40 ms)
///
/// These values produce asymmetric lead-follow dynamics where the leading dimension
/// travels with amplified stiffness (`leadMultiplier = 1 + 2.2 * stretch`) and reduced
/// damping (`leadZeta`), while the following dimension holds for `followDelaySeconds`.
@immutable
class QuickNotesMorphGeometryConfig {
  const QuickNotesMorphGeometryConfig({
    this.stiffness = 195.0,
    this.damping = 19.5,
    this.stretch = 0.75,
    this.leadBounce = 0.10,
    this.followDelaySeconds = 0.04,
    this.seedScale = 1.0,
    this.anchor = Alignment.center,
  })  : assert(stiffness > 0, 'stiffness must be positive'),
        assert(damping >= 0, 'damping must be non-negative'),
        assert(stretch >= 0.0 && stretch <= 1.0, 'stretch must be within [0, 1]'),
        assert(followDelaySeconds >= 0.0, 'followDelaySeconds cannot be negative'),
        assert(seedScale > 0.0 && seedScale <= 1.0, 'seedScale must be within (0, 1]');

  /// Baseline spring stiffness $k$ ($N/m$ equivalent). Default is 195.0.
  final double stiffness;

  /// Baseline viscous damping coefficient $c$. Default is 19.5.
  final double damping;

  /// Asymmetric stretch factor governing lead stiffness amplification ($1 + 2.2 \times \text{stretch}$).
  /// Default is 0.75.
  final double stretch;

  /// Lead damping ratio reduction factor ($\zeta_{\text{lead}} = \zeta_{\text{base}} - \text{leadBounce}$).
  /// Default is 0.10.
  final double leadBounce;

  /// Delay in seconds before the following dimension starts moving.
  /// Default is 0.04 (40 ms).
  final double followDelaySeconds;

  /// Birth scale factor for growing transitions (1.0 = native size).
  final double seedScale;

  /// Spatial reference anchor on the geometry (default is Alignment.center).
  final Alignment anchor;

  /// Base damping ratio $\zeta = c / (2\sqrt{k})$.
  double get baseZeta => damping / (2.0 * math.sqrt(stiffness));

  /// Characteristic period $T = 2\pi / \sqrt{k}$ in seconds.
  double get periodSeconds => 2.0 * math.pi / math.sqrt(stiffness);

  /// Native-inspired lead stiffness multiplier $1 + 2.2 \times \text{stretch}$.
  double get leadMultiplier => 1.0 + 2.2 * stretch;

  /// Leading spring pair damping ratio $\text{clamp}(\zeta_{\text{base}} - \text{leadBounce}, 0.05, 4.0)$.
  double get leadZeta => (baseZeta - leadBounce).clamp(0.05, 4.0);

  QuickNotesMorphGeometryConfig copyWith({
    double? stiffness,
    double? damping,
    double? stretch,
    double? leadBounce,
    double? followDelaySeconds,
    double? seedScale,
    Alignment? anchor,
  }) {
    return QuickNotesMorphGeometryConfig(
      stiffness: stiffness ?? this.stiffness,
      damping: damping ?? this.damping,
      stretch: stretch ?? this.stretch,
      leadBounce: leadBounce ?? this.leadBounce,
      followDelaySeconds: followDelaySeconds ?? this.followDelaySeconds,
      seedScale: seedScale ?? this.seedScale,
      anchor: anchor ?? this.anchor,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QuickNotesMorphGeometryConfig &&
        other.stiffness == stiffness &&
        other.damping == damping &&
        other.stretch == stretch &&
        other.leadBounce == leadBounce &&
        other.followDelaySeconds == followDelaySeconds &&
        other.seedScale == seedScale &&
        other.anchor == anchor;
  }

  @override
  int get hashCode => Object.hash(
        stiffness,
        damping,
        stretch,
        leadBounce,
        followDelaySeconds,
        seedScale,
        anchor,
      );

  @override
  String toString() {
    return 'QuickNotesMorphGeometryConfig(stiffness: $stiffness, damping: $damping, '
        'stretch: $stretch, leadBounce: $leadBounce, followDelay: ${followDelaySeconds}s, '
        'seedScale: $seedScale, anchor: $anchor)';
  }
}
