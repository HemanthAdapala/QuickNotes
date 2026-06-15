import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../providers/notes_provider.dart';
import '../../themes/app_theme.dart';
import '../widgets/living_writing_experience.dart';
import '../widgets/home_prompt_view.dart';
import 'note_editor_screen.dart';
import 'folder_management_screen.dart';
import 'settings_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Calendar stub — intentionally minimal until the feature is built
// ─────────────────────────────────────────────────────────────────────────────

class _CalendarPlaceholder extends StatelessWidget {
  const _CalendarPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Text(
          'Calendar',
          style: GoogleFonts.playfairDisplay(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
      ),
    );
  }
}

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

  void _openNewNote() {
    HapticFeedback.lightImpact();

    // Compute FAB screen bounds from the SVG spec so the morph starts there.
    final size = MediaQuery.of(context).size;
    final double scale = size.width / 354;
    final double barH = 83 * scale;
    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    final double fabSize = 50 * scale;
    final double fabLeft = (177 - 25) * scale;
    // The nav bar sits at the bottom of the screen.
    final double fabTop = size.height - barH - bottomPadding;

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

  Widget _buildCalendarBody() => const _CalendarPlaceholder();

  Widget _buildSettingsBody() {
    final provider = Provider.of<NotesProvider>(context, listen: false);
    return SettingsScreen(
      isDarkMode: false, // HomeScreen is always light
      onThemeToggle: provider.toggleTheme,
      onMenuTap: () {},
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

          // ── Bottom nav bar (The Cardboard Cutout) ──────────────────
          Positioned(
            bottom: 32 + MediaQuery.of(context).padding.bottom,
            left: 24,
            right: 24,
            child: Center(
              child: SizedBox(
                width: 354,
                height: 83,
                child: Stack(
                  children: [
                    SvgPicture.asset(
                      'assets/icons/bottom_bar.svg',
                      width: 354,
                      height: 83,
                    ),
                    Positioned(
                      left: 31,
                      top: 39,
                      width: 26,
                      height: 26,
                      child: GestureDetector(
                        key: const Key('nav_home'),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _activeNavIndex = 0);
                        },
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                    Positioned(
                      left: 106,
                      top: 39,
                      width: 26,
                      height: 26,
                      child: GestureDetector(
                        key: const Key('nav_folders'),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _activeNavIndex = 1);
                        },
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                    Positioned(
                      left: 152,
                      top: 0,
                      width: 50,
                      height: 50,
                      child: GestureDetector(
                        key: const Key('nav_fab'),
                        onTap: _openNewNote,
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                    Positioned(
                      left: 222,
                      top: 40,
                      width: 28,
                      height: 28,
                      child: GestureDetector(
                        key: const Key('nav_calendar'),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _activeNavIndex = 2);
                        },
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                    Positioned(
                      left: 297,
                      top: 39,
                      width: 28,
                      height: 28,
                      child: GestureDetector(
                        key: const Key('nav_settings'),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _activeNavIndex = 3);
                        },
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
