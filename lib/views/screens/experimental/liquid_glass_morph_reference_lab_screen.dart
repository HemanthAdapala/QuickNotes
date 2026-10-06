import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

/// Phase 8B: Controlled Native Reference Laboratory for `LiquidGlassMorph`
/// from `liquid_glass_easy 4.3.1`.
///
/// Uses the actual package `LiquidGlassMorph`, `LiquidGlassMorphMotion`,
/// and `LiquidGlassMorphAdvanced` directly with zero custom morph recreation.
enum MorphReferencePreset {
  fluid('fluid', LiquidGlassMorphMotion.fluid),
  anchoredPop('anchoredPop', LiquidGlassMorphMotion.anchoredPop),
  plain('plain', LiquidGlassMorphMotion.plain),
  droplet('droplet', LiquidGlassMorphMotion.droplet),
  calm('calm', LiquidGlassMorphMotion.calm);

  const MorphReferencePreset(this.label, this.motion);
  final String label;
  final LiquidGlassMorphMotion motion;
}

enum MorphReferenceStateId {
  stateA('STATE A'),
  stateB('STATE B'),
  stateC('STATE C');

  const MorphReferenceStateId(this.label);
  final String label;
}

enum MorphReferenceAnchorOption {
  center('Center', Alignment.center),
  topLeft('TopLeft', Alignment.topLeft),
  topRight('TopRight', Alignment.topRight),
  bottomLeft('BottomLeft', Alignment.bottomLeft),
  bottomRight('BottomRight', Alignment.bottomRight);

  const MorphReferenceAnchorOption(this.label, this.alignment);
  final String label;
  final Alignment alignment;
}

enum MorphTopologyExperimentMode {
  sizeAndPosition('Size + Position'),
  sizeOnly('Size Only'),
  positionOnly('Position Only');

  const MorphTopologyExperimentMode(this.label);
  final String label;
}

enum MorphShapeExperimentOption {
  capsuleAuto('Capsule (null)'),
  rounded16('Rounded 16px'),
  rounded28('Rounded 28px'),
  superellipse28('Superellipse 28px');

  const MorphShapeExperimentOption(this.label);
  final String label;
}

class LiquidGlassMorphReferenceLabScreen extends StatefulWidget {
  const LiquidGlassMorphReferenceLabScreen({super.key});

  @override
  State<LiquidGlassMorphReferenceLabScreen> createState() =>
      _LiquidGlassMorphReferenceLabScreenState();
}

