import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/app_bottom_navigation_bar.dart';
import '../widgets/tactile_button.dart';

class TestWelcomeScreen extends StatefulWidget {
  const TestWelcomeScreen({super.key});

  @override
  State<TestWelcomeScreen> createState() => _TestWelcomeScreenState();
}

class _TestWelcomeScreenState extends State<TestWelcomeScreen> {
  int _selectedIndex = 0;
  Color _backgroundColor = const Color(0xFFFFFFFF);

  void _randomizeBackgroundColor() {
    HapticFeedback.selectionClick();
    final random = math.Random();
    setState(() {
      _backgroundColor = Color.fromARGB(
        255,
        random.nextInt(256),
        random.nextInt(256),
        random.nextInt(256),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      color: _backgroundColor,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF333333),
              size: 20,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AppBottomNavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
              ),
              const SizedBox(height: 32),
              TactileButton(
                useAppleSpring: true,
                onTap: _randomizeBackgroundColor,
                child: BottomBarGlassSurface(
                  width: 220,
                  height: 56,
                  borderRadius: BorderRadius.circular(30),
                  child: Center(
                    child: Text(
                      'Random Color',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF333333),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TactileButton(
                useAppleSpring: true,
                onTap: () => HapticFeedback.selectionClick(),
                child: BottomBarGlassSurface(
                  width: 220,
                  height: 56,
                  borderRadius: BorderRadius.circular(30),
                  child: Center(
                    child: Text(
                      'Liquid Glass',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF333333),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TactileButton(
                useAppleSpring: true,
                onTap: () => HapticFeedback.selectionClick(),
                child: BottomBarGlassSurface(
                  width: 30,
                  height: 30,
                  borderRadius: BorderRadius.circular(15),
                  child: const Center(
                    child: Icon(
                      Icons.bolt_rounded,
                      color: Color(0xFF333333),
                      size: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TactileButton(
                useAppleSpring: true,
                onTap: () => HapticFeedback.selectionClick(),
                child: BottomBarGlassSurface(
                  width: 40,
                  height: 90,
                  borderRadius: BorderRadius.circular(20),
                  child: const Center(
                    child: Icon(
                      Icons.star_rounded,
                      color: Color(0xFF333333),
                      size: 18,
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
}
