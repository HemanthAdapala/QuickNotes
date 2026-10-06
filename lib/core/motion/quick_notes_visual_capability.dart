import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'quick_notes_visual_frame.dart';
import 'quick_notes_visual_preset.dart';

/// Forward declaration for controller interface exposed to capabilities.
abstract class QuickNotesVisualTransitionControllerInterface {
  /// Current target visual state.
  Object? get currentState;

  /// Current visual frame.
  QuickNotesVisualFrame get currentFrame;

  /// Current active preset.
  QuickNotesVisualPreset get preset;

  /// Current spatial anchor.
  Alignment get anchor;

  /// Retargets the transition to [targetState].
  void transitionTo(Object? targetState);

  /// Requests a frame refresh or state update.
  void markNeedsUpdate();
}

/// Base contract for pluggable visual capabilities in the Quick Notes motion system.
///
/// Follows the compositional capability architecture:
/// - New visual capabilities can be added as modular plug-ins.
/// - Capabilities receive authoritative frame updates and can decorate the frame.
/// - Capabilities can optionally wrap or transform visual content.
/// - Capabilities do NOT own application business logic.
abstract class QuickNotesVisualCapability {
  const QuickNotesVisualCapability();

  /// Invoked when the capability is attached to a visual transition controller.
  void onAttach(QuickNotesVisualTransitionControllerInterface controller) {}

  /// Invoked when the capability is detached.
  void onDetach() {}

  /// Invoked when the semantic visual state changes (e.g. collapsed <-> expanded).
  void onStateChange(Object? oldState, Object? newState) {}

  /// Processes and optionally decorates the live [frame] during an animation frame tick.
  QuickNotesVisualFrame processFrame(QuickNotesVisualFrame frame, double dt) =>
      frame;

  /// Wraps or decorates the rendered content widget tree.
  Widget wrapContent(
    BuildContext context,
    QuickNotesVisualFrame frame,
    Widget child,
  ) =>
      child;
}

// =============================================================================
// 1. GEOMETRY CAPABILITY
// =============================================================================

/// Geometry capability managing surface dimensions, bounds, and layout placement.
class GeometryCapability extends QuickNotesVisualCapability {
  const GeometryCapability({
    this.collapsedSize = const Size(44.0, 44.0),
    this.expandedSize = const Size(192.0, 100.0),
    this.anchor = Alignment.topRight,
    this.occupyBounds = false,
  });

  /// Size of the collapsed state.
  final Size collapsedSize;

  /// Size of the expanded state.
  final Size expandedSize;

  /// Reference spatial anchor.
  final Alignment anchor;

  /// Whether the parent container occupies the total bounding box.
  final bool occupyBounds;

  /// Resolves the bounding box containing both collapsed and expanded geometries.
  Size get boundsSize => Size(
        math.max(collapsedSize.width, expandedSize.width),
        math.max(collapsedSize.height, expandedSize.height),
      );

  /// Inscribes a state size into the bounding box according to [anchor].
  Rect rectForSize(Size size) {
    final Rect bounds = Offset.zero & boundsSize;
    return anchor.inscribe(size, bounds);
  }

  @override
  QuickNotesVisualFrame processFrame(QuickNotesVisualFrame frame, double dt) {
    // Stores geometry bounds metadata in frame.extra for consumers
    final Map<String, Object?> extra = Map<String, Object?>.from(frame.extra);
    extra['geometry.boundsSize'] = boundsSize;
    extra['geometry.occupyBounds'] = occupyBounds;
    return frame.copyWith(anchor: anchor, extra: extra);
  }
}

// =============================================================================
// 2. MOTION CAPABILITY
// =============================================================================

/// Motion capability managing harmonic spring physics and velocity continuity.
class MotionCapability extends QuickNotesVisualCapability {
  const MotionCapability({
    this.stiffness,
    this.damping,
  });

  /// Optional override for baseline spring stiffness $k$.
  final double? stiffness;

  /// Optional override for baseline viscous damping $c$.
  final double? damping;

  @override
  QuickNotesVisualFrame processFrame(QuickNotesVisualFrame frame, double dt) {
    final Map<String, Object?> extra = Map<String, Object?>.from(frame.extra);
    if (stiffness != null) extra['motion.stiffness'] = stiffness;
    if (damping != null) extra['motion.damping'] = damping;
    return frame.copyWith(extra: extra);
  }
}

// =============================================================================
// 3. MORPH CAPABILITY
// =============================================================================

/// Morph capability managing state-to-state transformation, live retargeting, and interruption.
class MorphCapability extends QuickNotesVisualCapability {
  const MorphCapability({
    this.enableInterruption = true,
    this.enableRetargeting = true,
  });

  /// Whether mid-flight user taps/actions preserve instantaneous velocity and position.
  final bool enableInterruption;

  /// Whether mid-flight redirection to a 3rd target transitions smoothly.
  final bool enableRetargeting;

  @override
  QuickNotesVisualFrame processFrame(QuickNotesVisualFrame frame, double dt) {
    final Map<String, Object?> extra = Map<String, Object?>.from(frame.extra);
    extra['morph.interruption'] = enableInterruption;
    extra['morph.retargeting'] = enableRetargeting;
    return frame.copyWith(extra: extra);
  }
}

// =============================================================================
// 4. STRETCH CAPABILITY
// =============================================================================

