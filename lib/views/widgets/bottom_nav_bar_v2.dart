import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GravityNotesNavBar — Fixed Implementation
//
// Architecture change:
//   • Bar shape  → CustomPainter (SVG path, pixel-exact notch)
//   • Icons      → Positioned in a Row with Spacers, NOT by SVG x-coordinates
//   • FAB        → Absolute Positioned above bar center
//   • Bottom     → Extends into safe area via MediaQuery padding
// ─────────────────────────────────────────────────────────────────────────────

class GravityNotesNavBar extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onTap;
  final VoidCallback? onFabTap;

  const GravityNotesNavBar({
    super.key,
    required this.activeIndex,
    required this.onTap,
    this.onFabTap,
  });

  // SVG viewBox is 354 × 83. Bar body starts at Y=23.
  // So visible bar height = 83 - 23 = 60 SVG units.
  static const double _svgW = 354;
  static const double _svgBarTopY = 23; // where the bar body starts in SVG
  static const double _svgTotalH = 83;
  static const double _fabR = 25; // FAB radius in SVG units
  static const double _fabCY = 25; // FAB center Y in SVG = same as bar top

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final double screenW = mq.size.width;
    final double bottomPad = mq.padding.bottom;
    final double scale = screenW / _svgW;

    // Heights
    final double svgScaledH = _svgTotalH * scale;
    final double barBodyH = (_svgTotalH - _svgBarTopY) * scale; // 60 * scale
    final double fabDiameter = _fabR * 2 * scale;
    final double fabTopOffset = _svgBarTopY * scale - _fabR * scale; // = 0 (FAB sits exactly at bar top edge)

    // Total widget height = SVG height + bottom safe area
    final double totalH = svgScaledH + bottomPad;

    return SizedBox(
      width: screenW,
      height: totalH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── 1. Bar shape (CustomPainter) ─────────────────────────────
          Positioned(
            top: _svgBarTopY * scale, // bar body starts here
            left: 0,
            right: 0,
            bottom: 0,
            child: CustomPaint(
              painter: _BarPainter(
                scale: scale,
                bottomPad: bottomPad,
              ),
            ),
          ),

          // ── 2. FAB ────────────────────────────────────────────────────
          Positioned(
            top: 0, // FAB top aligns with SVG Y=0
            left: screenW / 2 - fabDiameter / 2,
            child: _FabButton(
              diameter: fabDiameter,
              onTap: () {
                HapticFeedback.lightImpact();
                onFabTap?.call();
              },
            ),
          ),

          // ── 3. Icons row inside bar body ─────────────────────────────
          // Bar body occupies from _svgBarTopY*scale to svgScaledH (ignoring bottomPad area)
          // Icons should be vertically centered in the bar body (not the bottom padding)
          Positioned(
            top: _svgBarTopY * scale,
            left: 0,
            right: 0,
            height: barBodyH,
            child: _IconsRow(
              activeIndex: activeIndex,
              onTap: onTap,
              screenW: screenW,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bar Painter — exact SVG path, scaled
// ─────────────────────────────────────────────────────────────────────────────
class _BarPainter extends CustomPainter {
  final double scale;
  final double bottomPad;

  const _BarPainter({required this.scale, required this.bottomPad});

  @override
  void paint(Canvas canvas, Size size) {
    final s = scale;
    // Adjust: painter's (0,0) = SVG Y=23 (bar body top)
    // So subtract 23 from all Y values in the original SVG path
    const double dy = -23; // offset

    final paint = Paint()
      ..color = const Color(0xFF333333)
      ..style = PaintingStyle.fill;

    final path = Path();

    // Original SVG path (Y values offset by -23, extended at bottom by bottomPad)
    // M0 43 → M0 20 (43-23)
    path.moveTo(0, (43 + dy) * s);
    path.cubicTo(0, (31.9543 + dy) * s, 8.9543 * s, (23 + dy) * s, 20 * s, (23 + dy) * s);
    path.lineTo(129 * s, (23 + dy) * s);
    path.cubicTo(140.046 * s, (23 + dy) * s, 148.602 * s, (32.6238 + dy) * s, 154.366 * s, (42.046 + dy) * s);
    path.cubicTo(158.363 * s, (48.5782 + dy) * s, 165.335 * s, (54.2766 + dy) * s, 177.5 * s, (54.2766 + dy) * s);
    path.cubicTo(189.665 * s, (54.2766 + dy) * s, 196.637 * s, (48.5782 + dy) * s, 200.634 * s, (42.046 + dy) * s);
    path.cubicTo(206.398 * s, (32.6238 + dy) * s, 214.954 * s, (23 + dy) * s, 226 * s, (23 + dy) * s);
    path.lineTo(334 * s, (23 + dy) * s);
    path.cubicTo(345.046 * s, (23 + dy) * s, 354 * s, (31.9543 + dy) * s, 354 * s, (43 + dy) * s);
    // extend right side down through safe area
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
// FAB Button
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
// Layout: [spacer] [Home] [spacer] [Folder] [spacer(FAB gap)] [Calendar] [spacer] [Settings] [spacer]
// The FAB gap is the center — we leave it empty since FAB is absolutely positioned
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
    // Split screen into two halves, 2 icons each side, FAB in center gap
    return Row(
      children: [
        // LEFT HALF — Home + Folder
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

        // CENTER GAP — FAB placeholder (50px diameter + some breathing room)
        SizedBox(width: screenW * (50 / 354) * 1.4),

        // RIGHT HALF — Calendar + Settings
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
// Single nav item — icon + optional active dot
// ─────────────────────────────────────────────────────────────────────────────
enum _NavIcon { home, folder, calendar, settings }

class _NavItem extends StatelessWidget {
  final _NavIcon icon;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildIcon(),
            const SizedBox(height: 5),
            // Active dot or empty space to prevent layout shift
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? Colors.white : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    const Color c = Colors.white;
    const double size = 24;
    switch (icon) {
      case _NavIcon.home:
        return const Icon(Icons.home_outlined, color: c, size: size);
      case _NavIcon.folder:
        return const Icon(Icons.folder_open_outlined, color: c, size: size);
      case _NavIcon.calendar:
        return const Icon(Icons.calendar_month_outlined, color: c, size: size);
      case _NavIcon.settings:
        return const Icon(Icons.settings_outlined, color: c, size: size);
    }
  }
}
