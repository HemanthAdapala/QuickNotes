import 'dart:io';
import 'package:flutter/material.dart' hide BoxDecoration, BoxShadow;
import 'package:flutter_inset_shadow/flutter_inset_shadow.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/app_bottom_navigation_bar.dart';
import '../widgets/glass_container.dart';
import '../widgets/tactile_button.dart';
import '../../themes/glassmorphism_presets.dart';

import '../../providers/notes_provider.dart';
import '../../themes/app_theme.dart';
import '../../core/animations/page_transitions.dart';
import '../widgets/living_writing_experience.dart';
import '../widgets/home_prompt_view.dart';
import 'note_editor_screen.dart';
import 'folder_management_screen.dart';
import 'settings_screen.dart';
import 'note_calendar_screen.dart';
import 'create_task_screen.dart';
import '../widgets/notes_and_task_pill.dart';
import '../widgets/task_widget.dart';

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

  @override
  void initState() {
    super.initState();
    final initialIndex = Provider.of<NotesProvider>(context, listen: false).selectedBgIndex;
    _updatePresetsForBackground(initialIndex);
  }

  void _updatePresetsForBackground(int index) {
    final isDark = index == 1 || index == 2 || index == 6;

    if (isDark) {
      // Dark Mode Preset: D1, D2, D3, D4, FL, BV, I1, I2
      GlassmorphismPresets.shadows = const [
        BoxShadow(offset: Offset(1.25, 0), blurRadius: 0, spreadRadius: -0.75, color: Color(0xFFD0D0D0)),
        BoxShadow(offset: Offset(-1.25, 0), blurRadius: 0, spreadRadius: -0.75, color: Color(0xFFD0D0D0)),
        BoxShadow(offset: Offset(0, 0), blurRadius: 0, spreadRadius: 0.5, color: Color(0xFFCCCCCC)),
        BoxShadow(offset: Offset(0, 8), blurRadius: 15, spreadRadius: 0, color: Color(0x05000000)),
      ];
      GlassmorphismPresets.innerShadows = const [
        BoxShadow(offset: Offset(0, 1.25), blurRadius: 0.25, spreadRadius: 0, color: Color(0xFF282828), inset: true),
        BoxShadow(offset: Offset(0, -1.25), blurRadius: 0.25, spreadRadius: 0, color: Color(0xFF282828), inset: true),
      ];
    } else {
      // Light Mode Preset: D4, FL, BV, I1, I2
      GlassmorphismPresets.shadows = const [
        BoxShadow(offset: Offset(0, 8), blurRadius: 15, spreadRadius: 0, color: Color(0x05000000)),
      ];
      GlassmorphismPresets.innerShadows = const [
        BoxShadow(offset: Offset(0, 1.25), blurRadius: 0.25, spreadRadius: 0, color: Color(0xFF282828), inset: true),
        BoxShadow(offset: Offset(0, -1.25), blurRadius: 0.25, spreadRadius: 0, color: Color(0xFF282828), inset: true),
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
      buildPageRoute(NoteEditorScreen(note: note)),
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

  void _openNewTask() {
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
        builder: (_) => CreateTaskScreen(initialDate: DateTime.now()),
      ),
    );
  }

  // ── Home tab body — exact reference layout ───────────────────────────────

  Widget _buildHomeBody(int selectedBgIndex) {
    return SafeArea(
      bottom: false, // bottom handled by nav bar + system padding
      child: HomePromptView(
        date: DateTime.now(),
        interactive: false,
        onTap: _openNewNote,
        onLastEditedNoteTap: _openNote,
        isDarkBackground: selectedBgIndex == 1 || selectedBgIndex == 2 || selectedBgIndex == 6,
      ),
    );
  }

  // ── Other tab bodies ─────────────────────────────────────────────────────

  Widget _buildFoldersBody() {
    return FolderManagementScreen(
      onMenuTap: () {},
      onNavigateToTab: (i) => setState(() => _activeNavIndex = i),
    );
  }

  Widget _buildCalendarBody() {
    return NoteCalendarScreen(
      onNavigateToTab: (i) => setState(() => _activeNavIndex = i),
    );
  }

  Widget _buildSettingsBody() {
    final provider = Provider.of<NotesProvider>(context, listen: false);
    return SettingsScreen(
      isDarkMode: provider.isDarkMode,
      onThemeToggle: provider.toggleTheme,
      onMenuTap: () {
        HapticFeedback.lightImpact();
        setState(() => _activeNavIndex = 0);
      },
    );
  }

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
        return Container(color: const Color(0xFF000000));
      case 0:
      default:
        // B0: Default Warm Stone
        return Container(color: const Color(0xFFF2F2EE));
    }
  }



  // ── Root build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final notesProvider = Provider.of<NotesProvider>(context);
    final selectedBgIndex = notesProvider.selectedBgIndex;
    _updatePresetsForBackground(selectedBgIndex);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Dynamic Background (only active/visible behind Home tab)
          if (_activeNavIndex == 0) _buildBackground(selectedBgIndex),

          // Tab content — IndexedStack keeps all tabs alive
          IndexedStack(
            index: _activeNavIndex,
            children: [
              _buildHomeBody(selectedBgIndex),
              _buildFoldersBody(),
              _buildCalendarBody(),
              _buildSettingsBody(),
            ],
          ),

          // Task Widget (only visible on Home tab when Tasks view is selected)
          if (_activeNavIndex == 0 && !_isNotesActive)
            Positioned(
              left: 0,
              right: 0,
              bottom: 58.0 + MediaQuery.paddingOf(context).bottom + 10.0 + 32.0 + 24.0,
              child: TweenAnimationBuilder<double>(
                key: const ValueKey('task_widget_entry'),
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
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
                child: Center(
                  child: TaskWidget(
                    onEdit: _openNewTask,
                  ),
                ),
              ),
            ),

          // Segmented Control Pill (only visible on Home tab, placed 10px above bottom bar)
          if (_activeNavIndex == 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 58.0 + MediaQuery.paddingOf(context).bottom + 10.0,
              child: Center(
                child: NotesAndTaskPill(
                  isNotesActive: _isNotesActive,
                  onChanged: (val) {
                    setState(() {
                      _isNotesActive = val;
                    });
                  },
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
              activeColor: _isNotesActive ? const Color(0xFFFFA322) : const Color(0xFF0088FF),
              onDestinationSelected: (i) {
                if (i == 4) {
                  if (_isNotesActive) {
                    _openNewNote();
                  } else {
                    _openNewTask();
                  }
                } else {
                  HapticFeedback.lightImpact();
                  setState(() => _activeNavIndex = i);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

