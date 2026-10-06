import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
// ignore: implementation_imports
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_flex.dart';

import 'app_bottom_navigation_bar.dart';

/// Reusable production Liquid Glass Button for Quick Notes.
///
/// Combines Quick Notes' design system glass renderer ([BottomBarGlassSurface])
/// with the soft-body press and drag deformation physics of [LiquidGlassFlexDriver]
/// from `liquid_glass_easy: 4.3.1`.
///
/// Locked Stage 2 Mechanics:
/// - Directional stretch along the pull axis (13.0 px max, bounded by tanh).
/// - Transverse volume squeeze (0.70 ratio).
/// - Asymmetric directional lean (0.50).
/// - Localized grip proximity (0.70).
/// - Inward squashing with cross-axis bulge (`compressInward: true`).
/// - Localized outward press swell (`holdScale: 0.030`).
/// - Tap completion pop (`tapScale: 0.020`).
/// - Fluid underdamped recoil wobble on release (`stiffness: 320.0`, `damping: 24.0`, `releaseDamping: 17.0`).
/// - Anchored content with zero drift (`childFollow: 0.0` default).
/// - Native Quick Notes typography ([GoogleFonts.inter]) and glassmorphism.
class QuickNotesLiquidGlassButton extends StatefulWidget {
  final VoidCallback onTap;
  final String? label;
  final Widget? child;
  final double width;
  final double height;
  final bool isDark;
  final bool enabled;
  final bool enableFlex;
  final double childFollow;
  final String? semanticLabel;

  const QuickNotesLiquidGlassButton({
    super.key,
    required this.onTap,
    this.label = 'Create Folder',
    this.child,
    this.width = 200.0,
    this.height = 50.0,
    this.isDark = false,
    this.enabled = true,
    this.enableFlex = true,
    this.childFollow = 0.0,
    this.semanticLabel,
  });

  @override
  State<QuickNotesLiquidGlassButton> createState() =>
      _QuickNotesLiquidGlassButtonState();
}

