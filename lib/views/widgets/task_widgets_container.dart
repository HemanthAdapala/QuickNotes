import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';

import '../models/calendar_task.dart';
import 'calendar_task_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TaskWidgetsContainer
//
// Bottom panel in CalendarScreen. Layout (from DesignCode spec):
//   ┌──────────────────────────────────────────────┐
//   │  Tasks for June 16          [ + Add Task ]   │  ← fixed, never scrolls
//   ├──────────────────────────────────────────────┤
//   │  [Task card]                                 │
//   │  [Task card]                                 │  ← scrollable list
//   │  [Task card]                                 │
//   └──────────────────────────────────────────────┘
//
// Container design: white, borderRadius 20 all sides, shadow blur 16 X=0 Y=0.
// The white bg blends into screen (also white), shadow creates separation.
// ─────────────────────────────────────────────────────────────────────────────
class TaskWidgetsContainer extends StatelessWidget {
  /// The day currently selected on the calendar.
  final DateTime selectedDate;

  /// Tasks to display in the scrollable list.
  final List<CalendarTask> tasks;

  /// Called when a task's toggle circle is tapped.
  final void Function(String taskId)? onToggleTask;

  /// Called when a task card is swiped away (right-to-left).
  final void Function(String taskId)? onDismissTask;

  /// Called when a task card's complete action is activated via swipe.
  final void Function(String taskId)? onCompleteTask;

  /// Called when a task card itself is tapped for editing.
  final void Function(String taskId)? onTapTask;

  /// Called when "+ Add Task" button is tapped.
  final VoidCallback? onAddTask;

  const TaskWidgetsContainer({
    super.key,
    required this.selectedDate,
    required this.tasks,
    this.onToggleTask,
    this.onDismissTask,
    this.onCompleteTask,
    this.onTapTask,
    this.onAddTask,
  });

  String get _dateLabel =>
      'Tasks for ${DateFormat('MMMM d').format(selectedDate)}';

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: ShapeDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      child: Stack(
        children: [
          // ── 1. Scrollable task list (bottom layer) ──────────────────────
          Positioned.fill(
            child: tasks.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 60.0),
                    child: _EmptyState(),
                  )
                : ListView.separated(
                    clipBehavior: Clip.none,
                    padding: EdgeInsets.only(
                      left: 24,
                      right: 24,
                      top: 68,
                      bottom: bottomPad + 80,
                    ),
                    physics: const BouncingScrollPhysics(),
                    itemCount: tasks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final task = tasks[i];
                      return _SwipableCalendarTaskCard(
                        key: ValueKey(task.id),
                        task: task,
                        onToggle: () => onToggleTask?.call(task.id),
                        onDismiss: () => onDismissTask?.call(task.id),
                        onComplete: () => onCompleteTask?.call(task.id),
                        onTap: () => onTapTask?.call(task.id),
                      );
                    },
                  ),
          ),

          // ── 2. Fixed Gradient Header (top layer, height: 60px) ─────────
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 60,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: const Alignment(0.50, 0.00),
                  end: const Alignment(0.50, 1.00),
                  colors: isDark
                      ? [
                          const Color(0xFF2C2C2C),
                          const Color(0xFF2C2C2C).withValues(alpha: 0.25),
                        ]
                      : [
                          Colors.white,
                          Colors.white.withValues(alpha: 0.25),
                        ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  children: [
                    // "Tasks for June 16"
                    Expanded(
                      child: Text(
                        _dateLabel,
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFFFFFFFF)
                              : const Color(0xFF333333),
                          fontSize: 16,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.43,
                        ),
                      ),
                    ),

                    // "+ Add Task" button
                    _AddTaskButton(onTap: onAddTask),
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

// ── Swipable task card with action-on-tap delete and complete buttons ─────────
class _SwipableCalendarTaskCard extends StatefulWidget {
  final CalendarTask task;
  final VoidCallback? onToggle;
  final VoidCallback? onDismiss;
  final VoidCallback? onComplete;
  final VoidCallback? onTap;

  const _SwipableCalendarTaskCard({
    super.key,
    required this.task,
    this.onToggle,
    this.onDismiss,
    this.onComplete,
    this.onTap,
  });

  @override
  State<_SwipableCalendarTaskCard> createState() =>
      _SwipableCalendarTaskCardState();
}

