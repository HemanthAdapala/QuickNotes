import 'package:flutter/material.dart';

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
      return 24.0;
    }
    if (isNextHeading) {
      return 24.0;
    }
    if (isPrevHeading && !isNextHeading) {
      return 20.0;
    }

    return 12.0; // Default spacing between elements
  }

  static double getHorizontalMargin() {
    return 24.0; // Standard horizontal padding margin
  }
}
