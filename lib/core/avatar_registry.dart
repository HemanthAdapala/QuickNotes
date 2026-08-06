/// AvatarRegistry — Single source of truth for avatar asset path resolution.
///
/// All UI that needs to display a profile avatar must go through this registry.
/// Never store or hard-code asset paths in the database or in UI code directly.
///
/// Usage:
/// ```dart
/// final path = AvatarRegistry.assetPath('andre');
/// // → 'assets/Profile Icons/andre_transparent.png'
/// ```
///
/// This decouples the logical avatar identity from the physical asset location.
/// When assets are renamed, reorganised, or migrated to a CDN, only this
/// registry needs to change — database records remain intact.
class AvatarRegistry {
  AvatarRegistry._();

  /// All available avatar logical IDs.
  static const List<String> allIds = [
    'andre',
    'ashton',
    'babs',
    'brad',
    'brini',
    'camilla',
    'charlotte',
    'clara',
    'efron',
    'elsa',
    'elvira',
    'fini',
    'gene',
    'greggy',
    'greta',
    'hanna',
    'lars',
    'laura',
    'leni',
    'ludmilla',
    'luisa',
    'marnie',
    'maxim',
    'nicola',
    'paul',
    'phichi',
    'pitta',
    'raul',
    'reana',
    'sam',
    'saskia',
    'serj',
    'theo',
    'tzu-yung',
  ];

  /// Resolves a logical avatar ID to its asset path.
  ///
  /// Returns null if [avatarId] is null or unrecognized.
  static String? assetPath(String? avatarId) {
    if (avatarId == null) return null;
    return 'assets/Profile Icons/${avatarId}_transparent.png';
  }

  /// Returns true if [avatarId] is a registered avatar.
  static bool isValid(String? avatarId) {
    if (avatarId == null) return false;
    return allIds.contains(avatarId);
  }
}
