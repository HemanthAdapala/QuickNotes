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
      width: 173.0,
      height: 32.0,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000), // Black 25% opacity
            blurRadius: 16.0,
            offset: Offset(0, 0),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Selected Background Indicator
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
            left: isNotesActive ? 0.0 : 86.5,
            top: 0.0,
            width: 86.5,
            height: 32.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOutCubic,
              decoration: BoxDecoration(
                color: const Color(0xFF0088FF),
                borderRadius: isNotesActive
                    ? const BorderRadius.only(
                        topLeft: Radius.circular(30.0),
                        bottomLeft: Radius.circular(30.0),
                        topRight: Radius.circular(0.0),
                        bottomRight: Radius.circular(0.0),
                      )
                    : const BorderRadius.only(
                        topLeft: Radius.circular(0.0),
                        bottomLeft: Radius.circular(0.0),
                        topRight: Radius.circular(30.0),
                        bottomRight: Radius.circular(30.0),
                      ),
              ),
            ),
          ),

          // Center Divider (line weight 0.2)
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 0.2,
              height: 32.0,
              color: Colors.black.withValues(alpha: 0.2),
            ),
          ),

          // Two half tap areas
          Row(
            children: [
              Expanded(
                child: TactileButton(
                  onTap: () => onChanged(true),
                  child: Container(
                    height: 32.0,
                    alignment: Alignment.center,
                    child: Text(
                      'Notes',
                      style: GoogleFonts.inter(
                        fontSize: 16.0,
                        fontWeight: FontWeight.w400,
                        height: 22.0 / 16.0,
                        letterSpacing: -0.43,
                        color: const Color(0xFF1C1C1E),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: TactileButton(
                  onTap: () => onChanged(false),
                  child: Container(
                    height: 32.0,
                    alignment: Alignment.center,
                    child: Text(
                      'Tasks',
                      style: GoogleFonts.inter(
                        fontSize: 16.0,
                        fontWeight: FontWeight.w400,
                        height: 22.0 / 16.0,
                        letterSpacing: -0.43,
                        color: const Color(0xFF1C1C1E),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