class _LiquidGlassMorphReferenceLabScreenState
    extends State<LiquidGlassMorphReferenceLabScreen> {
  // ── Active Target State ─────────────────────────────────────────────
  MorphReferenceStateId _currentState = MorphReferenceStateId.stateA;
  MorphReferenceStateId _previousState = MorphReferenceStateId.stateB;

  // ── Canonical Baseline & Tunable Parameters ─────────────────────────
  MorphReferencePreset _selectedPreset = MorphReferencePreset.fluid;
  MorphReferenceAnchorOption _selectedAnchor =
      MorphReferenceAnchorOption.center;
  bool _useNullMotionAnchor = false;
  bool _blended = LiquidGlassMorphMotion.fluid.blended;
  bool _liteGlassEnabled = false;
  bool _debugClipBounds = false;
  final bool _labScrollingEnabled = true;

  MorphTopologyExperimentMode _topologyMode =
      MorphTopologyExperimentMode.sizeAndPosition;
  MorphShapeExperimentOption _shapeOption =
      MorphShapeExperimentOption.rounded28;

  double _stiffness = LiquidGlassMorphMotion.fluid.stiffness;
  double _damping = LiquidGlassMorphMotion.fluid.damping;
  double _stretch = LiquidGlassMorphMotion.fluid.stretch;
  double _smoothness = 40.0;

  double _leadBounce = LiquidGlassMorphMotion.fluid.advanced.leadBounce;
  double _followDelay = LiquidGlassMorphMotion.fluid.advanced.followDelay;
  double _seedScale = LiquidGlassMorphMotion.fluid.advanced.seedScale;
  double _linger = LiquidGlassMorphMotion.fluid.advanced.linger;
  double _drainSpeed = LiquidGlassMorphMotion.fluid.advanced.drainSpeed;
  double _drainInward = LiquidGlassMorphMotion.fluid.advanced.drainInward;
  bool _sourceFollows = LiquidGlassMorphMotion.fluid.advanced.sourceFollows;
  double _neckRamp = LiquidGlassMorphMotion.fluid.advanced.neckRamp;

  double _contentFollow = LiquidGlassMorphMotion.fluid.advanced.contentFollow;
  double _contentSlide = LiquidGlassMorphMotion.fluid.advanced.contentSlide;
  double _contentBlur = LiquidGlassMorphMotion.fluid.advanced.contentBlur;

  int _settleCount = 0;
  final List<Timer> _sequenceTimers = <Timer>[];

  @override
  void dispose() {
    _cancelTimers();
    if (_liteGlassEnabled) {
      LiquidGlassEngine.liteGlassOnSkia = false;
      LiquidGlassEngine.liteGlassOnImpeller = false;
    }
    super.dispose();
  }

  void _cancelTimers() {
    for (final Timer t in _sequenceTimers) {
      t.cancel();
    }
    _sequenceTimers.clear();
  }

  void _applyPreset(MorphReferencePreset preset) {
    _cancelTimers();
    final LiquidGlassMorphMotion m = preset.motion;
    final LiquidGlassMorphAdvanced a = m.advanced;
    setState(() {
      _selectedPreset = preset;
      _stiffness = m.stiffness;
      _damping = m.damping;
      _stretch = m.stretch;
      _blended = m.blended;
      _useNullMotionAnchor = m.anchor == null;
      _leadBounce = a.leadBounce;
      _followDelay = a.followDelay;
      _seedScale = a.seedScale;
      _linger = a.linger;
      _drainSpeed = a.drainSpeed;
      _drainInward = a.drainInward;
      _sourceFollows = a.sourceFollows;
      _neckRamp = a.neckRamp;
      _contentFollow = a.contentFollow;
      _contentSlide = a.contentSlide;
      _contentBlur = a.contentBlur;
    });
  }

  void _setLiteGlass(bool enabled) {
    setState(() {
      _liteGlassEnabled = enabled;
      LiquidGlassEngine.liteGlassOnSkia = enabled;
      LiquidGlassEngine.liteGlassOnImpeller = enabled;
    });
  }

  void _transitionTo(MorphReferenceStateId next) {
    if (_currentState == next) return;
    setState(() {
      _previousState = _currentState;
      _currentState = next;
    });
  }

  void _runAToB() {
    _cancelTimers();
    if (_currentState != MorphReferenceStateId.stateA) {
      setState(() {
        _previousState = _currentState;
        _currentState = MorphReferenceStateId.stateA;
      });
      _sequenceTimers.add(
        Timer(const Duration(milliseconds: 30), () {
          if (!mounted) return;
          _transitionTo(MorphReferenceStateId.stateB);
        }),
      );
    } else {
      _transitionTo(MorphReferenceStateId.stateB);
    }
  }

  void _runBToA() {
    _cancelTimers();
    if (_currentState != MorphReferenceStateId.stateB) {
      setState(() {
        _previousState = _currentState;
        _currentState = MorphReferenceStateId.stateB;
      });
      _sequenceTimers.add(
        Timer(const Duration(milliseconds: 30), () {
          if (!mounted) return;
          _transitionTo(MorphReferenceStateId.stateA);
        }),
      );
    } else {
      _transitionTo(MorphReferenceStateId.stateA);
    }
  }

  void _runAToBToCSequential() {
    _cancelTimers();
    setState(() {
      _previousState = _currentState;
      _currentState = MorphReferenceStateId.stateA;
    });
    _sequenceTimers.add(
      Timer(const Duration(milliseconds: 40), () {
        if (!mounted) return;
        _transitionTo(MorphReferenceStateId.stateB);
      }),
    );
    _sequenceTimers.add(
      Timer(const Duration(milliseconds: 520), () {
        if (!mounted) return;
        _transitionTo(MorphReferenceStateId.stateC);
      }),
    );
  }

  /// Mandatory Interruption Test 1: A -> B, then before completion B -> A.
  void _runInterruptABA() {
    _cancelTimers();
    setState(() {
      _previousState = _currentState;
      _currentState = MorphReferenceStateId.stateA;
    });
    _sequenceTimers.add(
      Timer(const Duration(milliseconds: 30), () {
        if (!mounted) return;
        _transitionTo(MorphReferenceStateId.stateB);
      }),
    );
    _sequenceTimers.add(
      Timer(const Duration(milliseconds: 150), () {
        if (!mounted) return;
        _transitionTo(MorphReferenceStateId.stateA);
      }),
    );
  }

  /// Mandatory Interruption Test 2: A -> B, then mid-transition retarget B -> C.
  void _runRetargetABC() {
    _cancelTimers();
    setState(() {
      _previousState = _currentState;
      _currentState = MorphReferenceStateId.stateA;
    });
    _sequenceTimers.add(
      Timer(const Duration(milliseconds: 30), () {
        if (!mounted) return;
        _transitionTo(MorphReferenceStateId.stateB);
      }),
    );
    _sequenceTimers.add(
      Timer(const Duration(milliseconds: 150), () {
        if (!mounted) return;
        _transitionTo(MorphReferenceStateId.stateC);
      }),
    );
  }

  /// Mandatory Rapid Repeated State Changes: A -> B -> A -> B -> A.
  void _runRapidBurstABABA() {
    _cancelTimers();
    setState(() {
      _previousState = _currentState;
      _currentState = MorphReferenceStateId.stateA;
    });
    const List<MorphReferenceStateId> burst = <MorphReferenceStateId>[
      MorphReferenceStateId.stateB,
      MorphReferenceStateId.stateA,
      MorphReferenceStateId.stateB,
      MorphReferenceStateId.stateA,
    ];
    for (int i = 0; i < burst.length; i++) {
      _sequenceTimers.add(
        Timer(Duration(milliseconds: 70 * (i + 1)), () {
          if (!mounted) return;
          _transitionTo(burst[i]);
        }),
      );
    }
  }

  void _runReverseImmediate() {
    _cancelTimers();
    final MorphReferenceStateId target =
        _currentState == MorphReferenceStateId.stateA
            ? MorphReferenceStateId.stateB
            : (_previousState == _currentState
                ? MorphReferenceStateId.stateA
                : _previousState);
    _transitionTo(target);
  }

  void _resetToBaseline() {
    _cancelTimers();
    _setLiteGlass(false);
    setState(() {
      _currentState = MorphReferenceStateId.stateA;
      _previousState = MorphReferenceStateId.stateB;
      _selectedPreset = MorphReferencePreset.fluid;
      _selectedAnchor = MorphReferenceAnchorOption.center;
      _useNullMotionAnchor = false;
      _blended = LiquidGlassMorphMotion.fluid.blended;
      _debugClipBounds = false;
      _topologyMode = MorphTopologyExperimentMode.sizeAndPosition;
      _shapeOption = MorphShapeExperimentOption.rounded28;

      _stiffness = LiquidGlassMorphMotion.fluid.stiffness;
      _damping = LiquidGlassMorphMotion.fluid.damping;
      _stretch = LiquidGlassMorphMotion.fluid.stretch;
      _smoothness = 40.0;

      final LiquidGlassMorphAdvanced a = LiquidGlassMorphMotion.fluid.advanced;
      _leadBounce = a.leadBounce;
      _followDelay = a.followDelay;
      _seedScale = a.seedScale;
      _linger = a.linger;
      _drainSpeed = a.drainSpeed;
      _drainInward = a.drainInward;
      _sourceFollows = a.sourceFollows;
      _neckRamp = a.neckRamp;
      _contentFollow = a.contentFollow;
      _contentSlide = a.contentSlide;
      _contentBlur = a.contentBlur;
      _settleCount = 0;
    });
  }

  LiquidGlassMorphMotion _buildEffectiveMotion() {
    return LiquidGlassMorphMotion(
      stiffness: _stiffness,
      damping: _damping,
      stretch: _stretch,
      anchor: _useNullMotionAnchor ? null : _selectedAnchor.alignment,
      blended: _blended,
      advanced: LiquidGlassMorphAdvanced(
        leadBounce: _leadBounce,
        followDelay: _followDelay,
        seedScale: _seedScale,
        linger: _linger,
        drainSpeed: _drainSpeed,
        drainInward: _drainInward,
        sourceFollows: _sourceFollows,
        neckRamp: _neckRamp,
        contentFollow: _contentFollow,
        contentSlide: _contentSlide,
        contentBlur: _contentBlur,
      ),
    );
  }

  Alignment _stateSpatialAlignment(MorphReferenceStateId state) {
    switch (state) {
      case MorphReferenceStateId.stateA:
        return const Alignment(-0.62, -0.52);
      case MorphReferenceStateId.stateB:
        return const Alignment(0.38, 0.36);
      case MorphReferenceStateId.stateC:
        return const Alignment(-0.38, 0.54);
    }
  }

  Alignment _buildEffectiveWidgetAlignment() {
    switch (_topologyMode) {
      case MorphTopologyExperimentMode.sizeOnly:
        return _selectedAnchor.alignment;
      case MorphTopologyExperimentMode.positionOnly:
        return _stateSpatialAlignment(_currentState);
      case MorphTopologyExperimentMode.sizeAndPosition:
        if (_selectedAnchor != MorphReferenceAnchorOption.center ||
            _useNullMotionAnchor) {
          return _selectedAnchor.alignment;
        }
        return _stateSpatialAlignment(_currentState);
    }
  }

  LiquidGlassShape? _buildEffectiveShape() {
    switch (_shapeOption) {
      case MorphShapeExperimentOption.capsuleAuto:
        return null;
      case MorphShapeExperimentOption.rounded16:
        return const LiquidGlassShape.roundedRectangle(
          cornerRadius: 16,
          borderWidth: 1.1,
          lightIntensity: 1.2,
        );
      case MorphShapeExperimentOption.rounded28:
        return const LiquidGlassShape.roundedRectangle(
          cornerRadius: 28,
          borderWidth: 1.1,
          lightIntensity: 1.2,
        );
      case MorphShapeExperimentOption.superellipse28:
        return const LiquidGlassShape.continuousRoundedRectangle(
          cornerRadius: 28,
          borderWidth: 1.1,
          lightIntensity: 1.2,
        );
    }
  }

  LiquidGlassStyle _buildEffectiveStyle() {
    return LiquidGlassStyle(
      shape: _buildEffectiveShape(),
      appearance: const LiquidGlassAppearance(
        color: Color(0x24FFFFFF),
        blur: LiquidGlassBlur(sigmaX: 4, sigmaY: 4),
      ),
      refraction: const LiquidGlassRefraction(
        distortion: 0.08,
        distortionWidth: 22,
        chromaticAberration: 0.002,
      ),
      liteGlass: _liteGlassEnabled ? LiquidGlassLitePickup.backdrop : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final LiquidGlassMorphMotion effectiveMotion = _buildEffectiveMotion();
    final double leadMul = 1.0 + 2.2 * effectiveMotion.stretch;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0D14),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool isWide = constraints.maxWidth >= 860;
            return Column(
              children: <Widget>[
                _buildHeaderBar(context, effectiveMotion, leadMul),
                Expanded(
                  child: isWide
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(
                                flex: 6,
                                child: _buildPreviewStage(effectiveMotion),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                flex: 5,
                                child: SingleChildScrollView(
                                  key: const ValueKey('morph_lab_scroll_view'),
                                  physics: _labScrollingEnabled
                                      ? const AlwaysScrollableScrollPhysics()
                                      : const NeverScrollableScrollPhysics(),
                                  child: _buildControlPanel(),
                                ),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          key: const ValueKey('morph_lab_scroll_view'),
                          physics: _labScrollingEnabled
                              ? const AlwaysScrollableScrollPhysics()
                              : const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              _buildPreviewStage(effectiveMotion),
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

  Widget _buildHeaderBar(
    BuildContext context,
    LiquidGlassMorphMotion motion,
    double leadMul,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF131622),
        border: Border(
          bottom: BorderSide(color: Color(0xFF23283D)),
        ),
      ),
      child: Row(
        children: <Widget>[
          InkWell(
            key: const ValueKey('morph_lab_back_button'),
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
                  'LIQUID GLASS MORPH — NATIVE REFERENCE LAB',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'PHASE 8B • liquid_glass_easy 4.3.1 • T=${motion.duration.toStringAsFixed(2)}s • ζ=${motion.zeta.toStringAsFixed(2)} • leadMul=${leadMul.toStringAsFixed(2)}x • settled=$_settleCount',
                  key: const ValueKey('morph_lab_telemetry_text'),
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
              border: Border.all(color: const Color(0xFF38BDF8)),
            ),
            child: Text(
              _currentState.label,
              key: const ValueKey('morph_lab_current_state_badge'),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF38BDF8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewStage(LiquidGlassMorphMotion motion) {
    final double? overrideWidth =
        _topologyMode == MorphTopologyExperimentMode.positionOnly ? 156.0 : null;
    final double? overrideHeight =
        _topologyMode == MorphTopologyExperimentMode.positionOnly ? 56.0 : null;

    return Container(
      key: const ValueKey('morph_preview_stage_container'),
      height: 340,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF262D45)),
      ),
      clipBehavior: Clip.antiAlias,
      child: LiquidGlassView(
        backgroundWidget: _buildRichStageBackground(),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: LiquidGlassMorph(
            key: const ValueKey('native_liquid_glass_morph'),
            width: overrideWidth,
            height: overrideHeight,
            alignment: _buildEffectiveWidgetAlignment(),
            motion: motion,
            smoothness: _smoothness,
            style: _buildEffectiveStyle(),
            debugClipBounds: _debugClipBounds,
            onEnd: () {
              if (!mounted) return;
              setState(() {
                _settleCount++;
              });
            },
            child: _buildActiveStateChild(),
          ),
        ),
      ),
    );
  }

  Widget _buildRichStageBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF0F172A),
            Color(0xFF1E1B4B),
            Color(0xFF311042),
            Color(0xFF0F172A),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned(
            left: -30,
            top: -20,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    const Color(0xFF38BDF8).withAlpha(115),
                    const Color(0xFF38BDF8).withAlpha(0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: -20,
            bottom: -30,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    const Color(0xFFF43F5E).withAlpha(115),
                    const Color(0xFFF43F5E).withAlpha(0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 90,
            bottom: 40,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    const Color(0xFFA855F7).withAlpha(100),
                    const Color(0xFFA855F7).withAlpha(0),
                  ],
                ),
              ),
            ),
          ),
          // High-contrast reference grid lines so refraction & lens waist are clearly visible
          IgnorePointer(
            child: CustomPaint(
              painter: _ReferenceGridPainter(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveStateChild() {
    final bool shiftPosition =
        _topologyMode == MorphTopologyExperimentMode.sizeAndPosition ||
            _topologyMode == MorphTopologyExperimentMode.positionOnly;

    switch (_currentState) {
      case MorphReferenceStateId.stateA:
        return SizedBox(
          key: const ValueKey('morph_child_state_a'),
          width: 128,
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Color(0xFF38BDF8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mail_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Inbox A',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

      case MorphReferenceStateId.stateB:
        return SizedBox(
          key: const ValueKey('morph_child_state_b'),
          width: 268,
          height: 176,
          child: Padding(
            padding: EdgeInsets.fromLTRB(18, shiftPosition ? 16 : 14, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withAlpha(60),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.mark_email_unread_rounded,
                        size: 18,
                        color: Color(0xFF38BDF8),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Inbox B',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '12 unread messages',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Flexible(
                  child: Text(
                    'LiquidGlassMorph native two-blob smooth-union transition preview.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white70,
                      height: 1.25,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(36),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Open Thread',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

      case MorphReferenceStateId.stateC:
        return SizedBox(
          key: const ValueKey('morph_child_state_c'),
          width: 216,
          height: 96,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF43F5E).withAlpha(70),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.archive_rounded,
                    size: 18,
                    color: Color(0xFFF43F5E),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'State C • Pinned',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '3 threads archived',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
    }
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
                key: const ValueKey('action_a_to_b'),
                label: 'A → B',
                onTap: _runAToB,
              ),
              _buildActionButton(
                key: const ValueKey('action_b_to_a'),
                label: 'B → A',
                onTap: _runBToA,
              ),
              _buildActionButton(
                key: const ValueKey('action_a_to_b_to_c'),
                label: 'A → B → C',
                onTap: _runAToBToCSequential,
              ),
              _buildActionButton(
                key: const ValueKey('action_interrupt_aba'),
                label: 'INTERRUPT (A→B→A)',
                onTap: _runInterruptABA,
              ),
              _buildActionButton(
                key: const ValueKey('action_retarget_abc'),
                label: 'RETARGET (A→B→C)',
                onTap: _runRetargetABC,
              ),
              _buildActionButton(
                key: const ValueKey('action_rapid_burst'),
                label: 'RAPID BURST',
                onTap: _runRapidBurstABABA,
              ),
              _buildActionButton(
                key: const ValueKey('action_reverse'),
                label: 'REVERSE',
                onTap: _runReverseImmediate,
              ),
              _buildActionButton(
                key: const ValueKey('action_reset'),
                label: 'RESET',
                isAccent: true,
                onTap: _resetToBaseline,
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFF23283D)),

          // ── Direct State Selector ───────────────────────────────────────
          _buildSectionHeader('DIRECT STATE TARGET'),
          const SizedBox(height: 8),
          Row(
            children: MorphReferenceStateId.values.map((MorphReferenceStateId s) {
              final bool selected = _currentState == s;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    key: ValueKey('select_${s.name}'),
                    onTap: () {
                      _cancelTimers();
                      _transitionTo(s);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF0284C7)
                            : const Color(0xFF1C2030),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF38BDF8)
                              : const Color(0xFF2E3550),
                        ),
                      ),
                      child: Text(
                        s.label,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const Divider(height: 24, color: Color(0xFF23283D)),

          // ── Motion Preset Selector (All 5 Official 4.3.1 Presets) ───────
          _buildSectionHeader('MOTION PRESET (4.3.1 OFFICIAL)'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: MorphReferencePreset.values.map((MorphReferencePreset p) {
              final bool selected = _selectedPreset == p;
              return ChoiceChip(
                key: ValueKey('preset_chip_${p.name}'),
                label: Text(p.label),
                selected: selected,
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

          // ── Mode Switches (Blended, Lite Glass, Debug Clip) ─────────────
          _buildSectionHeader('GLASS & BLENDER MODES'),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: _buildToggleTile(
                  key: const ValueKey('toggle_blended'),
                  label: 'Blended',
                  value: _blended,
                  onChanged: (bool val) => setState(() => _blended = val),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildToggleTile(
                  key: const ValueKey('toggle_lite_glass'),
                  label: 'Lite Glass',
                  value: _liteGlassEnabled,
                  onChanged: _setLiteGlass,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildToggleTile(
                  key: const ValueKey('toggle_debug_clip'),
                  label: 'Clip Bounds',
                  value: _debugClipBounds,
                  onChanged: (bool val) =>
                      setState(() => _debugClipBounds = val),
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFF23283D)),

          // ── Anchor Selector ─────────────────────────────────────────────
          _buildSectionHeader('ANCHOR / ALIGNMENT'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                MorphReferenceAnchorOption.values.map((MorphReferenceAnchorOption a) {
              final bool selected = _selectedAnchor == a;
              return ChoiceChip(
                key: ValueKey('anchor_chip_${a.name}'),
                label: Text(a.label),
                selected: selected,
                onSelected: (_) => setState(() => _selectedAnchor = a),
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

          // ── Topology & Shape Selectors ──────────────────────────────────
          _buildSectionHeader('TOPOLOGY & SHAPE OVERRIDES'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: MorphTopologyExperimentMode.values
                .map((MorphTopologyExperimentMode m) {
              final bool selected = _topologyMode == m;
              return ChoiceChip(
                key: ValueKey('topology_chip_${m.name}'),
                label: Text(m.label),
                selected: selected,
                onSelected: (_) => setState(() => _topologyMode = m),
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
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: MorphShapeExperimentOption.values
                .map((MorphShapeExperimentOption s) {
              final bool selected = _shapeOption == s;
              return ChoiceChip(
                key: ValueKey('shape_chip_${s.name}'),
                label: Text(s.label),
                selected: selected,
                onSelected: (_) => setState(() => _shapeOption = s),
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

          // ── Physics & Content Sliders ───────────────────────────────────
          _buildSectionHeader('MORPH MOTION & ADVANCED PARAMETERS'),
          _buildSliderRow(
            sliderKey: const ValueKey('slider_stretch'),
            label: 'Stretch',
            value: _stretch,
            min: 0.0,
            max: 1.0,
            onChanged: (double v) => setState(() => _stretch = v),
          ),
          _buildSliderRow(
            sliderKey: const ValueKey('slider_lead_bounce'),
            label: 'Lead Bounce',
            value: _leadBounce,
            min: 0.0,
            max: 0.30,
            onChanged: (double v) => setState(() => _leadBounce = v),
          ),
          _buildSliderRow(
            sliderKey: const ValueKey('slider_follow_delay'),
            label: 'Follow Delay (s)',
            value: _followDelay,
            min: 0.0,
            max: 0.18,
            onChanged: (double v) => setState(() => _followDelay = v),
          ),
          _buildSliderRow(
            sliderKey: const ValueKey('slider_seed_scale'),
            label: 'Seed Scale',
            value: _seedScale,
            min: 0.20,
            max: 1.0,
            onChanged: (double v) => setState(() => _seedScale = v),
          ),
          _buildSliderRow(
            sliderKey: const ValueKey('slider_content_follow'),
            label: 'Content Follow',
            value: _contentFollow,
            min: 0.0,
            max: 1.0,
            onChanged: (double v) => setState(() => _contentFollow = v),
          ),
          _buildSliderRow(
            sliderKey: const ValueKey('slider_content_slide'),
            label: 'Content Slide (px)',
            value: _contentSlide,
            min: -24.0,
            max: 24.0,
            onChanged: (double v) => setState(() => _contentSlide = v),
          ),
          _buildSliderRow(
            sliderKey: const ValueKey('slider_content_blur'),
            label: 'Content Blur (px)',
            value: _contentBlur,
            min: 0.0,
            max: 16.0,
            onChanged: (double v) => setState(() => _contentBlur = v),
          ),
          _buildSliderRow(
            sliderKey: const ValueKey('slider_smoothness'),
            label: 'Smoothness (px)',
            value: _smoothness,
            min: 0.0,
            max: 64.0,
            onChanged: (double v) => setState(() => _smoothness = v),
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

  Widget _buildToggleTile({
    required Key key,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      key: key,
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: value ? const Color(0xFF0369A1) : const Color(0xFF1C2030),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: value ? const Color(0xFF38BDF8) : const Color(0xFF2E3550),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            Text(
              value ? 'ON' : 'OFF',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: value ? const Color(0xFF7DD3FC) : Colors.white54,
              ),
            ),
          ],
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

class _ReferenceGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white.withAlpha(18)
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
