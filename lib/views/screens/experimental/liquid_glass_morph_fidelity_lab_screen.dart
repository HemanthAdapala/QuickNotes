import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../widgets/app_bottom_navigation_bar.dart'
    show BottomBarGlassSurface;
import 'liquid_glass_morph_content_lab_screen.dart'
    show
        QuickNotesEvaluatedContentLayer,
        QuickNotesMorphContentConfig,
        QuickNotesMorphContentController,
        QuickNotesMorphContentSnapshot;
import 'liquid_glass_morph_mechanics_lab_screen.dart'
    show
        QuickNotesMorphAnchorOption,
        QuickNotesMorphGeometryConfig,
        QuickNotesMorphGeometryController,
        QuickNotesMorphStateId;

/// Target states for the Phase 8C-D Morph Fidelity & Circle → Square Lab.
///
/// - [circle]: 56 × 56 (`width == height`). When rendered by Quick Notes'
///   existing `BottomBarGlassSurface` with `borderRadius = min(28, min(w,h)/2) = 28`,
///   this produces a true circular glass silhouette without altering the renderer.
/// - [square]: 224 × 184 (`width != height`) with `borderRadius = 28.0`,
///   producing a rounded-square / card silhouette.
/// - [alternate]: 168 × 112 (`width != height`) compact card used for mid-flight
///   retarget testing (Mode F).
enum MorphFidelityStateId {
  circle('Circle (56×56)', 'Circle', Size(56, 56)),
  square('Square (224×184)', 'Square', Size(224, 184)),
  alternate('Alt Target (168×112)', 'Alt Card', Size(168, 112));

  const MorphFidelityStateId(this.fullLabel, this.shortLabel, this.size);
  final String fullLabel;
  final String shortLabel;
  final Size size;
}

extension MorphFidelityStateMapping on MorphFidelityStateId {
  QuickNotesMorphStateId toPhase8CStateId() {
    switch (this) {
      case MorphFidelityStateId.circle:
        return QuickNotesMorphStateId.stateA;
      case MorphFidelityStateId.square:
        return QuickNotesMorphStateId.stateB;
      case MorphFidelityStateId.alternate:
        return QuickNotesMorphStateId.stateC;
    }
  }
}

extension QuickNotesStateMapping on QuickNotesMorphStateId {
  MorphFidelityStateId toFidelityStateId() {
    switch (this) {
      case QuickNotesMorphStateId.stateA:
        return MorphFidelityStateId.circle;
      case QuickNotesMorphStateId.stateB:
        return MorphFidelityStateId.square;
      case QuickNotesMorphStateId.stateC:
        return MorphFidelityStateId.alternate;
    }
  }
}

/// Primary reference modes required by Section 7 of Phase 8C-D.
enum MorphFidelityReferenceMode {
  modeACircleToSquare('MODE A — CIRCLE → SQUARE', 'Circle → Square'),
  modeBSquareToCircle('MODE B — SQUARE → CIRCLE', 'Square → Circle'),
  modeCCircleSquareCircle(
    'MODE C — CIRCLE → SQUARE → CIRCLE',
    'Circle → Square → Circle',
  ),
  modeDCircleToSquareWithPosition(
    'MODE D — CIRCLE → SQUARE WITH POSITION',
    'Circle → Square + Position',
  ),
  modeEInterrupted('MODE E — INTERRUPTED', 'Interrupted (C → S → C)'),
  modeFRetarget('MODE F — RETARGET', 'Retarget (C → S → Alt)');

  const MorphFidelityReferenceMode(this.fullTitle, this.buttonLabel);
  final String fullTitle;
  final String buttonLabel;
}

/// Spatial placement mode for Circle → Square experiments.
enum MorphFidelitySpatialMode {
  anchorPlaced('In-Place (Anchor Aligned)'),
  withPosition('With Position (Translate + Resize)');

  const MorphFidelitySpatialMode(this.label);
  final String label;
}

/// Position choreography refinement variants required by Section 12.
///
/// All variants reuse the existing Phase 8C-A `QuickNotesMorphGeometryController`
/// without rewriting the 4D spring engine.
enum MorphFidelityChoreographyVariant {
  baseline(
    'Baseline',
    'Phase 8C-A default: Growing leads with anchor (1 + 2.2·stretch) and holds size for followDelay; Shrinking leads with size and holds anchor for followDelay.',
  ),
  positionLead(
    'Position Lead',
    'Anchor (ax, ay) leads at (1 + 2.2·stretch) with leadBounce while size (w, h) waits followDelay in BOTH growing and shrinking transitions.',
  ),
  sizeLead(
    'Size Lead',
    'Size (w, h) expands immediately at (1 + 2.2·stretch) while anchor (ax, ay) waits followDelay when growing, so the circle blooms before/during travel.',
  ),
  balanced(
    'Balanced',
    'Synchronized 4D choreography (followDelay = 0 ms, leadBounce = 0, matched stiffness multiplier = 1.0, center-tracked translation) eliminating center path bowing.',
  ),
  anchorLocked(
    'Anchor Locked',
    'Native anchoredPop-inspired lock: tracks the active placement corner/center with stretch = 0.20, leadBounce = 0.0, followDelay = 0 ms so the pinned edge never detaches.',
  );

  const MorphFidelityChoreographyVariant(this.label, this.description);
  final String label;
  final String description;
}

/// Comparison profiles required by Section 13 ("NATIVE REFERENCE COMPARISON").
enum MorphFidelityComparisonProfile {
  nativeReference(
    'Native Reference',
    'Verified Phase 8A-R / 8B liquid_glass_easy 4.3.1 behavior specification (two-blob LiquidGlassBlender union in fluid mode; single-lens spring in plain/anchoredPop). Not rendered by Quick Notes glass.',
  ),
  quickNotesBaseline(
    'Quick Notes Baseline',
    'Existing BottomBarGlassSurface + Phase 8C-A Baseline choreography (stretch = 0.60, leadBounce = 0.10, followDelay = 40 ms).',
  ),
  quickNotesRefined(
    'Quick Notes Refined',
    'Existing BottomBarGlassSurface + Refined single-surface choreography (Balanced / Anchor-Locked coordination, zero hold lag, clamped 28px circular-to-card radius).',
  );

  const MorphFidelityComparisonProfile(this.label, this.summary);
  final String label;
  final String summary;
}

/// Pass / Fail / Not Tested status for physical-device test recording.
enum MorphFidelityCheckStatus {
  pass('PASS'),
  fail('FAIL'),
  notTested('NOT TESTED');

  const MorphFidelityCheckStatus(this.label);
  final String label;
}

/// Specification for one item in the Phase 8C-D checklists.
@immutable
class MorphFidelityChecklistItem {
  const MorphFidelityChecklistItem({
    required this.id,
    required this.group,
    required this.title,
  });

  final String id;
  final String group;
  final String title;
}

/// The 12 Physical Device Test Sequence items required by Section 19.
const List<MorphFidelityChecklistItem> kFidelityPhysicalSequenceTests =
    <MorphFidelityChecklistItem>[
  MorphFidelityChecklistItem(
    id: 'seq_test_1',
    group: 'TEST SEQUENCE',
    title: 'TEST 1: Circle → Square',
  ),
  MorphFidelityChecklistItem(
    id: 'seq_test_2',
    group: 'TEST SEQUENCE',
    title: 'TEST 2: Square → Circle',
  ),
  MorphFidelityChecklistItem(
    id: 'seq_test_3',
    group: 'TEST SEQUENCE',
    title: 'TEST 3: Circle → Square → Circle',
  ),
  MorphFidelityChecklistItem(
    id: 'seq_test_4',
    group: 'TEST SEQUENCE',
    title: 'TEST 4: Circle → Square with Center anchor',
  ),
  MorphFidelityChecklistItem(
    id: 'seq_test_5',
    group: 'TEST SEQUENCE',
    title: 'TEST 5: Circle → Square with Top Left anchor',
  ),
  MorphFidelityChecklistItem(
    id: 'seq_test_6',
    group: 'TEST SEQUENCE',
    title: 'TEST 6: Circle → Square with Top Right anchor',
  ),
  MorphFidelityChecklistItem(
    id: 'seq_test_7',
    group: 'TEST SEQUENCE',
    title: 'TEST 7: Circle → Square with Bottom Left anchor',
  ),
  MorphFidelityChecklistItem(
    id: 'seq_test_8',
    group: 'TEST SEQUENCE',
    title: 'TEST 8: Circle → Square with Bottom Right anchor',
  ),
  MorphFidelityChecklistItem(
    id: 'seq_test_9',
    group: 'TEST SEQUENCE',
    title: 'TEST 9: Circle → Square interrupted → Circle',
  ),
  MorphFidelityChecklistItem(
    id: 'seq_test_10',
    group: 'TEST SEQUENCE',
    title: 'TEST 10: Circle → Square retargeted mid-flight',
  ),
  MorphFidelityChecklistItem(
    id: 'seq_test_11',
    group: 'TEST SEQUENCE',
    title: 'TEST 11: Rapid repeated Circle/Square transitions',
  ),
  MorphFidelityChecklistItem(
    id: 'seq_test_12',
    group: 'TEST SEQUENCE',
    title: 'TEST 12: Compare Baseline vs Refined position choreography',
  ),
];

