import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'morph_content_controller.dart';
import 'morph_geometry_config.dart';

/// Formalized, immutable visual motion preset derived strictly from the
/// physically validated Quick Notes Morph Fidelity Lab.
///
/// Encapsulates harmonic spring geometry parameters, asymmetric lead-follow
/// coordination, and content layer transition curves.
///
/// Validated Lab Presets:
/// - [QuickNotesVisualPreset.baseline]: Phase 8C-A / 8D-R2 golden baseline with
///   pronounced asymmetric stretch (`stretch = 0.75`, `leadBounce = 0.10`, `followDelay = 40ms`).
/// - [QuickNotesVisualPreset.balanced]: Coupled 4D spring with zero lag and zero stretch
///   (`stretch = 0.0`, `leadBounce = 0.0`, `followDelay = 0ms`) producing balanced, linear travel.
/// - [QuickNotesVisualPreset.anchorLocked]: Native-inspired anchored lock matching placement
///   alignment with subtle stretch (`stretch = 0.20`, `leadBounce = 0.0`, `followDelay = 0ms`).
@immutable
class QuickNotesVisualPreset {
  const QuickNotesVisualPreset({
    required this.name,
    this.stiffness = 195.0,
    this.damping = 19.5,
    this.stretch = 0.75,
    this.leadBounce = 0.10,
    this.followDelaySeconds = 0.04,
    this.contentBlur = 8.0,
    this.contentFollow = 1.0,
    this.contentSlide = 0.0,
    this.contentOutEnd = 0.40,
    this.contentInStart = 0.30,
    this.contentInEnd = 0.80,
    this.oldScaleTo = 0.92,
    this.newScaleFrom = 0.90,
  })  : assert(stiffness > 0, 'stiffness must be positive'),
        assert(damping >= 0, 'damping must be non-negative'),
        assert(stretch >= 0.0 && stretch <= 1.0, 'stretch must be within [0, 1]'),
        assert(leadBounce >= 0.0, 'leadBounce cannot be negative'),
        assert(followDelaySeconds >= 0.0, 'followDelaySeconds cannot be negative'),
        assert(contentOutEnd > 0.0 && contentOutEnd <= 1.0,
            'contentOutEnd must be within (0, 1]'),
        assert(contentInStart >= 0.0 && contentInStart < 1.0,
            'contentInStart must be within [0, 1)'),
        assert(contentInEnd > 0.0 && contentInEnd <= 1.0,
            'contentInEnd must be within (0, 1]'),
        assert(contentInStart < contentInEnd,
            'contentInStart must be strictly less than contentInEnd');

  /// Identifiable name of this visual preset.
  final String name;

  /// Baseline spring stiffness $k$ (N/m equivalent).
  final double stiffness;

  /// Baseline viscous damping coefficient $c$.
  final double damping;

  /// Asymmetric stretch factor governing lead stiffness amplification ($1 + 2.2 \times \text{stretch}$).
  final double stretch;

  /// Lead damping ratio reduction factor ($\zeta_{\text{lead}} = \zeta_{\text{base}} - \text{leadBounce}$).
  final double leadBounce;

  /// Delay in seconds before the following dimension starts moving.
  final double followDelaySeconds;

  /// Maximum Gaussian blur sigma applied to content during mid-flight crossfade.
  final double contentBlur;

  /// Spatial follow ratio `[0..1]` governing how content rides the moving glass surface.
  final double contentFollow;

  /// Normalized directional slide offset along travel direction.
  final double contentSlide;

  /// Normalized progress `[0..1]` at which outgoing content reaches `0` opacity.
  final double contentOutEnd;

  /// Normalized progress `[0..1]` at which incoming content begins fading in.
  final double contentInStart;

  /// Normalized progress `[0..1]` at which incoming content reaches `1` opacity.
  final double contentInEnd;

  /// Target scale for outgoing content during crossfade exit.
  final double oldScaleTo;

