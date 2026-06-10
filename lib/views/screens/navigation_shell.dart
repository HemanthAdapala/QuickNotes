import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/notes_provider.dart';
import 'notes_list_screen.dart';
import 'folder_management_screen.dart';
import 'habit_dashboard_screen.dart';
import 'vault_screen.dart';
import 'settings_screen.dart';

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

class _NavigationShellState extends State<NavigationShell> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Get active screen body
  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        // Main notes list (Feed)
        return NotesListScreen(
          viewType: NotesViewType.feed,
          onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
          onNavigateToTab: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
        );
      case 1:
        // Bento Folders
        return FolderManagementScreen(
          onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
          onNavigateToTab: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
        );
      case 2:
        // Favorites list
        return NotesListScreen(
          viewType: NotesViewType.favorites,
          onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
          onNavigateToTab: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
        );
      case 3:
        // Habits Dashboard
        return HabitDashboardScreen(
          onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
        );
      case 4:
        // Locked/Unlocked Vault Bento Grid
        return VaultScreen(
          onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
        );
      case 5:
        // Settings Screen
        return SettingsScreen(
          isDarkMode: widget.isDarkMode,
          onThemeToggle: widget.onThemeToggle,
          onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
        );
      case 6:
        // Archive list (Navigated via Drawer)
        return NotesListScreen(
          viewType: NotesViewType.archive,
          onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
          onNavigateToTab: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
        );
      case 7:
        // Trash list (Navigated via Drawer)
        return NotesListScreen(
          viewType: NotesViewType.trash,
          onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
          onNavigateToTab: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
        );
      default:
        return const Center(child: Text("Page Not Found"));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 768;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: theme.scaffoldBackgroundColor,
      // Desktop uses side menu, mobile uses Drawer + Bottom Navigation
      drawer: isDesktop ? null : _buildDrawer(context),
      body: Row(
        children: [
          if (isDesktop) ...[
            _buildSidebar(context),
            const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFEBEBE8)),
          ],
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
      bottomNavigationBar: isDesktop ? null : _buildBottomNavigationBar(context),
    );
  }

  // Mobile Bottom Navigation Bar (Floating Rounded Pill Bar)
  Widget _buildBottomNavigationBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final strokeColor = isDark ? const Color(0xFF312E81) : const Color(0xFF1E1B4B);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withAlpha(240),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: strokeColor,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildBottomNavItem(0, Icons.home_outlined, Icons.home_rounded),
                _buildBottomNavItem(1, Icons.folder_open_outlined, Icons.folder_rounded),
                _buildBottomNavItem(2, Icons.star_outline_rounded, Icons.star_rounded),
                _buildBottomNavItem(3, Icons.auto_awesome_outlined, Icons.auto_awesome_rounded),
                _buildBottomNavItem(4, Icons.lock_open_outlined, Icons.lock_rounded),
                _buildBottomNavItem(5, Icons.settings_outlined, Icons.settings_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(int index, IconData icon, IconData activeIcon) {
    final isSelected = _currentIndex == index;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeColor = isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1);
    final inactiveColor = theme.colorScheme.onSurface.withAlpha(120);

    return InkWell(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withAlpha(35) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: isSelected 
              ? Border.all(color: activeColor.withAlpha(80), width: 1.0)
              : null,
        ),
        child: Icon(
          isSelected ? activeIcon : icon,
          color: isSelected ? activeColor : inactiveColor,
          size: isSelected ? 24 : 22,
        ),
      ),
    );
  }

  // Sidebar for Desktop viewports
  Widget _buildSidebar(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      child: Container(
        width: 280,
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Spaces",
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildSidebarNavItem(0, Icons.description_outlined, "All Notes"),
                  _buildSidebarNavItem(1, Icons.folder_open_outlined, "Folders"),
                  _buildSidebarNavItem(6, Icons.archive_outlined, "Archive"),
                  _buildSidebarNavItem(7, Icons.delete_outline_rounded, "Trash"),
                  _buildSidebarNavItem(2, Icons.star_outline_rounded, "Favorites"),
                  _buildSidebarNavItem(3, Icons.auto_awesome, "Habits"),
                  _buildSidebarNavItem(4, Icons.lock_outline_rounded, "Vault"),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Divider(color: Color(0xFFEBEBE8)),
                  ),
                  _buildSidebarNavItem(5, Icons.settings_outlined, "Settings"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
      leading: Icon(
        icon,
        color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withAlpha(120),
        size: 20,
      ),
      title: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withAlpha(180),
        ),
      ),
      selected: isSelected,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
    );
  }

  // Sidebar Drawer for Mobile hamburger tap
  Widget _buildDrawer(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Spaces",
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  children: [
                    _buildDrawerNavItem(0, Icons.description_outlined, "All Notes"),
                    _buildDrawerNavItem(1, Icons.folder_open_outlined, "Folders"),
                    _buildDrawerNavItem(6, Icons.archive_outlined, "Archive"),
                    _buildDrawerNavItem(7, Icons.delete_outline_rounded, "Trash"),
                    _buildDrawerNavItem(2, Icons.star_outline_rounded, "Favorites"),
                    _buildDrawerNavItem(3, Icons.auto_awesome, "Habits"),
                    _buildDrawerNavItem(4, Icons.lock_outline_rounded, "Vault"),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Divider(color: Color(0xFFEBEBE8)),
                    ),
                    _buildDrawerNavItem(5, Icons.settings_outlined, "Settings"),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withAlpha(120),
      ),
      title: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withAlpha(180),
        ),
      ),
      selected: isSelected,
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
        Navigator.pop(context);
      },
    );
  }
}
