import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/calendar_task.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CalendarTaskCard
//
// Visual design from DesignCode / Calender Screen specs:
//   • Container  : 67px tall, white, borderRadius 20, shadow blur 16 X=0 Y=0
//   • Left strip : 26px wide, priority color, left corners rounded only
//   • Content    : title (Inter 16 w500) + subtitle (Inter 12 w400)
//   • Right      : 20×20 circle — blue filled + check.svg when completed,
//                                gray outline (empty toggle) when running
//
// Tapping the right circle toggles completion state via [onToggle].
// ─────────────────────────────────────────────────────────────────────────────
class CalendarTaskCard extends StatelessWidget {
  final CalendarTask task;
  final VoidCallback? onToggle;
  final VoidCallback? onTap;

  const CalendarTaskCard({
    super.key,
    required this.task,
    this.onToggle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 67,
      decoration: ShapeDecoration(
        color: task.priorityColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Row(
        children: [
          // ── Priority color strip (left corners only) ─────────────────────
          Container(
            width: 26,
            decoration: BoxDecoration(
              color: task.priorityColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                bottomLeft: Radius.circular(20),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // ── Text content ─────────────────────────────────────────────────
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title — strikethrough when completed
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF333333),
                      fontSize: 16,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.43,
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      decorationColor: const Color(0xFF333333),
                      decorationThickness: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Subtitle
                  Text(
                    task.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF333333),
                      fontSize: 12,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.43,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // ── Toggle circle ─────────────────────────────────────────────────
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onToggle?.call();
            },
            child: task.isCompleted
                ? const _BlueCheckCircle()
                : const _GrayEmptyCircle(),
          ),

          const SizedBox(width: 22),
        ],
      ),
    );
  }
}

// ── Blue circle with white check icon (completed state) ───────────────────────
class _BlueCheckCircle extends StatelessWidget {
  const _BlueCheckCircle();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: Stack(
        children: [
          // Blue oval fill
          Positioned.fill(
            child: Container(
              decoration: const ShapeDecoration(
                color: Color(0xFF0088FF),
                shape: OvalBorder(),
              ),
            ),
          ),
          // Check icon — 12×12, white, centred
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

// ── Gray outline circle (running / uncompleted state) — acts as toggle ────────
class _GrayEmptyCircle extends StatelessWidget {
  const _GrayEmptyCircle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: const ShapeDecoration(
        shape: OvalBorder(
          side: BorderSide(
            width: 1,
            color: Color(0x33787878),
          ),
        ),
      ),
    );
  }
}
