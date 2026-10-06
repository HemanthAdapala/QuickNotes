import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Configuration for Quick Notes content handoff timing, scale, blur, and spatial follow.
///
/// Contains the physically validated parameters frozen in Phase 8D-R2:
/// - `contentOutEnd = 0.40`: Outgoing content reaches 0 opacity by 40% progress.
/// - `contentInStart = 0.30`: Incoming content begins fading in at 30% progress.
/// - `contentInEnd = 0.80`: Incoming content reaches full opacity by 80% progress.
/// - `oldScaleTo = 0.92`: Target scale for outgoing content as it fades out.
/// - `newScaleFrom = 0.90`: Initial scale for incoming content as it enters.
/// - `contentBlur = 8.0`: Peak Gaussian blur sigma during the transition.
/// - `contentFollow = 1.0`: Content rides centered inside the moving glass surface.
/// - `contentSlide = 0.0`: No directional slide displacement.
/// - `anchor = Alignment.center`: Transform alignment for content scaling.
@immutable
class QuickNotesMorphContentConfig {
  const QuickNotesMorphContentConfig({
    this.contentOutEnd = 0.40,
    this.contentInStart = 0.30,
    this.contentInEnd = 0.80,
    this.oldScaleTo = 0.92,
    this.newScaleFrom = 0.90,
    this.contentBlur = 8.0,
    this.contentFollow = 1.0,
    this.contentSlide = 0.0,
    this.anchor = Alignment.center,
  })  : assert(contentOutEnd > 0.0 && contentOutEnd <= 1.0,
            'contentOutEnd must be within (0, 1]'),
        assert(contentInStart >= 0.0 && contentInStart < 1.0,
            'contentInStart must be within [0, 1)'),
        assert(contentInEnd > 0.0 && contentInEnd <= 1.0,
            'contentInEnd must be within (0, 1]'),
        assert(contentInStart < contentInEnd,
            'contentInStart must be strictly less than contentInEnd');

  /// Normalized progress `[0..1]` at which outgoing content reaches `0` opacity.
  final double contentOutEnd;

  /// Normalized progress `[0..1]` at which incoming content begins fading in.
  final double contentInStart;

  /// Normalized progress `[0..1]` at which incoming content reaches `1` opacity.
  final double contentInEnd;

  /// Target scale for outgoing content as its visibility drops from `1 -> 0`.
  final double oldScaleTo;

  /// Initial scale for incoming content before it scales toward `1.0`.
  final double newScaleFrom;

  /// Peak Gaussian blur sigma applied to content at lowest visibility.
  /// Settles to `0.0` when transition is complete.
  final double contentBlur;

  /// Spatial binding of content during morph:
  /// - `0.0`: pinned to fixed world/stage layout rect.
  /// - `1.0`: centered inside and riding with the moving glass surface.
  final double contentFollow;

  /// Directional slide distance along the travel vector.
  final double contentSlide;

  /// Transform alignment for content scale (`Alignment.center`, etc.).
  final Alignment anchor;

  QuickNotesMorphContentConfig copyWith({
    double? contentOutEnd,
    double? contentInStart,
    double? contentInEnd,
    double? oldScaleTo,
    double? newScaleFrom,
    double? contentBlur,
    double? contentFollow,
    double? contentSlide,
    Alignment? anchor,
  }) {
    return QuickNotesMorphContentConfig(
      contentOutEnd: contentOutEnd ?? this.contentOutEnd,
      contentInStart: contentInStart ?? this.contentInStart,
      contentInEnd: contentInEnd ?? this.contentInEnd,
      oldScaleTo: oldScaleTo ?? this.oldScaleTo,
      newScaleFrom: newScaleFrom ?? this.newScaleFrom,
      contentBlur: contentBlur ?? this.contentBlur,
      contentFollow: contentFollow ?? this.contentFollow,
      contentSlide: contentSlide ?? this.contentSlide,
      anchor: anchor ?? this.anchor,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QuickNotesMorphContentConfig &&
        other.contentOutEnd == contentOutEnd &&
        other.contentInStart == contentInStart &&
        other.contentInEnd == contentInEnd &&
        other.oldScaleTo == oldScaleTo &&
        other.newScaleFrom == newScaleFrom &&
        other.contentBlur == contentBlur &&
        other.contentFollow == contentFollow &&
        other.contentSlide == contentSlide &&
        other.anchor == anchor;
  }

  @override
  int get hashCode => Object.hash(
        contentOutEnd,
        contentInStart,
        contentInEnd,
        oldScaleTo,
        newScaleFrom,
        contentBlur,
        contentFollow,
        contentSlide,
        anchor,
      );
}

/// Snapshot of evaluated visual properties for a single content layer (outgoing or incoming).
@immutable
class QuickNotesEvaluatedContentLayer<T extends Object> {
  const QuickNotesEvaluatedContentLayer({
    required this.stateId,
    required this.isIncoming,
    required this.visibilityLevel,
    required this.opacity,
    required this.scale,
    required this.blurSigma,
    required this.localOffset,
    required this.pinnedRect,
    required this.alignment,
  });

