import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../views/widgets/tactile_button.dart';
import '../views/widgets/blurred_bottom_sheet.dart';
import 'premium_feature.dart';
import 'premium_feature_presentation.dart';
import 'feature_access.dart';

/// Launches the presentation-only Premium Gate Bottom Sheet.
///
/// If the current user already has active Premium access, the sheet gracefully returns
/// without presenting a redundant paywall.
Future<void> showPremiumGate({
  required BuildContext context,
  PremiumFeature? feature,
  VoidCallback? onUnlockPressed,
  VoidCallback? onRestorePressed,
  String? customPriceSubtitle,
}) async {
  try {
    final featureAccess = Provider.of<FeatureAccess>(context, listen: false);
    if (featureAccess.isPremiumActive) {
      return;
    }
  } catch (_) {
    // Graceful fallback if FeatureAccess provider is not in context (e.g. isolated unit tests)
  }

  HapticFeedback.lightImpact();

  showBlurredBottomSheet(
    context: context,
    child: PremiumGateSheet(
      feature: feature,
      onUnlockPressed: onUnlockPressed,
      onRestorePressed: onRestorePressed,
      customPriceSubtitle: customPriceSubtitle,
    ),
  );
}

/// PremiumGateSheet — Presentation-only bottom sheet for introducing Quick Notes Premium.
///
/// Adheres strictly to the project's Liquid Glass, typography, and tactile standards.
/// Contains zero real or fake purchasing logic; all actions delegate cleanly to
/// future platform purchase boundaries (Phase P4).
class PremiumGateSheet extends StatelessWidget {
  final PremiumFeature? feature;
  final VoidCallback? onUnlockPressed;
  final VoidCallback? onRestorePressed;
  final String? customPriceSubtitle;

  const PremiumGateSheet({
    super.key,
    this.feature,
    this.onUnlockPressed,
    this.onRestorePressed,
    this.customPriceSubtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final presentation = PremiumFeaturePresentation.forFeature(feature);

    // Dynamic color tokens
    final sheetBg = isDark ? const Color(0xFF141414) : const Color(0xFFFFFFFF);
    final textPrimary = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF1E1B4B);
    final textSecondary = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4A4A4A);
    final textMuted = isDark ? const Color(0xFF6B7280) : const Color(0xFF8C8987);
    final cardBg = isDark
        ? const Color(0xFF1F2430)
        : const Color(0xFFF8FAFC);
    final cardBorder = isDark
        ? const Color(0xFF312E81).withValues(alpha: 0.4)
        : const Color(0xFFE2E8F0);

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(
          top: BorderSide(
            color: isDark
                ? const Color(0xFF312E81).withValues(alpha: 0.6)
                : const Color(0xFFE2E8F0),
            width: 1.0,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Drag Handle ────────────────────────────────────────────────
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF374151)
                        : const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Hero Capability Badge ─────────────────────────────────────
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: presentation.accentColor.withValues(alpha: isDark ? 0.18 : 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: presentation.accentColor.withValues(alpha: 0.30),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Icon(
                    presentation.icon,
                    size: 30,
                    color: presentation.accentColor,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Category Tag ──────────────────────────────────────────────
              Text(
                presentation.categoryTag,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: presentation.accentColor,
                ),
              ),
              const SizedBox(height: 8),

              // ── Headline ──────────────────────────────────────────────────
              Text(
                presentation.headline,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              // ── Description ───────────────────────────────────────────────
              Text(
                presentation.description,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  height: 1.45,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // ── Benefits Checklist Container ──────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: cardBorder, width: 1.0),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < presentation.benefits.length; i++) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: presentation.accentColor.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              size: 13,
                              color: presentation.accentColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              presentation.benefits[i],
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                height: 1.35,
                                color: textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (i < presentation.benefits.length - 1)
                        const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Primary Unlock CTA Button ─────────────────────────────────
              TactileButton(
                useAppleSpring: true,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  if (onUnlockPressed != null) {
                    onUnlockPressed!();
                  } else {
                    // Informative non-purchasing placeholder
                    _showPurchasePlaceholderInfo(context);
                  }
                },
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1), // QuickNotes Signature Indigo
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'Unlock Premium',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // ── Pricing / Lifetime Subtitle ───────────────────────────────
              Text(
                customPriceSubtitle ?? presentation.pricingNote,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: textMuted,
                ),
              ),
              const SizedBox(height: 16),

              // ── Secondary Action: Restore Purchases ───────────────────────
              TactileButton(
                useAppleSpring: true,
                onTap: () {
                  HapticFeedback.selectionClick();
                  if (onRestorePressed != null) {
                    onRestorePressed!();
                  } else {
                    _showRestorePlaceholderInfo(context);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Text(
                    'Restore Purchases',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: textMuted,
                      decoration: TextDecoration.underline,
                      decorationColor: textMuted.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // ── Dismiss Action: Maybe Later ───────────────────────────────
              TactileButton(
                useAppleSpring: true,
                onTap: () {
                  Navigator.of(context).pop();
                },
                child: Container(
                  width: double.infinity,
                  height: 44,
                  alignment: Alignment.center,
                  child: Text(
                    'Maybe Later',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
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

  void _showPurchasePlaceholderInfo(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Store purchases will be available in Phase P4.',
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showRestorePlaceholderInfo(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Purchase restoration will connect to platform stores in Phase P4.',
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