/// Visual Comparison Checklist items required by Section 14.
const List<MorphFidelityChecklistItem> kFidelityVisualComparisonItems =
    <MorphFidelityChecklistItem>[
  MorphFidelityChecklistItem(
    id: 'vis_shape_circle_starts',
    group: 'SHAPE',
    title: 'Circle starts correctly',
  ),
  MorphFidelityChecklistItem(
    id: 'vis_shape_circle_expands',
    group: 'SHAPE',
    title: 'Circle expands correctly',
  ),
  MorphFidelityChecklistItem(
    id: 'vis_shape_square_looks_correct',
    group: 'SHAPE',
    title: 'Rounded-square state looks correct',
  ),
  MorphFidelityChecklistItem(
    id: 'vis_shape_reverse_correct',
    group: 'SHAPE',
    title: 'Reverse morph looks correct',
  ),
  MorphFidelityChecklistItem(
    id: 'vis_shape_no_jump',
    group: 'SHAPE',
    title: 'No unexpected shape jump',
  ),
  MorphFidelityChecklistItem(
    id: 'vis_pos_start_correct',
    group: 'POSITION',
    title: 'Start position correct',
  ),
  MorphFidelityChecklistItem(
    id: 'vis_pos_begins_correct_time',
    group: 'POSITION',
    title: 'Movement begins at correct time',
  ),
  MorphFidelityChecklistItem(
    id: 'vis_pos_expected_trajectory',
    group: 'POSITION',
    title: 'Movement follows expected trajectory',
  ),
  MorphFidelityChecklistItem(
    id: 'vis_pos_anchor_stable',
    group: 'POSITION',
    title: 'Anchor remains stable',
  ),
  MorphFidelityChecklistItem(
    id: 'vis_pos_final_correct',
    group: 'POSITION',
    title: 'Final position correct',
  ),
  MorphFidelityChecklistItem(
    id: 'vis_pos_no_snap',
    group: 'POSITION',
    title: 'No visible positional snap',
  ),
  MorphFidelityChecklistItem(
    id: 'vis_pos_no_overshoot',
    group: 'POSITION',
    title: 'No unwanted overshoot',
  ),
  MorphFidelityChecklistItem(
    id: 'vis_motion_expansion_continuous',
    group: 'MOTION',
    title: 'Expansion feels continuous',
  ),
  MorphFidelityChecklistItem(
    id: 'vis_motion_contraction_continuous',
    group: 'MOTION',
    title: 'Contraction feels continuous',
  ),
  MorphFidelityChecklistItem(
    id: 'vis_motion_choreo_coordinated',
    group: 'MOTION',
    title: 'Position/size choreography feels coordinated',
  ),
  MorphFidelityChecklistItem(
    id: 'vis_motion_no_sudden_accel',
    group: 'MOTION',
    title: 'No sudden acceleration',
  ),
  MorphFidelityChecklistItem(
    id: 'vis_motion_no_sudden_decel',
    group: 'MOTION',
    title: 'No sudden deceleration',
  ),
  MorphFidelityChecklistItem(
    id: 'vis_motion_interruption_continuous',
    group: 'MOTION',
    title: 'Interruption remains continuous',
  ),
  MorphFidelityChecklistItem(
    id: 'vis_content_outgoing_fades',
    group: 'CONTENT',
    title: 'Outgoing content fades correctly',
  ),
  MorphFidelityChecklistItem(
    id: 'vis_content_incoming_appears',
    group: 'CONTENT',
    title: 'Incoming content appears correctly',
  ),
  MorphFidelityChecklistItem(
    id: 'vis_content_no_flash',
    group: 'CONTENT',
    title: 'No content flash',
  ),
  MorphFidelityChecklistItem(
    id: 'vis_content_no_jump',
    group: 'CONTENT',
    title: 'No content jump',
  ),
  MorphFidelityChecklistItem(
    id: 'vis_content_blur_correct',
    group: 'CONTENT',
    title: 'Blur behaves correctly',
  ),
  MorphFidelityChecklistItem(
    id: 'vis_glass_preserved',
    group: 'GLASS',
    title: 'Quick Notes glass appearance preserved',
  ),
  MorphFidelityChecklistItem(
    id: 'vis_glass_no_flicker',
    group: 'GLASS',
    title: 'No flicker',
  ),
  MorphFidelityChecklistItem(
    id: 'vis_glass_no_clipping',
    group: 'GLASS',
    title: 'No clipping artifact',
  ),
  MorphFidelityChecklistItem(
    id: 'vis_glass_no_renderer_change',
    group: 'GLASS',
    title: 'No unwanted renderer change',
  ),
  MorphFidelityChecklistItem(
    id: 'vis_glass_no_shader_artifacts',
    group: 'GLASS',
    title: 'No shader artifacts',
  ),
];

/// Isolated refinement orchestration layer over [QuickNotesMorphGeometryController].
///
/// Preserves the Phase 8C-A `QuickNotesMorphGeometryController` untouched while
/// allowing controlled testing of `Baseline`, `Position Lead`, `Size Lead`,
/// `Balanced`, and `Anchor Locked` choreography variants in Phase 8C-D.
class MorphFidelityChoreographyAdapter {
  MorphFidelityChoreographyAdapter(this.geometryController);

  final QuickNotesMorphGeometryController geometryController;

  double _customAnchorHold = 0.0;
  double _customSizeHold = 0.0;
  double _customAnchorMul = 1.0;
  double _customSizeMul = 1.0;
  double? _customAnchorZeta;
  double? _customSizeZeta;
  bool _useCustomStep = false;

  /// Resolves the effective [QuickNotesMorphGeometryConfig] for a given
  /// [variant] and user-selected parameters.
  QuickNotesMorphGeometryConfig resolveConfig({
    required MorphFidelityChoreographyVariant variant,
    required double baseStiffness,
    required double baseDamping,
    required double userStretch,
    required double userLeadBounce,
    required int userFollowDelayMs,
    required Alignment selectedAnchor,
    required Alignment placementAlignment,
    required MorphFidelitySpatialMode spatialMode,
  }) {
    switch (variant) {
      case MorphFidelityChoreographyVariant.baseline:
      case MorphFidelityChoreographyVariant.positionLead:
      case MorphFidelityChoreographyVariant.sizeLead:
        return QuickNotesMorphGeometryConfig(
          stiffness: baseStiffness,
          damping: baseDamping,
          stretch: userStretch,
          leadBounce: userLeadBounce,
          followDelaySeconds: userFollowDelayMs / 1000.0,
          seedScale: 1.0,
          anchor: spatialMode == MorphFidelitySpatialMode.withPosition
              ? Alignment.center
              : selectedAnchor,
        );
      case MorphFidelityChoreographyVariant.balanced:
        // Coupled 4D spring: zero lag between position and size, center-tracked
        // when translating so center trajectory is a straight line.
        return QuickNotesMorphGeometryConfig(
          stiffness: baseStiffness,
          damping: baseDamping,
          stretch: 0.0,
          leadBounce: 0.0,
          followDelaySeconds: 0.0,
          seedScale: 1.0,
          anchor: spatialMode == MorphFidelitySpatialMode.withPosition
              ? Alignment.center
              : selectedAnchor,
        );
      case MorphFidelityChoreographyVariant.anchorLocked:
        // Native anchoredPop-inspired lock: tracking anchor matches placement
        // alignment with subtle stretch (0.20), zero bounce, zero hold delay.
        return QuickNotesMorphGeometryConfig(
          stiffness: baseStiffness,
          damping: baseDamping,
          stretch: 0.20,
          leadBounce: 0.0,
          followDelaySeconds: 0.0,
          seedScale: 1.0,
          anchor: placementAlignment,
        );
    }
  }

  /// Starts or retargets a transition according to [variant].
  void startTransition(
    Rect toRect, {
    required MorphFidelityChoreographyVariant variant,
    required QuickNotesMorphGeometryConfig config,
  }) {
    geometryController.transitionToRect(
      toRect,
      config: config,
      applySeedScaleWhenGrowing: false,
    );

    if (variant == MorphFidelityChoreographyVariant.positionLead ||
        variant == MorphFidelityChoreographyVariant.sizeLead) {
      _useCustomStep = true;
      final double leadMul = config.leadMultiplier;
      final double leadZeta = config.leadZeta;
      if (variant == MorphFidelityChoreographyVariant.positionLead) {
        _customAnchorMul = leadMul;
        _customSizeMul = 1.0;
        _customAnchorZeta = leadZeta;
        _customSizeZeta = null;
        _customAnchorHold = 0.0;
        _customSizeHold = config.followDelaySeconds;
      } else {
        _customAnchorMul = 1.0;
        _customSizeMul = leadMul;
        _customAnchorZeta = null;
        _customSizeZeta = leadZeta;
        _customAnchorHold = config.followDelaySeconds;
        _customSizeHold = 0.0;
      }
    } else {
      _useCustomStep = false;
      _customAnchorHold = 0.0;
      _customSizeHold = 0.0;
    }
  }

