import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import '../../services/session_manager.dart';
import '../../core/animations/page_transitions.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _floatController;
  late AnimationController _arrowController;

  // Staggered offscreen entrance animations
  late Animation<double> _leftCardsFade;
  late Animation<Offset> _leftCardsSlide;

  late Animation<double> _rightCardsFade;
  late Animation<Offset> _rightCardsSlide;

  late Animation<double> _bottomCardFade;
  late Animation<Offset> _bottomCardSlide;

  late Animation<double> _centerFade;
  late Animation<double> _centerScale;

  // Arrow pulse animation
  late Animation<double> _arrowPulse;

  final _secureStorage = const FlutterSecureStorage();
  bool _isButtonPressed = false;

  @override
  void initState() {
    super.initState();

    // 1. Entrance animation controller (1400ms)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // 2. Perpetual floating animation controller (3000ms loop)
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    // 3. Arrow pulse animation controller (1500ms loop)
    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Staggered Entrance Curves
    _leftCardsFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
    );
    _leftCardsSlide = Tween<Offset>(
      begin: const Offset(-1.2, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.75, curve: Curves.easeOutCubic),
    ));

    _rightCardsFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.1, 0.75, curve: Curves.easeOut),
    );
    _rightCardsSlide = Tween<Offset>(
      begin: const Offset(1.2, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.1, 0.85, curve: Curves.easeOutCubic),
    ));

    _bottomCardFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.2, 0.85, curve: Curves.easeOut),
    );
    _bottomCardSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.8),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.2, 0.90, curve: Curves.easeOutCubic),
    ));

    _centerFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.3, 0.95, curve: Curves.easeOut),
    );
    _centerScale = Tween<double>(begin: 0.92, end: 1.0).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOutBack),
    ));

    _arrowPulse = Tween<double>(begin: 0.0, end: 4.0).animate(CurvedAnimation(
      parent: _arrowController,
      curve: Curves.easeInOut,
    ));

    // Start entrance, then trigger continuous floating loop
    _entranceController.forward().then((_) {
      if (mounted) {
        _floatController.repeat(reverse: true);
        _arrowController.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _floatController.dispose();
    _arrowController.dispose();
    super.dispose();
  }

  Future<void> _handleStartPressed() async {
    HapticFeedback.mediumImpact();
    // 1. Play cards offscreen exit animation
    await _entranceController.reverse();

    // 2. Persist onboarding status in SessionManager & SecureStorage
    await SessionManager().setOnboardingCompleted();
    await _secureStorage.write(key: 'has_completed_onboarding', value: 'true');

    if (!mounted) return;
    // 3. Navigate to LoginScreen
    Navigator.of(context).pushReplacement(
      buildPageRoute(const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;

    // Card sizes proportional to screen bounds
    final cardWidth = math.min(screenWidth * 0.44, 180.0);
    final cardHeight = cardWidth * 1.06;
    final calWidth = math.min(screenWidth * 0.82, 330.0);
    final calHeight = calWidth * 1.15;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFDF9), // Warm Paper Cream Surface
        body: SafeArea(
          top: false,
          bottom: false,
          child: AnimatedBuilder(
            animation: Listenable.merge([_floatController, _arrowController]),
            builder: (context, child) {
              final floatOffset1 = math.sin(_floatController.value * math.pi * 2) * 5.0;
              final floatOffset2 = math.cos(_floatController.value * math.pi * 2) * 4.0;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // 0. Ambient Glow Positions:
                  // Top-Left Folder: Soft Coral Glow
                  Positioned(
                    top: screenHeight * 0.04,
                    left: -20,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x1CFFAAA6), // Soft Coral Glow
                            blurRadius: 95,
                            spreadRadius: 45,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Middle-Left Yellow Card: Amber Yellow Glow
                  Positioned(
                    top: screenHeight * 0.42,
                    left: -30,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x22FFCC00), // Amber Yellow Glow
                            blurRadius: 95,
                            spreadRadius: 45,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Top-Right Card (03): Subtle Soft Blue Glow
                  Positioned(
                    top: screenHeight * 0.14,
                    right: -20,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x250088FF), // Subtle Soft Blue Glow
                            blurRadius: 95,
                            spreadRadius: 45,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Card 04: Subtle Yellow Glow
                  Positioned(
                    top: screenHeight * 0.52,
                    right: -20,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x22FFCC00), // Subtle Yellow Glow
                            blurRadius: 95,
                            spreadRadius: 45,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 1. Top-Left Card: Grey Folder ("Love 4")
                  Positioned(
                    left: -45,
                    top: screenHeight * 0.04 + floatOffset1,
                    child: SlideTransition(
                      position: _leftCardsSlide,
                      child: FadeTransition(
                        opacity: _leftCardsFade,
                        child: Transform.rotate(
                          angle: -0.45,
                          alignment: Alignment.center,
                          child: Image.asset(
                            'DesignCode/Welcome Screens/Folder popup.png',
                            width: cardWidth,
                            height: cardHeight,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 2. Middle-Left Card: Yellow Card ("Camera Equipment")
                  Positioned(
                    left: -60,
                    top: screenHeight * 0.44 - floatOffset2,
                    child: SlideTransition(
                      position: _leftCardsSlide,
                      child: FadeTransition(
                        opacity: _leftCardsFade,
                        child: Transform.rotate(
                          angle: -0.45,
                          alignment: Alignment.center,
                          child: Image.asset(
                            'DesignCode/Welcome Screens/Welcome screen Note Widget 02.png',
                            width: cardWidth,
                            height: cardHeight,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 3. Top-Right Card (03): Yellow Card ("Things to do today")
                  Positioned(
                    right: -40,
                    top: screenHeight * 0.15 - floatOffset1,
                    child: SlideTransition(
                      position: _rightCardsSlide,
                      child: FadeTransition(
                        opacity: _rightCardsFade,
                        child: Transform.rotate(
                          angle: -0.45,
                          alignment: Alignment.center,
                          child: Image.asset(
                            'DesignCode/Welcome Screens/Welcome Screen Task Widget 01.png',
                            width: cardWidth,
                            height: cardHeight,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 4. Card 04: Blue Card ("Client Meeting Tomorrow")
                  Positioned(
                    right: -40,
                    top: screenHeight * 0.52 + floatOffset2,
                    child: SlideTransition(
                      position: _rightCardsSlide,
                      child: FadeTransition(
                        opacity: _rightCardsFade,
                        child: Transform.rotate(
                          angle: 0.45,
                          alignment: Alignment.center,
                          child: Image.asset(
                            'DesignCode/Welcome Screens/Welcome screen Note Widget 01.png',
                            width: cardWidth,
                            height: cardHeight,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 5. Bottom Habit Calendar Grid (Calender.png)
                  Positioned(
                    left: (screenWidth - calWidth) / 2,
                    bottom: -215,
                    child: SlideTransition(
                      position: _bottomCardSlide,
                      child: FadeTransition(
                        opacity: _bottomCardFade,
                        child: Opacity(
                          opacity: 0.40,
                          child: Image.asset(
                            'DesignCode/Welcome Screens/Calender.png',
                            width: calWidth,
                            height: calHeight,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 6. Centered Title & Subtitle Stack
                  Positioned(
                    left: 0,
                    right: 0,
                    top: screenHeight * 0.35,
                    child: Center(
                      child: FadeTransition(
                        opacity: _centerFade,
                        child: ScaleTransition(
                          scale: _centerScale,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 274,
                                height: 115,
                                child: Text(
                                  'Quick Notes',
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
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                child: Text(
                                  'Capture thoughts. Organize effortlessly.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    color: const Color(0x99333333),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 7. Premium Glassmorphic Start Button
                  Positioned(
                    left: 0,
                    right: 0,
                    top: screenHeight * 0.67,
                    child: Center(
                      child: FadeTransition(
                        opacity: _centerFade,
                        child: ScaleTransition(
                          scale: _centerScale,
                          child: GestureDetector(
                            onTapDown: (_) {
                              HapticFeedback.lightImpact();
                              setState(() => _isButtonPressed = true);
                            },
                            onTapUp: (_) {
                              setState(() => _isButtonPressed = false);
                              _handleStartPressed();
                            },
                            onTapCancel: () => setState(() => _isButtonPressed = false),
                            child: AnimatedScale(
                              scale: _isButtonPressed ? 0.92 : 1.0,
                              duration: const Duration(milliseconds: 100),
                              curve: Curves.easeOut,
                              child: Container(
                                width: 130,
                                height: 50,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(25),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x18000000),
                                      blurRadius: 20,
                                      offset: Offset(0, 8),
                                      spreadRadius: 0,
                                    ),
                                    BoxShadow(
                                      color: Color(0x50FFFFFF),
                                      blurRadius: 10,
                                      offset: Offset(-2, -2),
                                      spreadRadius: -1,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(25),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 14.0, sigmaY: 14.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(25),
                                        // Translucent frosted glass surface fill
                                        color: Colors.white.withValues(alpha: 0.35),
                                        // Specular glass rim outline
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.70),
                                          width: 1.2,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Start',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.inter(
                                              color: const Color(0xFF222222),
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: -0.3,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Transform.translate(
                                            offset: Offset(_arrowPulse.value, 0),
                                            child: const Icon(
                                              Icons.arrow_forward_rounded,
                                              size: 18,
                                              color: Color(0xFF222222),
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
