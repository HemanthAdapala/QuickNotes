import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../widgets/app_header_bar.dart';
import '../../themes/quick_notes_theme.dart';
import '../../providers/settings_provider.dart';
import '../../premium/premium.dart';

/// Authoritative capability boundary for requesting activation of Premium Dark Mode.
/// Gated by [PremiumFeature.darkMode].
Future<void> requestDarkModeAccess(BuildContext context) async {
  try {
    final featureAccess = Provider.of<FeatureAccess>(context, listen: false);
    if (!featureAccess.canAccess(PremiumFeature.darkMode)) {
      await showPremiumGate(
        context: context,
        feature: PremiumFeature.darkMode,
      );
      return;
    }
  } catch (_) {
    // Graceful fallback if FeatureAccess provider is not in context (e.g. isolated tests)
    await showPremiumGate(
      context: context,
      feature: PremiumFeature.darkMode,
    );
    return;
  }

  if (!context.mounted) return;

  final settingsProvider =
      Provider.of<SettingsProvider>(context, listen: false);
  await settingsProvider.setThemeMode(ThemeMode.dark);
}

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isDark = settingsProvider.isDarkMode;

    final backgroundColor = isDark ? QuickNotesTheme.background : const Color(0xFFF2F2F7);
    final surfaceColor = isDark ? QuickNotesTheme.surface : Colors.white;
    final textPrimaryColor = isDark ? QuickNotesTheme.textPrimary : const Color(0xFF333333);
    final textSecondaryColor = isDark ? QuickNotesTheme.textSecondary : const Color(0xFF8E8E93);
    final borderColor = isDark ? QuickNotesTheme.border : const Color(0x14333333);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: AppHeaderBar(
                leftWidth: 44.0,
                onLeftTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).maybePop();
                },
                leftChild: SvgPicture.asset(
                  'assets/icons/angle_left.svg',
                  width: 22,
                  height: 22,
                  colorFilter:
                      ColorFilter.mode(textPrimaryColor, BlendMode.srcIn),
                ),
                title: "Appearance",
                titleColor: textPrimaryColor,
              ),
            ),
            const SizedBox(height: 12.0),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 402.0),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: EdgeInsets.only(
                          left: 24.0,
                          right: 24.0,
                          top: 8.0,
                          bottom: 8.0 + MediaQuery.paddingOf(context).bottom),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle("THEME STYLE", textSecondaryColor),
                          const SizedBox(height: 12),

                          // Interactive Theme Style Choices (Light & Dark)
                          Row(
                            children: [
                              Expanded(
                                child: _buildThemeChoiceCard(
                                  title: "Light Paper",
                                  description: "Warm stone minimal canvas",
                                  selected: !isDark,
                                  icon: Icons.light_mode_rounded,
                                  surfaceColor: surfaceColor,
                                  borderColor: borderColor,
                                  textPrimary: textPrimaryColor,
                                  textSecondary: textSecondaryColor,
                                  accentColor: const Color(0xFF6366F1),
                                  onTap: () async {
                                    HapticFeedback.selectionClick();
                                    await settingsProvider.setThemeMode(ThemeMode.light);
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildThemeChoiceCard(
                                  title: "Obsidian Night",
                                  description: "Luxury machined dark canvas",
                                  selected: isDark,
                                  isPremiumFeature: true,
                                  icon: Icons.dark_mode_rounded,
                                  surfaceColor: surfaceColor,
                                  borderColor: borderColor,
                                  textPrimary: textPrimaryColor,
                                  textSecondary: textSecondaryColor,
                                  accentColor: QuickNotesTheme.accent,
                                  onTap: () async {
                                    HapticFeedback.selectionClick();
                                    await requestDarkModeAccess(context);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),

                          _buildSectionTitle("LAYOUT DENSITY", textSecondaryColor),
                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(
                                child: _buildChoiceCard(
                                  title: "Bento Grid",
                                  description: "Masonry card view",
                                  selected: settingsProvider.layoutDensity == "grid",
                                  icon: Icons.dashboard_outlined,
                                  surfaceColor: surfaceColor,
                                  borderColor: borderColor,
                                  textPrimary: textPrimaryColor,
                                  textSecondary: textSecondaryColor,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    settingsProvider.setLayoutDensity("grid");
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildChoiceCard(
                                  title: "Quiet List",
                                  description: "High visual density",
                                  selected: settingsProvider.layoutDensity == "list",
                                  icon: Icons.view_headline_rounded,
                                  surfaceColor: surfaceColor,
                                  borderColor: borderColor,
                                  textPrimary: textPrimaryColor,
                                  textSecondary: textSecondaryColor,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    settingsProvider.setLayoutDensity("list");
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),

                          _buildSectionTitle("TYPOGRAPHY SCALE", textSecondaryColor),
                          const SizedBox(height: 12),

                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              children: [
                                Slider(
                                  value: settingsProvider.fontSizeScale,
                                  min: 0.8,
                                  max: 1.2,
                                  divisions: 2,
                                  activeColor: isDark
                                      ? QuickNotesTheme.accent
                                      : const Color(0xFF6366F1),
                                  inactiveColor: borderColor,
                                  onChanged: (val) {
                                    HapticFeedback.selectionClick();
                                    settingsProvider.setFontSizeScale(val);
                                  },
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("Compact",
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                  color: textSecondaryColor)),
                                      Text("Regular",
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: textPrimaryColor)),
                                      Text("Large",
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                  color: textSecondaryColor)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          _buildSectionTitle("ACCENT COLOR", textSecondaryColor),
                          const SizedBox(height: 12),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildAccentOption(
                                name: "yellow",
                                color: isDark
                                    ? QuickNotesTheme.accent
                                    : const Color(0xFFFFCC00),
                                label: "Amber",
                                isSelected:
                                    settingsProvider.selectedAccent == "yellow",
                                textPrimary: textPrimaryColor,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  settingsProvider.setSelectedAccent("yellow");
                                },
                              ),
                              _buildAccentOption(
                                name: "indigo",
                                color: const Color(0xFF6366F1),
                                label: "Indigo",
                                isSelected:
                                    settingsProvider.selectedAccent == "indigo",
                                textPrimary: textPrimaryColor,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  settingsProvider.setSelectedAccent("indigo");
                                },
                              ),
                              _buildAccentOption(
                                name: "gray",
                                color: const Color(0xFF8E8E93),
                                label: "Muted",
                                isSelected:
                                    settingsProvider.selectedAccent == "gray",
                                textPrimary: textPrimaryColor,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  settingsProvider.setSelectedAccent("gray");
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Text(
      title,
      style: TextStyle(
        fontFamily: 'JetBrains Mono',
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: color,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildThemeChoiceCard({
    required String title,
    required String description,
    required bool selected,
    required IconData icon,
    required Color surfaceColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color accentColor,
    required VoidCallback onTap,
    bool isPremiumFeature = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? accentColor : borderColor,
            width: selected ? 2.0 : 1.0,
          ),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: accentColor.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  color: selected ? accentColor : textSecondary,
                  size: 24,
                ),
                if (selected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: accentColor,
                    size: 20,
                  )
                else if (isPremiumFeature)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                        width: 0.5,
                      ),
                    ),
                    child: const Text(
                      '✦ PREMIUM',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6366F1),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: textPrimary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 11,
                color: textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceCard({
    required String title,
    required String description,
    required bool selected,
    required IconData icon,
    required Color surfaceColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFF6366F1)
                : borderColor,
            width: selected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: selected
                  ? const Color(0xFF6366F1)
                  : textSecondary,
              size: 24,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccentOption({
    required String name,
    required Color color,
    required String label,
    required bool isSelected,
    required Color textPrimary,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 2.0,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 10,
                  ),
              ],
            ),
            child: isSelected
                ? const Icon(
                    Icons.check,
                    color: Colors.white,
                  )
                : null,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
