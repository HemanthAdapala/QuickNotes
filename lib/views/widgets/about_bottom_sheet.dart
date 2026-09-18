import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AboutBottomSheet extends StatelessWidget {
  final bool? isDark;

  const AboutBottomSheet({
    Key? key,
    this.isDark,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dark = isDark ?? (Theme.of(context).brightness == Brightness.dark);
    final sheetColor = dark ? const Color(0xFF2C2C2C) : Colors.white;
    final titleColor = dark ? const Color(0xFFFFFFFF) : const Color(0xFF333333);
    final versionColor = dark ? const Color(0xFF8E8E93) : const Color(0xFF8C8987);
    final descriptionColor = dark ? const Color(0xFF8E8E93) : const Color(0xFF4A4A4A);
    final pillBgColor = dark ? const Color(0xFF3A3A3C) : const Color(0xFFF2F2F7);
    final pillTextColor = dark ? const Color(0xFF8E8E93) : const Color(0xFF8C8987);
    final closeBtnBgColor = dark ? const Color(0xFF3A3A3C) : const Color(0xFFF2F2F7);
    final closeBtnTextColor = dark ? const Color(0xFFFFFFFF) : const Color(0xFF333333);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: sheetColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Custom App Icon / Logo
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF222222),
              borderRadius: BorderRadius.circular(22),
              border: dark
                  ? Border.all(
                      color: const Color(0xFF2C2C2E),
                      width: 1.0,
                    )
                  : null,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x3F000000),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Text(
                "Q",
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  height: 1.0,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          Text(
            "QuickNotes",
            style: GoogleFonts.inter(
              color: titleColor,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Version 1.0.4",
            style: GoogleFonts.inter(
              color: versionColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 32),
          
          Text(
            "The fastest, most elegant way to capture your thoughts, organize your life, and secure your ideas.",
            style: GoogleFonts.inter(
              color: descriptionColor,
              fontSize: 15,
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 40),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: pillBgColor,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Crafted with ",
                  style: GoogleFonts.inter(
                    color: pillTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Text(
                  "❤️",
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Close button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: closeBtnBgColor,
                foregroundColor: closeBtnTextColor,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              child: Text(
                "Close",
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
