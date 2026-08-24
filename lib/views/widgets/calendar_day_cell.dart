import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Orbital Ring Painter (Tasks Progress)
// ─────────────────────────────────────────────────────────────────────────────
class OrbitalRingPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  OrbitalRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    this.strokeWidth = 2.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.width / 2) - (strokeWidth / 2);

    // Draw background track
    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Draw progress arc
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, // start at top (-90 degrees)
        2 * math.pi * progress, // sweep angle
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant OrbitalRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.trackColor != trackColor ||
           oldDelegate.progressColor != progressColor ||
           oldDelegate.strokeWidth != strokeWidth;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CalendarDayCell (Option 2: Orbital Ring)
//
// A circular cell (40×40) that merges the date and task indicator into one.
// The orbital ring represents task completion progress.
// ─────────────────────────────────────────────────────────────────────────────
class CalendarDayCell extends StatelessWidget {
  final int day;
  
  /// null = no tasks, 0.0 to 1.0 = completion progress
  final double? progress; 

  /// Whether this day is the currently selected day.
  final bool isSelected;

  /// Called when the user taps this cell.
  final VoidCallback? onTap;

  const CalendarDayCell({
    super.key,
    required this.day,
    this.progress,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // If progress is 1.0, tasks are fully completed. We can make the cell pop a bit more.
    final bool isFullyCompleted = progress == 1.0;
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap?.call();
      },
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── Background Circle ──────────────────────────────────────
            Container(
              decoration: ShapeDecoration(
                color: isSelected ? const Color(0xFFEAF5FF) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: isSelected
                      ? const BorderSide(
                          color: Color(0xFF0088FF),
                          width: 1.5,
                        )
                      : BorderSide.none,
                ),
                shadows: const [
                  BoxShadow(
                    color: Color(0x1A000000), // lighter shadow for circle
                    blurRadius: 8,
                    offset: Offset(0, 2),
                    spreadRadius: 0,
                  ),
                ],
              ),
            ),

            // ── Orbital Ring (if there are tasks) ──────────────────────
            if (progress != null)
              SizedBox(
                width: 34,
                height: 34,
                child: CustomPaint(
                  painter: OrbitalRingPainter(
                    progress: progress!,
                    trackColor: const Color(0xFF333333).withOpacity(0.08),
                    progressColor: isFullyCompleted ? const Color(0xFF0088FF) : const Color(0xFFCCFF00), // Blue when done, Chartreuse when in progress
                    strokeWidth: 2.5,
                  ),
                ),
              ),

            // ── Day Number ─────────────────────────────────────────────
            Text(
              '$day',
              style: TextStyle(
                color: isSelected || isFullyCompleted
                    ? const Color(0xFF0088FF)
                    : const Color(0xFF333333),
                fontSize: 16,
                fontFamily: 'Inter',
                fontWeight: isSelected || isFullyCompleted ? FontWeight.bold : FontWeight.w500,
                letterSpacing: -0.43,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
