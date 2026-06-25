import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/notes_provider.dart';
import '../widgets/tactile_button.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SettingsScreen extends StatelessWidget {
  final bool isDarkMode;
  final VoidCallback onThemeToggle;
  final VoidCallback onMenuTap;

  const SettingsScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeToggle,
    required this.onMenuTap,
  });

  // Reusable Helper to Show a Clean Dialog
  void _showMockDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF2F2EE),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
        title: Text(
          title,
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1C1C1C),
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.inter(
            color: const Color(0xFF1C1C1C),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Dismiss",
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1C1C1C),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<NotesProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2EE),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 24.0),
            // Header Bar
            Container(
              height: 38,
              margin: const EdgeInsets.symmetric(horizontal: 30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  TactileButton(
                    onTap: onMenuTap,
                    child: SizedBox(
                      width: 38,
                      height: 38,
                      child: SvgPicture.asset(
                        'assets/icons/angle_left.svg',
                        colorFilter: const ColorFilter.mode(Color(0xFF1C1C1E), BlendMode.srcIn),
                        fit: BoxFit.scaleDown,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        "Settings",
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1C1C1E),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 38), // spacer to center the title
                ],
              ),
            ),
            const SizedBox(height: 24.0),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 120.0), // space for bottom nav
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── User Profile Section ─────────────────────────────────────
                    sectionProfileCard(context),

                    const SizedBox(height: 12),

                    // ── Account & Security Section ───────────────────────────────
                    _buildSectionTitle("Account & Security"),
                    const SizedBox(height: 8),
                    _buildSettingsTile(
                      leadingIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF1C1C1C), size: 22),
                      title: "Account Details",
                      isActive: false,
                      onTap: () => _showMockDialog(
                        context,
                        "Account Details",
                        "Olivia Green\nEmail: olivia.green@example.com\nMembership: Premium Pro Writer",
                      ),
                    ),
                    _buildSettingsTile(
                      leadingIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF1C1C1C), size: 22),
                      title: "Change Password",
                      isActive: true,
                      onTap: () => _showMockDialog(
                        context,
                        "Change Password",
                        "Password change verification request has been sent to your registered email address.",
                      ),
                    ),
                    _buildSettingsTile(
                      leadingIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF1C1C1C), size: 22),
                      title: "Two-Factor Auth.",
                      isActive: false,
                      onTap: () => _showMockDialog(
                        context,
                        "Two-Factor Authentication",
                        "Two-factor authentication is configured and active via Authenticator app.",
                      ),
                    ),

                    // ── Preferences Section ──────────────────────────────────────
                    _buildSectionTitle("Preferences"),
                    const SizedBox(height: 8),
                    
                    // Appearance with Toggle Switch
                    _buildSettingsTile(
                      leadingIcon: const Icon(Icons.dark_mode_outlined, color: Color(0xFF1C1C1C), size: 22),
                      title: "Appearance",
                      isActive: false,
                      trailing: StitchToggleSwitch(
                        value: isDarkMode,
                        onChanged: (val) {
                          HapticFeedback.mediumImpact();
                          onThemeToggle();
                        },
                      ),
                    ),
                    
                    // Zen Focus Mode with Toggle Switch
                    _buildSettingsTile(
                      leadingIcon: const Icon(Icons.visibility_off_outlined, color: Color(0xFF1C1C1C), size: 22),
                      title: "Zen Focus Mode",
                      isActive: false,
                      trailing: StitchToggleSwitch(
                        value: provider.isZenModeEnabled,
                        onChanged: (val) {
                          HapticFeedback.mediumImpact();
                          provider.setZenMode(val);
                        },
                      ),
                    ),

                    _buildSettingsTile(
                      leadingIcon: const Icon(Icons.language_outlined, color: Color(0xFF1C1C1C), size: 22),
                      title: "Language",
                      isActive: false,
                      onTap: () => _showMockDialog(
                        context,
                        "Language Selection",
                        "Language is set to English (United States). Sub-locales and spellcheck dictionary are active.",
                      ),
                    ),
                    _buildSettingsTile(
                      leadingIcon: const Icon(Icons.sync_rounded, color: Color(0xFF1C1C1C), size: 22),
                      title: "Sync Settings",
                      isActive: true,
                      onTap: () => _showMockDialog(
                        context,
                        "Sync Status",
                        "Database and Vault are fully synchronized. Last cloud backup was successful 2 minutes ago.",
                      ),
                    ),

                    // ── Support Section ──────────────────────────────────────────
                    _buildSectionTitle("Support"),
                    const SizedBox(height: 8),
                    _buildSettingsTile(
                      leadingIcon: const Icon(Icons.mail_outline_rounded, color: Color(0xFF1C1C1C), size: 22),
                      title: "Contact Us",
                      isActive: false,
                      onTap: () => _showMockDialog(
                        context,
                        "Contact Support",
                        "Reach us at: support@quicknotes.app\nOur Sweden and Stockholm desks usually reply within 2 hours.",
                      ),
                    ),
                    _buildSettingsTile(
                      leadingIcon: const Icon(Icons.help_outline_rounded, color: Color(0xFF1C1C1C), size: 22),
                      title: "Help Center",
                      isActive: false,
                      onTap: () => _showMockDialog(
                        context,
                        "Help Center",
                        "Opening Help Guides & Documentation center...",
                      ),
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

  // Section Title Component
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 28.0, bottom: 12.0),
      child: Text(
        title,
        style: GoogleFonts.playfairDisplay(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF1C1C1C),
        ),
      ),
    );
  }

  // Profile Card Component
  Widget sectionProfileCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
              image: DecorationImage(
                image: const NetworkImage(
                  "https://lh3.googleusercontent.com/aida-public/AB6AXuDEjfhMsQNM65m7wtNQwIQdhcBJYXcEQZY24Chk7PphQNnTQuA20aghXSK5n7V4I7z5tc-rbZz2OyscJo8DjoMD4ivAvH1aWdGY8mYfsUqJMt-iwCwUMhE2yTk1ZSaHivtQ7VPV0i439Qi2SUSiOKho0V5KWDs8nB4r22xzRD_bL2fe0RFBD_Z1iBNZls6AVmOvXRTRB4AsuBelONd2tM06dVLrAhNysx1AI0q826XDwoGxr7J42qZolRMDWy1y_TzaaiFiLNTJRKg",
                ),
                fit: BoxFit.cover,
                onError: (exception, stackTrace) {
                  // Catch image loading errors gracefully in test and production
                },
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Olivia Green",
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1C1C1C),
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Olivia Green",
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: const Color(0xFF6B685B),
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Reusable Settings List Tile
  Widget _buildSettingsTile({
    required Widget leadingIcon,
    required String title,
    required bool isActive,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: TactileButton(
        onTap: onTap ?? () {},
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFF5EFCB) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Center(child: leadingIcon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1C1C1C),
                  ),
                ),
              ),
              trailing ?? const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF6B685B),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Custom Toggle Switch ─────────────────────────────────────────────────────
class StitchToggleSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const StitchToggleSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 48,
        height: 24,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFFD1D5DB),
        ),
        padding: const EdgeInsets.all(2.0),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
