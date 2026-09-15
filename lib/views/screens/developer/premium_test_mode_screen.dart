import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../premium/premium.dart';
import '../../../providers/settings_provider.dart';
import '../../widgets/app_header_bar.dart';
import '../../widgets/grouped_list_container.dart';
import '../../widgets/primary_screen_surface.dart';
import '../../widgets/tactile_button.dart';

/// PremiumTestModeScreen — Development-only testing screen for simulating
/// Premium entitlement states without real store purchases.
///
/// In release builds, this widget returns [SizedBox.shrink] immediately to
/// ensure strict release isolation.
class PremiumTestModeScreen extends StatelessWidget {
  const PremiumTestModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ── Release Isolation Guard ───────────────────────────────────────────────
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    final isCurrentDark =
        context.select<SettingsProvider, bool>((p) => p.isDarkMode);
    final isDark = isCurrentDark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF333333);
    final secondaryTextColor =
        isDark ? const Color(0xFF9E9E9E) : const Color(0xFF8E8E93);
    final backgroundColor = isDark ? const Color(0xFF121212) : const Color(0xFFF2F2F7);

    final manager = Provider.of<PremiumEntitlementManager>(context);
    FeatureAccess featureAccess;
    try {
      featureAccess = Provider.of<FeatureAccess>(context);
    } catch (_) {
      featureAccess = DefaultFeatureAccess(manager);
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // Primary background surface
          Positioned.fill(
            child: PrimaryScreenSurface(
              color: backgroundColor,
              child: const SizedBox.expand(),
            ),
          ),

          // Main Scrollable Content
          SafeArea(
            child: Column(
              children: [
                // Top spacing for header bar
                const SizedBox(height: 64.0),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 16.0,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── 1. DEVELOPER WARNING BANNER ──────────────────────
                            _buildDeveloperBanner(isDark),

                            const SizedBox(height: 24.0),

                            // ── 2. MODE SELECTOR ─────────────────────────────────
                            _buildSectionHeader(
                              'ENTITLEMENT TEST MODE',
                              isDark: isDark,
                            ),
                            GroupedListContainer(
                              width: double.infinity,
                              border: isDark
                                  ? Border.all(
                                      color: const Color(0xFF2C2C2E), width: 1.0)
                                  : Border.all(
                                      color: const Color(0xFFEFEFF2), width: 1.0),
                              children: [
                                _buildModeTile(
                                  context: context,
                                  title: 'System Entitlement (Follow Store)',
                                  subtitle:
                                      'Inherits real store billing status from Google Play / App Store',
                                  mode: PremiumTestMode.system,
                                  currentMode: manager.debugTestMode,
                                  isDark: isDark,
                                  primaryTextColor: primaryTextColor,
                                  secondaryTextColor: secondaryTextColor,
                                  onSelect: () =>
                                      manager.setDebugTestMode(PremiumTestMode.system),
                                ),
                                _buildModeTile(
                                  context: context,
                                  title: 'Force Premium (Simulated)',
                                  subtitle:
                                      'Simulates active lifetime entitlement across all feature gates',
                                  mode: PremiumTestMode.premium,
                                  currentMode: manager.debugTestMode,
                                  isDark: isDark,
                                  primaryTextColor: primaryTextColor,
                                  secondaryTextColor: secondaryTextColor,
                                  onSelect: () =>
                                      manager.setDebugTestMode(PremiumTestMode.premium),
                                ),
                                _buildModeTile(
                                  context: context,
                                  title: 'Force Free (Simulated)',
                                  subtitle:
                                      'Simulates un-entitled free tier; enforces all feature paywalls',
                                  mode: PremiumTestMode.free,
                                  currentMode: manager.debugTestMode,
                                  isDark: isDark,
                                  primaryTextColor: primaryTextColor,
                                  secondaryTextColor: secondaryTextColor,
                                  onSelect: () =>
                                      manager.setDebugTestMode(PremiumTestMode.free),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24.0),

                            // ── 3. RESET ACTION ──────────────────────────────────
                            GroupedListContainer(
                              width: double.infinity,
                              border: isDark
                                  ? Border.all(
                                      color: const Color(0xFF2C2C2E), width: 1.0)
                                  : Border.all(
                                      color: const Color(0xFFEFEFF2), width: 1.0),
                              children: [
                                TactileButton(
                                  useAppleSpring: true,
                                  onTap: () async {
                                    HapticFeedback.mediumImpact();
                                    await manager.resetDebugTestMode();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Reset to authoritative store entitlement',
                                          ),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0,
                                      vertical: 14.0,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Reset to System Entitlement',
                                        style: GoogleFonts.inter(
                                          fontSize: 15.0,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFFFF3B30),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24.0),

                            // ── 4. DIAGNOSTICS CARD ──────────────────────────────
                            _buildSectionHeader(
                              'LIVE ENTITLEMENT DIAGNOSTICS',
                              isDark: isDark,
                            ),
                            _buildDiagnosticsCard(
                              manager: manager,
                              featureAccess: featureAccess,
                              isDark: isDark,
                              primaryTextColor: primaryTextColor,
                              secondaryTextColor: secondaryTextColor,
                            ),

                            const SizedBox(height: 32.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Top Header Bar Overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 12.0,
                ),
                child: AppHeaderBar(
                  leftHeroTag: 'hero_premium_test_back',
                  leftWidth: 44.0,
                  onLeftTap: () => Navigator.pop(context),
                  titleWidget: Text(
                    'Premium Test Mode',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: primaryTextColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeveloperBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2411) : const Color(0xFFFFF8E6),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: isDark ? const Color(0xFF7A5914) : const Color(0xFFFFD566),
          width: 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.build_circle_outlined,
            color: Color(0xFFD97706),
            size: 22.0,
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DEVELOPER UTILITY',
                  style: GoogleFonts.inter(
                    fontSize: 12.0,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  'This screen only affects local debug testing. It does not create or modify a real purchase.',
                  style: GoogleFonts.inter(
                    fontSize: 13.0,
                    fontWeight: FontWeight.w400,
                    color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF4B5563),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required PremiumTestMode mode,
    required PremiumTestMode currentMode,
    required bool isDark,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required VoidCallback onSelect,
  }) {
    final isSelected = mode == currentMode;
    const activeColor = Color(0xFF007AFF);

    return TactileButton(
      useAppleSpring: true,
      onTap: () {
        HapticFeedback.selectionClick();
        onSelect();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15.0,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: primaryTextColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 3.0),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      color: secondaryTextColor,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12.0),
            Container(
              width: 22.0,
              height: 22.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? activeColor : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? activeColor
                      : (isDark ? const Color(0xFF48484A) : const Color(0xFFC7C7CC)),
                  width: 1.8,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 14.0,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosticsCard({
    required PremiumEntitlementManager manager,
    required FeatureAccess featureAccess,
    required bool isDark,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    final authoritative = manager.authoritativeEntitlement;
    final effective = manager.effectiveEntitlement;
    final testMode = manager.debugTestMode;

    // Badge configuration
    String badgeText;
    Color badgeBgColor;
    Color badgeTextColor;

    switch (testMode) {
      case PremiumTestMode.premium:
        badgeText = 'SIMULATED PREMIUM';
        badgeBgColor = isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7);
        badgeTextColor = isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
        break;
      case PremiumTestMode.free:
        badgeText = 'FORCED FREE';
        badgeBgColor = isDark ? const Color(0xFF262626) : const Color(0xFFF3F4F6);
        badgeTextColor = isDark ? const Color(0xFFA3A3A3) : const Color(0xFF6B7280);
        break;
      case PremiumTestMode.system:
        badgeText = 'SYSTEM (REAL STORE)';
        badgeBgColor = isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE0F2FE);
        badgeTextColor = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEFEFF2),
          width: 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Effective Status Badge Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Effective Entitlement',
                style: GoogleFonts.inter(
                  fontSize: 14.0,
                  fontWeight: FontWeight.w600,
                  color: primaryTextColor,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: badgeBgColor,
                  borderRadius: BorderRadius.circular(6.0),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.inter(
                    fontSize: 11.0,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: badgeTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14.0),
          Divider(
            height: 1.0,
            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF0F0F2),
          ),
          const SizedBox(height: 14.0),

          // Diagnostic Attributes Table
          _buildDiagRow(
            label: 'Authoritative Status',
            value: authoritative.status.name.toUpperCase(),
            isDark: isDark,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
          ),
          const SizedBox(height: 8.0),
          _buildDiagRow(
            label: 'Authoritative Store Source',
            value: authoritative.storeSource.name,
            isDark: isDark,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
          ),
          const SizedBox(height: 8.0),
          _buildDiagRow(
            label: 'Authoritative Product ID',
            value: authoritative.productId ?? 'None',
            isDark: isDark,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
          ),
          const SizedBox(height: 8.0),
          _buildDiagRow(
            label: 'Active Override Mode',
            value: testMode.name,
            isDark: isDark,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
          ),
          const SizedBox(height: 8.0),
          _buildDiagRow(
            label: 'Effective Status',
            value: effective.status.name.toUpperCase(),
            isDark: isDark,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
          ),
          const SizedBox(height: 8.0),
          _buildDiagRow(
            label: 'Effective Product ID',
            value: effective.productId ?? 'None',
            isDark: isDark,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
          ),

          const SizedBox(height: 14.0),
          Divider(
            height: 1.0,
            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF0F0F2),
          ),
          const SizedBox(height: 14.0),

          // Feature Gate Status Summary
          Text(
            'Feature Gate Statuses',
            style: GoogleFonts.inter(
              fontSize: 13.0,
              fontWeight: FontWeight.w600,
              color: primaryTextColor,
            ),
          ),
          const SizedBox(height: 8.0),
          _buildGateStatusRow(
            label: 'Folder Customization',
            unlocked: featureAccess.canAccess(PremiumFeature.folderCustomization),
            isDark: isDark,
          ),
          const SizedBox(height: 6.0),
          _buildGateStatusRow(
            label: 'Obsidian Dark Mode',
            unlocked: featureAccess.canAccess(PremiumFeature.darkMode),
            isDark: isDark,
          ),
          const SizedBox(height: 6.0),
          _buildGateStatusRow(
            label: 'Home Screen Widgets',
            unlocked: featureAccess.canAccess(PremiumFeature.widgets),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildDiagRow({
    required String label,
    required String value,
    required bool isDark,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13.0,
            fontWeight: FontWeight.w400,
            color: secondaryTextColor,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13.0,
            fontWeight: FontWeight.w600,
            color: primaryTextColor,
          ),
        ),
      ],
    );
  }

  Widget _buildGateStatusRow({
    required String label,
    required bool unlocked,
    required bool isDark,
  }) {
    final statusColor =
        unlocked ? const Color(0xFF34C759) : const Color(0xFFFF3B30);
    final statusText = unlocked ? 'UNLOCKED' : 'LOCKED';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w400,
            color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              unlocked ? Icons.lock_open : Icons.lock,
              size: 13.0,
              color: statusColor,
            ),
            const SizedBox(width: 4.0),
            Text(
              statusText,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: statusColor,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, {required bool isDark}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: isDark ? const Color(0xFF9E9E9E) : const Color(0xFF8E8E93),
        ),
      ),
    );
  }
}
