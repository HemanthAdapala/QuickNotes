import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../controllers/splash_controller.dart';
import 'welcome_screen.dart';
import 'login_screen.dart';
import 'passcode_lock_screen.dart';
import 'profile_test_screen.dart';
import 'home_screen.dart';
import '../../core/animations/page_transitions.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  final SplashController _splashController = SplashController();

  @override
  void initState() {
    super.initState();
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
              buildPageRoute(const HomeScreen()),
            );
          },
        );
        break;
      case SplashDestination.profileCompletion:
        nextScreen = const ProfileScreen();
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFFFF),
        body: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SizedBox(
              width: 274,
              height: 121,
              child: Text(
                'Quick Notes',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: const Color(0xFF333333),
                  fontSize: 48,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.21,
                  height: 1.15,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