  /// Identifier representing the content state.
  final T stateId;

  /// Whether this layer represents incoming destination content (`true`) or outgoing (`false`).
  final bool isIncoming;

  /// Normalized visibility level `[0..1]`.
  final double visibilityLevel;

  /// Effective opacity `[0..1]`.
  final double opacity;

  /// Effective scale factor around [alignment].
  final double scale;

  /// Effective Gaussian blur sigma (`0.0` when settled or disabled).
  final double blurSigma;

  /// Top-left offset inside the moving glass surface's coordinate space.
  final Offset localOffset;

  /// Stable layout rect defining this content's natural size and world position.
  final Rect pinnedRect;

  /// Scale transform alignment.
  final Alignment alignment;

  /// True if Gaussian blur should be active this frame.
  bool get isBlurActive => blurSigma > 0.05;
}

/// Snapshot of the complete content transition state at normalized progress `t`.
@immutable
class QuickNotesMorphContentSnapshot<T extends Object> {
  const QuickNotesMorphContentSnapshot({
    required this.progress,
    required this.elapsedSeconds,
    required this.durationSeconds,
    required this.travelUnitVector,
    required this.incoming,
    required this.outgoing,
    this.secondaryOutgoing,
  });

  /// Normalized content progress in `[0..1]`.
  final double progress;

  /// Elapsed seconds since the transition began.
  final double elapsedSeconds;

  /// Nominal duration in seconds derived from spring stiffness ($2\pi / \sqrt{k}$).
  final double durationSeconds;

  /// Unit travel vector from source center to destination center.
  final Offset travelUnitVector;

  /// Active incoming layer.
  final QuickNotesEvaluatedContentLayer<T> incoming;

  /// Active primary outgoing layer, if still fading out.
  final QuickNotesEvaluatedContentLayer<T>? outgoing;

  /// Active secondary outgoing layer during rapid mid-flight multi-step interruptions.
  final QuickNotesEvaluatedContentLayer<T>? secondaryOutgoing;

  /// Whether both incoming and outgoing layers are concurrently visible.
  bool get isInOverlapWindow =>
      outgoing != null && outgoing!.opacity > 0.001 && incoming.opacity > 0.001;
}

/// Production content transition controller for Quick Notes Liquid Glass Morph.
///
/// Coordinates cross-fading, scaling, Gaussian blur, and spatial follow between
/// source and destination content layers independently from glass rendering.
///
/// Features:
/// - Asymmetric overlap window: Outgoing fades $0.0 \to 0.40$, incoming enters $0.30 \to 0.80$.
/// - Live interruption handoff: $A \to B \to A$ reverses smoothly from current live opacity
///   without snapping or flash.
/// - Rapid retargeting: $A \to B \to C$ maintains secondary outgoing fade if interrupted during overlap.
class QuickNotesMorphContentController<T extends Object> {
  QuickNotesMorphContentController({
    T? initialState,
    Rect initialRect = Rect.zero,
    double stiffness = 195.0,
  }) {
    if (initialState != null) {
      seedInitialState(
        stateId: initialState,
        stateRect: initialRect,
        stiffness: stiffness,
      );
    }
  }

  late T _incomingState;
  T? _outgoingState;
  T? _secondaryOutgoingState;

  Rect _incomingPinRect = Rect.zero;
  Rect _outgoingPinRect = Rect.zero;
  Rect _secondaryOutgoingPinRect = Rect.zero;
  Rect _originRect = Rect.zero;

  double _srcFrom = 0.0;
  double _secondarySrcFrom = 0.0;
  double _dstFrom = 1.0;

  double _elapsedSeconds = 1e9;
  double _durationSeconds = 2.0 * math.pi / math.sqrt(195.0);
  bool _seeded = false;

