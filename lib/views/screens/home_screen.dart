import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../widgets/bottom_nav_bar_v2.dart';
import '../widgets/app_bottom_navigation_bar.dart';


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
  int _validationSelectedIndex = 0;

  static const List<NavDestination> _destinations = [
    NavDestination(
      svgAssetPath: 'assets/app_bottom_navigation_bar_Icons/home.svg',
      label: 'Home',
    ),
    NavDestination(
      svgAssetPath: 'assets/app_bottom_navigation_bar_Icons/folder-open.svg',
      label: 'Folders',
    ),
    NavDestination(
      svgAssetPath: 'assets/app_bottom_navigation_bar_Icons/calendar-pen.svg',
      label: 'Calendar',
    ),
    NavDestination(
      svgAssetPath: 'assets/app_bottom_navigation_bar_Icons/settings.svg',
      label: 'Settings',
    ),
  ];

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
    final double screenWidth = MediaQuery.of(context).size.width;
    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    
    // Sizing for the floating 88dff2f comparison bar
    final double barWidth = screenWidth < 402 ? (screenWidth - 48) : 354;
    final double barScale = barWidth / 354;
    final double barHeight = 83 * barScale;

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

          // ── CURRENT Bottom Nav Bar (at bottom: 0) ──────────────────────────
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

          // ── AppBottomNavigationBar for Visual Validation and Reference ──────
          Positioned(
            bottom: 120 + bottomPadding,
            left: 0,
            right: 0,
            child: AppBottomNavigationBar(
              destinations: _destinations,
              selectedIndex: _validationSelectedIndex,
              onDestinationSelected: (i) {
                setState(() => _validationSelectedIndex = i);
              },
              fabSvgAssetPath: 'assets/app_bottom_navigation_bar_Icons/pencil.svg',
              onFabPressed: _openNewNote,
            ),
          ),
        ],
      ),
    );
  }
}

class _InteractiveFab extends StatefulWidget {
  final VoidCallback onTap;
  final double size;

  const _InteractiveFab({
    super.key,
    required this.onTap,
    this.size = 50.0,
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
    final double size = widget.size;
    final double iconSize = size * (30.0 / 50.0);

    Widget child = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF333333),
        boxShadow: isTest
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(_isHovered ? 0.35 : 0.2),
                  blurRadius: _isHovered ? (14.0 * size / 50.0) : (7.0 * size / 50.0),
                  offset: Offset(0, 4.0 * size / 50.0),
                ),
              ],
      ),
      child: Center(
        child: SvgPicture.string(
          '''<svg width="$iconSize" height="$iconSize" viewBox="162 10 30 30" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M177 10C174.033 10 171.133 10.8797 168.666 12.528C166.2 14.1762 164.277 16.5189 163.142 19.2598C162.006 22.0006 161.709 25.0166 162.288 27.9264C162.867 30.8361 164.296 33.5088 166.393 35.6066C168.491 37.7044 171.164 39.133 174.074 39.7118C176.983 40.2906 179.999 39.9935 182.74 38.8582C185.481 37.7229 187.824 35.8003 189.472 33.3336C191.12 30.8668 192 27.9667 192 25C191.996 21.0231 190.414 17.2103 187.602 14.3981C184.79 11.586 180.977 10.0043 177 10ZM177 37.5C174.528 37.5 172.111 36.7669 170.055 35.3934C168 34.0199 166.398 32.0676 165.452 29.7835C164.505 27.4995 164.258 24.9861 164.74 22.5614C165.223 20.1366 166.413 17.9093 168.161 16.1612C169.909 14.413 172.137 13.2225 174.561 12.7402C176.986 12.2579 179.499 12.5054 181.784 13.4515C184.068 14.3976 186.02 15.9998 187.393 18.0554C188.767 20.111 189.5 22.5277 189.5 25C189.496 28.3141 188.178 31.4914 185.835 33.8348C183.491 36.1782 180.314 37.4964 177 37.5ZM183.25 25C183.25 25.3315 183.118 25.6495 182.884 25.8839C182.649 26.1183 182.332 26.25 182 26.25H178.25V30C178.25 30.3315 178.118 30.6495 177.884 30.8839C177.649 31.1183 177.332 31.25 177 31.25C176.668 31.25 176.351 31.1183 176.116 30.8839C175.882 30.6495 175.75 30.3315 175.75 30V26.25H172C171.668 26.25 171.351 26.1183 171.116 25.8839C170.882 25.6495 170.75 25.3315 170.75 25C170.75 24.6685 170.882 24.3505 171.116 24.1161C171.351 23.8817 171.668 23.75 172 23.75H175.75V20C175.75 19.6685 175.882 19.3505 176.116 19.1161C176.351 18.8817 176.668 18.75 177 18.75C177.332 18.75 177.649 18.8817 177.884 19.1161C178.118 19.3505 178.25 19.6685 178.25 20V23.75H182C182.332 23.75 182.649 23.8817 182.884 24.1161C183.118 24.3505 183.25 24.6685 183.25 25Z" fill="white"/>
</svg>''',
          width: iconSize,
          height: iconSize,
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
