
class LayoutEngine {
  static double getSpacing({
    required String? prevType,
    required String? nextType,
  }) {
    if (prevType == null || nextType == null) return 0.0;

    final isPrevHeading = prevType.startsWith('h');
    final isNextHeading = nextType.startsWith('h');
    final isPrevImage = prevType == 'image';
    final isNextImage = nextType == 'image';

    if (isPrevImage || isNextImage) {
      return 4.0;
    }
    if (isPrevHeading || isNextHeading) {
      return 2.0;
    }

    return 1.5; // Paragraph ↔ Paragraph spacing
  }

  static double getHorizontalMargin() {
    return 24.0; // Standard horizontal padding margin
  }
}
