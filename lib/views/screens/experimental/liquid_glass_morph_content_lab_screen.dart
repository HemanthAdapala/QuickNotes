import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:quick_notes/views/screens/experimental/liquid_glass_morph_mechanics_lab_screen.dart';
import 'package:quick_notes/views/widgets/app_bottom_navigation_bar.dart';

/// Configuration for Phase 8C-B native-inspired content handoff timing, scale,
/// blur, spatial follow, and directional slide.
///
/// Behavioral reference: `LiquidGlassMorphAdvanced` in `liquid_glass_easy 4.3.1`.
/// Classification: `OUR DESIGN` reproducing `SOURCE-CONFIRMED` parameters.
@immutable
class QuickNotesMorphContentConfig {
  const QuickNotesMorphContentConfig({
    this.contentOutEnd = 0.40,
    this.contentInStart = 0.30,
    this.contentInEnd = 0.80,
    this.oldScaleTo = 0.92,
    this.newScaleFrom = 0.90,
    this.contentBlur = 8.0,
    this.contentFollow = 0.0,
    this.contentSlide = 12.0,
    this.anchor = Alignment.center,
  })  : assert(contentOutEnd > 0.0 && contentOutEnd <= 1.0),
        assert(contentInStart >= 0.0 && contentInStart < 1.0),
        assert(contentInEnd > 0.0 && contentInEnd <= 1.0);

  /// Normalized progress `[0..1]` at which outgoing content reaches `0` opacity.
  final double contentOutEnd;

  /// Normalized progress `[0..1]` at which incoming content begins fading in.
  final double contentInStart;

  /// Normalized progress `[0..1]` at which incoming content reaches `1` opacity.
  final double contentInEnd;

  /// Target scale for outgoing content as its visibility drops from `1 → 0`.
  final double oldScaleTo;

  /// Initial scale for incoming content before it scales toward `1.0`.
  final double newScaleFrom;

  /// Peak Gaussian blur sigma applied to content at `0` visibility.
  /// Removed completely (`0.0`) when settled.
  final double contentBlur;

  /// Spatial binding of content during morph:
  /// - `0.0`: pinned to world/stage target or origin rect
  /// - `1.0`: centered inside and riding with the moving glass surface
  final double contentFollow;

  /// Directional slide distance (in logical pixels) along the travel vector:
  /// - Positive (`+12`, `+24`): incoming content starts displaced opposite the
  ///   travel direction and slides forward into place.
  /// - Negative (`-12`, `-24`): incoming content starts ahead of destination
  ///   and slides backward into place.
  /// - Zero (`0`) or zero travel vector: no directional slide.
  final double contentSlide;

  /// Transform alignment for content scale (`center`, `topLeft`, etc.).
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
}

/// Snapshot of evaluated visual properties for a single content layer
/// (outgoing or incoming) at a specific frame.
@immutable
class QuickNotesEvaluatedContentLayer {
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

  final QuickNotesMorphStateId stateId;
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

  /// Stable world/stage rect that defines this content's fixed layout size
  /// (`pinnedRect.size`) and world pin location (`pinnedRect.topLeft`).
  final Rect pinnedRect;

  /// Scale transform alignment.
  final Alignment alignment;

  bool get isBlurActive => blurSigma > 0.05;
}

/// Snapshot of the complete content transition state at normalized progress `t`.
@immutable
class QuickNotesMorphContentSnapshot {
  const QuickNotesMorphContentSnapshot({
    required this.progress,
    required this.elapsedSeconds,
    required this.durationSeconds,
    required this.travelUnitVector,
    required this.incoming,
    required this.outgoing,
    this.secondaryOutgoing,
  });

  final double progress;
  final double elapsedSeconds;
  final double durationSeconds;
  final Offset travelUnitVector;
  final QuickNotesEvaluatedContentLayer incoming;
  final QuickNotesEvaluatedContentLayer? outgoing;
  final QuickNotesEvaluatedContentLayer? secondaryOutgoing;

  bool get isInOverlapWindow =>
      outgoing != null &&
      outgoing!.opacity > 0.001 &&
      incoming.opacity > 0.001;
}

/// Isolated Phase 8C-B content transition controller.
///
/// Tracks incoming and outgoing content states, normalized timeline progress
/// (`t = (elapsed / duration).clamp(0.0, 1.0)` where `duration = 2π / √stiffness`),
/// travel unit vector, and live interruption/retargeting handoff without
/// coupling to or modifying `BottomBarGlassSurface`.
class QuickNotesMorphContentController {
  QuickNotesMorphStateId _incomingState = QuickNotesMorphStateId.stateA;
  QuickNotesMorphStateId? _outgoingState;
  QuickNotesMorphStateId? _secondaryOutgoingState;

  Rect _incomingPinRect = const Rect.fromLTWH(0, 0, 128, 48);
  Rect _outgoingPinRect = const Rect.fromLTWH(0, 0, 128, 48);
  Rect _secondaryOutgoingPinRect = const Rect.fromLTWH(0, 0, 128, 48);
  Rect _originRect = const Rect.fromLTWH(0, 0, 128, 48);

  double _srcFrom = 0.0;
  double _secondarySrcFrom = 0.0;
  double _dstFrom = 1.0;

  double _elapsedSeconds = 1e9;
  double _durationSeconds = 2 * math.pi / math.sqrt(195.0);
  bool _seeded = false;

