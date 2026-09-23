import 'package:flutter/cupertino.dart';

/// Types of optical reference patterns available for glass testing.
enum OpticalPatternType {
  stripes,
  alphanumeric,
  gridLines,
  chromaticEdges,
}

/// Minimal measurement and reference patterns placed behind glass surfaces
/// in Phase 1B experiments to reveal optical effects (displacement, distortion,
/// frost, chromatic aberration, magnification) clearly against the fixed background.
class OpticalTestPattern extends StatelessWidget {
  const OpticalTestPattern.stripes({
    super.key,
    this.width = 240,
    this.height = 100,
  }) : type = OpticalPatternType.stripes;

  const OpticalTestPattern.alphanumeric({
    super.key,
    this.width = 240,
    this.height = 100,
  }) : type = OpticalPatternType.alphanumeric;

  const OpticalTestPattern.gridLines({
    super.key,
    this.width = 240,
    this.height = 100,
  }) : type = OpticalPatternType.gridLines;

  const OpticalTestPattern.chromaticEdges({
    super.key,
    this.width = 240,
    this.height = 100,
  }) : type = OpticalPatternType.chromaticEdges;

  final OpticalPatternType type;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Center(
        child: switch (type) {
          OpticalPatternType.stripes => _buildStripes(),
          OpticalPatternType.alphanumeric => _buildAlphanumeric(),
          OpticalPatternType.gridLines => _buildGridLines(),
          OpticalPatternType.chromaticEdges => _buildChromaticEdges(),
        },
      ),
    );
  }

  Widget _buildStripes() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '||||||||||||||||||||||||||||||||',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: CupertinoColors.white,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 6),
        Container(height: 2, color: CupertinoColors.white.withValues(alpha: 0.8)),
        const SizedBox(height: 6),
        const Text(
          '--------------------------------',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: CupertinoColors.white,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildAlphanumeric() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'A  B  C  D  E  F  G',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: CupertinoColors.white,
            letterSpacing: 4,
          ),
        ),
        SizedBox(height: 8),
        Text(
          '1  2  3  4  5  6  7',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: CupertinoColors.white,
            letterSpacing: 4,
          ),
        ),
      ],
    );
  }

  Widget _buildGridLines() {
    return CustomPaint(
      size: Size(width, height),
      painter: const _GridPainter(),
    );
  }

  Widget _buildChromaticEdges() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          color: CupertinoColors.systemRed,
        ),
        const SizedBox(width: 8),
        Container(
          width: 32,
          height: 32,
          color: CupertinoColors.white,
        ),
        const SizedBox(width: 8),
        Container(
          width: 32,
          height: 32,
          color: CupertinoColors.systemBlue,
        ),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = CupertinoColors.white.withValues(alpha: 0.8)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Horizontal lines
    for (double y = 10; y < size.height; y += 20) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // Vertical lines
    for (double x = 10; x < size.width; x += 20) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
