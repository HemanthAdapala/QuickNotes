import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../widgets/bottom_nav_bar_v2.dart';


import '../../providers/notes_provider.dart';
import '../../themes/app_theme.dart';
import '../../core/animations/page_transitions.dart';
import '../widgets/living_writing_experience.dart';
import '../widgets/home_prompt_view.dart';
import 'note_editor_screen.dart';
import 'folder_management_screen.dart';
import 'settings_screen.dart';
import 'note_calendar_screen.dart';

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

  // ── Home tab body — exact reference layout ───────────────────────────────

  Widget _buildHomeBody() {
    return SafeArea(
      bottom: false, // bottom handled by nav bar + system padding
      child: HomePromptView(
        date: DateTime.now(),
        interactive: false,
        onTap: _openNewNote,
        onLastEditedNoteTap: _openNote,
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

  // ── Root build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Tab content — IndexedStack keeps all tabs alive
          IndexedStack(
            index: _activeNavIndex,
            children: [
              _buildHomeBody(),
              _buildFoldersBody(),
              _buildCalendarBody(),
              _buildSettingsBody(),
            ],
          ),

          // ── Bottom nav bar (Change 3 + Change 4) ──────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: GravityNotesNavBar(
              activeIndex: _activeNavIndex,
              onTap: (i) {
                HapticFeedback.lightImpact();
                setState(() => _activeNavIndex = i);
              },
              onFabTap: _openNewNote,
            ),
          ),
        ],
      ),
    );
  }
}
