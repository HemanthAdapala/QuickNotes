import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ---------------------------------------------------------------------------
// GravityNotesNavBar
// Pixel-perfect replica of the Figma SVG (354 Ã— 83 viewBox).
//
// SVG key measurements (all in SVG units, scale = deviceWidth / 354):
//   â€¢ Bar body   : Y 23 â†’ 83, corner radius 20
//   â€¢ Notch left : X 129 â†’ 154.366, curves down to Y 54.2766
//   â€¢ Notch peak : cx=177.5, cy=54.2766
//   â€¢ Notch right: X 200.634 â†’ 226, mirrors left
//   â€¢ FAB circle : cx=177, cy=25, r=25  (sits above bar, touching at Y=0 of SVG)
//   â€¢ Icon centres (SVG x): Homeâ‰ˆ44, Folderâ‰ˆ119, FABâ‰ˆ177, Calendarâ‰ˆ236, Settingsâ‰ˆ311
// ---------------------------------------------------------------------------

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

  @override
  Widget build(BuildContext context) {
    const double svgW = 354;
    const double svgH = 83;
    final double screenW = MediaQuery.of(context).size.width;
    final double scale = screenW / svgW;
    final double barH = svgH * scale;
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    return SizedBox(
      width: screenW,
      height: barH + bottomPadding,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // â”€â”€ Custom-shaped bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SizedBox(
              width: screenW,
              height: barH + bottomPadding,
              child: CustomPaint(
                painter: _NavBarPainter(
                  scale: scale,
                  bottomPadding: bottomPadding,
                ),
              ),
            ),
          ),

          // â”€â”€ FAB button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Positioned(
            top: 0,
            left: (177 - 25) * scale, // cx - r
            child: _FabButton(
              size: 50 * scale,
              onTap: () {
                HapticFeedback.lightImpact();
                onFabTap?.call();
              },
            ),
          ),

          // â”€â”€ Nav icons row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Positioned(
            bottom: bottomPadding,
            left: 0,
            right: 0,
            height: 60 * scale,
            child: _NavIconsRow(
              scale: scale,
              activeIndex: activeIndex,
              onTap: onTap,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bar shape painter â€” replicates the SVG path exactly
// ---------------------------------------------------------------------------
class _NavBarPainter extends CustomPainter {
  final double scale;
  final double bottomPadding;

  const _NavBarPainter({required this.scale, required this.bottomPadding});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF333333)
      ..style = PaintingStyle.fill;

    final s = scale;
    final extraH = bottomPadding; // extend below SVG to cover home indicator

    final path = Path();

    // Replicate SVG path (scaled), then extend downward by extraH
    // Original: M0 43 C0 31.9543 8.9543 23 20 23
    //           H129 C140.046 23 148.602 32.6238 154.366 42.046
    //           C158.363 48.5782 165.335 54.2766 177.5 54.2766
    //           C189.665 54.2766 196.637 48.5782 200.634 42.046
    //           C206.398 32.6238 214.954 23 226 23
    //           H334 C345.046 23 354 31.9543 354 43
    //           V63 C354 74.0457 345.046 83 334 83
    //           H20 C8.9543 83 0 74.0457 0 63 Z

    path.moveTo(0 * s, 43 * s);
    // top-left rounded corner
    path.cubicTo(0 * s, 31.9543 * s, 8.9543 * s, 23 * s, 20 * s, 23 * s);
    // straight to notch start
    path.lineTo(129 * s, 23 * s);
    // left notch curve (up and in)
    path.cubicTo(
      140.046 * s, 23 * s,
      148.602 * s, 32.6238 * s,
      154.366 * s, 42.046 * s,
    );
    // curve to notch bottom-center
    path.cubicTo(
      158.363 * s, 48.5782 * s,
      165.335 * s, 54.2766 * s,
      177.5 * s,   54.2766 * s,
    );
    // curve back up from notch center (right side)
    path.cubicTo(
      189.665 * s, 54.2766 * s,
      196.637 * s, 48.5782 * s,
      200.634 * s, 42.046 * s,
    );
    // right notch curve
    path.cubicTo(
      206.398 * s, 32.6238 * s,
      214.954 * s, 23 * s,
      226 * s,     23 * s,
    );
    // straight to top-right corner
    path.lineTo(334 * s, 23 * s);
    // top-right rounded corner
    path.cubicTo(345.046 * s, 23 * s, 354 * s, 31.9543 * s, 354 * s, 43 * s);
    // right side down (extended for safe area)
    path.lineTo(354 * s, 63 * s + extraH);
    // bottom-right corner
    path.cubicTo(354 * s, 74.0457 * s + extraH, 345.046 * s, 83 * s + extraH, 334 * s, 83 * s + extraH);
    // bottom edge
    path.lineTo(20 * s, 83 * s + extraH);
    // bottom-left corner
    path.cubicTo(8.9543 * s, 83 * s + extraH, 0 * s, 74.0457 * s + extraH, 0 * s, 63 * s + extraH);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_NavBarPainter old) =>
      old.scale != scale || old.bottomPadding != bottomPadding;
}

