import 'package:flutter/material.dart';
import 'premium_feature.dart';

/// Presentation metadata model for presenting a [PremiumFeature] in the Premium Gate UI.
class PremiumFeaturePresentation {
  /// The feature being presented.
  final PremiumFeature? feature;

  /// Uppercase category/badge label (e.g. 'QUICK NOTES PREMIUM').
  final String categoryTag;

  /// Headline title tailored to the feature value proposition.
  final String headline;

  /// Concise, editorial description of the feature benefit.
  final String description;

  /// Visual icon representing the capability.
  final IconData icon;

  /// Theme accent color associated with the capability.
  final Color accentColor;

  /// Bulleted list of specific capabilities unlocked.
  final List<String> benefits;

  /// Subtitle or pricing note displayed below the main CTA.
  final String pricingNote;

  const PremiumFeaturePresentation({
    this.feature,
    required this.categoryTag,
    required this.headline,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.benefits,
    this.pricingNote = 'One-time purchase • Lifetime access',
  });

  /// Factory constructor that resolves presentation metadata for any given [PremiumFeature].
  factory PremiumFeaturePresentation.forFeature(PremiumFeature? feature) {
    if (feature == null) {
      return const PremiumFeaturePresentation(
        feature: null,
        categoryTag: 'QUICK NOTES PREMIUM',
        headline: 'Unlock the Full Experience',
        description:
            'Elevate your writing, folder organization, and home screen workflow with permanent lifetime access to all premium features.',
        icon: Icons.auto_awesome_rounded,
        accentColor: Color(0xFF6366F1),
        benefits: [
          'Obsidian Night OLED Dark Mode',
          'Custom folder colors & expressive stickers',
          'Interactive Home Screen & Lock Screen widgets',
          'All future premium updates included',
        ],
      );
    }

    switch (feature) {
      case PremiumFeature.folderCustomization:
        return const PremiumFeaturePresentation(
          feature: PremiumFeature.folderCustomization,
          categoryTag: 'FOLDER CUSTOMIZATION',
          headline: 'Make Every Folder Yours',
          description:
              'Personalize your workspace with bespoke hex colors, warm stationery tones, and expressive visual stickers.',
          icon: Icons.folder_special_rounded,
          accentColor: Color(0xFFF59E0B),
          benefits: [
            'Curated stationery palettes & custom hex colors',
            'Expressive sticker badges for visual scanning',
            'Distinct visual hierarchy in grid and list views',
          ],
        );

      case PremiumFeature.darkMode:
        return const PremiumFeaturePresentation(
          feature: PremiumFeature.darkMode,
          categoryTag: 'OBSIDIAN DARK MODE',
          headline: 'A Calmer Workspace for Night',
          description:
              'Machined dark aluminum aesthetic crafted for late-night notes, reduced eye fatigue, and pure OLED contrast.',
          icon: Icons.dark_mode_rounded,
          accentColor: Color(0xFF6366F1),
          benefits: [
            'Deep Obsidian & Graphite OLED surfaces',
            'Reduced eye strain during low-light writing',
            'Refined contrast across editor, cards, and widgets',
          ],
        );

      case PremiumFeature.widgets:
        return const PremiumFeaturePresentation(
          feature: PremiumFeature.widgets,
          categoryTag: 'HOME SCREEN WIDGETS',
          headline: 'Your Thoughts, Right at a Glance',
          description:
              'Bring glanceable Quick Capture, pinned Single Note cards, and live Task lists directly to your Home Screen.',
          icon: Icons.widgets_rounded,
          accentColor: Color(0xFF10B981),
          benefits: [
            'Instant 1-tap capture right from your Home Screen',
            'Glanceable single note cards with live sync',
            'Interactive task tracking without opening the app',
          ],
        );
    }
  }
}
