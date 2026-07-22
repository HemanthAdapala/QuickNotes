import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import 'package:provider/provider.dart';
import '../../providers/tasks_provider.dart';
import '../../models/task_item.dart';
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
  final TaskItem? taskToEdit;

  const CreateTaskBottomSheet({
    super.key,
    required this.initialDate,
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
  late TimeOfDay _endTime;

  TaskPriority? _selectedPriority;
  bool _showPriorityPopup = false;

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    if (widget.taskToEdit != null) {
      final task = widget.taskToEdit!;
      _titleController.text = task.title;
      _descController.text = task.description;
      _selectedDate = task.dueDate;
      if (task.reminderTime != null) {
        _startTime = TimeOfDay(hour: task.reminderTime!.hour, minute: task.reminderTime!.minute);
      } else {
        _startTime = TimeOfDay(hour: task.dueDate.hour, minute: task.dueDate.minute);
      }
      _endTime = _startTime;
      _selectedPriority = switch (task.priority.toLowerCase()) {
        'high' => TaskPriority.red,
        'medium' => TaskPriority.yellow,
        'low' => TaskPriority.green,
        _ => TaskPriority.green,
      };
    } else {
      _selectedDate = widget.initialDate;
      _startTime = const TimeOfDay(hour: 0, minute: 0);
      _endTime = const TimeOfDay(hour: 0, minute: 0);
      _selectedPriority = null;
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

  Future<void> _pickEndTime() async {
    final picked =
        await showTimePicker(context: context, initialTime: _endTime);
    if (picked != null && mounted) setState(() => _endTime = picked);
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

    final DateTime reminderDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _startTime.hour,
      _startTime.minute,
    );

    final tasksProvider = Provider.of<TasksProvider>(context, listen: false);
    final isEditing = widget.taskToEdit != null;
    
    if (isEditing) {
      final updated = widget.taskToEdit!.copyWith(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        dueDate: _selectedDate,
        priority: priorityStr,
        reminderTime: reminderDateTime,
        updatedAt: DateTime.now(),
      );
      tasksProvider.updateTask(updated);
    } else {
      tasksProvider.addTask(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        dueDate: _selectedDate,
        priority: priorityStr,
        reminderTime: reminderDateTime,
      );
    }

    // Capture messenger BEFORE pop so we can show SnackBar after route removal
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          isEditing ? 'Task updated' : 'Task created',
          style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500),
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xFF1C1C1E),
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
      // Tap outside priority popup / text fields to dismiss them
      onTap: () {
        if (_showPriorityPopup) setState(() => _showPriorityPopup = false);
        FocusScope.of(context).unfocus();
      },
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          // Subtle top shadow matching the design's blur-16 spec
          boxShadow: [
            BoxShadow(
              color: Color(0x3F000000),
              blurRadius: 16,
              offset: Offset(0, 0),
              spreadRadius: 0,
            ),
          ],
        ),
        // Lift content up when keyboard is visible
        padding: EdgeInsets.only(bottom: keyboardPad),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header row ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Row(
                children: [
                  // Close — glass pill (matches other screen headers)
                  _buildGlassPill(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop();
                    },
                    child: SvgPicture.asset(
                      'assets/icons/calendar_cross.svg',
                      width: 15,
                      height: 15,
                      colorFilter: const ColorFilter.mode(
                        Color(0xFF1C1C1E),
                        BlendMode.srcIn,
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Create — solid blue circle with check icon
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

            // ── Scrollable form body ────────────────────────────────────────
            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPad + 24),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Task Title ───────────────────────────────────────────
                  _sectionLabel('Task Title'),
                  const SizedBox(height: 8),
                  _inputField(
                    controller: _titleController,
                    hint: 'Add a task title',
                  ),

                  const SizedBox(height: 16),

                  // ── Due Date & Time row ──────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date column (expands to fill remaining space)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionLabel('Due Date & Time'),
                            const SizedBox(height: 8),
                            _dateField(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),

                      // Start time column
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel('Start time'),
                          const SizedBox(height: 8),
                          _timeField(_startTime, _pickStartTime),
                        ],
                      ),
                      const SizedBox(width: 5),

                      // End time column
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel('End time'),
                          const SizedBox(height: 8),
                          _timeField(_endTime, _pickEndTime),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Task Description ──────────────────────────────────────
                  _sectionLabel('Task Description'),
                  const SizedBox(height: 8),
                  _inputField(
                    controller: _descController,
                    hint: 'Add details',
                  ),

                  const SizedBox(height: 16),

                  // ── Priority (popup + button) ─────────────────────────────
                  _prioritySection(),
                ],
              ),
            ),
          ],
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

  /// Time pill (95px wide) with alarm-clock icon on the right.
  Widget _timeField(TimeOfDay time, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        if (_showPriorityPopup) setState(() => _showPriorityPopup = false);
        onTap();
      },
      child: Container(
        width: 95,
        height: 45,
        decoration: ShapeDecoration(
          color: const Color(0x28787880),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatTime(time),
                style: const TextStyle(
                  color: Color(0x993C3C43),
                  fontSize: 12,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.43,
                ),
              ),
              const SizedBox(width: 4),
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

  // ── Priority section ───────────────────────────────────────────────────────
  Widget _prioritySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Popup (animates in above the button) ──────────────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: _showPriorityPopup
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // White pill — 219×45, shadow blur-16
                    Container(
                      width: 219,
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
                          _priorityOption(
                              'High', const Color(0x7FFF383C), TaskPriority.red),
                          _priorityOption(
                              'Medium', const Color(0x7FFFCC00), TaskPriority.yellow),
                          _priorityOption(
                              'Low', const Color(0x7F34C759), TaskPriority.green),
                        ],
                      ),
                    ),

                    // Speech-bubble downward-pointing tail
                    // Aligned to roughly the center of the Priority button
                    const Padding(
                      padding: EdgeInsets.only(left: 42),
                      child: CustomPaint(
                        size: Size(16, 8),
                        painter: _TrianglePainter(),
                      ),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),

        // ── Priority button ───────────────────────────────────────────────
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            FocusScope.of(context).unfocus();
            setState(() => _showPriorityPopup = !_showPriorityPopup);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 45,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: ShapeDecoration(
              shape: RoundedRectangleBorder(
                side: BorderSide(
                  width: 1.2,
                  color: _selectedPriority != null
                      ? _priorityAccentColor(_selectedPriority!)
                      : const Color(0xFF333333),
                ),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // flag-alt icon
                SvgPicture.asset(
                  'assets/icons/flag_alt.svg',
                  width: 14,
                  height: 14,
                  colorFilter: ColorFilter.mode(
                    _selectedPriority != null
                        ? _priorityAccentColor(_selectedPriority!)
                        : const Color(0xFF333333),
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 6),

                // Label: "Priority" or selected priority with dot
                _selectedPriority != null
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: ShapeDecoration(
                              color: _priorityDotColor(_selectedPriority!),
                              shape: const OvalBorder(),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _priorityLabel(_selectedPriority!),
                            style: TextStyle(
                              color: _priorityAccentColor(_selectedPriority!),
                              fontSize: 15,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w500,
                              letterSpacing: -0.43,
                            ),
                          ),
                        ],
                      )
                    : const Text(
                        'Priority',
                        style: TextStyle(
                          color: Color(0xFF333333),
                          fontSize: 15,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.43,
                        ),
                      ),
              ],
            ),
          ),
        ),
      ],
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
              color: Colors.black,
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
