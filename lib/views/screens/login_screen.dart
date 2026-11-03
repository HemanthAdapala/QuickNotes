import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../controllers/first_run_recovery_controller.dart';
import '../../controllers/login_controller.dart';
import '../../core/animations/page_transitions.dart';
import '../../services/recovery/first_run_recovery_state.dart';
import '../widgets/tactile_button.dart';
import 'first_run_recovery_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'welcome_screen.dart';

/// FirstRunRecoveryFlow — Observes recovery controller completion and replaces route with HomeScreen.
class FirstRunRecoveryFlow extends StatefulWidget {
  final FirstRunRecoveryResult recoveryResult;
  final FirstRunRecoveryController? controller;

  const FirstRunRecoveryFlow({
    super.key,
    required this.recoveryResult,
    this.controller,
  });

  @override
  State<FirstRunRecoveryFlow> createState() => _FirstRunRecoveryFlowState();
}

class _FirstRunRecoveryFlowState extends State<FirstRunRecoveryFlow> {
  late FirstRunRecoveryController _controller;
  bool _isLocal = false;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _isLocal = true;
      _controller =
          FirstRunRecoveryController(recoveryResult: widget.recoveryResult);
    }
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    if (_isLocal) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted || _hasNavigated) return;
    if (_controller.isCompleted) {
      _hasNavigated = true;
      Navigator.of(context).pushReplacement(
        buildPageRoute(const ProfileScreen(isSetupFlow: true)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FirstRunRecoveryScreen(
      recoveryResult: widget.recoveryResult,
      controller: _controller,
    );
  }
}

class LoginScreen extends StatefulWidget {
  final LoginController? controller;

  const LoginScreen({super.key, this.controller});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final LoginController _controller;
  bool _isLocalController = false;
  Animation<double>? _routeAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _isLocalController = true;
      _controller = LoginController();
    }
    _controller.addListener(_onControllerStateChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    final animation = route?.animation;
    if (animation != _routeAnimation) {
      _routeAnimation?.removeStatusListener(_handleRouteStatusChange);
      _routeAnimation = animation;
      if (_routeAnimation != null) {
        if (_routeAnimation!.isCompleted) {
          _schedulePostTransitionRepaint();
        } else {
          _routeAnimation!.addStatusListener(_handleRouteStatusChange);
        }
      }
    }
  }

  void _handleRouteStatusChange(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _routeAnimation?.removeStatusListener(_handleRouteStatusChange);
      _schedulePostTransitionRepaint();
    }
  }

  void _schedulePostTransitionRepaint() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_handleRouteStatusChange);
    _controller.removeListener(_onControllerStateChanged);
    if (_isLocalController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onControllerStateChanged() {
    if (!mounted) return;
    if (_controller.state == LoginUiState.error &&
        _controller.errorMessage != null) {
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
      case LoginResult.navigateToRecovery:
        Navigator.of(context).pushReplacement(
          buildPageRoute(
            FirstRunRecoveryFlow(
              recoveryResult: _controller.recoveryResult!,
            ),
          ),
        );
        break;
      case LoginResult.navigateToProfile:
        Navigator.of(context).pushReplacement(
          buildPageRoute(const ProfileScreen(isSetupFlow: true)),
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
    if (!mounted) return;
    if (result == LoginResult.navigateToProfile) {
      Navigator.of(context).pushReplacement(
        buildPageRoute(const ProfileScreen(isSetupFlow: true)),
      );
    } else if (result == LoginResult.navigateToHome) {
      Navigator.of(context).pushReplacement(
        buildPageRoute(const HomeScreen()),
      );
    }
  }

  void _handleBackToWelcome() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        buildPageRoute(const WelcomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness:
            isDark ? Brightness.dark : Brightness.light,
      ),
      child: ColoredBox(
        color: isDark
            ? const Color(0xFF1E1E1E)
            : const Color(0xFFFFFDF9),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
          children: [
            // ── Ambient Color Glows (for Liquid Glass refraction) ──
            Positioned(
              top: screenHeight * 0.15,
              right: -30,
              child: Container(
                width: 200,
                height: 200,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x1CFFAAA6), // Soft Coral Glow
                      blurRadius: 100,
                      spreadRadius: 50,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: screenHeight * 0.10,
              left: -40,
              child: Container(
                width: 220,
                height: 220,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x22FFCC00), // Amber Yellow Glow
                      blurRadius: 100,
                      spreadRadius: 50,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: screenHeight * 0.02,
              right: -20,
              child: Container(
                width: 180,
                height: 180,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x156366F1), // Soft Indigo Glow
                      blurRadius: 90,
                      spreadRadius: 40,
                    ),
                  ],
                ),
              ),
            ),

            // ── Scrollable body content ──────────────────────────────
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Top Header Block
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 72),
                                const SizedBox(height: 32),
                                Text(
                                  'Welcome to\nQuick Notes',
                                  style: GoogleFonts.inter(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF1E1E1E),
                                    height: 1.2,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Sign in to sync your notes across devices, or continue offline on this device.',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    color: isDark
                                        ? const Color(0xFF8E8E93)
                                        : const Color(0xFF757575),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),

                            // Bottom Buttons & Footer Block
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                AnimatedBuilder(
                                  animation: _controller,
                                  builder: (context, child) {
                                    final isGoogleLoading = _controller.state ==
                                        LoginUiState.authenticatingGoogle;
                                    final isOfflineLoading =
                                        _controller.state ==
                                            LoginUiState.initializingOffline;

                                    return Column(
                                      children: [
                                        // ── Circular Back Button ───────────────────────
                                        TactileButton(
                                          useAppleSpring: true,
                                          onTap: (isGoogleLoading ||
                                                  isOfflineLoading)
                                              ? () {}
                                              : _handleBackToWelcome,
                                          child: Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? const Color(0xFF38383A)
                                                  : Colors.white,
                                              shape: BoxShape.circle,
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: Color(0x14000000),
                                                  blurRadius: 12,
                                                  offset: Offset(0, 4),
                                                ),
                                                BoxShadow(
                                                  color: Color(0x0A000000),
                                                  blurRadius: 4,
                                                  offset: Offset(0, 1),
                                                ),
                                              ],
                                              border: Border.all(
                                                color: isDark
                                                    ? const Color(0xFF38383A)
                                                    : const Color(0xFFE2E2DF),
                                                width: 1.0,
                                              ),
                                            ),
                                            child: Center(
                                              child: SvgPicture.asset(
                                                'assets/icons/angle_left.svg',
                                                width: 20,
                                                height: 20,
                                                colorFilter: ColorFilter.mode(
                                                  isDark
                                                      ? Colors.white
                                                      : const Color(0xFF333333),
                                                  BlendMode.srcIn,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 24),

                                        // ── Google Sign-In Button ─────────────────────
                                        ElevatedButton(
                                          onPressed: (isGoogleLoading ||
                                                  isOfflineLoading)
                                              ? null
                                              : _handleGoogleSignIn,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isDark
                                                ? Colors.white
                                                : const Color(0xFF1E1E1E),
                                            foregroundColor: isDark
                                                ? const Color(0xFF1C1C1E)
                                                : Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 16),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                          ),
                                          child: isGoogleLoading
                                              ? SizedBox(
                                                  height: 20,
                                                  width: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                                Color>(
                                                      isDark
                                                          ? const Color(0xFF1C1C1E)
                                                          : Colors.white,
                                                    ),
                                                  ),
                                                )
                                              : Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Image.asset(
                                                      'assets/icons/google.png',
                                                      width: 20,
                                                      height: 20,
                                                      fit: BoxFit.contain,
                                                      errorBuilder: (context,
                                                              error,
                                                              stackTrace) =>
                                                          const SizedBox(
                                                        width: 20,
                                                        height: 20,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Text(
                                                      'Continue with Google',
                                                      style: GoogleFonts.inter(
                                                        color: isDark
                                                            ? const Color(0xFF1C1C1E)
                                                            : Colors.white,
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                        ),
                                        const SizedBox(height: 16),

                                        // ── Continue Offline Button (Plain White with Shadow) ──
                                        TactileButton(
                                          useAppleSpring: true,
                                          onTap: (isGoogleLoading ||
                                                  isOfflineLoading)
                                              ? () {}
                                              : _handleOfflineSignIn,
                                          child: Container(
                                            width: 170,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? const Color(0xFF38383A)
                                                  : Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(25),
                                              border: Border.all(
                                                color: isDark
                                                    ? const Color(0xFF38383A)
                                                    : const Color(0xFFE2E2DF),
                                                width: 1.0,
                                              ),
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: Color(0x14000000),
                                                  blurRadius: 12,
                                                  offset: Offset(0, 4),
                                                ),
                                                BoxShadow(
                                                  color: Color(0x0A000000),
                                                  blurRadius: 4,
                                                  offset: Offset(0, 1),
                                                ),
                                              ],
                                            ),
                                            child: Center(
                                              child: isOfflineLoading
                                                  ? SizedBox(
                                                      height: 20,
                                                      width: 20,
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        valueColor:
                                                            AlwaysStoppedAnimation<
                                                                    Color>(
                                                          isDark
                                                              ? Colors.white
                                                              : const Color(0xFF333333),
                                                        ),
                                                      ),
                                                    )
                                                  : Text(
                                                      'Continue Offline',
                                                      style: GoogleFonts.inter(
                                                        color: isDark
                                                            ? Colors.white
                                                            : const Color(
                                                                0xFF333333),
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        letterSpacing: -0.3,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 32),
                                Text(
                                  'By continuing, you agree to our Terms of Service and Privacy Policy.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: isDark
                                        ? const Color(0xFF8E8E93)
                                        : const Color(0xFF9E9E9E),
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ],
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
  );
  }
}

