import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class QuickNotesTheme {
  // ── Brand Color Palette (Obsidian Dark) ────────────────────────────────────
  static const Color background = Color(0xFF080808); // Near Black / Matte Black
  static const Color surface =
      Color(0xFF141414); // Dark Charcoal / Elevated Surface
  static const Color surfaceElevated =
      Color(0xFF1C1C1E); // Elevated card hover/dialog
  static const Color accent =
      Color(0xFFCCFF00); // Bright Chartreuse / Neon Yellow
  static const Color textPrimary = Color(0xFFFFFFFF); // Pure White
  static const Color textSecondary = Color(0xFF8E8E93); // Muted Gray
  static const Color border = Color(0xFF242426); // Quiet Hairline Border
  static const Color borderActive = Color(0xFF38383A);

  // ── Brand Color Palette (Light Paper) ──────────────────────────────────────
  static const Color lightScaffoldBackground = Color(0xFFFFFDF9);
  static const Color lightCardBackground = Color(0xFFFDFBF7);
  static const Color lightDivider = Color(0xFF1E1B4B);

  // ── Color Schemes ──────────────────────────────────────────────────────────
  static const ColorScheme lightColorScheme = ColorScheme.light(
    primary: Color(0xFF6366F1), // Electric Indigo
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFF14B8A6), // Neon Teal
    onSecondary: Color(0xFFFFFFFF),
    tertiary: Color(0xFFF97316), // Playful Orange
    surface: Color(0xFFF5F3EF), // Playful Warm Surface
    onSurface: Color(0xFF1E1B4B), // Midnight Navy
    outline: Color(0xFF1E1B4B),
    outlineVariant: Color(0xFFE2E8F0),
  );

  static const ColorScheme darkColorScheme = ColorScheme.dark(
    primary: Color(0xFF818CF8), // Light Indigo
    onPrimary: Color(0xFF0B0D17),
    secondary: Color(0xFF2DD4BF), // Light Teal
    onSecondary: Color(0xFF0B0D17),
    tertiary: Color(0xFFFB923C), // Light Orange
    surface: Color(0xFF1E1C2E), // Playful Deep Surface
    onSurface: Color(0xFFFAF8F5), // Light Cream Text
    outline: Color(0xFFFAF8F5),
    outlineVariant: Color(0xFF312E81),
  );

  // ── Light Theme ────────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    final lightBaseTextTheme = ThemeData.light().textTheme;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: lightColorScheme,
      scaffoldBackgroundColor: lightScaffoldBackground,
      cardColor: lightCardBackground,
      dividerColor: lightDivider,
      appBarTheme: const AppBarTheme(
        backgroundColor: lightScaffoldBackground,
        foregroundColor: Color(0xFF1E1B4B),
        elevation: 0,
      ),
      textTheme: GoogleFonts.interTextTheme(
        lightBaseTextTheme.copyWith(
          displayLarge: GoogleFonts.inter(
              fontWeight: FontWeight.w800, color: const Color(0xFF1E1B4B)),
          displayMedium: GoogleFonts.inter(
              fontWeight: FontWeight.w800, color: const Color(0xFF1E1B4B)),
          displaySmall: GoogleFonts.inter(
              fontWeight: FontWeight.w800, color: const Color(0xFF1E1B4B)),
          headlineLarge: GoogleFonts.inter(
              fontWeight: FontWeight.bold, color: const Color(0xFF1E1B4B)),
          headlineMedium: GoogleFonts.inter(
              fontWeight: FontWeight.bold, color: const Color(0xFF1E1B4B)),
          headlineSmall: GoogleFonts.inter(
              fontWeight: FontWeight.bold, color: const Color(0xFF1E1B4B)),
          titleLarge: GoogleFonts.inter(
              fontWeight: FontWeight.bold, color: const Color(0xFF1E1B4B)),
          titleMedium: GoogleFonts.inter(
              fontWeight: FontWeight.bold, color: const Color(0xFF1E1B4B)),
          titleSmall: GoogleFonts.inter(
              fontWeight: FontWeight.bold, color: const Color(0xFF1E1B4B)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF6366F1),
        foregroundColor: Color(0xFFFFFFFF),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF333333),
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        contentTextStyle: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.3,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Dark Theme ─────────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    final darkBaseTextTheme = ThemeData.dark().textTheme;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0B0D17), // Obsidian Night
      cardColor: const Color(0xFF1A1C2E),
      dividerColor: const Color(0xFF312E81),
      dialogTheme: const DialogThemeData(backgroundColor: surface),
      colorScheme: darkColorScheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0B0D17),
        foregroundColor: Color(0xFFFAF8F5),
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Color(0xFFFAF8F5)),
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        darkBaseTextTheme.copyWith(
          displayLarge: GoogleFonts.outfit(
              fontWeight: FontWeight.w800, color: const Color(0xFFFAF8F5)),
          displayMedium: GoogleFonts.outfit(
              fontWeight: FontWeight.w800, color: const Color(0xFFFAF8F5)),
          displaySmall: GoogleFonts.outfit(
              fontWeight: FontWeight.w800, color: const Color(0xFFFAF8F5)),
          headlineLarge: GoogleFonts.outfit(
              fontWeight: FontWeight.bold, color: const Color(0xFFFAF8F5)),
          headlineMedium: GoogleFonts.outfit(
              fontWeight: FontWeight.bold, color: const Color(0xFFFAF8F5)),
          headlineSmall: GoogleFonts.outfit(
              fontWeight: FontWeight.bold, color: const Color(0xFFFAF8F5)),
          titleLarge: GoogleFonts.outfit(
              fontWeight: FontWeight.bold, color: const Color(0xFFFAF8F5)),
          titleMedium: GoogleFonts.outfit(
              fontWeight: FontWeight.bold, color: const Color(0xFFFAF8F5)),
          titleSmall: GoogleFonts.outfit(
              fontWeight: FontWeight.bold, color: const Color(0xFFFAF8F5)),
          bodyLarge: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: textPrimary,
            height: 1.5,
          ),
          bodyMedium: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: textSecondary,
            height: 1.4,
          ),
          bodySmall: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: textSecondary,
          ),
          labelLarge: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: accent,
            letterSpacing: 0.05,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF818CF8),
        foregroundColor: Color(0xFF0B0D17),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: const Color(0xFF333333),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: accent),
        ),
        labelStyle: GoogleFonts.inter(color: textSecondary),
        hintStyle: GoogleFonts.inter(color: textSecondary),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF333333),
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        contentTextStyle: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.3,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
