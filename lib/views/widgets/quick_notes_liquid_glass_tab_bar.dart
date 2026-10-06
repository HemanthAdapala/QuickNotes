import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_inset_shadow/flutter_inset_shadow.dart' as inset;
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/motion/motion_constants.dart';
import '../../core/motion/quick_notes_haptics.dart';
import '../../themes/glassmorphism_presets.dart';
import '../constants/app_bottom_navigation_assets.dart';
import 'app_bottom_navigation_bar.dart'
    show AppBottomNavigationDestination, BottomBarGlassSurface;

/// Quick Notes Liquid Glass TabBar (Stage 2 Recreated Production Widget).
///
/// Extracted from the validated Stage 2 Liquid Glass TabBar Lab.
/// Implements the full 4+1 navigation architecture:
///   - 264x50 stationary glass capsule hosting 4 navigation destinations
///   - 4px physical gap
///   - 50x50 independent glass FAB action button
///   - 240Hz sub-stepped physics spring simulation for the yellow liquid pill
///   - Dual-axis dynamic deformation (dynamic X stretching + Y grow height)
///   - Dual-layer aperture clipping (_InsidePillClipper / _OutsidePillClipper)
///   - Full accessibility semantics for all 4 tabs and the action FAB
class QuickNotesLiquidGlassTabBar extends StatefulWidget {
  static const double figmaWidth = 318.0;
  static const double barWidth = 264.0;
  static const double controlHeight = 50.0;
  static const double gap = 4.0;

  // Aliases for private member compatibility
  static const double _figmaWidth = figmaWidth;
  static const double _barWidth = barWidth;
  static const double _controlHeight = controlHeight;
  static const double _gap = gap;

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool folderModeActive;
  final VoidCallback? onFabPressed;
  final double? width;
  final bool? isDark;
  final Color? activeColor;

  // ── Physics Parameters (Forensic Stage 2 Defaults) ─────────────────────────
  final double travelStiffness;
  final double travelDamping;
  final double liftStiffness;
  final double liftDampingX;
  final double liftDampingY;
  final double pillGrowHeight;
  final double sensitivity;
  final double maxDeformation;
  final double responseTime;
  final double followTau;
  final double signTau;
  final int longPressMs;
  final double dragThreshold;

  final ValueChanged<bool>? onPhysicsActiveChanged;
  final ValueChanged<bool>? onFabAnimationActiveChanged;

  QuickNotesLiquidGlassTabBar({
    super.key,
    required this.selectedIndex,
    ValueChanged<int>? onDestinationSelected,
    ValueChanged<int>? onChanged,
    this.folderModeActive = false,
    this.onFabPressed,
    this.width,
    this.isDark,
    this.activeColor,
    this.travelStiffness = 280.0,
    this.travelDamping = 31.4,
    this.liftStiffness = 250.0,
    this.liftDampingX = 19.0,
    this.liftDampingY = 22.1,
    this.pillGrowHeight = 12.0,
    this.sensitivity = 0.00007,
    this.maxDeformation = 0.12,
    this.responseTime = 0.18,
    this.followTau = 0.05,
    this.signTau = 0.25,
    this.longPressMs = 100,
    this.dragThreshold = 0.20,
    this.onPhysicsActiveChanged,
    this.onFabAnimationActiveChanged,
  })  : assert(
          onDestinationSelected != null || onChanged != null,
          'Either onDestinationSelected or onChanged must be provided.',
        ),
        onDestinationSelected = (onDestinationSelected ?? onChanged)!;

  @override
  State<QuickNotesLiquidGlassTabBar> createState() =>
      _QuickNotesLiquidGlassTabBarState();
}

