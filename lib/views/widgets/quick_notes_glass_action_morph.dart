import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/motion/quick_notes_haptics.dart';
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
    show QuickNotesMorphGeometryConfig, QuickNotesMorphGeometryController;
import 'app_bottom_navigation_bar.dart' show BottomBarGlassSurface;

/// Generic, decoupled action data model for glass action surfaces.
///
/// Contains purely visual/presentation properties and action identity [id].
/// Contains ZERO application or business logic.
@immutable
class QuickNotesGlassAction<T> {
  const QuickNotesGlassAction({
    required this.id,
    required this.label,
    this.iconPath,
    this.iconData,
    this.subtitle,
    this.textColor,
    this.iconColor,
    this.isDestructive = false,
  });

  /// The caller-defined action identifier (e.g. enum, string, or typed action).
  final T id;

  /// Primary label displayed for this action item.
  final String label;

  /// Optional SVG asset path for the action icon.
  final String? iconPath;

  /// Optional [IconData] for the action icon (if not using an SVG asset).
  final IconData? iconData;

  /// Optional supporting subtitle text.
  final String? subtitle;

  /// Text color override. If omitted, defaults to [QuickNotesGlassActionMorph.defaultTextColor].
  final Color? textColor;

  /// Icon tint color override. If omitted, defaults to [textColor].
  final Color? iconColor;

  /// Whether this action represents a destructive operation.
  final bool isDestructive;
}

/// A production-safe reusable visual presentation component for Quick Notes
/// glass action surfaces, powered by the physically validated Morph Fidelity
/// spring and choreography engine.
///
/// This component is responsible ONLY for the visual presentation and Morph motion
/// mechanics between collapsed (trigger button) and expanded (action surface) states.
/// It receives visual state externally and reports user selections upward via
/// [onActionSelected].
///
/// It contains ZERO knowledge of:
/// - SettingsScreen
/// - Settings business logic
/// - Specific application actions (delete, refresh, theme, etc.)
/// - External screen/application state
class QuickNotesGlassActionMorph<T> extends StatefulWidget {
  const QuickNotesGlassActionMorph({
    super.key,
    this.actions = const [],
    this.onActionSelected,
    this.isExpanded = false,
    this.onTriggerTap,
    this.triggerChild,
    this.expandedChild,
    this.width = 192.0,
    this.height = 100.0,
    this.collapsedWidth = 44.0,
    this.collapsedHeight = 44.0,
    this.collapsedRadius = 22.0,
    this.expandedRadius = 20.0,
    this.itemHeight = 50.0,
    this.dividerColor,
    this.defaultTextColor,
    this.anchor = Alignment.topRight,
    this.onTransitionEnd,
  });

  /// Action definitions to display on this glass action surface.
  final List<QuickNotesGlassAction<T>> actions;

  /// Callback invoked when the user selects an action. Reports the action's [id].
  final ValueChanged<T>? onActionSelected;

  /// Whether the action surface is currently expanded.
  final bool isExpanded;

  /// Callback invoked when the collapsed surface is tapped to request expansion.
  final VoidCallback? onTriggerTap;

  /// Optional custom widget to render in the collapsed state. Defaults to a 3-dot trigger.
  final Widget? triggerChild;

  /// Optional custom widget to render in the expanded state. Defaults to [actions] list.
  final Widget? expandedChild;

  /// Total width of the expanded action surface.
  final double width;

  /// Total height of the expanded action surface.
  final double height;

  /// Width of the collapsed trigger button.
  final double collapsedWidth;

  /// Height of the collapsed trigger button.
  final double collapsedHeight;

  /// Corner radius of the collapsed trigger button.
  final double collapsedRadius;

  /// Corner radius of the expanded action card.
  final double expandedRadius;

  /// Height allocated to each individual action tile.
  final double itemHeight;

  /// Color used for the divider border between action tiles.
  final Color? dividerColor;

  /// Default text color for action labels.
  final Color? defaultTextColor;

  /// Anchor alignment for spatial inscribe geometry.
  final Alignment anchor;

  /// Callback invoked when the Morph spring and content transition settle.
  final VoidCallback? onTransitionEnd;

  @override
  State<QuickNotesGlassActionMorph<T>> createState() =>
      _QuickNotesGlassActionMorphState<T>();
}

