import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../controllers/splash_controller.dart';
import 'welcome_screen.dart';
import 'login_screen.dart';
import 'passcode_lock_screen.dart';
import 'profile_screen.dart';
import 'home_screen.dart';
import '../../core/animations/page_transitions.dart';

class SplashScreen extends StatefulWidget {
  final SplashController? splashController;

  const SplashScreen({super.key, this.splashController});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late final SplashController _splashController;

  @override
  void initState() {
    super.initState();
    _splashController = widget.splashController ?? SplashController();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _fadeController.forward();
    _initializeApp();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    final destination = await _splashController.initializeAndDetermineDestination();
    if (!mounted) return;

    Widget nextScreen;
    switch (destination) {
      case SplashDestination.onboarding:
        nextScreen = const WelcomeScreen();
        break;
      case SplashDestination.login:
        nextScreen = const LoginScreen();
        break;
      case SplashDestination.passcodeLock:
        nextScreen = PasscodeLockScreen(
          purpose: LockPurpose.appUnlock,
          onSuccess: () {
            Navigator.of(context).pushReplacement(
              buildPageRoute(
                _splashController.recoveryResult != null &&
                        _splashController.recoveryResult!.isEligible
                    ? FirstRunRecoveryFlow(
                        recoveryResult: _splashController.recoveryResult!,
                      )
                    : const HomeScreen(),
              ),
            );
          },
        );
        break;
      case SplashDestination.profileCompletion:
        nextScreen = const ProfileScreen();
        break;
      case SplashDestination.recovery:
        nextScreen = FirstRunRecoveryFlow(
          recoveryResult: _splashController.recoveryResult!,
        );
        break;
      case SplashDestination.home:
        nextScreen = const HomeScreen();
        break;
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      buildPageRoute(nextScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFFFF),
        body: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: screenHeight * 0.35,
              child: Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SizedBox(
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
