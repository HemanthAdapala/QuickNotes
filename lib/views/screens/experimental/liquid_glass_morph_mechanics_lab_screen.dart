import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../themes/glassmorphism_presets.dart';
import '../../widgets/app_bottom_navigation_bar.dart'
    show BottomBarGlassSurface;

/// Target states for the Phase 8C-A Quick Notes Morph Mechanics Feasibility Lab.
enum QuickNotesMorphStateId {
  stateA('State A (Pill 128×48)', Size(128, 48)),
  stateB('State B (Card 268×176)', Size(268, 176)),
  stateC('State C (Banner 216×96)', Size(216, 96));

  const QuickNotesMorphStateId(this.label, this.defaultSize);
  final String label;
  final Size defaultSize;
}

/// Anchor options for testing anchor-pinned expansion and contraction.
enum QuickNotesMorphAnchorOption {
  center('Center', Alignment.center),
  topLeft('Top-Left', Alignment.topLeft),
  topRight('Top-Right', Alignment.topRight),
  bottomLeft('Bottom-Left', Alignment.bottomLeft),
  bottomRight('Bottom-Right', Alignment.bottomRight);

  const QuickNotesMorphAnchorOption(this.label, this.alignment);
  final String label;
  final Alignment alignment;
}

/// Topology modes isolating size+position, position-only, and size-only transitions.
enum QuickNotesMorphTopologyMode {
  sizeAndPosition('Size + Position'),
  positionOnly('Position Only (156×56)'),
  sizeOnly('Size Only (Concentric)');

  const QuickNotesMorphTopologyMode(this.label);
  final String label;
}

/// Native-inspired motion presets for the Phase 8C-A geometry controller.
enum QuickNotesMorphPreset {
  fluid('fluid'),
  anchoredPop('anchoredPop'),
  plain('plain'),
  droplet('droplet'),
  calm('calm');

  const QuickNotesMorphPreset(this.label);
  final String label;

  QuickNotesMorphGeometryConfig toConfig(Alignment activeAnchor) {
    switch (this) {
      case QuickNotesMorphPreset.fluid:
        return QuickNotesMorphGeometryConfig(
          stiffness: 195.0,
          damping: 19.5,
          stretch: 0.60,
          leadBounce: 0.10,
          followDelaySeconds: 0.04,
          seedScale: 1.0,
          anchor: activeAnchor,
        );
      case QuickNotesMorphPreset.anchoredPop:
        return QuickNotesMorphGeometryConfig(
          stiffness: 195.0,
          damping: 19.5,
          stretch: 0.20,
          leadBounce: 0.0,
          followDelaySeconds: 0.0,
          seedScale: 1.0,
          anchor: activeAnchor,
        );
      case QuickNotesMorphPreset.plain:
        return QuickNotesMorphGeometryConfig(
          stiffness: 195.0,
          damping: 19.5,
          stretch: 0.35,
          leadBounce: 0.05,
          followDelaySeconds: 0.04,
          seedScale: 1.0,
          anchor: activeAnchor,
        );
      case QuickNotesMorphPreset.droplet:
        return QuickNotesMorphGeometryConfig(
          stiffness: 195.0,
          damping: 19.5,
          stretch: 0.90,
          leadBounce: 0.15,
          followDelaySeconds: 0.09,
          seedScale: 0.55,
          anchor: activeAnchor,
        );
      case QuickNotesMorphPreset.calm:
        return QuickNotesMorphGeometryConfig(
          stiffness: 247.0,
          damping: 31.4,
          stretch: 0.25,
          leadBounce: 0.0,
          followDelaySeconds: 0.04,
          seedScale: 1.0,
          anchor: activeAnchor,
        );
    }
  }
}

/// Immutable configuration for the Phase 8C-A 4D Morph Geometry Controller.
@immutable
class QuickNotesMorphGeometryConfig {
  const QuickNotesMorphGeometryConfig({
    this.stiffness = 195.0,
    this.damping = 19.5,
    this.stretch = 0.60,
    this.leadBounce = 0.10,
    this.followDelaySeconds = 0.04,
    this.seedScale = 1.0,
    this.anchor = Alignment.center,
  })  : assert(stiffness > 0),
        assert(damping >= 0),
        assert(stretch >= 0.0 && stretch <= 1.0),
        assert(followDelaySeconds >= 0.0),
        assert(seedScale > 0.0 && seedScale <= 1.0);

  final double stiffness;
  final double damping;
  final double stretch;
  final double leadBounce;
  final double followDelaySeconds;
  final double seedScale;
  final Alignment anchor;

