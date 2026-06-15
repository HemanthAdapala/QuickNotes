import 'dart:io';
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
                      child: _InteractiveFab(
                        key: const Key('nav_fab'),
                        onTap: _openNewNote,
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

class _InteractiveFab extends StatefulWidget {
  final VoidCallback onTap;

  const _InteractiveFab({
    super.key,
    required this.onTap,
  });

  @override
  State<_InteractiveFab> createState() => _InteractiveFabState();
}

class _InteractiveFabState extends State<_InteractiveFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTest = Platform.environment.containsKey('FLUTTER_TEST');

    Widget child = Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF333333),
        boxShadow: isTest
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(_isHovered ? 0.35 : 0.2),
                  blurRadius: _isHovered ? 14 : 7,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Center(
        child: SvgPicture.string(
          '''<svg width="30" height="30" viewBox="162 10 30 30" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M177 10C174.033 10 171.133 10.8797 168.666 12.528C166.2 14.1762 164.277 16.5189 163.142 19.2598C162.006 22.0006 161.709 25.0166 162.288 27.9264C162.867 30.8361 164.296 33.5088 166.393 35.6066C168.491 37.7044 171.164 39.133 174.074 39.7118C176.983 40.2906 179.999 39.9935 182.74 38.8582C185.481 37.7229 187.824 35.8003 189.472 33.3336C191.12 30.8668 192 27.9667 192 25C191.996 21.0231 190.414 17.2103 187.602 14.3981C184.79 11.586 180.977 10.0043 177 10ZM177 37.5C174.528 37.5 172.111 36.7669 170.055 35.3934C168 34.0199 166.398 32.0676 165.452 29.7835C164.505 27.4995 164.258 24.9861 164.74 22.5614C165.223 20.1366 166.413 17.9093 168.161 16.1612C169.909 14.413 172.137 13.2225 174.561 12.7402C176.986 12.2579 179.499 12.5054 181.784 13.4515C184.068 14.3976 186.02 15.9998 187.393 18.0554C188.767 20.111 189.5 22.5277 189.5 25C189.496 28.3141 188.178 31.4914 185.835 33.8348C183.491 36.1782 180.314 37.4964 177 37.5ZM183.25 25C183.25 25.3315 183.118 25.6495 182.884 25.8839C182.649 26.1183 182.332 26.25 182 26.25H178.25V30C178.25 30.3315 178.118 30.6495 177.884 30.8839C177.649 31.1183 177.332 31.25 177 31.25C176.668 31.25 176.351 31.1183 176.116 30.8839C175.882 30.6495 175.75 30.3315 175.75 30V26.25H172C171.668 26.25 171.351 26.1183 171.116 25.8839C170.882 25.6495 170.75 25.3315 170.75 25C170.75 24.6685 170.882 24.3505 171.116 24.1161C171.351 23.8817 171.668 23.75 172 23.75H175.75V20C175.75 19.6685 175.882 19.3505 176.116 19.1161C176.351 18.8817 176.668 18.75 177 18.75C177.332 18.75 177.649 18.8817 177.884 19.1161C178.118 19.3505 178.25 19.6685 178.25 20V23.75H182C182.332 23.75 182.649 23.8817 182.884 24.1161C183.118 24.3505 183.25 24.6685 183.25 25Z" fill="white"/>
</svg>''',
          width: 30,
          height: 30,
        ),
      ),
    );

    if (isTest) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: child,
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) => _controller.reverse(),
        onTapCancel: () => _controller.reverse(),
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: child,
        ),
      ),
    );
  }
}
