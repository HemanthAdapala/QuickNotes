import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/animations/page_transitions.dart';
import '../../../core/avatar_registry.dart';
import '../../../data/sqlite_profile_repository.dart';
import '../../../models/current_user.dart';
import '../../../models/session_type.dart';
import '../../../models/user_profile.dart';
import '../../../repositories/user_repository.dart';
import '../../../services/session_manager.dart';
import '../../widgets/tactile_button.dart';
import '../../widgets/grouped_list_container.dart';
import '../home_screen.dart';
import '../../widgets/app_header_bar.dart';

/// AccountProfileScreen — Canonical profile management screen for Quick Notes.
///
/// Supports both Offline and Google-connected account states:
/// - Offline: displays local character avatar, editable name, "Offline Account" status,
///   and local storage note (no fake verified email).
/// - Google: displays Google photo (or custom avatar), editable name, authenticated Google email
///   with verified badge, and "Google Account Connected" status.
class AccountProfileScreen extends StatefulWidget {
  final bool isSetupFlow;
  const AccountProfileScreen({super.key, this.isSetupFlow = false});

  @override
  State<AccountProfileScreen> createState() => _AccountProfileScreenState();
}

class _AccountProfileScreenState extends State<AccountProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final FocusNode _nameFocusNode;

  bool _isLoading = true;
  bool _isGoogleUser = false;
  bool _isAvatarGridOpen = false;
  bool _usesGooglePhoto = true;

  String? _photoUrl;
  String? _selectedAvatarId;
  String? _selectedAvatarPath;
  int? _selectedAvatarIndex;

  UserProfile? _existingProfile;
  CurrentUser? _currentUser;

  static const primaryTextColor = Color(0xFF333333);
  static const backgroundColor = Color(0xFFF2F2F7);

  void _navigateToHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      buildPageRoute(const HomeScreen()),
    );
  }

  void _handleSkip() {
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();
    if (widget.isSetupFlow || !Navigator.canPop(context)) {
      _navigateToHome();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _nameFocusNode = FocusNode();
    _loadProfileData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    try {
      final sessionManager = SessionManager();
      await sessionManager.init();

      final activeId = sessionManager.activeUserId;
      final isGoogle = sessionManager.activeSessionType == SessionType.google;

      final userRepo = UserRepository();
      _currentUser = userRepo.currentUser;
      if (_currentUser == null && activeId != null) {
        _currentUser = await userRepo.getUserById(activeId);
      }

      if (activeId != null && activeId.isNotEmpty) {
        try {
          _existingProfile =
              await SqliteProfileRepository().getProfileForUser(activeId);
        } catch (_) {}
      }

      final prefs = await SharedPreferences.getInstance();

      final effectiveDisplayName = _existingProfile?.displayName ??
          _currentUser?.displayName ??
          prefs.getString('profile_username') ??
          prefs.getString('profile_full_name') ??
          (isGoogle ? 'QuickNotes User' : 'Guest');

      final effectiveEmail = isGoogle
          ? (_existingProfile?.email ??
              _currentUser?.email ??
              prefs.getString('user_email') ??
              '')
          : '';

      _photoUrl = isGoogle
          ? (_existingProfile?.photoUrl ?? _currentUser?.photoUrl)
          : null;
      _usesGooglePhoto = _existingProfile?.usesGooglePhoto ??
          (_photoUrl != null && _photoUrl!.isNotEmpty);
      _selectedAvatarId = _existingProfile?.avatarId ?? 'andre';

      if (_selectedAvatarId != null &&
          AvatarRegistry.isValid(_selectedAvatarId)) {
        _selectedAvatarPath = AvatarRegistry.assetPath(_selectedAvatarId);
        _selectedAvatarIndex =
            AvatarRegistry.allIds.indexOf(_selectedAvatarId!);
      } else {
        _selectedAvatarPath = 'assets/Profile Icons/andre_transparent.png';
        _selectedAvatarIndex = 0;
      }

      _isGoogleUser = isGoogle;
      _nameController.text = effectiveDisplayName;
      _emailController.text = effectiveEmail;
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _toggleAvatarGrid() {
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();
    setState(() {
      _isAvatarGridOpen = !_isAvatarGridOpen;
    });
  }

  Future<void> _saveProfile() async {
    HapticFeedback.mediumImpact();
    FocusScope.of(context).unfocus();

    final activeId = SessionManager().activeUserId ?? _currentUser?.id;
    if (activeId == null || activeId.isEmpty) {
      if (mounted) Navigator.pop(context);
      return;
    }

    final now = DateTime.now();
    final updatedDisplayName = _nameController.text.trim().isEmpty
        ? (_isGoogleUser ? 'QuickNotes User' : 'Guest')
        : _nameController.text.trim();

    final updatedEmail = _isGoogleUser
        ? (_existingProfile?.email ??
            _currentUser?.email ??
            'user@quicknotes.app')
        : 'offline@local.quicknotes';

    final profile = UserProfile(
      userId: activeId,
      displayName: updatedDisplayName,
      email: updatedEmail,
      avatarId: _selectedAvatarId ?? 'andre',
      photoUrl: _photoUrl,
      usesGooglePhoto: _usesGooglePhoto,
      profileVersion: _existingProfile?.profileVersion ?? 1,
      createdAt: _existingProfile?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      await SqliteProfileRepository().saveProfile(profile);
    } catch (_) {}

    final updatedCurrentUser = CurrentUser(
      id: activeId,
      email: updatedEmail,
      displayName: updatedDisplayName,
      photoUrl: _usesGooglePhoto ? _photoUrl : null,
      sessionType: SessionManager().activeSessionType,
      isOffline: !(_isGoogleUser),
      createdAt: _currentUser?.createdAt ?? now,
    );
    await UserRepository().saveUser(updatedCurrentUser);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_username', updatedDisplayName);
    await prefs.setString('profile_full_name', updatedDisplayName);
    if (_isGoogleUser) {
      await prefs.setString('profile_email', updatedEmail);
    }
    if (_selectedAvatarPath != null) {
      await prefs.setString('profile_avatar_path', _selectedAvatarPath!);
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              'Profile saved successfully',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF333333),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    if (widget.isSetupFlow || !Navigator.canPop(context)) {
      _navigateToHome();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.isSetupFlow && Navigator.canPop(context),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleSkip();
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: primaryTextColor))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24.0, 12.0, 24.0, 0.0),
                      child: Stack(
                        alignment: Alignment.centerRight,
                        children: [
                          AppHeaderBar(
                            leftHeroTag: 'hero_profile_back',
                            rightHeroTag: 'hero_profile_empty',
                            leftWidth: 44.0,
                            rightWidth: 44.0,
                            rightChild: null,
                            onLeftTap: () {
                              HapticFeedback.lightImpact();
                              if (widget.isSetupFlow || !Navigator.canPop(context)) {
                                _navigateToHome();
                              } else {
                                Navigator.pop(context);
                              }
                            },
                            leftChild: SvgPicture.asset(
                              'assets/icons/angle_left.svg',
                  width: 22,
                  height: 22,
                              colorFilter: const ColorFilter.mode(primaryTextColor, BlendMode.srcIn),
                            ),
                            titleWidget: Text(
                              "Profile",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                color: primaryTextColor,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.43,
                              ),
                            ),
                          ),
                          if (widget.isSetupFlow)
                            TactileButton(
                              useAppleSpring: true,
                              onTap: _handleSkip,
                              child: Container(
                                alignment: Alignment.centerRight,
                                width: 50,
                                height: 44, // Match AppHeaderBar height
                                child: Text(
                                  'Skip',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF8E8E93),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8.0),

                    // Content Area (White Rounded Sheet)
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(32)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24.0, vertical: 24.0),
                          child: Column(
                            children: [
                              const SizedBox(height: 8),

                              // ── PROFILE PICTURE CIRCLE ──────────────────────
                              Center(
                                child: TactileButton(
                                  useAppleSpring: true,
                                  compressionScale: 0.92,
                                  onTap: _toggleAvatarGrid,
                                  child: SizedBox(
                                    width: 96,
                                    height: 96,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Container(
                                          width: 96,
                                          height: 96,
                                          decoration: const ShapeDecoration(
                                            color: Colors.white,
                                            shape: OvalBorder(
                                              side: BorderSide(
                                                  color: Color(0x1F3C3C43),
                                                  width: 1),
                                            ),
                                            shadows: [
                                              BoxShadow(
                                                color: Color(0x1A000000),
                                                blurRadius: 10,
                                                offset: Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: _isGoogleUser &&
                                                  _usesGooglePhoto &&
                                                  _photoUrl != null &&
                                                  _photoUrl!.isNotEmpty
                                              ? Image.network(
                                                  _photoUrl!,
                                                  width: 96,
                                                  height: 96,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (ctx, _, __) =>
                                                      _buildFallbackAvatar(),
                                                )
                                              : _buildFallbackAvatar(),
                                        ),

                                        // Camera overlay badge (26x26)
                                        Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: Container(
                                            width: 26,
                                            height: 26,
                                            decoration: const ShapeDecoration(
                                              color: Colors.white,
                                              shape: OvalBorder(
                                                side: BorderSide(
                                                    color: Color(0x1F3C3C43),
                                                    width: 0.5),
                                              ),
                                              shadows: [
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
                                                width: 12,
                                                height: 12,
                                                colorFilter:
                                                    const ColorFilter.mode(
                                                        primaryTextColor,
                                                        BlendMode.srcIn),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 8),

                              // Change Photo text button
                              TactileButton(
                                useAppleSpring: true,
                                onTap: _toggleAvatarGrid,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 6.0, horizontal: 12.0),
                                  child: Text(
                                    'Change Photo',
                                    style: GoogleFonts.inter(
                                      color: primaryTextColor,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ),
                              ),

                              // ── EXPANDABLE CHARACTER AVATAR PICKER ──────────
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeOutCubic,
                                width: double.infinity,
                                height: _isAvatarGridOpen ? 260 : 0,
                                margin: EdgeInsets.only(
                                    top: _isAvatarGridOpen ? 12.0 : 0.0),
                                clipBehavior: Clip.antiAlias,
                                decoration: ShapeDecoration(
                                  color: const Color(0xFFF9F9FB),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: const BorderSide(
                                        color: Color(0x14000000), width: 1),
                                  ),
                                ),
                                child: _isAvatarGridOpen
                                    ? Column(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                top: 10.0, bottom: 6.0),
                                            child: Text(
                                              'Choose an Avatar Character',
                                              style: GoogleFonts.inter(
                                                color: const Color(0x803C3C43),
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: GridView.builder(
                                              padding: const EdgeInsets.all(8),
                                              physics:
                                                  const BouncingScrollPhysics(),
                                              gridDelegate:
                                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: 5,
                                                mainAxisSpacing: 8,
                                                crossAxisSpacing: 8,
                                                childAspectRatio: 1.0,
                                              ),
                                              itemCount:
                                                  AvatarRegistry.allIds.length,
                                              itemBuilder: (context, index) {
                                                final avatarId = AvatarRegistry
                                                    .allIds[index];
                                                final assetPath =
                                                    AvatarRegistry.assetPath(
                                                        avatarId);
                                                final isSelected =
                                                    !_usesGooglePhoto &&
                                                        _selectedAvatarIndex ==
                                                            index;

                                                return TactileButton(
                                                  useAppleSpring: true,
                                                  compressionScale: 0.85,
                                                  onTap: () {
                                                    HapticFeedback
                                                        .selectionClick();
                                                    setState(() {
                                                      _selectedAvatarId =
                                                          avatarId;
                                                      _selectedAvatarPath =
                                                          assetPath;
                                                      _selectedAvatarIndex =
                                                          index;
                                                      _usesGooglePhoto = false;
                                                    });
                                                  },
                                                  child: AnimatedContainer(
                                                    duration: const Duration(
                                                        milliseconds: 200),
                                                    decoration: ShapeDecoration(
                                                      color: isSelected
                                                          ? const Color(
                                                              0xFFE5E5EA)
                                                          : Colors.white,
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                        side: isSelected
                                                            ? const BorderSide(
                                                                color:
                                                                    primaryTextColor,
                                                                width: 1.5)
                                                            : const BorderSide(
                                                                color: Color(
                                                                    0x14000000),
                                                                width: 0.5),
                                                      ),
                                                    ),
                                                    child: Center(
                                                      child: assetPath != null
                                                          ? Image.asset(
                                                              assetPath,
                                                              width: 38,
                                                              height: 38,
                                                              fit: BoxFit
                                                                  .contain,
                                                            )
                                                          : null,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      )
                                    : const SizedBox.shrink(),
                              ),

                              const SizedBox(height: 24),

                              // ── FORM TILES ──────────────────────────────────
                              GroupedListContainer(
                                width: double.infinity,
                                children: [
                                  GroupedTile.input(
                                    controller: _nameController,
                                    focusNode: _nameFocusNode,
                                    hintText: 'User Name',
                                    inputFormatters: [
                                      FilteringTextInputFormatter.deny(
                                        RegExp(r'(\u00a9|\u00ae|[\u2000-\u3300]|\ud83c[\ud000-\udfff]|\ud83d[\ud000-\udfff]|\ud83e[\ud000-\udfff])'),
                                      ),
                                    ],
                                  ),
                                  if (_isGoogleUser)
                                    GroupedTile.input(
                                      controller: _emailController,
                                      hintText: 'Email Address',
                                      isReadOnly: true,
                                      isEnabled: false,
                                      showVerifiedBadge: true,
                                      keyboardType: TextInputType.emailAddress,
                                    )
                                  else
                                    GroupedTile.keyValue(
                                      iconPath:
                                          'assets/icons/bottom_navigation/settings.svg',
                                      title: 'Account Type',
                                      value: 'Offline',
                                    ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // ── ACCOUNT STATUS & HELPER CARD ────────────────
                              if (_isGoogleUser)
                                GroupedListContainer(
                                  width: double.infinity,
                                  children: [
                                    GroupedTile.keyValue(
                                      iconPath: 'assets/icons/terms-info.svg',
                                      title: 'Account',
                                      value: 'Google Connected',
                                    ),
                                  ],
                                )
                              else
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  decoration: ShapeDecoration(
                                    color: const Color(0xFFF9F9FB),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      side: const BorderSide(
                                          color: Color(0x14000000), width: 1),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      SvgPicture.asset(
                                        'assets/icons/terms-info.svg',
                                        width: 16,
                                        height: 16,
                                        colorFilter: const ColorFilter.mode(
                                            Color(0xFF8E8E93), BlendMode.srcIn),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Your notes are stored locally on this device.',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w400,
                                            color: const Color(0xFF8E8E93),
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              const SizedBox(height: 36),

                              // ── SAVE BUTTON ─────────────────────────────────
                              TactileButton(
                                useAppleSpring: true,
                                onTap: _saveProfile,
                                child: Container(
                                  width: 160,
                                  height: 42,
                                  decoration: ShapeDecoration(
                                    color: primaryTextColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(21),
                                    ),
                                    shadows: const [
                                      BoxShadow(
                                        color: Color(0x26000000),
                                        blurRadius: 10,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Save',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              if (widget.isSetupFlow) ...[
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: _handleSkip,
                                  child: Text(
                                    'Skip for now',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF8E8E93),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildFallbackAvatar() {
    if (_selectedAvatarPath != null) {
      return Center(
        child: Image.asset(
          _selectedAvatarPath!,
          width: 72,
          height: 72,
          fit: BoxFit.contain,
        ),
      );
    }
    return const Center(
      child: Icon(Icons.person, size: 48, color: Color(0xFF8E8E93)),
    );
  }
}


