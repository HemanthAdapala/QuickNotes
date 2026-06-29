import 'package:flutter/material.dart';

class GlassmorphismPresets {
  static const double blurSigma = 4.5;
  static const double frostOpacity = 0.0;
  static const double depthOpacity = 0.0;
  static const double outlineWidth = 0.8;
  static const double outlineOpacity = 0.30;
  static const double bevelIntensity = 0.0;

  static const Color fillColor = Color(0x54999999);

  static const List<BoxShadow> shadows = [
    BoxShadow(
      offset: Offset(1.25, 0),
      blurRadius: 0,
      spreadRadius: -0.75,
      color: Color(0xFFD0D0D0),
    ),
    BoxShadow(
      offset: Offset(-1.25, 0),
      blurRadius: 0,
      spreadRadius: -0.75,
      color: Color(0xFFD0D0D0),
    ),
    BoxShadow(
      offset: Offset(0, 0),
      blurRadius: 0,
      spreadRadius: 0.5,
      color: Color(0xFFCCCCCC),
    ),
    BoxShadow(
      offset: Offset(0, 8),
      blurRadius: 15,
      spreadRadius: 0,
      color: Color(0x05000000), // #000000 at 2% opacity
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
