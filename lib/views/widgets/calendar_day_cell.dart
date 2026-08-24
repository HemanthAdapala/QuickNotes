import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CalendarDayCell
//
// A single day pill cell — 32 × 48 — from the DesignCode/Calender Screen spec.
//
// Layout (all values match the original design file):
//   • White pill (empty) or Chartreuse pill (has task), borderRadius 20, shadow blur 10, X=0 Y=0
//   • Selected state : 1.5px border (Blue if empty, Ink if has task) around the pill
//   • Top half  → day number (Inter 16 w500, #333333)
//   • Bottom half → 20×20 circle:
//       - Task created  : Ink (#333333) + check SVG 12×12 (Chartreuse)
//       - No task       : Faint Gray (#F2F2F7) anchor (no icon)
// ─────────────────────────────────────────────────────────────────────────────
class CalendarDayCell extends StatelessWidget {
  final int day;
  final bool hasTask;

  /// Whether this day is the currently selected day.
  final bool isSelected;

  /// Called when the user taps this cell.
  final VoidCallback? onTap;

  const CalendarDayCell({
    super.key,
    required this.day,
    required this.hasTask,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap?.call();
      },
      child: SizedBox(
        width: 32,
        height: 48,
        child: Stack(
          children: [
            // ── Pill background ──────────────────────────────────────
            Positioned.fill(
              child: Container(
                decoration: ShapeDecoration(
                  color: hasTask ? const Color(0xFFCCFF00) : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: isSelected
                        ? BorderSide(
                            color: hasTask ? const Color(0xFF333333) : const Color(0xFF0088FF),
                            width: 1.5,
                          )
                        : BorderSide.none,
                  ),
                  shadows: const [
                    BoxShadow(
                      color: Color(0x3F000000),
                      blurRadius: 10,
                      offset: Offset(0, 0),
                      spreadRadius: 0,
                    ),
                  ],
                ),
              ),
            ),

            // ── Content column ─────────────────────────────────────────────
            Column(
              children: [
                const SizedBox(height: 6),

                // Day number — centred horizontally
                Center(
                  child: Text(
                    '$day',
                    style: TextStyle(
                      color: isSelected && !hasTask
                          ? const Color(0xFF0088FF)
                          : const Color(0xFF333333),
                      fontSize: 16,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                      height: 1.0,
                      letterSpacing: -0.43,
                      shadows: const [
                        Shadow(
                          offset: Offset(0, 0),
                          blurRadius: 16,
                          color: Color(0x15000000),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 1),

                // Status circle
                Center(child: _buildCircle()),

                const SizedBox(height: 4),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircle() {
    return hasTask ? const _TaskCircle() : const _NoTaskCircle();
  }
}

// ── Ink circle with check icon (Task exists) ─────────────────────────────────
class _TaskCircle extends StatelessWidget {
  const _TaskCircle();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const ShapeDecoration(
                color: Color(0xFF333333),
                shape: OvalBorder(),
              ),
            ),
          ),
          Center(
            child: SvgPicture.asset(
              'assets/icons/calendar_check.svg',
              width: 12,
              height: 12,
              colorFilter: const ColorFilter.mode(
                Color(0xFFCCFF00),
                BlendMode.srcIn,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Faint gray anchor circle (No Task) ───────────────────────────────────────
class _NoTaskCircle extends StatelessWidget {
  const _NoTaskCircle();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const ShapeDecoration(
                color: Color(0xFFF2F2F7),
                shape: OvalBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