  /// Active incoming content state ID.
  T get incomingState => _incomingState;

  /// Active outgoing content state ID, if any.
  T? get outgoingState => _outgoingState;

  /// Active secondary outgoing content state ID, if any.
  T? get secondaryOutgoingState => _secondaryOutgoingState;

  /// Layout rectangle for incoming content.
  Rect get incomingPinRect => _incomingPinRect;

  /// Layout rectangle for primary outgoing content.
  Rect get outgoingPinRect => _outgoingPinRect;

  /// Glass origin rectangle at transition start.
  Rect get originRect => _originRect;

  /// Elapsed time in seconds for the current content transition.
  double get elapsedSeconds => _elapsedSeconds;

  /// Total duration in seconds derived from stiffness.
  double get durationSeconds => _durationSeconds;

  /// Starting visibility for primary outgoing content at transition start.
  double get srcFrom => _srcFrom;

  /// Starting visibility for incoming content at transition start.
  double get dstFrom => _dstFrom;

  /// Whether the controller has been initialized with a state.
  bool get isSeeded => _seeded;

  /// Normalized content progress in `[0..1]`.
  double get progress =>
      (_elapsedSeconds / math.max(_durationSeconds, 0.001)).clamp(0.0, 1.0);

  /// True while the content transition has not yet finished (`progress < 1.0`).
  bool get isAnimating => _seeded && _elapsedSeconds < _durationSeconds;

  /// Nominal morph duration derived from spring stiffness ($2\pi / \sqrt{k}$).
  static double durationForStiffness(double stiffness) {
    return 2.0 * math.pi / math.sqrt(math.max(stiffness, 1.0));
  }

  /// Unit direction vector from origin center to incoming destination center.
  Offset get travelUnitVector {
    final Offset delta = _incomingPinRect.center - _originRect.center;
    final double dist = delta.distance;
    if (dist < 1.0) return Offset.zero;
    return delta / dist;
  }

  /// Seeds initial resting state without triggering a transition.
  void seedInitialState({
    required T stateId,
    required Rect stateRect,
    double stiffness = 195.0,
  }) {
    _seeded = true;
    _incomingState = stateId;
    _outgoingState = null;
    _secondaryOutgoingState = null;
    _incomingPinRect = stateRect;
    _outgoingPinRect = stateRect;
    _secondaryOutgoingPinRect = stateRect;
    _originRect = stateRect;
    _srcFrom = 0.0;
    _secondarySrcFrom = 0.0;
    _dstFrom = 1.0;
    _durationSeconds = durationForStiffness(stiffness);
    _elapsedSeconds = 1e9;
  }

  /// Evaluates outgoing visibility level at normalized progress [t] in `[0..1]`.
  double evaluateOutgoingLevel(
    double t,
    QuickNotesMorphContentConfig config, {
    double? fromOverride,
  }) {
    final double startLevel = fromOverride ?? _srcFrom;
    if (startLevel <= 0.0001) return 0.0;
    final double u =
        (t / math.max(config.contentOutEnd, 0.01)).clamp(0.0, 1.0);
    return (startLevel * (1.0 - Curves.easeIn.transform(u))).clamp(0.0, 1.0);
  }

  /// Evaluates incoming visibility level at normalized progress [t] in `[0..1]`.
  double evaluateIncomingLevel(
    double t,
    QuickNotesMorphContentConfig config,
  ) {
    final double span =
        math.max(config.contentInEnd - config.contentInStart, 0.01);
    final double u = ((t - config.contentInStart) / span).clamp(0.0, 1.0);
    return (_dstFrom + (1.0 - _dstFrom) * Curves.easeOut.transform(u))
        .clamp(0.0, 1.0);
  }