class _QuickNotesLiquidGlassTabBarState
    extends State<QuickNotesLiquidGlassTabBar>
    with SingleTickerProviderStateMixin {
  late int _selectedIndex;

  // ── Physics States ────────────────────────────────────────────────────────
  double _travelPos = 0.0;
  double _travelVel = 0.0;
  double _travelTarget = 0.0;
  double _travelFrom = 0.0;
  bool _travelActive = false;

  bool _lifted = false;
  double _liftX = 0.0;
  double _liftXVel = 0.0;
  double _liftY = 0.0;
  double _liftYVel = 0.0;

  double _travelSign = 0.0;
  double _travelSignEased = 0.0;

  // Drag interaction
  bool _tabDragging = false;
  double _dragFollow = 0.0;
  double _dragTargetFrac = 0.0;
  double _pressFrac = 0.0;
  bool _draggedRealMove = false;

  // Handover state
  double _handover = 1.0;

  // Acceleration deformation
  final List<(Offset, double)> _history = [];
  double _deviation = 0.0;

  Ticker? _ticker;
  Duration? _lastElapsed;

  void _notifyPhysicsActive(bool active) {
    widget.onPhysicsActiveChanged?.call(active);
  }

  double _getCenter(double frac, double scale) =>
      (40.0 + frac * (184.0 / 3.0)) * scale;

  @override
  void initState() {
    super.initState();
    _selectedIndex = (widget.selectedIndex < 4) ? widget.selectedIndex : 0;
    _travelPos = _selectedIndex.toDouble();
    _travelTarget = _travelPos;
    _travelFrom = _travelPos;
    _dragFollow = _travelPos;
    _ticker = createTicker(_onTick);
  }

  @override
  void didUpdateWidget(covariant QuickNotesLiquidGlassTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex < 4 &&
        widget.selectedIndex != _selectedIndex &&
        oldWidget.selectedIndex != widget.selectedIndex) {
      _animateTo(widget.selectedIndex, notify: false);
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _notifyPhysicsActive(false);
    super.dispose();
  }

  void _startTicker() {
    _notifyPhysicsActive(true);
    if (_ticker?.isActive != true) {
      _lastElapsed = null;
      _ticker?.start();
    }
  }

  void _animateTo(int next, {required bool notify}) {
    if (next == _selectedIndex && !_travelActive && !_tabDragging) return;
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      setState(() {
        _selectedIndex = next;
        _travelPos = next.toDouble();
        _travelTarget = next.toDouble();
        _travelFrom = next.toDouble();
        _travelActive = false;
        _lifted = false;
        _liftX = 0.0;
        _liftY = 0.0;
        _deviation = 0.0;
      });
      if (notify) widget.onDestinationSelected(next);
      return;
    }
    setState(() {
      _selectedIndex = next;
      _travelActive = true;
      _lifted = true;
      _travelFrom = _travelPos;
      _travelTarget = next.toDouble();
      final span = _travelTarget - _travelFrom;
      _travelSign = span.abs() < 1e-6 ? 0.0 : span.sign;
    });
    _startTicker();
    if (notify) widget.onDestinationSelected(next);
  }

  // 240Hz sub-stepped spring integrator (liquidGlassSpringStep)
  (double, double) _springStep({
    required double x,
    required double vel,
    required double target,
    required double dt,
    required double stiffness,
    required double damping,
  }) {
    var t = dt;
    var px = x;
    var pv = vel;
    while (t > 0) {
      final step = t > 1 / 240.0 ? 1 / 240.0 : t;
      final accel = -stiffness * (px - target) - damping * pv;
      pv += accel * step;
      px += pv * step;
      t -= step;
    }
    return (px, pv);
  }

  double _computeAverageAcceleration(double now) {
    const sampleWindow = 0.30;
    final cutoff = now - sampleWindow;
    _history.removeWhere((s) => s.$2 < cutoff);
    if (_history.length < 3) return 0.0;

    final velocities = <(Offset, double)>[];
    for (var i = 1; i < _history.length; i++) {
      final dt = _history[i].$2 - _history[i - 1].$2;
      if (dt <= 0) continue;
      velocities.add((
        (_history[i].$1 - _history[i - 1].$1) / dt,
        (_history[i].$2 + _history[i - 1].$2) / 2,
      ));
    }
    if (velocities.length < 2) return 0.0;

    var totalDx = 0.0;
    var count = 0;
    for (var i = 1; i < velocities.length; i++) {
      final dt = velocities[i].$2 - velocities[i - 1].$2;
      if (dt <= 0) continue;
      totalDx += (velocities[i].$1.dx - velocities[i - 1].$1.dx) / dt;
      count++;
    }
    if (count == 0) return 0.0;
    return totalDx / count;
  }

  void _onTick(Duration elapsed) {
    final last = _lastElapsed ?? elapsed;
    final dt = (elapsed - last).inMicroseconds / 1e6;
    _lastElapsed = elapsed;

    if (dt <= 0) return;

    // 1. Travel Positional Spring
    bool travelSettled = true;
    if (_travelActive) {
      final r = _springStep(
        x: _travelPos,
        vel: _travelVel,
        target: _travelTarget,
        dt: dt,
        stiffness: widget.travelStiffness,
        damping: widget.travelDamping,
      );
      _travelPos = r.$1;
      _travelVel = r.$2;
      travelSettled =
          (_travelPos - _travelTarget).abs() < 0.003 && _travelVel.abs() < 0.05;
      if (travelSettled) {
        _travelPos = _travelTarget;
        _travelVel = 0.0;
        _travelActive = false;
      }
    }

    // 2. Drag Follow (Exponential low-pass)
    if (_tabDragging) {
      _dragFollow += (_dragTargetFrac - _dragFollow) *
          (1 - math.exp(-dt / widget.followTau));
    }

    // 3. Travel Progress and Handover Gate
    final double span = (_travelTarget - _travelFrom).abs();
    final double progress = span < 1e-6
        ? 1.0
        : (1.0 - (_travelTarget - _travelPos).abs() / span).clamp(0.0, 1.0);

    // Release lift on arrival or passing 92% handover threshold
    if (!_tabDragging && (travelSettled || progress >= 0.92)) {
      _lifted = false;
    }

    // 4. Dual-Axis Lift Springs (Width & Height)
    final double liftTarget = _lifted ? 1.0 : 0.0;
    final xr = _springStep(
      x: _liftX,
      vel: _liftXVel,
      target: liftTarget,
      dt: dt,
      stiffness: widget.liftStiffness,
      damping: widget.liftDampingX,
    );
    _liftX = xr.$1;
    _liftXVel = xr.$2;

    final yr = _springStep(
      x: _liftY,
      vel: _liftYVel,
      target: liftTarget,
      dt: dt,
      stiffness: widget.liftStiffness,
      damping: widget.liftDampingY,
    );
    _liftY = yr.$1;
    _liftYVel = yr.$2;

    final bool liftSettled = !_lifted &&
        (_liftX - 0.0).abs() < 0.005 &&
        (_liftY - 0.0).abs() < 0.005;
    if (liftSettled) {
      _liftX = 0.0;
      _liftXVel = 0.0;
      _liftY = 0.0;
      _liftYVel = 0.0;
    }

    // 5. Acceleration Tracking & Deformation
    final double baseWidth = widget.width ?? QuickNotesLiquidGlassTabBar._figmaWidth;
    final double scale =
        (baseWidth / QuickNotesLiquidGlassTabBar._figmaWidth).clamp(0.65, 1.0);
    final double currentPillFrac = _tabDragging ? _dragFollow : _travelPos;
    final double currentPillX = _getCenter(currentPillFrac, scale);
    final double nowSeconds = elapsed.inMicroseconds / 1e6;

    if (_travelActive || _tabDragging) {
      _history.add((Offset(currentPillX, 0.0), nowSeconds));
      final avgAccel = _computeAverageAcceleration(nowSeconds);
      final rawDev = (avgAccel * widget.sensitivity)
          .clamp(-widget.maxDeformation, widget.maxDeformation);
      final ease = widget.responseTime <= 0
          ? 1.0
          : (dt / widget.responseTime).clamp(0.0, 1.0);
      _deviation += (rawDev - _deviation) * ease;
    } else {
      _history.clear();
      _deviation += (0.0 - _deviation) * (1 - math.exp(-dt / 0.05));
      if (_deviation.abs() < 0.001) _deviation = 0.0;
    }

    // Smooth directional reversal cross-fade
    if (_travelSignEased == 0) {
      _travelSignEased = _travelSign;
    } else if (_travelSignEased != _travelSign) {
      _travelSignEased += (_travelSign - _travelSignEased) *
          (1 - math.exp(-dt / widget.signTau));
      if ((_travelSign - _travelSignEased).abs() < 0.01) {
        _travelSignEased = _travelSign;
      }
    }

    // 6. Handover (Glass presence)
    final double handoverTarget = _lifted ? 0.0 : 1.0;
    final double tau = handoverTarget > _handover ? 0.09 : 0.05;
    _handover += (handoverTarget - _handover) * (1 - math.exp(-dt / tau));
    if ((handoverTarget - _handover).abs() < 0.002) _handover = handoverTarget;
    if (!_lifted && _handover >= 0.99) _handover = 1.0;

    // Settle Check
    final bool motionSettled = _deviation == 0.0;
    final bool handoverSettled = _handover == 1.0;
    if (!_travelActive &&
        !_tabDragging &&
        liftSettled &&
        motionSettled &&
        handoverSettled) {
      _travelSign = 0.0;
      _travelSignEased = 0.0;
      _ticker?.stop();
      _notifyPhysicsActive(false);
    }

    if (mounted) setState(() {});
  }

  // ── Gesture Handling ─────────────────────────────────────────────────────
  double _xToFrac(double localX, double scale) {
    final raw = (localX / scale - 40.0) / (184.0 / 3.0);
    return raw.clamp(0.0, 3.0);
  }

  void _onTapUp(TapUpDetails d, double scale) {
    final raw = (d.localPosition.dx / scale - 40.0) / (184.0 / 3.0);
    final next = raw.round().clamp(0, 3);
    if (next != _selectedIndex) {
      QuickNotesHaptics.navigationSelection();
    }
    _animateTo(next, notify: true);
  }

  void _onLongPressStart(LongPressStartDetails d, double scale) {
    final frac = _xToFrac(d.localPosition.dx, scale);
    _tabDragging = true;
    _travelActive = false;
    _lifted = true;
    _travelSign = 0.0;
    _pressFrac = frac;
    _dragFollow = _travelPos;
    _dragTargetFrac = frac;
    _draggedRealMove = false;
    _startTicker();
    setState(() {});
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails d, double scale) {
    if (!_tabDragging) return;
    final frac = _xToFrac(d.localPosition.dx, scale);
    if ((frac - _pressFrac).abs() > widget.dragThreshold) {
      _draggedRealMove = true;
    }
    setState(() {
      _dragTargetFrac = frac;
    });
  }

  void _onLongPressEnd(LongPressEndDetails d) {
    if (!_tabDragging) return;
    _releaseDrag();
  }

  void _onLongPressCancel() {
    if (!_tabDragging) return;
    _releaseDrag();
  }

  void _releaseDrag() {
    final from = _dragFollow;
    final double snapFrac = _draggedRealMove ? from : _pressFrac;
    final next = snapFrac.round().clamp(0, 3);
    final notify = next != _selectedIndex;

    if (notify) {
      QuickNotesHaptics.navigationSelection();
    }

    setState(() {
      _tabDragging = false;
      _selectedIndex = next;
      _travelActive = true;
      _travelPos = from;
      _travelVel = 0.0;
      _travelFrom = from;
      _travelTarget = next.toDouble();
      final span = _travelTarget - _travelFrom;
      _travelSign = span.abs() < 1e-6 ? 0.0 : span.sign;
    });
    _startTicker();
    if (notify) widget.onDestinationSelected(next);
  }

  Widget _buildIconRow({
    required bool selected,
    required double scale,
    required bool isDark,
    required int selectedIndex,
  }) {
    final unselectedColor = isDark ? Colors.white60 : const Color(0xFF333333);
    const selectedColor = Colors.white;
    final color = selected ? selectedColor : unselectedColor;

    return Stack(
      children: [
        for (var i = 0; i < 4; i++)
          Positioned(
            left: (40.0 + i * (184.0 / 3.0) - 35.0) * scale,
            top: 0,
            width: 70.0 * scale,
            height: QuickNotesLiquidGlassTabBar._controlHeight * scale,
            child: Center(
              child: SvgPicture.asset(
                AppBottomNavigationDestination.defaults[i].iconAsset,
                width: 22.0 * scale,
                height: 22.0 * scale,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveIsDark =
        widget.isDark ?? (Theme.of(context).brightness == Brightness.dark);
    final effectiveWidth =
        widget.width ?? QuickNotesLiquidGlassTabBar._figmaWidth;
    final scale = (effectiveWidth / QuickNotesLiquidGlassTabBar._figmaWidth)
        .clamp(0.65, 1.0);
    final barW = QuickNotesLiquidGlassTabBar._barWidth * scale;
    final controlH = QuickNotesLiquidGlassTabBar._controlHeight * scale;
    final gapW = QuickNotesLiquidGlassTabBar._gap * scale;
    final totalW = barW + gapW + controlH;

    final currentFrac = _tabDragging ? _dragFollow : _travelPos;

    // Resting geometry matching production _PhysicalActiveIndicator
    final pillRestW = 70.0 * scale;
    final pillRestH = 43.0 * scale;
    final pillLiftedH = pillRestH + widget.pillGrowHeight * scale;
    final pillLiftedW = pillLiftedH * (pillRestW / pillRestH);

    final envelopeW = pillRestW + (pillLiftedW - pillRestW) * _liftX;
    final envelopeH = pillRestH + (pillLiftedH - pillRestH) * _liftY;

    // Directional deformation
    final double key = _travelSignEased;
    double effectiveDev = _deviation;
    if (key != 0) {
      effectiveDev = effectiveDev * (1 - key.abs()) - key * effectiveDev.abs();
    }

    final liveW = envelopeW * (1 + effectiveDev);
    final liveH = envelopeH * (1 - effectiveDev);

    final pillCX = _getCenter(currentFrac, scale);
    final pillCY = controlH / 2.0;

    final pillRect = Rect.fromCenter(
      center: Offset(pillCX, pillCY),
      width: liveW,
      height: liveH,
    );
    final pillRadius = liveH / 2.0;

    return SizedBox(
      key: const ValueKey('quick_notes_navigation_row'),
      width: totalW,
      height: controlH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Sibling 1: Independent FAB (isolated glass pass, painted FIRST so BackdropFilter samples ONLY clean background)
          Positioned(
            left: barW + gapW,
            top: 0,
            width: controlH,
            height: controlH,
            child: RepaintBoundary(
              key: const ValueKey('fab_repaint_boundary'),
              child: _QuickNotesNavigationFab(
                key: const ValueKey('quick_notes_navigation_fab'),
                size: controlH,
                scale: scale,
                selectedIndex: widget.selectedIndex,
                folderModeActive: widget.folderModeActive,
                onFabPressed: widget.onFabPressed,
                onChanged: widget.onDestinationSelected,
                onAnimationActiveChanged: widget.onFabAnimationActiveChanged,
                isDark: effectiveIsDark,
              ),
            ),
          ),

          // ── Sibling 2: Independent 4px Gap
          Positioned(
            left: barW,
            top: 0,
            width: gapW,
            height: controlH,
            child: const SizedBox(
              key: ValueKey('quick_notes_navigation_gap'),
            ),
          ),

          // ── Sibling 3: Main Navigation Capsule (stationary glass capsule + unselected icons)
          Positioned(
            left: 0,
            top: 0,
            width: barW,
            height: controlH,
            child: RepaintBoundary(
              key: const ValueKey('main_nav_repaint_boundary'),
              child: ClipRect(
                key: const ValueKey('main_nav_shadow_clip'),
                clipper: _MainNavShadowIsolationClipper(
                  barW: barW,
                  gapW: gapW,
                  controlH: controlH,
                ),
                child: _QuickNotesMainNavigationBar(
                  key: const ValueKey('quick_notes_main_navigation_bar'),
                  width: barW,
                  height: controlH,
                  scale: scale,
                  isDark: effectiveIsDark,
                  pillRect: pillRect,
                  pillRadius: pillRadius,
                  selectedIndex: _selectedIndex,
                  longPressMs: widget.longPressMs,
                  onTapUp: (d) => _onTapUp(d, scale),
                  onLongPressStart: (d) => _onLongPressStart(d, scale),
                  onLongPressMoveUpdate: (d) =>
                      _onLongPressMoveUpdate(d, scale),
                  onLongPressEnd: _onLongPressEnd,
                  onLongPressCancel: _onLongPressCancel,
                  onSemanticsTap: (i) {
                    if (i != _selectedIndex) {
                      QuickNotesHaptics.navigationSelection();
                    }
                    _animateTo(i, notify: true);
                  },
                ),
              ),
            ),
          ),

          // ── Sibling 4: Yellow Liquid Glass Selection Pill (Independent Floating Overlay)
          Positioned(
            left: pillRect.left,
            top: pillRect.top,
            width: pillRect.width,
            height: pillRect.height,
            child: IgnorePointer(
              child: RepaintBoundary(
                key: const ValueKey('yellow_pill_repaint_boundary'),
                child: ClipRect(
                  clipper: _PillShadowIsolationClipper(
                    pillLeft: pillRect.left,
                    pillWidth: pillRect.width,
                    barW: barW,
                    gapW: gapW,
                    controlH: controlH,
                  ),
                  child: Container(
                    key: const ValueKey('quick_notes_tabbar_selection_pill'),
                    child: _QuickNotesYellowGlassPill(
                      key: const ValueKey('physical_active_indicator'),
                      width: pillRect.width,
                      height: pillRect.height,
                      borderRadius: BorderRadius.circular(pillRadius),
                      scale: scale,
                      isDark: effectiveIsDark,
                      activeColor:
                          widget.activeColor ?? const Color(0xFFFFCC00),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Sibling 5: Selected White Icons Aperture Layer (anchored to navigation coordinates)
          Positioned(
            left: 0,
            top: 0,
            width: barW,
            height: controlH,
            child: IgnorePointer(
              child: ClipPath(
                clipper: _InsidePillClipper(
                  pillRect: pillRect,
                  pillRadius: pillRadius,
                ),
                child: _buildIconRow(
                  selected: true,
                  scale: scale,
                  isDark: effectiveIsDark,
                  selectedIndex: _selectedIndex,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickNotesMainNavigationBar extends StatelessWidget {
  final double width;
  final double height;
  final double scale;
  final bool isDark;
  final Rect pillRect;
  final double pillRadius;
  final int selectedIndex;
  final int longPressMs;
  final GestureTapUpCallback onTapUp;
  final GestureLongPressStartCallback onLongPressStart;
  final GestureLongPressMoveUpdateCallback onLongPressMoveUpdate;
  final GestureLongPressEndCallback onLongPressEnd;
  final GestureLongPressCancelCallback onLongPressCancel;
  final ValueChanged<int> onSemanticsTap;

  const _QuickNotesMainNavigationBar({
    super.key,
    required this.width,
    required this.height,
    required this.scale,
    required this.isDark,
    required this.pillRect,
    required this.pillRadius,
    required this.selectedIndex,
    required this.longPressMs,
    required this.onTapUp,
    required this.onLongPressStart,
    required this.onLongPressMoveUpdate,
    required this.onLongPressEnd,
    required this.onLongPressCancel,
    required this.onSemanticsTap,
  });

  @override
  Widget build(BuildContext context) {
    final unselectedColor = isDark ? Colors.white60 : const Color(0xFF333333);

    return BottomBarGlassSurface(
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(25.0 * scale),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25.0 * scale),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Layer 1: Outside Pill Aperture (Unselected Icons - Dark Ink)
            Positioned.fill(
              child: IgnorePointer(
                child: ClipPath(
                  clipper: _OutsidePillClipper(
                    pillRect: pillRect,
                    pillRadius: pillRadius,
                  ),
                  child: Stack(
                    children: [
                      for (var i = 0; i < 4; i++)
                        Positioned(
                          left: (40.0 + i * (184.0 / 3.0) - 35.0) * scale,
                          top: 0,
                          width: 70.0 * scale,
                          height: height,
                          child: Center(
                            child: SvgPicture.asset(
                              AppBottomNavigationDestination
                                  .defaults[i].iconAsset,
                              width: 22.0 * scale,
                              height: 22.0 * scale,
                              colorFilter: ColorFilter.mode(
                                  unselectedColor, BlendMode.srcIn),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Layer 2: Unified Gesture Overlay for Main Navigation Bar (4 destinations)
            Positioned.fill(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: RawGestureDetector(
                      behavior: HitTestBehavior.opaque,
                      gestures: {
                        TapGestureRecognizer:
                            GestureRecognizerFactoryWithHandlers<
                                TapGestureRecognizer>(
                          () => TapGestureRecognizer(),
                          (instance) {
                            instance.onTapUp = onTapUp;
                          },
                        ),
                        LongPressGestureRecognizer:
                            GestureRecognizerFactoryWithHandlers<
                                LongPressGestureRecognizer>(
                          () => LongPressGestureRecognizer(
                            duration: Duration(milliseconds: longPressMs),
                          ),
                          (instance) {
                            instance.onLongPressStart = onLongPressStart;
                            instance.onLongPressMoveUpdate =
                                onLongPressMoveUpdate;
                            instance.onLongPressEnd = onLongPressEnd;
                            instance.onLongPressCancel = onLongPressCancel;
                          },
                        ),
                      },
                    ),
                  ),
                  for (var i = 0; i < 4; i++)
                    Positioned(
                      left: (40.0 + i * (184.0 / 3.0) - 35.0) * scale,
                      top: 0,
                      width: 70.0 * scale,
                      height: height,
                      child: Semantics(
                        button: true,
                        enabled: true,
                        label: AppBottomNavigationDestination.defaults[i].label,
                        selected: selectedIndex == i,
                        onTap: () => onSemanticsTap(i),
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: () => onSemanticsTap(i),
                          child: const SizedBox.expand(),
                        ),
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

/// Quick Notes Yellow Liquid Glass Selection Pill
class _QuickNotesYellowGlassPill extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;
  final double scale;
  final bool isDark;
  final Color activeColor;

  const _QuickNotesYellowGlassPill({
    super.key,
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.scale,
    required this.isDark,
    this.activeColor = const Color(0xFFFFCC00),
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: inset.BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: GlassmorphismPresets.shadows,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: GlassmorphismPresets.blurSigma,
            sigmaY: GlassmorphismPresets.blurSigma,
          ),
          child: CustomPaint(
            foregroundPainter: _InnerGlassBorderPainter(
              borderRadius: borderRadius,
            ),
            child: SizedBox(
              width: width,
              height: height,
              child: DecoratedBox(
                decoration: inset.BoxDecoration(
                  borderRadius: borderRadius,
                  color: activeColor.withValues(alpha: isDark ? 0.78 : 0.82),
                  boxShadow: GlassmorphismPresets.innerShadows,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.55),
                    width: 0.8,
                  ),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: borderRadius,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.72),
                        Colors.white.withValues(alpha: 0.0),
                        scheme.surfaceTint.withValues(alpha: 0.06),
                        Colors.black.withValues(alpha: 0.035),
                      ],
                      stops: const [0.0, 0.42, 0.78, 1.0],
                    ),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InnerGlassBorderPainter extends CustomPainter {
  const _InnerGlassBorderPainter({required this.borderRadius});

  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    return;
  }

  @override
  bool shouldRepaint(_InnerGlassBorderPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius;
  }
}

/// Prevents the Yellow Selection Pill's outer BoxShadow from casting or bleeding
/// underneath the FAB's physical region (x >= barW + gapW).
class _PillShadowIsolationClipper extends CustomClipper<Rect> {
  final double pillLeft;
  final double pillWidth;
  final double barW;
  final double gapW;
  final double controlH;

  const _PillShadowIsolationClipper({
    required this.pillLeft,
    required this.pillWidth,
    required this.barW,
    required this.gapW,
    required this.controlH,
  });

  @override
  Rect getClip(Size size) {
    final maxRight = (barW + gapW) - pillLeft;
    return Rect.fromLTRB(-50.0, -50.0, maxRight, size.height + 50.0);
  }

  @override
  bool shouldReclip(_PillShadowIsolationClipper oldClipper) {
    return oldClipper.pillLeft != pillLeft ||
        oldClipper.pillWidth != pillWidth ||
        oldClipper.barW != barW ||
        oldClipper.gapW != gapW ||
        oldClipper.controlH != controlH;
  }
}

// ── Independent Floating Action Button (FAB) ────────────────────────────────

class _QuickNotesNavigationFab extends StatefulWidget {
  final double size;
  final double scale;
  final int selectedIndex;
  final bool folderModeActive;
  final VoidCallback? onFabPressed;
  final ValueChanged<int> onChanged;
  final ValueChanged<bool>? onAnimationActiveChanged;
  final bool isDark;

  const _QuickNotesNavigationFab({
    super.key,
    required this.size,
    required this.scale,
    required this.selectedIndex,
    this.folderModeActive = false,
    this.onFabPressed,
    required this.onChanged,
    this.onAnimationActiveChanged,
    required this.isDark,
  });

  @override
  State<_QuickNotesNavigationFab> createState() =>
      _QuickNotesNavigationFabState();
}

class _QuickNotesNavigationFabState extends State<_QuickNotesNavigationFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  void _notifyAnimationActive() {
    final active = _isPressed || _scaleController.isAnimating;
    widget.onAnimationActiveChanged?.call(active);
  }

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(vsync: this);
    _scaleController.addStatusListener((status) {
      _notifyAnimationActive();
    });
    _scaleAnimation = const AlwaysStoppedAnimation<double>(1.0);
  }

  @override
  void dispose() {
    widget.onAnimationActiveChanged?.call(false);
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTapDown(bool reduceMotion) {
    if (reduceMotion) return;
    _isPressed = true;
    _notifyAnimationActive();
    _scaleController.stop();
    _scaleController.duration = QuickNotesMotion.kMotionMicro;
    setState(() {
      _scaleAnimation = Tween<double>(
        begin: _scaleAnimation.value,
        end: 0.94,
      ).animate(CurvedAnimation(
        parent: _scaleController,
        curve: Curves.easeIn,
      ));
    });
    _scaleController.forward(from: 0.0);
  }

  void _handleTapCancel(bool reduceMotion) {
    if (reduceMotion) return;
    _isPressed = false;
    _notifyAnimationActive();
    _scaleController.stop();
    _scaleController.duration = QuickNotesMotion.kMotionRelease;
    setState(() {
      _scaleAnimation = Tween<double>(
        begin: _scaleAnimation.value,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _scaleController,
        curve: Curves.easeOutCubic,
      ));
    });
    _scaleController.forward(from: 0.0);
  }

  void _handleTap(bool reduceMotion) {
    QuickNotesHaptics.buttonPress();
    _isPressed = false;
    if (reduceMotion) {
      _notifyAnimationActive();
      widget.onFabPressed?.call();
      widget.onChanged(4);
      return;
    }
    _scaleController.stop();
    _scaleController.duration = QuickNotesMotion.kMotionRelease;
    setState(() {
      _scaleAnimation = TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween<double>(begin: _scaleAnimation.value, end: 1.018)
              .chain(CurveTween(curve: Curves.easeOutCubic)),
          weight: 60,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.018, end: 1.0)
              .chain(CurveTween(curve: Curves.easeInOutCubic)),
          weight: 40,
        ),
      ]).animate(_scaleController);
    });
    _scaleController.forward(from: 0.0);
    _notifyAnimationActive();
    widget.onFabPressed?.call();
    widget.onChanged(4);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final isFolderActive =
        widget.folderModeActive || widget.selectedIndex == 1;

    final fabGlassBody = BottomBarGlassSurface(
      key: const ValueKey('fab_glass_surface'),
      width: widget.size,
      height: widget.size,
      borderRadius: BorderRadius.circular(25.0 * widget.scale),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25.0 * widget.scale),
        clipBehavior: Clip.antiAlias,
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) {
              return ScaleTransition(
                scale: animation,
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
            child: isFolderActive
                ? Icon(
                    Icons.add_rounded,
                    key: const ValueKey('plus_icon'),
                    size: 22.0 * widget.scale,
                    color:
                        widget.isDark ? Colors.white : const Color(0xFF333333),
                  )
                : SvgPicture.asset(
                    AppBottomNavigationAssets.pencil,
                    key: const ValueKey('pencil_icon'),
                    width: 22.0 * widget.scale,
                    height: 22.0 * widget.scale,
                    colorFilter: ColorFilter.mode(
                      widget.isDark ? Colors.white : const Color(0xFF333333),
                      BlendMode.srcIn,
                    ),
                  ),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: true,
      label: isFolderActive
          ? 'Add folder'
          : AppBottomNavigationDestination.defaults[4].label,
      onTap: () => _handleTap(reduceMotion),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _handleTapDown(reduceMotion),
        onTapCancel: () => _handleTapCancel(reduceMotion),
        onTap: () => _handleTap(reduceMotion),
        child: AnimatedBuilder(
          animation: _scaleController,
          builder: (context, child) {
            return Transform.scale(
              key: const ValueKey('fab_scale_transform'),
              scale: reduceMotion ? 1.0 : _scaleAnimation.value,
              child: child,
            );
          },
          child: fabGlassBody,
        ),
      ),
    );
  }
}

// ── Standard Flutter Clippers for Dual-Layer Aperture Reveal ────────────────

class _InsidePillClipper extends CustomClipper<Path> {
  final Rect pillRect;
  final double pillRadius;

  _InsidePillClipper({required this.pillRect, required this.pillRadius});

  @override
  Path getClip(Size size) {
    return Path()
      ..addRRect(RRect.fromRectAndRadius(
        pillRect,
        Radius.circular(pillRadius),
      ));
  }

  @override
  bool shouldReclip(_InsidePillClipper oldClipper) =>
      oldClipper.pillRect != pillRect || oldClipper.pillRadius != pillRadius;
}

class _OutsidePillClipper extends CustomClipper<Path> {
  final Rect pillRect;
  final double pillRadius;

  _OutsidePillClipper({required this.pillRect, required this.pillRadius});

  @override
  Path getClip(Size size) {
    final full = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final pill = Path()
      ..addRRect(RRect.fromRectAndRadius(
        pillRect,
        Radius.circular(pillRadius),
      ));
    return Path.combine(PathOperation.difference, full, pill);
  }

  @override
  bool shouldReclip(_OutsidePillClipper oldClipper) =>
      oldClipper.pillRect != pillRect || oldClipper.pillRadius != pillRadius;
}

/// Prevents the Main Navigation bar's outer BoxShadow (blurRadius: 15, offset: (0, 8))
/// from casting or bleeding underneath the FAB's physical region (x >= barW + gapW).
class _MainNavShadowIsolationClipper extends CustomClipper<Rect> {
  const _MainNavShadowIsolationClipper({
    required this.barW,
    required this.gapW,
    required this.controlH,
  });

  final double barW;
  final double gapW;
  final double controlH;

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(-50.0, -50.0, barW + gapW, controlH + 50.0);
  }

  @override
  bool shouldReclip(_MainNavShadowIsolationClipper oldClipper) {
    return oldClipper.barW != barW ||
        oldClipper.gapW != gapW ||
        oldClipper.controlH != controlH;
  }
}