  /// Base damping ratio `zeta = damping / (2 * sqrt(stiffness))`.
  double get baseZeta => damping / (2.0 * math.sqrt(stiffness));

  /// Characteristic period `T = 2 * pi / sqrt(stiffness)` in seconds.
  double get periodSeconds => 2.0 * math.pi / math.sqrt(stiffness);

  /// Native-inspired lead stiffness multiplier `1 + 2.2 * stretch`.
  double get leadMultiplier => 1.0 + 2.2 * stretch;

  /// Leading spring pair damping ratio `clamp(baseZeta - leadBounce, 0.05, 4.0)`.
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
}

/// Minimal, isolated 1D damped harmonic oscillator for Quick Notes Phase 8C-A.
///
/// Uses semi-implicit (symplectic) Euler integration with a clamped time step
/// (`dt <= 1/30s`) so that underdamped springs (`zeta < 1`) remain stable across
/// variable frame intervals while preserving live velocity across interruptions.
class QuickNotesHarmonicSpring {
  QuickNotesHarmonicSpring(double initialValue)
      : _position = initialValue,
        _target = initialValue,
        _velocity = 0.0;

  double _position;
  double _target;
  double _velocity;

  static const double kPositionRestThreshold = 0.25;
  static const double kVelocityRestThreshold = 2.0;

  double get position => _position;
  double get target => _target;
  double get velocity => _velocity;

  bool get isMoving =>
      (_position - _target).abs() > kPositionRestThreshold ||
      _velocity.abs() > kVelocityRestThreshold;

  void setPositionAndTarget(double pos, double tgt) {
    _position = pos;
    _target = tgt;
  }

  void aimAt(double newTarget) {
    _target = newTarget;
  }

  void snapTo(double value) {
    _position = value;
    _target = value;
    _velocity = 0.0;
  }

