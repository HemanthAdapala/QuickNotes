import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  /// Primary dark — used for all text and UI elements (#333333)
  static const Color ink = Color(0xFF333333);

  /// Accent amber — "Today" label, active highlights (#FFA322)
  static const Color amber = Color(0xFFFFA322);

  /// Placeholder / muted text — ink at 45% opacity
  static const Color placeholder = Color(0x73333333); // 0x73 ≈ 45% of 0xFF

  /// Pure white
  static const Color white = Color(0xFFFFFFFF);

  /// Screen background
  static const Color background = Color(0xFFFFFFFF);
}

class AppTextStyles {
  AppTextStyles._();

  // "Apr 13" — Playfair Display Medium 20
  static const TextStyle dateSmall = TextStyle(
    fontFamily: 'PlayfairDisplay',
    fontWeight: FontWeight.w500, // Medium
    fontSize: 20,
    color: AppColors.ink,
    height: 1.2,
  );

  // "Monday" — Playfair Display SemiBold 24
  static const TextStyle dateLarge = TextStyle(
    fontFamily: 'PlayfairDisplay',
    fontWeight: FontWeight.w600, // SemiBold
    fontSize: 24,
    color: AppColors.ink,
    height: 1.2,
  );

  // "Today" — Playfair Display Regular 14
  static const TextStyle dateLabel = TextStyle(
    fontFamily: 'PlayfairDisplay',
    fontWeight: FontWeight.w400,
    fontSize: 14,
    color: AppColors.amber,
    height: 1.4,
  );

  // "what happened today?" — SF Pro Display Regular 20
  static const TextStyle entryPlaceholder = TextStyle(
    fontFamily: 'SFProDisplay',
    fontWeight: FontWeight.w400,
    fontSize: 20,
    color: AppColors.placeholder,
    height: 1.4,
  );
}
