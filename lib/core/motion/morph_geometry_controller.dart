import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'harmonic_spring.dart';
import 'morph_geometry_config.dart';

/// Production 4D Morph Geometry Controller for Quick Notes Liquid Glass.
///
/// Models the morphing surface as a 4-dimensional decoupled spring system:
/// - Anchor X (`ax`)
/// - Anchor Y (`ay`)
/// - Width (`w`)
/// - Height (`h`)
///
/// Implements the physically validated Phase 8D-R2 asymmetric lead-follow choreography:
/// - **Growing** (`targetArea >= currentArea * 0.999`):
///   The spatial anchor `(ax, ay)` leads with amplified stiffness (`leadMultiplier`)
///   and lower damping (`leadZeta`), pulling the lens across space while size `(w, h)`
///   holds for `followDelaySeconds` before expanding.
/// - **Shrinking** (`targetArea < currentArea * 0.999`):
///   The size `(w, h)` collapses first with amplified stiffness and lower damping,
///   while the spatial anchor holds for `followDelaySeconds` before translating.
///
/// Features:
/// - **Live Interruption**: New targets are applied directly to the current live
///   spring geometry (`currentRect`) without resetting velocities or snapping.
/// - **Live Retargeting**: Mid-flight redirection to a 3rd destination transitions
///   smoothly from the current instantaneous velocity and position.
/// - **Native Anchor Semantics**: Preserves spatial coincident alignment based on
///   the specified [Alignment] anchor (Center, TopLeft, TopRight, etc.).
/// - **Ticker Self-Stopping**: Reports `isAnimating == false` as soon as all four
///   springs have settled and delays have elapsed, allowing animation loops to pause.
class QuickNotesMorphGeometryController {
  QuickNotesMorphGeometryController({
    required Rect initialRect,
    Alignment initialAnchor = Alignment.center,
  }) : _anchor = initialAnchor {
    seedInitialRect(initialRect, anchor: initialAnchor);
  }

  /// Spring driving the horizontal position of the reference anchor.
  final QuickNotesHarmonicSpring anchorXSpring = QuickNotesHarmonicSpring(0);

  /// Spring driving the vertical position of the reference anchor.
  final QuickNotesHarmonicSpring anchorYSpring = QuickNotesHarmonicSpring(0);

  /// Spring driving the surface width.
  final QuickNotesHarmonicSpring widthSpring = QuickNotesHarmonicSpring(1);

  /// Spring driving the surface height.
  final QuickNotesHarmonicSpring heightSpring = QuickNotesHarmonicSpring(1);

  Alignment _anchor;
  Rect _originRect = Rect.zero;
  Rect _targetRect = Rect.zero;
  bool _isSeeded = false;
  bool _isGrowing = true;

  double _anchorHoldRemaining = 0.0;
  double _sizeHoldRemaining = 0.0;
  double _anchorStiffnessMultiplier = 1.0;
  double _sizeStiffnessMultiplier = 1.0;
  double? _anchorZetaOverride;
  double? _sizeZetaOverride;

  int _activeFrameCount = 0;
  double _elapsedSeconds = 0.0;

  /// Current reference spatial anchor.
  Alignment get anchor => _anchor;

  /// Starting rectangle of the active transition.
  Rect get originRect => _originRect;

  /// Destination rectangle of the active transition.
  Rect get targetRect => _targetRect;

  /// Whether the controller has been initialized with a valid rectangle.
  bool get isSeeded => _isSeeded;

  /// Whether the current transition is expanding (`true`) or collapsing (`false`).
  bool get isGrowing => _isGrowing;

  /// Remaining hold time in seconds for the anchor spring.
  double get anchorHoldRemaining => _anchorHoldRemaining;

  /// Remaining hold time in seconds for the size spring.
  double get sizeHoldRemaining => _sizeHoldRemaining;

  /// Total frames evaluated during the current transition.
  int get activeFrameCount => _activeFrameCount;

  /// Total elapsed seconds since the current transition started.
  double get elapsedSeconds => _elapsedSeconds;

  /// Whether any dimension is actively moving or held.
  bool get isAnimating =>
      _anchorHoldRemaining > 0.0 ||
      _sizeHoldRemaining > 0.0 ||
      anchorXSpring.isMoving ||
      anchorYSpring.isMoving ||
      widthSpring.isMoving ||
      heightSpring.isMoving;

