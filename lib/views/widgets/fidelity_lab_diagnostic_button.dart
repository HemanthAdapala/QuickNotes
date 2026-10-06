import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../screens/experimental/liquid_glass_morph_content_lab_screen.dart'
    show
        QuickNotesEvaluatedContentLayer,
        QuickNotesMorphContentConfig,
        QuickNotesMorphContentController,
        QuickNotesMorphContentSnapshot;
import '../screens/experimental/liquid_glass_morph_fidelity_lab_screen.dart'
    show
        MorphFidelityChoreographyAdapter,
        MorphFidelityChoreographyVariant,
        MorphFidelitySpatialMode,
        MorphFidelityStateId,
        MorphFidelityStateMapping,
        QuickNotesStateMapping;
import '../screens/experimental/liquid_glass_morph_mechanics_lab_screen.dart'
    show
        QuickNotesMorphAnchorOption,
        QuickNotesMorphGeometryConfig,
        QuickNotesMorphGeometryController;
import 'app_bottom_navigation_bar.dart' show BottomBarGlassSurface;

/// Temporary diagnostic button hosting the EXACT physically-validated
/// Liquid Glass Morph Fidelity Lab implementation directly inside SettingsScreen.
///
/// This component is strictly visual/diagnostic and isolated from Settings
/// business and application state.
class FidelityLabDiagnosticMorphButton extends StatefulWidget {
  const FidelityLabDiagnosticMorphButton({super.key});

  @override
  State<FidelityLabDiagnosticMorphButton> createState() =>
      _FidelityLabDiagnosticMorphButtonState();
}

