import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/motion/morph_content_controller.dart';
import '../../core/motion/morph_geometry_config.dart';
import '../../core/motion/morph_geometry_controller.dart';
import 'app_bottom_navigation_bar.dart';

/// Content state identifier for [LiquidGlassMorphContainer].
enum _MorphContainerState {
  collapsed,
  expanded,
}

/// Production Liquid Glass Morph Container for Quick Notes.
///
/// Encapsulates the extracted 4D harmonic spring geometry controller and
/// content controller into a production-ready Flutter widget.
///
/// Responsibilities:
/// - Coordinates a single authoritative [Ticker] clock driving both geometry and content transitions.
/// - Automatically self-stops the [Ticker] when springs settle and hold delays expire.
/// - Adapts real layout geometry (collapsed size, expanded size, and spatial anchor).
/// - Renders through Quick Notes' unaltered [BottomBarGlassSurface].
/// - Clips content strictly inside the glass surface boundaries.
/// - Coordinates cross-fade, scale, and Gaussian blur between collapsed and expanded states.
/// - Gates pointer events to prevent touch events on partially transformed content.
class LiquidGlassMorphContainer extends StatefulWidget {
  const LiquidGlassMorphContainer({
    super.key,
    required this.isExpanded,
    required this.collapsedChild,
    required this.expandedChild,
    this.collapsedSize = const Size(44.0, 44.0),
    this.expandedSize = const Size(192.0, 250.0),
    this.collapsedBorderRadius = const BorderRadius.all(Radius.circular(22.0)),
    this.expandedBorderRadius = const BorderRadius.all(Radius.circular(20.0)),
    this.anchor = Alignment.topRight,
    this.geometryConfig = const QuickNotesMorphGeometryConfig(),
    this.contentConfig = const QuickNotesMorphContentConfig(),
    this.useFrost = true,
    this.heroTag,
    this.occupyBounds = false,
    this.onTransitionEnd,
  });

  /// Whether the container is in its expanded state (`true`) or collapsed state (`false`).
  final bool isExpanded;

  /// Content rendered when collapsed (e.g. 3-dots icon button).
  final Widget collapsedChild;

  /// Content rendered when expanded (e.g. options popup menu).
  final Widget expandedChild;

  /// Measured or natural size of the collapsed state.
  final Size collapsedSize;

  /// Measured or natural size of the expanded state.
  final Size expandedSize;

  /// Corner radius when fully collapsed.
  final BorderRadius collapsedBorderRadius;

  /// Corner radius when fully expanded.
  final BorderRadius expandedBorderRadius;

  /// Spatial anchor determining the coincident point during expansion/contraction.
  final Alignment anchor;

  /// Physical spring and asymmetric lead-follow configuration.
  final QuickNotesMorphGeometryConfig geometryConfig;

  /// Content timing, scale, blur, and spatial follow configuration.
  final QuickNotesMorphContentConfig contentConfig;

  /// Whether to enable backdrop frosted glass effect in [BottomBarGlassSurface].
  final bool useFrost;

  /// Optional Hero animation tag wrapping the glass surface.
  final String? heroTag;

  /// Whether the container widget occupies the total bounding box (`true`)
  /// or sizes itself directly to the live moving surface (`false`).
  final bool occupyBounds;

  /// Callback invoked when the morph transition has completely settled.
  final VoidCallback? onTransitionEnd;

  @override
  State<LiquidGlassMorphContainer> createState() =>
      _LiquidGlassMorphContainerState();
}