  /// Advances the geometry controller by [dtSeconds].
  bool step(double dtSeconds, QuickNotesMorphGeometryConfig config) {
    if (!_useCustomStep) {
      return geometryController.step(dtSeconds, config);
    }
    if (dtSeconds <= 0.0) return isAnimating;
    final double clampedDt = math.min(dtSeconds, 1.0 / 30.0);

    if (_customAnchorHold > 0.0) {
      _customAnchorHold = math.max(0.0, _customAnchorHold - clampedDt);
    } else {
      final double kAnchor = config.stiffness * _customAnchorMul;
      final double dAnchor = _customAnchorZeta != null
          ? 2.0 * _customAnchorZeta! * math.sqrt(kAnchor)
          : config.damping * math.sqrt(_customAnchorMul);
      geometryController.anchorXSpring.advance(
        clampedDt,
        stiffness: kAnchor,
        damping: dAnchor,
      );
      geometryController.anchorYSpring.advance(
        clampedDt,
        stiffness: kAnchor,
        damping: dAnchor,
      );
    }

    if (_customSizeHold > 0.0) {
      _customSizeHold = math.max(0.0, _customSizeHold - clampedDt);
    } else {
      final double kSize = config.stiffness * _customSizeMul;
      final double dSize = _customSizeZeta != null
          ? 2.0 * _customSizeZeta! * math.sqrt(kSize)
          : config.damping * math.sqrt(_customSizeMul);
      geometryController.widthSpring.advance(
        clampedDt,
        stiffness: kSize,
        damping: dSize,
      );
      geometryController.heightSpring.advance(
        clampedDt,
        stiffness: kSize,
        damping: dSize,
      );
    }

    if (!isAnimating) {
      geometryController.seedInitialRect(
        geometryController.targetRect,
        anchor: geometryController.anchor,
      );
      return false;
    }
    return true;
  }

  bool get isAnimating =>
      _useCustomStep
          ? (_customAnchorHold > 0.0 ||
              _customSizeHold > 0.0 ||
              geometryController.anchorXSpring.isMoving ||
              geometryController.anchorYSpring.isMoving ||
              geometryController.widthSpring.isMoving ||
              geometryController.heightSpring.isMoving)
          : geometryController.isAnimating;
}

/// Phase 8C-D: Isolated Morph Fidelity & Circle → Square Reference Lab.
///
/// Compares Quick Notes' single-surface Morphing (`BottomBarGlassSurface` +
/// Phase 8C-A 4D geometry + Phase 8C-B content handoff) against the verified
/// `liquid_glass_easy 4.3.1` Circle → Square reference behavior.
class LiquidGlassMorphFidelityLabScreen extends StatefulWidget {
  const LiquidGlassMorphFidelityLabScreen({super.key});

  @override
  State<LiquidGlassMorphFidelityLabScreen> createState() =>
      _LiquidGlassMorphFidelityLabScreenState();
}

