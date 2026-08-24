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
import 'account/account_settings_screen.dart';
import 'backup_restore_screen.dart';
import 'test_welcome_screen.dart';

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
  String _email = 'hemanth@example.com';
  String? _imagePath;
  bool _avatarFileExists = false;
  bool _isDummyDarkMode = true;
  bool _isMoreOptionsOpen = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('profile_full_name') ?? prefs.getString('profile_username');
    final uname = prefs.getString('profile_username');
    final mail = prefs.getString('profile_email') ?? prefs.getString('user_email');
    final imgPath = prefs.getString('profile_avatar_path') ?? prefs.getString('profile_image_path');

    bool fileExists = false;
    if (imgPath != null && !imgPath.startsWith('assets/')) {
      fileExists = await File(imgPath).exists();
    }

    if (mounted) {
      setState(() {
        if (name != null && name.trim().isNotEmpty) {
          _fullName = name.trim();
        }
        if (uname != null && uname.trim().isNotEmpty) {
          _username = uname.trim().replaceAll('@', '');
        }
        if (mail != null) {
          _email = mail.trim();
        }
        _imagePath = imgPath;
        _avatarFileExists = fileExists;
      });
    }
  }

  Widget _buildAvatarWidget() {
    if (_imagePath != null && _imagePath!.startsWith('assets/')) {
      return Padding(
        padding: const EdgeInsets.all(6.0),
        child: Image.asset(
          _imagePath!,
          width: 78,
          height: 78,
          cacheWidth: 156,
          cacheHeight: 156,
          fit: BoxFit.contain,
        ),
      );
    }
    
    if (_imagePath != null && _avatarFileExists) {
      return Image.file(
        File(_imagePath!),
        width: 90,
        height: 90,
        cacheWidth: 180,
        cacheHeight: 180,
        fit: BoxFit.cover,
      );
    }

    return Padding(
      padding: const EdgeInsets.all(6.0),
      child: Image.asset(
        'assets/Profile Icons/maxim_transparent.png',
        width: 78,
        height: 78,
        cacheWidth: 156,
        cacheHeight: 156,
        fit: BoxFit.contain,
      ),
    );
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

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Fixed Top Floral Background Banner (Layer Isolated)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 180,
            child: RepaintBoundary(
              child: SvgPicture.asset(
                'assets/Settings Screen/Background.svg',
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
          ),

          // 2. Fixed Upper Header Block + Scrollable Cards Column
          Column(
            children: [
              // Fixed Top Header Area (Height: 285px) — Floral background + white curved top + Avatar + User info
              SizedBox(
                height: 285,
                child: Stack(
                  children: [
                    // White rounded sheet top
                    Positioned(
                      top: 140,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                        ),
                      ),
                    ),

                    // Overlapping Profile Avatar Circle
                    Positioned(
                      top: 95,
                      left: 0,
                      right: 0,
                      child: Center(
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
                            width: 90,
                            height: 90,
                            decoration: const ShapeDecoration(
                              color: Colors.white,
                              shape: OvalBorder(
                                side: BorderSide(width: 4, color: Colors.white),
                              ),
                              shadows: [
                                BoxShadow(
                                  color: Color(0x26000000),
                                  blurRadius: 16,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _buildAvatarWidget(),
                          ),
                        ),
                      ),
                    ),

                    // Fixed User Info (FullName, @Email)
                    Positioned(
                      top: 195,
                      left: 24,
                      right: 24,
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
                        child: Column(
                          children: [
                            Text(
                              _fullName,
                              style: GoogleFonts.inter(
                                color: primaryTextColor,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                height: 1.1,
                                letterSpacing: -0.43,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '@${_email.isNotEmpty ? _email : _username}',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF8E8E93),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                height: 1.1,
                                letterSpacing: -0.43,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable Cards Only (GroupedListContainer Section 1, 2, 3, 4)
              Expanded(
                child: Container(
                  color: Colors.white,
                  child: RepaintBoundary(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 12.0, bottom: 100.0),
                      child: Column(
                      children: [
                        // Section 1 Card (Account, Backup & Sync)
                        GroupedListContainer(
                          children: [
                            GroupedTile.navigation(
                              iconPath: 'assets/icons/bottom_navigation/settings.svg',
                              title: 'Account',
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.push(
                                  context,
                                  buildPageRoute(const AccountSettingsScreen()),
                                );
                              },
                            ),
                            GroupedTile.navigation(
                              iconPath: 'assets/icons/refresh.svg',
                              title: 'Backup & Sync',
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.push(
                                  context,
                                  buildPageRoute(const BackupRestoreScreen()),
                                );
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 16.0),

                        // Section 2 Card (Dark Mode, Storage and Data)
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
                              iconPath: 'assets/icons/settings-sliders.svg',
                              title: 'Storage and Data',
                              onTap: () => _showInfoDialog(
                                context,
                                "Storage and Data",
                                "Storage allocations and offline cache settings.",
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16.0),

                        // Section 3 Card (FAQ, Terms of service, Privacy Policy, About)
                        GroupedListContainer(
                          children: [
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
                              title: 'Privacy Policy',
                              onTap: () => _showInfoDialog(
                                context,
                                "Privacy Policy",
                                "Privacy and Data Protection Policy for QuickNotes.",
                              ),
                            ),
                            GroupedTile.navigation(
                              iconPath: 'assets/icons/terms-info.svg',
                              title: 'About',
                              onTap: () => _showInfoDialog(
                                context,
                                "About",
                                "QuickNotes v2.9.0 — Clean minimal note-taking experience.",
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16.0),

                        // Section 4 Card (🧪 Developer & Testing Screens)
                        GroupedListContainer(
                          children: [
                            GroupedTile.navigation(
                              iconPath: 'assets/icons/bottom_navigation/home.svg',
                              title: '🧪 Test Welcome Screen',
                              onTap: () {
                                HapticFeedback.selectionClick();
                                Navigator.push(
                                  context,
                                  buildPageRoute(const TestWelcomeScreen()),
                                );
                              },
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
                              title: 'Seed 50 Test Tasks',
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
              ),
            ),
            ],
          ),

          // 3. Header Bar Overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
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
                      final notesProvider = Provider.of<NotesProvider>(context, listen: false);
                      final tasksProvider = Provider.of<TasksProvider>(context, listen: false);
                      final messenger = ScaffoldMessenger.of(context);
                      final confirm = await showDeleteNoteDialog(
                        context,
                        title: 'Delete Data',
                        message: 'Are you sure you want to delete\nall notes and tasks? This action\ncannot be undone',
                      );
                      if (confirm == true && mounted) {
                        for (final note in List<Note>.from(notesProvider.notes)) {
                          await notesProvider.deleteNote(note.id);
                        }
                        for (final task in List<TaskItem>.from(tasksProvider.tasks)) {
                          await tasksProvider.deleteTask(task.id);
                        }
                        for (final folder in List<Folder>.from(notesProvider.folders)) {
                          await notesProvider.deleteFolder(folder.id);
                        }
                        messenger.showSnackBar(
                          const SnackBar(content: Text('All data deleted successfully.')),
                        );
                      }
                    },
                    onRefresh: () async {
                      setState(() => _isMoreOptionsOpen = false);
                      final notesProvider = Provider.of<NotesProvider>(context, listen: false);
                      final tasksProvider = Provider.of<TasksProvider>(context, listen: false);
                      final messenger = ScaffoldMessenger.of(context);
                      await notesProvider.loadFolders();
                      await notesProvider.loadNotes();
                      await tasksProvider.loadTasks();
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Data refreshed.')),
                      );
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
            ),
          ),
        ],
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
