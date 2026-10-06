import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../core/motion/quick_notes_visual_capability.dart';
import '../../core/motion/quick_notes_visual_frame.dart';
import '../../core/motion/quick_notes_visual_preset.dart';
import '../../core/motion/quick_notes_visual_transition_controller.dart';
import 'app_bottom_navigation_bar.dart';

/// Builder signature for custom surface rendering.
typedef QuickNotesSurfaceBuilder = Widget Function(
  BuildContext context,
  QuickNotesVisualFrame frame,
  Widget child,
);

/// Generic, reusable visual motion and morphing component for Quick Notes.
///
/// Designed as a pure visual transition layer:
/// - **Zero Business Logic**: Does NOT own domain or application state.
///   The caller owns the semantic state (e.g. `_isMoreOptionsOpen`) and passes it to [state].
/// - **Universal Surface Support**: Works seamlessly with Quick Notes Liquid Glass
///   ([BottomBarGlassSurface]) and ordinary Flutter widgets alike.
/// - **Composable Capabilities**: Pluggable architecture allowing [GeometryCapability],
///   [MotionCapability], [MorphCapability], [StretchCapability], [ShapeCapability],
///   [ContentCapability], and future capabilities (e.g. [AdaptivityCapability]) to be mixed.
/// - **Single Authoritative Clock**: Drives decoupled 4D springs and content crossfades
///   from a single vsync [Ticker] that automatically stops when settled.
class QuickNotesVisualTransition extends StatefulWidget {
  const QuickNotesVisualTransition({
    super.key,
    required this.state,
    this.preset = QuickNotesVisualPreset.baseline,
    this.capabilities = const <QuickNotesVisualCapability>[],
    this.collapsedSize = const Size(44.0, 44.0),
    this.expandedSize = const Size(192.0, 100.0),
    this.collapsedBorderRadius = const BorderRadius.all(Radius.circular(22.0)),
    this.expandedBorderRadius = const BorderRadius.all(Radius.circular(20.0)),
    this.anchor = Alignment.topRight,
    this.occupyBounds = false,
    this.child,
    this.collapsedChild,
    this.expandedChild,
    this.surfaceBuilder,
    this.onTransitionEnd,
  });

  /// Specialized factory for 100% visual consistency with Quick Notes Liquid Glass.
  factory QuickNotesVisualTransition.liquidGlass({
    Key? key,
    required Object state,
    QuickNotesVisualPreset preset = QuickNotesVisualPreset.baseline,
    List<QuickNotesVisualCapability> capabilities = const [],
    Size collapsedSize = const Size(44.0, 44.0),
    Size expandedSize = const Size(192.0, 100.0),
    BorderRadius collapsedBorderRadius = const BorderRadius.all(Radius.circular(22.0)),
    BorderRadius expandedBorderRadius = const BorderRadius.all(Radius.circular(20.0)),
    Alignment anchor = Alignment.topRight,
    bool occupyBounds = false,
    bool useFrost = true,
    String? heroTag,
    Widget? child,
    Widget? collapsedChild,
    Widget? expandedChild,
    VoidCallback? onTransitionEnd,
  }) {
    return QuickNotesVisualTransition(
      key: key,
      state: state,
      preset: preset,
      capabilities: capabilities,
      collapsedSize: collapsedSize,
      expandedSize: expandedSize,
      collapsedBorderRadius: collapsedBorderRadius,
      expandedBorderRadius: expandedBorderRadius,
      anchor: anchor,
      occupyBounds: occupyBounds,
      collapsedChild: collapsedChild,
      expandedChild: expandedChild,
      onTransitionEnd: onTransitionEnd,
      surfaceBuilder: (context, frame, content) {
        Widget glass = BottomBarGlassSurface(
          width: frame.width,
          height: frame.height,
          borderRadius: frame.borderRadius,
          useFrost: useFrost,
          child: ClipRRect(
            borderRadius: frame.borderRadius,
            child: content,
          ),
        );
        if (heroTag != null && heroTag.isNotEmpty) {
          glass = Hero(tag: heroTag, child: glass);
        }
        return glass;
      },
      child: child,
    );
  }

