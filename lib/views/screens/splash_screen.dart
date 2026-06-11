import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../themes/quick_notes_theme.dart';
import 'onboarding_screen.dart';
import 'passcode_lock_screen.dart';
import 'navigation_shell.dart';

import 'package:provider/provider.dart';
import '../../providers/notes_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  final _secureStorage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _controller.forward();
    _startTimer();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startTimer() {
    Timer(const Duration(milliseconds: 2500), _navigateToNextScreen);
  }

  Future<void> _navigateToNextScreen() async {
    if (!mounted) return;

    // Read onboarding status
    final onboardingDone = await _secureStorage.read(key: 'has_completed_onboarding');
    final appLockEnabled = await _secureStorage.read(key: 'app_lock_enabled') == 'true';
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);

    Widget nextScreen;
    if (onboardingDone != 'true') {
      nextScreen = const OnboardingScreen();
    } else if (appLockEnabled) {
      nextScreen = PasscodeLockScreen(
        purpose: LockPurpose.appUnlock,
        onSuccess: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => NavigationShell(
                onThemeToggle: notesProvider.toggleTheme,
                isDarkMode: notesProvider.isDarkMode,
              ),
            ),
          );
        },
      );
    } else {
      nextScreen = NavigationShell(
        onThemeToggle: notesProvider.toggleTheme,
        isDarkMode: notesProvider.isDarkMode,
      );
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: QuickNotesTheme.background,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Stylized premium QuickNotes logo
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: QuickNotesTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: QuickNotesTheme.border, width: 1.5),
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  color: QuickNotesTheme.accent,
                  size: 60,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "QuickNotes",
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "LUXURY PRODUCTIVITY",
                style: theme.textTheme.labelMedium?.copyWith(
                  color: QuickNotesTheme.textSecondary,
                  letterSpacing: 3.0,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
