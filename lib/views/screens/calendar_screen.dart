import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import 'package:provider/provider.dart';
import '../models/calendar_task.dart';
import '../../models/task_item.dart';
import '../../models/repeat_rule.dart';
import '../../providers/tasks_provider.dart';
import '../widgets/app_bottom_navigation_bar.dart';
import '../widgets/calendar_grid_widget.dart';
import '../widgets/celebration_overlay.dart';
import 'create_task_screen.dart';
import '../widgets/create_task_bottom_sheet.dart';
import '../widgets/month_container.dart';
import '../widgets/tactile_button.dart';
import '../widgets/task_widgets_container.dart';
import '../widgets/delete_task_confirmation_dialog.dart';
import '../../core/animations/page_transitions.dart';
import 'search_screen.dart';
import '../../core/animations/search_transition_routes.dart';
import '../../themes/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CalendarScreen
//
// Layout:
//   ┌──────────────────────────────────────┐
//   │  [←]    [‹ January,2026 ›]    [🔍]   │  ← fixed header row
//   ├──────────────────────────────────────┤
//   │           Calendar grid              │  ← fixed (no scroll)
//   │   • Blue check = ALL tasks done      │
//   │   • Gray cross = not all done        │
//   ├──────────────────────────────────────┤
//   │  Tasks for Jan 16   [ + Add Task ]   │  ← fixed panel header
//   │  [Task card …]                       │  ← scrollable
//   └──────────────────────────────────────┘
//
// Functionality changes (v2):
//   1. Blue check cell ONLY when every task for that day is completed.
//   2. Navigating back to current month re-selects today.
//   3. Completing the last pending task triggers a particle burst celebration.
// ─────────────────────────────────────────────────────────────────────────────
class CalendarScreen extends StatefulWidget {
  /// Optional back handler.
  /// • Provided by [HomeScreen] when CalendarScreen is embedded as a tab
  ///   (calls onBack to switch back to the home tab).
  /// • Omitted when CalendarScreen is pushed onto the Navigator stack
  ///   (falls back to Navigator.pop).
  final VoidCallback? onBack;

  const CalendarScreen({super.key, this.onBack});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _currentMonth = DateTime.now();
  late int _selectedDay;

  // Per-day task lists for the currently viewed month.
  // Pre-populated in _initMonthTasks(), toggled in-place.
  final Map<int, List<CalendarTask>> _monthTasks = {};

