import 'package:flutter/material.dart';

/// Painter for continuous global backgrounds (Grid and Dots patterns)
class GlobalPaperGuidePainter extends CustomPainter {
  final String guideType;
  final double spacing;
  final Color color;
  final double opacity;

  GlobalPaperGuidePainter({
    required this.guideType,
    required this.spacing,
    required this.color,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (guideType == 'plain' || guideType.startsWith('lines') || guideType == 'custom') return;

    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..strokeWidth = 1.0;

    if (guideType == 'dots') {
      final dotPaint = Paint()
        ..color = color.withOpacity(opacity)
        ..style = PaintingStyle.fill;
      final double dotRadius = 1.2;

      // Draw dot matrix starting from spacing and repeating
      for (double x = spacing; x < size.width; x += spacing) {
        for (double y = spacing; y < size.height; y += spacing) {
          canvas.drawCircle(Offset(x, y), dotRadius, dotPaint);
        }
      }
    } else if (guideType == 'grid') {
      // Draw vertical lines
      for (double x = spacing; x < size.width; x += spacing) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
      // Draw horizontal lines
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant GlobalPaperGuidePainter oldDelegate) {
    return oldDelegate.guideType != guideType ||
        oldDelegate.spacing != spacing ||
        oldDelegate.color != color ||
        oldDelegate.opacity != opacity;
  }
}

/// Painter for block-level horizontal notebook ruled lines
class BlockPaperGuidePainter extends CustomPainter {
  final String guideType;
  final double lineHeight;
  final Color color;
  final double opacity;

  BlockPaperGuidePainter({
    required this.guideType,
    required this.lineHeight,
    required this.color,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // We only paint horizontal lines for lines or custom guide modes
    if (!guideType.startsWith('lines') && guideType != 'custom') return;

    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..strokeWidth = 1.0;

    // Draw horizontal lines at multiples of lineHeight
    double y = lineHeight;
    while (y <= size.height) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      y += lineHeight;
    }
  }

  @override
  bool shouldRepaint(covariant BlockPaperGuidePainter oldDelegate) {
    return oldDelegate.guideType != guideType ||
        oldDelegate.lineHeight != lineHeight ||
        oldDelegate.color != color ||
        oldDelegate.opacity != opacity;
  }
}