  /// Starting scale for incoming content during crossfade enter.
  final double newScaleFrom;

  // ---------------------------------------------------------------------------
  // Formalized Validated Presets
  // ---------------------------------------------------------------------------

  /// Baseline Phase 8C-A / 8D-R2 golden reference choreography.
  ///
  /// Represents the exact physically validated Locked Configuration:
  /// - Geometry Spring: Stiffness 195.0, Damping 19.5
  /// - Stretch: 0.75, Lead Bounce: 0.10, Follow Delay: 40ms (0.04s)
  /// - Content Timing: OutEnd 0.40, InStart 0.30, InEnd 0.80
  /// - Content Scale: OldScaleTo 0.92, NewScaleFrom 0.90
  /// - Content Optics: Blur 8.0, Follow 1.0, Slide 0.0
  static const QuickNotesVisualPreset baseline = QuickNotesVisualPreset(
    name: 'Baseline',
    stiffness: 195.0,
    damping: 19.5,
    stretch: 0.75,
    leadBounce: 0.10,
    followDelaySeconds: 0.04,
    contentBlur: 8.0,
    contentFollow: 1.0,
    contentSlide: 0.0,
    contentOutEnd: 0.40,
    contentInStart: 0.30,
    contentInEnd: 0.80,
    oldScaleTo: 0.92,
    newScaleFrom: 0.90,
  );

  /// Balanced coordination: zero lag between anchor and size springs, zero bounce,
  /// yielding a straight-line, coupled visual transformation.
  static const QuickNotesVisualPreset balanced = QuickNotesVisualPreset(
    name: 'Balanced',
    stiffness: 195.0,
    damping: 19.5,
    stretch: 0.0,
    leadBounce: 0.0,
    followDelaySeconds: 0.0,
    contentBlur: 8.0,
    contentFollow: 1.0,
    contentSlide: 0.0,
    contentOutEnd: 0.40,
    contentInStart: 0.30,
    contentInEnd: 0.80,
    oldScaleTo: 0.92,
    newScaleFrom: 0.90,
  );

  /// Anchor-Locked coordination: spatial anchor locks firmly to placement alignment
  /// with subtle stretch (`0.20`), zero bounce, and zero hold delay.
  static const QuickNotesVisualPreset anchorLocked = QuickNotesVisualPreset(
    name: 'Anchor Locked',
    stiffness: 195.0,
    damping: 19.5,
    stretch: 0.20,
    leadBounce: 0.0,
    followDelaySeconds: 0.0,
    contentBlur: 8.0,
    contentFollow: 1.0,
    contentSlide: 0.0,
    contentOutEnd: 0.40,
    contentInStart: 0.30,
    contentInEnd: 0.80,
    oldScaleTo: 0.92,
    newScaleFrom: 0.90,
  );

  // ---------------------------------------------------------------------------
  // Conversion to Core Motion Configs
  // ---------------------------------------------------------------------------

  /// Converts this preset into an immutable [QuickNotesMorphGeometryConfig] with
  /// the specified spatial [anchor].
  QuickNotesMorphGeometryConfig toGeometryConfig({Alignment anchor = Alignment.center}) {
    return QuickNotesMorphGeometryConfig(
      stiffness: stiffness,
      damping: damping,
      stretch: stretch,
      leadBounce: leadBounce,
      followDelaySeconds: followDelaySeconds,
      anchor: anchor,
    );
  }

  /// Converts this preset into an immutable [QuickNotesMorphContentConfig].
  QuickNotesMorphContentConfig toContentConfig({Alignment anchor = Alignment.center}) {
    return QuickNotesMorphContentConfig(
      contentOutEnd: contentOutEnd,
      contentInStart: contentInStart,
      contentInEnd: contentInEnd,
      contentBlur: contentBlur,
      contentFollow: contentFollow,
      contentSlide: contentSlide,
      oldScaleTo: oldScaleTo,
      newScaleFrom: newScaleFrom,
      anchor: anchor,
    );
  }