class _LiquidGlassMorphFidelityLabScreenState
    extends State<LiquidGlassMorphFidelityLabScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastTickElapsed = Duration.zero;
  final List<Timer> _sequenceTimers = <Timer>[];

  final QuickNotesMorphGeometryController _geometryController =
      QuickNotesMorphGeometryController(
    initialRect: const Rect.fromLTWH(0, 0, 56, 56),
  );
  late final MorphFidelityChoreographyAdapter _choreographyAdapter =
      MorphFidelityChoreographyAdapter(_geometryController);
  final QuickNotesMorphContentController _contentController =
      QuickNotesMorphContentController();

  // ── Active Morph State & Mode ───────────────────────────────────────
  MorphFidelityStateId _currentState = MorphFidelityStateId.circle;
  MorphFidelityStateId _targetState = MorphFidelityStateId.circle;
  MorphFidelityReferenceMode _lastReferenceMode =
      MorphFidelityReferenceMode.modeACircleToSquare;
  MorphFidelitySpatialMode _spatialMode =
      MorphFidelitySpatialMode.withPosition;
  MorphFidelityChoreographyVariant _choreographyVariant =
      MorphFidelityChoreographyVariant.baseline;
  MorphFidelityComparisonProfile _comparisonProfile =
      MorphFidelityComparisonProfile.quickNotesBaseline;

  // ── Parameter Experiment Controls (Section 15) ──────────────────────
  QuickNotesMorphAnchorOption _selectedAnchor =
      QuickNotesMorphAnchorOption.center;
  double _stretch = 0.75;
  double _leadBounce = 0.10;
  int _followDelayMs = 40;
  double _contentBlur = 8.0;
  double _contentFollow = 1.0;
  double _contentSlide = 0.0;

  // ── Target Card Corner Radius (Clamped to half short-side for Circle)
  static const double kTargetCardCornerRadius = 28.0;

  // ── Diagnostic Overlays (Sections 16 & 17) ──────────────────────────
  bool _showDebugOverlay = true;
  bool _showMotionPath = true;
  final List<Offset> _recordedCenterPath = <Offset>[];
  final List<Offset> _recordedAnchorPath = <Offset>[];
  double _maxCenterDeviationPx = 0.0;

  // ── Ticker Interval Observation (Section 21) ────────────────────────
  final List<double> _recentFrameDeltasMs = <double>[];
  double _worstFrameDeltaMs = 0.0;

  // ── Physical Device Checklists (Sections 14, 19, 20) ────────────────
  final Map<String, MorphFidelityCheckStatus> _checklistStatus =
      <String, MorphFidelityCheckStatus>{};
  final Map<String, TextEditingController> _failNoteControllers =
      <String, TextEditingController>{};

  Size _stageFieldSize = const Size(340, 290);

  // ── Authoritative Destination Layout Keys (Section 4 & 5) ──────────
  final GlobalKey _stageStackKey =
      GlobalKey(debugLabel: 'fidelity_preview_stack_key');
  final Map<MorphFidelityStateId, GlobalKey> _targetSlotKeys =
      <MorphFidelityStateId, GlobalKey>{
    MorphFidelityStateId.circle:
        GlobalKey(debugLabel: 'fidelity_slot_circle'),
    MorphFidelityStateId.square:
        GlobalKey(debugLabel: 'fidelity_slot_square'),
    MorphFidelityStateId.alternate:
        GlobalKey(debugLabel: 'fidelity_slot_alternate'),
  };

  @override
  void initState() {
    super.initState();
    for (final MorphFidelityChecklistItem item
        in <MorphFidelityChecklistItem>[
      ...kFidelityPhysicalSequenceTests,
      ...kFidelityVisualComparisonItems,
    ]) {
      _checklistStatus[item.id] = MorphFidelityCheckStatus.notTested;
      _failNoteControllers[item.id] = TextEditingController();
    }
    _ticker = createTicker(_onTick);
    final Rect initialRect = _resolveAuthoritativeStateRect(
      MorphFidelityStateId.circle,
    );
    _geometryController.seedInitialRect(
      initialRect,
      anchor: _selectedAnchor.alignment,
    );
    _contentController.seedInitialState(
      stateId: MorphFidelityStateId.circle.toPhase8CStateId(),
      stateRect: initialRect,
      stiffness: 195.0,
    );
    _recordedCenterPath
      ..clear()
      ..add(initialRect.center);
    _recordedAnchorPath
      ..clear()
      ..add(_selectedAnchor.alignment.withinRect(initialRect));
  }

  @override
  void dispose() {
    _cancelTimers();
    _ticker.dispose();
    for (final TextEditingController controller
        in _failNoteControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _cancelTimers() {
    for (final Timer timer in _sequenceTimers) {
      timer.cancel();
    }
    _sequenceTimers.clear();
  }

  /// Resolves the spatial placement alignment for [state].
  ///
  /// In native `liquid_glass_easy 4.3.1`, all states are placed using `widget.alignment`:
  /// `Rect _place(Size s) => widget.alignment.inscribe(s, Offset.zero & _field);`
  ///
  /// The selected anchor represents which edge or corner holds while the
  /// surface changes size, so all states share [_selectedAnchor.alignment].
  Alignment _placementAlignmentForState(MorphFidelityStateId state) {
    return _selectedAnchor.alignment;
  }

  /// Resolves the authoritative geometry for [state] directly from Flutter's
  /// layout system (via the mounted [RenderBox] of that state's layout slot
  /// transformed into the preview Stack's local coordinate space).
  ///
  /// Falls back to [_computeLayoutSlotRect] prior to the first frame render
  /// or in headless test harnesses.
  Rect _resolveAuthoritativeStateRect(MorphFidelityStateId state) {
    final Rect computed = _computeLayoutSlotRect(state, _stageFieldSize);
    final GlobalKey? key = _targetSlotKeys[state];
    final BuildContext? targetCtx = key?.currentContext;
    final BuildContext? stackCtx = _stageStackKey.currentContext;
    if (targetCtx != null && stackCtx != null) {
      final RenderBox? targetBox = targetCtx.findRenderObject() as RenderBox?;
      final RenderBox? stackBox = stackCtx.findRenderObject() as RenderBox?;
      if (targetBox != null &&
          stackBox != null &&
          targetBox.hasSize &&
          stackBox.hasSize) {
        final Offset localTopLeft =
            targetBox.localToGlobal(Offset.zero, ancestor: stackBox);
        final Rect measured = localTopLeft & targetBox.size;
        // Verify measured layout rect matches current placement (handles immediate taps)
        if ((measured.center - computed.center).distance < 2.0) {
          return measured;
        }
      }
    }
    return computed;
  }

  /// Evaluates the exact mathematical layout bounds of the destination slot
  /// inside the stage's standard padding (EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0)).
  Rect _computeLayoutSlotRect(MorphFidelityStateId state, Size field) {
    const EdgeInsets stagePadding =
        EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0);
    final Rect stageBounds = Rect.fromLTWH(
      stagePadding.left,
      stagePadding.top,
      math.max(0.0, field.width - stagePadding.horizontal),
      math.max(0.0, field.height - stagePadding.vertical),
    );
    return _placementAlignmentForState(state).inscribe(state.size, stageBounds);
  }

  QuickNotesMorphGeometryConfig _buildEffectiveGeometryConfig(
    MorphFidelityStateId targetState,
  ) {
    return _choreographyAdapter.resolveConfig(
      variant: _choreographyVariant,
      baseStiffness: 195.0,
      baseDamping: 19.5,
      userStretch: _stretch,
      userLeadBounce: _leadBounce,
      userFollowDelayMs: _followDelayMs,
      selectedAnchor: _selectedAnchor.alignment,
      placementAlignment: _placementAlignmentForState(targetState),
      spatialMode: _spatialMode,
    );
  }

  QuickNotesMorphContentConfig _buildContentConfig() {
    return QuickNotesMorphContentConfig(
      contentOutEnd: 0.40,
      contentInStart: 0.30,
      contentInEnd: 0.80,
      newScaleFrom: 0.90,
      oldScaleTo: 0.92,
      contentBlur: _contentBlur,
      contentFollow: _contentFollow,
      contentSlide: _contentSlide,
      anchor: _selectedAnchor.alignment,
    );
  }

  double _effectiveCornerRadiusForRect(Rect rect) {
    final double halfShortSide =
        math.max(0.0, math.min(rect.width, rect.height) * 0.5);
    return math.min(kTargetCardCornerRadius, halfShortSide);
  }

  void _wakeTicker() {
    if (!_ticker.isActive) {
      _lastTickElapsed = Duration.zero;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    final double rawDtSeconds =
        (elapsed - _lastTickElapsed).inMicroseconds / 1e6;
    _lastTickElapsed = elapsed;
    if (rawDtSeconds <= 0.0) return;

    final double dtMs = rawDtSeconds * 1000.0;
    if (dtMs < 250.0) {
      _recentFrameDeltasMs.add(dtMs);
      if (_recentFrameDeltasMs.length > 60) {
        _recentFrameDeltasMs.removeAt(0);
      }
      if (dtMs > _worstFrameDeltaMs) {
        _worstFrameDeltaMs = dtMs;
      }
    }

    final QuickNotesMorphGeometryConfig geomConfig =
        _buildEffectiveGeometryConfig(_targetState);
    final QuickNotesMorphContentConfig contentConfig = _buildContentConfig();

    final bool geomActive = _choreographyAdapter.step(rawDtSeconds, geomConfig);
    final bool contentActive =
        _contentController.step(rawDtSeconds, contentConfig);

    final Rect liveRect = _geometryController.currentRect;
    final Offset liveCenter = liveRect.center;
    if (_recordedCenterPath.isEmpty ||
        (_recordedCenterPath.last - liveCenter).distance > 0.5) {
      _recordedCenterPath.add(liveCenter);
    }
    final Offset liveAnchor =
        _geometryController.anchor.withinRect(liveRect);
    if (_recordedAnchorPath.isEmpty ||
        (_recordedAnchorPath.last - liveAnchor).distance > 0.5) {
      _recordedAnchorPath.add(liveAnchor);
    }
    final double dev = _pointToSegmentDistance(
      liveCenter,
      _geometryController.originRect.center,
      _geometryController.targetRect.center,
    );
    if (dev > _maxCenterDeviationPx) {
      _maxCenterDeviationPx = dev;
    }

    if (!geomActive && !contentActive) {
      _ticker.stop();
    }
    if (mounted) {
      setState(() {});
    }
  }

  static double _pointToSegmentDistance(Offset p, Offset a, Offset b) {
    final Offset ab = b - a;
    final double lenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lenSq < 1e-4) return (p - a).distance;
    final double t = ((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / lenSq;
    final Offset proj = Offset(a.dx + t * ab.dx, a.dy + t * ab.dy);
    return (p - proj).distance;
  }

  void _triggerMorphTo(
    MorphFidelityStateId nextState, {
    bool cancelScheduled = true,
  }) {
    if (cancelScheduled) {
      _cancelTimers();
    }
    final Rect currentLiveRect = _geometryController.currentRect;
    final Rect toRect = _resolveAuthoritativeStateRect(nextState);
    final QuickNotesMorphGeometryConfig geomConfig =
        _buildEffectiveGeometryConfig(nextState);
    final QuickNotesMorphContentConfig contentConfig = _buildContentConfig();

    setState(() {
      _currentState = nextState;
      _targetState = nextState;
      _recordedCenterPath
        ..clear()
        ..add(currentLiveRect.center);
      _recordedAnchorPath
        ..clear()
        ..add(geomConfig.anchor.withinRect(currentLiveRect));
      _maxCenterDeviationPx = 0.0;

      _contentController.transitionToState(
        targetState: nextState.toPhase8CStateId(),
        targetRect: toRect,
        liveGlassRect: currentLiveRect,
        config: contentConfig,
        stiffness: geomConfig.stiffness,
      );

      _choreographyAdapter.startTransition(
        toRect,
        variant: _choreographyVariant,
        config: geomConfig,
      );
    });
    _wakeTicker();
  }

  void _snapToState(MorphFidelityStateId state) {
    _cancelTimers();
    _ticker.stop();
    final Rect rect = _resolveAuthoritativeStateRect(state);
    final QuickNotesMorphGeometryConfig geomConfig =
        _buildEffectiveGeometryConfig(state);
    setState(() {
      _currentState = state;
      _targetState = state;
      _geometryController.seedInitialRect(rect, anchor: geomConfig.anchor);
      _contentController.seedInitialState(
        stateId: state.toPhase8CStateId(),
        stateRect: rect,
        stiffness: geomConfig.stiffness,
      );
      _recordedCenterPath
        ..clear()
        ..add(rect.center);
      _recordedAnchorPath
        ..clear()
        ..add(geomConfig.anchor.withinRect(rect));
      _maxCenterDeviationPx = 0.0;
    });
  }

  // ── Reference Mode Handlers (Section 7) ─────────────────────────────

  void _runModeACircleToSquare({MorphFidelitySpatialMode? overrideSpatial}) {
    _cancelTimers();
    if (overrideSpatial != null) {
      _spatialMode = overrideSpatial;
    }
    _lastReferenceMode = MorphFidelityReferenceMode.modeACircleToSquare;
    if (_targetState != MorphFidelityStateId.circle ||
        _choreographyAdapter.isAnimating) {
      _snapToState(MorphFidelityStateId.circle);
    }
    _triggerMorphTo(MorphFidelityStateId.square);
  }

  void _runModeBSquareToCircle() {
    _cancelTimers();
    _lastReferenceMode = MorphFidelityReferenceMode.modeBSquareToCircle;
    if (_targetState != MorphFidelityStateId.square ||
        _choreographyAdapter.isAnimating) {
      _snapToState(MorphFidelityStateId.square);
    }
    _triggerMorphTo(MorphFidelityStateId.circle);
  }

  void _runModeCCircleSquareCircle() {
    _cancelTimers();
    _lastReferenceMode = MorphFidelityReferenceMode.modeCCircleSquareCircle;
    _snapToState(MorphFidelityStateId.circle);
    _triggerMorphTo(MorphFidelityStateId.square, cancelScheduled: false);
    _sequenceTimers.add(
      Timer(const Duration(milliseconds: 520), () {
        if (!mounted) return;
        _triggerMorphTo(MorphFidelityStateId.circle, cancelScheduled: false);
      }),
    );
  }

  void _runModeDCircleToSquareWithPosition() {
    _cancelTimers();
    _spatialMode = MorphFidelitySpatialMode.withPosition;
    _lastReferenceMode =
        MorphFidelityReferenceMode.modeDCircleToSquareWithPosition;
    _snapToState(MorphFidelityStateId.circle);
    _triggerMorphTo(MorphFidelityStateId.square);
  }

  void _runModeEInterrupted() {
    _cancelTimers();
    _lastReferenceMode = MorphFidelityReferenceMode.modeEInterrupted;
    _snapToState(MorphFidelityStateId.circle);
    _triggerMorphTo(MorphFidelityStateId.square, cancelScheduled: false);
    _sequenceTimers.add(
      Timer(const Duration(milliseconds: 150), () {
        if (!mounted) return;
        _triggerMorphTo(MorphFidelityStateId.circle, cancelScheduled: false);
      }),
    );
  }

  void _runModeFRetarget() {
    _cancelTimers();
    _lastReferenceMode = MorphFidelityReferenceMode.modeFRetarget;
    _snapToState(MorphFidelityStateId.circle);
    _triggerMorphTo(MorphFidelityStateId.square, cancelScheduled: false);
    _sequenceTimers.add(
      Timer(const Duration(milliseconds: 160), () {
        if (!mounted) return;
        _triggerMorphTo(MorphFidelityStateId.alternate, cancelScheduled: false);
      }),
    );
  }

  // ── Physical Device 12-Step Sequence Runner (Section 19) ────────────

  void _runPhysicalTestStep(int stepNumber) {
    switch (stepNumber) {
      case 1:
        _runModeACircleToSquare();
      case 2:
        _runModeBSquareToCircle();
      case 3:
        _runModeCCircleSquareCircle();
      case 4:
        _selectAnchorAndRunCircleToSquare(QuickNotesMorphAnchorOption.center);
      case 5:
        _selectAnchorAndRunCircleToSquare(QuickNotesMorphAnchorOption.topLeft);
      case 6:
        _selectAnchorAndRunCircleToSquare(QuickNotesMorphAnchorOption.topRight);
      case 7:
        _selectAnchorAndRunCircleToSquare(
          QuickNotesMorphAnchorOption.bottomLeft,
        );
      case 8:
        _selectAnchorAndRunCircleToSquare(
          QuickNotesMorphAnchorOption.bottomRight,
        );
      case 9:
        _runModeEInterrupted();
      case 10:
        _runModeFRetarget();
      case 11:
        _runRapidCircleSquareSequence();
      case 12:
        _toggleBaselineVsRefinedAndRun();
    }
  }

  void _selectAnchorAndRunCircleToSquare(QuickNotesMorphAnchorOption anchor) {
    _cancelTimers();
    _selectedAnchor = anchor;
    _snapToState(MorphFidelityStateId.circle);
    _triggerMorphTo(MorphFidelityStateId.square);
  }

  void _runRapidCircleSquareSequence() {
    _cancelTimers();
    _snapToState(MorphFidelityStateId.circle);
    _triggerMorphTo(MorphFidelityStateId.square, cancelScheduled: false);
    const List<int> delaysMs = <int>[140, 280, 420, 560];
    const List<MorphFidelityStateId> targets = <MorphFidelityStateId>[
      MorphFidelityStateId.circle,
      MorphFidelityStateId.square,
      MorphFidelityStateId.circle,
      MorphFidelityStateId.square,
    ];
    for (int i = 0; i < delaysMs.length; i++) {
      final MorphFidelityStateId next = targets[i];
      _sequenceTimers.add(
        Timer(Duration(milliseconds: delaysMs[i]), () {
          if (!mounted) return;
          _triggerMorphTo(next, cancelScheduled: false);
        }),
      );
    }
  }

  void _toggleBaselineVsRefinedAndRun() {
    _cancelTimers();
    setState(() {
      _spatialMode = MorphFidelitySpatialMode.withPosition;
      if (_choreographyVariant == MorphFidelityChoreographyVariant.baseline) {
        _choreographyVariant = MorphFidelityChoreographyVariant.balanced;
        _comparisonProfile = MorphFidelityComparisonProfile.quickNotesRefined;
      } else {
        _choreographyVariant = MorphFidelityChoreographyVariant.baseline;
        _comparisonProfile = MorphFidelityComparisonProfile.quickNotesBaseline;
      }
    });
    _snapToState(MorphFidelityStateId.circle);
    _triggerMorphTo(MorphFidelityStateId.square);
  }

  void _applyComparisonProfile(MorphFidelityComparisonProfile profile) {
    _cancelTimers();
    setState(() {
      _comparisonProfile = profile;
      switch (profile) {
        case MorphFidelityComparisonProfile.nativeReference:
          break;
        case MorphFidelityComparisonProfile.quickNotesBaseline:
          _choreographyVariant = MorphFidelityChoreographyVariant.baseline;
          _stretch = 0.75;
          _leadBounce = 0.10;
          _followDelayMs = 40;
        case MorphFidelityComparisonProfile.quickNotesRefined:
          _choreographyVariant =
              _spatialMode == MorphFidelitySpatialMode.withPosition
                  ? MorphFidelityChoreographyVariant.balanced
                  : MorphFidelityChoreographyVariant.anchorLocked;
          _stretch = 0.25;
          _leadBounce = 0.0;
          _followDelayMs = 0;
      }
    });
  }

  void _handleReset() {
    _cancelTimers();
    _ticker.stop();
    setState(() {
      _currentState = MorphFidelityStateId.circle;
      _targetState = MorphFidelityStateId.circle;
      _lastReferenceMode = MorphFidelityReferenceMode.modeACircleToSquare;
      _spatialMode = MorphFidelitySpatialMode.withPosition;
      _choreographyVariant = MorphFidelityChoreographyVariant.baseline;
      _comparisonProfile = MorphFidelityComparisonProfile.quickNotesBaseline;
      _selectedAnchor = QuickNotesMorphAnchorOption.center;
      _stretch = 0.75;
      _leadBounce = 0.10;
      _followDelayMs = 40;
      _contentBlur = 8.0;
      _contentFollow = 1.0;
      _contentSlide = 0.0;
      _recentFrameDeltasMs.clear();
      _worstFrameDeltaMs = 0.0;

      final Rect initialRect = _resolveAuthoritativeStateRect(
        MorphFidelityStateId.circle,
      );
      _geometryController.seedInitialRect(
        initialRect,
        anchor: _selectedAnchor.alignment,
      );
      _contentController.seedInitialState(
        stateId: MorphFidelityStateId.circle.toPhase8CStateId(),
        stateRect: initialRect,
        stiffness: 195.0,
      );
      _recordedCenterPath
        ..clear()
        ..add(initialRect.center);
      _recordedAnchorPath
        ..clear()
        ..add(_selectedAnchor.alignment.withinRect(initialRect));
      _maxCenterDeviationPx = 0.0;
    });
  }

  double get _averageFrameDeltaMs {
    if (_recentFrameDeltasMs.isEmpty) return 0.0;
    final double sum = _recentFrameDeltasMs.fold<double>(
      0.0,
      (double a, double b) => a + b,
    );
    return sum / _recentFrameDeltasMs.length;
  }

  String _readPlatformLabel() {
    if (kIsWeb) return 'Web';
    try {
      return Platform.operatingSystem.toUpperCase();
    } catch (_) {
      return 'UNKNOWN';
    }
  }

  @override
  Widget build(BuildContext context) {
    final Rect liveRect = _geometryController.currentRect;
    final QuickNotesMorphContentConfig contentConfig = _buildContentConfig();
    final double effectiveRadius = _effectiveCornerRadiusForRect(liveRect);

    return Scaffold(
      key: const ValueKey<String>('morph_fidelity_lab_screen'),
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Morph Fidelity — Circle → Square',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: <Widget>[
          IconButton(
            key: const ValueKey<String>('fidelity_reset_icon_btn'),
            tooltip: 'Reset Lab',
            onPressed: _handleReset,
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F172A)),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double availableHeight = constraints.maxHeight;
            // Provide a fixed, responsive stage height:
            // - Leaves at least 50% for scrollable controls on typical phones (700-950px height).
            // - Clamps between 200px and 290px (or scaled down if viewport is severely constrained).
            final double stageHeight = (availableHeight < 450.0)
                ? math.max(140.0, availableHeight * 0.40)
                : (availableHeight * 0.35).clamp(200.0, 290.0);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // ── REGION A: FIXED MORPH VIEWER ──────────────────────────────
                // Remains continuously visible and pinned while controls scroll below
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
                  child: _buildPreviewStageCard(
                    liveRect,
                    effectiveRadius,
                    contentConfig,
                    stageHeight: stageHeight,
                  ),
                ),

                // ── REGION B: SCROLLABLE CONTROL PANEL ────────────────────────
                // All controls scroll independently in this dedicated region
                Expanded(
                  child: ListView(
                    key: const ValueKey<String>('morph_fidelity_lab_scroll'),
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 32),
                    children: <Widget>[
                      _buildOverlayAndSpatialTogglesCard(
                        liveRect,
                        effectiveRadius,
                      ),
                      const SizedBox(height: 12),
                      _buildReferenceModesCard(),
                      const SizedBox(height: 12),
                      _buildChoreographyVariantsCard(),
                      const SizedBox(height: 12),
                      _buildNativeComparisonCard(),
                      const SizedBox(height: 12),
                      _buildParameterExperimentsCard(),
                      const SizedBox(height: 12),
                      _buildShapeInvestigationCard(liveRect, effectiveRadius),
                      const SizedBox(height: 12),
                      _buildPhysicalTestSequenceCard(),
                      const SizedBox(height: 12),
                      _buildVisualComparisonChecklistCard(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── 1. Central Circle → Square Preview Stage ────────────────────────

  Widget _buildPreviewStageCard(
    Rect liveRect,
    double effectiveRadius,
    QuickNotesMorphContentConfig contentConfig, {
    double stageHeight = 280.0,
  }) {
    final bool isRunning = _ticker.isActive;
    return Container(
      key: const ValueKey<String>('fidelity_preview_card'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  'STATE: ${_currentState.fullLabel} • ${_choreographyVariant.label.toUpperCase()} • ${_lastReferenceMode.buttonLabel}',
                  key: const ValueKey<String>('fidelity_active_state_banner'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  isRunning ? 'ANIMATION: RUNNING' : 'ANIMATION: IDLE',
                  key: const ValueKey<String>('fidelity_anim_status_badge'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isRunning
                        ? const Color(0xFFD97706)
                        : const Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: stageHeight,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final Size fieldSize = Size(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                if (fieldSize != _stageFieldSize &&
                    fieldSize.width > 0 &&
                    fieldSize.height > 0) {
                  final Size prev = _stageFieldSize;
                  _stageFieldSize = fieldSize;
                  if (!_ticker.isActive && prev != fieldSize) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted || _ticker.isActive) return;
                      final Rect updated = _resolveAuthoritativeStateRect(
                        _currentState,
                      );
                      _geometryController.seedInitialRect(
                        updated,
                        anchor: _geometryController.anchor,
                      );
                      setState(() {});
                    });
                  }
                }

                final Rect clampedRect = Rect.fromLTWH(
                  liveRect.left,
                  liveRect.top,
                  math.max(1.0, liveRect.width),
                  math.max(1.0, liveRect.height),
                );

                final QuickNotesMorphContentSnapshot snapshot =
                    _contentController.currentSnapshot(
                  currentGlassRect: clampedRect,
                  config: contentConfig,
                );

                return KeyedSubtree(
                  key: _stageStackKey,
                  child: Stack(
                    key: const ValueKey<String>('fidelity_preview_stack'),
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      ..._buildStageBackdropDecorations(),

                      // ── Authoritative Destination Layout Slots ──────────
                      // These real widgets are laid out by Flutter's layout engine.
                      // Their RenderBox instances establish the true, authoritative layout geometry.
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14.0,
                              vertical: 10.0,
                            ),
                            child: Stack(
                              children: <Widget>[
                                for (final MorphFidelityStateId state
                                    in MorphFidelityStateId.values)
                                  Align(
                                    alignment:
                                        _placementAlignmentForState(state),
                                    child: KeyedSubtree(
                                      key: _targetSlotKeys[state],
                                      child: SizedBox(
                                        key: ValueKey<String>(
                                          'fidelity_slot_${state.name}',
                                        ),
                                        width: state.size.width,
                                        height: state.size.height,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      if (_showDebugOverlay || _showMotionPath)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              key: const ValueKey<String>(
                                'fidelity_debug_trajectory_canvas',
                              ),
                              painter: _MorphFidelityDiagnosticPainter(
                                showDebugOverlay: _showDebugOverlay,
                                showMotionPath: _showMotionPath,
                                originRect: _geometryController.originRect,
                                currentRect: clampedRect,
                                targetRect: _geometryController.targetRect,
                                activeAnchor: _selectedAnchor.alignment,
                                centerPath: List<Offset>.unmodifiable(
                                  _recordedCenterPath,
                                ),
                                anchorPath: List<Offset>.unmodifiable(
                                  _recordedAnchorPath,
                                ),
                              ),
                            ),
                          ),
                        ),

                      Positioned(
                        key: const ValueKey<String>(
                          'fidelity_glass_positioned',
                        ),
                        left: clampedRect.left,
                        top: clampedRect.top,
                        width: clampedRect.width,
                        height: clampedRect.height,
                        child: BottomBarGlassSurface(
                          key: const ValueKey<String>(
                            'fidelity_quick_notes_glass_surface',
                          ),
                          width: clampedRect.width,
                          height: clampedRect.height,
                          borderRadius: BorderRadius.circular(effectiveRadius),
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(effectiveRadius),
                            child: Stack(
                              fit: StackFit.expand,
                              clipBehavior: Clip.hardEdge,
                              children: <Widget>[
                                if (snapshot.outgoing != null &&
                                    snapshot.outgoing!.opacity > 0.001)
                                  _buildEvaluatedLayer(
                                    snapshot.outgoing!,
                                    clampedRect,
                                    'outgoing',
                                  ),
                                if (snapshot.secondaryOutgoing != null &&
                                    snapshot.secondaryOutgoing!.opacity > 0.001)
                                  _buildEvaluatedLayer(
                                    snapshot.secondaryOutgoing!,
                                    clampedRect,
                                    'secondary',
                                  ),
                                _buildEvaluatedLayer(
                                  snapshot.incoming,
                                  clampedRect,
                                  'incoming',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
            child: Builder(
              builder: (BuildContext context) {
                final Rect destTarget =
                    _resolveAuthoritativeStateRect(_targetState);
                final double dL = (liveRect.left - destTarget.left).abs();
                final double dT = (liveRect.top - destTarget.top).abs();
                final double dR = (liveRect.right - destTarget.right).abs();
                final double dB = (liveRect.bottom - destTarget.bottom).abs();
                final double dW = (liveRect.width - destTarget.width).abs();
                final double dH = (liveRect.height - destTarget.height).abs();
                final double maxDelta = math.max(
                  math.max(dL, dT),
                  math.max(math.max(dR, dB), math.max(dW, dH)),
                );
                final bool isSettledExact = !isRunning && maxDelta < 0.05;

                return Text(
                  'Morph: (${liveRect.left.toStringAsFixed(1)}, ${liveRect.top.toStringAsFixed(1)}) '
                  '${liveRect.width.toStringAsFixed(1)}×${liveRect.height.toStringAsFixed(1)} • '
                  'Target: (${destTarget.left.toStringAsFixed(1)}, ${destTarget.top.toStringAsFixed(1)}) • '
                  '${isSettledExact ? "SETTLED: EXACT" : isRunning ? "MOVING" : "Δmax: ${maxDelta.toStringAsFixed(2)}px"} • '
                  'Radius: ${effectiveRadius.toStringAsFixed(1)}px • '
                  'Max path bow: ${_maxCenterDeviationPx.toStringAsFixed(1)}px',
                  key: const ValueKey<String>('fidelity_live_rect_readout'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: Color(0xFF475569),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStageBackdropDecorations() {
    return const <Widget>[];
  }

  Widget _buildEvaluatedLayer(
    QuickNotesEvaluatedContentLayer layer,
    Rect liveGlassRect,
    String roleKey,
  ) {
    final MorphFidelityStateId state = layer.stateId.toFidelityStateId();
    final Size naturalSize = state.size;
    Widget content = SizedBox(
      width: naturalSize.width,
      height: naturalSize.height,
      child: _buildStateVisualContent(state),
    );

    if (layer.blurSigma > 0.2) {
      content = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: layer.blurSigma,
          sigmaY: layer.blurSigma,
        ),
        child: content,
      );
    }

    return Positioned(
      key: ValueKey<String>('fidelity_content_${roleKey}_${state.name}'),
      left: layer.localOffset.dx,
      top: layer.localOffset.dy,
      width: naturalSize.width,
      height: naturalSize.height,
      child: Opacity(
        opacity: layer.opacity.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: layer.scale,
          alignment: layer.alignment,
          child: content,
        ),
      ),
    );
  }

  Widget _buildStateVisualContent(MorphFidelityStateId state) {
    switch (state) {
      case MorphFidelityStateId.circle:
        return Center(
          key: const ValueKey<String>('fidelity_state_circle_content'),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.24),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.more_horiz_rounded,
              size: 22,
              color: Color(0xFF0F172A),
            ),
          ),
        );
      case MorphFidelityStateId.square:
        return Padding(
          key: const ValueKey<String>('fidelity_state_square_content'),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Row(
                children: <Widget>[
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 18,
                    color: Color(0xFF0F172A),
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Rounded Square',
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
              const Text(
                '224 × 184 Card • Radius 28px\nQuick Notes Glass Surface',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: <Widget>[
                  _buildMiniPillBadge('Share'),
                  _buildMiniPillBadge('Pin'),
                  _buildMiniPillBadge('Duplicate'),
                ],
              ),
            ],
          ),
        );
      case MorphFidelityStateId.alternate:
        return const Padding(
          key: ValueKey<String>('fidelity_state_alt_content'),
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'Retarget Card (168×112)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Mid-flight retarget state',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildMiniPillBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F172A),
        ),
      ),
    );
  }

  // ── 2. Debug Overlay, Motion Path & Direct State Switcher ───────────

  Widget _buildOverlayAndSpatialTogglesCard(
    Rect liveRect,
    double effectiveRadius,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'DIAGNOSTIC VISUALIZATION & SPATIAL PLACEMENT (SECTIONS 16 & 17)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilterChip(
                key: const ValueKey<String>('fidelity_debug_overlay_toggle'),
                label: const Text('Debug Overlay (Bounds / Centers / Anchor)'),
                selected: _showDebugOverlay,
                onSelected: (bool v) => setState(() => _showDebugOverlay = v),
              ),
              FilterChip(
                key: const ValueKey<String>('fidelity_motion_path_toggle'),
                label: const Text('Show Motion Path (Trajectory)'),
                selected: _showMotionPath,
                onSelected: (bool v) => setState(() => _showMotionPath = v),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: MorphFidelitySpatialMode.values.map(
              (MorphFidelitySpatialMode mode) {
                return ChoiceChip(
                  key: ValueKey<String>('fidelity_spatial_${mode.name}'),
                  label: Text(mode.label),
                  selected: _spatialMode == mode,
                  onSelected: (_) {
                    setState(() {
                      _spatialMode = mode;
                    });
                    _snapToState(_currentState);
                  },
                );
              },
            ).toList(),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                key: const ValueKey<String>('fidelity_snap_circle_btn'),
                onPressed: () => _snapToState(MorphFidelityStateId.circle),
                icon: const Icon(Icons.circle_outlined, size: 16),
                label: const Text('Snap Circle (56×56)'),
              ),
              OutlinedButton.icon(
                key: const ValueKey<String>('fidelity_snap_square_btn'),
                onPressed: () => _snapToState(MorphFidelityStateId.square),
                icon: const Icon(Icons.crop_square_rounded, size: 16),
                label: const Text('Snap Square (224×184)'),
              ),
              OutlinedButton.icon(
                key: const ValueKey<String>('fidelity_interrupt_now_btn'),
                onPressed: () {
                  final MorphFidelityStateId reverseTarget =
                      _targetState == MorphFidelityStateId.square
                          ? MorphFidelityStateId.circle
                          : MorphFidelityStateId.square;
                  _triggerMorphTo(reverseTarget);
                },
                icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                label: const Text('Reverse Mid-Flight'),
              ),
              OutlinedButton.icon(
                key: const ValueKey<String>('fidelity_retarget_alt_now_btn'),
                onPressed: () =>
                    _triggerMorphTo(MorphFidelityStateId.alternate),
                icon: const Icon(Icons.alt_route_rounded, size: 16),
                label: const Text('Retarget Alt (168×112)'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 3. Primary Reference Modes (Section 7) ──────────────────────────

  Widget _buildReferenceModesCard() {
    return Container(
      key: const ValueKey<String>('fidelity_reference_modes_card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            'PRIMARY REFERENCE MODES (SECTION 7)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _buildLargeModeButton(
                keyName: 'fidelity_mode_a_circle_to_square',
                label: 'Circle → Square (Mode A)',
                color: const Color(0xFF0284C7),
                onPressed: _runModeACircleToSquare,
              ),
              _buildLargeModeButton(
                keyName: 'fidelity_mode_b_square_to_circle',
                label: 'Square → Circle (Mode B)',
                color: const Color(0xFF0D9488),
                onPressed: _runModeBSquareToCircle,
              ),
              _buildLargeModeButton(
                keyName: 'fidelity_mode_c_round_trip',
                label: 'Circle → Square → Circle (Mode C)',
                color: const Color(0xFF4F46E5),
                onPressed: _runModeCCircleSquareCircle,
              ),
              _buildLargeModeButton(
                keyName: 'fidelity_mode_d_with_position',
                label: 'Circle → Square + Position (Mode D)',
                color: const Color(0xFF7C3AED),
                onPressed: _runModeDCircleToSquareWithPosition,
              ),
              _buildLargeModeButton(
                keyName: 'fidelity_mode_e_interrupted',
                label: 'Interrupted C → S → C (Mode E)',
                color: const Color(0xFFD97706),
                onPressed: _runModeEInterrupted,
              ),
              _buildLargeModeButton(
                keyName: 'fidelity_mode_f_retarget',
                label: 'Retarget C → S → Alt (Mode F)',
                color: const Color(0xFFBE123C),
                onPressed: _runModeFRetarget,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLargeModeButton({
    required String keyName,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 46,
      child: ElevatedButton(
        key: ValueKey<String>(keyName),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  // ── 4. Position Choreography Refinement Variants (Section 12) ───────

  Widget _buildChoreographyVariantsCard() {
    return Container(
      key: const ValueKey<String>('fidelity_choreography_variants_card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'POSITION REFINEMENT VARIANTS (SECTION 12)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: MorphFidelityChoreographyVariant.values.map(
              (MorphFidelityChoreographyVariant variant) {
                return ChoiceChip(
                  key: ValueKey<String>('fidelity_variant_${variant.name}'),
                  label: Text(
                    variant.label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  selected: _choreographyVariant == variant,
                  onSelected: (_) {
                    setState(() {
                      _choreographyVariant = variant;
                    });
                  },
                );
              },
            ).toList(),
          ),
          const SizedBox(height: 8),
          Text(
            _choreographyVariant.description,
            key: const ValueKey<String>('fidelity_variant_description'),
            style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
          ),
        ],
      ),
    );
  }

  // ── 5. Native Reference Comparison Section (Section 13) ─────────────

  Widget _buildNativeComparisonCard() {
    return Container(
      key: const ValueKey<String>('fidelity_native_comparison_card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'NATIVE REFERENCE COMPARISON (SECTION 13)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: MorphFidelityComparisonProfile.values.map(
              (MorphFidelityComparisonProfile profile) {
                return ChoiceChip(
                  key: ValueKey<String>('fidelity_comp_${profile.name}'),
                  label: Text(
                    profile.label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  selected: _comparisonProfile == profile,
                  onSelected: (_) => _applyComparisonProfile(profile),
                );
              },
            ).toList(),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _comparisonProfile.summary,
                  key: const ValueKey<String>('fidelity_comp_summary'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '• GEOMETRY: 4D spring (ax, ay, w, h). In native fluid mode, anchor defaults to Center so _dst leaps away from _src to form a two-blob neck. In single-surface mode, uncoupled lead/hold causes corner detachment or bowed paths unless Balanced or Anchor-Locked.\n'
                  '• SHAPE: No ShapeBorder.lerp. Radius is clamped each frame via min(cornerRadius, min(w,h)/2). At 56×56 with r=28, surface is a true circle; at 224×184 with r=28, it is a rounded square.\n'
                  '• GLASS RENDERING: Quick Notes uses BottomBarGlassSurface (single surface). Native fluid uses two-blob LiquidGlassBlender smooth-union waist.\n'
                  '• CONTENT TRANSITION: Outgoing [0..0.40] easeIn + Incoming [0.30..0.80] easeOut with scale & blur.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 6. Parameter Experiments (Section 15) ───────────────────────────

  Widget _buildParameterExperimentsCard() {
    return Container(
      key: const ValueKey<String>('fidelity_parameter_experiments_card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'PARAMETER EXPERIMENTS (SECTION 15)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'anchor',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: QuickNotesMorphAnchorOption.values.map(
              (QuickNotesMorphAnchorOption option) {
                return ChoiceChip(
                  key: ValueKey<String>('fidelity_anchor_${option.name}'),
                  label: Text(option.label),
                  selected: _selectedAnchor == option,
                  onSelected: (_) {
                    setState(() {
                      _selectedAnchor = option;
                      _geometryController.rebaseAnchor(option.alignment);
                    });
                    if (!_ticker.isActive) {
                      _snapToState(_currentState);
                    }
                  },
                );
              },
            ).toList(),
          ),
          const SizedBox(height: 8),
          _buildChipRow<double>(
            title: 'stretch',
            keyPrefix: 'fidelity_stretch',
            values: const <double>[0.0, 0.25, 0.5, 0.75, 1.0],
            selected: _stretch,
            format: (double v) => v == 0.5
                ? '0.5'
                : (v == 0.0 || v == 1.0
                    ? v.toStringAsFixed(1)
                    : v.toStringAsFixed(2)),
            onSelected: (double v) => setState(() => _stretch = v),
          ),
          _buildChipRow<double>(
            title: 'leadBounce',
            keyPrefix: 'fidelity_leadBounce',
            values: const <double>[0.0, 0.10, 0.25],
            selected: _leadBounce,
            format: (double v) => v == 0.0 ? '0' : v.toStringAsFixed(2),
            onSelected: (double v) => setState(() => _leadBounce = v),
          ),
          _buildChipRow<int>(
            title: 'followDelay',
            keyPrefix: 'fidelity_followDelay',
            values: const <int>[0, 40, 100, 150],
            selected: _followDelayMs,
            format: (int v) => '$v ms',
            onSelected: (int v) => setState(() => _followDelayMs = v),
          ),
          _buildChipRow<double>(
            title: 'contentBlur',
            keyPrefix: 'fidelity_contentBlur',
            values: const <double>[0.0, 4.0, 8.0, 12.0],
            selected: _contentBlur,
            format: (double v) => v.toStringAsFixed(0),
            onSelected: (double v) => setState(() => _contentBlur = v),
          ),
          _buildChipRow<double>(
            title: 'contentFollow',
            keyPrefix: 'fidelity_contentFollow',
            values: const <double>[0.0, 0.5, 1.0],
            selected: _contentFollow,
            format: (double v) =>
                v == 0.0 ? '0' : (v == 1.0 ? '1' : v.toStringAsFixed(1)),
            onSelected: (double v) => setState(() => _contentFollow = v),
          ),
          _buildChipRow<double>(
            title: 'contentSlide',
            keyPrefix: 'fidelity_contentSlide',
            values: const <double>[-24.0, 0.0, 24.0],
            selected: _contentSlide,
            format: (double v) =>
                v > 0 ? '+${v.toStringAsFixed(0)}' : v.toStringAsFixed(0),
            onSelected: (double v) => setState(() => _contentSlide = v),
          ),
        ],
      ),
    );
  }

  Widget _buildChipRow<T>({
    required String title,
    required String keyPrefix,
    required List<T> values,
    required T selected,
    required String Function(T) format,
    required ValueChanged<T> onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '$title: ${format(selected)}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: values.map((T val) {
              final String label = format(val);
              return ChoiceChip(
                key: ValueKey<String>('${keyPrefix}_$label'),
                label: Text(label),
                selected: selected == val,
                onSelected: (_) => onSelected(val),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── 7. Shape Investigation & Telemetry Card (Sections 8, 9, 10, 21) ─

  Widget _buildShapeInvestigationCard(Rect liveRect, double effectiveRadius) {
    return Container(
      key: const ValueKey<String>('fidelity_shape_investigation_card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'SHAPE INVESTIGATION & TICKER OBSERVATION (SECTIONS 8–10 & 21)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton(
                key: const ValueKey<String>('fidelity_shape_test_no_pos'),
                onPressed: () => _runModeACircleToSquare(
                  overrideSpatial: MorphFidelitySpatialMode.anchorPlaced,
                ),
                child: const Text('1. Circle → Square (No Position Change)'),
              ),
              OutlinedButton(
                key: const ValueKey<String>(
                  'fidelity_shape_test_center_anchor',
                ),
                onPressed: () {
                  _spatialMode = MorphFidelitySpatialMode.anchorPlaced;
                  _selectAnchorAndRunCircleToSquare(
                    QuickNotesMorphAnchorOption.center,
                  );
                },
                child: const Text('2. Circle → Square (Center Anchor)'),
              ),
              OutlinedButton(
                key: const ValueKey<String>(
                  'fidelity_shape_test_corner_anchor',
                ),
                onPressed: () {
                  _spatialMode = MorphFidelitySpatialMode.anchorPlaced;
                  _selectAnchorAndRunCircleToSquare(
                    QuickNotesMorphAnchorOption.bottomRight,
                  );
                },
                child: const Text('3. Circle → Square (Corner Anchor)'),
              ),
              OutlinedButton(
                key: const ValueKey<String>('fidelity_shape_test_reverse'),
                onPressed: _runModeBSquareToCircle,
                child: const Text('4. Square → Circle'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Platform: ${_readPlatformLabel()} • '
            'Circle Config: 56×56 (r=28px true circle) • '
            'Square Config: 224×184 (r=28px rounded card) • '
            'Ticker Avg: ${_averageFrameDeltaMs.toStringAsFixed(1)}ms '
            '(Worst: ${_worstFrameDeltaMs.toStringAsFixed(1)}ms — Flutter Ticker observation only, not GPU profiler)',
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  // ── 8. Physical Device 12-Step Test Sequence (Sections 19 & 20) ─────

  Widget _buildPhysicalTestSequenceCard() {
    return Material(
      key: const ValueKey<String>('fidelity_physical_sequence_card'),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const ValueKey<String>('fidelity_physical_sequence_expansion'),
        initiallyExpanded: true,
        title: const Text(
          'PHYSICAL DEVICE TEST SEQUENCE (TESTS 1–12)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        subtitle: const Text(
          'Tap [Run] to execute each test on the device, then record PASS / FAIL / NOT TESTED.',
          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: List<Widget>.generate(
          kFidelityPhysicalSequenceTests.length,
          (int index) {
            final MorphFidelityChecklistItem item =
                kFidelityPhysicalSequenceTests[index];
            final int stepNum = index + 1;
            return _buildChecklistRow(
              item: item,
              trailingRunButton: ElevatedButton(
                key: ValueKey<String>('fidelity_run_seq_test_$stepNum'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(64, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onPressed: () => _runPhysicalTestStep(stepNum),
                child: Text(
                  'Run T$stepNum',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── 9. Visual Comparison Checklist (Section 14 & 20) ────────────────

  Widget _buildVisualComparisonChecklistCard() {
    return Material(
      key: const ValueKey<String>('fidelity_visual_checklist_card'),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const ValueKey<String>('fidelity_visual_checklist_expansion'),
        initiallyExpanded: true,
        title: const Text(
          'VISUAL COMPARISON CHECKLIST (SHAPE / POSITION / MOTION / CONTENT / GLASS)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        subtitle: const Text(
          'All items default to NOT TESTED until human observation on physical Android device.',
          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: kFidelityVisualComparisonItems
            .map((MorphFidelityChecklistItem item) => _buildChecklistRow(item: item))
            .toList(),
      ),
    );
  }

  Widget _buildChecklistRow({
    required MorphFidelityChecklistItem item,
    Widget? trailingRunButton,
  }) {
    final MorphFidelityCheckStatus status =
        _checklistStatus[item.id] ?? MorphFidelityCheckStatus.notTested;
    return Container(
      key: ValueKey<String>('fidelity_check_item_${item.id}'),
      margin: const EdgeInsets.only(top: 8),
      child: Material(
        color: const Color(0xFFF8FAFC),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.group,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  if (trailingRunButton != null) trailingRunButton,
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: MorphFidelityCheckStatus.values.map(
                  (MorphFidelityCheckStatus opt) {
                    return ChoiceChip(
                      key: ValueKey<String>(
                        'fidelity_status_${item.id}_${opt.name}',
                      ),
                      label: Text(
                        opt.label,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      selected: status == opt,
                      onSelected: (_) {
                        setState(() {
                          _checklistStatus[item.id] = opt;
                        });
                      },
                    );
                  },
                ).toList(),
              ),
              if (status == MorphFidelityCheckStatus.fail) ...<Widget>[
                const SizedBox(height: 8),
                TextField(
                  key: ValueKey<String>('fidelity_notes_${item.id}'),
                  controller: _failNoteControllers[item.id],
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    hintText: 'Record physical-device FAIL observation...',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom diagnostic painter for Sections 16 (Position Visualization) and 17
/// (Trajectory Visualization / Show Motion Path).
class _MorphFidelityDiagnosticPainter extends CustomPainter {
  const _MorphFidelityDiagnosticPainter({
    required this.showDebugOverlay,
    required this.showMotionPath,
    required this.originRect,
    required this.currentRect,
    required this.targetRect,
    required this.activeAnchor,
    required this.centerPath,
    required this.anchorPath,
  });

  final bool showDebugOverlay;
  final bool showMotionPath;
  final Rect originRect;
  final Rect currentRect;
  final Rect targetRect;
  final Alignment activeAnchor;
  final List<Offset> centerPath;
  final List<Offset> anchorPath;

  @override
  void paint(Canvas canvas, Size size) {
    if (showDebugOverlay) {
      final Paint originPaint = Paint()
        ..color = const Color(0xFFFBBF24).withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawRect(originRect, originPaint);

      final Paint targetPaint = Paint()
        ..color = const Color(0xFF34D399).withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawRect(targetRect, targetPaint);

      final Paint currentPaint = Paint()
        ..color = const Color(0xFF38BDF8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawRect(currentRect, currentPaint);

      final Paint travelLinePaint = Paint()
        ..color = const Color(0xFF64748B).withValues(alpha: 0.60)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawLine(originRect.center, targetRect.center, travelLinePaint);

      canvas.drawCircle(
        originRect.center,
        4.5,
        Paint()..color = const Color(0xFFFBBF24),
      );
      canvas.drawCircle(
        targetRect.center,
        5.0,
        Paint()..color = const Color(0xFF34D399),
      );
      canvas.drawCircle(
        currentRect.center,
        5.0,
        Paint()..color = const Color(0xFF38BDF8),
      );

      // Source and Destination Anchor Points (showing held corner coincidence)
      final Offset srcAnchorPt = activeAnchor.withinRect(originRect);
      final Offset destAnchorPt = activeAnchor.withinRect(targetRect);

      canvas.drawCircle(
        srcAnchorPt,
        3.5,
        Paint()
          ..color = const Color(0xFFFBBF24)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        destAnchorPt,
        4.0,
        Paint()
          ..color = const Color(0xFF34D399)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      final Offset anchorPt = activeAnchor.withinRect(currentRect);
      final Paint anchorPaint = Paint()
        ..color = const Color(0xFFF43F5E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(anchorPt, 6.0, anchorPaint);
      canvas.drawLine(
        anchorPt + const Offset(-9, 0),
        anchorPt + const Offset(9, 0),
        anchorPaint,
      );
      canvas.drawLine(
        anchorPt + const Offset(0, -9),
        anchorPt + const Offset(0, 9),
        anchorPaint,
      );
    }

    if (showMotionPath && centerPath.length > 1) {
      final Path path = Path()..moveTo(centerPath.first.dx, centerPath.first.dy);
      for (int i = 1; i < centerPath.length; i++) {
        path.lineTo(centerPath[i].dx, centerPath[i].dy);
      }
      final Paint pathPaint = Paint()
        ..color = const Color(0xFFFDE047)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, pathPaint);

      for (final Offset pt in centerPath) {
        canvas.drawCircle(
          pt,
          2.2,
          Paint()..color = const Color(0xFFFDE047),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MorphFidelityDiagnosticPainter oldDelegate) {
    return oldDelegate.showDebugOverlay != showDebugOverlay ||
        oldDelegate.showMotionPath != showMotionPath ||
        oldDelegate.originRect != originRect ||
        oldDelegate.currentRect != currentRect ||
        oldDelegate.targetRect != targetRect ||
        oldDelegate.activeAnchor != activeAnchor ||
        oldDelegate.centerPath.length != centerPath.length;
  }
}
