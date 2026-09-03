import 'package:flutter/material.dart' hide BoxDecoration, BoxShadow;
import 'package:flutter_inset_shadow/flutter_inset_shadow.dart';

class GlassmorphismPresets {
  static double blurSigma = 3.0; // Frost: 3
  static double frostOpacity = 0.0;
  static double depthOpacity = 0.30; // Depth: 30%
  static double outlineWidth = 0.8;
  static double outlineOpacity = 0.30;
  static double bevelIntensity = 0.20; // Light from above: 20%

  static Color fillColor = Colors.transparent; // No fill

  static List<BoxShadow> shadows = [
    const BoxShadow(
      offset: Offset(1.25, 0),
      blurRadius: 0,
      spreadRadius: -0.75,
      color: Color(0xFFD0D0D0),
    ),
    const BoxShadow(
      offset: Offset(-1.25, 0),
      blurRadius: 0,
      spreadRadius: -0.75,
      color: Color(0xFFD0D0D0),
    ),
    const BoxShadow(
      offset: Offset(0, 0),
      blurRadius: 0,
      spreadRadius: 0.5,
      color: Color(0xFFCCCCCC),
    ),
    const BoxShadow(
      offset: Offset(0, 8),
      blurRadius: 15,
      spreadRadius: 0,
      color: Color(0x05000000), // #000000 at 2% opacity
    ),
  ];

  static List<BoxShadow> innerShadows = [
    const BoxShadow(
      offset: Offset(0, 1.25),
      blurRadius: 0.25,
      spreadRadius: 0,
      color: Color(0xFF282828),
      inset: true,
    ),
    const BoxShadow(
      offset: Offset(0, -1.25),
      blurRadius: 0.25,
      spreadRadius: 0,
      color: Color(0xFF282828),
      inset: true,
    ),
    const BoxShadow(
      offset: Offset(0, 40),
      blurRadius: 10,
      spreadRadius: -40,
      color: Color(0xFF282828),
      inset: true,
    ),
    const BoxShadow(
      offset: Offset(0, -40),
      blurRadius: 10,
      spreadRadius: -40,
      color: Color(0xFF282828),
      inset: true,
    ),
  ];
}

class MotionPresets {
  static const double compressionScale = 0.94;
  static const Duration settleDuration = Duration(milliseconds: 190);
  static const Duration pressDuration = Duration(milliseconds: 90);
  static const Duration morphDuration = Duration(milliseconds: 260);
  static const Curve morphCurve = Curves.easeOutCubic;
}
