import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/tactile_button.dart';
import '../widgets/app_header_bar.dart';
import '../widgets/grouped_list_container.dart';
import '../../core/animations/page_transitions.dart';
import 'profile_screen.dart';
import 'glassmorphism_sandbox_screen.dart';

import 'package:provider/provider.dart';
import '../../providers/tasks_provider.dart';
import '../../providers/notes_provider.dart';
import 'experimental/sde_drag_test_screen.dart';
import '../widgets/more_options_popup.dart';
import '../widgets/delete_confirmation_dialog.dart';
import '../../models/note.dart';
import '../../models/task_item.dart';
import '../../models/folder.dart';

class SettingsScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onThemeToggle;
  final VoidCallback onMenuTap;

  const SettingsScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeToggle,
    required this.onMenuTap,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _fullName = 'Hemanth Adapala';
  String _username = 'byhmnth';
  String? _imagePath;
  bool _isDummyDarkMode = true;
  bool _isMoreOptionsOpen = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final name = prefs.getString('profile_username') ?? prefs.getString('profile_full_name');
      final uname = prefs.getString('profile_username');
      if (name != null && name.trim().isNotEmpty) {
        _fullName = name.trim();
      }
      if (uname != null && uname.trim().isNotEmpty) {
        _username = uname.trim().replaceAll('@', '');
      }
      _imagePath = prefs.getString('profile_avatar_path') ?? prefs.getString('profile_image_path');
    });
  }

  void _showInfoDialog(BuildContext context, String title, String message) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF333333),
            fontSize: 18,
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.inter(
            color: const Color(0xFF333333).withValues(alpha: 0.8),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Dismiss",
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF333333),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryTextColor = Color(0xFF333333);
    const circleColor = Color(0x33787878);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: AppHeaderBar(
                leftHeroTag: 'hero_settings_back',
                leftWidth: 44.0,
                onLeftTap: widget.onMenuTap,
                leftChild: SvgPicture.asset(
                  'assets/icons/angle_left.svg',
                  width: 22,
                  height: 22,
                  colorFilter: const ColorFilter.mode(primaryTextColor, BlendMode.srcIn),
                ),
                titleWidget: Text(
                  "Settings",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: primaryTextColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 0.70,
                    letterSpacing: -0.43,
                  ),
                ),
                rightHeroTag: 'hero_settings_more',
                rightWidth: 44.0,
                isExpanded: _isMoreOptionsOpen,
                expandedWidth: 192.0,
                expandedHeight: 100.0,
                expandedChild: MoreOptionsPopup(
                  onDeleteData: () async {
                    setState(() => _isMoreOptionsOpen = false);
                    final confirm = await showDeleteNoteDialog(
                      context,
                      title: 'Delete Data',
                      message: 'Are you sure you want to delete\nall notes and tasks? This action\ncannot be undone',
                    );
                    if (confirm == true && mounted) {
                      final notesProvider = Provider.of<NotesProvider>(context, listen: false);
                      final tasksProvider = Provider.of<TasksProvider>(context, listen: false);
                      for (final note in List<Note>.from(notesProvider.notes)) {
                        await notesProvider.deleteNote(note.id);
                      }
                      for (final task in List<TaskItem>.from(tasksProvider.tasks)) {
                        await tasksProvider.deleteTask(task.id);
                      }
                      for (final folder in List<Folder>.from(notesProvider.folders)) {
                        await notesProvider.deleteFolder(folder.id);
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('All data deleted successfully.')),
                        );
                      }
                    }
                  },
                  onRefresh: () async {
                    setState(() => _isMoreOptionsOpen = false);
                    final notesProvider = Provider.of<NotesProvider>(context, listen: false);
                    final tasksProvider = Provider.of<TasksProvider>(context, listen: false);
                    await notesProvider.loadFolders();
                    await notesProvider.loadNotes();
                    await tasksProvider.loadTasks();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Data refreshed.')),
                      );
                    }
                  },
                ),
                rightChild: TactileButton(
                  useAppleSpring: true,
                  compressionScale: 0.7,
                  settleDuration: const Duration(milliseconds: 1000),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _isMoreOptionsOpen = !_isMoreOptionsOpen;
                    });
                  },
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5.0,
                          height: 5.0,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C1E).withValues(alpha: 0.8),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4.0),
                        Container(
                          width: 5.0,
                          height: 5.0,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C1E).withValues(alpha: 0.8),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4.0),
                        Container(
                          width: 5.0,
                          height: 5.0,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C1E).withValues(alpha: 0.8),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 12.0, bottom: 120.0),
                child: Column(
                  children: [
                    // Top Profile Card (322x60)
                    Center(
                      child: TactileButton(
                        useAppleSpring: true,
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          await Navigator.push(
                            context,
                            buildPageRoute(const ProfileScreen()),
                          );
                          _loadUserData();
                        },
                        child: Container(
                          width: 322,
                          height: 70,
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
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Row(
                              children: [
                                // Avatar circle 44x44
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: const ShapeDecoration(
                                    color: circleColor,
                                    shape: OvalBorder(),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: _imagePath != null && _imagePath!.startsWith('assets/')
                                      ? Padding(
                                          padding: const EdgeInsets.all(4.0),
                                          child: Image.asset(
                                            _imagePath!,
                                            width: 36,
                                            height: 36,
                                            fit: BoxFit.contain,
                                          ),
                                        )
                                      : _imagePath != null && File(_imagePath!).existsSync()
                                          ? Image.file(
                                              File(_imagePath!),
                                              width: 44,
                                              height: 44,
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _fullName,
                                        style: GoogleFonts.inter(
                                          color: primaryTextColor,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          height: 1.1,
                                          letterSpacing: -0.43,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '@$_username',
                                        style: GoogleFonts.inter(
                                          color: primaryTextColor,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          height: 1.1,
                                          letterSpacing: -0.43,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                SvgPicture.asset(
                                  'assets/icons/angle-right.svg',
                                  width: 14,
                                  height: 14,
                                  colorFilter: const ColorFilter.mode(primaryTextColor, BlendMode.srcIn),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 26.0),

                    // Section 1 Card (Pause Notifications, General Settings, SDEDragTest)
                    GroupedListContainer(
                      children: [
                        GroupedTile.navigation(
                          iconPath: 'assets/icons/pause-notifications.svg',
                          title: 'Pause Notifications',
                          onTap: () => _showInfoDialog(
                            context,
                            "Pause Notifications",
                            "Notification alerts are currently paused.",
                          ),
                        ),
                        GroupedTile.navigation(
                          iconPath: 'assets/icons/settings-sliders.svg',
                          title: 'General Settings',
                          onTap: () => _showInfoDialog(
                            context,
                            "General Settings",
                            "General application preferences configured.",
                          ),
                        ),
                        GroupedTile.navigation(
                          iconPath: 'assets/icons/settings-sliders.svg',
                          title: '🧪 Test SDE Drag Selection',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => const SDEDragTestScreen()),
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16.0),

                    // Section 2 Card (Dark Mode, Language)
                    GroupedListContainer(
                      children: [
                        GroupedTile.toggle(
                          iconPath: 'assets/icons/night-day.svg',
                          title: 'Dark Mode',
                          trailingSwitch: ToggleSwitch(
                            value: _isDummyDarkMode,
                            onChanged: (val) {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _isDummyDarkMode = val;
                              });
                            },
                          ),
                        ),
                        GroupedTile.navigation(
                          iconPath: 'assets/icons/translate.svg',
                          title: 'Language',
                          onTap: () => _showInfoDialog(
                            context,
                            "Language",
                            "Current application language: English (US)",
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16.0),

                    // Section 3 Card (Glassmorphism, FAQ, Terms, Policy, Seeds)
                    GroupedListContainer(
                      children: [
                        GroupedTile.navigation(
                          iconPath: 'assets/icons/refresh.svg',
                          title: 'Glassmorphism Sandbox',
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.push(
                              context,
                              buildPageRoute(const GlassmorphismSandboxScreen()),
                            );
                          },
                        ),
                        GroupedTile.navigation(
                          iconPath: 'assets/icons/interrogation.svg',
                          title: 'FAQ',
                          onTap: () => _showInfoDialog(
                            context,
                            "FAQ",
                            "Frequently asked questions and support resources.",
                          ),
                        ),
                        GroupedTile.navigation(
                          iconPath: 'assets/icons/terms-info.svg',
                          title: 'Terms of service',
                          onTap: () => _showInfoDialog(
                            context,
                            "Terms of service",
                            "Standard Terms of Service for QuickNotes.",
                          ),
                        ),
                        GroupedTile.navigation(
                          iconPath: 'assets/icons/insurance.svg',
                          title: 'User Policy',
                          onTap: () => _showInfoDialog(
                            context,
                            "User Policy",
                            "Privacy and Data Protection Policy for QuickNotes.",
                          ),
                        ),
                        GroupedTile.navigation(
                          iconPath: 'assets/icons/terms-info.svg',
                          title: 'Seed Long Note (10,000+ Chars)',
                          onTap: () async {
                            HapticFeedback.mediumImpact();
                            final provider = Provider.of<NotesProvider>(context, listen: false);
                            final seededNote = await provider.seedLongTestNote();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('✅ Seeded Long Note with ${seededNote.content.length} characters!'),
                                  backgroundColor: const Color(0xFF34C759),
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            }
                          },
                        ),
                        GroupedTile.navigation(
                          iconPath: 'assets/icons/alarm_clock.svg',
                          title: 'Seed 50 Test Tasks (Test 12.1)',
                          onTap: () async {
                            HapticFeedback.mediumImpact();
                            final provider = Provider.of<TasksProvider>(context, listen: false);
                            await provider.seedTestTasks(55);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('✅ 55 Test Tasks created across Today, Weekly & Missed!'),
                                  backgroundColor: Color(0xFF34C759),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            }
                          },
                        ),
                      ],
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

  Widget _buildSettingRow({
    required String iconPath,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
    required bool showBorderBottom,
  }) {
    const primaryTextColor = Color(0xFF333333);
    const borderColor = Color(0xFF333333);

    return TactileButton(
      useAppleSpring: true,
      onTap: onTap ?? () {},
      child: Container(
        width: 322,
        height: 50,
        decoration: ShapeDecoration(
          shape: RoundedRectangleBorder(
            side: showBorderBottom
                ? const BorderSide(
                    width: 0.20,
                    strokeAlign: BorderSide.strokeAlignOutside,
                    color: borderColor,
                  )
                : BorderSide.none,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          children: [
            SvgPicture.asset(
              iconPath,
              width: 18,
              height: 18,
              colorFilter: const ColorFilter.mode(primaryTextColor, BlendMode.srcIn),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  color: primaryTextColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.0,
                  letterSpacing: -0.43,
                ),
              ),
            ),
            trailing ??
                SvgPicture.asset(
                  'assets/icons/angle-right.svg',
                  width: 14,
                  height: 14,
                  colorFilter: const ColorFilter.mode(primaryTextColor, BlendMode.srcIn),
                ),
          ],
        ),
      ),
    );
  }
}

// ── Custom Toggle Switch matching Toggle Switch.txt ───────────────────────────
class ToggleSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const ToggleSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 53,
        height: 28,
        decoration: ShapeDecoration(
          color: value ? const Color(0xFF34C759) : const Color(0xFFE5E5EA),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              left: value ? 24 : 2,
              top: 2,
              child: Container(
                width: 27,
                height: 24,
                decoration: ShapeDecoration(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef StitchToggleSwitch = ToggleSwitch;
