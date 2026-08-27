import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/task_item.dart';
import '../../models/recurrence_rule.dart';
import '../../models/reminder_mode.dart';
import '../../models/repeat_rule.dart';
import '../../providers/tasks_provider.dart';
import '../widgets/tactile_button.dart';
import '../widgets/app_header_bar.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// TaskEditorScreen
///
/// Implements the exact design specification from:
/// `DesignCode/TaskEditor/TaskEditorScreen.txt` and Figma reference mockup.
///
/// Features & Layout Architecture:
/// - Fixed outer blue header card (Color(0xFF0088FF)) displaying Date & Time
/// - Fixed AppHeaderBar with standard Hero tags ('hero_profile_header', 'hero_more_options')
/// - White card container (Color(0xFFFFFFFF)) with 30px top radius
/// - Inner-only content scrolling (form fields scroll while header remains pinned)
/// - Responsive Priority selector (zero horizontal overflow on any device)
/// - Zero subpixel text overflow on Task Title, Description, and Priority button
/// - Rect-clip free Repeat option scale animations
/// - Toast SnackBar feedback on Save
/// ─────────────────────────────────────────────────────────────────────────────

class TaskEditorScreen extends StatefulWidget {
  final DateTime? initialDate;
  final TaskItem? taskToEdit;

  const TaskEditorScreen({
    super.key,
    this.initialDate,
    this.taskToEdit,
  });

  @override
  State<TaskEditorScreen> createState() => _TaskEditorScreenState();
}

/// Backward compatibility wrapper alias for legacy callers
class CreateTaskScreen extends TaskEditorScreen {
  const CreateTaskScreen({
    super.key,
    super.initialDate,
    super.taskToEdit,
  });
}