  /// Initiates or retargets a content transition to [targetState] at [targetRect].
  ///
  /// Seamlessly preserves live opacity during interruptions ($A \to B \to A$)
  /// and rapid multi-step retargeting ($A \to B \to C$).
  void transitionToState({
    required T targetState,
    required Rect targetRect,
    required Rect liveGlassRect,
    required QuickNotesMorphContentConfig config,
    required double stiffness,
  }) {
    if (!_seeded) {
      seedInitialState(
        stateId: targetState,
        stateRect: targetRect,
        stiffness: stiffness,
      );
      return;
    }

    _durationSeconds = durationForStiffness(stiffness);

    // If identical state is retargeted (e.g. geometry resize), update pinned rect.
    if (targetState == _incomingState) {
      _originRect = liveGlassRect;
      _incomingPinRect = targetRect;
      return;
    }

    final double t = progress;
    final double currentIncomingLevel = evaluateIncomingLevel(t, config);
    final double currentOutgoingLevel = _outgoingState != null
        ? evaluateOutgoingLevel(t, config)
        : 0.0;

    final bool returningToOutgoing =
        _outgoingState != null && targetState == _outgoingState;

    if (returningToOutgoing) {
      // Reversal: the arriving layer becomes outgoing from its current level,
      // and the departing layer returns from its live level without snapping.
      final T previousIncoming = _incomingState;
      final Rect previousIncomingPin = _incomingPinRect;

      _incomingState = targetState;
      _incomingPinRect = targetRect;
      _dstFrom = currentOutgoingLevel;

      if (currentIncomingLevel > 0.001) {
        _outgoingState = previousIncoming;
        _outgoingPinRect = previousIncomingPin;
        _srcFrom = currentIncomingLevel;
      } else {
        _outgoingState = null;
        _srcFrom = 0.0;
      }
      _secondaryOutgoingState = null;
      _secondarySrcFrom = 0.0;
    } else {
      final T previousIncoming = _incomingState;
      final Rect previousIncomingPin = _incomingPinRect;
      final T? previousOutgoing = _outgoingState;
      final Rect previousOutgoingPin = _outgoingPinRect;

      if (currentIncomingLevel > 0.001) {
        _outgoingState = previousIncoming;
        _outgoingPinRect = previousIncomingPin;
        _srcFrom = currentIncomingLevel;

        if (previousOutgoing != null &&
            previousOutgoing != targetState &&
            currentOutgoingLevel > 0.001) {
          _secondaryOutgoingState = previousOutgoing;
          _secondaryOutgoingPinRect = previousOutgoingPin;
          _secondarySrcFrom = currentOutgoingLevel;
        } else {
          _secondaryOutgoingState = null;
          _secondarySrcFrom = 0.0;
        }
      } else if (previousOutgoing != null && currentOutgoingLevel > 0.001) {
        _outgoingState = previousOutgoing;
        _outgoingPinRect = previousOutgoingPin;
        _srcFrom = currentOutgoingLevel;
        _secondaryOutgoingState = null;
        _secondarySrcFrom = 0.0;
      } else {
        _outgoingState = previousIncoming;
        _outgoingPinRect = previousIncomingPin;
        _srcFrom = currentIncomingLevel;
        _secondaryOutgoingState = null;
        _secondarySrcFrom = 0.0;
      }

      _incomingState = targetState;
      _incomingPinRect = targetRect;
      _dstFrom = 0.0;
    }

    _originRect = liveGlassRect;
    _elapsedSeconds = 0.0;
  }

  /// Advances the content transition clock by [dt] seconds (clamped to max `1/30 s`).
  ///
  /// Returns `true` if the content transition is still animating.
  bool step(double dt, QuickNotesMorphContentConfig config) {
    if (!_seeded) return false;
    final double clampedDt = dt.clamp(0.0, 1.0 / 30.0);
    _elapsedSeconds += clampedDt;

    final double t = progress;
    if (_outgoingState != null && evaluateOutgoingLevel(t, config) <= 0.001) {
      _outgoingState = null;
      _srcFrom = 0.0;
    }
    if (_secondaryOutgoingState != null &&
        evaluateOutgoingLevel(t, config, fromOverride: _secondarySrcFrom) <=
            0.001) {
      _secondaryOutgoingState = null;
      _secondarySrcFrom = 0.0;
    }

    if (_elapsedSeconds >= _durationSeconds) {
      _outgoingState = null;
      _secondaryOutgoingState = null;
      _srcFrom = 0.0;
      _secondarySrcFrom = 0.0;
      _dstFrom = 1.0;
      return false;
    }
    return true;
  }