class _QuickNotesLiquidGlassButtonState
    extends State<QuickNotesLiquidGlassButton>
    with SingleTickerProviderStateMixin {
  /// Source of Truth: LiquidGlassFlex configured strictly with the coupled native
  /// deformation model from `liquid_glass_easy: 4.3.1`:
  /// - stretch: 13.0 (native default peak elongation)
  /// - squeeze: 0.70 (native default transverse contraction)
  /// - lean: 0.50 (native default directional asymmetry)
  /// - grip: 0.70 (native default grab locality)
  /// - compressInward: true (native default inward squashing)
  /// - holdScale: 0.030 (Native press swell outward ~3%)
  /// - tapScale: 0.020 (Native tap pop outward feedback)
  /// - maxPull: 48.0 (native default saturation threshold)
  /// - childFollow: variable (0.0=anchored default, 0.25, 0.50, 0.75, 1.0=full ride-along)
  /// - releaseDamping: 17.0 (Native underdamped release; liquid recoil wobble)
  /// - refractionBoost: 0.0 (Quick Notes uses BackdropFilter/DecoratedBox, no fragment shader)
  static LiquidGlassFlex _buildFlexSpec(double childFollow) => LiquidGlassFlex(
        stretch: 13.0,
        squeeze: 0.70,
        lean: 0.50,
        grip: 0.70,
        compressInward: true,
        holdScale: 0.030,
        tapScale: 0.020,
        maxPull: 48.0,
        advanced: LiquidGlassFlexAdvanced(
          childFollow: childFollow,
          refractionBoost: 0.0,
          magnificationBoost: 0.0,
          stiffness: 320,
          damping: 24,
          releaseDamping: 17.0, // Native underdamped release (liquid recoil wobble)
        ),
      );

  late final LiquidGlassFlexDriver _flexDriver;
  double _dragDistance = 0.0;

  @override
  void initState() {
    super.initState();
    _flexDriver = LiquidGlassFlexDriver(
      vsync: this,
      spec: _buildFlexSpec(widget.childFollow),
    );
  }

  @override
  void didUpdateWidget(covariant QuickNotesLiquidGlassButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.width != widget.width || oldWidget.height != widget.height) {
      _flexDriver.restSize = Size(widget.width, widget.height);
    }
    if (oldWidget.childFollow != widget.childFollow) {
      _flexDriver.spec = _buildFlexSpec(widget.childFollow);
    }
  }

  @override
  void dispose() {
    _flexDriver.dispose();
    super.dispose();
  }

  Widget _buildContent(BuildContext context) {
    if (widget.child != null) {
      return widget.child!;
    }
    return Container(
      alignment: Alignment.center,
      child: Text(
        widget.label ?? '',
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: widget.isDark
              ? const Color(0xFFFFFFFF)
              : const Color(0xFF1C1C1E),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size restSize = Size(widget.width, widget.height);
    _flexDriver.restSize = restSize;

    final Widget buttonContent;

    // ── CLEAN BASELINE MODE (Static Touch) ──────────────────────────────────
    // When flex is disabled, exhibits ZERO touch animation:
    // - NO ScaleTransition
    // - NO compressionScale = 0.90
    // - NO press animation
    // - NO release animation
    // - NO Apple spring or overshoot
    // - NO haptics
    // The Quick Notes glass surface remains 100% static when touched.
    if (!widget.enableFlex) {
      buttonContent = GestureDetector(
        key: const ValueKey('stage2_clean_baseline_gesture'),
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? widget.onTap : null,
        child: BottomBarGlassSurface(
          width: widget.width,
          height: widget.height,
          borderRadius: BorderRadius.circular(widget.height / 2),
          useFrost: true,
          child: _buildContent(context),
        ),
      );
    } else {
      // ── EXPERIMENTAL TOUCH MODE (LiquidGlassEasy Press + Drag/Stretch Physics)
      // Connects LiquidGlassFlexDriver pointer events to the real Quick Notes
      // BottomBarGlassSurface renderer at the widget geometry level.
      // Wrapped in a PanGestureDetector to claim drag gestures starting on the button
      // so horizontal/vertical parent scrollables (PageView / ScrollView) do not hijack
      // directional button stretch.
      buttonContent = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) {},
        onPanUpdate: (_) {},
        onPanEnd: (_) {},
        onPanCancel: () {},
        child: Listener(
          key: const ValueKey('stage2_experimental_flex_listener'),
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            if (!widget.enabled) return;
            _dragDistance = 0.0;
            _flexDriver.down(event.localPosition, restSize,
                pointer: event.pointer);
          },
          onPointerMove: (event) {
            if (!widget.enabled) return;
            _dragDistance += event.delta.distance;
            _flexDriver.move(event.delta, pointer: event.pointer);
          },
          onPointerUp: (event) {
            if (!widget.enabled) return;
            _flexDriver.up(pointer: event.pointer);
            if (_dragDistance <= kTouchSlop) {
              widget.onTap();
            }
          },
          onPointerCancel: (event) {
            if (!widget.enabled) return;
            _flexDriver.up(pointer: event.pointer);
          },
          child: SizedBox.fromSize(
            size: restSize,
            child: ValueListenableBuilder<LiquidGlassFlexDeform>(
              valueListenable: _flexDriver,
              builder: (context, deform, _) {
                final Size deformed = deform.sizeFrom(restSize);
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: deform.originShift.dx,
                      top: deform.originShift.dy,
                      width: deformed.width,
                      height: deformed.height,
                      child: BottomBarGlassSurface(
                        width: deformed.width,
                        height: deformed.height,
                        borderRadius:
                            BorderRadius.circular(deformed.height / 2),
                        useFrost: true,
                        child: liquidGlassFlexChild(
                          deform: deform,
                          restSize: restSize,
                          child: _buildContent(context),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.semanticLabel,
      child: buttonContent,
    );
  }
}
