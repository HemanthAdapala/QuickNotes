import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum DayTaskState {
  none,
  task,
  notCompleted,
  completed,
}

class CalendarDayCell extends StatelessWidget {
  final int day;
  final DayTaskState taskState;
  final bool isSelected;
  final VoidCallback? onTap;

  const CalendarDayCell({
    super.key,
    required this.day,
    this.taskState = DayTaskState.none,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isCompleted = taskState == DayTaskState.completed;

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
                  color: isCompleted ? const Color(0xFF0088FF) : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: isSelected
                        ? BorderSide(
                            color: isCompleted ? const Color(0xFF333333) : const Color(0xFF0088FF),
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
                Center(
                  child: Text(
                    '$day',
                    style: const TextStyle(
                      color: Color(0xFF333333),
                      fontSize: 16,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                      height: 1.0,
                      letterSpacing: -0.43,
                    ),
                  ),
                ),
                const SizedBox(height: 1),
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
    switch (taskState) {
      case DayTaskState.none:
        return _buildSolidCircle(const Color(0xFFE5E5EA));
      case DayTaskState.task:
        return _buildSolidCircle(const Color(0xFF0088FF));
      case DayTaskState.notCompleted:
        return _buildIconCircle(
          bgColor: const Color(0xFF0088FF),
          iconAsset: 'assets/icons/calendar_cross.svg',
          iconColor: const Color(0xFF333333),
          iconSize: 10,
        );
      case DayTaskState.completed:
        return _buildIconCircle(
          bgColor: Colors.white,
          iconAsset: 'assets/icons/calendar_check.svg',
          iconColor: const Color(0xFF333333),
          iconSize: 12,
        );
    }
  }

  Widget _buildSolidCircle(Color color) {
    return SizedBox(
      width: 20,
      height: 20,
      child: Container(
        decoration: ShapeDecoration(
          color: color,
          shape: const OvalBorder(),
        ),
      ),
    );
  }

  Widget _buildIconCircle({
    required Color bgColor,
    required String iconAsset,
    required Color iconColor,
    required double iconSize,
  }) {
    return SizedBox(
      width: 20,
      height: 20,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: ShapeDecoration(
                color: bgColor,
                shape: const OvalBorder(),
              ),
            ),
          ),
          Center(
            child: SvgPicture.asset(
              iconAsset,
              width: iconSize,
              height: iconSize,
              colorFilter: ColorFilter.mode(
                iconColor,
                BlendMode.srcIn,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
