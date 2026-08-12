import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/note.dart';
import '../../models/folder.dart';
import '../../providers/notes_provider.dart';
import '../../themes/app_theme.dart';
import '../widgets/tactile_button.dart';
import '../widgets/app_header_bar.dart';
import 'note_editor_screen.dart';
import 'create_task_screen.dart';
import '../../core/animations/page_transitions.dart';
import 'search_screen.dart';
import '../../core/animations/search_transition_routes.dart';
import '../../core/animations/dialog_transition.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Selected Date Gradient Ring Painter
// ─────────────────────────────────────────────────────────────────────────────
class GradientBorderPainter extends CustomPainter {
  final double strokeWidth;
  final Gradient gradient;

  GradientBorderPainter({
    required this.strokeWidth,
    required this.gradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..shader = gradient.createShader(rect);

    // Draw circular border
    canvas.drawCircle(
      size.center(Offset.zero),
      (size.width / 2) - (strokeWidth / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant GradientBorderPainter oldDelegate) {
    return oldDelegate.strokeWidth != strokeWidth || oldDelegate.gradient != gradient;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NoteCalendarScreen
// ─────────────────────────────────────────────────────────────────────────────
class NoteCalendarScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateToTab;

  const NoteCalendarScreen({
    super.key,
    required this.onNavigateToTab,
  });

  @override
  State<NoteCalendarScreen> createState() => _NoteCalendarScreenState();
}

class _NoteCalendarScreenState extends State<NoteCalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _currentMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
  }

  // Helper: check if two dates fall on the same day
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // Helper: get color coding for task card left strip
  Color _getLeftStripColor(String type) {
    switch (type) {
      case 'pink':
        return const Color(0xFFF187C1);
      case 'yellow':
        return const Color(0xFFF9D423);
      case 'blue':
        return const Color(0xFF57B0E2);
      default:
        return const Color(0xFF6AB27B);
    }
  }

  // Helper: get card background color
  Color _getCardBgColor(String type) {
    switch (type) {
      case 'pink':
        return const Color(0xFFFDF8F9);
      case 'yellow':
        return const Color(0xFFFFFBF0);
      case 'blue':
        return const Color(0xFFF4FAFF);
      default:
        return const Color(0xFFF5F9F6);
    }
  }

  // Show dropdown menu to change month
  void _showMonthPicker(BuildContext context) {
    final List<DateTime> months = List.generate(
      12,
      (index) => DateTime(2026, index + 1),
    );

    showAnimatedDialog<DateTime>(
      context: context,
      child: AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          "Select Month",
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1C1C1E),
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.8,
            ),
            itemCount: months.length,
            itemBuilder: (context, index) {
              final monthDate = months[index];
              final label = DateFormat('MMM').format(monthDate);
              final isCurrent = _currentMonth.month == monthDate.month;
              return InkWell(
                onTap: () {
                  Navigator.pop(context, monthDate);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: isCurrent ? const Color(0xFF222222) : const Color(0xFFE6E3D2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      color: isCurrent ? Colors.white : const Color(0xFF1C1C1E),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ).then((selected) {
      if (selected != null) {
        setState(() {
          _currentMonth = DateTime(2026, selected.month);
          // Auto-select the 1st of the month (or 15th if it's June)
          _selectedDate = DateTime(2026, selected.month, selected.month == 6 ? 15 : 1);
        });
      }
    });
  }

  // Route to the new high-fidelity task creation screen
  void _showAddTaskSheet() {
    Navigator.push(
      context,
      buildPageRoute(CreateTaskScreen(initialDate: _selectedDate)),
    );
  }

  // Render individual day cell in grid
  Widget _buildDayCell(int dayNumber, bool isDifferentMonth, Color dotColor, bool isSelected) {
    final bool isToday = _isSameDay(DateTime.now(), DateTime(_currentMonth.year, _currentMonth.month, dayNumber));

    Widget content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "$dayNumber",
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : (isToday ? FontWeight.w700 : FontWeight.normal),
            color: isDifferentMonth ? AppColors.ink.withOpacity(0.3) : AppColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dotColor,
          ),
        ),
      ],
    );

    if (isSelected) {
      return Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Colors.white.withOpacity(0.8),
              Colors.white.withOpacity(0.0),
            ],
            stops: const [0.0, 1.0],
          ),
        ),
        child: CustomPaint(
          size: const Size(32, 32),
          painter: GradientBorderPainter(
            strokeWidth: 2.0,
            gradient: const LinearGradient(
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
              colors: [
                Color(0xFFF9D423),
                Color(0xFFFF4E50),
                Color(0xFF00C9FF),
              ],
            ),
          ),
          child: Center(child: content),
        ),
      );
    }

    return Center(child: content);
  }

  Widget _buildDot(Color color) {
    return Container(
      width: 4,
      height: 4,
      margin: const EdgeInsets.symmetric(horizontal: 1.0),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<NotesProvider>(context);
    final notes = provider.allActiveNotes;

    // Filter notes for the selected date
    final dayNotes = notes.where((note) {
      return (note.reminderTime != null && _isSameDay(note.reminderTime!, _selectedDate)) ||
          (_isSameDay(note.createdAt, _selectedDate));
    }).toList();

    // Months and dates math
    final int daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final int firstWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday; // 1=Mon, 7=Sun
    final int offset = firstWeekday == 7 ? 0 : firstWeekday; // offset assuming week starts on Sunday

    // Total cells to display in grid (offsets + days)
    final int totalCells = offset + daysInMonth;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
             Padding(
               padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
               child: AppHeaderBar(
                 leftWidth: 44.0,
                 onLeftTap: () {
                   HapticFeedback.lightImpact();
                   widget.onNavigateToTab?.call(0);
                 },
                 leftChild: SvgPicture.asset(
                   'assets/icons/angle_left.svg',
                   width: 22,
                   height: 22,
                   colorFilter: const ColorFilter.mode(Color(0xFF1C1C1E), BlendMode.srcIn),
                 ),
                 title: "Note Calendar",
                 rightWidth: 44.0,
                 rightChild: TactileButton(
                   useAppleSpring: true,
                   compressionScale: 0.7,
                   settleDuration: const Duration(milliseconds: 1000),
                   onTap: () {
                     HapticFeedback.lightImpact();
                     Navigator.of(context).push(buildSearchTransitionRoute(
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
             ),
             const SizedBox(height: 12.0),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 120.0), // space for bottom nav bar
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Note Activity Section Header ────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "NOTE ACTIVITY",
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                              letterSpacing: 1.0,
                            ),
                          ),
                          Text(
                            "${provider.notes.length} total notes".toUpperCase(),
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink.withOpacity(0.5),
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Calendar Month Selector & Grid Card ──────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3EAC0),
                          borderRadius: BorderRadius.circular(24.0),
                          border: Border.all(
                            color: AppColors.ink.withOpacity(0.08),
                            width: 1.0,
                          ),
                        ),
                        child: Column(
                          children: [
                            // Month Header
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.chevron_left_rounded, color: AppColors.ink),
                                    onPressed: () {
                                      setState(() {
                                        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
                                      });
                                    },
                                  ),
                                  GestureDetector(
                                    onTap: () => _showMonthPicker(context),
                                    child: Text(
                                      DateFormat('MMMM yyyy').format(_currentMonth),
                                      style: GoogleFonts.inter(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.chevron_right_rounded, color: AppColors.ink),
                                    onPressed: () {
                                      setState(() {
                                        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),

                            // Days of Week Header Row
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((day) {
                                  return SizedBox(
                                    width: 38,
                                    child: Center(
                                      child: Text(
                                        day.substring(0, 1),
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: AppColors.ink.withOpacity(0.4),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Calendar Grid
                            Padding(
                              padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 20.0),
                              child: GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 7,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  childAspectRatio: 1.0,
                                ),
                                itemCount: totalCells,
                                itemBuilder: (context, index) {
                                  if (index < offset) {
                                    return const SizedBox.shrink();
                                  }
                                  
                                  final int dayNumber = index - offset + 1;
                                  final DateTime cellDate = DateTime(_currentMonth.year, _currentMonth.month, dayNumber);
                                  final bool isToday = cellDate.year == DateTime.now().year &&
                                      cellDate.month == DateTime.now().month &&
                                      cellDate.day == DateTime.now().day;
                                  final bool isSelected = cellDate.year == _selectedDate.year &&
                                      cellDate.month == _selectedDate.month &&
                                      cellDate.day == _selectedDate.day;

                                  // Find notes on this day
                                  final dayNotes = provider.notes.where((note) {
                                    return note.createdAt.year == cellDate.year &&
                                        note.createdAt.month == cellDate.month &&
                                        note.createdAt.day == cellDate.day;
                                  }).toList();

                                  // Check if day has habits/vault/tasks/notes
                                  final hasLocked = dayNotes.any((n) => n.isLocked);
                                  final hasTasks = dayNotes.any((n) => n.title.startsWith("Task:"));
                                  final hasHabits = dayNotes.any((n) => n.isHabit);
                                  final hasStandard = dayNotes.any((n) => !n.isLocked && !n.isHabit && !n.title.startsWith("Task:"));

                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedDate = cellDate;
                                      });
                                    },
                                    child: CustomPaint(
                                      painter: isSelected
                                          ? GradientBorderPainter(
                                              strokeWidth: 2.0,
                                              gradient: const LinearGradient(
                                                begin: Alignment.bottomLeft,
                                                end: Alignment.topRight,
                                                colors: [
                                                  Color(0xFFF9D423),
                                                  Color(0xFFFF4E50),
                                                  Color(0xFF00C9FF),
                                                ],
                                              ),
                                            )
                                          : null,
                                      child: Container(
                                        margin: const EdgeInsets.all(1.0),
                                        decoration: BoxDecoration(
                                          color: isToday
                                              ? const Color(0xFFFCE1B6)
                                              : (isSelected ? Colors.white : Colors.transparent),
                                          borderRadius: BorderRadius.circular(10.0),
                                        ),
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Center(
                                              child: Text(
                                                dayNumber.toString(),
                                                style: GoogleFonts.inter(
                                                  fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.w500,
                                                  color: AppColors.ink,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                            // Tiny dot indicator for notes
                                            if (dayNotes.isNotEmpty)
                                              Positioned(
                                                bottom: 4,
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    if (hasLocked) _buildDot(const Color(0xFF6B685B)),
                                                    if (hasTasks) _buildDot(const Color(0xFFE07A5F)),
                                                    if (hasHabits) _buildDot(const Color(0xFF81B29A)),
                                                    if (hasStandard) _buildDot(const Color(0xFF3D5A80)),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),

                            // Legend Row
                            Padding(
                              padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
                              child: Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: [
                                  _buildLegendItem(const Color(0xFF3D5A80), "Notes"),
                                  _buildLegendItem(const Color(0xFFE07A5F), "Tasks"),
                                  _buildLegendItem(const Color(0xFF81B29A), "Habits"),
                                  _buildLegendItem(const Color(0xFF6B685B), "Locked"),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Tasks Card List ──────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Tasks for ${DateFormat('MMMM d').format(_selectedDate)}",
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.ink,
                            ),
                          ),
                          TactileButton(
                            onTap: _showAddTaskSheet,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                              decoration: BoxDecoration(
                                color: const Color(0xFF222222),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Add Task",
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      if (dayNotes.isEmpty) ...[
                        // Empty State for days with no notes
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32.0),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.assignment_turned_in_outlined,
                                  size: 40,
                                  color: AppColors.ink.withOpacity(0.2),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  "No tasks scheduled for today",
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: AppColors.ink.withOpacity(0.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        // Real notes scheduled for this day
                        ...dayNotes.map((note) {
                          final isTaskChecked = note.isFavorite; // map to favorite or check items completion
                          final priorityType = note.tags.contains('yellow')
                              ? 'yellow'
                              : (note.tags.contains('blue') ? 'blue' : 'pink');

                          // Resolve folder name
                          String folderLabel = "Quick Note";
                          if (note.folderId != null) {
                            final folder = provider.folders.firstWhere(
                              (f) => f.id == note.folderId,
                              orElse: () => Folder(id: '', name: 'Folder', createdAt: DateTime.now()),
                            );
                            if (folder.name.isNotEmpty) {
                              folderLabel = "${folder.name} folder";
                            }
                          }

                          return _buildTaskCard(
                            id: note.id,
                            title: note.title,
                            subtitle: "$folderLabel • ${note.reminderTime != null ? DateFormat('jm').format(note.reminderTime!) : 'All Day'}",
                            type: priorityType,
                            isCompleted: isTaskChecked,
                            onToggle: () {
                              HapticFeedback.lightImpact();
                              provider.updateNote(note.copyWith(isFavorite: !note.isFavorite));
                            },
                            onTap: () {
                              Navigator.push(
                                context,
                                buildPageRoute(NoteEditorScreen(note: note)),
                              );
                            },
                          );
                        }),
                      ],
                    ],
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
    );
  }

  // Legend bullet indicator helper
  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: AppColors.ink.withOpacity(0.7),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  // Reusable Task Card Builder
  Widget _buildTaskCard({
    required String id,
    required String title,
    required String subtitle,
    required String type,
    required bool isCompleted,
    required VoidCallback onToggle,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TactileButton(
        onTap: onTap ?? () {},
        child: Container(
          decoration: BoxDecoration(
            color: _getCardBgColor(type),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.black.withOpacity(0.02),
              width: 1.0,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              Container(
                width: 6,
                height: 72,
                color: _getLeftStripColor(type),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.ink,
                          decoration: isCompleted ? TextDecoration.lineThrough : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.ink.withOpacity(0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: onToggle,
                child: Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.only(right: 16.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted ? const Color(0xFF222222) : Colors.transparent,
                    border: isCompleted
                        ? null
                        : Border.all(
                            color: AppColors.ink.withOpacity(0.2),
                            width: 2.0,
                          ),
                  ),
                  child: isCompleted
                      ? const Center(
                          child: Icon(
                            Icons.check,
                            size: 14,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