  /// Current visual rectangle reconstructed from `(ax, ay, w, h)` and `anchor`.
  /// Clamps width and height to `>= 1.0` so negative or zero dimensions never occur.
  Rect get currentRect {
    final double w = math.max(1.0, widthSpring.position);
    final double h = math.max(1.0, heightSpring.position);
    final double fx = (_anchor.x + 1.0) * 0.5;
    final double fy = (_anchor.y + 1.0) * 0.5;
    return Rect.fromLTWH(
      anchorXSpring.position - fx * w,
      anchorYSpring.position - fy * h,
      w,
      h,
    );
  }

  /// Snaps all 4 springs directly to [rect] with zero velocity.
  void seedInitialRect(Rect rect, {Alignment? anchor}) {
    if (anchor != null) {
      _anchor = anchor;
    }
    _originRect = rect;
    _targetRect = rect;
    _isSeeded = true;
    final Offset p = _anchor.withinRect(rect);
    anchorXSpring.snapTo(p.dx);
    anchorYSpring.snapTo(p.dy);
    widthSpring.snapTo(math.max(1.0, rect.width));
    heightSpring.snapTo(math.max(1.0, rect.height));
    _anchorHoldRemaining = 0.0;
    _sizeHoldRemaining = 0.0;
    _anchorStiffnessMultiplier = 1.0;
    _sizeStiffnessMultiplier = 1.0;
    _anchorZetaOverride = null;
    _sizeZetaOverride = null;
    _activeFrameCount = 0;
    _elapsedSeconds = 0.0;
  }

  /// Changes which point on the rectangle is tracked by `(ax, ay)` without
  /// moving the current visual rectangle or resetting velocity.
  void rebaseAnchor(Alignment newAnchor) {
    if (newAnchor == _anchor) return;
    final Rect live = currentRect;
    final double oldFx = (_anchor.x + 1.0) * 0.5;
    final double oldFy = (_anchor.y + 1.0) * 0.5;
    final Rect currentTarget = Rect.fromLTWH(
      anchorXSpring.target - oldFx * widthSpring.target,
      anchorYSpring.target - oldFy * heightSpring.target,
      widthSpring.target,
      heightSpring.target,
    );
    _anchor = newAnchor;
    final Offset liveAnchorPt = newAnchor.withinRect(live);
    final Offset targetAnchorPt = newAnchor.withinRect(currentTarget);
    anchorXSpring.setPositionAndTarget(liveAnchorPt.dx, targetAnchorPt.dx);
    anchorYSpring.setPositionAndTarget(liveAnchorPt.dy, targetAnchorPt.dy);
  }

  /// Initiates or retargets a transition from the live `currentRect` to [toRect].
  ///
  /// Guarantees continuity: if a transition is in progress, the current live
  /// position and velocity are preserved without resetting to origin or snapping.
  void transitionToRect(
    Rect toRect, {
    required QuickNotesMorphGeometryConfig config,
    bool applySeedScaleWhenGrowing = false,
  }) {
    if (!_isSeeded) {
      seedInitialRect(toRect, anchor: config.anchor);
      return;
    }

    final bool wasAnimating = isAnimating;
    final Rect fromRect = currentRect;
    _originRect = fromRect;
    _targetRect = toRect;

    rebaseAnchor(config.anchor);

    final double fromArea = fromRect.width * fromRect.height;
    final double toArea = toRect.width * toRect.height;
    _isGrowing = toArea >= fromArea * 0.999;

    final double leadMul = config.leadMultiplier;
    final double leadZeta = config.leadZeta;

    // Reset baseline multipliers before applying directional role assignment.
    _anchorStiffnessMultiplier = 1.0;
    _sizeStiffnessMultiplier = 1.0;
    _anchorZetaOverride = null;
    _sizeZetaOverride = null;
    _anchorHoldRemaining = 0.0;
    _sizeHoldRemaining = 0.0;

    if (_isGrowing) {
      if (applySeedScaleWhenGrowing && !wasAnimating && config.seedScale < 1.0) {
        final Size seedSize = Size(
          math.max(1.0, fromRect.width * config.seedScale),
          math.max(1.0, fromRect.height * config.seedScale),
        );
        final Offset anchorPt = _anchor.withinRect(fromRect);
        final Rect seeded = _clampSeedInside(fromRect, anchorPt, seedSize);
        final Offset seededAnchorPt = _anchor.withinRect(seeded);
        anchorXSpring.snapTo(seededAnchorPt.dx);
        anchorYSpring.snapTo(seededAnchorPt.dy);
        widthSpring.snapTo(seeded.width);
        heightSpring.snapTo(seeded.height);
      }

      final Offset targetAnchorPt = _anchor.withinRect(toRect);
      anchorXSpring.aimAt(targetAnchorPt.dx);
      anchorYSpring.aimAt(targetAnchorPt.dy);
      widthSpring.aimAt(math.max(1.0, toRect.width));
      heightSpring.aimAt(math.max(1.0, toRect.height));

      _anchorStiffnessMultiplier = leadMul;
      _anchorZetaOverride = leadZeta;
      _sizeHoldRemaining = config.followDelaySeconds;
    } else {
      // Shrinking: size collapses first at leadMul/leadZeta; anchor follows
      // after followDelaySeconds.
      final Offset targetAnchorPt = _anchor.withinRect(toRect);
      anchorXSpring.aimAt(targetAnchorPt.dx);
      anchorYSpring.aimAt(targetAnchorPt.dy);
      widthSpring.aimAt(math.max(1.0, toRect.width));
      heightSpring.aimAt(math.max(1.0, toRect.height));

      _sizeStiffnessMultiplier = leadMul;
      _sizeZetaOverride = leadZeta;
      _anchorHoldRemaining = config.followDelaySeconds;
    }

    _activeFrameCount = 0;
    _elapsedSeconds = 0.0;
  }