  // Active celebration overlays — cleaned up on dispose.
  final List<OverlayEntry> _overlayEntries = [];

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now().day;
    _initMonthTasks();
  }

  @override
  void dispose() {
    for (final entry in _overlayEntries) {
      entry.remove();
    }
    super.dispose();
  }

  // ── Month tasks — populate from TasksProvider for the current month ───────
  void _initMonthTasks() {
    _monthTasks.clear();
    final tasksProvider = Provider.of<TasksProvider>(context, listen: false);
    final daysInMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, day);
      final dayTasks = tasksProvider.getTasksForDate(date);

      _monthTasks[day] = dayTasks.map((t) {
        final priority = switch (t.priority.toLowerCase()) {
          'high' => TaskPriority.red,
          'medium' => TaskPriority.yellow,
          'low' => TaskPriority.green,
          _ => TaskPriority.green,
        };
        return CalendarTask(
          id: t.id,
          title: t.title,
          subtitle: t.description.isNotEmpty ? t.description : 'Task',
          priority: priority,
          isCompleted: t.completed,
        );
      }).toList();
    }
  }

  // ── Computed: task progress per day (drives orbital rings) ─
  Map<int, double> get _dayTaskProgress {
    final result = <int, double>{};
    for (final entry in _monthTasks.entries) {
      if (entry.value.isNotEmpty) {
        final total = entry.value.length;
        final completed = entry.value.where((t) => t.isCompleted).length;
        result[entry.key] = completed / total;
      }
    }
    return result;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String get _monthLabel => DateFormat('MMMM,yyyy').format(_currentMonth);

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _currentMonth.year == now.year && _currentMonth.month == now.month;
  }

  List<CalendarTask> get _selectedDayTasks {
    _initMonthTasks();
    return _monthTasks[_selectedDay] ?? const [];
  }

  // ── Month navigation ───────────────────────────────────────────────────────
  void _previousMonth() {
    HapticFeedback.selectionClick();
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
      _initMonthTasks();
      // Auto-select today if we're back on the current month
      _selectedDay = _isCurrentMonth ? DateTime.now().day : 1;
    });
  }

  void _nextMonth() {
    HapticFeedback.selectionClick();
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
      _initMonthTasks();
      _selectedDay = _isCurrentMonth ? DateTime.now().day : 1;
    });
  }

  // ── Task toggle ────────────────────────────────────────────────────────────
  void _toggleTask(String taskId) {
    bool allComplete = false;
    final tasksProvider = Provider.of<TasksProvider>(context, listen: false);
    final selectedDate =
        DateTime(_currentMonth.year, _currentMonth.month, _selectedDay);
    tasksProvider.toggleTaskCompletionOnDate(taskId, selectedDate);

    setState(() {
      _initMonthTasks();
      final tasks = _monthTasks[_selectedDay];
      allComplete = tasks != null &&
          tasks.isNotEmpty &&
          tasks.every((t) => t.isCompleted);
    });

    if (allComplete) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) _triggerCelebration();
      });
    }
  }

  // ── Task dismiss (swipe-to-delete) ────────────────────────────────────────
  Future<void> _removeTask(String taskId) async {
    final tasksProvider = Provider.of<TasksProvider>(context, listen: false);
    final parts = taskId.split('_');
    final String baseId = (parts.length >= 3 && parts[0] == 'task')
        ? '${parts[0]}_${parts[1]}'
        : ((parts.length >= 2 && parts[0] != 'task') ? parts[0] : taskId);

    final taskItem = tasksProvider.tasks.firstWhere(
      (t) => t.id == taskId || t.id == baseId || taskId.startsWith(t.id),
      orElse: () => TaskItem(
        id: baseId,
        title: '',
        dueDate: DateTime.now(),
        priority: 'low',
        isRecurring: true,
      ),
    );

    final bool isRecurring = taskItem.isRecurring ||
        taskItem.recurrence != null ||
        taskItem.repeatRule != RepeatRule.none;
    final DateTime selectedDate =
        DateTime(_currentMonth.year, _currentMonth.month, _selectedDay);
    final option = await showDeleteTaskDialog(
      context,
      isRecurring: isRecurring,
    );

    if (option == 'today') {
      await tasksProvider.deleteTaskOccurrence(baseId, selectedDate);
    } else if (option == 'forever') {
      await tasksProvider.deleteTask(baseId);
    }

    if (mounted) {
      setState(() {
        _initMonthTasks();
      });
    }
  }

  // ── Celebration particle burst ─────────────────────────────────────────────
  void _triggerCelebration() {
    HapticFeedback.heavyImpact();

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => CelebrationOverlay(
        message: '🎉 All tasks are done!',
        onDone: () {
          entry.remove();
          _overlayEntries.remove(entry);
        },
      ),
    );

    _overlayEntries.add(entry);
    Overlay.of(context).insert(entry);
  }

  // ── Add Task — TaskEditorScreen ──────────────────────────────────────────
  void _showAddTaskSheet() async {
    HapticFeedback.lightImpact();
    await Navigator.push(
      context,
      buildPageRoute(
        TaskEditorScreen(
          initialDate: DateTime(
            _currentMonth.year,
            _currentMonth.month,
            _selectedDay,
          ),
        ),
      ),
    );
    if (mounted) {
      setState(() {
        _initMonthTasks();
      });
    }
  }

  void _editTask(String taskId) {
    final tasksProvider = Provider.of<TasksProvider>(context, listen: false);
    final taskItem = tasksProvider.tasks.firstWhere(
      (t) => t.id == taskId,
      orElse: () => tasksProvider.tasks.firstWhere(
        (t) => t.id.startsWith(taskId),
        orElse: () => TaskItem(
          id: taskId,
          title: '',
          dueDate: DateTime.now(),
          priority: 'low',
        ),
      ),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateTaskBottomSheet(
        initialDate: taskItem.dueDate,
        taskToEdit: taskItem,
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          _initMonthTasks();
        });
      }
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    Provider.of<TasksProvider>(context);
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── 1. Header Row (floating on stone background) ──────────────────
            Center(
              child: SizedBox(
                width: screenWidth.clamp(0.0, 402.0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 12.0,
                  ),
                  child: Row(
                    children: [
                      // ─ Back / home-tab button ─────────────────────────────────
                      BottomBarGlassSurface(
                        width: 44.0,
                        height: 44.0,
                        borderRadius: BorderRadius.circular(22.0),
                        child: TactileButton(
                          useAppleSpring: true,
                          compressionScale: 0.7,
                          settleDuration: const Duration(milliseconds: 1000),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            if (widget.onBack != null) {
                              widget.onBack!();
                            } else {
                              Navigator.of(context).pop();
                            }
                          },
                          child: Center(
                            child: SvgPicture.asset(
                              'assets/icons/angle_left.svg',
                              width: 22,
                              height: 22,
                              colorFilter: const ColorFilter.mode(
                                Color(0xFF1C1C1E),
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // ─ MonthContainer pill ──────────────────────────────────
                      Expanded(
                        child: Center(
                          child: MonthContainer(
                            label: _monthLabel,
                            onPrevious: _previousMonth,
                            onNext: _nextMonth,
                          ),
                        ),
                      ),

                      // ─ Search button ───────────────────────────────────────────
                      BottomBarGlassSurface(
                        width: 44.0,
                        height: 44.0,
                        borderRadius: BorderRadius.circular(22.0),
                        child: TactileButton(
                          useAppleSpring: true,
                          compressionScale: 0.7,
                          settleDuration: const Duration(milliseconds: 1000),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.of(context)
                                .push(buildSearchTransitionRoute(
                              builder: (_) => const SearchScreen(
                                initialScope: 'tasks',
                              ),
                            ));
                          },
                          child: const Center(
                            child: Icon(
                              Icons.search_rounded,
                              color: Color(0xFF1C1C1E),
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── 2. Calendar Grid (sitting on background) ──────────────────────
            Center(
              child: SizedBox(
                width: screenWidth.clamp(0.0, 402.0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 8.0,
                  ),
                  child: CalendarGridWidget(
                    currentMonth: _currentMonth,
                    taskProgress: _dayTaskProgress,
                    selectedDay: _selectedDay,
                    onDayTap: (day) => setState(() => _selectedDay = day),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12.0),

            // ── 3. White Bottom Sheet Panel (ONLY wrapping Tasks Preview!) ────
            Expanded(
              child: Center(
                child: Container(
                  width: screenWidth.clamp(0.0, 402.0),
                  decoration: const ShapeDecoration(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    shadows: [
                      BoxShadow(
                        color: Color(0x1F000000),
                        blurRadius: 20,
                        offset: Offset(0, -4),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                    child: TaskWidgetsContainer(
                      selectedDate: DateTime(
                        _currentMonth.year,
                        _currentMonth.month,
                        _selectedDay,
                      ),
                      tasks: _selectedDayTasks,
                      onToggleTask: _toggleTask,
                      onDismissTask: _removeTask,
                      onTapTask: _editTask,
                      onAddTask: _showAddTaskSheet,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