  // ---------------------------------------------------------------------------
  // Composable Overrides
  // ---------------------------------------------------------------------------

  /// Creates a modified copy with new spring stiffness and damping.
  QuickNotesVisualPreset withMotion({double? stiffness, double? damping}) {
    return copyWith(
      stiffness: stiffness,
      damping: damping,
    );
  }

  /// Creates a modified copy with customized asymmetric stretch parameters.
  QuickNotesVisualPreset withStretch({
    double? stretch,
    double? leadBounce,
    double? followDelaySeconds,
  }) {
    return copyWith(
      stretch: stretch,
      leadBounce: leadBounce,
      followDelaySeconds: followDelaySeconds,
    );
  }

  /// Creates a modified copy with customized content crossfade parameters.
  QuickNotesVisualPreset withContent({
    double? contentBlur,
    double? contentFollow,
    double? contentSlide,
    double? contentOutEnd,
    double? contentInStart,
    double? contentInEnd,
    double? oldScaleTo,
    double? newScaleFrom,
  }) {
    return copyWith(
      contentBlur: contentBlur,
      contentFollow: contentFollow,
      contentSlide: contentSlide,
      contentOutEnd: contentOutEnd,
      contentInStart: contentInStart,
      contentInEnd: contentInEnd,
      oldScaleTo: oldScaleTo,
      newScaleFrom: newScaleFrom,
    );
  }

  /// Creates a full clone with any individual parameters overridden.
  QuickNotesVisualPreset copyWith({
    String? name,
    double? stiffness,
    double? damping,
    double? stretch,
    double? leadBounce,
    double? followDelaySeconds,
    double? contentBlur,
    double? contentFollow,
    double? contentSlide,
    double? contentOutEnd,
    double? contentInStart,
    double? contentInEnd,
    double? oldScaleTo,
    double? newScaleFrom,
  }) {
    return QuickNotesVisualPreset(
      name: name ?? this.name,
      stiffness: stiffness ?? this.stiffness,
      damping: damping ?? this.damping,
      stretch: stretch ?? this.stretch,
      leadBounce: leadBounce ?? this.leadBounce,
      followDelaySeconds: followDelaySeconds ?? this.followDelaySeconds,
      contentBlur: contentBlur ?? this.contentBlur,
      contentFollow: contentFollow ?? this.contentFollow,
      contentSlide: contentSlide ?? this.contentSlide,
      contentOutEnd: contentOutEnd ?? this.contentOutEnd,
      contentInStart: contentInStart ?? this.contentInStart,
      contentInEnd: contentInEnd ?? this.contentInEnd,
      oldScaleTo: oldScaleTo ?? this.oldScaleTo,
      newScaleFrom: newScaleFrom ?? this.newScaleFrom,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QuickNotesVisualPreset &&
        other.name == name &&
        other.stiffness == stiffness &&
        other.damping == damping &&
        other.stretch == stretch &&
        other.leadBounce == leadBounce &&
        other.followDelaySeconds == followDelaySeconds &&
        other.contentBlur == contentBlur &&
        other.contentFollow == contentFollow &&
        other.contentSlide == contentSlide &&
        other.contentOutEnd == contentOutEnd &&
        other.contentInStart == contentInStart &&
        other.contentInEnd == contentInEnd &&
        other.oldScaleTo == oldScaleTo &&
        other.newScaleFrom == newScaleFrom;
  }

  @override
  int get hashCode => Object.hash(
        name,
        stiffness,
        damping,
        stretch,
        leadBounce,
        followDelaySeconds,
        contentBlur,
        contentFollow,
        contentSlide,
        contentOutEnd,
        contentInStart,
        contentInEnd,
        oldScaleTo,
        newScaleFrom,
      );

  @override
  String toString() {
    return 'QuickNotesVisualPreset($name: k=$stiffness, c=$damping, stretch=$stretch, delay=${(followDelaySeconds * 1000).toStringAsFixed(0)}ms)';
  }
}
