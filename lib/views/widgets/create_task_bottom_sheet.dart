import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:provider/provider.dart';
import '../../providers/tasks_provider.dart';
import '../../models/task_item.dart';
import '../../models/reminder_mode.dart';
import '../../models/recurrence_rule.dart';
import '../models/calendar_task.dart';
import '../widgets/app_bottom_navigation_bar.dart';
import '../widgets/tactile_button.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CreateTaskBottomSheet
//
// Design reference: DesignCode/Calender Screen/CreateTaskBottomSheet.txt
// Priority popup:   DesignCode/Calender Screen/PrioritySet.txt
//
// Layout (from top to bottom inside the white sheet):
//   [×]  close glass pill                    [✓] blue create circle
//   ─────────────────────────────────────────────────────────────────
//   Task Title
//   [   Add a task title                              ]
//   Due Date & Time          Start time   End time
//   [ Jul 11th, 2026 🗓 ]  [12:00 AM ⏰] [12:00 AM ⏰]
//   Task Description
//   [   Add details                                   ]
//
//   [🚩 Priority]  ← tapping reveals popup above button
//
// Behaviour:
//   • Date field  → showDatePicker
//   • Time fields → showTimePicker
//   • Priority    → inline animated popup (High / Medium / Low)
//   • Create (✓) → close + "Task created" SnackBar
//   • Close  (×) → dismiss silently
// ─────────────────────────────────────────────────────────────────────────────
class CreateTaskBottomSheet extends StatefulWidget {
  final DateTime initialDate;
  final TimeOfDay? initialTime;
  final TaskItem? taskToEdit;

  const CreateTaskBottomSheet({
    super.key,
    required this.initialDate,
    this.initialTime,
    this.taskToEdit,
  });

  @override
  State<CreateTaskBottomSheet> createState() => _CreateTaskBottomSheetState();
}

