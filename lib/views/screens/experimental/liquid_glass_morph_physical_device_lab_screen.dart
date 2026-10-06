import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:quick_notes/views/screens/experimental/liquid_glass_morph_content_lab_screen.dart';
import 'package:quick_notes/views/screens/experimental/liquid_glass_morph_mechanics_lab_screen.dart';
import 'package:quick_notes/views/widgets/app_bottom_navigation_bar.dart';

/// Tri-state human verification status for each physical-device checklist item.
///
/// Per Section 19 governance, all items initialize to [notTested] and must
/// NEVER be automatically marked as [pass].
enum PhysicalDeviceChecklistStatus {
  pass('PASS'),
  fail('FAIL'),
  notTested('NOT TESTED');

  const PhysicalDeviceChecklistStatus(this.label);
  final String label;
}

/// Definition of a single checklist item in the Physical Device Morphing Lab.
@immutable
class PhysicalDeviceChecklistItemSpec {
  const PhysicalDeviceChecklistItemSpec({
    required this.id,
    required this.category,
    required this.title,
  });

  final String id;
  final String category;
  final String title;
}

/// Complete catalog of required Phase 8C-P physical-device checklist items
/// (Section 18).
const List<PhysicalDeviceChecklistItemSpec> kPhysicalDeviceChecklistSpecs =
    <PhysicalDeviceChecklistItemSpec>[
  // BASIC MORPHING
  PhysicalDeviceChecklistItemSpec(
    id: 'basic_a_to_b',
    category: 'BASIC MORPHING',
    title: 'A → B',
  ),
  PhysicalDeviceChecklistItemSpec(
    id: 'basic_b_to_a',
    category: 'BASIC MORPHING',
    title: 'B → A',
  ),
  PhysicalDeviceChecklistItemSpec(
    id: 'basic_size_only',
    category: 'BASIC MORPHING',
    title: 'Size Only',
  ),
  PhysicalDeviceChecklistItemSpec(
    id: 'basic_position_only',
    category: 'BASIC MORPHING',
    title: 'Position Only',
  ),
  PhysicalDeviceChecklistItemSpec(
    id: 'basic_size_and_position',
    category: 'BASIC MORPHING',
    title: 'Size + Position',
  ),

  // INTERRUPTION
  PhysicalDeviceChecklistItemSpec(
    id: 'interrupt_early_aba',
    category: 'INTERRUPTION',
    title: 'A → B interrupted early → A',
  ),
  PhysicalDeviceChecklistItemSpec(
    id: 'interrupt_overlap_aba',
    category: 'INTERRUPTION',
    title: 'A → B interrupted during overlap → A',
  ),
  PhysicalDeviceChecklistItemSpec(
    id: 'interrupt_retarget_abc',
    category: 'INTERRUPTION',
    title: 'A → B retargeted → C',
  ),

  // RAPID INTERACTION
  PhysicalDeviceChecklistItemSpec(
    id: 'rapid_ababa',
    category: 'RAPID INTERACTION',
    title: 'Rapid A → B → A → B → A',
  ),

  // ANCHORS
  PhysicalDeviceChecklistItemSpec(
    id: 'anchor_center',
    category: 'ANCHORS',
    title: 'Center',
  ),
  PhysicalDeviceChecklistItemSpec(
    id: 'anchor_top_left',
    category: 'ANCHORS',
    title: 'Top Left',
  ),
  PhysicalDeviceChecklistItemSpec(
    id: 'anchor_top_right',
    category: 'ANCHORS',
    title: 'Top Right',
  ),
  PhysicalDeviceChecklistItemSpec(
    id: 'anchor_bottom_left',
    category: 'ANCHORS',
    title: 'Bottom Left',
  ),
  PhysicalDeviceChecklistItemSpec(
    id: 'anchor_bottom_right',
    category: 'ANCHORS',
    title: 'Bottom Right',
  ),

  // CONTENT
  PhysicalDeviceChecklistItemSpec(
    id: 'content_blur_0',
    category: 'CONTENT',
    title: 'contentBlur = 0',
  ),
  PhysicalDeviceChecklistItemSpec(
    id: 'content_blur_4',
    category: 'CONTENT',
    title: 'contentBlur = 4',
  ),
  PhysicalDeviceChecklistItemSpec(
    id: 'content_blur_8',
    category: 'CONTENT',
    title: 'contentBlur = 8',
  ),
  PhysicalDeviceChecklistItemSpec(
    id: 'content_blur_12',
    category: 'CONTENT',
    title: 'contentBlur = 12',
  ),
  PhysicalDeviceChecklistItemSpec(
    id: 'content_follow_0',
    category: 'CONTENT',
    title: 'contentFollow = 0',
  ),
  PhysicalDeviceChecklistItemSpec(
    id: 'content_follow_05',
    category: 'CONTENT',
    title: 'contentFollow = 0.5',
  ),
  PhysicalDeviceChecklistItemSpec(
    id: 'content_follow_1',
    category: 'CONTENT',
    title: 'contentFollow = 1',
  ),
  PhysicalDeviceChecklistItemSpec(
    id: 'content_slide_neg24',
    category: 'CONTENT',
    title: 'contentSlide = -24',
  ),
  PhysicalDeviceChecklistItemSpec(
    id: 'content_slide_0',
    category: 'CONTENT',
    title: 'contentSlide = 0',
  ),
  PhysicalDeviceChecklistItemSpec(
    id: 'content_slide_pos24',
    category: 'CONTENT',
    title: 'contentSlide = +24',
  ),

  // GEOMETRY
  PhysicalDeviceChecklistItemSpec(
    id: 'geo_stretch_0',
    category: 'GEOMETRY',
    title: 'stretch = 0',
  ),
  PhysicalDeviceChecklistItemSpec(
    id: 'geo_stretch_05',
    category: 'GEOMETRY',
    title: 'stretch = 0.5',
  ),
  PhysicalDeviceChecklistItemSpec(
    id: 'geo_stretch_1',
    category: 'GEOMETRY',
    title: 'stretch = 1',
  ),
  PhysicalDeviceChecklistItemSpec(
    id: 'geo_bounce_0',
    category: 'GEOMETRY',
    title: 'leadBounce = 0',
  ),
  PhysicalDeviceChecklistItemSpec(
    id: 'geo_bounce_010',
    category: 'GEOMETRY',
    title: 'leadBounce = 0.10',
  ),
  PhysicalDeviceChecklistItemSpec(
    id: 'geo_bounce_025',
    category: 'GEOMETRY',
    title: 'leadBounce = 0.25',
  ),
  PhysicalDeviceChecklistItemSpec(
    id: 'geo_delay_0',
    category: 'GEOMETRY',
    title: 'followDelay = 0',
  ),
  PhysicalDeviceChecklistItemSpec(
    id: 'geo_delay_40',
    category: 'GEOMETRY',
    title: 'followDelay = 40 ms',
  ),
  PhysicalDeviceChecklistItemSpec(
    id: 'geo_delay_100',
    category: 'GEOMETRY',
    title: 'followDelay = 100 ms',
  ),
  PhysicalDeviceChecklistItemSpec(
    id: 'geo_delay_150',
    category: 'GEOMETRY',
    title: 'followDelay = 150 ms',
  ),

  // VISUAL QUALITY
  PhysicalDeviceChecklistItemSpec(
    id: 'vq_no_clipping',
    category: 'VISUAL QUALITY',
    title: 'No clipping artifacts',
  ),
  PhysicalDeviceChecklistItemSpec(
    id: 'vq_no_flicker',
    category: 'VISUAL QUALITY',
    title: 'No flicker',
  ),
  PhysicalDeviceChecklistItemSpec(
    id: 'vq_no_opacity_jumps',
    category: 'VISUAL QUALITY',
    title: 'No sudden opacity jumps',
  ),
  PhysicalDeviceChecklistItemSpec(
    id: 'vq_no_flashing',
    category: 'VISUAL QUALITY',
    title: 'No content flashing',
  ),
  PhysicalDeviceChecklistItemSpec(
    id: 'vq_no_layout_jitter',
    category: 'VISUAL QUALITY',
    title: 'No visible layout jitter',
  ),
  PhysicalDeviceChecklistItemSpec(
    id: 'vq_no_blur_persistence',
    category: 'VISUAL QUALITY',
    title: 'No unexpected blur persistence',
  ),
  PhysicalDeviceChecklistItemSpec(
    id: 'vq_no_glass_corruption',
    category: 'VISUAL QUALITY',
    title: 'No glass appearance corruption',
  ),
  PhysicalDeviceChecklistItemSpec(
    id: 'vq_no_frame_drops',
    category: 'VISUAL QUALITY',
    title: 'No obvious frame drops',
  ),
  PhysicalDeviceChecklistItemSpec(
    id: 'vq_no_stalls',
    category: 'VISUAL QUALITY',
    title: 'No animation stalls',
  ),
  PhysicalDeviceChecklistItemSpec(
    id: 'vq_no_stuck_ticker',
    category: 'VISUAL QUALITY',
    title: 'No stuck ticker',
  ),
  PhysicalDeviceChecklistItemSpec(
    id: 'vq_no_wrong_final_state',
    category: 'VISUAL QUALITY',
    title: 'No incorrect final state',
  ),
];