class _FidelityLabDiagnosticMorphButtonState
    extends State<FidelityLabDiagnosticMorphButton>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastTickElapsed = Duration.zero;

  final QuickNotesMorphGeometryController _geometryController =
      QuickNotesMorphGeometryController(
    initialRect: const Rect.fromLTWH(168, 0, 56, 56),
  );
  late final MorphFidelityChoreographyAdapter _choreographyAdapter =
      MorphFidelityChoreographyAdapter(_geometryController);
  final QuickNotesMorphContentController _contentController =
      QuickNotesMorphContentController();

  // ── Exact Lab Baseline Configuration (Source of Truth from Lab) ─────────
  MorphFidelityStateId _targetState = MorphFidelityStateId.circle;
  final MorphFidelitySpatialMode _spatialMode =
      MorphFidelitySpatialMode.withPosition;
  final MorphFidelityChoreographyVariant _choreographyVariant =
      MorphFidelityChoreographyVariant.baseline;
  final QuickNotesMorphAnchorOption _selectedAnchor =
      QuickNotesMorphAnchorOption.topRight;

  static const double _stretch = 0.75;
  static const double _leadBounce = 0.10;
  static const int _followDelayMs = 40;
  static const double _contentBlur = 8.0;
  static const double _contentFollow = 1.0;
  static const double _contentSlide = 0.0;
  static const double _baseStiffness = 195.0;
  static const double _baseDamping = 19.5;
  static const double kTargetCardCornerRadius = 28.0;

  static const Size _stageFieldSize = Size(224, 184);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    final Rect initialRect = _resolveStateRect(MorphFidelityStateId.circle);
    _geometryController.seedInitialRect(
      initialRect,
      anchor: _selectedAnchor.alignment,
    );
    _contentController.seedInitialState(
      stateId: MorphFidelityStateId.circle.toPhase8CStateId(),
      stateRect: initialRect,
      stiffness: _baseStiffness,
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  Rect _resolveStateRect(MorphFidelityStateId state) {
    const Rect stageBounds = Rect.fromLTWH(0, 0, 224, 184);
    return Alignment.topRight.inscribe(state.size, stageBounds);
  }

  QuickNotesMorphGeometryConfig _buildEffectiveGeometryConfig(
    MorphFidelityStateId targetState,
  ) {
    return _choreographyAdapter.resolveConfig(
      variant: _choreographyVariant,
      baseStiffness: _baseStiffness,
      baseDamping: _baseDamping,
      userStretch: _stretch,
      userLeadBounce: _leadBounce,
      userFollowDelayMs: _followDelayMs,
      selectedAnchor: _selectedAnchor.alignment,
      placementAlignment: _selectedAnchor.alignment,
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

    final QuickNotesMorphGeometryConfig geomConfig =
        _buildEffectiveGeometryConfig(_targetState);
    final QuickNotesMorphContentConfig contentConfig = _buildContentConfig();

    final bool geomActive = _choreographyAdapter.step(rawDtSeconds, geomConfig);
    final bool contentActive =
        _contentController.step(rawDtSeconds, contentConfig);

    if (!geomActive && !contentActive) {
      _ticker.stop();
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _triggerMorphTo(MorphFidelityStateId nextState) {
    final Rect currentLiveRect = _geometryController.currentRect;
    final Rect toRect = _resolveStateRect(nextState);
    final QuickNotesMorphGeometryConfig geomConfig =
        _buildEffectiveGeometryConfig(nextState);
    final QuickNotesMorphContentConfig contentConfig = _buildContentConfig();

    setState(() {
      _targetState = nextState;

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

  void _handleTap() {
    final MorphFidelityStateId next =
        (_targetState == MorphFidelityStateId.circle)
            ? MorphFidelityStateId.square
            : MorphFidelityStateId.circle;
    _triggerMorphTo(next);
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
      key: ValueKey<String>('lab_diag_content_${roleKey}_${state.name}'),
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
          key: const ValueKey<String>('lab_diag_state_circle_content'),
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
          key: const ValueKey<String>('lab_diag_state_square_content'),
          padding: const EdgeInsets.all(12.0),
          child: Column(
            key: const ValueKey<String>('lab_diag_options_grouped_column'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: Container(
                  key: const ValueKey<String>('lab_diag_options_container'),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(18.0),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.28),
                      width: 1.0,
                    ),
                  ),
                  child: Column(
                    children: <Widget>[
                      Expanded(
                        child: _buildOptionTile(
                          key: const ValueKey<String>('lab_diag_option_a'),
                          icon: Icons.check_circle_outline_rounded,
                          title: 'Option A',
                          subtitle: 'First diagnostic action',
                        ),
                      ),
                      Divider(
                        height: 1.0,
                        thickness: 1.0,
                        color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                      ),
                      Expanded(
                        child: _buildOptionTile(
                          key: const ValueKey<String>('lab_diag_option_b'),
                          icon: Icons.radio_button_checked_rounded,
                          title: 'Option B',
                          subtitle: 'Second diagnostic action',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      case MorphFidelityStateId.alternate:
        return const SizedBox.shrink();
    }
  }

  Widget _buildOptionTile({
    required Key key,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 36.0,
            height: 36.0,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 20.0,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.0,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2.0),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF0F172A).withValues(alpha: 0.65),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Rect liveRect = _geometryController.currentRect;
    final QuickNotesMorphContentConfig contentConfig = _buildContentConfig();
    final double effectiveRadius = _effectiveCornerRadiusForRect(liveRect);

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

    return SizedBox(
      key: const ValueKey<String>('fidelity_lab_diagnostic_container'),
      width: _stageFieldSize.width,
      height: _stageFieldSize.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(
            key: const ValueKey<String>('fidelity_lab_diagnostic_glass_pos'),
            left: clampedRect.left,
            top: clampedRect.top,
            width: clampedRect.width,
            height: clampedRect.height,
            child: GestureDetector(
              key: const ValueKey<String>('fidelity_lab_diagnostic_gesture'),
              behavior: HitTestBehavior.opaque,
              onTap: _handleTap,
              child: BottomBarGlassSurface(
                key: const ValueKey<String>(
                  'fidelity_lab_diagnostic_glass_surface',
                ),
                width: clampedRect.width,
                height: clampedRect.height,
                borderRadius: BorderRadius.circular(effectiveRadius),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(effectiveRadius),
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
          ),
        ],
      ),
    );
  }
}