  QuickNotesMorphStateId get incomingState => _incomingState;
  QuickNotesMorphStateId? get outgoingState => _outgoingState;
  QuickNotesMorphStateId? get secondaryOutgoingState => _secondaryOutgoingState;
  Rect get incomingPinRect => _incomingPinRect;
  Rect get outgoingPinRect => _outgoingPinRect;
  Rect get originRect => _originRect;
  double get elapsedSeconds => _elapsedSeconds;
  double get durationSeconds => _durationSeconds;
  double get srcFrom => _srcFrom;
  double get dstFrom => _dstFrom;

  /// Normalized content swap progress `[0..1]`.
  double get progress =>
      (_elapsedSeconds / math.max(_durationSeconds, 0.001)).clamp(0.0, 1.0);

  /// True while the content timeline has not yet completed (`progress < 1.0`).
  bool get isAnimating => _seeded && _elapsedSeconds < _durationSeconds;

  /// Nominal morph duration derived from spring stiffness (`2π / √stiffness`).
  static double durationForStiffness(double stiffness) {
    return 2.0 * math.pi / math.sqrt(math.max(stiffness, 1.0));
  }

  /// Unit direction vector from `_originRect.center` to `_incomingPinRect.center`.
  /// Returns `Offset.zero` for concentric / size-only morphs (`distance < 1.0`).
  Offset get travelUnitVector {
    final Offset delta = _incomingPinRect.center - _originRect.center;
    final double dist = delta.distance;
    if (dist < 1.0) return Offset.zero;
    return delta / dist;
  }