// ---------------------------------------------------------------------------
// FAB â€” white stroke circle with + icon, dark fill
// ---------------------------------------------------------------------------
class _FabButton extends StatelessWidget {
  final double size;
  final VoidCallback onTap;

  const _FabButton({required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF333333),
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.add,
            color: Colors.white,
            size: size * 0.5,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Nav icons row â€” 4 tappable icons with active dot indicator
// Icon SVG centres: Homeâ‰ˆ44, Folderâ‰ˆ119, Calendarâ‰ˆ236, Settingsâ‰ˆ311
// ---------------------------------------------------------------------------
class _NavIconsRow extends StatelessWidget {
  final double scale;
  final int activeIndex;
  final ValueChanged<int> onTap;

  const _NavIconsRow({
    required this.scale,
    required this.activeIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // X centres from SVG for the 4 icons (FAB is not a tab)
    final List<double> centres = [44, 119, 236, 311];
    final List<Widget Function(Color)> iconBuilders = [
      (c) => _HomeIcon(color: c),
      (c) => _FolderIcon(color: c),
      (c) => _CalendarIcon(color: c),
      (c) => _SettingsIcon(color: c),
    ];

    return Stack(
      children: List.generate(4, (i) {
        final bool isActive = activeIndex == i;
        const Color iconColor = Colors.white;
        final double cx = centres[i] * scale;
        const double iconSize = 24;
        const double dotSize = 4;
        const double dotGap = 5;

        return Positioned(
          left: cx - iconSize / 2 * scale,
          top: 0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.lightImpact();
              onTap(i);
            },
            child: SizedBox(
              width: iconSize * scale,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  iconBuilders[i](iconColor),
                  if (isActive) ...[
                    SizedBox(height: dotGap * scale),
                    Container(
                      width: dotSize * scale,
                      height: dotSize * scale,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ] else ...[
                    SizedBox(height: (dotGap + dotSize) * scale),
                  ],
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Icon widgets â€” scaled SVG paths via CustomPainter
// ---------------------------------------------------------------------------

class _HomeIcon extends StatelessWidget {
  final Color color;
  const _HomeIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(22, 22),
      painter: _SvgIconPainter(
        color: color,
        pathData:
            'M23.121,9.069L15.536,1.483a5.008,5.008,0,0,0-7.072,0L.879,9.069A2.978,2.978,0,0,0,0,11.19v9.817a3,3,0,0,0,3,3H21a3,3,0,0,0,3-3V11.19A2.978,2.978,0,0,0,23.121,9.069ZM15,22.007H9V18.073a3,3,0,0,1,6,0Zm7-1a1,1,0,0,1-1,1H17V18.073a5,5,0,0,0-10,0v3.934H3a1,1,0,0,1-1-1V11.19a1.008,1.008,0,0,1,.293-.707L9.878,2.9a3.008,3.008,0,0,1,4.244,0l7.585,7.586A1.008,1.008,0,0,1,22,11.19Z',
        viewBoxSize: const Size(24, 24),
      ),
    );
  }
}

class _FolderIcon extends StatelessWidget {
  final Color color;
  const _FolderIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(22, 22),
      painter: _SvgIconPainter(
        color: color,
        pathData:
            'M23.493,11.017c-.487-.654-1.234-1.03-2.05-1.03h-.443v-1.987c0-2.757-2.243-5-5-5h-5.056c-.154,0-.31-.037-.447-.105l-3.155-1.578c-.414-.207-.878-.316-1.342-.316h-2C1.794,1,0,2.794,0,5v13c0,2.757,2.243,5,5,5h12.558c2.226,0,4.15-1.432,4.802-3.607l1.532-6.116c.234-.782.089-1.605-.398-2.26ZM2,18V5c0-1.103.897-2,2-2h2c.154,0,.31.037.447.105l3.155,1.578c.414.207.878.316,1.342.316h5.056c1.654,0,3,1.346,3,3v1.987h-10.385c-1.7,0-3.218,1.079-3.789,2.72l-2.19,7.138c-.398-.509-.636-1.15-.636-1.845Zm19.964-5.253l-1.532,6.115c-.384,1.279-1.539,2.138-2.874,2.138H5c-.208,0-.411-.021-.607-.062l2.334-7.609c.279-.803,1.039-1.342,1.889-1.342h12.828c.242,0,.383.14.445.224.062.084.156.259.075.536Z',
        viewBoxSize: const Size(24, 24),
      ),
    );
  }
}

class _CalendarIcon extends StatelessWidget {
  final Color color;
  const _CalendarIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    // Calendar has multiple sub-paths; use the raw SVG path string
    return CustomPaint(
      size: const Size(22, 22),
      painter: _SvgIconPainter(
        color: color,
        pathData:
            'M19,2H18V1a1,1,0,0,0-2,0V2H8V1A1,1,0,0,0,6,1V2H5A5.006,5.006,0,0,0,0,7V19a5.006,5.006,0,0,0,5,5H19a5.006,5.006,0,0,0,5-5V7A5.006,5.006,0,0,0,19,2ZM2,7A3,3,0,0,1,5,4H19a3,3,0,0,1,3,3V8H2ZM19,22H5a3,3,0,0,1-3-3V10H22v9A3,3,0,0,1,19,22Z M12,13.5a1.5,1.5,0,1,0,1.5,1.5A1.5,1.5,0,0,0,12,13.5Z M7,13.5a1.5,1.5,0,1,0,1.5,1.5A1.5,1.5,0,0,0,7,13.5Z M17,13.5a1.5,1.5,0,1,0,1.5,1.5A1.5,1.5,0,0,0,17,13.5Z',
        viewBoxSize: const Size(24, 24),
      ),
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  final Color color;
  const _SettingsIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(22, 22),
      painter: _SvgIconPainter(
        color: color,
        pathData:
            'M12,8a4,4,0,1,0,4,4A4,4,0,0,0,12,8Zm0,6a2,2,0,1,1,2-2A2,2,0,0,1,12,14Z M21.294,13.9l-.444-.256a9.1,9.1,0,0,0,0-3.29l.444-.256a3,3,0,1,0-3-5.2l-.445.257A8.977,8.977,0,0,0,15,3.513V3A3,3,0,0,0,9,3v.513A8.977,8.977,0,0,0,6.152,5.159L5.705,4.9a3,3,0,0,0-3,5.2l.444.256a9.1,9.1,0,0,0,0,3.29l-.444.256a3,3,0,1,0,3,5.2l.445-.257A8.977,8.977,0,0,0,9,20.487V21a3,3,0,0,0,6,0v-.513a8.977,8.977,0,0,0,2.848-1.646l.447.258a3,3,0,0,0,3-5.2Zm-2.548-3.776a7.048,7.048,0,0,1,0,3.75,1,1,0,0,0,.464,1.133l1.084.626a1,1,0,0,1-1,1.733l-1.086-.628a1,1,0,0,0-1.215.165,6.984,6.984,0,0,1-3.243,1.875,1,1,0,0,0-.751.969V21a1,1,0,0,1-2,0V19.748a1,1,0,0,0-.751-.969A6.984,6.984,0,0,1,7.006,16.9a1,1,0,0,0-1.215-.165l-1.084.627a1,1,0,1,1-1-1.732l1.084-.626a1,1,0,0,0,.464-1.133,7.048,7.048,0,0,1,0-3.75A1,1,0,0,0,4.79,8.992L3.706,8.366a1,1,0,0,1,1-1.733l1.086.628A1,1,0,0,0,7.006,7.1a6.984,6.984,0,0,1,3.243-1.875A1,1,0,0,0,11,4.252V3a1,1,0,0,1,2,0V4.252a1,1,0,0,0,.751.969A6.984,6.984,0,0,1,16.994,7.1a1,1,0,0,0,1.215.165l1.084-.627a1,1,0,1,1,1,1.732l-1.084.626A1,1,0,0,0,18.746,10.125Z',
        viewBoxSize: const Size(24, 24),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Generic SVG path painter â€” parses a simplified SVG path string
// Uses Flutter's Path.parse via parseSvgPathData equivalent
// ---------------------------------------------------------------------------
class _SvgIconPainter extends CustomPainter {
  final Color color;
  final String pathData;
  final Size viewBoxSize;

  const _SvgIconPainter({
    required this.color,
    required this.pathData,
    required this.viewBoxSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / viewBoxSize.width;
    final scaleY = size.height / viewBoxSize.height;

    canvas.save();
    canvas.scale(scaleX, scaleY);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Split compound paths on M (after the first)
    final subPaths = pathData.split(RegExp(r'(?<=[ZzMm])\s*(?=[Mm])'));
    for (final sub in subPaths) {
      final path = _parsePath(sub.trim());
      canvas.drawPath(path, paint);
    }

    canvas.restore();
  }

  Path _parsePath(String d) {
    return Path()..addPathFromSvgData(d);
  }

  @override
  bool shouldRepaint(_SvgIconPainter old) =>
      old.color != color || old.pathData != pathData;
}

// Extension to parse SVG path data into Flutter Path
extension _SvgPath on Path {
  void addPathFromSvgData(String d) {
    // Tokenise
    final tokens = <String>[];
    final re = RegExp(r'[MmZzLlHhVvCcSsQqTtAa]|[-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?');
    for (final m in re.allMatches(d)) {
      tokens.add(m.group(0)!);
    }

    int i = 0;
    double cx = 0, cy = 0;
    double startX = 0, startY = 0;
    String cmd = 'M';

    double nextNum() => double.parse(tokens[i++]);

    while (i < tokens.length) {
      final t = tokens[i];
      if (RegExp(r'[A-Za-z]').hasMatch(t)) {
        cmd = t;
        i++;
      }
      switch (cmd) {
        case 'M':
          cx = nextNum(); cy = nextNum();
          moveTo(cx, cy);
          startX = cx; startY = cy;
          cmd = 'L';
        case 'm':
          cx += nextNum(); cy += nextNum();
          moveTo(cx, cy);
          startX = cx; startY = cy;
          cmd = 'l';
        case 'L':
          cx = nextNum(); cy = nextNum();
          lineTo(cx, cy);
        case 'l':
          cx += nextNum(); cy += nextNum();
          lineTo(cx, cy);
        case 'H':
          cx = nextNum();
          lineTo(cx, cy);
        case 'h':
          cx += nextNum();
          lineTo(cx, cy);
        case 'V':
          cy = nextNum();
          lineTo(cx, cy);
        case 'v':
          cy += nextNum();
          lineTo(cx, cy);
        case 'C':
          final x1 = nextNum(), y1 = nextNum();
          final x2 = nextNum(), y2 = nextNum();
          cx = nextNum(); cy = nextNum();
          cubicTo(x1, y1, x2, y2, cx, cy);
        case 'c':
          final x1 = cx + nextNum(), y1 = cy + nextNum();
          final x2 = cx + nextNum(), y2 = cy + nextNum();
          final dx = nextNum(), dy = nextNum();
          cubicTo(x1, y1, x2, y2, cx + dx, cy + dy);
          cx += dx; cy += dy;
        case 'S':
          final x2 = nextNum(), y2 = nextNum();
          cx = nextNum(); cy = nextNum();
          cubicTo(cx, cy, x2, y2, cx, cy);
        case 'Q':
          final x1 = nextNum(), y1 = nextNum();
          cx = nextNum(); cy = nextNum();
          conicTo(x1, y1, cx, cy, 1);
        case 'Z': case 'z':
          close();
          cx = startX; cy = startY;
        default:
          i++; // skip unknown
      }
    }
  }
}