  /// Authoritative semantic visual state (e.g. `true`/`false` or an enum).
  final Object state;

  /// Visual preset defining baseline spring physics and content curves.
  final QuickNotesVisualPreset preset;

  /// Pluggable list of visual capabilities decorating geometry, motion, or shape.
  final List<QuickNotesVisualCapability> capabilities;

  /// Natural size when collapsed.
  final Size collapsedSize;

  /// Natural size when expanded.
  final Size expandedSize;

  /// Corner radius when collapsed.
  final BorderRadius collapsedBorderRadius;

  /// Corner radius when expanded.
  final BorderRadius expandedBorderRadius;

  /// Spatial anchor for deformation and positioning.
  final Alignment anchor;

  /// Whether the root widget occupies the full bounding box of both states.
  final bool occupyBounds;

  /// Single child widget used if separate state children are not specified.
  final Widget? child;

  /// Child widget rendered when collapsed.
  final Widget? collapsedChild;

  /// Child widget rendered when expanded.
  final Widget? expandedChild;

  /// Custom surface builder wrapping the animated content.
  final QuickNotesSurfaceBuilder? surfaceBuilder;

  /// Callback invoked when a transition has settled.
  final VoidCallback? onTransitionEnd;

  @override
  State<QuickNotesVisualTransition> createState() =>
      _QuickNotesVisualTransitionState();
}