class _CreateTaskBottomSheetState extends State<CreateTaskBottomSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  late DateTime _selectedDate;
  late TimeOfDay _startTime;

  TaskPriority? _selectedPriority;
  RecurrenceType? _selectedRecurrence; // null = Never
  bool _showPriorityPopup = false;
  late bool _reminderEnabled;

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  late ReminderMode _selectedReminderMode;

  @override
  void initState() {
    super.initState();
    if (widget.taskToEdit != null) {
      final task = widget.taskToEdit!;
      _titleController.text = task.title;
      _descController.text = task.description;
      _selectedDate = task.dueDate.toLocal();
      if (task.reminderTime != null) {
        final localReminder = task.reminderTime!.toLocal();
        _startTime =
            TimeOfDay(hour: localReminder.hour, minute: localReminder.minute);
      } else {
        final localDue = task.dueDate.toLocal();
        _startTime = TimeOfDay(hour: localDue.hour, minute: localDue.minute);
      }
      _selectedPriority = switch (task.priority.toLowerCase()) {
        'high' => TaskPriority.red,
        'medium' => TaskPriority.yellow,
        'low' => TaskPriority.green,
        _ => TaskPriority.green,
      };
      _selectedReminderMode = task.reminderMode;
      _reminderEnabled = _selectedReminderMode != ReminderMode.off;
      if (task.isRecurring) {
        _selectedRecurrence = task.recurrence?.type;
      }
    } else {
      _selectedDate = widget.initialDate;
      _startTime = widget.initialTime ?? TimeOfDay.now();
      _selectedPriority = null;
      _selectedRecurrence = null;
      _selectedReminderMode = ReminderMode.notification;
      _reminderEnabled = true;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  // ── Formatters ─────────────────────────────────────────────────────────────
  /// Produces "Jul 11th, 2026" with ordinal suffix.
  String get _formattedDate {
    final day = _selectedDate.day;
    final suffix = (day >= 11 && day <= 13)
        ? 'th'
        : {1: 'st', 2: 'nd', 3: 'rd'}[day % 10] ?? 'th';
    return '${DateFormat('MMM').format(_selectedDate)} $day$suffix, ${_selectedDate.year}';
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  // ── Pickers ────────────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null && mounted) setState(() => _selectedDate = picked);
  }

  Future<void> _pickStartTime() async {
    final picked =
        await showTimePicker(context: context, initialTime: _startTime);
    if (picked != null && mounted) setState(() => _startTime = picked);
  }

  // ── Create action ──────────────────────────────────────────────────────────
  void _onCreateTapped() {
    if (_titleController.text.trim().isEmpty) return;
    HapticFeedback.lightImpact();

    final priorityStr = switch (_selectedPriority) {
      TaskPriority.red => 'High',
      TaskPriority.yellow => 'Medium',
      TaskPriority.green => 'Low',
      _ => 'Low',
    };

    final DateTime fullDueDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _startTime.hour,
      _startTime.minute,
    );

    final bool isReminderActive = _selectedReminderMode != ReminderMode.off;
    final DateTime? reminderDateTime = isReminderActive ? fullDueDate : null;

    final tasksProvider = Provider.of<TasksProvider>(context, listen: false);
    final isEditing = widget.taskToEdit != null;
    final recurrenceRule = _selectedRecurrence != null
        ? RecurrenceRule(type: _selectedRecurrence!, interval: 1)
        : null;

    if (isEditing) {
      final updated = widget.taskToEdit!.copyWith(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        dueDate: fullDueDate,
        priority: priorityStr,
        reminderTime: reminderDateTime,
        reminderEnabled: isReminderActive,
        reminderMode: _selectedReminderMode,
        isRecurring: _selectedRecurrence != null,
        recurrence: recurrenceRule,
        updatedAt: DateTime.now(),
      );
      tasksProvider.updateTask(updated);
    } else {
      tasksProvider.addTask(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        dueDate: fullDueDate,
        priority: priorityStr,
        reminderTime: reminderDateTime,
        reminderEnabled: isReminderActive,
        reminderMode: _selectedReminderMode,
        isRecurring: _selectedRecurrence != null,
        recurrence: recurrenceRule,
      );
    }

    // Capture messenger BEFORE pop so we can show SnackBar after route removal
    final String toastMsg;
    final now = DateTime.now();
    final localDue = fullDueDate.toLocal();
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

    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          toastMsg,
          style:
              const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500),
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFF0088FF),
      ),
    );
  }

  // ── Priority helpers ───────────────────────────────────────────────────────
  Color _priorityDotColor(TaskPriority p) => switch (p) {
        TaskPriority.red => const Color(0x7FFF383C),
        TaskPriority.yellow => const Color(0x7FFFCC00),
        TaskPriority.green => const Color(0x7F34C759),
      };

  Color _priorityAccentColor(TaskPriority p) => switch (p) {
        TaskPriority.red => const Color(0xFFFF383C),
        TaskPriority.yellow => const Color(0xFFCC9900),
        TaskPriority.green => const Color(0xFF34C759),
      };

  String _priorityLabel(TaskPriority p) => switch (p) {
        TaskPriority.red => 'High',
        TaskPriority.yellow => 'Medium',
        TaskPriority.green => 'Low',
      };

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final keyboardPad = MediaQuery.of(context).viewInsets.bottom;
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;

    return GestureDetector(
      onTap: () {
        if (_showPriorityPopup) setState(() => _showPriorityPopup = false);
        FocusScope.of(context).unfocus();
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x3F000000),
                blurRadius: 16,
                offset: Offset(0, 0),
                spreadRadius: 0,
              ),
            ],
          ),
          padding: EdgeInsets.only(bottom: keyboardPad),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: ShapeDecoration(
                  color: const Color(0x4C3C3C43),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Sheet Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    // Close pill button
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: ShapeDecoration(
                          color: const Color(0x19000000),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: SvgPicture.asset(
                          'assets/icons/cross.svg',
                          width: 16,
                          height: 16,
                          colorFilter: const ColorFilter.mode(
                            Color(0xFF1C1C1E),
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Create — solid blue circle
                    GestureDetector(
                      onTap: _onCreateTapped,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const ShapeDecoration(
                          color: Color(0xFF0088FF),
                          shape: OvalBorder(),
                        ),
                        child: Center(
                          child: SvgPicture.asset(
                            'assets/icons/calendar_check.svg',
                            width: 18,
                            height: 18,
                            colorFilter: const ColorFilter.mode(
                              Colors.white,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Form body
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPad + 24),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel('Task Title'),
                      const SizedBox(height: 8),
                      _inputField(
                        controller: _titleController,
                        hint: 'Add a task title',
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Due Date
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _sectionLabel('Due Date'),
                                const SizedBox(height: 8),
                                _dateField(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),

                          // 2. Time
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _sectionLabel('Time'),
                                const SizedBox(height: 8),
                                _timeField(_startTime, _pickStartTime),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),

                          // 3. Priority
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _sectionLabel('Priority'),
                                const SizedBox(height: 8),
                                _inlinePriorityPill(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_showPriorityPopup) ...[
                        const SizedBox(height: 8),
                        _priorityPopup(),
                      ],
                      const SizedBox(height: 16),
                      _sectionLabel('Task Description (Optional)'),
                      const SizedBox(height: 8),
                      _inputField(
                        controller: _descController,
                        hint: 'Add details',
                      ),
                      const SizedBox(height: 16),
                      _reminderSection(),
                      const SizedBox(height: 16),
                      _recurrenceSection(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reminderSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: ShapeDecoration(
        color: const Color(0x28787880),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Icon(
                  _selectedReminderMode == ReminderMode.alarm
                      ? Icons.alarm_on_rounded
                      : (_selectedReminderMode == ReminderMode.notification
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_off_rounded),
                  size: 16,
                  color: _selectedReminderMode == ReminderMode.alarm
                      ? const Color(0xFFFF9500)
                      : (_selectedReminderMode == ReminderMode.notification
                          ? const Color(0xFF0088FF)
                          : const Color(0x993C3C43)),
                ),
                const SizedBox(width: 8),
                Text(
                  'Reminder Mode',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF333333),
                    letterSpacing: -0.43,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 40,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0x1F787880),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _buildReminderModePill(ReminderMode.off, 'Off', null),
                _buildReminderModePill(ReminderMode.notification,
                    '🔔 Notification', const Color(0xFF0088FF)),
                _buildReminderModePill(
                    ReminderMode.alarm, '⏰ Alarm', const Color(0xFFFF9500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
            borderRadius: BorderRadius.circular(11),
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
              fontSize: 11,
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

  // ── Widget builders ────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: Color(0xFF333333),
          fontSize: 16,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
          letterSpacing: -0.43,
        ),
      );

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
  }) {
    return Container(
      height: 45,
      decoration: ShapeDecoration(
        color: const Color(0x28787880),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Center(
          child: TextField(
            controller: controller,
            style: const TextStyle(
              color: Color(0xFF333333),
              fontSize: 14,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              letterSpacing: -0.43,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: Color(0x993C3C43),
                fontSize: 14,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                letterSpacing: -0.43,
              ),
              border: InputBorder.none,
              isCollapsed: true,
            ),
          ),
        ),
      ),
    );
  }

  /// Date pill with calendar icon on the right.
  Widget _dateField() {
    return GestureDetector(
      onTap: () {
        if (_showPriorityPopup) setState(() => _showPriorityPopup = false);
        _pickDate();
      },
      child: Container(
        height: 45,
        decoration: ShapeDecoration(
          color: const Color(0x28787880),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  _formattedDate,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0x993C3C43),
                    fontSize: 13,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    letterSpacing: -0.43,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SvgPicture.asset(
                'assets/icons/calendar_icon.svg',
                width: 14,
                height: 14,
                colorFilter: const ColorFilter.mode(
                  Color(0xFF888888),
                  BlendMode.srcIn,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Time pill with alarm-clock icon on the right.
  Widget _timeField(TimeOfDay time, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        if (_showPriorityPopup) setState(() => _showPriorityPopup = false);
        onTap();
      },
      child: Container(
        height: 45,
        decoration: ShapeDecoration(
          color: const Color(0x28787880),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  _formatTime(time),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0x993C3C43),
                    fontSize: 12,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    letterSpacing: -0.43,
                  ),
                ),
              ),
              const SizedBox(width: 3),
              SvgPicture.asset(
                'assets/icons/alarm_clock.svg',
                width: 13,
                height: 13,
                colorFilter: const ColorFilter.mode(
                  Color(0xFF888888),
                  BlendMode.srcIn,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inlinePriorityPill() {
    final color = switch (_selectedPriority) {
      TaskPriority.red => const Color(0xFFFF453A),
      TaskPriority.yellow => const Color(0xFFFF9F0A),
      TaskPriority.green => const Color(0xFF30D158),
      null => const Color(0x993C3C43),
    };
    final label = switch (_selectedPriority) {
      TaskPriority.red => 'High',
      TaskPriority.yellow => 'Medium',
      TaskPriority.green => 'Low',
      null => 'None',
    };

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        FocusScope.of(context).unfocus();
        setState(() {
          _showPriorityPopup = !_showPriorityPopup;
        });
      },
      child: Container(
        height: 45,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: ShapeDecoration(
          color: color.withOpacity(0.12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: color.withOpacity(0.4), width: 1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/icons/flag_alt.svg',
              width: 14,
              height: 14,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _priorityPopup() {
    return Container(
      width: 230,
      height: 45,
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        shadows: const [
          BoxShadow(
            color: Color(0x3F000000),
            blurRadius: 16,
            offset: Offset(0, 0),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _priorityOption('High', const Color(0x7FFF383C), TaskPriority.red),
          _priorityOption(
              'Medium', const Color(0x7FFFCC00), TaskPriority.yellow),
          _priorityOption('Low', const Color(0x7F34C759), TaskPriority.green),
        ],
      ),
    );
  }

  /// A single option row inside the priority popup (dot + label).
  Widget _priorityOption(String label, Color dotColor, TaskPriority priority) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedPriority = priority;
          _showPriorityPopup = false;
        });
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: ShapeDecoration(
              color: dotColor,
              shape: const OvalBorder(),
            ),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF333333),
              fontSize: 15,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              letterSpacing: -0.43,
            ),
          ),
        ],
      ),
    );
  }

  Widget _recurrenceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Repeat / Recurrence'),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _recurrenceChip(null, 'Never'),
              const SizedBox(width: 8),
              _recurrenceChip(RecurrenceType.daily, 'Daily'),
              const SizedBox(width: 8),
              _recurrenceChip(RecurrenceType.weekly, 'Weekly'),
              const SizedBox(width: 8),
              _recurrenceChip(RecurrenceType.monthly, 'Monthly'),
              const SizedBox(width: 8),
              _recurrenceChip(RecurrenceType.yearly, 'Yearly'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _recurrenceChip(RecurrenceType? type, String label) {
    final isSelected = _selectedRecurrence == type;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedRecurrence = type;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0088FF) : const Color(0x28787880),
          borderRadius: BorderRadius.circular(19),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF333333),
            fontSize: 13,
            fontFamily: 'Inter',
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  // ── Glass pill (matches other screen headers) ──────────────────────────────
  Widget _buildGlassPill({
    required Widget child,
    required VoidCallback onTap,
  }) {
    return BottomBarGlassSurface(
      width: 44.0,
      height: 44.0,
      borderRadius: BorderRadius.circular(22.0),
      child: TactileButton(
        useAppleSpring: true,
        compressionScale: 0.7,
        settleDuration: const Duration(milliseconds: 1000),
        onTap: onTap,
        child: Center(child: child),
      ),
    );
  }
}

// ── Speech bubble downward-pointing triangle ───────────────────────────────
class _TrianglePainter extends CustomPainter {
  const _TrianglePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_TrianglePainter _) => false;
}
