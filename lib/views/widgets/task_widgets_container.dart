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
    this.onTapTask,
    this.onAddTask,
  });

  String get _dateLabel =>
      'Tasks for ${DateFormat('MMMM d').format(selectedDate)}';

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;

    return Stack(
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
                colors: [
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
                      style: const TextStyle(
                        color: Color(0xFF333333),
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
    );
  }
}

// ── Swipable task card with action-on-tap delete button ─────────────────────────
class _SwipableCalendarTaskCard extends StatefulWidget {
  final CalendarTask task;
  final VoidCallback? onToggle;
  final VoidCallback? onDismiss;
  final VoidCallback? onTap;

  const _SwipableCalendarTaskCard({
    super.key,
    required this.task,
    this.onToggle,
    this.onDismiss,
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
  final double _maxSwipe = -69.0; // 61px delete button + 8px gap

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
      _dragX = (_dragX + details.delta.dx).clamp(_maxSwipe, 0.0);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (details.primaryVelocity != null && details.primaryVelocity! < -200 ||
        _dragX < _maxSwipe / 2) {
      _open();
    } else {
      _close();
    }
  }

  void _open() {
    final start = _dragX;
    _controller.reset();
    final anim = Tween<double>(begin: start, end: _maxSwipe).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    anim.addListener(() {
      setState(() {
        _dragX = anim.value;
      });
    });
    _controller.forward();
  }

  void _close() {
    final start = _dragX;
    _controller.reset();
    final anim = Tween<double>(begin: start, end: 0.0).animate(
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
    final double opacity = (_dragX.abs() / 69.0).clamp(0.0, 1.0);

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
            // Revealed Red Delete Button on right (rendered ONLY when swiping/revealed!)
            if (showDeleteButton)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Opacity(
                    opacity: opacity,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        widget.onDismiss?.call();
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
                                    value: const Color(0xFF333333),
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
              child: CalendarTaskCard(
                task: widget.task,
                onToggle: widget.onToggle,
                onTap: widget.onTap,
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
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: Container(
        width: 110,
        height: 36,
        decoration: ShapeDecoration(
          color: const Color(0x33787878),
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
              colorFilter: const ColorFilter.mode(
                Colors.black,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 5),
            const Text(
              'Add Task',
              style: TextStyle(
                color: Colors.black,
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
    return const Center(
      child: Text(
        'No tasks for this day',
        style: TextStyle(
          color: Color(0x80000000),
          fontSize: 14,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}
