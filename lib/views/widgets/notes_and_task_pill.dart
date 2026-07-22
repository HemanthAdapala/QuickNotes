import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tactile_button.dart';

class NotesAndTaskPill extends StatelessWidget {
  final bool isNotesActive;
  final ValueChanged<bool> onChanged;

  const NotesAndTaskPill({
    super.key,
    required this.isNotesActive,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 177.0,
      height: 40.0,
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        shadows: const [
          BoxShadow(
            color: Color(0x3F000000),
            blurRadius: 16.0,
            offset: Offset(0, 0),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Inner Sliding Active Pod
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            left: isNotesActive ? 5.0 : 89.0,
            top: 4.0,
            width: 83.0,
            height: 32.0,
            child: Container(
              decoration: ShapeDecoration(
                color: isNotesActive ? const Color(0xFFFFCC00) : const Color(0xFF0088FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.0),
                ),
              ),
            ),
          ),

          // Tactile Tap Areas
          Positioned(
            left: 5.0,
            top: 4.0,
            width: 83.0,
            height: 32.0,
            child: TactileButton(
              onTap: () => onChanged(true),
              useAppleSpring: true,
              compressionScale: 0.92,
              child: Container(
                alignment: Alignment.center,
                color: Colors.transparent,
                child: Text(
                  'Notes',
                  style: GoogleFonts.inter(
                    color: isNotesActive ? Colors.white : Colors.black,
                    fontSize: 16.0,
                    fontWeight: FontWeight.w600,
                    height: 1.38,
                    letterSpacing: -0.43,
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            left: 89.0,
            top: 4.0,
            width: 83.0,
            height: 32.0,
            child: TactileButton(
              onTap: () => onChanged(false),
              useAppleSpring: true,
              compressionScale: 0.92,
              child: Container(
                alignment: Alignment.center,
                color: Colors.transparent,
                child: Text(
                  'Tasks',
                  style: GoogleFonts.inter(
                    color: !isNotesActive ? Colors.white : Colors.black,
                    fontSize: 16.0,
                    fontWeight: FontWeight.w600,
                    height: 1.38,
                    letterSpacing: -0.43,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
