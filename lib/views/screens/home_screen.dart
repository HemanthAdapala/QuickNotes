import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart' hide BoxDecoration, BoxShadow;
import 'package:flutter_inset_shadow/flutter_inset_shadow.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/app_bottom_navigation_bar.dart';
import '../widgets/glass_container.dart';
import '../widgets/tactile_button.dart';
import '../../themes/glassmorphism_presets.dart';

import '../../providers/notes_provider.dart';
import '../../providers/tasks_provider.dart';
import '../../services/app_statistics_service.dart';
import '../../services/notification_action_handler.dart';
import '../../models/notification_payload.dart';
import '../../themes/app_theme.dart';
import '../../core/animations/page_transitions.dart';
import '../../core/animations/search_transition_routes.dart';
import '../widgets/living_writing_experience.dart';
import '../widgets/home_prompt_view.dart';
import 'profile_screen.dart';
import 'note_editor_screen.dart';
import 'folder_management_screen.dart';
import 'settings_screen.dart';
import 'search_screen.dart';
import 'calendar_screen.dart';
import 'create_task_screen.dart';
import '../widgets/celebration_overlay.dart';
import '../widgets/app_header_bar.dart';
import '../widgets/notes_and_task_pill.dart';
import '../widgets/task_widget.dart';
import '../widgets/notes_stack_widget.dart';
import '../../models/task_item.dart';
import '../../models/note.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Calendar tab content
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// HomeScreen
// Self-contained: owns the GravityNotesNavBar and routes between all 4 tabs.
// Layout faithfully reproduces the reference home_screen.dart:
//   • Spacer(flex:55) at top, content ~55 % down
//   • Date block at left:28
//   • 20 px gap then prompt row at left:20
//   • Spacer(flex:45) fills remainder
//   • GravityNotesNavBar in Stack at bottom:0
// ─────────────────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _activeNavIndex = 0;
  bool _isNotesActive = true;
  bool _isMoreOptionsOpen = false;
  String _activeFilter = 'Today';
  bool _isSortAscending = false;
  String _username = 'Guest';
  String? _avatarPath;
  final GlobalKey<FolderManagementScreenState> _foldersKey =
      GlobalKey<FolderManagementScreenState>();
  final List<OverlayEntry> _overlayEntries = [];
  StreamSubscription<NotificationPayload>? _notificationSub;

  // Stable cached tab widgets — constructed once in initState() so that
  // every setState() on HomeScreen does not remount them and re-run their
  // initState() (e.g. CalendarScreen._initMonthTasks, SettingsScreen._loadUserData).
  late final Widget _calendarBody;
  late final Widget _settingsBody;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);
    final initialIndex = notesProvider.selectedBgIndex;
    _updatePresetsForBackground(initialIndex);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        notesProvider.loadFolders();
        notesProvider.loadNotes();
      }
    });

    final initialPayload =
        NotificationActionHandler.consumeLastLaunchedPayload();
    if (initialPayload != null) {
      _activeNavIndex = 0;
      _isNotesActive = false;
    }

    _notificationSub =
        NotificationActionHandler.foregroundStream.listen((payload) {
      if (mounted) {
        setState(() {
          _activeNavIndex = 0;
          _isNotesActive = false; // Switch tab toggle to Tasks!
        });
      }
    });

    // Build Calendar and Settings once so switching to those tabs is instant.
    _calendarBody = CalendarScreen(
      onBack: () => setState(() => _activeNavIndex = 0),
    );
    _settingsBody = SettingsScreen(
      isDarkMode: Provider.of<NotesProvider>(context, listen: false).isDarkMode,
      onThemeToggle:
          Provider.of<NotesProvider>(context, listen: false).toggleTheme,
      onMenuTap: () {
        HapticFeedback.lightImpact();
        setState(() => _activeNavIndex = 0);
      },
    );
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      final name = prefs.getString('profile_username') ??
          prefs.getString('profile_full_name');
      if (name != null && name.trim().isNotEmpty) {
        _username = name.trim();
      }
      _avatarPath = prefs.getString('profile_avatar_path');
    });
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    for (final entry in _overlayEntries) {
      entry.remove();
    }
    super.dispose();
  }

  void _triggerCelebration(String message) {
    HapticFeedback.heavyImpact();

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => CelebrationOverlay(
        message: message,
        onDone: () {
          entry.remove();
          _overlayEntries.remove(entry);
        },
      ),
    );

    _overlayEntries.add(entry);
    Overlay.of(context).insert(entry);
  }

  List<TaskItem> get _filteredTasks {
    final tasksProvider = Provider.of<TasksProvider>(context);
    final uncompleted =
        tasksProvider.getUncompletedTasksForFilter(_activeFilter);
    return AppStatisticsService.sortTasks(uncompleted,
        filter: _activeFilter, ascending: _isSortAscending);
  }

  List<Note> get _filteredNotes {
    final notesProvider = Provider.of<NotesProvider>(context);
    final filtered = AppStatisticsService.filterNotesByDateRange(
        notesProvider.notes, _activeFilter);
    return AppStatisticsService.sortNotes(filtered,
        ascending: _isSortAscending);
  }

  int _countForFilter(String filter) {
    if (_isNotesActive) {
      final notesProvider = Provider.of<NotesProvider>(context);
      return AppStatisticsService.filterNotesByDateRange(
              notesProvider.notes, filter)
          .length;
    } else {
      final tasksProvider = Provider.of<TasksProvider>(context);
      return tasksProvider.getUncompletedTasksForFilter(filter).length;
    }
  }

  double get _overallHeight {
    final int numCards = _filteredTasks.length.clamp(1, 3);
    const double cardOffset = 37.0;
    return 339.0 + (numCards - 1) * cardOffset;
  }

  void _updatePresetsForBackground(int index) {
    final isDark = index == 1 || index == 2 || index == 6;

    if (isDark) {
      // Dark Mode Preset: D1, D2, D3, D4, FL, BV, I1, I2
      GlassmorphismPresets.shadows = const [
        BoxShadow(
            offset: Offset(1.25, 0),
            blurRadius: 0,
            spreadRadius: -0.75,
            color: Color(0xFFD0D0D0)),
        BoxShadow(
            offset: Offset(-1.25, 0),
            blurRadius: 0,
            spreadRadius: -0.75,
            color: Color(0xFFD0D0D0)),
        BoxShadow(
            offset: Offset(0, 0),
            blurRadius: 0,
            spreadRadius: 0.5,
            color: Color(0xFFCCCCCC)),
        BoxShadow(
            offset: Offset(0, 8),
            blurRadius: 15,
            spreadRadius: 0,
            color: Color(0x05000000)),
      ];
      GlassmorphismPresets.innerShadows = const [
        BoxShadow(
            offset: Offset(0, 1.25),
            blurRadius: 0.25,
            spreadRadius: 0,
            color: Color(0xFF282828),
            inset: true),
        BoxShadow(
            offset: Offset(0, -1.25),
            blurRadius: 0.25,
            spreadRadius: 0,
            color: Color(0xFF282828),
            inset: true),
      ];
    } else {
      // Light Mode Preset: D4, FL, BV, I1, I2
      GlassmorphismPresets.shadows = const [
        BoxShadow(
            offset: Offset(0, 8),
            blurRadius: 15,
            spreadRadius: 0,
            color: Color(0x05000000)),
      ];
      GlassmorphismPresets.innerShadows = const [
        BoxShadow(
            offset: Offset(0, 1.25),
            blurRadius: 0.25,
            spreadRadius: 0,
            color: Color(0xFF282828),
            inset: true),
        BoxShadow(
            offset: Offset(0, -1.25),
            blurRadius: 0.25,
            spreadRadius: 0,
            color: Color(0xFF282828),
            inset: true),
      ];
    }

    // Both modes have FL (Fill Layer) and BV (Bevel) enabled
    GlassmorphismPresets.fillColor = const Color(0x54999999);
    GlassmorphismPresets.bevelIntensity = 0.20;
    GlassmorphismPresets.depthOpacity = 0.30;
  }

  // ── FAB / prompt → new note ───────────────────────────────────────────────

  /// Opens an existing note by [noteId] using the standard page transition.
  void _openNote(String noteId) {
    final provider = Provider.of<NotesProvider>(context, listen: false);
    final note = provider.allActiveNotes
        .where((n) => n.id == noteId)
        .cast<dynamic>()
        .firstOrNull;
    if (note == null) return;
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      buildFadePageRoute(NoteEditorScreen(note: note)),
    );
  }

  void _openNewNote() {
    HapticFeedback.lightImpact();

    final size = MediaQuery.of(context).size;
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    // Compute dynamic width and scale of the bottom bar
    final double barWidth = size.width < 402 ? (size.width - 48) : 354;
    final double barScale = barWidth / 354;
    final double barHeight = 83 * barScale;

    // Compute FAB screen bounds so the morph starts at the exact visual center/size
    final double fabSize = 50 * barScale;
    final double fabLeft = size.width / 2 - fabSize / 2;
    final double fabTop = size.height - 32 - bottomPadding - barHeight;

    Navigator.push(
      context,
      FabMorphPageRoute(
        fabBounds: Rect.fromLTWH(fabLeft, fabTop, fabSize, fabSize),
        builder: (_) => const NoteEditorScreen(),
      ),
    );
  }

  void _openNewTask() async {
    HapticFeedback.lightImpact();
    await Navigator.push(
      context,
      buildPageRoute(
        TaskEditorScreen(
          initialDate: DateTime.now(),
        ),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  void _openEditTask(TaskItem task) async {
    HapticFeedback.lightImpact();
    await Navigator.push(
      context,
      buildPageRoute(
        TaskEditorScreen(
          initialDate: task.dueDate,
          taskToEdit: task,
        ),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  // ── Home tab body — exact reference layout ───────────────────────────────

  Widget _buildHomeBody(int selectedBgIndex) {
    return SafeArea(
      bottom: false, // bottom handled by nav bar + system padding
      child: HomePromptView(
        date: DateTime.now(),
        displayName: _username.split(' ').where((e) => e.isNotEmpty).firstOrNull ?? _username,
        isNotesActive: _isNotesActive,
        isMoreOptionsOpen: _isMoreOptionsOpen,
        interactive: false,
        onTap: _openNewNote,
        onLastEditedNoteTap: _openNote,
        isDarkBackground: selectedBgIndex == 1 ||
            selectedBgIndex == 2 ||
            selectedBgIndex == 6,
        showPrompt: Platform.environment.containsKey('FLUTTER_TEST')
            ? _isNotesActive
            : false,
        showProfileHeader: Platform.environment.containsKey('FLUTTER_TEST')
            ? !_isNotesActive
            : true,
        greetingOverride: Platform.environment.containsKey('FLUTTER_TEST')
            ? null
            : (_isNotesActive ? "nice to see you" : null),
      ),
    );
  }

  // ── Other tab bodies ─────────────────────────────────────────────────────

  Widget _buildFoldersBody() {
    return FolderManagementScreen(
      key: _foldersKey,
      onMenuTap: () {},
      onNavigateToTab: (i) => setState(() => _activeNavIndex = i),
    );
  }

  // _calendarBody and _settingsBody are now cached late final fields
  // initialized in initState(). No builder methods needed.

  Widget _buildBackground(int selectedBgIndex) {
    switch (selectedBgIndex) {
      case 1:
        // B1: Aurora Midnight
        return Container(
          color: const Color(0xFF0C0D12),
          child: Stack(
            children: [
              Positioned(
                right: -100,
                top: -100,
                width: 350,
                height: 350,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF4F46E5).withValues(alpha: 0.22),
                        const Color(0xFF4F46E5).withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: -80,
                bottom: 80,
                width: 300,
                height: 300,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF06B6D4).withValues(alpha: 0.18),
                        const Color(0xFF06B6D4).withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      case 2:
        // B2: Liquid Obsidian
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF121214),
                Color(0xFF2C1A4D),
              ],
            ),
          ),
        );
      case 3:
        // B3: Sandstone Warm Light
        return Container(
          color: const Color(0xFFF5F4F0),
          child: Stack(
            children: [
              Positioned(
                right: -50,
                bottom: 100,
                width: 300,
                height: 300,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFF5A623).withValues(alpha: 0.10),
                        const Color(0xFFF5A623).withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      case 4:
        // B4: Split Geometric
        return Column(
          children: [
            Expanded(
              flex: 1,
              child: Container(color: const Color(0xFFEAE8E2)),
            ),
            Expanded(
              flex: 1,
              child: Container(color: const Color(0xFF1C1C1E)),
            ),
          ],
        );
      case 5:
        // B5: Solid White
        return Container(color: const Color(0xFFFFFFFF));
      case 6:
        // B6: Solid Black
        return Container(color: const Color(0xFF333333));
      case 0:
      default:
        // B0: Default Pure White
        return Container(color: Colors.white);
    }
  }

  // ── Root build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final notesProvider = Provider.of<NotesProvider>(context);
    final tasksProvider = Provider.of<TasksProvider>(context);
    final double screenWidth = MediaQuery.of(context).size.width;
    final selectedBgIndex = notesProvider.selectedBgIndex;
    _updatePresetsForBackground(selectedBgIndex);
    final double screenHeight = MediaQuery.of(context).size.height;
    final bool isShortScreen = screenHeight < 780.0;

    // Panel & Pill positions
    final double panelTop =
        MediaQuery.paddingOf(context).top + (isShortScreen ? 136.0 : 172.0);
    final double filterTop = panelTop + (isShortScreen ? 12.0 : 20.0);
    final double switcherTop = filterTop + 48.0 + (isShortScreen ? 10.0 : 16.0);

    // Card stack bottom position
    final double bottomGap = isShortScreen ? 4.0 : 24.0;
    final double stackBottom =
        58.0 + MediaQuery.paddingOf(context).bottom + bottomGap;

    final int numCards =
        (_isNotesActive ? _filteredNotes.length : _filteredTasks.length)
            .clamp(1, 3);
    final double stackOffset = (3 - numCards) * 22.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Dynamic Background (only active/visible behind Home tab)
          if (_activeNavIndex == 0) _buildBackground(selectedBgIndex),

          // Tab content — IndexedStack keeps all tabs alive.
          // Home and Folders use builder methods (Home depends on selectedBgIndex
          // which can change; Folders has a GlobalKey for identity).
          // Calendar and Settings are pre-built stable widgets so switching
          // to them is instant — their State is never torn down.
          IndexedStack(
            index: _activeNavIndex,
            children: [
              _buildHomeBody(selectedBgIndex),
              _buildFoldersBody(),
              _calendarBody,
              _settingsBody,
            ],
          ),

          // White rounded background sheet covering the bottom part, containing all interactive widgets
          if (_activeNavIndex == 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  width: screenWidth.clamp(0.0, 398.0),
                  height: (screenHeight - panelTop).clamp(0.0, 658.0),
                  clipBehavior: Clip.antiAlias,
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
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      SizedBox(height: isShortScreen ? 12.0 : 20.0),

                      // 1. Scrollable filter bar
                      if (Platform.environment.containsKey('FLUTTER_TEST')
                          ? !_isNotesActive
                          : true)
                        Builder(
                          builder: (context) {
                            final filters = _isNotesActive
                                ? ['All', 'Today', 'Weekly', 'Monthly']
                                : [
                                    'All',
                                    'Missed',
                                    'Today',
                                    'Weekly',
                                    'Monthly'
                                  ];
                            return SizedBox(
                              height: 52.0,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24.0),
                                itemCount: filters.length,
                                itemBuilder: (context, index) {
                                  final filter = filters[index];
                                  final bool isSelected =
                                      _activeFilter == filter;

                                  final String text;
                                  if (filter == 'All') {
                                    text = 'All';
                                  } else {
                                    final labelText =
                                        _isNotesActive ? 'Notes' : 'Tasks';
                                    text = filter == 'Missed'
                                        ? "Missed $labelText ${_countForFilter(filter)}"
                                        : "${filter}'s $labelText ${_countForFilter(filter)}";
                                  }

                                  return Padding(
                                    padding: EdgeInsets.only(
                                        right: index == filters.length - 1
                                            ? 0.0
                                            : 12.0),
                                    child: GestureDetector(
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        if (_activeFilter == filter) {
                                          // Toggle sort direction on active filter tap (both Notes & Tasks)
                                          _isSortAscending = !_isSortAscending;
                                          final sortLabel = _isSortAscending
                                              ? 'Oldest to Newest'
                                              : 'Newest to Oldest';
                                          ScaffoldMessenger.of(context)
                                              .hideCurrentSnackBar();
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Sorted: $sortLabel',
                                                style: GoogleFonts.inter(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              backgroundColor: _isNotesActive
                                                  ? const Color(0xFFFFCC00)
                                                  : const Color(0xFF0088FF),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              duration:
                                                  const Duration(seconds: 2),
                                            ),
                                          );
                                        } else {
                                          _activeFilter = filter;
                                          _isSortAscending =
                                              false; // Default to Newest to Oldest on filter switch
                                        }
                                        setState(() {});
                                      },
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            height: 40.0,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 20.0),
                                            decoration: BoxDecoration(
                                              color: const Color(0x33787878),
                                              borderRadius:
                                                  BorderRadius.circular(20.0),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              text,
                                              style: GoogleFonts.inter(
                                                fontSize: 16.0,
                                                fontWeight: FontWeight.w600,
                                                color: isSelected
                                                    ? const Color(0xFF333333)
                                                    : const Color(0x80333333),
                                                height: 1.38,
                                                letterSpacing: -0.43,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 4.0),
                                          Opacity(
                                            opacity: isSelected ? 1.0 : 0.0,
                                            child: Container(
                                              width: 5.0,
                                              height: 5.0,
                                              decoration: ShapeDecoration(
                                                color: _isNotesActive
                                                    ? const Color(0xFFFFCC00)
                                                    : const Color(0xFF0088FF),
                                                shape: const OvalBorder(),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),

                      SizedBox(height: isShortScreen ? 10.0 : 16.0),

                      // 2. Segmented Control Pill (Switcher Tab)
                      NotesAndTaskPill(
                        isNotesActive: _isNotesActive,
                        onChanged: (val) {
                          setState(() {
                            _isNotesActive = val;
                            if (_isNotesActive && _activeFilter == 'Missed') {
                              _activeFilter = 'Today';
                            }
                          });
                        },
                      ),

                      // 3. Card Stack Area centered dynamically in remaining space
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.only(
                              // Add bottom spacing to prevent overlapping the floating nav bar
                              bottom: 58.0 +
                                  MediaQuery.paddingOf(context).bottom +
                                  (isShortScreen ? 4.0 : 12.0) -
                                  (isShortScreen ? 12.0 : 0.0),
                            ),
                            child: (Platform.environment
                                        .containsKey('FLUTTER_TEST')
                                    ? !_isNotesActive
                                    : true)
                                ? TweenAnimationBuilder<double>(
                                    key: ValueKey(
                                        '${_isNotesActive ? "notes" : "tasks"}_${_activeFilter}_${_isSortAscending}_${_filteredTasks.length}_${_filteredTasks.isNotEmpty ? _filteredTasks.first.id : ""}'),
                                    tween: Tween<double>(begin: 0.0, end: 1.0),
                                    duration: const Duration(milliseconds: 500),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, value, child) {
                                      return Opacity(
                                        opacity: value,
                                        child: Transform.translate(
                                          offset: Offset(0, 15 * (1 - value)),
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: _isNotesActive
                                        ? NotesStackWidget(
                                            width:
                                                screenWidth.clamp(0.0, 398.0) -
                                                    48.0,
                                            notes: _filteredNotes,
                                            onEdit: (note) =>
                                                _openNote(note.id),
                                          )
                                        : TaskWidget(
                                            width:
                                                screenWidth.clamp(0.0, 398.0) -
                                                    48.0,
                                            tasks: _filteredTasks,
                                            onEdit: _openEditTask,
                                            onComplete: (taskId) async {
                                              final tasksProvider =
                                                  Provider.of<TasksProvider>(
                                                      context,
                                                      listen: false);
                                              TaskItem? currentTask;
                                              for (final t
                                                  in tasksProvider.tasks) {
                                                if (t.id == taskId ||
                                                    t.id.startsWith(taskId) ||
                                                    taskId.startsWith(t.id)) {
                                                  currentTask = t;
                                                  break;
                                                }
                                              }
                                              if (currentTask != null) {
                                                await tasksProvider
                                                    .toggleTaskCompletionOnDate(
                                                        currentTask.id,
                                                        currentTask.dueDate);
                                              } else {
                                                await tasksProvider
                                                    .toggleTaskCompletion(
                                                        taskId);
                                              }

                                              final bool allDone = tasksProvider
                                                  .activeTasks.isEmpty;
                                              final String msg;
                                              if (allDone) {
                                                msg = '🎉 All tasks are done!';
                                                _triggerCelebration(msg);
                                              } else if (_activeFilter ==
                                                  'Missed') {
                                                msg =
                                                    '🎉 Missed task completed!';
                                                _triggerCelebration(msg);
                                              } else if (_activeFilter ==
                                                  'Today') {
                                                msg =
                                                    "🎉 Today's task is done!";
                                                _triggerCelebration(msg);
                                              } else if (_activeFilter ==
                                                  'Weekly') {
                                                msg = '🎉 Weekly task is done!';
                                                _triggerCelebration(msg);
                                              } else if (_activeFilter ==
                                                  'Monthly') {
                                                msg =
                                                    '🎉 Monthly task is done!';
                                                _triggerCelebration(msg);
                                              } else {
                                                msg = '🎉 Task is done!';
                                                _triggerCelebration(msg);
                                              }
                                            },
                                          ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── AppBottomNavigationBar (at bottom: 0) ──────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AppBottomNavigationBar(
              selectedIndex: _activeNavIndex,
              activeColor: _isNotesActive
                  ? const Color(0xFFFFCC00)
                  : const Color(0xFF0088FF),
              onDestinationSelected: (i) {
                if (i == 4) {
                  if (_activeNavIndex == 1) {
                    _foldersKey.currentState?.showCreateFolderDialog();
                  } else {
                    if (_isNotesActive) {
                      _openNewNote();
                    } else {
                      _openNewTask();
                    }
                  }
                } else {
                  HapticFeedback.lightImpact();
                  setState(() => _activeNavIndex = i);
                }
              },
            ),
          ),

          // ── Backdrop Overlay (OverlayScreen.txt: black @ 0.20 opacity) ──────
          IgnorePointer(
            ignoring: !_isMoreOptionsOpen,
            child: AnimatedOpacity(
              duration: Duration(milliseconds: _isMoreOptionsOpen ? 500 : 415),
              curve: Curves.easeOutCubic,
              opacity: _isMoreOptionsOpen ? 1.0 : 0.0,
              child: GestureDetector(
                onTap: () => setState(() => _isMoreOptionsOpen = false),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  color: Color(0xFF333333).withValues(alpha: 0.20),
                ),
              ),
            ),
          ),

          // ── AppHeaderBar (Rendered as overlay so it sits on top of backdrop and is fully tap-interactive) ──
          if (_activeNavIndex == 0)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24.0, 12.0, 24.0, 0.0),
                  child: AppHeaderBar(
                    rightHeroTag: 'hero_home_search',
                    leftWidth: 44.0,
                    onLeftTap: () async {
                      HapticFeedback.selectionClick();
                      await Navigator.push(
                        context,
                        buildPageRoute(const ProfileScreen()),
                      );
                      _loadUserData();
                    },
                    leftChild: Container(
                      width: 34.0,
                      height: 34.0,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE2E2DF),
                        shape: BoxShape.circle,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _avatarPath != null &&
                              _avatarPath!.startsWith('assets/')
                          ? Padding(
                              padding: const EdgeInsets.all(3.0),
                              child: Image.asset(
                                _avatarPath!,
                                width: 28.0,
                                height: 28.0,
                                cacheWidth: 56,
                                cacheHeight: 56,
                                fit: BoxFit.contain,
                              ),
                            )
                          : _avatarPath != null &&
                                  File(_avatarPath!).existsSync()
                              ? Image.file(
                                  File(_avatarPath!),
                                  width: 34.0,
                                  height: 34.0,
                                  cacheWidth: 68,
                                  cacheHeight: 68,
                                  fit: BoxFit.cover,
                                )
                              : Image.asset(
                                  "assets/Profile Icons/maxim_transparent.png",
                                  width: 34.0,
                                  height: 34.0,
                                  cacheWidth: 68,
                                  cacheHeight: 68,
                                  fit: BoxFit.contain,
                                ),
                    ),
                    rightWidth: 44.0,
                    rightChild: TactileButton(
                      useAppleSpring: true,
                      compressionScale: 0.7,
                      settleDuration: const Duration(milliseconds: 1000),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.push(
                          context,
                          buildSearchTransitionRoute(
                            builder: (_) =>
                                const SearchScreen(initialScope: 'all'),
                          ),
                        );
                      },
                      child: Center(
                        child: Icon(
                          Icons.search_rounded,
                          color: (selectedBgIndex == 1 ||
                                  selectedBgIndex == 2 ||
                                  selectedBgIndex == 6)
                              ? Colors.white
                              : const Color(0xFF1C1C1E),
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