class _TaskEditorScreenState extends State<TaskEditorScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  String _selectedPriority = 'None'; // 'High', 'Medium', 'Low', 'None'
  RecurrenceType? _selectedRecurrence; // null = Never, daily, weekly, monthly
  bool _showPriorityPicker = false;
  late bool _reminderEnabled;
  late ReminderMode _selectedReminderMode;

  @override
  void initState() {
    super.initState();
    if (widget.taskToEdit != null) {
      final task = widget.taskToEdit!;
      _titleController.text = task.title;
      _descriptionController.text = task.description;
      _selectedDate = task.dueDate.toLocal();
      if (task.reminderTime != null) {
        final reminder = task.reminderTime!.toLocal();
        _selectedTime = TimeOfDay(hour: reminder.hour, minute: reminder.minute);
      } else {
        final due = task.dueDate.toLocal();
        _selectedTime = TimeOfDay(hour: due.hour, minute: due.minute);
      }
      _selectedPriority = task.priority.isNotEmpty ? task.priority : 'None';
      _selectedReminderMode = task.reminderMode;
      _reminderEnabled = _selectedReminderMode != ReminderMode.off;
      if (task.isRecurring) {
        _selectedRecurrence = task.recurrence?.type;
      }
    } else {
      _selectedDate = widget.initialDate ?? DateTime.now();
      _selectedTime = TimeOfDay.now();
      _selectedPriority = 'None';
      _selectedRecurrence = null;
      _selectedReminderMode = ReminderMode.notification;
      _reminderEnabled = true;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Pick Due Date
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0088FF),
              onPrimary: Colors.white,
              onSurface: Color(0xFF333333),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // Pick Due Time
  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0088FF),
              onPrimary: Colors.white,
              onSurface: Color(0xFF333333),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  // Save Task
  Future<void> _saveTask() async {
    final String title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a task title'),
          backgroundColor: Color(0xFFFF453A),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final tasksProvider = Provider.of<TasksProvider>(context, listen: false);
    final String description = _descriptionController.text.trim();

    final DateTime dueDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final bool isReminderActive = _selectedReminderMode != ReminderMode.off;
    final DateTime? reminderDateTime = isReminderActive ? dueDateTime : null;

    final recurrenceRule = _selectedRecurrence != null
        ? RecurrenceRule(type: _selectedRecurrence!, interval: 1)
        : null;

    final repeatRule = _selectedRecurrence != null
        ? RepeatRuleExtension.fromDbString(_selectedRecurrence!.toDbString())
        : RepeatRule.none;

    final isEditing = widget.taskToEdit != null;

    if (isEditing) {
      final updated = widget.taskToEdit!.copyWith(
        title: title,
        description: description,
        dueDate: dueDateTime,
        reminderTime: reminderDateTime,
        reminderEnabled: isReminderActive,
        reminderMode: _selectedReminderMode,
        priority: _selectedPriority,
        repeatRule: repeatRule,
        isRecurring: _selectedRecurrence != null,
        recurrence: recurrenceRule,
        updatedAt: DateTime.now(),
      );
      await tasksProvider.updateTask(updated);
    } else {
      await tasksProvider.addTask(
        title: title,
        description: description,
        dueDate: dueDateTime,
        priority: _selectedPriority,
        reminderTime: reminderDateTime,
        reminderEnabled: isReminderActive,
        reminderMode: _selectedReminderMode,
        repeatRule: repeatRule,
        isRecurring: _selectedRecurrence != null,
        recurrence: recurrenceRule,
      );
    }

    HapticFeedback.mediumImpact();
    if (mounted) {
      final String toastMsg;
      final now = DateTime.now();
      final localDue = dueDateTime.toLocal();
      final todayStart = DateTime(now.year, now.month, now.day);
      final dueStart = DateTime(localDue.year, localDue.month, localDue.day);
      final verb = isEditing ? 'updated' : 'saved';

      if (dueStart.isBefore(todayStart)) {
        toastMsg = '🎉 Task $verb in Missed Tasks';
      } else if (dueStart.isAtSameMomentAs(todayStart)) {
        toastMsg = "🎉 Task $verb in Today's Tasks";
      } else {
        final diffDays = dueStart.difference(todayStart).inDays;
        if (diffDays <= 7) {
          toastMsg = '🎉 Task $verb in Weekly Tasks';
        } else {
          toastMsg = '🎉 Task $verb in Monthly Tasks';
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            toastMsg,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: const Color(0xFF0088FF),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
    }
  }

  // Format Helper: "Jul 11th, 2026"
  String _formatDateWithSuffix(DateTime date) {
    final day = date.day;
    String suffix = 'th';
    if (day % 10 == 1 && day != 11) {
      suffix = 'st';
    } else if (day % 10 == 2 && day != 12) {
      suffix = 'nd';
    } else if (day % 10 == 3 && day != 13) {
      suffix = 'rd';
    }
    final monthStr = DateFormat('MMM').format(date);
    return '$monthStr $day$suffix, ${date.year}';
  }

  // Priority Flag Color Helper
  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return const Color(0xFFFF453A);
      case 'medium':
        return const Color(0xFFFF9F0A);
      case 'low':
        return const Color(0xFF30D158);
      default:
        return const Color(0x993C3C43);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Format Header Date & Time Strings
    final String dateHeaderStr =
        DateFormat('EEE, d MMMM yyyy').format(_selectedDate);
    final String timeHeaderStr = DateFormat('hh:mm a').format(
      DateTime(2026, 1, 1, _selectedTime.hour, _selectedTime.minute),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom:
            false, // top safe area handled by system — mirrors NoteEditorScreen
        child: Stack(
          children: [
            // ── Card Area (identical structure to NoteEditorScreen, blue instead of amber) ──
            Positioned(
              left: 0.0,
              right: 0.0,
              top:
                  74.0, // starts below the top bar buttons — exact same as NoteEditorScreen
              bottom: 0.0,
              child: Stack(
                children: [
                  // 1. Background layers (blue card + white overlay)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF333333).withOpacity(0.06),
                            blurRadius: 20.0,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Blue header band — same dimensions as amber in NoteEditorScreen
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: 100.0,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Color(0xFF0088FF),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(30.0),
                                  topRight: Radius.circular(30.0),
                                ),
                              ),
                            ),
                          ),
                          // White card overlapping blue — starts at 50px, same as NoteEditorScreen
                          Positioned(
                            top: 50.0,
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(30.0),
                                  topRight: Radius.circular(30.0),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 2. Scrollable form content — starts at top: 59 (header 50 + gap 9)
                  Positioned.fill(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 700.0),
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.only(
                              left: 20.0,
                              right: 20.0,
                              top: 59.0, // blue sticky header (50) + gap (9)
                              bottom: 40.0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── Task Title Field ──────────────────────────────
                                Text(
                                  'Task Title',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF333333),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: -0.43,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  height: 45,
                                  clipBehavior: Clip.antiAlias,
                                  decoration: ShapeDecoration(
                                    color: const Color(0x28787880),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  child: TextField(
                                    controller: _titleController,
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF333333),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Add a task title',
                                      hintStyle: GoogleFonts.inter(
                                        color: const Color(0x993C3C43),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                        letterSpacing: -0.43,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 20, vertical: 12),
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 22),

                                // ── Due Date, Time & Priority Section (DueDate - Time - Priority) ───────
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        // 1. Due Date Picker
                                        Expanded(
                                          flex: 3,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Due Date',
                                                style: GoogleFonts.inter(
                                                  color:
                                                      const Color(0xFF333333),
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w500,
                                                  letterSpacing: -0.43,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              TactileButton(
                                                onTap: _selectDate,
                                                child: Container(
                                                  height: 45,
                                                  padding: const EdgeInsets
                                                      .symmetric(horizontal: 8),
                                                  decoration: ShapeDecoration(
                                                    color:
                                                        const Color(0x28787880),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              16),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          _formatDateWithSuffix(
                                                              _selectedDate),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              GoogleFonts.inter(
                                                            color: const Color(
                                                                0x993C3C43),
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w400,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      SvgPicture.asset(
                                                        'assets/icons/calendar_icon.svg',
                                                        width: 14,
                                                        height: 14,
                                                        colorFilter:
                                                            const ColorFilter
                                                                .mode(
                                                          Color(0x993C3C43),
                                                          BlendMode.srcIn,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        const SizedBox(width: 6),

                                        // 2. Time Picker
                                        Expanded(
                                          flex: 2,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Time',
                                                style: GoogleFonts.inter(
                                                  color:
                                                      const Color(0xFF333333),
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w500,
                                                  letterSpacing: -0.43,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              TactileButton(
                                                onTap: _selectTime,
                                                child: Container(
                                                  height: 45,
                                                  padding: const EdgeInsets
                                                      .symmetric(horizontal: 6),
                                                  decoration: ShapeDecoration(
                                                    color:
                                                        const Color(0x28787880),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              16),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          _selectedTime
                                                              .format(context),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              GoogleFonts.inter(
                                                            color: const Color(
                                                                0x993C3C43),
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w400,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 2),
                                                      SvgPicture.asset(
                                                        'assets/icons/alarm_clock.svg',
                                                        width: 14,
                                                        height: 14,
                                                        colorFilter:
                                                            const ColorFilter
                                                                .mode(
                                                          Color(0x993C3C43),
                                                          BlendMode.srcIn,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        const SizedBox(width: 6),

                                        // 3. Priority Picker
                                        Expanded(
                                          flex: 2,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Priority',
                                                style: GoogleFonts.inter(
                                                  color:
                                                      const Color(0xFF333333),
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w500,
                                                  letterSpacing: -0.43,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              TactileButton(
                                                onTap: () {
                                                  HapticFeedback.lightImpact();
                                                  setState(() {
                                                    _showPriorityPicker =
                                                        !_showPriorityPicker;
                                                  });
                                                },
                                                child: Container(
                                                  height: 45,
                                                  padding: const EdgeInsets
                                                      .symmetric(horizontal: 6),
                                                  decoration: ShapeDecoration(
                                                    color: _getPriorityColor(
                                                            _selectedPriority)
                                                        .withOpacity(0.12),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              16),
                                                      side: BorderSide(
                                                        color: _getPriorityColor(
                                                                _selectedPriority)
                                                            .withOpacity(0.4),
                                                        width: 1,
                                                      ),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      SvgPicture.asset(
                                                        'assets/icons/flag_alt.svg',
                                                        width: 13,
                                                        height: 13,
                                                        colorFilter:
                                                            ColorFilter.mode(
                                                          _getPriorityColor(
                                                              _selectedPriority),
                                                          BlendMode.srcIn,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Flexible(
                                                        child: Text(
                                                          _selectedPriority,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              GoogleFonts.inter(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: _getPriorityColor(
                                                                _selectedPriority),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (_showPriorityPicker) ...[
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Color(0xFF333333)
                                                  .withOpacity(0.08),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            _buildPriorityOption('High',
                                                const Color(0xFFFF453A)),
                                            _buildPriorityOption('Medium',
                                                const Color(0xFFFF9F0A)),
                                            _buildPriorityOption(
                                                'Low', const Color(0xFF30D158)),
                                            _buildPriorityOption('None',
                                                const Color(0x993C3C43)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),

                                const SizedBox(height: 22),

                                // ── Task Description Field ────────────────────────
                                Text(
                                  'Task Description (Optional)',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF333333),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: -0.43,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  height: 122,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 4),
                                  decoration: ShapeDecoration(
                                    color: const Color(0x28787880),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  child: TextField(
                                    controller: _descriptionController,
                                    maxLines: null,
                                    keyboardType: TextInputType.multiline,
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF333333),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Add details',
                                      hintStyle: GoogleFonts.inter(
                                        color: const Color(0x993C3C43),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                        letterSpacing: -0.43,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              vertical: 10),
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 22),

                                // ── Reminder Mode Segmented Pill Selector Card ───────────────────────
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: ShapeDecoration(
                                    color: const Color(0x28787880),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            left: 4, bottom: 8),
                                        child: Row(
                                          children: [
                                            Icon(
                                              _selectedReminderMode ==
                                                      ReminderMode.alarm
                                                  ? Icons.alarm_on_rounded
                                                  : (_selectedReminderMode ==
                                                          ReminderMode
                                                              .notification
                                                      ? Icons
                                                          .notifications_active_rounded
                                                      : Icons
                                                          .notifications_off_rounded),
                                              size: 18,
                                              color: _selectedReminderMode ==
                                                      ReminderMode.alarm
                                                  ? const Color(0xFFFF9500)
                                                  : (_selectedReminderMode ==
                                                          ReminderMode
                                                              .notification
                                                      ? const Color(0xFF0088FF)
                                                      : const Color(
                                                          0x993C3C43)),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Reminder Mode',
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: const Color(0xFF333333),
                                                letterSpacing: -0.43,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        height: 42,
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: const Color(0x1F787880),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          children: [
                                            _buildReminderModePill(
                                                ReminderMode.off, 'Off', null),
                                            _buildReminderModePill(
                                                ReminderMode.notification,
                                                '🔔 Notification',
                                                const Color(0xFF0088FF)),
                                            _buildReminderModePill(
                                                ReminderMode.alarm,
                                                '⏰ Alarm',
                                                const Color(0xFFFF9500)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 22),

                                // ── Repeat Options Section ────────────────────────
                                Text(
                                  'Repeat',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF333333),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: -0.43,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    clipBehavior: Clip.none,
                                    physics: const BouncingScrollPhysics(),
                                    child: Row(
                                      children: [
                                        _buildRepeatPill(null, 'Never', 88),
                                        const SizedBox(width: 9),
                                        _buildRepeatPill(
                                            RecurrenceType.daily, 'Daily', 88),
                                        const SizedBox(width: 9),
                                        _buildRepeatPill(RecurrenceType.weekly,
                                            'Weekly', 97),
                                        const SizedBox(width: 9),
                                        _buildRepeatPill(RecurrenceType.monthly,
                                            'Monthly', 112),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 35),

                                // ── Bottom Action Buttons ─────────────────────────
                                Row(
                                  children: [
                                    Expanded(
                                      child: TactileButton(
                                        onTap: () => Navigator.pop(context),
                                        child: Container(
                                          height: 50,
                                          decoration: ShapeDecoration(
                                            color: const Color(0x28787880),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              'Cancel',
                                              style: GoogleFonts.inter(
                                                color: const Color(0x993C3C43),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w400,
                                                letterSpacing: -0.43,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: TactileButton(
                                        onTap: _saveTask,
                                        child: Container(
                                          height: 50,
                                          decoration: ShapeDecoration(
                                            color: const Color(0xFF0088FF),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              'Save',
                                              style: GoogleFonts.inter(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w400,
                                                letterSpacing: -0.43,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 30),
                              ],
                            ),
                          ),
                        ), // ConstrainedBox
                      ), // Center
                    ),

                        // Sticky Blue Date-Time Header with Blur — mirrors NoteEditorScreen's sticky amber bar
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: 50.0,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(30.0),
                              topRight: Radius.circular(30.0),
                            ),
                            child: BackdropFilter(
                              filter: ui.ImageFilter.blur(
                                  sigmaX: 10.0, sigmaY: 10.0),
                              child: Container(
                                color: const Color(0xFF0088FF).withOpacity(0.9),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24.0),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      dateHeaderStr,
                                      style: GoogleFonts.inter(
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.w400,
                                        color: Colors.white,
                                        letterSpacing: -0.43,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: _selectDate,
                                      child: Text(
                                        timeHeaderStr,
                                        style: GoogleFonts.inter(
                                          fontSize: 14.0,
                                          fontWeight: FontWeight.w400,
                                          color: Colors.white,
                                          letterSpacing: -0.43,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── AppHeaderBar — same position as NoteEditorScreen (top: 12, horizontal: 24) ──
            Positioned(
              top: 12.0,
              left: 24.0,
              right: 24.0,
              child: AppHeaderBar(
                leftWidth: 44.0,
                leftHeroTag: 'hero_task_editor_back',
                onLeftTap: () => Navigator.pop(context),
                leftChild: SvgPicture.asset(
                  'assets/icons/angle_left.svg',
                  width: 22,
                  height: 22,
                  colorFilter: const ColorFilter.mode(
                      Color(0xFF1C1C1E), BlendMode.srcIn),
                ),
                rightWidth: 44.0,
                rightHeroTag: 'hero_task_editor_more',
                rightChild: const Center(
                  child: Icon(
                    Icons.more_horiz_rounded,
                    size: 20,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Priority Option Helper
  Widget _buildPriorityOption(String level, Color color) {
    final bool isSelected =
        _selectedPriority.toLowerCase() == level.toLowerCase();
    return TactileButton(
      onTap: () {
        setState(() {
          _selectedPriority = level;
          _showPriorityPicker = false;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/icons/flag_alt.svg',
              width: 14,
              height: 14,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
            const SizedBox(width: 6),
            Text(
              level,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF333333),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Repeat Pill Helper Widget
  Widget _buildRepeatPill(RecurrenceType? type, String label, double width) {
    final bool isSelected = _selectedRecurrence == type;

    return TactileButton(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedRecurrence = type;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: width,
        height: 45,
        decoration: ShapeDecoration(
          color: isSelected ? const Color(0xFF0088FF) : const Color(0x28787880),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: isSelected ? Colors.white : const Color(0x993C3C43),
              fontSize: 14,
              fontWeight: FontWeight.w400,
              letterSpacing: -0.43,
            ),
          ),
        ),
      ),
    );
  }

  // Reminder Mode Pill Helper Widget
  Widget _buildReminderModePill(
      ReminderMode mode, String label, Color? activeColor) {
    final isSelected = _selectedReminderMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _selectedReminderMode = mode;
            _reminderEnabled = mode != ReminderMode.off;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Color(0xFF333333).withOpacity(0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected
                  ? (activeColor ?? const Color(0xFF333333))
                  : const Color(0x993C3C43),
            ),
          ),
        ),
      ),
    );
  }
}
