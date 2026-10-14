/// SplashAnimationResolver — Deterministic pure resolver for Quick Notes
/// cold-start Lottie splash animations.
///
/// Maps the resolved active tab (Notes vs Tasks) and effective theme
/// (Light vs Dark) to the exact verified asset paths.
class SplashAnimationResolver {
  SplashAnimationResolver._();

  static const String notesLight =
      'assets/animations/SplashScreen/QuickNotesYellowTheme_Light.json';
  static const String tasksLight =
      'assets/animations/SplashScreen/QuickNotes_BlueTheme_Light.json';
  static const String notesDark =
      'assets/animations/SplashScreen/QuickNotesYellowTheme_Dark.json';
  static const String tasksDark =
      'assets/animations/SplashScreen/QuickNotes_BlueTheme_Dark.json';

  /// Resolves the exact Lottie splash asset path from the active tab state and
  /// effective dark mode boolean.
  ///
  /// - Notes tab always maps to the Yellow variant.
  /// - Tasks tab always maps to the Blue variant.
  /// - Light mode selects the Light variant.
  /// - Dark mode selects the Dark variant.
  static String resolve({
    required bool isNotesTab,
    required bool isDarkMode,
  }) {
    if (isNotesTab) {
      return isDarkMode ? notesDark : notesLight;
    } else {
      return isDarkMode ? tasksDark : tasksLight;
    }
  }

  /// Convenience resolver accepting a persisted tab string identifier
  /// ('notes' | 'tasks' | null) and the effective dark mode boolean.
  ///
  /// If [tabName] is absent, unreadable, or invalid, it safely defaults
  /// to the Notes tab (Yellow variant).
  static String resolveFromTabName({
    required String? tabName,
    required bool isDarkMode,
  }) {
    final isNotes = (tabName?.trim().toLowerCase() != 'tasks');
    return resolve(isNotesTab: isNotes, isDarkMode: isDarkMode);
  }
}