  /// Seeds the initial resting state without triggering a transition.
  void seedInitialState({
    required QuickNotesMorphStateId stateId,
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

  /// Evaluates outgoing visibility level at normalized progress [t] (`[0..1]`).
  ///
  /// Behavioral reference: `LiquidGlassMorph._srcLevel(t)`:
  /// `u = (t / max(contentOutEnd, 0.01)).clamp(0.0, 1.0)`
  /// `srcFrom * (1 - Curves.easeIn.transform(u))`
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

  /// Evaluates incoming visibility level at normalized progress [t] (`[0..1]`).
  ///
  /// Behavioral reference: `LiquidGlassMorph._dstLevel(t)`:
  /// `span = max(contentInEnd - contentInStart, 0.01)`
  /// `u = ((t - contentInStart) / span).clamp(0.0, 1.0)`
  /// `dstFrom + (1 - dstFrom) * Curves.easeOut.transform(u)`
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

  /// Starts or retargets a content transition to [targetState] at [targetRect],
  /// using [liveGlassRect] as the current moving glass outline.
  ///
  /// Handles:
  /// - Standard `A → B` swap
  /// - Mid-flight `A → B → A` reversal (resumes `A` from `returningAt`, fades
  ///   `B` down from `leavingAt`, and if `B` had `0.0` visibility before
  ///   `contentInStart`, `B` never flashes)
  /// - Mid-flight `A → B → C` retargeting (smoothly fades out whichever state(s)
  ///   were currently visible without snapping through `B`'s final state)
  void transitionToState({
    required QuickNotesMorphStateId targetState,
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

    // If the same state is retargeted (e.g., anchor/topology resize), update
    // its pinned rect without restarting the content cross-fade.
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
      // A -> B -> A reversal:
      // The child that was arriving (B) now leaves from whatever visibility it
      // had reached (`currentIncomingLevel` — 0.0 if before contentInStart).
      // The child that was leaving (A) returns from its current visibility
      // (`currentOutgoingLevel`) instead of restarting from 0.0.
      final QuickNotesMorphStateId previousIncoming = _incomingState;
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
      // A -> B (from rest) or A -> B -> C (mid-flight retarget to third state):
      final QuickNotesMorphStateId previousIncoming = _incomingState;
      final Rect previousIncomingPin = _incomingPinRect;
      final QuickNotesMorphStateId? previousOutgoing = _outgoingState;
      final Rect previousOutgoingPin = _outgoingPinRect;

      if (currentIncomingLevel > 0.001) {
        // B had already started appearing: B becomes primary outgoing.
        // If A was also still partially visible (inside overlap window), retain
        // A as secondary outgoing so neither A nor B snaps in opacity.
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
        // Retargeted to C before B ever became visible (t <= contentInStart):
        // A is still the only visible content, so A stays outgoing from its
        // live level and B is cleanly dropped without flashing.
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

      // If C happened to be the secondary outgoing state, resume from its level.
      _incomingState = targetState;
      _incomingPinRect = targetRect;
      _dstFrom = 0.0;
    }

    _originRect = liveGlassRect;
    _elapsedSeconds = 0.0;
  }

  /// Advances the content clock by [dt] seconds (clamped to `1/30 s` max per step
  /// to match native frame-drop protection).
  ///
  /// Returns `true` if the content transition is still active.
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

  /// Evaluates the complete content snapshot for a given normalized progress [t]
  /// (`[0..1]`) and current glass rectangle [currentGlassRect].
  QuickNotesMorphContentSnapshot evaluateAt({
    required double t,
    required Rect currentGlassRect,
    required QuickNotesMorphContentConfig config,
  }) {
    final double clampedT = t.clamp(0.0, 1.0);
    final Offset travel = travelUnitVector;

    // 1. Incoming layer evaluation
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

    final QuickNotesEvaluatedContentLayer incomingLayer =
        QuickNotesEvaluatedContentLayer(
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

    // 2. Primary outgoing layer evaluation
    QuickNotesEvaluatedContentLayer? outgoingLayer;
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

        outgoingLayer = QuickNotesEvaluatedContentLayer(
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

    // 3. Secondary outgoing layer (only during mid-overlap A->B->C retargets)
    QuickNotesEvaluatedContentLayer? secondaryLayer;
    if (_secondaryOutgoingState != null) {
      final double secLevel = evaluateOutgoingLevel(
        clampedT,
        config,
        fromOverride: _secondarySrcFrom,
      );
      if (secLevel > 0.001) {
        final double kSec = 1.0 - secLevel;
        final Offset secPinned =
            _secondaryOutgoingPinRect.topLeft - currentGlassRect.topLeft;
        final Offset secRiding = Offset(
          (currentGlassRect.width - _secondaryOutgoingPinRect.width) * 0.5,
          (currentGlassRect.height - _secondaryOutgoingPinRect.height) * 0.5,
        );
        secondaryLayer = QuickNotesEvaluatedContentLayer(
          stateId: _secondaryOutgoingState!,
          isIncoming: false,
          visibilityLevel: secLevel,
          opacity: (1.0 - kSec).clamp(0.0, 1.0),
          scale: ui.lerpDouble(1.0, config.oldScaleTo, kSec)!,
          blurSigma: config.contentBlur * kSec,
          localOffset:
              Offset.lerp(secPinned, secRiding, config.contentFollow)!,
          pinnedRect: _secondaryOutgoingPinRect,
          alignment: config.anchor,
        );
      }
    }

    return QuickNotesMorphContentSnapshot(
      progress: clampedT,
      elapsedSeconds: _elapsedSeconds,
      durationSeconds: _durationSeconds,
      travelUnitVector: travel,
      incoming: incomingLayer,
      outgoing: outgoingLayer,
      secondaryOutgoing: secondaryLayer,
    );
  }

  /// Evaluates the current frame snapshot using `this.progress`.
  QuickNotesMorphContentSnapshot currentSnapshot({
    required Rect currentGlassRect,
    required QuickNotesMorphContentConfig config,
  }) {
    return evaluateAt(
      t: progress,
      currentGlassRect: currentGlassRect,
      config: config,
    );
  }
}

/// Render-object probe that counts how many times `performLayout` is executed
/// on its child subtree.
///
/// Used to verify Section 6 & Section 22 ("No Layout Jitter"): because each
/// state's content is placed inside a fixed-dimension box (`Size(w, h)` of its
/// target state) and moved via parent offset/transforms, `performLayout` is
/// executed once on mount and is NOT re-triggered on every animation frame.
class QuickNotesLayoutCountProbe extends SingleChildRenderObjectWidget {
  const QuickNotesLayoutCountProbe({
    super.key,
    required this.onLayoutCounted,
    required Widget super.child,
  });

  final VoidCallback onLayoutCounted;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return QuickNotesRenderLayoutCountProbe(onLayoutCounted: onLayoutCounted);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant QuickNotesRenderLayoutCountProbe renderObject,
  ) {
    renderObject.onLayoutCounted = onLayoutCounted;
  }
}

class QuickNotesRenderLayoutCountProbe extends RenderProxyBox {
  QuickNotesRenderLayoutCountProbe({required this.onLayoutCounted});

  VoidCallback onLayoutCounted;
  int layoutCount = 0;

  @override
  void performLayout() {
    layoutCount++;
    onLayoutCounted();
    super.performLayout();
  }
}

/// Isolated Phase 8C-B Experimental Lab Screen:
/// Layers native-inspired content handoff (`QuickNotesMorphContentController`)
/// inside the Phase 8C-A 4D geometry controller (`QuickNotesMorphGeometryController`)
/// and Quick Notes' unaltered `BottomBarGlassSurface`.
class LiquidGlassMorphContentLabScreen extends StatefulWidget {
  const LiquidGlassMorphContentLabScreen({super.key});

  @override
  State<LiquidGlassMorphContentLabScreen> createState() =>
      _LiquidGlassMorphContentLabScreenState();
}

class _LiquidGlassMorphContentLabScreenState
    extends State<LiquidGlassMorphContentLabScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastTickElapsed = Duration.zero;
  final List<Timer> _sequenceTimers = <Timer>[];

  final QuickNotesMorphGeometryController _geometryController =
      QuickNotesMorphGeometryController();
  final QuickNotesMorphContentController _contentController =
      QuickNotesMorphContentController();

  QuickNotesMorphStateId _currentState = QuickNotesMorphStateId.stateA;
  QuickNotesMorphPreset _selectedPreset = QuickNotesMorphPreset.fluid;
  QuickNotesMorphAnchorOption _selectedAnchor =
      QuickNotesMorphAnchorOption.center;
  QuickNotesMorphTopologyMode _topologyMode =
      QuickNotesMorphTopologyMode.sizeAndPosition;

  // Phase 8C-A Geometry parameters
  double _stiffness = 195.0;
  double _damping = 19.5;
  double _stretch = 0.60;
  double _leadBounce = 0.10;
  double _followDelaySeconds = 0.04;
  double _seedScale = 1.0;

  // Phase 8C-B Content parameters
  double _contentOutEnd = 0.40;
  double _contentInStart = 0.30;
  double _contentInEnd = 0.80;
  double _oldScaleTo = 0.92;
  double _newScaleFrom = 0.90;
  double _contentBlur = 8.0;
  double _contentFollow = 0.0;
  double _contentSlide = 12.0;

  // Optional manual progress scrub for inspecting exact overlap points
  // (e.g. t = 0.25, 0.30, 0.35, 0.40, 0.50)
  double? _manualProgressOverride;

  final Size _stageFieldSize = const Size(520, 320);

  // Per-state layout counters to prove zero per-frame relayout jitter
  final Map<QuickNotesMorphStateId, int> _stateLayoutCounts =
      <QuickNotesMorphStateId, int>{
    QuickNotesMorphStateId.stateA: 0,
    QuickNotesMorphStateId.stateB: 0,
    QuickNotesMorphStateId.stateC: 0,
  };
  final Map<QuickNotesMorphStateId, GlobalKey> _stateProbeKeys =
      <QuickNotesMorphStateId, GlobalKey>{
    QuickNotesMorphStateId.stateA: GlobalKey(debugLabel: 'probe_stateA'),
    QuickNotesMorphStateId.stateB: GlobalKey(debugLabel: 'probe_stateB'),
    QuickNotesMorphStateId.stateC: GlobalKey(debugLabel: 'probe_stateC'),
  };
  final Map<QuickNotesMorphStateId, GlobalKey> _stateBoxKeys =
      <QuickNotesMorphStateId, GlobalKey>{
    QuickNotesMorphStateId.stateA: GlobalKey(debugLabel: 'box_stateA'),
    QuickNotesMorphStateId.stateB: GlobalKey(debugLabel: 'box_stateB'),
    QuickNotesMorphStateId.stateC: GlobalKey(debugLabel: 'box_stateC'),
  };
  int _activeTransitionFrameCount = 0;

  // Cached stable content subtrees keyed by state ID so Flutter reuses the
  // exact Element & RenderObject subtree across all animation frames without
  // re-laying out text or icons.
  late final Map<QuickNotesMorphStateId, Widget> _stableStateChildren =
      <QuickNotesMorphStateId, Widget>{
    QuickNotesMorphStateId.stateA: _buildStableStateChild(
      QuickNotesMorphStateId.stateA,
    ),
    QuickNotesMorphStateId.stateB: _buildStableStateChild(
      QuickNotesMorphStateId.stateB,
    ),
    QuickNotesMorphStateId.stateC: _buildStableStateChild(
      QuickNotesMorphStateId.stateC,
    ),
  };

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    final Rect initialRect = _computeStateRect(
      QuickNotesMorphStateId.stateA,
      _stageFieldSize,
    );
    _geometryController.seedInitialRect(
      initialRect,
      anchor: _selectedAnchor.alignment,
    );
    _contentController.seedInitialState(
      stateId: QuickNotesMorphStateId.stateA,
      stateRect: initialRect,
      stiffness: _stiffness,
    );
  }

  @override
  void dispose() {
    _cancelTimers();
    _ticker.dispose();
    super.dispose();
  }

  void _cancelTimers() {
    for (final Timer timer in _sequenceTimers) {
      timer.cancel();
    }
    _sequenceTimers.clear();
  }

  QuickNotesMorphGeometryConfig _buildGeometryConfig() {
    return QuickNotesMorphGeometryConfig(
      stiffness: _stiffness,
      damping: _damping,
      stretch: _stretch,
      leadBounce: _leadBounce,
      followDelaySeconds: _followDelaySeconds,
      seedScale: _seedScale,
      anchor: _selectedAnchor.alignment,
    );
  }

  QuickNotesMorphContentConfig _buildContentConfig() {
    return QuickNotesMorphContentConfig(
      contentOutEnd: _contentOutEnd,
      contentInStart: _contentInStart,
      contentInEnd: _contentInEnd,
      oldScaleTo: _oldScaleTo,
      newScaleFrom: _newScaleFrom,
      contentBlur: _contentBlur,
      contentFollow: _contentFollow,
      contentSlide: _contentSlide,
      anchor: _selectedAnchor.alignment,
    );
  }

  Alignment _spatialAlignmentForState(QuickNotesMorphStateId state) {
    switch (state) {
      case QuickNotesMorphStateId.stateA:
        return const Alignment(-0.62, -0.52);
      case QuickNotesMorphStateId.stateB:
        return const Alignment(0.38, 0.36);
      case QuickNotesMorphStateId.stateC:
        return const Alignment(-0.38, 0.54);
    }
  }

  Rect _computeStateRect(QuickNotesMorphStateId state, Size field) {
    final Size size = _topologyMode == QuickNotesMorphTopologyMode.positionOnly
        ? const Size(156, 56)
        : state.defaultSize;

    final Alignment placementAlignment;
    switch (_topologyMode) {
      case QuickNotesMorphTopologyMode.sizeOnly:
        placementAlignment = _selectedAnchor.alignment;
      case QuickNotesMorphTopologyMode.positionOnly:
        placementAlignment = _spatialAlignmentForState(state);
      case QuickNotesMorphTopologyMode.sizeAndPosition:
        placementAlignment =
            _selectedAnchor == QuickNotesMorphAnchorOption.center
                ? _spatialAlignmentForState(state)
                : _selectedAnchor.alignment;
    }
    return placementAlignment.inscribe(size, Offset.zero & field);
  }

  void _wakeTicker() {
    if (!_ticker.isActive) {
      _lastTickElapsed = Duration.zero;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    final double dt = (elapsed - _lastTickElapsed).inMicroseconds / 1e6;
    _lastTickElapsed = elapsed;
    if (dt <= 0.0) return;

    final QuickNotesMorphGeometryConfig geoConfig = _buildGeometryConfig();
    final QuickNotesMorphContentConfig contentConfig = _buildContentConfig();

    final bool geoMoving = _geometryController.step(dt, geoConfig);
    final bool contentMoving = _contentController.step(dt, contentConfig);
    _activeTransitionFrameCount++;

    if (!geoMoving && !contentMoving) {
      _ticker.stop();
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _transitionToState(QuickNotesMorphStateId targetState) {
    setState(() {
      _manualProgressOverride = null;
      _activeTransitionFrameCount = 0;
      _currentState = targetState;
      final Rect liveRect = _geometryController.currentRect;
      final Rect targetRect = _computeStateRect(targetState, _stageFieldSize);

      _geometryController.transitionToRect(
        targetRect,
        config: _buildGeometryConfig(),
      );
      _contentController.transitionToState(
        targetState: targetState,
        targetRect: targetRect,
        liveGlassRect: liveRect,
        config: _buildContentConfig(),
        stiffness: _stiffness,
      );
      _wakeTicker();
    });
  }

  void _runAToB() {
    _cancelTimers();
    if (_currentState != QuickNotesMorphStateId.stateA) {
      final Rect rectA = _computeStateRect(
        QuickNotesMorphStateId.stateA,
        _stageFieldSize,
      );
      _geometryController.seedInitialRect(
        rectA,
        anchor: _selectedAnchor.alignment,
      );
      _contentController.seedInitialState(
        stateId: QuickNotesMorphStateId.stateA,
        stateRect: rectA,
        stiffness: _stiffness,
      );
      _currentState = QuickNotesMorphStateId.stateA;
    }
    _transitionToState(QuickNotesMorphStateId.stateB);
  }

  void _runBToA() {
    _cancelTimers();
    if (_currentState != QuickNotesMorphStateId.stateB) {
      final Rect rectB = _computeStateRect(
        QuickNotesMorphStateId.stateB,
        _stageFieldSize,
      );
      _geometryController.seedInitialRect(
        rectB,
        anchor: _selectedAnchor.alignment,
      );
      _contentController.seedInitialState(
        stateId: QuickNotesMorphStateId.stateB,
        stateRect: rectB,
        stiffness: _stiffness,
      );
      _currentState = QuickNotesMorphStateId.stateB;
    }
    _transitionToState(QuickNotesMorphStateId.stateA);
  }

  void _runInterruptABA() {
    _cancelTimers();
    final Rect rectA = _computeStateRect(
      QuickNotesMorphStateId.stateA,
      _stageFieldSize,
    );
    _geometryController.seedInitialRect(
      rectA,
      anchor: _selectedAnchor.alignment,
    );
    _contentController.seedInitialState(
      stateId: QuickNotesMorphStateId.stateA,
      stateRect: rectA,
      stiffness: _stiffness,
    );
    setState(() {
      _currentState = QuickNotesMorphStateId.stateA;
    });
    _transitionToState(QuickNotesMorphStateId.stateB);
    _sequenceTimers.add(
      Timer(const Duration(milliseconds: 120), () {
        if (!mounted) return;
        _transitionToState(QuickNotesMorphStateId.stateA);
      }),
    );
  }

  void _runRetargetABC() {
    _cancelTimers();
    final Rect rectA = _computeStateRect(
      QuickNotesMorphStateId.stateA,
      _stageFieldSize,
    );
    _geometryController.seedInitialRect(
      rectA,
      anchor: _selectedAnchor.alignment,
    );
    _contentController.seedInitialState(
      stateId: QuickNotesMorphStateId.stateA,
      stateRect: rectA,
      stiffness: _stiffness,
    );
    setState(() {
      _currentState = QuickNotesMorphStateId.stateA;
    });
    _transitionToState(QuickNotesMorphStateId.stateB);
    _sequenceTimers.add(
      Timer(const Duration(milliseconds: 120), () {
        if (!mounted) return;
        _transitionToState(QuickNotesMorphStateId.stateC);
      }),
    );
  }

  void _runRapidBurst({required int intervalMs}) {
    _cancelTimers();
    final Rect rectA = _computeStateRect(
      QuickNotesMorphStateId.stateA,
      _stageFieldSize,
    );
    _geometryController.seedInitialRect(
      rectA,
      anchor: _selectedAnchor.alignment,
    );
    _contentController.seedInitialState(
      stateId: QuickNotesMorphStateId.stateA,
      stateRect: rectA,
      stiffness: _stiffness,
    );
    setState(() {
      _currentState = QuickNotesMorphStateId.stateA;
    });
    const List<QuickNotesMorphStateId> sequence = <QuickNotesMorphStateId>[
      QuickNotesMorphStateId.stateB,
      QuickNotesMorphStateId.stateA,
      QuickNotesMorphStateId.stateB,
      QuickNotesMorphStateId.stateA,
    ];
    for (int i = 0; i < sequence.length; i++) {
      _sequenceTimers.add(
        Timer(Duration(milliseconds: intervalMs * (i + 1)), () {
          if (!mounted) return;
          _transitionToState(sequence[i]);
        }),
      );
    }
  }

  void _inspectOverlapProgress(double targetT) {
    _cancelTimers();
    _ticker.stop();
    final Rect rectA = _computeStateRect(
      QuickNotesMorphStateId.stateA,
      _stageFieldSize,
    );
    final Rect rectB = _computeStateRect(
      QuickNotesMorphStateId.stateB,
      _stageFieldSize,
    );
    _geometryController.seedInitialRect(
      rectA,
      anchor: _selectedAnchor.alignment,
    );
    _contentController.seedInitialState(
      stateId: QuickNotesMorphStateId.stateA,
      stateRect: rectA,
      stiffness: _stiffness,
    );
    _geometryController.transitionToRect(
      rectB,
      config: _buildGeometryConfig(),
    );
    _contentController.transitionToState(
      targetState: QuickNotesMorphStateId.stateB,
      targetRect: rectB,
      liveGlassRect: rectA,
      config: _buildContentConfig(),
      stiffness: _stiffness,
    );

    final double totalDuration = _contentController.durationSeconds;
    final double targetElapsed = totalDuration * targetT;
    const double stepDt = 0.008;
    double accumulated = 0.0;
    while (accumulated + stepDt <= targetElapsed) {
      _geometryController.step(stepDt, _buildGeometryConfig());
      _contentController.step(stepDt, _buildContentConfig());
      accumulated += stepDt;
    }
    final double remainder = targetElapsed - accumulated;
    if (remainder > 0.0) {
      _geometryController.step(remainder, _buildGeometryConfig());
      _contentController.step(remainder, _buildContentConfig());
    }

    setState(() {
      _currentState = QuickNotesMorphStateId.stateB;
      _manualProgressOverride = targetT;
    });
  }

  void _resetToBaseline() {
    _cancelTimers();
    _ticker.stop();
    setState(() {
      _manualProgressOverride = null;
      _activeTransitionFrameCount = 0;
      _currentState = QuickNotesMorphStateId.stateA;
      _selectedPreset = QuickNotesMorphPreset.fluid;
      _selectedAnchor = QuickNotesMorphAnchorOption.center;
      _topologyMode = QuickNotesMorphTopologyMode.sizeAndPosition;
      _stiffness = 195.0;
      _damping = 19.5;
      _stretch = 0.60;
      _leadBounce = 0.10;
      _followDelaySeconds = 0.04;
      _seedScale = 1.0;
      _contentOutEnd = 0.40;
      _contentInStart = 0.30;
      _contentInEnd = 0.80;
      _oldScaleTo = 0.92;
      _newScaleFrom = 0.90;
      _contentBlur = 8.0;
      _contentFollow = 0.0;
      _contentSlide = 12.0;

      final Rect rectA = _computeStateRect(
        QuickNotesMorphStateId.stateA,
        _stageFieldSize,
      );
      _geometryController.seedInitialRect(
        rectA,
        anchor: Alignment.center,
      );
      _contentController.seedInitialState(
        stateId: QuickNotesMorphStateId.stateA,
        stateRect: rectA,
        stiffness: _stiffness,
      );
    });
  }

  BorderRadius _computeBorderRadius(Rect rect) {
    final double maxPossible = math.min(rect.width, rect.height) * 0.5;
    return BorderRadius.circular(math.min(24.0, maxPossible));
  }

  Widget _buildStableStateChild(QuickNotesMorphStateId state) {
    return QuickNotesLayoutCountProbe(
      key: _stateProbeKeys[state],
      onLayoutCounted: () {
        _stateLayoutCounts[state] = (_stateLayoutCounts[state] ?? 0) + 1;
      },
      child: Builder(
        builder: (BuildContext context) {
          switch (state) {
            case QuickNotesMorphStateId.stateA:
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 16,
                      color: Color(0xFF1E293B),
                    ),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'State A',
                        key: ValueKey<String>('morph_content_text_stateA'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            case QuickNotesMorphStateId.stateB:
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0EA5E9).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.view_agenda_rounded,
                            size: 16,
                            color: Color(0xFF0369A1),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'State B',
                            key: ValueKey<String>('morph_content_text_stateB'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            '268×176',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF047857),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Flexible(
                      child: Text(
                        'Expanded multi-line note card content measured at fixed 268×176 constraints without per-frame text reflow.',
                        key: ValueKey<String>('morph_content_multiline_stateB'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                    const Row(
                      children: <Widget>[
                        Icon(
                          Icons.lock_clock_outlined,
                          size: 13,
                          color: Color(0xFF475569),
                        ),
                        SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Stable Layout • Zero Reflow',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            case QuickNotesMorphStateId.stateC:
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.layers_rounded,
                          size: 16,
                          color: Color(0xFF6D28D9),
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'State C',
                            key: ValueKey<String>('morph_content_text_stateC'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Flexible(
                      child: Text(
                        'Retargeted banner (216×96) verifying mid-flight A→B→C content handoff.',
                        key: ValueKey<String>('morph_content_multiline_stateC'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.2,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
              );
          }
        },
      ),
    );
  }

  /// Builds a single transformed content layer (incoming or outgoing) inside
  /// the glass surface without altering the child's layout constraints.
  Widget _buildEvaluatedContentLayer(
    QuickNotesEvaluatedContentLayer layer, {
    required String roleTag,
  }) {
    final Size stableLayoutSize = layer.stateId.defaultSize;
    Widget content = SizedBox(
      key: _stateBoxKeys[layer.stateId],
      width: stableLayoutSize.width,
      height: stableLayoutSize.height,
      child: _stableStateChildren[layer.stateId]!,
    );

    if (layer.isBlurActive) {
      content = ImageFiltered(
        key: ValueKey<String>('content_blur_${roleTag}_${layer.stateId.name}'),
        imageFilter: ui.ImageFilter.blur(
          sigmaX: layer.blurSigma,
          sigmaY: layer.blurSigma,
        ),
        child: content,
      );
    }

    return Positioned(
      key: ValueKey<String>('content_layer_${layer.stateId.name}'),
      left: layer.localOffset.dx,
      top: layer.localOffset.dy,
      width: stableLayoutSize.width,
      height: stableLayoutSize.height,
      child: IgnorePointer(
        ignoring: !layer.isIncoming,
        child: Opacity(
          key: ValueKey<String>(
            'content_opacity_${roleTag}_${layer.stateId.name}',
          ),
          opacity: layer.opacity,
          child: Transform.scale(
            key: ValueKey<String>(
              'content_scale_${roleTag}_${layer.stateId.name}',
            ),
            scale: layer.scale,
            alignment: layer.alignment,
            child: content,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Rect currentRect = _geometryController.currentRect;
    final QuickNotesMorphContentConfig contentConfig = _buildContentConfig();
    final QuickNotesMorphContentSnapshot snapshot =
        _manualProgressOverride != null
            ? _contentController.evaluateAt(
                t: _manualProgressOverride!,
                currentGlassRect: currentRect,
                config: contentConfig,
              )
            : _contentController.currentSnapshot(
                currentGlassRect: currentRect,
                config: contentConfig,
              );

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Phase 8C-B • Content Transition Lab',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: <Widget>[
          TextButton.icon(
            key: const ValueKey<String>('content_lab_reset_button'),
            onPressed: _resetToBaseline,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Reset'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _buildStageCard(currentRect, snapshot),
            const SizedBox(height: 12),
            _buildTelemetryCard(currentRect, snapshot),
            const SizedBox(height: 12),
            _buildControlsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStageCard(
    Rect currentRect,
    QuickNotesMorphContentSnapshot snapshot,
  ) {
    final BorderRadius borderRadius = _computeBorderRadius(currentRect);

    return Center(
      child: Container(
        key: const ValueKey<String>('content_lab_stage_container'),
        width: _stageFieldSize.width,
        height: _stageFieldSize.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFFE0F2FE),
              Color(0xFFEDE9FE),
              Color(0xFFFEF3C7),
              Color(0xFFD1FAE5),
            ],
          ),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: <Widget>[
              // Background wallpaper pattern for verifying Quick Notes 3.0px frost blur
              Positioned(
                left: 28,
                top: 24,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.28),
                  ),
                ),
              ),
              Positioned(
                right: 42,
                bottom: 28,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFA78BFA).withValues(alpha: 0.26),
                  ),
                ),
              ),
              // Moving Quick Notes Glass Surface + Isolated Content Transition Layer
              Positioned.fromRect(
                key: const ValueKey<String>('content_lab_positioned_glass'),
                rect: currentRect,
                child: BottomBarGlassSurface(
                  key: const ValueKey<String>('content_lab_glass_surface'),
                  width: currentRect.width,
                  height: currentRect.height,
                  borderRadius: borderRadius,
                  useFrost: true,
                  child: Stack(
                    key: const ValueKey<String>('content_lab_transition_stack'),
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      _buildEvaluatedContentLayer(
                        snapshot.incoming,
                        roleTag: 'incoming',
                      ),
                      if (snapshot.secondaryOutgoing != null)
                        _buildEvaluatedContentLayer(
                          snapshot.secondaryOutgoing!,
                          roleTag: 'secondary_outgoing',
                        ),
                      if (snapshot.outgoing != null)
                        _buildEvaluatedContentLayer(
                          snapshot.outgoing!,
                          roleTag: 'outgoing',
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTelemetryCard(
    Rect currentRect,
    QuickNotesMorphContentSnapshot snapshot,
  ) {
    final QuickNotesEvaluatedContentLayer inc = snapshot.incoming;
    final QuickNotesEvaluatedContentLayer? out = snapshot.outgoing;

    return Container(
      key: const ValueKey<String>('content_lab_telemetry_card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text(
                'Live Content & Geometry Telemetry',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _ticker.isActive
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _ticker.isActive ? 'TICKER ACTIVE' : 'IDLE',
                  key: const ValueKey<String>('content_lab_ticker_status'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _ticker.isActive
                        ? const Color(0xFF15803D)
                        : const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: <Widget>[
              Text(
                'Progress t: ${snapshot.progress.toStringAsFixed(2)}',
                key: const ValueKey<String>('telemetry_progress_t'),
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
              Text(
                'Rect: (${currentRect.left.toStringAsFixed(1)}, ${currentRect.top.toStringAsFixed(1)}, ${currentRect.width.toStringAsFixed(1)}×${currentRect.height.toStringAsFixed(1)})',
                key: const ValueKey<String>('telemetry_glass_rect'),
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
              Text(
                'In [${inc.stateId.name}]: op=${inc.opacity.toStringAsFixed(2)} sc=${inc.scale.toStringAsFixed(2)} blur=${inc.blurSigma.toStringAsFixed(1)}',
                key: const ValueKey<String>('telemetry_incoming_metrics'),
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
              Text(
                out != null
                    ? 'Out [${out.stateId.name}]: op=${out.opacity.toStringAsFixed(2)} sc=${out.scale.toStringAsFixed(2)} blur=${out.blurSigma.toStringAsFixed(1)}'
                    : 'Out: none',
                key: const ValueKey<String>('telemetry_outgoing_metrics'),
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
              Text(
                'Overlap: ${snapshot.isInOverlapWindow ? "YES" : "NO"}',
                key: const ValueKey<String>('telemetry_overlap_status'),
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
              Text(
                'Travel: (${snapshot.travelUnitVector.dx.toStringAsFixed(2)}, ${snapshot.travelUnitVector.dy.toStringAsFixed(2)})',
                key: const ValueKey<String>('telemetry_travel_vector'),
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
              Text(
                'Layouts A/B/C: ${_stateLayoutCounts[QuickNotesMorphStateId.stateA]}/${_stateLayoutCounts[QuickNotesMorphStateId.stateB]}/${_stateLayoutCounts[QuickNotesMorphStateId.stateC]} (Frames: $_activeTransitionFrameCount)',
                key: const ValueKey<String>('telemetry_layout_counts'),
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '1. State & Sequence Triggers',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              ElevatedButton(
                key: const ValueKey<String>('content_action_a_to_b'),
                onPressed: _runAToB,
                child: const Text('A → B'),
              ),
              ElevatedButton(
                key: const ValueKey<String>('content_action_b_to_a'),
                onPressed: _runBToA,
                child: const Text('B → A'),
              ),
              ElevatedButton(
                key: const ValueKey<String>('content_action_interrupt_aba'),
                onPressed: _runInterruptABA,
                child: const Text('Interrupt A→B→A'),
              ),
              ElevatedButton(
                key: const ValueKey<String>('content_action_retarget_abc'),
                onPressed: _runRetargetABC,
                child: const Text('Retarget A→B→C'),
              ),
              ElevatedButton(
                key: const ValueKey<String>('content_action_rapid_70'),
                onPressed: () => _runRapidBurst(intervalMs: 70),
                child: const Text('Rapid 70ms'),
              ),
              ElevatedButton(
                key: const ValueKey<String>('content_action_rapid_100'),
                onPressed: () => _runRapidBurst(intervalMs: 100),
                child: const Text('Rapid 100ms'),
              ),
              ElevatedButton(
                key: const ValueKey<String>('content_action_rapid_150'),
                onPressed: () => _runRapidBurst(intervalMs: 150),
                child: const Text('Rapid 150ms'),
              ),
            ],
          ),
          const Divider(height: 24),
          const Text(
            '2. Overlap Window Inspector (Scrub t)',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <double>[0.25, 0.30, 0.35, 0.40, 0.50].map((double tVal) {
              return OutlinedButton(
                key: ValueKey<String>(
                  'content_overlap_t_${tVal.toStringAsFixed(2)}',
                ),
                onPressed: () => _inspectOverlapProgress(tVal),
                child: Text('t = ${tVal.toStringAsFixed(2)}'),
              );
            }).toList(),
          ),
          const Divider(height: 24),
          const Text(
            '3. Topology & Anchor Selection',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: QuickNotesMorphTopologyMode.values.map((
              QuickNotesMorphTopologyMode mode,
            ) {
              final bool selected = _topologyMode == mode;
              return ChoiceChip(
                key: ValueKey<String>('content_topology_${mode.name}'),
                label: Text(mode.label),
                selected: selected,
                onSelected: (_) {
                  setState(() {
                    _topologyMode = mode;
                    final Rect rect = _computeStateRect(
                      _currentState,
                      _stageFieldSize,
                    );
                    _geometryController.seedInitialRect(
                      rect,
                      anchor: _selectedAnchor.alignment,
                    );
                    _contentController.seedInitialState(
                      stateId: _currentState,
                      stateRect: rect,
                      stiffness: _stiffness,
                    );
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: QuickNotesMorphAnchorOption.values.map((
              QuickNotesMorphAnchorOption anchorOpt,
            ) {
              final bool selected = _selectedAnchor == anchorOpt;
              return ChoiceChip(
                key: ValueKey<String>('content_anchor_${anchorOpt.name}'),
                label: Text(anchorOpt.label),
                selected: selected,
                onSelected: (_) {
                  setState(() {
                    _selectedAnchor = anchorOpt;
                    _geometryController.rebaseAnchor(anchorOpt.alignment);
                  });
                },
              );
            }).toList(),
          ),
          const Divider(height: 24),
          const Text(
            '4. Content Scale, Blur, Follow & Slide Matrix',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _buildChipRow<double>(
            label: 'oldScaleTo',
            keyPrefix: 'content_oldScaleTo',
            values: const <double>[1.00, 0.98, 0.95, 0.92, 0.88],
            currentValue: _oldScaleTo,
            format: (double v) => v.toStringAsFixed(2),
            onSelected: (double v) => setState(() => _oldScaleTo = v),
          ),
          _buildChipRow<double>(
            label: 'newScaleFrom',
            keyPrefix: 'content_newScaleFrom',
            values: const <double>[1.00, 0.98, 0.95, 0.90, 0.85],
            currentValue: _newScaleFrom,
            format: (double v) => v.toStringAsFixed(2),
            onSelected: (double v) => setState(() => _newScaleFrom = v),
          ),
          _buildChipRow<double>(
            label: 'contentBlur',
            keyPrefix: 'content_blur',
            values: const <double>[0.0, 4.0, 8.0, 12.0],
            currentValue: _contentBlur,
            format: (double v) => v.toStringAsFixed(0),
            onSelected: (double v) => setState(() => _contentBlur = v),
          ),
          _buildChipRow<double>(
            label: 'contentFollow',
            keyPrefix: 'content_follow',
            values: const <double>[0.0, 0.25, 0.50, 0.75, 1.0],
            currentValue: _contentFollow,
            format: (double v) => v.toStringAsFixed(2),
            onSelected: (double v) => setState(() => _contentFollow = v),
          ),
          _buildChipRow<double>(
            label: 'contentSlide',
            keyPrefix: 'content_slide',
            values: const <double>[-24.0, -12.0, 0.0, 12.0, 24.0],
            currentValue: _contentSlide,
            format: (double v) =>
                v > 0 ? '+${v.toStringAsFixed(0)}' : v.toStringAsFixed(0),
            onSelected: (double v) => setState(() => _contentSlide = v),
          ),
          const SizedBox(height: 6),
          Text(
            'Preset: ${_selectedPreset.label} • Timing: outEnd=${_contentOutEnd.toStringAsFixed(2)}, inStart=${_contentInStart.toStringAsFixed(2)}, inEnd=${_contentInEnd.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildChipRow<T>({
    required String label,
    required String keyPrefix,
    required List<T> values,
    required T currentValue,
    required String Function(T) format,
    required ValueChanged<T> onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: values.map((T val) {
                final String formatted = format(val);
                return ChoiceChip(
                  key: ValueKey<String>('${keyPrefix}_$formatted'),
                  label: Text(formatted, style: const TextStyle(fontSize: 11)),
                  selected: currentValue == val,
                  onSelected: (_) => onSelected(val),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
