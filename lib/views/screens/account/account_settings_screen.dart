import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../controllers/account_controller.dart';
import '../../../core/animations/page_transitions.dart';
import '../../widgets/tactile_button.dart';
import '../../widgets/app_bottom_navigation_bar.dart';
import '../../widgets/grouped_list_container.dart';
import '../login_screen.dart';
import 'account_profile_screen.dart';
import 'delete_account_screen.dart';

const String _googleLogoSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
  <path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
  <path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>
  <path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>
  <path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>
</svg>
''';

class AccountSettingsScreen extends StatefulWidget {
  final AccountController? controller;

  const AccountSettingsScreen({super.key, this.controller});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  late final AccountController _controller;
  bool _isLocalController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _isLocalController = true;
      _controller = AccountController();
    }
    _controller.addListener(_onControllerStateChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerStateChanged);
    if (_isLocalController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onControllerStateChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _handleGoogleSignIn() async {
    HapticFeedback.lightImpact();
    final result = await _controller.signInWithGoogle();
    if (!mounted) return;

    switch (result.action) {
      case AccountLinkAction.navigateToRecovery:
        Navigator.of(context).pushReplacement(
          buildPageRoute(
            FirstRunRecoveryFlow(
              recoveryResult: result.recoveryResult!,
            ),
          ),
        );
        break;

      case AccountLinkAction.conflict:
        _showConflictDialog(result);
        break;

      case AccountLinkAction.error:
        if (result.errorMessage != null) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.errorMessage!,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF333333),
              duration: const Duration(seconds: 4),
            ),
          );
        }
        break;

      case AccountLinkAction.cancelled:
      case AccountLinkAction.success:
        break;
    }
  }

  void _showConflictDialog(AccountLinkResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          "Existing Account Found",
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF333333),
            fontSize: 18,
          ),
        ),
        content: Text(
          "This Google account is already linked to another Quick Notes account.\n\nYou can switch to that account, or stay with your current offline account.",
          style: GoogleFonts.inter(
            color: const Color(0xFF333333).withValues(alpha: 0.8),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actionsPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              _controller.cancelConflict();
              Navigator.pop(ctx);
            },
            child: Text(
              "Cancel",
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF8E8E93),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              HapticFeedback.mediumImpact();
              Navigator.pop(ctx);
              final switched =
                  await _controller.switchAccountToConflictingUser();
              if (mounted && switched) {
                setState(() {});
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E1E1E),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              "Switch Account",
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
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
    const backgroundColor = Color(0xFFF2F2F7);

    final isOffline = _controller.isOffline;
    final isSigningIn = _controller.state == AccountUiState.signingIn;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Row(
                children: [
                  TactileButton(
                    useAppleSpring: true,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    child: BottomBarGlassSurface(
                      width: 40,
                      height: 40,
                      borderRadius: BorderRadius.circular(20),
                      child: Center(
                        child: SvgPicture.asset(
                          'assets/icons/angle_left.svg',
                          width: 18,
                          height: 18,
                          colorFilter: const ColorFilter.mode(
                              primaryTextColor, BlendMode.srcIn),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      "Account",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: primaryTextColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.43,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40), // Balance left back button space
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
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── ACCOUNT BANNER / CARD ─────────────────────────────
                      if (isOffline) ...[
                        // State A: Offline Account
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9F9FB),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                                color: const Color(0xFFE5E5EA), width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE5E5EA),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.cloud_off_rounded,
                                        size: 20,
                                        color: Color(0xFF8E8E93),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    "Offline Account",
                                    style: GoogleFonts.inter(
                                      color: primaryTextColor,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "Your notes are stored on this device.\nSign in with Google to connect this account and enable cloud backup.",
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF666666),
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 18),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed:
                                      isSigningIn ? null : _handleGoogleSignIn,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E1E1E),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: isSigningIn
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white),
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            SvgPicture.string(
                                              _googleLogoSvg,
                                              width: 18,
                                              height: 18,
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              'Sign in with Google',
                                              style: GoogleFonts.inter(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // State B: Authenticated User
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9F9FB),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                                color: const Color(0xFFE5E5EA), width: 1),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE5E5EA),
                                  shape: BoxShape.circle,
                                  image: _controller.photoUrl != null &&
                                          _controller.photoUrl!.isNotEmpty
                                      ? DecorationImage(
                                          image: NetworkImage(
                                              _controller.photoUrl!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: _controller.photoUrl == null ||
                                        _controller.photoUrl!.isEmpty
                                    ? const Center(
                                        child: Icon(
                                          Icons.person_rounded,
                                          size: 28,
                                          color: Color(0xFF8E8E93),
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _controller.displayName,
                                      style: GoogleFonts.inter(
                                        color: primaryTextColor,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            _controller.email,
                                            style: GoogleFonts.inter(
                                              color: const Color(0xFF8E8E93),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          size: 14,
                                          color: Color(0xFF34C759),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8F5E9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SvgPicture.string(_googleLogoSvg,
                                              width: 12, height: 12),
                                          const SizedBox(width: 6),
                                          Text(
                                            "Google Account Connected",
                                            style: GoogleFonts.inter(
                                              color: const Color(0xFF2E7D32),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24.0),

                      // ── GROUPED TILES ─────────────────────────────────────
                      GroupedListContainer(
                        children: [
                          GroupedTile.navigation(
                            iconPath:
                                'assets/icons/bottom_navigation/settings.svg',
                            title: 'Profile',
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.push(
                                context,
                                buildPageRoute(const AccountProfileScreen()),
                              );
                            },
                          ),
                          GroupedTile.navigation(
                            iconPath: 'assets/icons/trash.svg',
                            title: 'Delete your data and account',
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.push(
                                context,
                                buildPageRoute(const DeleteAccountScreen()),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
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
