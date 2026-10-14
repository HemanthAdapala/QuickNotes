import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

import '../../controllers/splash_controller.dart';
import '../../core/animations/page_transitions.dart';
import '../../providers/settings_provider.dart';
import '../../services/deep_link_coordinator.dart';
import '../../services/splash_animation_resolver.dart';
import 'welcome_screen.dart';
import 'login_screen.dart';
import 'passcode_lock_screen.dart';
import 'profile_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  final SplashController? splashController;
  final bool? isNotesTab;

  const SplashScreen({
    super.key,
    this.splashController,
    this.isNotesTab,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final SplashController _splashController;
  final Completer<void> _animCompleter = Completer<void>();
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _splashController = widget.splashController ?? SplashController();

    // The designer-provided Lottie animations run for 85 frames at 60 fps (1,417 ms).
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1417),
    );

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (!_animCompleter.isCompleted) {
          _animCompleter.complete();
        }
      }
    });

    _animController.forward();
    _initializeApp();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  bool _resolveIsNotesTab(BuildContext context) {
    if (widget.isNotesTab != null) return widget.isNotesTab!;

    // 1. Check if there is an explicit cold-launch deep-link targeting Tasks
    final pendingAction = DeepLinkCoordinator.instance.pendingAction;
    if (pendingAction != null) {
      if (pendingAction.type == DeepLinkActionType.openTask ||
          pendingAction.type == DeepLinkActionType.openTasks) {
        return false;
      }
    }

    // 2. Otherwise restore from persisted tab selection in SettingsProvider
    try {
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      return settings.lastActiveTab != 'tasks';
    } catch (_) {
      return true; // Safe default to Notes
    }
  }

  Future<void> _initializeApp() async {
    SplashDestination destination = SplashDestination.home;
    try {
      // 1. Run startup initialization concurrently with animation playback
      destination =
          await _splashController.initializeAndDetermineDestination(
        minDisplayDuration: Duration.zero,
      );
    } catch (e) {
      debugPrint('SplashScreen initialization error: $e');
      destination = SplashDestination.home;
    }

    // 2. Await animation completion so we never navigate before the animation ends
    if (!_animCompleter.isCompleted) {
      await _animCompleter.future;
    }

    // 3. Prevent duplicate navigation or navigation after unmount
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;

    _navigate(destination);
  }

  void _navigate(SplashDestination destination) {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isNotes = _resolveIsNotesTab(context);

    final assetPath = SplashAnimationResolver.resolve(
      isNotesTab: isNotes,
      isDarkMode: isDark,
    );

    // #343434 matches Layer 14 of Dark Lottie animations; #FFFFFF matches Light
    final backgroundColor =
        isDark ? const Color(0xFF343434) : const Color(0xFFFFFFFF);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness:
            isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: backgroundColor,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Responsive full-screen background layer covering entire physical screen edge-to-edge
            ColoredBox(color: backgroundColor),
            // Centered Lottie animation preserving aspect ratio, timing, and blur delegates
            Center(
              child: SizedBox.expand(
                child: Lottie.asset(
                  assetPath,
                  controller: _animController,
                  fit: BoxFit.cover,
                  delegates: LottieDelegates(
                    values: [
                      ValueDelegate.blurRadius(
                        const ['Small', '**'],
                        callback: (info) => 350.0 + (info.overallProgress * 0.01),
                      ),
                      ValueDelegate.blurRadius(
                        const ['Medium', '**'],
                        callback: (info) => 350.0 + (info.overallProgress * 0.01),
                      ),
                      ValueDelegate.blurRadius(
                        const ['Large', '**'],
                        callback: (info) => 350.0 + (info.overallProgress * 0.01),
                      ),
                    ],
                  ),
                  onLoaded: (composition) {
                    _animController.duration = composition.duration;
                    if (!_animController.isAnimating &&
                        !_animController.isCompleted) {
                      _animController.forward();
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
