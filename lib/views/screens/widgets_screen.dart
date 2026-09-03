import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/animations/page_transitions.dart';
import '../../premium/premium.dart';
import '../widgets/primary_screen_surface.dart';
import '../widgets/tactile_button.dart';

/// Authoritative capability boundary for requesting access to Home Screen Widgets.
/// Gated by [PremiumFeature.widgets].
Future<void> requestWidgetAccess(BuildContext context) async {
  try {
    final featureAccess = Provider.of<FeatureAccess>(context, listen: false);
    if (!featureAccess.canAccess(PremiumFeature.widgets)) {
      await showPremiumGate(
        context: context,
        feature: PremiumFeature.widgets,
      );
      return;
    }
  } catch (_) {
    // Fallback if FeatureAccess provider is not present in context
    await showPremiumGate(
      context: context,
      feature: PremiumFeature.widgets,
    );
    return;
  }

  if (!context.mounted) return;

  Navigator.push(
    context,
    buildPageRoute(const WidgetsScreen()),
  );
}

/// Screen presenting the Quick Notes Home Screen Widget Suite and configuration guide.
class WidgetsScreen extends StatelessWidget {
  const WidgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final primaryTextColor =
        isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1D1D1F);
    final secondaryTextColor =
        isDark ? const Color(0xFF8E8E93) : const Color(0xFF86868B);
    final borderColor = isDark ? const Color(0x33FFFFFF) : const Color(0x1A000000);

    return PrimaryScreenSurface(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Top Navigation Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                child: Row(
                  children: [
                    TactileButton(
                      useAppleSpring: true,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: cardBg,
                          shape: BoxShape.circle,
                          border: Border.all(color: borderColor, width: 0.5),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0F000000),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: SvgPicture.asset(
                            'assets/icons/arrow-left.svg',
                            width: 16,
                            height: 16,
                            colorFilter: ColorFilter.mode(
                              primaryTextColor,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Home Screen Widgets',
                        style: GoogleFonts.inter(
                          color: primaryTextColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content Body
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  children: [
                    // Header Banner
                    Container(
                      padding: const EdgeInsets.all(20.0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [
                                  const Color(0xFF10B981).withValues(alpha: 0.2),
                                  const Color(0xFF047857).withValues(alpha: 0.1),
                                ]
                              : [
                                  const Color(0xFF10B981).withValues(alpha: 0.12),
                                  const Color(0xFF059669).withValues(alpha: 0.05),
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.widgets_rounded,
                                  color: Color(0xFF10B981),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Glanceable Workflow',
                                style: GoogleFonts.inter(
                                  color: primaryTextColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Quick Notes widgets bring your thoughts, task lists, and instant capture directly to your Home Screen with live reactive sync.',
                            style: GoogleFonts.inter(
                              color: secondaryTextColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Section Title
                    Text(
                      'AVAILABLE WIDGETS',
                      style: GoogleFonts.inter(
                        color: secondaryTextColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 1. Quick Capture Widget Card
                    _buildWidgetShowcaseCard(
                      context: context,
                      cardBg: cardBg,
                      borderColor: borderColor,
                      primaryTextColor: primaryTextColor,
                      secondaryTextColor: secondaryTextColor,
                      title: 'Quick Capture',
                      tag: '4x1 • 2x2',
                      description:
                          'Instant one-tap creation for notes, checklists, and lightning search without opening the full app first.',
                      icon: Icons.bolt_rounded,
                      accentColor: const Color(0xFF6366F1),
                      actions: ['+ Note', '+ List', 'Search', 'Home'],
                    ),

                    const SizedBox(height: 14),

                    // 2. Single Note Widget Card
                    _buildWidgetShowcaseCard(
                      context: context,
                      cardBg: cardBg,
                      borderColor: borderColor,
                      primaryTextColor: primaryTextColor,
                      secondaryTextColor: secondaryTextColor,
                      title: 'Pinned Single Note',
                      tag: '2x2 • 4x2',
                      description:
                          'Pin any specific note or active checklist directly to your home screen with live preview and title.',
                      icon: Icons.article_rounded,
                      accentColor: const Color(0xFFF59E0B),
                    ),

                    const SizedBox(height: 14),

                    // 3. Multi-Task Widget Card
                    _buildWidgetShowcaseCard(
                      context: context,
                      cardBg: cardBg,
                      borderColor: borderColor,
                      primaryTextColor: primaryTextColor,
                      secondaryTextColor: secondaryTextColor,
                      title: 'Multi-Task Overview',
                      tag: '4x2 • 4x4',
                      description:
                          'Comprehensive task list displaying upcoming, today, and overdue items with live status and priority tags.',
                      icon: Icons.checklist_rounded,
                      accentColor: const Color(0xFF10B981),
                    ),

                    const SizedBox(height: 14),

                    // 4. Single Task Widget Card
                    _buildWidgetShowcaseCard(
                      context: context,
                      cardBg: cardBg,
                      borderColor: borderColor,
                      primaryTextColor: primaryTextColor,
                      secondaryTextColor: secondaryTextColor,
                      title: 'Priority Task',
                      tag: '2x2 • 4x1',
                      description:
                          'Keep your most critical task in focus with due time, priority indicator, and recurrence info.',
                      icon: Icons.check_circle_outline_rounded,
                      accentColor: const Color(0xFFEC4899),
                    ),

                    const SizedBox(height: 24),

                    // Setup Instructions Card
                    Container(
                      padding: const EdgeInsets.all(18.0),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderColor, width: 0.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 10,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.touch_app_rounded,
                                size: 18,
                                color: primaryTextColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'How to Add to Home Screen',
                                style: GoogleFonts.inter(
                                  color: primaryTextColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildInstructionStep(
                            stepNumber: '1',
                            text: 'Touch and hold an empty area on your Home Screen.',
                            primaryColor: primaryTextColor,
                            secondaryColor: secondaryTextColor,
                          ),
                          const SizedBox(height: 8),
                          _buildInstructionStep(
                            stepNumber: '2',
                            text: 'Tap the "+" icon (iOS) or select "Widgets" (Android).',
                            primaryColor: primaryTextColor,
                            secondaryColor: secondaryTextColor,
                          ),
                          const SizedBox(height: 8),
                          _buildInstructionStep(
                            stepNumber: '3',
                            text: 'Find Quick Notes and pick your desired widget format.',
                            primaryColor: primaryTextColor,
                            secondaryColor: secondaryTextColor,
                          ),
                          const SizedBox(height: 8),
                          _buildInstructionStep(
                            stepNumber: '4',
                            text: 'Tap "Add Widget" to place it on your screen.',
                            primaryColor: primaryTextColor,
                            secondaryColor: secondaryTextColor,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWidgetShowcaseCard({
    required BuildContext context,
    required Color cardBg,
    required Color borderColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required String title,
    required String tag,
    required String description,
    required IconData icon,
    required Color accentColor,
    List<String>? actions,
  }) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 0.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        color: primaryTextColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tag,
                      style: GoogleFonts.inter(
                        color: accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: GoogleFonts.inter(
              color: secondaryTextColor,
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
          ),
          if (actions != null && actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: actions.map((act) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.2),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    act,
                    style: GoogleFonts.inter(
                      color: accentColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInstructionStep({
    required String stepNumber,
    required String text,
    required Color primaryColor,
    required Color secondaryColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              stepNumber,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF10B981),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: secondaryColor,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
