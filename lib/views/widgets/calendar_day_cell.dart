import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CalendarDayCell
//
// A single day pill cell — 32 × 48 — from the DesignCode/Calender Screen spec.
//
// Layout (all values match the original design file):
//   • White pill, borderRadius 20, shadow blur 10, X=0 Y=0
//   • Selected state : 1.5px blue (#0088FF) border around the pill
//   • Top half  → day number (Inter 16 w500, #333333)
//   • Bottom half → 20×20 circle:
//       - Task created  : blue  (#0088FF) + check SVG 12×12 (white)
//       - No task       : gray  (#33787878) + cross SVG 10×10 (#333333)
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
            // ── White pill background ──────────────────────────────────────
            // Selected: 1.5px blue border applied via RoundedRectangleBorder.side
            Positioned.fill(
              child: Container(
                decoration: ShapeDecoration(
                  color: Colors.white,
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
            // Heights: 6 (top) + 16 (text) + 1 (gap) + 20 (circle) + 4 (bottom) = 47
            Column(
              children: [
                const SizedBox(height: 6),

                // Day number — centred horizontally
                Center(
                  child: Text(
                    '$day',
                    style: TextStyle(
                      // Blue tint on number when selected
                      color: isSelected
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
                          color: Color(0x40000000),
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

// ── Blue circle with check icon ───────────────────────────────────────────────
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
                color: Color(0xFF0088FF),
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
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Gray circle with cross icon ───────────────────────────────────────────────
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
                color: Color(0x33787878),
                shape: OvalBorder(),
              ),
            ),
          ),
          Center(
            child: SvgPicture.asset(
              'assets/icons/calendar_cross.svg',
              width: 10,
              height: 10,
              colorFilter: const ColorFilter.mode(
                Color(0xFF333333),
                BlendMode.srcIn,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
