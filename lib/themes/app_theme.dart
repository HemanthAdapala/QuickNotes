import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  /// Primary dark — used for all text and UI elements (#333333)
  static const Color ink = Color(0xFF333333);

  /// Accent amber — "Today" label, active highlights (#FFA322)
  static const Color amber = Color(0xFFFFA322);

  /// Placeholder / muted text — ink at 45% opacity
  static const Color placeholder = Color(0x73333333);

  /// Pure white
  static const Color white = Color(0xFFFFFFFF);

  /// Screen background
  static const Color background = Color(0xFFF2F2EE);

  /// Glass Surface - Frosted cards, widgets, floating panels
  static const Color glassSurface = Color(0x8CFFFFFF);

  /// Glass Border - Subtle glass outlines and edge highlights
  static const Color glassBorder = Color(0xA6FFFFFF);

  /// Divider - Layout separators and minimal boundaries
  static const Color divider = Color(0x14333333);

  /// Amber Soft - Hover states, gentle highlights, and animations
  static const Color amberSoft = Color(0xFFFFB84D);
}

class AppTextStyles {
  AppTextStyles._();

  // "Apr 13" — Playfair Display Medium 20
  static final TextStyle dateSmall = GoogleFonts.playfairDisplay(
    fontWeight: FontWeight.w500, // Medium
    fontSize: 20,
    color: AppColors.ink,
    height: 1.2,
  );

  // "Monday" — Playfair Display SemiBold 24
  static final TextStyle dateLarge = GoogleFonts.playfairDisplay(
    fontWeight: FontWeight.w600, // SemiBold
    fontSize: 24,
    color: AppColors.ink,
    height: 1.2,
  );

  // "Today" — Playfair Display Regular 14
  static final TextStyle dateLabel = GoogleFonts.playfairDisplay(
    fontWeight: FontWeight.w400,
    fontSize: 14,
    color: AppColors.amber,
    height: 1.4,
  );

  // "what happened today?" — Inter Regular 20 (SF Pro Display substitute)
  static final TextStyle entryPlaceholder = GoogleFonts.inter(
    fontWeight: FontWeight.w400,
    fontSize: 20,
    color: AppColors.placeholder,
    height: 1.4,
  );
}
