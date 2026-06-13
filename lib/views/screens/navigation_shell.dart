import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_screen.dart';
import 'folder_management_screen.dart';
import 'settings_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Calendar placeholder — stub until Calendar tab is implemented
// ─────────────────────────────────────────────────────────────────────────────
class _CalendarPlaceholder extends StatelessWidget {
  const _CalendarPlaceholder();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_month_outlined,
                size: 60,
                color: colorScheme.onSurface.withAlpha(50),
              ),
              const SizedBox(height: 16),
              Text(
                'Calendar',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface.withAlpha(120),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Coming soon',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: colorScheme.onSurface.withAlpha(80),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Navigation Shell
// ─────────────────────────────────────────────────────────────────────────────

class NavigationShell extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final bool isDarkMode;

  const NavigationShell({
    super.key,
    required this.onThemeToggle,
    required this.isDarkMode,
  });

  @override
  State<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends State<NavigationShell>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  // Tabs: Home(0) | Folders(1) | Calendar(2) | Settings(3)

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return const HomeScreen();
      case 1:
        return FolderManagementScreen(
          onMenuTap: () {},
          onNavigateToTab: (i) => setState(() => _currentIndex = i),
        );
      case 2:
        return const _CalendarPlaceholder();
      case 3:
        return SettingsScreen(
          isDarkMode: widget.isDarkMode,
          onThemeToggle: widget.onThemeToggle,
          onMenuTap: () {},
        );
      default:
        return const HomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 768;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Row(
        children: [
          if (isDesktop) ...[
            _buildSidebar(context, isDark),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: isDark
                  ? const Color(0xFF1F2937)
                  : const Color(0xFFEBEBE8),
            ),
          ],
          Expanded(child: _buildBody()),
        ],
      ),
      bottomNavigationBar: isDesktop ? null : _buildBottomNav(context, isDark),
    );
  }

  // ─── Bottom Navigation Bar (Figma design: dark pill, 4 icons + center FAB) ─

  Widget _buildBottomNav(BuildContext context, bool isDark) {
    // Pill background
    final Color pillBg = isDark
        ? const Color(0xFF111827)
        : const Color(0xFF1A1A2E);
    final Color activeColor = const Color(0xFFF97316); // orange accent
    final Color inactiveColor = isDark
        ? const Color(0xFF6B7280)
        : const Color(0xFF9CA3AF);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: SizedBox(
          height: 64,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Dark pill container ──
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: pillBg,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(isDark ? 80 : 40),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Left 2 tabs
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _NavItem(
                              index: 0,
                              currentIndex: _currentIndex,
                              icon: Icons.home_outlined,
                              activeIcon: Icons.home_rounded,
                              activeColor: activeColor,
                              inactiveColor: inactiveColor,
                              onTap: _onTabTap,
                            ),
                            _NavItem(
                              index: 1,
                              currentIndex: _currentIndex,
                              icon: Icons.folder_outlined,
                              activeIcon: Icons.folder_rounded,
                              activeColor: activeColor,
                              inactiveColor: inactiveColor,
                              onTap: _onTabTap,
                            ),
                          ],
                        ),
                      ),

                      // Center gap for the + FAB
                      const SizedBox(width: 56),

                      // Right 2 tabs
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _NavItem(
                              index: 2,
                              currentIndex: _currentIndex,
                              icon: Icons.calendar_month_outlined,
                              activeIcon: Icons.calendar_month_rounded,
                              activeColor: activeColor,
                              inactiveColor: inactiveColor,
                              onTap: _onTabTap,
                            ),
                            _NavItem(
                              index: 3,
                              currentIndex: _currentIndex,
                              icon: Icons.settings_outlined,
                              activeIcon: Icons.settings_rounded,
                              activeColor: activeColor,
                              inactiveColor: inactiveColor,
                              onTap: _onTabTap,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Floating center + button ──
              Positioned(
                top: -14,
                left: 0,
                right: 0,
                child: Center(
                  child: _CenterFab(
                    isDark: isDark,
                    onTap: () {
                      // Go to home tab and let HomeScreen handle opening editor
                      if (_currentIndex != 0) {
                        setState(() => _currentIndex = 0);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onTabTap(int index) {
    if (_currentIndex == index) return;
    HapticFeedback.lightImpact();
    setState(() => _currentIndex = index);
  }

  // ─── Desktop Sidebar ─────────────────────────────────────────────────────

  Widget _buildSidebar(BuildContext context, bool isDark) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      child: Container(
        width: 240,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'QuickNotes',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 32),
            _SidebarItem(
              index: 0,
              currentIndex: _currentIndex,
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'Home',
              onTap: _onTabTap,
              theme: theme,
            ),
            _SidebarItem(
              index: 1,
              currentIndex: _currentIndex,
              icon: Icons.folder_outlined,
              activeIcon: Icons.folder_rounded,
              label: 'Folders',
              onTap: _onTabTap,
              theme: theme,
            ),
            _SidebarItem(
              index: 2,
              currentIndex: _currentIndex,
              icon: Icons.calendar_month_outlined,
              activeIcon: Icons.calendar_month_rounded,
              label: 'Calendar',
              onTap: _onTabTap,
              theme: theme,
            ),
            const Spacer(),
            const Divider(),
            _SidebarItem(
              index: 3,
              currentIndex: _currentIndex,
              icon: Icons.settings_outlined,
              activeIcon: Icons.settings_rounded,
              label: 'Settings',
              onTap: _onTabTap,
              theme: theme,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom nav item
// ─────────────────────────────────────────────────────────────────────────────

class _NavItem extends StatefulWidget {
  final int index;
  final int currentIndex;
  final IconData icon;
  final IconData activeIcon;
  final Color activeColor;
  final Color inactiveColor;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.activeIcon,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.82).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  bool get _isSelected => widget.index == widget.currentIndex;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _scaleController.forward(),
      onTapUp: (_) {
        _scaleController.reverse();
        widget.onTap(widget.index);
      },
      onTapCancel: () => _scaleController.reverse(),
      child: SizedBox(
        width: 52,
        height: 64,
        child: Center(
          child: ScaleTransition(
            scale: _scale,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _isSelected ? widget.activeIcon : widget.icon,
                key: ValueKey(_isSelected),
                size: 24,
                color:
                    _isSelected ? widget.activeColor : widget.inactiveColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Center FAB (+) floating above the pill
// ─────────────────────────────────────────────────────────────────────────────

class _CenterFab extends StatefulWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _CenterFab({required this.isDark, required this.onTap});

  @override
  State<_CenterFab> createState() => _CenterFabState();
}

class _CenterFabState extends State<_CenterFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.88).animate(
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
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFF97316), // orange
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF97316).withAlpha(100),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.add_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Desktop sidebar item
// ─────────────────────────────────────────────────────────────────────────────

class _SidebarItem extends StatelessWidget {
  final int index;
  final int currentIndex;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final ValueChanged<int> onTap;
  final ThemeData theme;

  const _SidebarItem({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
    required this.theme,
  });

  bool get _isSelected => index == currentIndex;

  @override
  Widget build(BuildContext context) {
    final Color activeColor = theme.colorScheme.primary;
    final Color inactiveColor = theme.colorScheme.onSurface.withAlpha(130);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _isSelected
                ? activeColor.withAlpha(20)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                _isSelected ? activeIcon : icon,
                size: 20,
                color: _isSelected ? activeColor : inactiveColor,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight:
                      _isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: _isSelected ? activeColor : inactiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
