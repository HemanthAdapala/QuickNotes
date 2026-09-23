import 'package:flutter/material.dart';

/// Test background modes for evaluating glass refraction, blur, and edge lighting.
enum CatalogBackgroundMode {
  vibrantGradient,
  geometricShapes,
  monochromeGrid,
}

/// A neutral test surface widget designed specifically to reveal glass transparency,
/// blur, depth, contrast, and edge treatment.
///
/// This is NOT a production application background; it is a laboratory test pattern.
class CatalogBackground extends StatelessWidget {
  final CatalogBackgroundMode mode;
  final Widget child;

  const CatalogBackground({
    super.key,
    required this.mode,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: _buildBackgroundContent(context),
        ),
        child,
      ],
    );
  }

  Widget _buildBackgroundContent(BuildContext context) {
    switch (mode) {
      case CatalogBackgroundMode.vibrantGradient:
        return const _VibrantGradientPattern();
      case CatalogBackgroundMode.geometricShapes:
        return const _GeometricShapesPattern();
      case CatalogBackgroundMode.monochromeGrid:
        return const _MonochromeGridPattern();
    }
  }
}

class _VibrantGradientPattern extends StatelessWidget {
  const _VibrantGradientPattern();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E1B4B),
            Color(0xFF311042),
            Color(0xFF0D2538),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0xFFFF3B30),
                    Color(0x00FF3B30),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 280,
            left: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0xFF007AFF),
                    Color(0x00007AFF),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            right: -40,
            child: Container(
              width: 280,
              height: 280,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0xFF34C759),
                    Color(0x0034C759),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GeometricShapesPattern extends StatelessWidget {
  const _GeometricShapesPattern();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF12141A),
      child: CustomPaint(
        painter: _GeometricPainter(),
      ),
    );
  }
}

class _GeometricPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0x22FFFFFF);

    // Diagonal lines
    for (double i = -size.height; i < size.width + size.height; i += 40) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }

    // High-contrast geometric test circles
    final fillPaint1 = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0x66FF9500);
    canvas.drawCircle(Offset(size.width * 0.25, size.height * 0.3), 70, fillPaint1);

    final fillPaint2 = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0x66AF52DE);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width * 0.75, size.height * 0.65),
        width: 140,
        height: 140,
      ),
      fillPaint2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MonochromeGridPattern extends StatelessWidget {
  const _MonochromeGridPattern();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E2129),
      child: CustomPaint(
        painter: _GridPainter(),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0x18FFFFFF);

    const step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // High-frequency text sample to inspect optical legibility behind glass
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'TEST PATTERN // 0123456789 // HIGH FREQUENCY TEXT',
        style: TextStyle(
          color: Color(0x44FFFFFF),
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    for (double y = 60; y < size.height; y += 120) {
      textPainter.paint(canvas, Offset(20, y));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