  /// Steps the 4D spring system forward by [dtSeconds].
  ///
  /// Returns `true` if the controller is still animating, or `false` once settled.
  bool step(double dtSeconds, QuickNotesMorphGeometryConfig config) {
    if (dtSeconds <= 0.0) return isAnimating;
    final double clampedDt = math.min(dtSeconds, 1.0 / 30.0);

    _activeFrameCount++;
    _elapsedSeconds += clampedDt;

    if (_anchorHoldRemaining > 0.0) {
      _anchorHoldRemaining = math.max(0.0, _anchorHoldRemaining - clampedDt);
    } else {
      final double kAnchor = config.stiffness * _anchorStiffnessMultiplier;
      final double dAnchor = _anchorZetaOverride != null
          ? 2.0 * _anchorZetaOverride! * math.sqrt(kAnchor)
          : config.damping * math.sqrt(_anchorStiffnessMultiplier);
      anchorXSpring.advance(clampedDt, stiffness: kAnchor, damping: dAnchor);
      anchorYSpring.advance(clampedDt, stiffness: kAnchor, damping: dAnchor);
    }

    if (_sizeHoldRemaining > 0.0) {
      _sizeHoldRemaining = math.max(0.0, _sizeHoldRemaining - clampedDt);
    } else {
      final double kSize = config.stiffness * _sizeStiffnessMultiplier;
      final double dSize = _sizeZetaOverride != null
          ? 2.0 * _sizeZetaOverride! * math.sqrt(kSize)
          : config.damping * math.sqrt(_sizeStiffnessMultiplier);
      widthSpring.advance(clampedDt, stiffness: kSize, damping: dSize);
      heightSpring.advance(clampedDt, stiffness: kSize, damping: dSize);
    }

    if (!isAnimating) {
      final Offset targetPt = _anchor.withinRect(_targetRect);
      anchorXSpring.snapTo(targetPt.dx);
      anchorYSpring.snapTo(targetPt.dy);
      widthSpring.snapTo(math.max(1.0, _targetRect.width));
      heightSpring.snapTo(math.max(1.0, _targetRect.height));
      return false;
    }
    return true;
  }

  static Rect _clampSeedInside(Rect bounds, Offset centerPt, Size seedSize) {
    double left = centerPt.dx - seedSize.width * 0.5;
    double top = centerPt.dy - seedSize.height * 0.5;
    if (seedSize.width <= bounds.width) {
      left = left.clamp(bounds.left, bounds.right - seedSize.width);
    }
    if (seedSize.height <= bounds.height) {
      top = top.clamp(bounds.top, bounds.bottom - seedSize.height);
    }
    return Rect.fromLTWH(left, top, seedSize.width, seedSize.height);
  }
}