class _QuickNotesGlassActionMorphState<T>
    extends State<QuickNotesGlassActionMorph<T>>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastTickElapsed = Duration.zero;

  late final QuickNotesMorphGeometryController _geometryController;
  late final MorphFidelityChoreographyAdapter _choreographyAdapter;
  final QuickNotesMorphContentController _contentController =
      QuickNotesMorphContentController();

  // ── Exact Validated Morph Fidelity Baseline Configuration ────────────────
  late MorphFidelityStateId _targetState;
  final MorphFidelitySpatialMode _spatialMode =
      MorphFidelitySpatialMode.withPosition;
  final MorphFidelityChoreographyVariant _choreographyVariant =
      MorphFidelityChoreographyVariant.baseline;

  static const double _stretch = 0.75;
  static const double _leadBounce = 0.10;
  static const int _followDelayMs = 40;
  static const double _contentBlur = 8.0;
  static const double _contentFollow = 1.0;
  static const double _contentSlide = 0.0;
  static const double _baseStiffness = 195.0;
  static const double _baseDamping = 19.5;

  @override
  void initState() {
    super.initState();
    _targetState = widget.isExpanded
        ? MorphFidelityStateId.square
        : MorphFidelityStateId.circle;

    final Rect initialRect = _resolveStateRect(_targetState);
    _geometryController = QuickNotesMorphGeometryController(
      initialRect: initialRect,
    );
    _choreographyAdapter =
        MorphFidelityChoreographyAdapter(_geometryController);
    _ticker = createTicker(_onTick);

    _geometryController.seedInitialRect(
      initialRect,
      anchor: widget.anchor,
    );
    _contentController.seedInitialState(
      stateId: _targetState.toPhase8CStateId(),
      stateRect: initialRect,
      stiffness: _baseStiffness,
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(QuickNotesGlassActionMorph<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      final MorphFidelityStateId nextState = widget.isExpanded
          ? MorphFidelityStateId.square
          : MorphFidelityStateId.circle;
      if (nextState != _targetState) {
        _triggerMorphTo(nextState);
      }
    }
  }

  Rect _resolveStateRect(MorphFidelityStateId state) {
    final Rect stageBounds = Rect.fromLTWH(0, 0, widget.width, widget.height);
    final Size targetSize = (state == MorphFidelityStateId.circle)
        ? Size(widget.collapsedWidth, widget.collapsedHeight)
        : Size(widget.width, widget.height);
    return widget.anchor.inscribe(targetSize, stageBounds);
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
      selectedAnchor: widget.anchor,
      placementAlignment: widget.anchor,
      spatialMode: _spatialMode,
    );
  }

  QuickNotesMorphContentConfig _buildContentConfig() {
    return const QuickNotesMorphContentConfig(
      contentOutEnd: 0.40,
      contentInStart: 0.30,
      contentInEnd: 0.80,
      newScaleFrom: 0.90,
      oldScaleTo: 0.92,
      contentBlur: _contentBlur,
      contentFollow: _contentFollow,
      contentSlide: _contentSlide,
      anchor: Alignment.center,
    );
  }

  double _effectiveCornerRadiusForRect(Rect rect) {
    final double widthSpan = widget.width - widget.collapsedWidth;
    final double heightSpan = widget.height - widget.collapsedHeight;
    final double t;
    if (widthSpan.abs() >= heightSpan.abs() && widthSpan.abs() > 0.001) {
      t = ((rect.width - widget.collapsedWidth) / widthSpan).clamp(0.0, 1.0);
    } else if (heightSpan.abs() > 0.001) {
      t = ((rect.height - widget.collapsedHeight) / heightSpan).clamp(0.0, 1.0);
    } else {
      t = (_targetState == MorphFidelityStateId.square) ? 1.0 : 0.0;
    }
    return ui.lerpDouble(widget.collapsedRadius, widget.expandedRadius, t) ??
        widget.expandedRadius;
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
      widget.onTransitionEnd?.call();
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

  Widget _buildEvaluatedLayer(
    QuickNotesEvaluatedContentLayer layer,
    Rect liveGlassRect,
    String roleKey,
  ) {
    final MorphFidelityStateId state = layer.stateId.toFidelityStateId();
    final Size naturalSize = (state == MorphFidelityStateId.circle)
        ? Size(widget.collapsedWidth, widget.collapsedHeight)
        : Size(widget.width, widget.height);

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
      key: ValueKey<String>(
          'quick_notes_glass_action_morph_layer_${roleKey}_${state.name}'),
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
        return widget.triggerChild ?? _buildDefaultTrigger();
      case MorphFidelityStateId.square:
        return widget.expandedChild ?? _buildActionsContent();
      case MorphFidelityStateId.alternate:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDefaultTrigger() {
    final Color effectiveTextColor =
        widget.defaultTextColor ?? const Color(0xFF333333);

    return Semantics(
      button: true,
      label: 'More options',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          QuickNotesHaptics.buttonPress();
          widget.onTriggerTap?.call();
        },
        child: SizedBox(
          width: widget.collapsedWidth,
          height: widget.collapsedHeight,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 5.0,
                  height: 5.0,
                  decoration: BoxDecoration(
                    color: effectiveTextColor.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4.0),
                Container(
                  width: 5.0,
                  height: 5.0,
                  decoration: BoxDecoration(
                    color: effectiveTextColor.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4.0),
                Container(
                  width: 5.0,
                  height: 5.0,
                  decoration: BoxDecoration(
                    color: effectiveTextColor.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionsContent() {
    final Color effectiveDividerColor =
        widget.dividerColor ?? const Color(0x33000000);
    final Color effectiveTextColor =
        widget.defaultTextColor ?? const Color(0xFF333333);

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (int i = 0; i < widget.actions.length; i++)
            _buildActionTile(
              context,
              action: widget.actions[i],
              dividerColor: effectiveDividerColor,
              fallbackTextColor: effectiveTextColor,
              isFirst: i == 0,
              isLast: i == widget.actions.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required QuickNotesGlassAction<T> action,
    required Color dividerColor,
    required Color fallbackTextColor,
    required bool isFirst,
    required bool isLast,
  }) {
    final Color effectiveColor = action.textColor ?? fallbackTextColor;
    final Color effectiveIconColor = action.iconColor ?? effectiveColor;

    return Semantics(
      button: true,
      label: action.label,
      child: FocusableActionDetector(
        includeFocusSemantics: false,
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (intent) {
              QuickNotesHaptics.buttonPress();
              widget.onActionSelected?.call(action.id);
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTap: () {
            QuickNotesHaptics.buttonPress();
            widget.onActionSelected?.call(action.id);
          },
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: widget.width,
            height: widget.itemHeight,
            child: Stack(
              children: <Widget>[
                if (!isLast)
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Container(
                      width: widget.width,
                      height: widget.itemHeight,
                      decoration: ShapeDecoration(
                        shape: RoundedRectangleBorder(
                          side: BorderSide(width: 0.20, color: dividerColor),
                        ),
                      ),
                    ),
                  ),
                if (action.iconPath != null)
                  Positioned(
                    left: 14,
                    top: 17,
                    child: SvgPicture.asset(
                      action.iconPath!,
                      width: 16,
                      height: 16,
                      colorFilter: ColorFilter.mode(
                        effectiveIconColor,
                        BlendMode.srcIn,
                      ),
                    ),
                  )
                else if (action.iconData != null)
                  Positioned(
                    left: 14,
                    top: 16,
                    child: Icon(
                      action.iconData,
                      size: 18,
                      color: effectiveIconColor,
                    ),
                  ),
                Positioned(
                  left: 39,
                  top: 10,
                  child: SizedBox(
                    width: widget.width - 70,
                    height: 30,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        action.label,
                        style: GoogleFonts.inter(
                          color: effectiveColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
      key: const ValueKey<String>('quick_notes_glass_action_morph_container'),
      width: widget.width,
      height: widget.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(
            key: const ValueKey<String>(
                'quick_notes_glass_action_morph_glass_pos'),
            left: clampedRect.left,
            top: clampedRect.top,
            width: clampedRect.width,
            height: clampedRect.height,
            child: GestureDetector(
              behavior: widget.triggerChild == null
                  ? HitTestBehavior.opaque
                  : HitTestBehavior.deferToChild,
              onTap: widget.triggerChild == null
                  ? () {
                      if (_targetState == MorphFidelityStateId.circle) {
                        QuickNotesHaptics.buttonPress();
                        widget.onTriggerTap?.call();
                      }
                    }
                  : null,
              child: BottomBarGlassSurface(
                key: const ValueKey<String>(
                  'quick_notes_glass_action_morph_glass_surface',
                ),
                width: clampedRect.width,
                height: clampedRect.height,
                borderRadius: BorderRadius.circular(effectiveRadius),
                useFrost: true,
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