/// Stretch capability governing asymmetric lead-follow deformation and stretch factor.
class StretchCapability extends QuickNotesVisualCapability {
  const StretchCapability({
    this.stretch = 0.75,
    this.leadBounce = 0.10,
    this.followDelaySeconds = 0.04,
  });

  /// Asymmetric stretch intensity factor `[0.0 .. 1.0]`.
  final double stretch;

  /// Lead damping ratio reduction factor.
  final double leadBounce;

  /// Following dimension hold delay in seconds.
  final double followDelaySeconds;

  @override
  QuickNotesVisualFrame processFrame(QuickNotesVisualFrame frame, double dt) {
    final Map<String, Object?> extra = Map<String, Object?>.from(frame.extra);
    extra['stretch.factor'] = stretch;
    extra['stretch.leadBounce'] = leadBounce;
    extra['stretch.followDelaySeconds'] = followDelaySeconds;
    return frame.copyWith(extra: extra);
  }
}

// =============================================================================
// 5. SHAPE CAPABILITY
// =============================================================================

/// Shape capability computing live continuous corner radius interpolation across states.
class ShapeCapability extends QuickNotesVisualCapability {
  const ShapeCapability({
    this.collapsedBorderRadius = const BorderRadius.all(Radius.circular(22.0)),
    this.expandedBorderRadius = const BorderRadius.all(Radius.circular(20.0)),
  });

  /// Corner radius in collapsed state (e.g. circular button).
  final BorderRadius collapsedBorderRadius;

  /// Corner radius in expanded state (e.g. rounded card).
  final BorderRadius expandedBorderRadius;

  /// Computes continuous border radius lerped according to [progress].
  BorderRadius computeRadius(double progress) {
    return BorderRadius.lerp(
      collapsedBorderRadius,
      expandedBorderRadius,
      progress.clamp(0.0, 1.0),
    )!;
  }

  @override
  QuickNotesVisualFrame processFrame(QuickNotesVisualFrame frame, double dt) {
    final BorderRadius liveRadius = computeRadius(frame.progress);
    return frame.copyWith(borderRadius: liveRadius);
  }
}

// =============================================================================
// 6. CONTENT CAPABILITY
// =============================================================================

/// Content capability managing crossfade opacity, Gaussian blur, scale, and spatial follow.
class ContentCapability extends QuickNotesVisualCapability {
  const ContentCapability({
    this.contentBlur = 8.0,
    this.contentFollow = 1.0,
    this.contentSlide = 0.0,
    this.contentOutEnd = 0.40,
    this.contentInStart = 0.30,
    this.contentInEnd = 0.80,
    this.oldScaleTo = 0.92,
    this.newScaleFrom = 0.90,
  });

  /// Maximum Gaussian blur sigma during mid-flight crossfade.
  final double contentBlur;

  /// Spatial follow ratio `[0..1]`.
  final double contentFollow;

  /// Directional slide offset.
  final double contentSlide;

  /// Normalized progress `[0..1]` at which outgoing content reaches `0` opacity.
  final double contentOutEnd;

  /// Normalized progress `[0..1]` at which incoming content begins fading in.
  final double contentInStart;

  /// Normalized progress `[0..1]` at which incoming content reaches `1` opacity.
  final double contentInEnd;

  /// Target scale for outgoing content.
  final double oldScaleTo;

  /// Starting scale for incoming content.
  final double newScaleFrom;

  @override
  QuickNotesVisualFrame processFrame(QuickNotesVisualFrame frame, double dt) {
    final Map<String, Object?> extra = Map<String, Object?>.from(frame.extra);
    extra['content.blur'] = contentBlur;
    extra['content.follow'] = contentFollow;
    extra['content.slide'] = contentSlide;
    return frame.copyWith(extra: extra);
  }

  @override
  Widget wrapContent(
    BuildContext context,
    QuickNotesVisualFrame frame,
    Widget child,
  ) {
    final snapshot = frame.contentSnapshot;
    if (snapshot == null || !frame.isMoving) {
      return child;
    }

    Widget result = child;
    final activeBlur = snapshot.incoming.blurSigma;
    if (activeBlur > 0.01) {
      result = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: activeBlur, sigmaY: activeBlur),
        child: result,
      );
    }
    return result;
  }
}

// =============================================================================
// 7. ADAPTIVITY CAPABILITY (Future-Ready Extension Point)
// =============================================================================

/// Adaptivity capability interface enabling future responsive, device-adaptive,
/// and orientation-aware transitions without redesigning the core engine or consuming screens.
class AdaptivityCapability extends QuickNotesVisualCapability {
  const AdaptivityCapability({
    this.enableResponsiveAnchor = false,
    this.enableDynamicConstraints = false,
  });

  /// Whether anchor placement adapts to available screen boundaries.
  final bool enableResponsiveAnchor;

  /// Whether target dimensions adapt to screen size or density constraints.
  final bool enableDynamicConstraints;

  @override
  QuickNotesVisualFrame processFrame(QuickNotesVisualFrame frame, double dt) {
    final Map<String, Object?> extra = Map<String, Object?>.from(frame.extra);
    extra['adaptivity.responsiveAnchor'] = enableResponsiveAnchor;
    extra['adaptivity.dynamicConstraints'] = enableDynamicConstraints;
    return frame.copyWith(extra: extra);
  }
}