class _LiquidGlassMorphContainerState extends State<LiquidGlassMorphContainer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final QuickNotesMorphGeometryController _geometryController;
  late final QuickNotesMorphContentController<_MorphContainerState>
      _contentController;

  Duration? _lastElapsed;
  bool _initialized = false;
  late Rect _collapsedRect;
  late Rect _expandedRect;
  late Size _boundsSize;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _resolveGeometry();

    final Rect initialRect =
        widget.isExpanded ? _expandedRect : _collapsedRect;
    final _MorphContainerState initialState = widget.isExpanded
        ? _MorphContainerState.expanded
        : _MorphContainerState.collapsed;

    _geometryController = QuickNotesMorphGeometryController(
      initialRect: initialRect,
      initialAnchor: widget.anchor,
    );

    _contentController =
        QuickNotesMorphContentController<_MorphContainerState>(
      initialState: initialState,
      initialRect: initialRect,
      stiffness: widget.geometryConfig.stiffness,
    );

    _initialized = true;
  }

  void _resolveGeometry() {
    _boundsSize = Size(
      math.max(widget.collapsedSize.width, widget.expandedSize.width),
      math.max(widget.collapsedSize.height, widget.expandedSize.height),
    );
    final Rect bounds = Offset.zero & _boundsSize;
    _collapsedRect = widget.anchor.inscribe(widget.collapsedSize, bounds);
    _expandedRect = widget.anchor.inscribe(widget.expandedSize, bounds);
  }

  @override
  void didUpdateWidget(covariant LiquidGlassMorphContainer oldWidget) {
    super.didUpdateWidget(oldWidget);

    final bool sizeChanged =
        oldWidget.collapsedSize != widget.collapsedSize ||
        oldWidget.expandedSize != widget.expandedSize ||
        oldWidget.anchor != widget.anchor;

    if (sizeChanged) {
      _resolveGeometry();
    }

    if (oldWidget.isExpanded != widget.isExpanded || sizeChanged) {
      _startTransition();
    }
  }

  void _startTransition() {
    final Rect targetRect =
        widget.isExpanded ? _expandedRect : _collapsedRect;
    final _MorphContainerState targetState = widget.isExpanded
        ? _MorphContainerState.expanded
        : _MorphContainerState.collapsed;

    final QuickNotesMorphGeometryConfig activeConfig =
        widget.geometryConfig.copyWith(anchor: widget.anchor);

    _geometryController.transitionToRect(targetRect, config: activeConfig);
    _contentController.transitionToState(
      targetState: targetState,
      targetRect: targetRect,
      liveGlassRect: _geometryController.currentRect,
      config: widget.contentConfig,
      stiffness: widget.geometryConfig.stiffness,
    );

    if (!_ticker.isActive) {
      _lastElapsed = null;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;

    final double dt;
    if (_lastElapsed == null) {
      dt = 1.0 / 60.0;
    } else {
      dt = (elapsed - _lastElapsed!).inMicroseconds / 1e6;
    }
    _lastElapsed = elapsed;

    final QuickNotesMorphGeometryConfig activeConfig =
        widget.geometryConfig.copyWith(anchor: widget.anchor);

    final bool geomMoving =
        _geometryController.step(dt, activeConfig);
    final bool contentMoving =
        _contentController.step(dt, widget.contentConfig);

    setState(() {});

    if (!geomMoving && !contentMoving) {
      _ticker.stop();
      _lastElapsed = null;
      widget.onTransitionEnd?.call();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  BorderRadius _computeBorderRadius(Rect liveRect) {
    final double totalDx =
        (_expandedRect.width - _collapsedRect.width).abs();
    final double totalDy =
        (_expandedRect.height - _collapsedRect.height).abs();
    final double totalDist = math.sqrt(totalDx * totalDx + totalDy * totalDy);

    final double fraction;
    if (totalDist < 0.5) {
      fraction = widget.isExpanded ? 1.0 : 0.0;
    } else {
      final double currentDx =
          (liveRect.width - _collapsedRect.width).abs();
      final double currentDy =
          (liveRect.height - _collapsedRect.height).abs();
      final double currentDist =
          math.sqrt(currentDx * currentDx + currentDy * currentDy);
      fraction = (currentDist / totalDist).clamp(0.0, 1.0);
    }
    return BorderRadius.lerp(
      widget.collapsedBorderRadius,
      widget.expandedBorderRadius,
      fraction,
    )!;
  }

  Widget _buildContentLayer(
    QuickNotesEvaluatedContentLayer<_MorphContainerState> layer, {
    bool ignoring = false,
  }) {
    final bool isTargetExpanded =
        layer.stateId == _MorphContainerState.expanded;
    final Size naturalSize =
        isTargetExpanded ? widget.expandedSize : widget.collapsedSize;
    final Widget rawChild =
        isTargetExpanded ? widget.expandedChild : widget.collapsedChild;

    Widget content = SizedBox(
      width: naturalSize.width,
      height: naturalSize.height,
      child: rawChild,
    );

    if (layer.isBlurActive) {
      content = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: layer.blurSigma,
          sigmaY: layer.blurSigma,
        ),
        child: content,
      );
    }

    return Positioned(
      left: layer.localOffset.dx,
      top: layer.localOffset.dy,
      width: naturalSize.width,
      height: naturalSize.height,
      child: IgnorePointer(
        ignoring: ignoring,
        child: Opacity(
          opacity: layer.opacity.clamp(0.0, 1.0),
          child: Transform.scale(
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
    if (!_initialized) return const SizedBox.shrink();

    final Rect liveRect = _geometryController.currentRect;
    final BorderRadius currentRadius = _computeBorderRadius(liveRect);
    final QuickNotesMorphContentSnapshot<_MorphContainerState> snapshot =
        _contentController.evaluateAt(
      t: _contentController.progress,
      currentGlassRect: liveRect,
      config: widget.contentConfig,
    );

    // Gated interactivity: interactive only when fully settled at destination
    final bool isMoving =
        _ticker.isActive || _geometryController.isAnimating;
    final bool isExpandedInteractive = widget.isExpanded && !isMoving;
    final bool isCollapsedInteractive = !widget.isExpanded && !isMoving;

    Widget glassBody = BottomBarGlassSurface(
      width: liveRect.width,
      height: liveRect.height,
      borderRadius: currentRadius,
      useFrost: widget.useFrost,
      child: ClipRRect(
        borderRadius: currentRadius,
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.hardEdge,
          children: [
            // Outgoing layer (fading out)
            if (snapshot.outgoing != null &&
                snapshot.outgoing!.opacity > 0.001)
              _buildContentLayer(
                snapshot.outgoing!,
                ignoring: true,
              ),

            // Secondary outgoing layer (if retargeted during overlap)
            if (snapshot.secondaryOutgoing != null &&
                snapshot.secondaryOutgoing!.opacity > 0.001)
              _buildContentLayer(
                snapshot.secondaryOutgoing!,
                ignoring: true,
              ),

            // Incoming layer (fading in)
            _buildContentLayer(
              snapshot.incoming,
              ignoring: widget.isExpanded
                  ? !isExpandedInteractive
                  : !isCollapsedInteractive,
            ),
          ],
        ),
      ),
    );

    if (widget.heroTag != null && widget.heroTag!.isNotEmpty) {
      glassBody = Hero(
        tag: widget.heroTag!,
        child: glassBody,
      );
    }

    if (widget.occupyBounds) {
      return SizedBox(
        width: _boundsSize.width,
        height: _boundsSize.height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: liveRect.left,
              top: liveRect.top,
              width: liveRect.width,
              height: liveRect.height,
              child: glassBody,
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: liveRect.width,
      height: liveRect.height,
      child: glassBody,
    );
  }
}