class _QuickNotesVisualTransitionState extends State<QuickNotesVisualTransition>
    with SingleTickerProviderStateMixin {
  late final QuickNotesVisualTransitionController _controller;
  late Size _boundsSize;
  late Rect _collapsedRect;
  late Rect _expandedRect;

  bool get _isExpanded {
    if (widget.state is bool) {
      return widget.state as bool;
    }
    return widget.state != 'collapsed' && widget.state != 0;
  }

  @override
  void initState() {
    super.initState();
    _resolveGeometry();

    final Rect initialRect = _isExpanded ? _expandedRect : _collapsedRect;
    final BorderRadius initialRadius = _isExpanded
        ? widget.expandedBorderRadius
        : widget.collapsedBorderRadius;

    _controller = QuickNotesVisualTransitionController(
      vsync: this,
      initialRect: initialRect,
      initialAnchor: widget.anchor,
      initialPreset: widget.preset,
      initialRadius: initialRadius,
      capabilities: widget.capabilities,
      onTransitionEnd: widget.onTransitionEnd,
    );

    _controller.addListener(_onFrameUpdate);
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

  void _onFrameUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant QuickNotesVisualTransition oldWidget) {
    super.didUpdateWidget(oldWidget);

    final bool geomChanged =
        oldWidget.collapsedSize != widget.collapsedSize ||
        oldWidget.expandedSize != widget.expandedSize ||
        oldWidget.anchor != widget.anchor;

    if (geomChanged) {
      _resolveGeometry();
    }

    if (oldWidget.preset != widget.preset) {
      _controller.setPreset(widget.preset);
    }

    if (oldWidget.anchor != widget.anchor) {
      _controller.setAnchor(widget.anchor);
    }

    if (oldWidget.capabilities != widget.capabilities) {
      _controller.setCapabilities(widget.capabilities);
    }

    if (oldWidget.state != widget.state || geomChanged) {
      final Rect targetRect = _isExpanded ? _expandedRect : _collapsedRect;
      final BorderRadius targetRadius = _isExpanded
          ? widget.expandedBorderRadius
          : widget.collapsedBorderRadius;

      _controller.startTransition(
        targetRect: targetRect,
        targetRadius: targetRadius,
        targetState: widget.state,
        anchor: widget.anchor,
      );
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onFrameUpdate);
    _controller.dispose();
    super.dispose();
  }

  Widget _buildContent(QuickNotesVisualFrame frame) {
    if (widget.collapsedChild != null && widget.expandedChild != null) {
      final snapshot = frame.contentSnapshot;
      final bool isMoving = frame.isMoving;
      final bool isExpandedInteractive = _isExpanded && !isMoving;
      final bool isCollapsedInteractive = !_isExpanded && !isMoving;

      return Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          // Outgoing layer
          if (snapshot != null &&
              snapshot.outgoing != null &&
              snapshot.outgoing!.opacity > 0.001)
            _buildLayerWidget(
              snapshot.outgoing!,
              isTargetExpanded: !_isExpanded,
              ignoring: true,
            ),

          // Secondary outgoing layer (if retargeted during overlap)
          if (snapshot != null &&
              snapshot.secondaryOutgoing != null &&
              snapshot.secondaryOutgoing!.opacity > 0.001)
            _buildLayerWidget(
              snapshot.secondaryOutgoing!,
              isTargetExpanded: !_isExpanded,
              ignoring: true,
            ),

          // Incoming layer
          if (snapshot != null)
            _buildLayerWidget(
              snapshot.incoming,
              isTargetExpanded: _isExpanded,
              ignoring: _isExpanded
                  ? !isExpandedInteractive
                  : !isCollapsedInteractive,
            )
          else
            Positioned(
              left: 0,
              top: 0,
              width: _isExpanded ? widget.expandedSize.width : widget.collapsedSize.width,
              height: _isExpanded ? widget.expandedSize.height : widget.collapsedSize.height,
              child: _isExpanded ? widget.expandedChild! : widget.collapsedChild!,
            ),
        ],
      );
    }

    // Single child mode
    return widget.child ?? const SizedBox.shrink();
  }

  Widget _buildLayerWidget(
    dynamic layer, {
    required bool isTargetExpanded,
    required bool ignoring,
  }) {
    final Size naturalSize =
        isTargetExpanded ? widget.expandedSize : widget.collapsedSize;
    final Widget rawChild =
        isTargetExpanded ? widget.expandedChild! : widget.collapsedChild!;

    Widget content = SizedBox(
      width: naturalSize.width,
      height: naturalSize.height,
      child: rawChild,
    );

    if (layer.isBlurActive as bool? ?? false) {
      final double blurSigma = (layer.blurSigma as double?) ?? 0.0;
      if (blurSigma > 0.01) {
        content = ImageFiltered(
          imageFilter: ui.ImageFilter.blur(
            sigmaX: blurSigma,
            sigmaY: blurSigma,
          ),
          child: content,
        );
      }
    }

    final double opacity = (layer.opacity as double).clamp(0.0, 1.0);
    final double scale = (layer.scale as double?) ?? 1.0;
    final Alignment alignment = (layer.alignment as Alignment?) ?? Alignment.center;
    final Offset offset = (layer.localOffset as Offset?) ?? Offset.zero;

    return Positioned(
      left: offset.dx,
      top: offset.dy,
      width: naturalSize.width,
      height: naturalSize.height,
      child: IgnorePointer(
        ignoring: ignoring,
        child: Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            alignment: alignment,
            child: content,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final QuickNotesVisualFrame frame = _controller.currentFrame;

    // 1. Build and capability-wrap inner content
    Widget content = _buildContent(frame);
    for (final cap in widget.capabilities) {
      content = cap.wrapContent(context, frame, content);
    }

    // 2. Wrap with surface builder (Liquid Glass or custom/generic)
    Widget surface;
    if (widget.surfaceBuilder != null) {
      surface = widget.surfaceBuilder!(context, frame, content);
    } else {
      // Default clean, generic Flutter surface
      surface = ClipRRect(
        borderRadius: frame.borderRadius,
        child: SizedBox(
          width: frame.width,
          height: frame.height,
          child: content,
        ),
      );
    }

    // 3. Layout bounds
    if (widget.occupyBounds) {
      return SizedBox(
        width: _boundsSize.width,
        height: _boundsSize.height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: frame.topLeft.dx,
              top: frame.topLeft.dy,
              width: frame.width,
              height: frame.height,
              child: surface,
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: frame.width,
      height: frame.height,
      child: surface,
    );
  }
}
