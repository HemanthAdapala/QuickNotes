import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

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

  /// Called when "+ Add Task" button is tapped.
  final VoidCallback? onAddTask;

  const TaskWidgetsContainer({
    super.key,
    required this.selectedDate,
    required this.tasks,
    this.onToggleTask,
    this.onDismissTask,
    this.onAddTask,
  });

  String get _dateLabel =>
      'Tasks for ${DateFormat('MMMM d').format(selectedDate)}';

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      width: double.infinity,
      decoration: const ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        shadows: [
          BoxShadow(
            color: Color(0x3F000000),
            blurRadius: 16,
            offset: Offset(0, 0),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Fixed header ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 16, 12),
            child: Row(
              children: [
                // "Tasks for June 16"
                Expanded(
                  child: Text(
                    _dateLabel,
                    style: const TextStyle(
                      color: Colors.black,
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

          // ── Scrollable task list ───────────────────────────────────────
          Expanded(
            child: tasks.isEmpty
                ? _EmptyState()
                : ListView.separated(
                    padding: EdgeInsets.only(
                      left: 24,
                      right: 24,
                      bottom: bottomPad + 16,
                    ),
                    physics: const BouncingScrollPhysics(),
                    itemCount: tasks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final task = tasks[i];
                      return Dismissible(
                        key: ValueKey(task.id),
                        direction: DismissDirection.endToStart,
                        background: const _DismissBackground(),
                        onDismissed: (_) {
                          HapticFeedback.mediumImpact();
                          onDismissTask?.call(task.id);
                        },
                        child: CalendarTaskCard(
                          task: task,
                          onToggle: () => onToggleTask?.call(task.id),
                        ),
                      );
                    },
                  ),
          ),
        ],
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

// ── Dismiss background (revealed when swiping left) ───────────────────────────
// Red pill matching the card height, trash icon right-aligned.
class _DismissBackground extends StatelessWidget {
  const _DismissBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFF383C),
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      child: const Icon(
        Icons.delete_rounded,
        color: Colors.white,
        size: 22,
      ),
    );
  }
}