class _SwipableCalendarTaskCardState extends State<_SwipableCalendarTaskCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _dragX = 0.0;
  static const double _maxSwipeLeft = -69.0; // 61px delete button + 8px gap
  static const double _maxSwipeRight = 69.0; // 61px complete button + 8px gap

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragX = (_dragX + details.delta.dx).clamp(_maxSwipeLeft, _maxSwipeRight);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final v = details.primaryVelocity ?? 0.0;
    if (_dragX < 0) {
      if (v < -200 || _dragX < _maxSwipeLeft / 2) {
        _animateTo(_maxSwipeLeft);
      } else {
        _animateTo(0.0);
      }
    } else if (_dragX > 0) {
      if (v > 200 || _dragX > _maxSwipeRight / 2) {
        _animateTo(_maxSwipeRight);
      } else {
        _animateTo(0.0);
      }
    } else {
      _animateTo(0.0);
    }
  }

  void _animateTo(double target) {
    final start = _dragX;
    _controller.reset();
    final anim = Tween<double>(begin: start, end: target).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    anim.addListener(() {
      setState(() {
        _dragX = anim.value;
      });
    });
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    final bool showDeleteButton = _dragX < 0.0;
    final bool showCompleteButton = _dragX > 0.0;
    final double deleteOpacity = (_dragX.abs() / 69.0).clamp(0.0, 1.0);
    final double completeOpacity = (_dragX.abs() / 69.0).clamp(0.0, 1.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors
            .transparent, // Transparent background, no white box artifacts!
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Revealed Blue Complete Button on left (rendered ONLY when swiping right/revealed!)
            if (showCompleteButton)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Opacity(
                    opacity: completeOpacity,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        widget.onComplete?.call();
                        _animateTo(0.0);
                      },
                      child: Container(
                        width: 61,
                        height: 67,
                        alignment: Alignment.center,
                        decoration: ShapeDecoration(
                          color: const Color(0x7F0088FF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Align(
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Revealed Red Delete Button on right (rendered ONLY when swiping left/revealed!)
            if (showDeleteButton)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Opacity(
                    opacity: deleteOpacity,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        widget.onDismiss?.call();
                        _animateTo(0.0);
                      },
                      child: Container(
                        width: 61,
                        height: 67,
                        alignment: Alignment.center,
                        decoration: ShapeDecoration(
                          color: const Color(0x7FFF0000),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Align(
                          alignment: Alignment.center,
                          child: Transform.translate(
                            offset: const Offset(0, -5.5),
                            child: Lottie.asset(
                              'assets/animations/trash_can.json',
                              width: 32,
                              height: 32,
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                              repeat: true,
                              animate: true,
                              delegates: LottieDelegates(
                                values: [
                                  ValueDelegate.color(
                                    const ['**'],
                                    value: isDark
                                        ? const Color(0xFFFFFFFF)
                                        : const Color(0xFF333333),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Sliding Task Card
            Transform.translate(
              offset: Offset(_dragX, 0),
              child: GestureDetector(
                onTap: _dragX != 0.0 ? () => _animateTo(0.0) : null,
                behavior: _dragX != 0.0 ? HitTestBehavior.opaque : HitTestBehavior.deferToChild,
                child: CalendarTaskCard(
                  task: widget.task,
                  onToggle: _dragX == 0.0 ? widget.onToggle : null,
                  onTap: _dragX == 0.0 ? widget.onTap : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── "+ Add Task" button ───────────────────────────────────────────────────────
// Design: 110×36 gray pill (Color(0x33787878)), plus.svg 14×14 + "Add Task" text
class _AddTaskButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _AddTaskButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: Container(
        width: 110,
        height: 36,
        decoration: ShapeDecoration(
          color: isDark ? const Color(0xFF3A3A3C) : const Color(0x33787878),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/icons/calendar_plus.svg',
              width: 14,
              height: 14,
              colorFilter: ColorFilter.mode(
                isDark ? const Color(0xFFFFFFFF) : const Color(0xFF333333),
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              'Add Task',
              style: TextStyle(
                color: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF333333),
                fontSize: 15,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                letterSpacing: -0.43,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Text(
        'No tasks for this day',
        style: TextStyle(
          color: isDark ? const Color(0xFF757575) : const Color(0x80000000),
          fontSize: 14,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}
