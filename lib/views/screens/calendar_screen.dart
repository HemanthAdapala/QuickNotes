import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../models/calendar_task.dart';
import '../widgets/app_bottom_navigation_bar.dart';
import '../widgets/calendar_grid_widget.dart';
import '../widgets/celebration_overlay.dart';
import '../widgets/month_container.dart';
import '../widgets/tactile_button.dart';
import '../widgets/task_widgets_container.dart';
import '../../core/animations/search_route.dart';
import 'search_screen.dart';

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
  const CalendarScreen({super.key});

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

  // ── Month tasks — pre-generate for all days so the grid is fully populated ─
  void _initMonthTasks() {
    _monthTasks.clear();
    final daysInMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    for (int day = 1; day <= daysInMonth; day++) {
      _monthTasks[day] = _generateMockTasks(day);
    }
  }

  /// Mock task generator — early days start fully completed so the grid looks
  /// like the reference design on first open.
  /// In production: replace with real data from a tasks provider.
  List<CalendarTask> _generateMockTasks(int day) {
    // Days 1–8 come pre-completed → they show a blue check cell immediately.
    final allDone = day <= 8;

    return [
      CalendarTask(
        id: 'task_${day}_green',
        title: 'Task: Finalize Client Call',
        subtitle: 'Work Tasks Folder . Due 5 Pm',
        priority: TaskPriority.green,
        isCompleted: allDone,
      ),
      CalendarTask(
        id: 'task_${day}_yellow',
        title: 'Task: Review Study Guide',
        subtitle: 'Work Tasks Folder . Due 5 Pm',
        priority: TaskPriority.yellow,
        isCompleted: allDone,
      ),
      if (day % 3 == 0)
        CalendarTask(
          id: 'task_${day}_red',
          title: 'Task: Finalize Client Call',
          subtitle: 'Work Tasks Folder . Due 5 Pm',
          priority: TaskPriority.red,
          isCompleted: allDone,
        ),
    ];
  }

  // ── Computed: days where EVERY task is completed (drives blue check cells) ─
  Set<int> get _daysAllComplete {
    final result = <int>{};
    for (final entry in _monthTasks.entries) {
      if (entry.value.isNotEmpty && entry.value.every((t) => t.isCompleted)) {
        result.add(entry.key);
      }
    }
    return result;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String get _monthLabel => DateFormat('MMMM,yyyy').format(_currentMonth);

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _currentMonth.year == now.year &&
        _currentMonth.month == now.month;
  }

  List<CalendarTask> get _selectedDayTasks =>
      _monthTasks[_selectedDay] ?? const [];

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

    setState(() {
      final tasks = _monthTasks[_selectedDay];
      if (tasks == null) return;

      final task = tasks.firstWhere(
        (t) => t.id == taskId,
        orElse: () => throw StateError('Task $taskId not found'),
      );
      task.isCompleted = !task.isCompleted;

      // Check if this toggle completed the LAST pending task
      allComplete =
          tasks.isNotEmpty && tasks.every((t) => t.isCompleted);
    });

    // Only celebrate when the toggle made all tasks complete (not when un-doing)
    if (allComplete) {
      // Small delay so the card animation settles first
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) _triggerCelebration();
      });
    }
  }

  // ── Celebration particle burst ─────────────────────────────────────────────
  void _triggerCelebration() {
    HapticFeedback.heavyImpact();

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => CelebrationOverlay(
        onDone: () {
          entry.remove();
          _overlayEntries.remove(entry);
        },
      ),
    );

    _overlayEntries.add(entry);
    Overlay.of(context).insert(entry);
  }

  // ── Add Task placeholder ───────────────────────────────────────────────────
  void _showAddTaskSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.55,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0x33787878),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Add Task',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const Spacer(),
            const Text(
              'Task creation coming soon',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: Color(0x80000000),
              ),
            ),
            const Spacer(),
            SizedBox(height: MediaQuery.of(ctx).viewPadding.bottom + 16),
          ],
        ),
      ),
    );
  }

  // ── Header glass pill ──────────────────────────────────────────────────────
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

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 12.0,
              ),
              child: Row(
                children: [
                  // Back
                  _buildGlassPill(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop();
                    },
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

                  // Month pill
                  Expanded(
                    child: Center(
                      child: MonthContainer(
                        label: _monthLabel,
                        onPrevious: _previousMonth,
                        onNext: _nextMonth,
                      ),
                    ),
                  ),

                  // Search
                  _buildGlassPill(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).push(SearchRoute(
                        builder: (_) => const SearchScreen(
                          initialScope: 'tasks',
                        ),
                      ));
                    },
                    child: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF1C1C1E),
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),

            // ── Calendar grid (fixed, no scroll) ──────────────────────────
            // Blue check cell = ALL tasks for that day completed.
            // Gray cross cell = pending tasks or no tasks.
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: CalendarGridWidget(
                currentMonth: _currentMonth,
                daysWithTasks: _daysAllComplete, // ← only fully-done days
                selectedDay: _selectedDay,
                onDayTap: (day) => setState(() => _selectedDay = day),
              ),
            ),

            // ── Task panel (Expanded, scrolls internally) ──────────────────
            Expanded(
              child: TaskWidgetsContainer(
                selectedDate: DateTime(
                  _currentMonth.year,
                  _currentMonth.month,
                  _selectedDay,
                ),
                tasks: _selectedDayTasks,
                onToggleTask: _toggleTask,
                onAddTask: _showAddTaskSheet,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
