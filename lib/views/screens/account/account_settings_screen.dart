import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../widgets/tactile_button.dart';
import '../../widgets/grouped_list_container.dart';
import '../../../core/animations/page_transitions.dart';
import 'account_profile_screen.dart';
import 'delete_account_screen.dart';

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryTextColor = Color(0xFF333333);
    const backgroundColor = Color(0xFFF2F2F7);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Row(
                children: [
                  TactileButton(
                    useAppleSpring: true,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const ShapeDecoration(
                        color: Colors.white,
                        shape: OvalBorder(),
                        shadows: [
                          BoxShadow(
                            color: Color(0x0F000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          'assets/icons/angle_left.svg',
                          width: 18,
                          height: 18,
                          colorFilter: const ColorFilter.mode(primaryTextColor, BlendMode.srcIn),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      "Account",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: primaryTextColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.43,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40), // Balance left back button space
                ],
              ),
            ),

            const SizedBox(height: 8.0),

            // Content Area (White Rounded Sheet)
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                child: Column(
                  children: [
                    GroupedListContainer(
                      children: [
                        GroupedTile.navigation(
                          iconPath: 'assets/icons/bottom_navigation/settings.svg',
                          title: 'Profile',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              buildPageRoute(const AccountProfileScreen()),
                            );
                          },
                        ),
                        GroupedTile.navigation(
                          iconPath: 'assets/icons/trash.svg',
                          title: 'Delete your data and account',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              buildPageRoute(const DeleteAccountScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
