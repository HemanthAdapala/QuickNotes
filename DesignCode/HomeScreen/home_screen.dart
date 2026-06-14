import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _activeNavIndex = 0; // 0 = Home (active by default)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Main content ───────────────────────────────────────────────
          SafeArea(
            bottom: false, // bottom handled by nav bar + system padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Large top whitespace — content sits ~55% down in design
                const Spacer(flex: 55),

                // ── Date block ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(left: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // "Apr 13"
                      Text(
                        'Apr 13',
                        style: AppTextStyles.dateSmall,
                      ),
                      const SizedBox(height: 2),
                      // "Monday"
                      Text(
                        'Monday',
                        style: AppTextStyles.dateLarge,
                      ),
                      const SizedBox(height: 2),
                      // "Today"
                      Text(
                        'Today',
                        style: AppTextStyles.dateLabel,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Entry placeholder row ────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Bullet dot — #333333 at 45% opacity, diameter ~7
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.placeholder,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Placeholder text
                      Text(
                        'what happened today?',
                        style: AppTextStyles.entryPlaceholder,
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 45),
              ],
            ),
          ),

          // ── Bottom nav bar ─────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: GravityNotesNavBar(
              activeIndex: _activeNavIndex,
              onTap: (index) {
                setState(() => _activeNavIndex = index);
              },
            ),
          ),
        ],
      ),
    );
  }
}
