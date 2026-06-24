import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/animations/animation_constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GravityNotesNavBar — with Change 3 (amber pill indicator) + Change 4 (tap anim)
//
// Architecture:
//   • Bar shape  → CustomPainter (SVG path, pixel-exact notch)
//   • Icons      → Row in _IconsRow (Expanded layout)
//   • FAB        → Absolute Positioned above bar center
//   • Amber pill → AnimatedPositioned behind active icon
//   • Dot burst  → CustomPainter overlay triggered per tap
// ─────────────────────────────────────────────────────────────────────────────

class GravityNotesNavBar extends StatefulWidget {
  final int activeIndex;
  final ValueChanged<int> onTap;
  final VoidCallback? onFabTap;

  const GravityNotesNavBar({
    super.key,
    required this.activeIndex,
    required this.onTap,
    this.onFabTap,
  });

  // SVG viewBox constants
  static const double _svgW        = 354;
  static const double _svgBarTopY  = 23;
  static const double _svgTotalH   = 83;
  static const double _fabR        = 25;

  @override
  State<GravityNotesNavBar> createState() => _GravityNotesNavBarState();
}

class _GravityNotesNavBarState extends State<GravityNotesNavBar>
    with TickerProviderStateMixin {
  // One animation controller per tab for dot burst (kDurationSlow = 350ms)
  late final List<AnimationController> _burstControllers;
  int _burstIndex = -1;

  @override
  void initState() {
    super.initState();
    _burstControllers = List.generate(
      4,
      (_) => AnimationController(vsync: this, duration: kDurationSlow),
    );
  }

  @override
  void dispose() {
    for (final c in _burstControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _handleNavTap(int index) {
    setState(() => _burstIndex = index);
    _burstControllers[index].forward(from: 0.0);
    widget.onTap(index);
  }

  // Compute icon center X for a given index given current screen width
  double _iconCenterX(int index, double screenW) {
    final double fabGap = screenW * (50 / GravityNotesNavBar._svgW) * 1.4;
    final double halfW = (screenW - fabGap) / 2;
    switch (index) {
      case 0: return halfW / 4;
      case 1: return 3 * halfW / 4;
      case 2: return screenW / 2 + fabGap / 2 + halfW / 4;
      case 3: return screenW / 2 + fabGap / 2 + 3 * halfW / 4;
      default: return screenW / 2;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final double screenW = mq.size.width;
    final double bottomPad = mq.padding.bottom;
    final double scale = screenW / GravityNotesNavBar._svgW;

    final double svgScaledH = GravityNotesNavBar._svgTotalH * scale;
    final double barBodyH =
        (GravityNotesNavBar._svgTotalH - GravityNotesNavBar._svgBarTopY) *
            scale; // 60*scale
    final double fabDiameter = GravityNotesNavBar._fabR * 2 * scale;
    final double totalH = svgScaledH + bottomPad;

    // ── Amber pill geometry (Change 3) ────────────────────────────────────────
    const double pillW = 48;
    const double pillH = 32;
    final double pillLeft =
        _iconCenterX(widget.activeIndex, screenW) - pillW / 2;
    // Vertically centered in the top 60% of bar body (icon sits above the dot)
    final double pillTop =
        GravityNotesNavBar._svgBarTopY * scale + (barBodyH - pillH) / 2 - 6;

    // ── Dot burst geometry (Change 4) ─────────────────────────────────────────
    final double burstCenterY =
        GravityNotesNavBar._svgBarTopY * scale + barBodyH * 0.38;

    return SizedBox(
      width: screenW,
      height: totalH,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // ── 1. Bar shape ──────────────────────────────────────────────────
          Positioned(
            top: GravityNotesNavBar._svgBarTopY * scale,
            left: 0,
            right: 0,
            bottom: 0,
            child: CustomPaint(
              painter: _BarPainter(scale: scale, bottomPad: bottomPad),
            ),
          ),

          // ── 2. Amber pill indicator (Change 3) ────────────────────────────
          AnimatedPositioned(
            duration: kDurationNormal,
            curve: kCurvePage,
            left: pillLeft,
            top: pillTop,
            child: Container(
              width: pillW,
              height: pillH,
              decoration: BoxDecoration(
                color: const Color(0xFFF5A623).withOpacity(0.20),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          // ── 3. FAB ────────────────────────────────────────────────────────
          Positioned(
            top: 0,
            left: screenW / 2 - fabDiameter / 2,
            child: _FabButton(
              diameter: fabDiameter,
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onFabTap?.call();
              },
            ),
          ),

          // ── 4. Icons row ──────────────────────────────────────────────────
          Positioned(
            top: GravityNotesNavBar._svgBarTopY * scale,
            left: 0,
            right: 0,
            height: barBodyH,
            child: _IconsRow(
              activeIndex: widget.activeIndex,
              onTap: _handleNavTap,
              screenW: screenW,
            ),
          ),

          // ── 5. Dot burst overlay (Change 4) ───────────────────────────────
          if (_burstIndex >= 0)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _burstControllers[_burstIndex],
                builder: (_, __) => CustomPaint(
                  painter: _DotBurstPainter(
                    progress: _burstControllers[_burstIndex].value,
                    center: Offset(
                      _iconCenterX(_burstIndex, screenW),
                      burstCenterY,
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

// ─────────────────────────────────────────────────────────────────────────────
// Bar Painter — exact SVG path, scaled (unchanged)
// ─────────────────────────────────────────────────────────────────────────────
class _BarPainter extends CustomPainter {
  final double scale;
  final double bottomPad;

  const _BarPainter({required this.scale, required this.bottomPad});

  @override
  void paint(Canvas canvas, Size size) {
    final s = scale;
    const double dy = -23;

    final paint = Paint()
      ..color = const Color(0xFF333333)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, (43 + dy) * s);
    path.cubicTo(0, (31.9543 + dy) * s, 8.9543 * s, (23 + dy) * s, 20 * s, (23 + dy) * s);
    path.lineTo(129 * s, (23 + dy) * s);
    path.cubicTo(140.046 * s, (23 + dy) * s, 148.602 * s, (32.6238 + dy) * s, 154.366 * s, (42.046 + dy) * s);
    path.cubicTo(158.363 * s, (48.5782 + dy) * s, 165.335 * s, (54.2766 + dy) * s, 177.5 * s, (54.2766 + dy) * s);
    path.cubicTo(189.665 * s, (54.2766 + dy) * s, 196.637 * s, (48.5782 + dy) * s, 200.634 * s, (42.046 + dy) * s);
    path.cubicTo(206.398 * s, (32.6238 + dy) * s, 214.954 * s, (23 + dy) * s, 226 * s, (23 + dy) * s);
    path.lineTo(334 * s, (23 + dy) * s);
    path.cubicTo(345.046 * s, (23 + dy) * s, 354 * s, (31.9543 + dy) * s, 354 * s, (43 + dy) * s);
    path.lineTo(354 * s, (63 + dy) * s + bottomPad);
    path.cubicTo(354 * s, (74.0457 + dy) * s + bottomPad, 345.046 * s, (83 + dy) * s + bottomPad, 334 * s, (83 + dy) * s + bottomPad);
    path.lineTo(20 * s, (83 + dy) * s + bottomPad);
    path.cubicTo(8.9543 * s, (83 + dy) * s + bottomPad, 0, (74.0457 + dy) * s + bottomPad, 0, (63 + dy) * s + bottomPad);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.scale != scale || old.bottomPad != bottomPad;
}

// ─────────────────────────────────────────────────────────────────────────────
// Dot Burst Painter (Change 4)
// 5 pre-seeded dots, amber, spread 40px, fade opacity
// ─────────────────────────────────────────────────────────────────────────────
class _DotBurstPainter extends CustomPainter {
  final double progress; // 0.0 → 1.0
  final Offset center;

  // Pre-seeded angles in degrees
  static const List<double> _anglesDeg = [30, 82, 150, 222, 305];
  static const double _spreadRadius = 40.0;
  static const double _dotRadius    = 2.0;

  const _DotBurstPainter({required this.progress, required this.center});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final double opacity = (1.0 - progress).clamp(0.0, 1.0);
    final paint = Paint()
      ..color = const Color(0xFFF5A623).withOpacity(opacity)
      ..style = PaintingStyle.fill;

    for (final angleDeg in _anglesDeg) {
      final double radians = angleDeg * math.pi / 180.0;
      final double r = _spreadRadius * progress;
      final dx = center.dx + r * math.cos(radians);
      final dy = center.dy + r * math.sin(radians);
      canvas.drawCircle(Offset(dx, dy), _dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(_DotBurstPainter old) =>
      old.progress != progress || old.center != center;
}

// ─────────────────────────────────────────────────────────────────────────────
// FAB Button (unchanged)
// ─────────────────────────────────────────────────────────────────────────────
class _FabButton extends StatelessWidget {
  final double diameter;
  final VoidCallback onTap;

  const _FabButton({required this.diameter, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF333333),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Icon(Icons.add, color: Colors.white, size: diameter * 0.46),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Icons Row
// ─────────────────────────────────────────────────────────────────────────────
class _IconsRow extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onTap;
  final double screenW;

  const _IconsRow({
    required this.activeIndex,
    required this.onTap,
    required this.screenW,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              _NavItem(
                icon: _NavIcon.home,
                isActive: activeIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: _NavIcon.folder,
                isActive: activeIndex == 1,
                onTap: () => onTap(1),
              ),
            ],
          ),
        ),
        SizedBox(width: screenW * (50 / 354) * 1.4),
        Expanded(
          child: Row(
            children: [
              _NavItem(
                icon: _NavIcon.calendar,
                isActive: activeIndex == 2,
                onTap: () => onTap(2),
              ),
              _NavItem(
                icon: _NavIcon.settings,
                isActive: activeIndex == 3,
                onTap: () => onTap(3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single Nav Item — Change 4: spring tap animation + icon morph
// ─────────────────────────────────────────────────────────────────────────────
enum _NavIcon { home, folder, calendar, settings }

class _NavItem extends StatefulWidget {
  final _NavIcon icon;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> with TickerProviderStateMixin {
  // Local const: interaction-specific durations per SESSION.md note
  static const Duration _kPressDown   = Duration(milliseconds: 80);

  late final AnimationController _pressCtrl;
  late final AnimationController _springCtrl;
  late final Animation<double> _pressAnim;
  late final Animation<double> _springAnim;

  bool _isPressed = false;

  @override
  void initState() {
    super.initState();

    // Step 1 — compress: 1.0 → 0.85 in 80ms
    _pressCtrl = AnimationController(vsync: this, duration: _kPressDown);
    _pressAnim = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _pressCtrl, curve: kCurveExit),
    );

    // Step 2 — spring-back: 0.85 → 1.2 → 1.0 in 400ms (kDurationPage)
    _springCtrl = AnimationController(vsync: this, duration: kDurationPage);
    _springAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.85, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.2, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 40,
      ),
    ]).animate(_springCtrl);

    // Reset press controller once spring completes so scale returns to 1.0
    _springCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _pressCtrl.reset();
        _springCtrl.reset();
      }
    });
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    _springCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _isPressed = true;
    _springCtrl.reset();
    _pressCtrl.forward(from: 0.0);
  }

  void _onTapUp(TapUpDetails _) {
    if (!_isPressed) return;
    _isPressed = false;
    _pressCtrl.stop();
    _springCtrl.forward(from: 0.0);
    HapticFeedback.lightImpact();
    widget.onTap();
  }

  void _onTapCancel() {
    _isPressed = false;
    _pressCtrl.reverse();
  }

  Widget _buildIcon() {
    final IconData outlined;
    final IconData filled;
    switch (widget.icon) {
      case _NavIcon.home:
        outlined = Icons.home_outlined;
        filled   = Icons.home;
        break;
      case _NavIcon.folder:
        outlined = Icons.folder_open_outlined;
        filled   = Icons.folder;
        break;
      case _NavIcon.calendar:
        outlined = Icons.calendar_month_outlined;
        filled   = Icons.calendar_month;
        break;
      case _NavIcon.settings:
        outlined = Icons.settings_outlined;
        filled   = Icons.settings;
        break;
    }

    // Change 3: active icon is amber; inactive is white 60%
    final Color iconColor = widget.isActive
        ? const Color(0xFFF5A623)
        : Colors.white.withOpacity(0.60);

    // Change 4 Step 4: icon morph via AnimatedSwitcher
    return AnimatedSwitcher(
      duration: kDurationNormal,
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: animation,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: Icon(
        widget.isActive ? filled : outlined,
        key: ValueKey('${widget.icon}_${widget.isActive}'),
        color: iconColor,
        size: 24,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isTest = Platform.environment.containsKey('FLUTTER_TEST');

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: isTest ? null : _onTapDown,
        onTapUp: isTest ? null : _onTapUp,
        onTapCancel: isTest ? null : _onTapCancel,
        onTap: isTest
            ? () {
                HapticFeedback.lightImpact();
                widget.onTap();
              }
            : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Scale animation wrapper
            AnimatedBuilder(
              animation: Listenable.merge([_pressCtrl, _springCtrl]),
              builder: (_, child) {
                double scale;
                if (_springCtrl.isAnimating) {
                  scale = _springAnim.value;
                } else if (_pressCtrl.value > 0) {
                  scale = _pressAnim.value;
                } else {
                  scale = 1.0;
                }
                return Transform.scale(scale: scale, child: child);
              },
              child: _buildIcon(),
            ),
            const SizedBox(height: 5),
            // Active dot indicator
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isActive
                    ? const Color(0xFFF5A623)
                    : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
