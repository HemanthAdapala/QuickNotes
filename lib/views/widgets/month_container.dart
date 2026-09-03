import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A pill-shaped container that shows the current month + year with
/// left / right navigation chevrons, matching the DesignCode/Calender Screen
/// reference design exactly.
class MonthContainer extends StatelessWidget {
  /// Display label, e.g. "January,2026"
  final String label;

  /// Called when the user taps the left (previous) chevron.
  final VoidCallback? onPrevious;

  /// Called when the user taps the right (next) chevron.
  final VoidCallback? onNext;

  const MonthContainer({
    super.key,
    required this.label,
    this.onPrevious,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 193,
      height: 44,
      child: Stack(
        children: [
          // ── Background pill ────────────────────────────────────────────
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              width: 193,
              height: 44,
              decoration: ShapeDecoration(
                color: Colors.white, // Backgrounds-Primary
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                shadows: const [
                  BoxShadow(
                    color: Color(0x3F000000),
                    blurRadius: 16,
                    offset: Offset(0, 0),
                    spreadRadius: 0,
                  )
                ],
              ),
            ),
          ),

          // ── Month / Year label — always perfectly centred ──────────────
          Positioned.fill(
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF333333),
                  fontSize: 17,
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w500,
                  height: 1.06,
                ),
              ),
            ),
          ),

          // ── Angle-left icon (previous month) ──────────────────────────
          Positioned(
            left: 10,
            top: 13.5,
            child: GestureDetector(
              onTap: onPrevious,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 17,
                height: 17,
                child: SvgPicture.asset(
                  'assets/icons/calendar_angle_left.svg',
                  width: 17,
                  height: 17,
                  colorFilter: const ColorFilter.mode(
                    Color(0xFF333333),
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),

          // ── Angle-right icon (next month) ─────────────────────────────
          Positioned(
            left: 166,
            top: 13.5,
            child: GestureDetector(
              onTap: onNext,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 17,
                height: 17,
                child: SvgPicture.asset(
                  'assets/icons/calendar_angle_right.svg',
                  width: 17,
                  height: 17,
                  colorFilter: const ColorFilter.mode(
                    Color(0xFF333333),
                    BlendMode.srcIn,
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
