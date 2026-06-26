import 'package:flutter/material.dart';

class GlassmorphismPresets {
  static const double blurSigma = 4.5;
  static const double frostOpacity = 0.0;
  static const double depthOpacity = 0.0;
  static const double outlineWidth = 0.8;
  static const double outlineOpacity = 0.30;
  static const double bevelIntensity = 0.0;

  static final List<BoxShadow> shadows = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.10),
      blurRadius: 24,
      spreadRadius: -6,
      offset: const Offset(0, 16),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8,
      spreadRadius: -2,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.white.withValues(alpha: 0.42),
      blurRadius: 22,
      spreadRadius: -10,
      offset: const Offset(-8, -10),
    ),
  ];
}

class MotionPresets {
  static const double compressionScale = 0.7;
  static const Duration settleDuration = Duration(milliseconds: 1000);
  static const Duration pressDuration = Duration(milliseconds: 80);
  static const Duration morphDuration = Duration(milliseconds: 1000);
  static const Curve morphCurve = Curves.elasticOut;
}
