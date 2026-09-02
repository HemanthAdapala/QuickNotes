/// PremiumFeature — Strongly typed enumeration of Quick Notes Premium capabilities.
///
/// A feature definition answers: "What capability is being requested?"
/// It contains zero purchase, billing, or platform store logic.
enum PremiumFeature {
  /// Advanced folder styling, custom hex colors, and visual stickers.
  folderCustomization(
    id: 'folder_customization',
    displayName: 'Folder Customization',
    description: 'Personalize folders with custom colors and expressive stickers.',
  ),

  /// Luxury Obsidian Night dark theme and bespoke visual styling.
  darkMode(
    id: 'dark_mode',
    displayName: 'Obsidian Dark Mode',
    description: 'Machined dark aluminum aesthetic for low-light environments.',
  ),

  /// Interactive and glanceable Home Screen & Lock Screen widgets.
  widgets(
    id: 'widgets',
    displayName: 'Home Screen Widgets',
    description: 'Access Quick Capture, Single Note, and Task widgets from your home screen.',
  );

  final String id;
  final String displayName;
  final String description;

  const PremiumFeature({
    required this.id,
    required this.displayName,
    required this.description,
  });

  /// Resolves a [PremiumFeature] from its string identifier [id].
  static PremiumFeature? fromId(String id) {
    for (final feature in PremiumFeature.values) {
      if (feature.id == id) {
        return feature;
      }
    }
    return null;
  }
}