  /// Evaluates full content snapshot for normalized progress [t] and glass bounds [currentGlassRect].
  QuickNotesMorphContentSnapshot<T> evaluateAt({
    required double t,
    required Rect currentGlassRect,
    required QuickNotesMorphContentConfig config,
  }) {
    final double clampedT = t.clamp(0.0, 1.0);
    final Offset travel = travelUnitVector;

    // 1. Incoming layer
    final double kIn = evaluateIncomingLevel(clampedT, config);
    final double inOpacity = kIn.clamp(0.0, 1.0);
    final double inScale = ui.lerpDouble(config.newScaleFrom, 1.0, kIn)!;
    final double inBlur =
        clampedT >= 1.0 ? 0.0 : (config.contentBlur * (1.0 - kIn));

    final Offset inPinned = _incomingPinRect.topLeft - currentGlassRect.topLeft;
    final Offset inRiding = Offset(
      (currentGlassRect.width - _incomingPinRect.width) * 0.5,
      (currentGlassRect.height - _incomingPinRect.height) * 0.5,
    );
    final Offset inSlide = travel * (-config.contentSlide * (1.0 - kIn));
    final Offset inOffset =
        Offset.lerp(inPinned, inRiding, config.contentFollow)! + inSlide;

    final QuickNotesEvaluatedContentLayer<T> incomingLayer =
        QuickNotesEvaluatedContentLayer<T>(
      stateId: _incomingState,
      isIncoming: true,
      visibilityLevel: kIn,
      opacity: inOpacity,
      scale: inScale,
      blurSigma: inBlur,
      localOffset: inOffset,
      pinnedRect: _incomingPinRect,
      alignment: config.anchor,
    );

    // 2. Primary outgoing layer
    QuickNotesEvaluatedContentLayer<T>? outgoingLayer;
    if (_outgoingState != null) {
      final double outLevel = evaluateOutgoingLevel(clampedT, config);
      if (outLevel > 0.001) {
        final double kOut = 1.0 - outLevel;
        final double outOpacity = (1.0 - kOut).clamp(0.0, 1.0);
        final double outScale = ui.lerpDouble(1.0, config.oldScaleTo, kOut)!;
        final double outBlur = config.contentBlur * kOut;

        final Offset outPinned =
            _outgoingPinRect.topLeft - currentGlassRect.topLeft;
        final Offset outRiding = Offset(
          (currentGlassRect.width - _outgoingPinRect.width) * 0.5,
          (currentGlassRect.height - _outgoingPinRect.height) * 0.5,
        );
        final Offset outOffset =
            Offset.lerp(outPinned, outRiding, config.contentFollow)!;

        outgoingLayer = QuickNotesEvaluatedContentLayer<T>(
          stateId: _outgoingState!,
          isIncoming: false,
          visibilityLevel: outLevel,
          opacity: outOpacity,
          scale: outScale,
          blurSigma: outBlur,
          localOffset: outOffset,
          pinnedRect: _outgoingPinRect,
          alignment: config.anchor,
        );
      }
    }

    // 3. Secondary outgoing layer
    QuickNotesEvaluatedContentLayer<T>? secondaryLayer;
    if (_secondaryOutgoingState != null) {
      final double secLevel = evaluateOutgoingLevel(
        clampedT,
        config,
        fromOverride: _secondarySrcFrom,
      );
      if (secLevel > 0.001) {
        final double kSec = 1.0 - secLevel;
        final double secOpacity = (1.0 - kSec).clamp(0.0, 1.0);
        final double secScale = ui.lerpDouble(1.0, config.oldScaleTo, kSec)!;
        final double secBlur = config.contentBlur * kSec;

        final Offset secPinned =
            _secondaryOutgoingPinRect.topLeft - currentGlassRect.topLeft;
        final Offset secRiding = Offset(
          (currentGlassRect.width - _secondaryOutgoingPinRect.width) * 0.5,
          (currentGlassRect.height - _secondaryOutgoingPinRect.height) * 0.5,
        );
        final Offset secOffset =
            Offset.lerp(secPinned, secRiding, config.contentFollow)!;

        secondaryLayer = QuickNotesEvaluatedContentLayer<T>(
          stateId: _secondaryOutgoingState!,
          isIncoming: false,
          visibilityLevel: secLevel,
          opacity: secOpacity,
          scale: secScale,
          blurSigma: secBlur,
          localOffset: secOffset,
          pinnedRect: _secondaryOutgoingPinRect,
          alignment: config.anchor,
        );
      }
    }

    return QuickNotesMorphContentSnapshot<T>(
      progress: clampedT,
      elapsedSeconds: _elapsedSeconds,
      durationSeconds: _durationSeconds,
      travelUnitVector: travel,
      incoming: incomingLayer,
      outgoing: outgoingLayer,
      secondaryOutgoing: secondaryLayer,
    );
  }
}
