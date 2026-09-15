import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
import 'storage_and_data_screen.dart';
import 'legal_document_screen.dart';
import '../widgets/about_bottom_sheet.dart';
import '../widgets/blurred_bottom_sheet.dart';
import '../widgets/primary_screen_surface.dart';
import 'package:provider/provider.dart';
import '../../providers/tasks_provider.dart';
import '../../providers/notes_provider.dart';
import 'experimental/sde_drag_test_screen.dart';
import '../widgets/more_options_popup.dart';
import '../widgets/header_expanded_interaction.dart';
import '../widgets/delete_confirmation_dialog.dart';
import '../../models/note.dart';
import '../../models/task_item.dart';
import '../../models/folder.dart';
import 'appearance_screen.dart';
import 'widgets_screen.dart';
import '../../premium/premium.dart';
import '../../providers/settings_provider.dart';
import 'developer/premium_test_mode_screen.dart';

class SettingsScreen extends StatefulWidget {
  final bool? isDarkMode;
  final VoidCallback? onThemeToggle;
  final VoidCallback? onMenuTap;

  const SettingsScreen({
    super.key,
    this.isDarkMode,
    this.onThemeToggle,
    this.onMenuTap,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _fullName = 'Guest';
  String _username = 'Guest';
  String _email = 'Not connected';
  String? _imagePath;
  bool _avatarFileExists = false;
  bool _isMoreOptionsOpen = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('profile_full_name') ??
        prefs.getString('profile_username');
    final uname = prefs.getString('profile_username');
    final mail =
        prefs.getString('profile_email') ?? prefs.getString('user_email');
    final imgPath = prefs.getString('profile_avatar_path') ??
        prefs.getString('profile_image_path');

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

  // Placeholder Markdown Content
  static const String _faqMarkdown = '''
# Frequently Asked Questions

## 1. What is QuickNotes?
QuickNotes is the fastest, most elegant way to capture your thoughts, organize your life, and secure your ideas.

## 2. Is my data secure?
Yes! Your data is stored locally on your device in a secure SQLite database. If you use the Backup & Sync feature, your data is securely encrypted before being uploaded to the cloud.

## 3. How do I delete my account?
You can delete your account by navigating to **Account Settings** and tapping on **Delete Account**. Please note that this action is irreversible.

## 4. Does QuickNotes support Markdown?
Absolutely! QuickNotes supports a rich text editing experience and full Markdown support.
''';

  static const String _tosMarkdown = '''
# Terms of Service

**Last Updated: August 2026**

Welcome to QuickNotes. By using our application, you agree to these terms.

## 1. Acceptance of Terms
By accessing and using QuickNotes, you accept and agree to be bound by the terms and provision of this agreement.

## 2. Privacy Policy
We value your privacy. Our Privacy Policy explains how we collect, use, and protect your information. 

## 3. User Conduct
You agree not to use QuickNotes for any unlawful purpose or in any way that might harm, damage, or disparage any other party.

## 4. Modifications
We reserve the right to modify these terms at any time. Your continued use of the app constitutes acceptance of those changes.
''';

  static const String _privacyMarkdown = '''
# Privacy Policy

**Last Updated: August 2026**

## 1. Data Collection
QuickNotes is designed with privacy in mind. We only collect the data necessary to provide you with the best possible experience.

## 2. Local Storage
By default, all your notes, tasks, and settings are stored locally on your device. We do not have access to this data unless you explicitly enable cloud sync.

## 3. Cloud Synchronization
If you choose to use our Backup & Sync feature, your data will be securely transmitted and stored on our servers. All data is encrypted in transit and at rest.

## 4. Third-Party Services
We do not sell, trade, or otherwise transfer your personally identifiable information to outside parties.
''';

  Widget _buildSectionHeader(String title, {required bool isDark}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: isDark ? const Color(0xFF9E9E9E) : const Color(0xFF8E8E93),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCurrentDark =
        context.select<SettingsProvider, bool>((p) => p.isDarkMode);
    final isDark = widget.isDarkMode ?? isCurrentDark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF333333);
    final secondaryTextColor =
        isDark ? const Color(0xFF9E9E9E) : const Color(0xFF8E8E93);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final double headerHeight = screenHeight < 720 ? 238.0 : 248.0;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      body: Stack(
        children: [
          // 1. Fixed Top Floral Background Banner (Layer Isolated)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 180,
            child: RepaintBoundary(
              child: isDark
                  ? Opacity(
                      opacity: 0.38,
                      child: SvgPicture.asset(
                        'assets/Settings Screen/Background.svg',
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    )
                  : SvgPicture.asset(
                      'assets/Settings Screen/Background.svg',
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
            ),
          ),

          // 2. Primary Screen Surface Background
          Positioned(
            top: 140,
            left: 0,
            right: 0,
            bottom: 0,
            child: PrimaryScreenSurface(
              color: isDark ? const Color(0xFF121212) : Colors.white,
              child: const SizedBox.expand(),
            ),
          ),

          // 3. Fixed Upper Header Block + Scrollable Cards Column
          Column(
            children: [
              // Responsive Top Header Area (Height: 248px / 238px on compact) — Avatar + User info
              SizedBox(
                height: headerHeight,
                child: Stack(
                  children: [
                    // Overlapping Profile Avatar Circle with Camera Overlay Badge
                    Positioned(
                      top: 95,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: TactileButton(
                          useAppleSpring: true,
                          scrollSafe: false,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              buildPageRoute(const ProfileScreen()),
                            );
                            _loadUserData();
                          },
                          child: SizedBox(
                            width: 90,
                            height: 90,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // Main Avatar Circle
                                Container(
                                  width: 90,
                                  height: 90,
                                  decoration: ShapeDecoration(
                                    color: isDark
                                        ? const Color(0xFF1E1E1E)
                                        : Colors.white,
                                    shape: OvalBorder(
                                      side: BorderSide(
                                        width: 4,
                                        color: isDark
                                            ? const Color(0xFF121212)
                                            : Colors.white,
                                      ),
                                    ),
                                    shadows: const [
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

                                // Camera overlay badge (28x28 visual, 44x44 hit target)
                                Positioned(
                                  right: -8,
                                  bottom: -8,
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    color: Colors.transparent,
                                    alignment: Alignment.center,
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: ShapeDecoration(
                                        color: isDark
                                            ? const Color(0xFF2C2C2E)
                                            : Colors.white,
                                        shape: const OvalBorder(
                                          side: BorderSide(
                                            color: Color(0x1F3C3C43),
                                            width: 0.5,
                                          ),
                                        ),
                                        shadows: const [
                                          BoxShadow(
                                            color: Color(0x3F000000),
                                            blurRadius: 6,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: SvgPicture.asset(
                                          'assets/icons/camera.svg',
                                          width: 13,
                                          height: 13,
                                          colorFilter: ColorFilter.mode(
                                            primaryTextColor,
                                            BlendMode.srcIn,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Fixed User Info (FullName, @Email)
                    Positioned(
                      top: 193,
                      left: 24,
                      right: 24,
                      child: TactileButton(
                        useAppleSpring: true,
                        scrollSafe: false,
                        onTap: () async {
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
                                fontSize: 19,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                                letterSpacing: -0.43,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '@${_email.isNotEmpty ? _email : _username}',
                              style: GoogleFonts.inter(
                                color: secondaryTextColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
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
                child: RepaintBoundary(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(
                        left: 20.0, right: 20.0, top: 10.0, bottom: 120.0),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── SECTION 1: ACCOUNT & BACKUP ───────────────────────
                            _buildSectionHeader('ACCOUNT & BACKUP', isDark: isDark),
                            GroupedListContainer(
                              width: double.infinity,
                              border: isDark
                                  ? Border.all(color: const Color(0xFF2C2C2E), width: 1.0)
                                  : Border.all(color: const Color(0xFFEFEFF2), width: 1.0),
                              children: [
                                GroupedTile.navigation(
                                  iconPath:
                                      'assets/icons/bottom_navigation/settings.svg',
                                  title: 'Account',
                                  fontSize: 15.0,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      buildPageRoute(
                                          const AccountSettingsScreen()),
                                    );
                                  },
                                ),
                                GroupedTile.navigation(
                                  iconPath: 'assets/icons/refresh.svg',
                                  title: 'Backup & Sync',
                                  fontSize: 15.0,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      buildPageRoute(const BackupRestoreScreen()),
                                    );
                                  },
                                ),
                              ],
                            ),

                            const SizedBox(height: 20.0),

                            // ── SECTION 2: PREFERENCES ────────────────────────────
                            _buildSectionHeader('PREFERENCES', isDark: isDark),
                            GroupedListContainer(
                              width: double.infinity,
                              border: isDark
                                  ? Border.all(color: const Color(0xFF2C2C2E), width: 1.0)
                                  : Border.all(color: const Color(0xFFEFEFF2), width: 1.0),
                              children: [
                                GroupedTile.navigation(
                                  iconPath: 'assets/icons/highlighter.svg',
                                  title: 'Appearance',
                                  fontSize: 15.0,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      buildPageRoute(
                                          const AppearanceScreen()),
                                    );
                                  },
                                ),
                                GroupedTile.toggle(
                                  iconPath: 'assets/icons/night-day.svg',
                                  title: 'Dark Mode',
                                  fontSize: 15.0,
                                  trailingSwitch: Selector<SettingsProvider, bool>(
                                    selector: (_, p) => p.isDarkMode,
                                    builder: (context, isCurrentDark, _) {
                                      return ToggleSwitch(
                                        value: isCurrentDark,
                                        onChanged: (val) async {
                                          final settingsProv =
                                              Provider.of<SettingsProvider>(context,
                                                  listen: false);
                                          if (val) {
                                            await requestDarkModeAccess(context);
                                          } else {
                                            await settingsProv
                                                .setThemeMode(ThemeMode.light);
                                          }
                                          if (widget.onThemeToggle != null) {
                                            widget.onThemeToggle!();
                                          }
                                        },
                                      );
                                    },
                                  ),
                                ),
                                Builder(
                                  builder: (context) {
                                    bool hasWidgetAccess = false;
                                    try {
                                      final featureAccess =
                                          Provider.of<FeatureAccess>(context);
                                      hasWidgetAccess = featureAccess
                                          .canAccess(PremiumFeature.widgets);
                                    } catch (_) {
                                      hasWidgetAccess = false;
                                    }
                                    return GroupedTile.navigation(
                                      iconPath: 'assets/icons/category.svg',
                                      title: 'Widgets',
                                      fontSize: 15.0,
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (!hasWidgetAccess) ...[
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF10B981)
                                                    .withValues(alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: const Color(0xFF10B981)
                                                      .withValues(alpha: 0.3),
                                                  width: 0.8,
                                                ),
                                              ),
                                              child: Text(
                                                '✦ PREMIUM',
                                                style: GoogleFonts.inter(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 0.4,
                                                  color: const Color(0xFF10B981),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                          SvgPicture.asset(
                                            'assets/icons/angle-right.svg',
                                            width: 14,
                                            height: 14,
                                            colorFilter: ColorFilter.mode(
                                              isDark
                                                  ? const Color(0xFF8E8E93)
                                                  : const Color(0xFF333333),
                                              BlendMode.srcIn,
                                            ),
                                          ),
                                        ],
                                      ),
                                      onTap: () async {
                                        await requestWidgetAccess(context);
                                      },
                                    );
                                  },
                                ),
                                GroupedTile.navigation(
                                  iconPath: 'assets/icons/settings-sliders.svg',
                                  title: 'Storage and Data',
                                  fontSize: 15.0,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      buildPageRoute(
                                          const StorageAndDataScreen()),
                                    );
                                  },
                                ),
                              ],
                            ),

                            const SizedBox(height: 20.0),

                            // ── SECTION 3: SUPPORT & ABOUT ────────────────────────
                            _buildSectionHeader('SUPPORT & ABOUT', isDark: isDark),
                            GroupedListContainer(
                              width: double.infinity,
                              border: isDark
                                  ? Border.all(color: const Color(0xFF2C2C2E), width: 1.0)
                                  : Border.all(color: const Color(0xFFEFEFF2), width: 1.0),
                              children: [
                                GroupedTile.navigation(
                                  iconPath: 'assets/icons/interrogation.svg',
                                  title: 'FAQ',
                                  fontSize: 15.0,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      buildPageRoute(const LegalDocumentScreen(
                                        title: 'FAQ',
                                        markdownContent: _faqMarkdown,
                                      )),
                                    );
                                  },
                                ),
                                GroupedTile.navigation(
                                  iconPath: 'assets/icons/terms-info.svg',
                                  title: 'Terms of Service',
                                  fontSize: 15.0,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      buildPageRoute(const LegalDocumentScreen(
                                        title: 'Terms of Service',
                                        markdownContent: _tosMarkdown,
                                      )),
                                    );
                                  },
                                ),
                                GroupedTile.navigation(
                                  iconPath: 'assets/icons/insurance.svg',
                                  title: 'Privacy Policy',
                                  fontSize: 15.0,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      buildPageRoute(const LegalDocumentScreen(
                                        title: 'Privacy Policy',
                                        markdownContent: _privacyMarkdown,
                                      )),
                                    );
                                  },
                                ),
                                GroupedTile.navigation(
                                  iconPath: 'assets/icons/terms-info.svg',
                                  title: 'About',
                                  fontSize: 15.0,
                                  onTap: () {
                                    showBlurredBottomSheet(
                                      context: context,
                                      child: const AboutBottomSheet(),
                                    );
                                  },
                                ),
                              ],
                            ),

                            // ── SECTION 4: DEVELOPER (DEBUG BUILDS ONLY) ──────────
                            if (kDebugMode) ...[
                              const SizedBox(height: 20.0),
                              _buildSectionHeader('DEVELOPER', isDark: isDark),
                              GroupedListContainer(
                                width: double.infinity,
                                border: isDark
                                    ? Border.all(color: const Color(0xFF2C2C2E), width: 1.0)
                                    : Border.all(color: const Color(0xFFEFEFF2), width: 1.0),
                                children: [
                                  GroupedTile.navigation(
                                    iconPath: 'assets/icons/settings-sliders.svg',
                                    title: 'Premium Test Mode',
                                    fontSize: 15.0,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        buildPageRoute(
                                            const PremiumTestModeScreen()),
                                      );
                                    },
                                  ),
                                  GroupedTile.navigation(
                                    iconPath:
                                        'assets/icons/bottom_navigation/home.svg',
                                    title: 'Test Welcome Screen',
                                    fontSize: 15.0,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        buildPageRoute(const TestWelcomeScreen()),
                                      );
                                    },
                                  ),
                                  GroupedTile.navigation(
                                    iconPath: 'assets/icons/edit_pen.svg',
                                    title: 'Test SDE Drag Selection',
                                    fontSize: 15.0,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        buildPageRoute(const SDEDragTestScreen()),
                                      );
                                    },
                                  ),
                                  GroupedTile.navigation(
                                    iconPath: 'assets/icons/highlighter.svg',
                                    title: 'Glassmorphism Sandbox',
                                    fontSize: 15.0,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        buildPageRoute(
                                            const GlassmorphismSandboxScreen()),
                                      );
                                    },
                                  ),
                                  GroupedTile.navigation(
                                    iconPath: 'assets/icons/terms-info.svg',
                                    title: 'Seed Long Note (10,000+ Chars)',
                                    fontSize: 15.0,
                                    onTap: () async {
                                      final provider = Provider.of<NotesProvider>(
                                          context,
                                          listen: false);
                                      final seededNote =
                                          await provider.seedLongTestNote();
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                '✅ Seeded Long Note with ${seededNote.content.length} characters!'),
                                            backgroundColor:
                                                const Color(0xFF34C759),
                                            duration: const Duration(seconds: 3),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                  GroupedTile.navigation(
                                    iconPath: 'assets/icons/alarm_clock.svg',
                                    title: 'Seed 50 Test Tasks',
                                    fontSize: 15.0,
                                    onTap: () async {
                                      final provider = Provider.of<TasksProvider>(
                                          context,
                                          listen: false);
                                      await provider.seedTestTasks(55);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                '✅ 55 Test Tasks created across Today, Weekly & Missed!'),
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

                            const SizedBox(height: 24.0),
                            Text(
                              'QuickNotes v1.0.0',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: secondaryTextColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),

          // 3.5. Header Expanded Outside-Tap Barrier & Interaction
          Positioned.fill(
            child: HeaderExpandedInteraction(
              isExpanded: _isMoreOptionsOpen,
              onDismiss: () => setState(() => _isMoreOptionsOpen = false),
            ),
          ),

          // 4. Header Bar Overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 12.0),
                child: AppHeaderBar(
                  leftHeroTag: 'hero_settings_back',
                  leftWidth: 44.0,
                  onLeftTap: () {
                    if (_isMoreOptionsOpen) {
                      setState(() => _isMoreOptionsOpen = false);
                    } else {
                      widget.onMenuTap?.call();
                    }
                  },
                  onCollapse: () => setState(() => _isMoreOptionsOpen = false),
                  leftChild: SvgPicture.asset(
                    'assets/icons/angle_left.svg',
                    width: 22,
                    height: 22,
                    colorFilter: ColorFilter.mode(
                        primaryTextColor, BlendMode.srcIn),
                  ),
                  titleWidget: Text(
                    "Settings",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: primaryTextColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
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
                      final notesProvider =
                          Provider.of<NotesProvider>(context, listen: false);
                      final tasksProvider =
                          Provider.of<TasksProvider>(context, listen: false);
                      final messenger = ScaffoldMessenger.of(context);
                      final confirm = await showDeleteNoteDialog(
                        context,
                        title: 'Delete Data',
                        message:
                            'Are you sure you want to delete\nall notes and tasks? This action\ncannot be undone',
                      );
                      if (confirm == true && mounted) {
                        for (final note
                            in List<Note>.from(notesProvider.notes)) {
                          await notesProvider.deleteNote(note.id);
                        }
                        for (final task
                            in List<TaskItem>.from(tasksProvider.tasks)) {
                          await tasksProvider.deleteTask(task.id);
                        }
                        for (final folder
                            in List<Folder>.from(notesProvider.folders)) {
                          await notesProvider.deleteFolder(folder.id);
                        }
                        messenger.showSnackBar(
                          const SnackBar(
                              content: Text('All data deleted successfully.')),
                        );
                      }
                    },
                    onRefresh: () async {
                      setState(() => _isMoreOptionsOpen = false);
                      final notesProvider =
                          Provider.of<NotesProvider>(context, listen: false);
                      final tasksProvider =
                          Provider.of<TasksProvider>(context, listen: false);
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
                    onTap: () {
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
                              color: primaryTextColor
                                  .withValues(alpha: 0.8),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4.0),
                          Container(
                            width: 5.0,
                            height: 5.0,
                            decoration: BoxDecoration(
                              color: primaryTextColor
                                  .withValues(alpha: 0.8),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4.0),
                          Container(
                            width: 5.0,
                            height: 5.0,
                            decoration: BoxDecoration(
                              color: primaryTextColor
                                  .withValues(alpha: 0.8),
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

