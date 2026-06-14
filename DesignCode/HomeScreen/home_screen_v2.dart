import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav_bar_v2.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _activeNavIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      // ── Use resizeToAvoidBottomInset: false so keyboard doesn't push nav bar ──
      resizeToAvoidBottomInset: false,

      body: Column(
        children: [
          // ── Scrollable content area ──────────────────────────────────
          Expanded(
            child: SafeArea(
              bottom: false,
              child: _buildContent(),
            ),
          ),

          // ── Nav bar pinned to bottom ─────────────────────────────────
          // Sits BELOW the Expanded content, ABOVE nothing.
          // MediaQuery.padding.bottom is consumed inside the bar itself.
          GravityNotesNavBar(
            activeIndex: _activeNavIndex,
            onTap: (i) => setState(() => _activeNavIndex = i),
            onFabTap: () {
              // TODO: open new note
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Push date block to ~55% down the available content area
        final double topSpace = constraints.maxHeight * 0.52;

        return SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: SizedBox(
            height: constraints.maxHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: topSpace),

                // ── Date block ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(left: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Apr 13', style: AppTextStyles.dateSmall),
                      const SizedBox(height: 2),
                      Text('Monday', style: AppTextStyles.dateLarge),
                      const SizedBox(height: 2),
                      Text('Today', style: AppTextStyles.dateLabel),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Entry placeholder ──────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Bullet dot — #333333 @ 45% opacity
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.placeholder,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'what happened today?',
                        style: AppTextStyles.entryPlaceholder,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