  void advance(
    double dtSeconds, {
    required double stiffness,
    required double damping,
  }) {
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

/// Isolated 4D Morph Geometry Controller for Quick Notes Phase 8C-A.
///
/// Tracks four independent dimensions:
///   - `anchorX` (`ax`)
///   - `anchorY` (`ay`)
///   - `width` (`w`)
///   - `height` (`h`)
///
/// Implements asymmetric growing vs. shrinking lead-follow dynamics:
///   - Growing (`targetArea >= currentArea * 0.999`):
///     Anchor `(ax, ay)` leads at `leadMultiplier` with `leadZeta`, while
///     size `(w, h)` waits for `followDelaySeconds` before expanding on the
///     base spring.
///   - Shrinking (`targetArea < currentArea * 0.999`):
///     Size `(w, h)` collapses first at `leadMultiplier` with `leadZeta`, while
///     anchor `(ax, ay)` waits for `followDelaySeconds` before translating.
class QuickNotesMorphGeometryController {
  QuickNotesMorphGeometryController({
    Rect initialRect = const Rect.fromLTWH(0, 0, 128, 48),
    Alignment initialAnchor = Alignment.center,
  }) : _anchor = initialAnchor {
    seedInitialRect(initialRect, anchor: initialAnchor);
  }

  final QuickNotesHarmonicSpring anchorXSpring = QuickNotesHarmonicSpring(0);
  final QuickNotesHarmonicSpring anchorYSpring = QuickNotesHarmonicSpring(0);
  final QuickNotesHarmonicSpring widthSpring = QuickNotesHarmonicSpring(128);
  final QuickNotesHarmonicSpring heightSpring = QuickNotesHarmonicSpring(48);

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
  int _lastTransitionFrames = 0;
  double _elapsedSeconds = 0.0;
  double _lastSettleDurationMs = 0.0;
  int _settleCount = 0;

  Alignment get anchor => _anchor;
  Rect get originRect => _originRect;
  Rect get targetRect => _targetRect;
  bool get isSeeded => _isSeeded;
  bool get isGrowing => _isGrowing;
  double get anchorHoldRemaining => _anchorHoldRemaining;
  double get sizeHoldRemaining => _sizeHoldRemaining;
  int get activeFrameCount => _activeFrameCount;
  int get lastTransitionFrames => _lastTransitionFrames;
  double get elapsedSeconds => _elapsedSeconds;
  double get lastSettleDurationMs => _lastSettleDurationMs;
  int get settleCount => _settleCount;

  bool get isAnimating =>
      _anchorHoldRemaining > 0.0 ||
      _sizeHoldRemaining > 0.0 ||
      anchorXSpring.isMoving ||
      anchorYSpring.isMoving ||
      widthSpring.isMoving ||
      heightSpring.isMoving;

  /// Current bounding rectangle reconstructed from `(ax, ay, w, h)` and `anchor`.
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
  /// moving the current visual rectangle or losing velocity.
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
  void transitionToRect(
    Rect toRect, {
    required QuickNotesMorphGeometryConfig config,
    bool applySeedScaleWhenGrowing = true,
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
      // Optional seedScale birth size when starting a fresh growing transition
      // (e.g., droplet preset with seedScale = 0.55). Mid-flight interruptions
      // keep their live geometry so there is never a visual jump.
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
      _lastTransitionFrames = _activeFrameCount;
      _lastSettleDurationMs = _elapsedSeconds * 1000.0;
      _settleCount++;
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

/// Phase 8C-A: Quick Notes Native-Morph Mechanics Feasibility Laboratory.
///
/// Evaluates whether the 4D decoupled spring geometry (`ax, ay, w, h`) and
/// asymmetric growing/shrinking lead-follow mechanics can drive Quick Notes'
/// existing `BottomBarGlassSurface` without altering its visual appearance.
class LiquidGlassMorphMechanicsLabScreen extends StatefulWidget {
  const LiquidGlassMorphMechanicsLabScreen({super.key});

  @override
  State<LiquidGlassMorphMechanicsLabScreen> createState() =>
      _LiquidGlassMorphMechanicsLabScreenState();
}

class _LiquidGlassMorphMechanicsLabScreenState
    extends State<LiquidGlassMorphMechanicsLabScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastTickElapsed = Duration.zero;
  final List<Timer> _sequenceTimers = <Timer>[];

  final QuickNotesMorphGeometryController _controller =
      QuickNotesMorphGeometryController();

  QuickNotesMorphStateId _currentState = QuickNotesMorphStateId.stateA;
  QuickNotesMorphPreset _selectedPreset = QuickNotesMorphPreset.fluid;
  QuickNotesMorphAnchorOption _selectedAnchor =
      QuickNotesMorphAnchorOption.center;
  QuickNotesMorphTopologyMode _topologyMode =
      QuickNotesMorphTopologyMode.sizeAndPosition;

  double _stiffness = 195.0;
  double _damping = 19.5;
  double _stretch = 0.60;
  double _leadBounce = 0.10;
  double _followDelaySeconds = 0.04;
  double _seedScale = 1.0;
  bool _autoCapsuleRadius = false;
  double _fixedCornerRadius = 24.0;
  final bool _showTargetGhost = true;

  Size _stageFieldSize = const Size(520, 320);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    final Rect initial = _computeStateRect(
      QuickNotesMorphStateId.stateA,
      _stageFieldSize,
    );
    _controller.seedInitialRect(initial, anchor: _selectedAnchor.alignment);
  }

  @override
  void dispose() {
    _cancelTimers();
    _ticker.dispose();
    super.dispose();
  }

  void _cancelTimers() {
    for (final Timer t in _sequenceTimers) {
      t.cancel();
    }
    _sequenceTimers.clear();
  }

  QuickNotesMorphGeometryConfig _buildConfig() {
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

    final bool stillMoving = _controller.step(dt, _buildConfig());
    if (!stillMoving) {
      _ticker.stop();
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _transitionToState(QuickNotesMorphStateId targetState) {
    setState(() {
      _currentState = targetState;
      final Rect targetRect = _computeStateRect(targetState, _stageFieldSize);
      _controller.transitionToRect(
        targetRect,
        config: _buildConfig(),
      );
      _wakeTicker();
    });
  }

  void _applyPreset(QuickNotesMorphPreset preset) {
    final QuickNotesMorphGeometryConfig c =
        preset.toConfig(_selectedAnchor.alignment);
    setState(() {
      _selectedPreset = preset;
      _stiffness = c.stiffness;
      _damping = c.damping;
      _stretch = c.stretch;
      _leadBounce = c.leadBounce;
      _followDelaySeconds = c.followDelaySeconds;
      _seedScale = c.seedScale;
    });
  }

  void _runAToB() {
    _cancelTimers();
    if (_currentState != QuickNotesMorphStateId.stateA) {
      _controller.seedInitialRect(
        _computeStateRect(QuickNotesMorphStateId.stateA, _stageFieldSize),
        anchor: _selectedAnchor.alignment,
      );
      _currentState = QuickNotesMorphStateId.stateA;
    }
    _transitionToState(QuickNotesMorphStateId.stateB);
  }

  void _runBToA() {
    _cancelTimers();
    if (_currentState != QuickNotesMorphStateId.stateB) {
      _controller.seedInitialRect(
        _computeStateRect(QuickNotesMorphStateId.stateB, _stageFieldSize),
        anchor: _selectedAnchor.alignment,
      );
      _currentState = QuickNotesMorphStateId.stateB;
    }
    _transitionToState(QuickNotesMorphStateId.stateA);
  }

  void _runAToBToCSequential() {
    _cancelTimers();
    _controller.seedInitialRect(
      _computeStateRect(QuickNotesMorphStateId.stateA, _stageFieldSize),
      anchor: _selectedAnchor.alignment,
    );
    setState(() {
      _currentState = QuickNotesMorphStateId.stateA;
    });
    _transitionToState(QuickNotesMorphStateId.stateB);
    _sequenceTimers.add(
      Timer(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        _transitionToState(QuickNotesMorphStateId.stateC);
      }),
    );
  }

  void _runInterruptABA() {
    _cancelTimers();
    _controller.seedInitialRect(
      _computeStateRect(QuickNotesMorphStateId.stateA, _stageFieldSize),
      anchor: _selectedAnchor.alignment,
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
    _controller.seedInitialRect(
      _computeStateRect(QuickNotesMorphStateId.stateA, _stageFieldSize),
      anchor: _selectedAnchor.alignment,
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
    _controller.seedInitialRect(
      _computeStateRect(QuickNotesMorphStateId.stateA, _stageFieldSize),
      anchor: _selectedAnchor.alignment,
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

  void _resetToBaseline() {
    _cancelTimers();
    _ticker.stop();
    setState(() {
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
      _autoCapsuleRadius = false;
      _fixedCornerRadius = 24.0;
      _controller.seedInitialRect(
        _computeStateRect(QuickNotesMorphStateId.stateA, _stageFieldSize),
        anchor: Alignment.center,
      );
    });
  }

  BorderRadius _computeBorderRadius(Rect rect) {
    final double maxPossible = math.min(rect.width, rect.height) * 0.5;
    final double r = _autoCapsuleRadius
        ? maxPossible
        : math.min(_fixedCornerRadius, maxPossible);
    return BorderRadius.circular(r);
  }

  @override
  Widget build(BuildContext context) {
    final QuickNotesMorphGeometryConfig config = _buildConfig();
    final Rect liveRect = _controller.currentRect;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0D14),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool isWide = constraints.maxWidth >= 860;
            return Column(
              children: <Widget>[
                _buildHeaderBar(config, liveRect),
                Expanded(
                  child: isWide
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(
                                flex: 6,
                                child: _buildStagePanel(liveRect),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                flex: 5,
                                child: SingleChildScrollView(
                                  key: const ValueKey(
                                    'mechanics_lab_scroll_view',
                                  ),
                                  child: _buildControlPanel(),
                                ),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          key: const ValueKey('mechanics_lab_scroll_view'),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              _buildStagePanel(liveRect),
                              const SizedBox(height: 16),
                              _buildControlPanel(),
                            ],
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeaderBar(QuickNotesMorphGeometryConfig config, Rect liveRect) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF131622),
        border: Border(bottom: BorderSide(color: Color(0xFF23283D))),
      ),
      child: Row(
        children: <Widget>[
          InkWell(
            key: const ValueKey('mechanics_lab_back_button'),
            onTap: () => Navigator.of(context).maybePop(),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF1C2030),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF2E3550)),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'PHASE 8C-A — QUICK NOTES MORPH MECHANICS FEASIBILITY LAB',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Surface: BottomBarGlassSurface (LOCKED σ=${GlassmorphismPresets.blurSigma}) • '
                  'leadMul=${config.leadMultiplier.toStringAsFixed(2)}x • '
                  'leadZeta=${config.leadZeta.toStringAsFixed(2)} • '
                  'rect=(${liveRect.left.toStringAsFixed(1)}, ${liveRect.top.toStringAsFixed(1)}, '
                  '${liveRect.width.toStringAsFixed(1)}×${liveRect.height.toStringAsFixed(1)}) • '
                  'frames=${_controller.activeFrameCount} • settled=${_controller.settleCount}',
                  key: const ValueKey('mechanics_lab_telemetry_text'),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _controller.isAnimating
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF10B981),
              ),
            ),
            child: Text(
              _controller.isAnimating ? 'MOVING' : 'IDLE',
              key: const ValueKey('mechanics_lab_status_badge'),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _controller.isAnimating
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF10B981),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStagePanel(Rect liveRect) {
    return Container(
      key: const ValueKey('mechanics_preview_stage_container'),
      height: 360,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF262D45)),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints stageConstraints) {
          final Size paddedField = Size(
            math.max(280, stageConstraints.maxWidth - 40),
            math.max(220, stageConstraints.maxHeight - 40),
          );
          if (paddedField != _stageFieldSize) {
            _stageFieldSize = paddedField;
            if (!_controller.isAnimating) {
              _controller.seedInitialRect(
                _computeStateRect(_currentState, _stageFieldSize),
                anchor: _selectedAnchor.alignment,
              );
            }
          }
          final Rect current = _controller.currentRect;
          final Rect target = _controller.targetRect;

          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              _buildQuickNotesWallpaperBackground(),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    if (_showTargetGhost)
                      Positioned.fromRect(
                        rect: target,
                        child: IgnorePointer(
                          child: Container(
                            key: const ValueKey('mechanics_target_ghost_box'),
                            decoration: BoxDecoration(
                              borderRadius: _computeBorderRadius(target),
                              border: Border.all(
                                color: const Color(0xFF0284C7).withAlpha(90),
                                width: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Positioned.fromRect(
                      key: const ValueKey('mechanics_positioned_glass_host'),
                      rect: current,
                      child: BottomBarGlassSurface(
                        key: const ValueKey(
                          'mechanics_quick_notes_glass_surface',
                        ),
                        width: current.width,
                        height: current.height,
                        borderRadius: _computeBorderRadius(current),
                        child: _buildStableInteriorContent(current),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Light editorial wallpaper with geometric color accents so Quick Notes'
  /// authentic light-mode `BottomBarGlassSurface` (white top-fade gradient +
  /// S0 drop shadow + 4-layer inset shadow + sigma=3.0 BackdropFilter) is
  /// observed in its true visual environment.
  Widget _buildQuickNotesWallpaperBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFF5F6FA),
            Color(0xFFE8ECF5),
            Color(0xFFF2EFE9),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned(
            left: 36,
            top: 28,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    const Color(0xFF38BDF8).withAlpha(110),
                    const Color(0xFF38BDF8).withAlpha(0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: 24,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    const Color(0xFFF59E0B).withAlpha(105),
                    const Color(0xFFF59E0B).withAlpha(0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 190,
            top: 90,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    const Color(0xFFA855F7).withAlpha(85),
                    const Color(0xFFA855F7).withAlpha(0),
                  ],
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: CustomPaint(
              painter: _LightStageGridPainter(),
            ),
          ),
        ],
      ),
    );
  }

  /// Phase 8C-A Rule (Section 20): Content morphing is OUT OF SCOPE.
  /// Content remains stable inside the moving Quick Notes glass surface.
  Widget _buildStableInteriorContent(Rect current) {
    return ClipRect(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(
                Icons.auto_awesome_mosaic_rounded,
                size: 16,
                color: Color(0xFF333333),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'QN Glass • ${_currentState.name.toUpperCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF333333),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131622),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF23283D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildSectionHeader('ACTIONS & INTERRUPTION TRIGGERS'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _buildActionButton(
                key: const ValueKey('mechanics_action_a_to_b'),
                label: 'A → B (Grow)',
                onTap: _runAToB,
              ),
              _buildActionButton(
                key: const ValueKey('mechanics_action_b_to_a'),
                label: 'B → A (Shrink)',
                onTap: _runBToA,
              ),
              _buildActionButton(
                key: const ValueKey('mechanics_action_a_to_b_to_c'),
                label: 'A → B → C',
                onTap: _runAToBToCSequential,
              ),
              _buildActionButton(
                key: const ValueKey('mechanics_action_interrupt_aba'),
                label: 'INTERRUPT (A→B→A)',
                onTap: _runInterruptABA,
              ),
              _buildActionButton(
                key: const ValueKey('mechanics_action_retarget_abc'),
                label: 'RETARGET (A→B→C)',
                onTap: _runRetargetABC,
              ),
              _buildActionButton(
                key: const ValueKey('mechanics_action_rapid_70ms'),
                label: 'RAPID 70ms',
                onTap: () => _runRapidBurst(intervalMs: 70),
              ),
              _buildActionButton(
                key: const ValueKey('mechanics_action_rapid_100ms'),
                label: 'RAPID 100ms',
                onTap: () => _runRapidBurst(intervalMs: 100),
              ),
              _buildActionButton(
                key: const ValueKey('mechanics_action_reset'),
                label: 'RESET',
                isAccent: true,
                onTap: _resetToBaseline,
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFF23283D)),

          _buildSectionHeader('NATIVE-INSPIRED MOTION PRESETS'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                QuickNotesMorphPreset.values.map((QuickNotesMorphPreset p) {
              return ChoiceChip(
                key: ValueKey<String>('mechanics_preset_${p.name}'),
                label: Text(p.label),
                selected: _selectedPreset == p,
                onSelected: (_) => _applyPreset(p),
                selectedColor: const Color(0xFF0284C7),
                backgroundColor: const Color(0xFF1C2030),
                labelStyle: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              );
            }).toList(),
          ),
          const Divider(height: 24, color: Color(0xFF23283D)),

          _buildSectionHeader('ANCHOR ALIGNMENT'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: QuickNotesMorphAnchorOption.values
                .map((QuickNotesMorphAnchorOption a) {
              return ChoiceChip(
                key: ValueKey<String>('mechanics_anchor_${a.name}'),
                label: Text(a.label),
                selected: _selectedAnchor == a,
                onSelected: (_) {
                  setState(() {
                    _selectedAnchor = a;
                    _controller.seedInitialRect(
                      _computeStateRect(_currentState, _stageFieldSize),
                      anchor: a.alignment,
                    );
                  });
                },
                selectedColor: const Color(0xFF0284C7),
                backgroundColor: const Color(0xFF1C2030),
                labelStyle: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              );
            }).toList(),
          ),
          const Divider(height: 24, color: Color(0xFF23283D)),

          _buildSectionHeader('TOPOLOGY MODE'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: QuickNotesMorphTopologyMode.values
                .map((QuickNotesMorphTopologyMode m) {
              return ChoiceChip(
                key: ValueKey<String>('mechanics_topology_${m.name}'),
                label: Text(m.label),
                selected: _topologyMode == m,
                onSelected: (_) {
                  setState(() {
                    _topologyMode = m;
                    _controller.seedInitialRect(
                      _computeStateRect(_currentState, _stageFieldSize),
                      anchor: _selectedAnchor.alignment,
                    );
                  });
                },
                selectedColor: const Color(0xFF0284C7),
                backgroundColor: const Color(0xFF1C2030),
                labelStyle: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              );
            }).toList(),
          ),
          const Divider(height: 24, color: Color(0xFF23283D)),

          _buildSectionHeader('GEOMETRY & SPRING PARAMETERS'),
          _buildSliderRow(
            sliderKey: const ValueKey('mechanics_slider_stretch'),
            label: 'Stretch (leadMul = 1 + 2.2·s)',
            value: _stretch,
            min: 0.0,
            max: 1.0,
            onChanged: (double v) => setState(() => _stretch = v),
          ),
          _buildSliderRow(
            sliderKey: const ValueKey('mechanics_slider_lead_bounce'),
            label: 'Lead Bounce (Δζ)',
            value: _leadBounce,
            min: 0.0,
            max: 0.30,
            onChanged: (double v) => setState(() => _leadBounce = v),
          ),
          _buildSliderRow(
            sliderKey: const ValueKey('mechanics_slider_follow_delay'),
            label: 'Follow Delay (s)',
            value: _followDelaySeconds,
            min: 0.0,
            max: 0.18,
            onChanged: (double v) => setState(() => _followDelaySeconds = v),
          ),
          _buildSliderRow(
            sliderKey: const ValueKey('mechanics_slider_seed_scale'),
            label: 'Seed Scale',
            value: _seedScale,
            min: 0.20,
            max: 1.0,
            onChanged: (double v) => setState(() => _seedScale = v),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF94A3B8),
        letterSpacing: 0.6,
      ),
    );
  }

  Widget _buildActionButton({
    required Key key,
    required String label,
    required VoidCallback onTap,
    bool isAccent = false,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isAccent ? const Color(0xFFBE123C) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isAccent ? const Color(0xFFF43F5E) : const Color(0xFF334155),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required Key sliderKey,
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              Text(
                value.toStringAsFixed(2),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  color: const Color(0xFF38BDF8),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              key: sliderKey,
              value: value.clamp(min, max),
              min: min,
              max: max,
              activeColor: const Color(0xFF38BDF8),
              inactiveColor: const Color(0xFF1E293B),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _LightStageGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = const Color(0xFF334155).withAlpha(18)
      ..strokeWidth = 1;
    const double step = 28;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
