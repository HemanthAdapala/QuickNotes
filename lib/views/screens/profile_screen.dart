import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/animations/page_transitions.dart';
import '../../core/avatar_registry.dart';
import '../../data/sqlite_profile_repository.dart';
import '../../models/session_type.dart';
import '../../models/user_profile.dart';
import '../../repositories/user_repository.dart';
import '../../services/session_manager.dart';
import '../widgets/app_bottom_navigation_bar.dart';
import '../widgets/tactile_button.dart';
import 'home_screen.dart';

/// ProfileScreen — Handles both first-time profile creation and profile editing.
///
/// On first-time setup (navigated from LoginController):
/// - Pre-populated with Google account displayName and email from [UserRepository.currentUser].
/// - Save creates a new [UserProfile] via [SqliteProfileRepository] and navigates to HomeScreen.
///
/// On edit (navigated from Homescreen profile icon or Settings):
/// - Pre-populated with existing [UserProfile] data.
/// - Save upserts via [SqliteProfileRepository] and pops back.
///
/// ProfileScreen never performs authentication or calls Google APIs.
/// All data resolution goes through [UserRepository] and [SqliteProfileRepository].
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  late FocusNode _usernameFocusNode;
  late FocusNode _emailFocusNode;

  bool _isEditGridOpen = false;
  int? _selectedAvatarIndex;

  /// Logical avatar ID (e.g. "andre") stored in DB.
  /// Resolved to asset path via AvatarRegistry.assetPath().
  String? _selectedAvatarId;
  String? _selectedAvatarPath;

  bool _isLoading = true;
  bool _isAssetsPrecached = false;
  bool _isFirstTimeSetup = false; // true when no profile exists yet
  bool _isGoogleUser = false; // true when user authenticated via Google

  /// All available avatar logical IDs. Resolved to asset paths via AvatarRegistry.
  static const List<String> _profileIconIds = AvatarRegistry.allIds;

  static const List<String> _profileIconAssets = [
    'assets/Profile Icons/andre_transparent.png',
    'assets/Profile Icons/ashton_transparent.png',
    'assets/Profile Icons/babs_transparent.png',
    'assets/Profile Icons/brad_transparent.png',
    'assets/Profile Icons/brini_transparent.png',
    'assets/Profile Icons/camilla_transparent.png',
    'assets/Profile Icons/charlotte_transparent.png',
    'assets/Profile Icons/clara_transparent.png',
    'assets/Profile Icons/efron_transparent.png',
    'assets/Profile Icons/elsa_transparent.png',
    'assets/Profile Icons/elvira_transparent.png',
    'assets/Profile Icons/fini_transparent.png',
    'assets/Profile Icons/gene_transparent.png',
    'assets/Profile Icons/greggy_transparent.png',
    'assets/Profile Icons/greta_transparent.png',
    'assets/Profile Icons/hanna_transparent.png',
    'assets/Profile Icons/lars_transparent.png',
    'assets/Profile Icons/laura_transparent.png',
    'assets/Profile Icons/leni_transparent.png',
    'assets/Profile Icons/ludmilla_transparent.png',
    'assets/Profile Icons/luisa_transparent.png',
    'assets/Profile Icons/marnie_transparent.png',
    'assets/Profile Icons/maxim_transparent.png',
    'assets/Profile Icons/nicola_transparent.png',
    'assets/Profile Icons/paul_transparent.png',
    'assets/Profile Icons/phichi_transparent.png',
    'assets/Profile Icons/pitta_transparent.png',
    'assets/Profile Icons/raul_transparent.png',
    'assets/Profile Icons/reana_transparent.png',
    'assets/Profile Icons/sam_transparent.png',
    'assets/Profile Icons/saskia_transparent.png',
    'assets/Profile Icons/serj_transparent.png',
    'assets/Profile Icons/theo_transparent.png',
    'assets/Profile Icons/tzu-yung_transparent.png',
  ];

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _emailController = TextEditingController();
    _usernameFocusNode = FocusNode();
    _emailFocusNode = FocusNode();

    _usernameFocusNode.addListener(_onFieldFocus);
    _emailFocusNode.addListener(_onFieldFocus);
    _usernameController.addListener(_onTextChanged);
    _emailController.addListener(_onTextChanged);

    _loadProfileData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isAssetsPrecached) {
      _isAssetsPrecached = true;
      for (final assetPath in _profileIconAssets) {
        precacheImage(AssetImage(assetPath), context);
      }
    }
  }

  void _onFieldFocus() {
    if ((_usernameFocusNode.hasFocus || _emailFocusNode.hasFocus) && _isEditGridOpen) {
      setState(() {
        _isEditGridOpen = false;
      });
    }
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _usernameFocusNode.removeListener(_onFieldFocus);
    _emailFocusNode.removeListener(_onFieldFocus);
    _usernameController.removeListener(_onTextChanged);
    _emailController.removeListener(_onTextChanged);

    _usernameFocusNode.dispose();
    _emailFocusNode.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    final currentUser = UserRepository().currentUser;
    final sessionType = SessionManager().activeSessionType;
    final prefs = await SharedPreferences.getInstance();
    final savedSessionType = prefs.getString('session_type');

    final profileRepo = SqliteProfileRepository();
    final existingProfile = currentUser != null
        ? await profileRepo.getProfileForUser(currentUser.id)
        : null;

    final isGoogle = (currentUser != null && currentUser.sessionType == SessionType.google) ||
        (sessionType == SessionType.google) ||
        (savedSessionType == 'google');

    setState(() {
      _isGoogleUser = isGoogle;
      _isFirstTimeSetup = existingProfile == null && prefs.getString('profile_username') == null;

      if (existingProfile != null) {
        // Editing existing profile
        _usernameController.text = existingProfile.displayName;
        _emailController.text = existingProfile.email;
        _selectedAvatarId = existingProfile.avatarId;
        if (_selectedAvatarId != null) {
          _selectedAvatarIndex = _profileIconIds.indexOf(_selectedAvatarId!);
          _selectedAvatarPath = AvatarRegistry.assetPath(_selectedAvatarId!);
        }
      } else if (currentUser != null) {
        // First-time setup — pre-populate from Google account data
        _usernameController.text = currentUser.displayName;
        _emailController.text = currentUser.email;
      } else {
        _usernameController.text = prefs.getString('profile_username') ?? prefs.getString('profile_full_name') ?? 'Hemanth Adapala';
        _emailController.text = prefs.getString('profile_email') ?? 'JohnDoe@gmail.com';
        _selectedAvatarPath = prefs.getString('profile_avatar_path');
        if (_selectedAvatarPath != null) {
          _selectedAvatarIndex = _profileIconAssets.indexOf(_selectedAvatarPath!);
        }
      }

      _isLoading = false;
    });
  }

  Future<void> _saveProfileData() async {
    HapticFeedback.mediumImpact();

    final currentUser = UserRepository().currentUser;
    if (currentUser != null) {
      final now = DateTime.now();
      final existingProfile = await SqliteProfileRepository()
          .getProfileForUser(currentUser.id);

      final profile = UserProfile(
        userId: currentUser.id,
        displayName: _usernameController.text.trim().isEmpty
            ? currentUser.displayName
            : _usernameController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? currentUser.email
            : _emailController.text.trim(),
        avatarId: _selectedAvatarId ?? 'andre',
        createdAt: existingProfile?.createdAt ?? now,
        updatedAt: now,
      );

      await SqliteProfileRepository().saveProfile(profile);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_username', _usernameController.text.trim());
    await prefs.setString('profile_full_name', _usernameController.text.trim());
    await prefs.setString('profile_email', _emailController.text.trim());
    if (_selectedAvatarPath != null) {
      await prefs.setString('profile_avatar_path', _selectedAvatarPath!);
    }

    if (!mounted) return;

    if (_isFirstTimeSetup) {
      Navigator.of(context).pushReplacement(
        buildPageRoute(const HomeScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
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
      Navigator.of(context).maybePop();
    }
  }

  void _toggleGrid() {
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();
    setState(() {
      _isEditGridOpen = !_isEditGridOpen;
    });
  }

  @override
  Widget build(BuildContext context) {
    const primaryTextColor = Color(0xFF333333);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: primaryTextColor))
            : Stack(
                children: [
                  // Scrollable Content (placed FIRST so Back button renders on top)
                  Positioned.fill(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(top: 76.0, bottom: 100.0),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),

                          // Main Avatar Circle (100x100) with Camera Badge
                          Center(
                            child: TactileButton(
                              useAppleSpring: true,
                              compressionScale: 0.92,
                              onTap: _toggleGrid,
                              child: SizedBox(
                                width: 100,
                                height: 100,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    // Main Avatar Circle
                                    Container(
                                      width: 100,
                                      height: 100,
                                      decoration: const ShapeDecoration(
                                        color: Colors.white,
                                        shape: OvalBorder(
                                          side: BorderSide(color: Color(0x1F3C3C43), width: 1),
                                        ),
                                        shadows: [
                                          BoxShadow(
                                            color: Color(0x1A000000),
                                            blurRadius: 10,
                                            offset: Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: _selectedAvatarPath != null
                                          ? Center(
                                              child: Image.asset(
                                                _selectedAvatarPath!,
                                                width: 75,
                                                height: 75,
                                                fit: BoxFit.contain,
                                              ),
                                            )
                                          : null,
                                    ),

                                    // Camera Overlay Badge at bottom-right (26x26)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 26,
                                        height: 26,
                                        decoration: const ShapeDecoration(
                                          color: Colors.white,
                                          shape: OvalBorder(
                                            side: BorderSide(color: Color(0x1F3C3C43), width: 0.5),
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
                                            colorFilter: const ColorFilter.mode(primaryTextColor, BlendMode.srcIn),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Continuous GPU-Cached Expandable Grid Container
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutCubic,
                            width: 322,
                            height: _isEditGridOpen ? 407 : 0,
                            margin: EdgeInsets.only(top: _isEditGridOpen ? 20.0 : 0.0),
                            padding: EdgeInsets.all(_isEditGridOpen ? 12 : 0),
                            clipBehavior: Clip.antiAlias,
                            decoration: ShapeDecoration(
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              shadows: _isEditGridOpen
                                  ? const [
                                      BoxShadow(
                                        color: Color(0x1F000000),
                                        blurRadius: 16,
                                        offset: Offset(0, 4),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: OverflowBox(
                              minHeight: 407,
                              maxHeight: 407,
                              alignment: Alignment.topCenter,
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  children: [
                                    // Guidance Microcopy Header
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
                                      child: Text(
                                        'Choose your Profile Character',
                                        style: GoogleFonts.inter(
                                          color: const Color(0x803C3C43),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: GridView.builder(
                                        physics: const NeverScrollableScrollPhysics(),
                                        shrinkWrap: true,
                                        padding: const EdgeInsets.all(5),
                                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 5,
                                          mainAxisSpacing: 10,
                                          crossAxisSpacing: 10,
                                          childAspectRatio: 54.4 / 43.85,
                                        ),
                                        itemCount: _profileIconAssets.length,
                                        itemBuilder: (context, index) {
                                          final isSelected = _selectedAvatarIndex == index;
                                          final assetPath = _profileIconAssets[index];

                                          return TactileButton(
                                            useAppleSpring: true,
                                            compressionScale: 0.85,
                                            onTap: () {
                                              HapticFeedback.selectionClick();
                                              setState(() {
                                                _selectedAvatarIndex = index;
                                                _selectedAvatarPath = assetPath;
                                                if (index < _profileIconIds.length) {
                                                  _selectedAvatarId = _profileIconIds[index];
                                                }
                                              });
                                            },
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 200),
                                              curve: Curves.easeOutCubic,
                                              decoration: ShapeDecoration(
                                                color: isSelected ? const Color(0xFFF2F2F7) : Colors.transparent,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                  side: isSelected
                                                      ? const BorderSide(color: Color(0xFF333333), width: 1.5)
                                                      : BorderSide.none,
                                                ),
                                              ),
                                              child: Center(
                                                child: Image.asset(
                                                  assetPath,
                                                  width: 36,
                                                  height: 36,
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Username & Email Card (322px wide)
                          Center(
                            child: Container(
                              width: 322,
                              clipBehavior: Clip.antiAlias,
                              decoration: ShapeDecoration(
                                color: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(26),
                                ),
                                shadows: const [
                                  BoxShadow(
                                    color: Color(0x1A000000),
                                    blurRadius: 12,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Username Row with live TextField & clear (x) button
                                  Container(
                                    width: double.infinity,
                                    height: 52,
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _usernameController,
                                            focusNode: _usernameFocusNode,
                                            style: GoogleFonts.inter(
                                              color: primaryTextColor,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                              letterSpacing: -0.3,
                                            ),
                                            decoration: InputDecoration(
                                              hintText: 'Username',
                                              hintStyle: GoogleFonts.inter(
                                                color: const Color(0x4C3C3C43),
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500,
                                                letterSpacing: -0.3,
                                              ),
                                              border: InputBorder.none,
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                          ),
                                        ),
                                        if (_usernameController.text.isNotEmpty)
                                          GestureDetector(
                                            onTap: () {
                                              HapticFeedback.lightImpact();
                                              _usernameController.clear();
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.only(left: 8.0),
                                              child: Icon(
                                                Icons.cancel,
                                                size: 18,
                                                color: const Color(0xFF3C3C43).withValues(alpha: 0.3),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),

                                  // Separator Line
                                  Container(
                                    width: double.infinity,
                                    height: 1,
                                    margin: const EdgeInsets.symmetric(horizontal: 16),
                                    color: const Color(0xFFE6E6E6),
                                  ),

                                  // Email Row with TextField (disabled if Google User) & Check Icon (Verified) or Clear (x) button
                                  Container(
                                    width: double.infinity,
                                    height: 52,
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _emailController,
                                            focusNode: _emailFocusNode,
                                            readOnly: _isGoogleUser,
                                            enabled: !_isGoogleUser,
                                            keyboardType: TextInputType.emailAddress,
                                            style: GoogleFonts.inter(
                                              color: _isGoogleUser
                                                  ? primaryTextColor.withValues(alpha: 0.6)
                                                  : primaryTextColor,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                              letterSpacing: -0.3,
                                            ),
                                            decoration: InputDecoration(
                                              hintText: 'Email',
                                              hintStyle: GoogleFonts.inter(
                                                color: const Color(0x4C3C3C43),
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500,
                                                letterSpacing: -0.3,
                                              ),
                                              border: InputBorder.none,
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                          ),
                                        ),
                                        if (_isGoogleUser)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 8.0),
                                            child: Image.asset(
                                              'assets/icons/check.png',
                                              width: 18,
                                              height: 18,
                                              fit: BoxFit.contain,
                                            ),
                                          )
                                        else if (_emailController.text.isNotEmpty)
                                          GestureDetector(
                                            onTap: () {
                                              HapticFeedback.lightImpact();
                                              _emailController.clear();
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.only(left: 8.0),
                                              child: Icon(
                                                Icons.cancel,
                                                size: 18,
                                                color: const Color(0xFF3C3C43).withValues(alpha: 0.3),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Top Left Glass Back Button (placed LAST so it renders ON TOP of scroll view)
                  if (!_isFirstTimeSetup)
                    Positioned(
                      left: 24,
                      top: 12,
                      child: BottomBarGlassSurface(
                        width: 44.0,
                        height: 44.0,
                        borderRadius: BorderRadius.circular(22.0),
                        child: TactileButton(
                          useAppleSpring: true,
                          compressionScale: 0.7,
                          settleDuration: const Duration(milliseconds: 1000),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.of(context).maybePop();
                          },
                          child: Center(
                            child: SvgPicture.asset(
                              'assets/icons/angle_left.svg',
                              width: 22,
                              height: 22,
                              colorFilter: const ColorFilter.mode(primaryTextColor, BlendMode.srcIn),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Save Button pinned near bottom center
                  Positioned(
                    bottom: 32,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: TactileButton(
                        useAppleSpring: true,
                        onTap: _saveProfileData,
                        child: Container(
                          width: 150,
                          height: 38,
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
                              )
                            ],
                          ),
                          child: Center(
                            child: Text(
                              _isFirstTimeSetup ? 'Continue' : 'Save',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                color: primaryTextColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                height: 0.88,
                                letterSpacing: -0.43,
                              ),
                            ),
                          ),
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