/// Phase 8C-P — Dedicated Physical Device Morphing Lab.
///
/// Orchestrates the validated Phase 8C-A 4D geometry controller
/// ([QuickNotesMorphGeometryController]) and Phase 8C-B content controller
/// ([QuickNotesMorphContentController]) over Quick Notes' existing
/// [BottomBarGlassSurface] for human interaction and visual verification on a
/// physical Android device.
class LiquidGlassMorphPhysicalDeviceLabScreen extends StatefulWidget {
  const LiquidGlassMorphPhysicalDeviceLabScreen({super.key});

  @override
  State<LiquidGlassMorphPhysicalDeviceLabScreen> createState() =>
      _LiquidGlassMorphPhysicalDeviceLabScreenState();
}

class _LiquidGlassMorphPhysicalDeviceLabScreenState
    extends State<LiquidGlassMorphPhysicalDeviceLabScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastTickElapsed = Duration.zero;
  final List<Timer> _sequenceTimers = <Timer>[];

  final QuickNotesMorphGeometryController _geometryController =
      QuickNotesMorphGeometryController();
  final QuickNotesMorphContentController _contentController =
      QuickNotesMorphContentController();

  QuickNotesMorphStateId _currentState = QuickNotesMorphStateId.stateA;
  QuickNotesMorphStateId _targetState = QuickNotesMorphStateId.stateA;
  QuickNotesMorphAnchorOption _selectedAnchor =
      QuickNotesMorphAnchorOption.center;
  QuickNotesMorphTopologyMode _topologyMode =
      QuickNotesMorphTopologyMode.sizeAndPosition;

  // Phase 8C-A Geometry parameters (practical predefined presets)
  final double _stiffness = 195.0;
  final double _damping = 19.5;
  double _stretch = 0.50;
  double _leadBounce = 0.10;
  int _followDelayMs = 40;

  // Phase 8C-B Content parameters
  final double _contentOutEnd = 0.40;
  final double _contentInStart = 0.30;
  final double _contentInEnd = 0.80;
  final double _oldScaleTo = 0.92;
  final double _newScaleFrom = 0.90;
  double _contentBlur = 8.0;
  double _contentFollow = 0.0;
  double _contentSlide = 12.0;

  // Visual Test Mode (expands preview & minimizes visual clutter for recording)
  bool _testModeExpanded = false;
  bool _checklistExpanded = true;

  // Ticker-level frame interval observation (labeled as ticker delta, not GPU raster)
  final List<double> _recentFrameMs = <double>[];

  // Checklist statuses & fail notes
  late final Map<String, PhysicalDeviceChecklistStatus> _checklistStatus =
      <String, PhysicalDeviceChecklistStatus>{
    for (final PhysicalDeviceChecklistItemSpec spec
        in kPhysicalDeviceChecklistSpecs)
      spec.id: PhysicalDeviceChecklistStatus.notTested,
  };

  late final Map<String, TextEditingController> _failNoteControllers =
      <String, TextEditingController>{
    for (final PhysicalDeviceChecklistItemSpec spec
        in kPhysicalDeviceChecklistSpecs)
      spec.id: TextEditingController(),
  };

  // Stable GlobalKeys for child layout preservation across frames
  final Map<QuickNotesMorphStateId, GlobalKey> _stateBoxKeys =
      <QuickNotesMorphStateId, GlobalKey>{
    QuickNotesMorphStateId.stateA: GlobalKey(debugLabel: 'phys_box_stateA'),
    QuickNotesMorphStateId.stateB: GlobalKey(debugLabel: 'phys_box_stateB'),
    QuickNotesMorphStateId.stateC: GlobalKey(debugLabel: 'phys_box_stateC'),
  };

  late final Map<QuickNotesMorphStateId, Widget> _stableStateChildren =
      <QuickNotesMorphStateId, Widget>{
    QuickNotesMorphStateId.stateA:
        _buildStateChild(QuickNotesMorphStateId.stateA),
    QuickNotesMorphStateId.stateB:
        _buildStateChild(QuickNotesMorphStateId.stateB),
    QuickNotesMorphStateId.stateC:
        _buildStateChild(QuickNotesMorphStateId.stateC),
  };

  Size _stageFieldSize = const Size(360, 290);

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

  QuickNotesMorphGeometryConfig _buildGeometryConfig() {
    return QuickNotesMorphGeometryConfig(
      stiffness: _stiffness,
      damping: _damping,
      stretch: _stretch,
      leadBounce: _leadBounce,
      followDelaySeconds: _followDelayMs / 1000.0,
      seedScale: 1.0,
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
        return const Alignment(-0.62, -0.54);
      case QuickNotesMorphStateId.stateB:
        return const Alignment(0.42, 0.38);
      case QuickNotesMorphStateId.stateC:
        return const Alignment(-0.36, 0.56);
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

    final double dtMs = dt * 1000.0;
    if (dtMs > 0.5 && dtMs < 250.0) {
      _recentFrameMs.add(dtMs);
      if (_recentFrameMs.length > 60) {
        _recentFrameMs.removeAt(0);
      }
    }

    final QuickNotesMorphGeometryConfig geoConfig = _buildGeometryConfig();
    final QuickNotesMorphContentConfig contentConfig = _buildContentConfig();

    final bool geoMoving = _geometryController.step(dt, geoConfig);
    final bool contentMoving = _contentController.step(dt, contentConfig);

    if (!geoMoving && !contentMoving) {
      _currentState = _targetState;
      _ticker.stop();
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _transitionToState(
    QuickNotesMorphStateId nextTarget, {
    bool cancelScheduledSequence = true,
  }) {
    if (cancelScheduledSequence) {
      _cancelTimers();
    }
    setState(() {
      _targetState = nextTarget;
      final Rect liveRect = _geometryController.currentRect;
      final Rect targetRect = _computeStateRect(nextTarget, _stageFieldSize);

      _geometryController.transitionToRect(
        targetRect,
        config: _buildGeometryConfig(),
      );
      _contentController.transitionToState(
        targetState: nextTarget,
        targetRect: targetRect,
        liveGlassRect: liveRect,
        config: _buildContentConfig(),
        stiffness: _stiffness,
      );
      _wakeTicker();
    });
  }

  void _seedStateImmediate(QuickNotesMorphStateId state) {
    final Rect rect = _computeStateRect(state, _stageFieldSize);
    _geometryController.seedInitialRect(
      rect,
      anchor: _selectedAnchor.alignment,
    );
    _contentController.seedInitialState(
      stateId: state,
      stateRect: rect,
      stiffness: _stiffness,
    );
    _currentState = state;
    _targetState = state;
  }

  /// Primary Action: `A → B` (and `Start A → B` for manual interruption).
  void _handleAToB() {
    _cancelTimers();
    if (!_ticker.isActive && _targetState != QuickNotesMorphStateId.stateA) {
      _seedStateImmediate(QuickNotesMorphStateId.stateA);
    }
    _transitionToState(QuickNotesMorphStateId.stateB);
  }

  /// Primary Action: `B → A`.
  void _handleBToA() {
    _cancelTimers();
    if (!_ticker.isActive && _targetState != QuickNotesMorphStateId.stateB) {
      _seedStateImmediate(QuickNotesMorphStateId.stateB);
    }
    _transitionToState(QuickNotesMorphStateId.stateA);
  }

  /// Manual Interruption Control: `Reverse` (immediately reverses toward State A
  /// if currently heading toward B/C, or toward B if heading toward A).
  void _handleManualReverse() {
    _cancelTimers();
    final QuickNotesMorphStateId reverseTarget =
        _targetState == QuickNotesMorphStateId.stateA
            ? QuickNotesMorphStateId.stateB
            : QuickNotesMorphStateId.stateA;
    _transitionToState(reverseTarget);
  }

  /// Manual Retarget Control: `Retarget C` (immediately retargets mid-flight or
  /// from rest toward State C).
  void _handleManualRetargetC() {
    _cancelTimers();
    _transitionToState(QuickNotesMorphStateId.stateC);
  }

  /// Automated `A → B → A` mid-flight interruption sequence.
  void _handleSequenceABA() {
    _cancelTimers();
    _seedStateImmediate(QuickNotesMorphStateId.stateA);
    _transitionToState(
      QuickNotesMorphStateId.stateB,
      cancelScheduledSequence: false,
    );
    _sequenceTimers.add(
      Timer(const Duration(milliseconds: 130), () {
        if (!mounted) return;
        _transitionToState(
          QuickNotesMorphStateId.stateA,
          cancelScheduledSequence: false,
        );
      }),
    );
  }

  /// Automated `A → B → C` mid-flight retargeting sequence.
  void _handleSequenceABC() {
    _cancelTimers();
    _seedStateImmediate(QuickNotesMorphStateId.stateA);
    _transitionToState(
      QuickNotesMorphStateId.stateB,
      cancelScheduledSequence: false,
    );
    _sequenceTimers.add(
      Timer(const Duration(milliseconds: 130), () {
        if (!mounted) return;
        _transitionToState(
          QuickNotesMorphStateId.stateC,
          cancelScheduledSequence: false,
        );
      }),
    );
  }

  /// Automated `Rapid A → B → A → B → A` test (can be manually interrupted at
  /// any moment by tapping `Reverse`, `Retarget C`, `A → B`, `B → A`, or `Reset`).
  void _handleRapidSequence() {
    _cancelTimers();
    _seedStateImmediate(QuickNotesMorphStateId.stateA);
    const List<QuickNotesMorphStateId> steps = <QuickNotesMorphStateId>[
      QuickNotesMorphStateId.stateB,
      QuickNotesMorphStateId.stateA,
      QuickNotesMorphStateId.stateB,
      QuickNotesMorphStateId.stateA,
    ];
    for (int i = 0; i < steps.length; i++) {
      _sequenceTimers.add(
        Timer(Duration(milliseconds: 95 * (i + 1)), () {
          if (!mounted) return;
          _transitionToState(
            steps[i],
            cancelScheduledSequence: false,
          );
        }),
      );
    }
  }

  /// Resets all parameters, timers, and state back to the validated Phase 8C-A/8C-B
  /// baseline (`State A`).
  void _handleReset() {
    _cancelTimers();
    _ticker.stop();
    setState(() {
      _selectedAnchor = QuickNotesMorphAnchorOption.center;
      _topologyMode = QuickNotesMorphTopologyMode.sizeAndPosition;
      _stretch = 0.50;
      _leadBounce = 0.10;
      _followDelayMs = 40;
      _contentBlur = 8.0;
      _contentFollow = 0.0;
      _contentSlide = 12.0;
      _recentFrameMs.clear();
      _seedStateImmediate(QuickNotesMorphStateId.stateA);
    });
  }

  BorderRadius _computeBorderRadius(Rect rect) {
    final double maxPossible = math.min(rect.width, rect.height) * 0.5;
    return BorderRadius.circular(math.min(24.0, maxPossible));
  }

  Widget _buildStateChild(QuickNotesMorphStateId state) {
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
                color: Color(0xFF0F172A),
              ),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'State A',
                  key: ValueKey<String>('phys_lab_stateA_text'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
        );
      case QuickNotesMorphStateId.stateB:
        return Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.view_agenda_rounded,
                      size: 15,
                      color: Color(0xFF0369A1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'State B',
                      key: ValueKey<String>('phys_lab_stateB_text'),
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
                  'Expanded card surface for physical touch, blur, follow, slide & clipping validation.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.28,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
              const Row(
                children: <Widget>[
                  Icon(
                    Icons.verified_outlined,
                    size: 13,
                    color: Color(0xFF475569),
                  ),
                  SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Quick Notes Glass • 8C-A + 8C-B',
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
                      key: ValueKey<String>('phys_lab_stateC_text'),
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
                  'Retargeted banner (216×96) for mid-flight A→B→C validation.',
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
  }

  Widget _buildEvaluatedContentLayer(
    QuickNotesEvaluatedContentLayer layer, {
    required String roleTag,
  }) {
    final Size stableSize = layer.stateId.defaultSize;
    Widget content = SizedBox(
      key: _stateBoxKeys[layer.stateId],
      width: stableSize.width,
      height: stableSize.height,
      child: _stableStateChildren[layer.stateId]!,
    );

    if (layer.isBlurActive) {
      content = ImageFiltered(
        key: ValueKey<String>('phys_blur_${roleTag}_${layer.stateId.name}'),
        imageFilter: ui.ImageFilter.blur(
          sigmaX: layer.blurSigma,
          sigmaY: layer.blurSigma,
        ),
        child: content,
      );
    }

    return Positioned(
      key: ValueKey<String>('phys_layer_${layer.stateId.name}'),
      left: layer.localOffset.dx,
      top: layer.localOffset.dy,
      width: stableSize.width,
      height: stableSize.height,
      child: IgnorePointer(
        ignoring: !layer.isIncoming,
        child: Opacity(
          opacity: layer.opacity,
          child: Transform.scale(
            scale: layer.scale,
            alignment: layer.alignment,
            child: content,
          ),
        ),
      ),
    );
  }

  String _readPlatformLabel() {
    if (kIsWeb) return 'Web';
    try {
      return Platform.operatingSystem.toUpperCase();
    } catch (_) {
      return 'UNKNOWN';
    }
  }

  String _readOsVersionLabel() {
    if (kIsWeb) return 'Web Browser';
    try {
      return Platform.operatingSystemVersion;
    } catch (_) {
      return 'Unknown OS Version';
    }
  }

  String _readDeviceModelSummary() {
    if (kIsWeb) return 'Web Viewport';
    try {
      final String raw = Platform.operatingSystemVersion;
      final String host = Platform.localHostname;
      return host.isNotEmpty ? '$host ($raw)' : raw;
    } catch (_) {
      return 'Standard Device';
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    final double previewHeight = _testModeExpanded ? 380.0 : 300.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Morphing — Physical Device Lab',
          key: ValueKey<String>('phys_lab_appbar_title'),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: <Widget>[
          TextButton.icon(
            key: const ValueKey<String>('phys_lab_test_mode_toggle'),
            onPressed: () {
              setState(() {
                _testModeExpanded = !_testModeExpanded;
              });
            },
            icon: Icon(
              _testModeExpanded
                  ? Icons.fullscreen_exit_rounded
                  : Icons.videocam_outlined,
              size: 18,
            ),
            label: Text(_testModeExpanded ? 'Standard View' : 'Test Mode'),
          ),
          IconButton(
            key: const ValueKey<String>('phys_lab_appbar_reset'),
            tooltip: 'Reset Lab',
            onPressed: _handleReset,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          key: const ValueKey<String>('phys_lab_scroll_view'),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildPreviewStage(previewHeight),
              const SizedBox(height: 12),
              _buildPrimaryTouchControlsCard(),
              const SizedBox(height: 12),
              _buildManualInterruptionCard(),
              const SizedBox(height: 12),
              _buildPerformanceStatusPanel(),
              if (!_testModeExpanded) ...<Widget>[
                const SizedBox(height: 12),
                _buildModeAndAnchorCard(),
                const SizedBox(height: 12),
                _buildContentParametersCard(),
                const SizedBox(height: 12),
                _buildGeometryParametersCard(),
                const SizedBox(height: 12),
                _buildDeviceDiagnosticsCard(screenSize, dpr),
                const SizedBox(height: 12),
                _buildChecklistCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewStage(double previewHeight) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double stageWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 360.0;
        final Size nextFieldSize = Size(stageWidth, previewHeight);
        if (_stageFieldSize != nextFieldSize) {
          _stageFieldSize = nextFieldSize;
          if (!_ticker.isActive) {
            final Rect snapped = _computeStateRect(_targetState, _stageFieldSize);
            _geometryController.seedInitialRect(
              snapped,
              anchor: _selectedAnchor.alignment,
            );
            _contentController.seedInitialState(
              stateId: _targetState,
              stateRect: snapped,
              stiffness: _stiffness,
            );
          }
        }

        final Rect currentRect = _geometryController.currentRect;
        final QuickNotesMorphContentSnapshot snapshot =
            _contentController.currentSnapshot(
          currentGlassRect: currentRect,
          config: _buildContentConfig(),
        );
        final BorderRadius borderRadius = _computeBorderRadius(currentRect);

        return Container(
          key: const ValueKey<String>('phys_lab_preview_stage'),
          width: _stageFieldSize.width,
          height: _stageFieldSize.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0xFFDBEAFE),
                Color(0xFFEDE9FE),
                Color(0xFFFEF3C7),
                Color(0xFFD1FAE5),
              ],
            ),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: <Widget>[
                // High-contrast backdrop shapes to clearly observe Quick Notes 3.0px frost blur
                Positioned(
                  left: 24,
                  top: 22,
                  child: Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                    ),
                  ),
                ),
                Positioned(
                  right: 32,
                  bottom: 24,
                  child: Container(
                    width: 136,
                    height: 136,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.24),
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'State: ${_currentState.name} → Target: ${_targetState.name} • Anchor: ${_selectedAnchor.label}',
                      key: const ValueKey<String>('phys_lab_stage_status_badge'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ),
                // Quick Notes Existing Glass Surface + Phase 8C-A Geometry + Phase 8C-B Content
                Positioned.fromRect(
                  key: const ValueKey<String>('phys_lab_positioned_glass'),
                  rect: currentRect,
                  child: BottomBarGlassSurface(
                    key: const ValueKey<String>('phys_lab_glass_surface'),
                    width: currentRect.width,
                    height: currentRect.height,
                    borderRadius: borderRadius,
                    useFrost: true,
                    child: Stack(
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
        );
      },
    );
  }

  Widget _buildPrimaryTouchControlsCard() {
    return Container(
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
            'PRIMARY INTERACTION CONTROLS',
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
              _buildLargeActionButton(
                keyName: 'phys_btn_a_to_b',
                label: 'A → B',
                icon: Icons.open_in_full_rounded,
                backgroundColor: const Color(0xFF0284C7),
                onPressed: _handleAToB,
              ),
              _buildLargeActionButton(
                keyName: 'phys_btn_b_to_a',
                label: 'B → A',
                icon: Icons.close_fullscreen_rounded,
                backgroundColor: const Color(0xFF0F766E),
                onPressed: _handleBToA,
              ),
              _buildLargeActionButton(
                keyName: 'phys_btn_a_to_b_to_a',
                label: 'A → B → A',
                icon: Icons.u_turn_left_rounded,
                backgroundColor: const Color(0xFF4F46E5),
                onPressed: _handleSequenceABA,
              ),
              _buildLargeActionButton(
                keyName: 'phys_btn_a_to_b_to_c',
                label: 'A → B → C',
                icon: Icons.alt_route_rounded,
                backgroundColor: const Color(0xFF7C3AED),
                onPressed: _handleSequenceABC,
              ),
              _buildLargeActionButton(
                keyName: 'phys_btn_rapid_sequence',
                label: 'Rapid A → B → A → B → A',
                icon: Icons.bolt_rounded,
                backgroundColor: const Color(0xFFD97706),
                onPressed: _handleRapidSequence,
              ),
              _buildLargeActionButton(
                keyName: 'phys_btn_reset',
                label: 'Reset',
                icon: Icons.restart_alt_rounded,
                backgroundColor: const Color(0xFF475569),
                onPressed: _handleReset,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildManualInterruptionCard() {
    return Container(
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
            'MANUAL HUMAN INTERRUPTION & RAPID TEST',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap "Start A → B" or "Rapid Test", then immediately tap "Reverse" or "Retarget C" while the morph is in flight.',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _buildLargeActionButton(
                keyName: 'phys_btn_start_a_to_b',
                label: 'Start A → B',
                icon: Icons.play_arrow_rounded,
                backgroundColor: const Color(0xFF0369A1),
                onPressed: _handleAToB,
              ),
              _buildLargeActionButton(
                keyName: 'phys_btn_manual_reverse',
                label: 'Reverse',
                icon: Icons.settings_backup_restore_rounded,
                backgroundColor: const Color(0xFFDC2626),
                onPressed: _handleManualReverse,
              ),
              _buildLargeActionButton(
                keyName: 'phys_btn_manual_retarget_c',
                label: 'Retarget C',
                icon: Icons.call_split_rounded,
                backgroundColor: const Color(0xFF9333EA),
                onPressed: _handleManualRetargetC,
              ),
              _buildLargeActionButton(
                keyName: 'phys_btn_rapid_test',
                label: 'Rapid Test',
                icon: Icons.speed_rounded,
                backgroundColor: const Color(0xFFEA580C),
                onPressed: _handleRapidSequence,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLargeActionButton({
    required String keyName,
    required String label,
    required IconData icon,
    required Color backgroundColor,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 46,
      child: ElevatedButton.icon(
        key: ValueKey<String>(keyName),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildPerformanceStatusPanel() {
    final bool isRunning = _ticker.isActive;
    final bool geoSettling = _geometryController.isAnimating;
    final bool contentTransitioning = _contentController.isAnimating;

    double avgFrameMs = 0.0;
    double worstFrameMs = 0.0;
    double approxFps = 0.0;
    if (_recentFrameMs.isNotEmpty) {
      double sum = 0.0;
      for (final double ms in _recentFrameMs) {
        sum += ms;
        if (ms > worstFrameMs) worstFrameMs = ms;
      }
      avgFrameMs = sum / _recentFrameMs.length;
      if (avgFrameMs > 0.1) {
        approxFps = 1000.0 / avgFrameMs;
      }
    }

    return Container(
      key: const ValueKey<String>('phys_lab_performance_panel'),
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
            'PERFORMANCE & STATUS OBSERVATION PANEL',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: <Widget>[
              _buildStatusPill(
                keyName: 'phys_status_animation',
                text: 'Animation: ${isRunning ? "RUNNING" : "IDLE"}',
                active: isRunning,
              ),
              _buildStatusPill(
                keyName: 'phys_status_geometry',
                text: 'Geometry: ${geoSettling ? "SETTLING" : "SETTLED"}',
                active: geoSettling,
              ),
              _buildStatusPill(
                keyName: 'phys_status_content',
                text:
                    'Content: ${contentTransitioning ? "TRANSITIONING" : "SETTLED"}',
                active: contentTransitioning,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _recentFrameMs.isEmpty
                ? 'Ticker Frame Intervals (Not GPU Raster): No frames sampled yet'
                : 'Ticker Frame Intervals (Not GPU Raster): Avg ${avgFrameMs.toStringAsFixed(1)} ms • Worst ${worstFrameMs.toStringAsFixed(1)} ms • Approx ${approxFps.toStringAsFixed(0)} FPS',
            key: const ValueKey<String>('phys_status_frame_metrics'),
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill({
    required String keyName,
    required String text,
    required bool active,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        key: ValueKey<String>(keyName),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: active ? const Color(0xFF15803D) : const Color(0xFF334155),
        ),
      ),
    );
  }

  Widget _buildModeAndAnchorCard() {
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
            'SIZE / POSITION TEST MODES & ANCHOR SELECTOR',
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
              _buildTopologyChip(
                mode: QuickNotesMorphTopologyMode.sizeOnly,
                label: 'Size Only',
                keyName: 'phys_mode_sizeOnly',
              ),
              _buildTopologyChip(
                mode: QuickNotesMorphTopologyMode.positionOnly,
                label: 'Position Only',
                keyName: 'phys_mode_positionOnly',
              ),
              _buildTopologyChip(
                mode: QuickNotesMorphTopologyMode.sizeAndPosition,
                label: 'Size + Position',
                keyName: 'phys_mode_sizeAndPosition',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _buildAnchorChip(
                option: QuickNotesMorphAnchorOption.center,
                label: 'Center',
                keyName: 'phys_anchor_center',
              ),
              _buildAnchorChip(
                option: QuickNotesMorphAnchorOption.topLeft,
                label: 'Top Left',
                keyName: 'phys_anchor_topLeft',
              ),
              _buildAnchorChip(
                option: QuickNotesMorphAnchorOption.topRight,
                label: 'Top Right',
                keyName: 'phys_anchor_topRight',
              ),
              _buildAnchorChip(
                option: QuickNotesMorphAnchorOption.bottomLeft,
                label: 'Bottom Left',
                keyName: 'phys_anchor_bottomLeft',
              ),
              _buildAnchorChip(
                option: QuickNotesMorphAnchorOption.bottomRight,
                label: 'Bottom Right',
                keyName: 'phys_anchor_bottomRight',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopologyChip({
    required QuickNotesMorphTopologyMode mode,
    required String label,
    required String keyName,
  }) {
    return ChoiceChip(
      key: ValueKey<String>(keyName),
      label: Text(label),
      selected: _topologyMode == mode,
      onSelected: (_) {
        setState(() {
          _topologyMode = mode;
          _seedStateImmediate(_targetState);
        });
      },
    );
  }

  Widget _buildAnchorChip({
    required QuickNotesMorphAnchorOption option,
    required String label,
    required String keyName,
  }) {
    return ChoiceChip(
      key: ValueKey<String>(keyName),
      label: Text(label),
      selected: _selectedAnchor == option,
      onSelected: (_) {
        setState(() {
          _selectedAnchor = option;
          _geometryController.rebaseAnchor(option.alignment);
        });
      },
    );
  }

  Widget _buildContentParametersCard() {
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
            'CONTENT CONTROLS (PHASE 8C-B)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 10),
          _buildParameterSelectorRow<double>(
            title: 'contentBlur',
            keyPrefix: 'phys_contentBlur',
            values: const <double>[0.0, 4.0, 8.0, 12.0],
            selectedValue: _contentBlur,
            formatLabel: (double v) => v.toStringAsFixed(0),
            onSelected: (double v) => setState(() => _contentBlur = v),
          ),
          _buildParameterSelectorRow<double>(
            title: 'contentFollow',
            keyPrefix: 'phys_contentFollow',
            values: const <double>[0.0, 0.25, 0.50, 0.75, 1.0],
            selectedValue: _contentFollow,
            formatLabel: (double v) => v.toStringAsFixed(2),
            onSelected: (double v) => setState(() => _contentFollow = v),
          ),
          _buildParameterSelectorRow<double>(
            title: 'contentSlide',
            keyPrefix: 'phys_contentSlide',
            values: const <double>[-24.0, -12.0, 0.0, 12.0, 24.0],
            selectedValue: _contentSlide,
            formatLabel: (double v) =>
                v > 0 ? '+${v.toStringAsFixed(0)}' : v.toStringAsFixed(0),
            onSelected: (double v) => setState(() => _contentSlide = v),
          ),
        ],
      ),
    );
  }

  Widget _buildGeometryParametersCard() {
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
            'GEOMETRY CONTROLS (PHASE 8C-A)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 10),
          _buildParameterSelectorRow<double>(
            title: 'stretch',
            keyPrefix: 'phys_stretch',
            values: const <double>[0.0, 0.25, 0.5, 0.75, 1.0],
            selectedValue: _stretch,
            formatLabel: (double v) =>
                v == 0.5 ? '0.5' : (v == 0.0 || v == 1.0 ? v.toStringAsFixed(1) : v.toStringAsFixed(2)),
            onSelected: (double v) => setState(() => _stretch = v),
          ),
          _buildParameterSelectorRow<double>(
            title: 'leadBounce',
            keyPrefix: 'phys_leadBounce',
            values: const <double>[0.0, 0.10, 0.25],
            selectedValue: _leadBounce,
            formatLabel: (double v) =>
                v == 0.0 ? '0.0' : v.toStringAsFixed(2),
            onSelected: (double v) => setState(() => _leadBounce = v),
          ),
          _buildParameterSelectorRow<int>(
            title: 'followDelay',
            keyPrefix: 'phys_followDelay',
            values: const <int>[0, 40, 100, 150],
            selectedValue: _followDelayMs,
            formatLabel: (int v) => '$v ms',
            onSelected: (int v) => setState(() => _followDelayMs = v),
          ),
        ],
      ),
    );
  }

  Widget _buildParameterSelectorRow<T>({
    required String title,
    required String keyPrefix,
    required List<T> values,
    required T selectedValue,
    required String Function(T) formatLabel,
    required ValueChanged<T> onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '$title: ${formatLabel(selectedValue)}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: values.map((T val) {
              final String label = formatLabel(val);
              return ChoiceChip(
                key: ValueKey<String>('${keyPrefix}_$label'),
                label: Text(label, style: const TextStyle(fontSize: 12)),
                selected: selectedValue == val,
                onSelected: (_) => onSelected(val),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceDiagnosticsCard(Size screenSize, double dpr) {
    return Container(
      key: const ValueKey<String>('phys_lab_diagnostics_card'),
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
            'DEVICE TEST INFORMATION & ACTIVE CONFIG',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: <Widget>[
              Text(
                'Platform: ${_readPlatformLabel()}',
                key: const ValueKey<String>('diag_platform'),
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
              Text(
                'Android version: ${_readOsVersionLabel()}',
                key: const ValueKey<String>('diag_android_version'),
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
              Text(
                'Device model: ${_readDeviceModelSummary()}',
                key: const ValueKey<String>('diag_device_model'),
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
              Text(
                'Screen size: ${screenSize.width.toStringAsFixed(0)}×${screenSize.height.toStringAsFixed(0)}',
                key: const ValueKey<String>('diag_screen_size'),
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
              Text(
                'Device pixel ratio: ${dpr.toStringAsFixed(2)}',
                key: const ValueKey<String>('diag_dpr'),
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
              Text(
                'Current Morph State: ${_currentState.label}',
                key: const ValueKey<String>('diag_current_state'),
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
              Text(
                'Current Target: ${_targetState.label}',
                key: const ValueKey<String>('diag_current_target'),
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
              Text(
                'Current Anchor: ${_selectedAnchor.label}',
                key: const ValueKey<String>('diag_current_anchor'),
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
              Text(
                'Current contentBlur: ${_contentBlur.toStringAsFixed(0)}',
                key: const ValueKey<String>('diag_content_blur'),
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
              Text(
                'Current contentFollow: ${_contentFollow.toStringAsFixed(2)}',
                key: const ValueKey<String>('diag_content_follow'),
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
              Text(
                'Current contentSlide: ${_contentSlide > 0 ? "+${_contentSlide.toStringAsFixed(0)}" : _contentSlide.toStringAsFixed(0)}',
                key: const ValueKey<String>('diag_content_slide'),
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
              Text(
                'Current stretch: ${_stretch.toStringAsFixed(2)}',
                key: const ValueKey<String>('diag_stretch'),
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
              Text(
                'Current leadBounce: ${_leadBounce.toStringAsFixed(2)}',
                key: const ValueKey<String>('diag_lead_bounce'),
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
              Text(
                'Current followDelay: $_followDelayMs ms',
                key: const ValueKey<String>('diag_follow_delay'),
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistCard() {
    final int passCount = _checklistStatus.values
        .where((PhysicalDeviceChecklistStatus s) =>
            s == PhysicalDeviceChecklistStatus.pass)
        .length;
    final int failCount = _checklistStatus.values
        .where((PhysicalDeviceChecklistStatus s) =>
            s == PhysicalDeviceChecklistStatus.fail)
        .length;
    final int notTestedCount = _checklistStatus.values
        .where((PhysicalDeviceChecklistStatus s) =>
            s == PhysicalDeviceChecklistStatus.notTested)
        .length;

    return Material(
      key: const ValueKey<String>('phys_lab_checklist_card'),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const ValueKey<String>('phys_lab_checklist_expansion'),
        initiallyExpanded: _checklistExpanded,
        onExpansionChanged: (bool expanded) {
          setState(() {
            _checklistExpanded = expanded;
          });
        },
        title: const Text(
          'PHYSICAL DEVICE TEST CHECKLIST',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        subtitle: Text(
          'PASS: $passCount • FAIL: $failCount • NOT TESTED: $notTestedCount',
          key: const ValueKey<String>('phys_lab_checklist_summary'),
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: kPhysicalDeviceChecklistSpecs.map(
          (PhysicalDeviceChecklistItemSpec spec) {
            final PhysicalDeviceChecklistStatus status =
                _checklistStatus[spec.id] ??
                    PhysicalDeviceChecklistStatus.notTested;
            return Container(
              key: ValueKey<String>('checklist_item_${spec.id}'),
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
                          spec.category,
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
                          spec.title,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: PhysicalDeviceChecklistStatus.values.map(
                      (PhysicalDeviceChecklistStatus opt) {
                        final bool selected = status == opt;
                        return ChoiceChip(
                          key: ValueKey<String>(
                            'checklist_${spec.id}_${opt.name}',
                          ),
                          label: Text(
                            opt.label,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          selected: selected,
                          onSelected: (_) {
                            setState(() {
                              _checklistStatus[spec.id] = opt;
                            });
                          },
                        );
                      },
                    ).toList(),
                  ),
                  if (status == PhysicalDeviceChecklistStatus.fail) ...<Widget>[
                    const SizedBox(height: 8),
                    TextField(
                      key: ValueKey<String>('checklist_notes_${spec.id}'),
                      controller: _failNoteControllers[spec.id],
                      decoration: const InputDecoration(
                        labelText: 'Notes (FAIL observation)',
                        hintText: 'Describe physical device issue observed...',
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
          },
        ).toList(),
      ),
    );
  }
}
