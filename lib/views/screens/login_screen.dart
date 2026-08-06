import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../controllers/login_controller.dart';
import '../../core/animations/page_transitions.dart';
import '../widgets/app_header_bar.dart';
import 'home_screen.dart';
import 'profile_test_screen.dart';
import 'welcome_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _controller = LoginController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerStateChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerStateChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerStateChanged() {
    if (!mounted) return;
    if (_controller.state == LoginUiState.error && _controller.errorMessage != null) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _controller.errorMessage!,
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
  }

  Future<void> _handleGoogleSignIn() async {
    HapticFeedback.lightImpact();
    final result = await _controller.handleGoogleSignIn();
    if (!mounted) return;

    switch (result) {
      case LoginResult.navigateToProfile:
        Navigator.of(context).pushReplacement(
          buildPageRoute(const ProfileScreen()),
        );
        break;
      case LoginResult.navigateToHome:
        Navigator.of(context).pushReplacement(
          buildPageRoute(const HomeScreen()),
        );
        break;
      case LoginResult.cancelled:
      case LoginResult.error:
        // Error shown via _onControllerStateChanged snackbar.
        break;
    }
  }

  Future<void> _handleOfflineSignIn() async {
    HapticFeedback.lightImpact();
    final result = await _controller.handleOfflineSignIn();
    if (result == LoginResult.navigateToHome && mounted) {
      Navigator.of(context).pushReplacement(
        buildPageRoute(const HomeScreen()),
      );
    }
  }

  void _handleBackToWelcome() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pushReplacement(
      buildPageRoute(const WelcomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFDF9), // Warm Paper Cream Surface
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, child) {
              final isLoading = _controller.state == LoginUiState.authenticatingGoogle ||
                  _controller.state == LoginUiState.initializingOffline;

              return Stack(
                children: [
                  // App Header Bar with Back Button (standardized with Folders screen)
                  Positioned(
                    left: 30.0,
                    right: 30.0,
                    top: 24.0,
                    child: AppHeaderBar(
                      leftWidth: 44.0,
                      onLeftTap: _handleBackToWelcome,
                      leftHeroTag: 'hero_login_back',
                      leftChild: SvgPicture.asset(
                        'assets/icons/angle_left.svg',
                        width: 22,
                        height: 22,
                        colorFilter: const ColorFilter.mode(
                          Color(0xFF333333),
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),

                  // Main Content: Brand Title & SignInOptions
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Centered Quick Notes Title
                        SizedBox(
                          width: 274,
                          height: 115,
                          child: Text(
                            'Quick\nNotes',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF333333),
                              fontSize: 48,
                              fontWeight: FontWeight.w700,
                              height: 1.12,
                              letterSpacing: -0.21,
                            ),
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.12),

                        // SignInOptions Widget Stack
                        _SignInOptions(
                          onGoogleTap: isLoading ? null : _handleGoogleSignIn,
                          onOfflineTap: isLoading ? null : _handleOfflineSignIn,
                        ),
                      ],
                    ),
                  ),

                  // Frosted Loading Overlay
                  if (isLoading)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.15),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF333333),
                            strokeWidth: 3.0,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SignInOptions extends StatelessWidget {
  final VoidCallback? onGoogleTap;
  final VoidCallback? onOfflineTap;

  const _SignInOptions({
    this.onGoogleTap,
    this.onOfflineTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 244,
      height: 114,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Continue with Google Button
          Positioned(
            left: 0,
            top: 0,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onGoogleTap,
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  width: 244,
                  height: 42,
                  clipBehavior: Clip.antiAlias,
                  decoration: ShapeDecoration(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'DesignCode/Welcome Screens/google.png',
                        width: 16,
                        height: 16,
                        fit: BoxFit.cover,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Continue with google',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF333333),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 2. Centered "or" Divider Text
          Positioned(
            left: 28,
            top: 42,
            child: SizedBox(
              width: 189,
              height: 30,
              child: Center(
                child: Text(
                  'or',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),

          // 3. Continue Offline Button
          Positioned(
            left: 0,
            top: 72,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onOfflineTap,
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  width: 244,
                  height: 42,
                  clipBehavior: Clip.antiAlias,
                  decoration: ShapeDecoration(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
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
                  child: Center(
                    child: Text(
                      'Continue Offline',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: const Color(0xFFFF383C), // Accents-Red
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
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
