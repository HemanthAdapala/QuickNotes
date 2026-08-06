import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/note_summary.dart';
import '../widgets/tactile_button.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FolderNoteCard
//
// Implementation derived directly from DesignCode/Widgets/FolderNote.txt.
// Displays note title, formatted date, time, pin indicator, and selection badge.
// Exact 150 × 157 px dimensions.
// ─────────────────────────────────────────────────────────────────────────────

class FolderNoteCard extends StatelessWidget {
  final NoteSummary note;
  final VoidCallback onTap;
  final ValueChanged<Offset>? onLongPressStart;
  final bool isSelectionMode;
  final bool isSelected;

  const FolderNoteCard({
    super.key,
    required this.note,
    required this.onTap,
    this.onLongPressStart,
    this.isSelectionMode = false,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEE, d MMM').format(note.updatedAt.toLocal());
    final timeStr = DateFormat('hh:mm a').format(note.updatedAt.toLocal());

    // Accent color for top tab
    final Color accentColor = switch (note.colorValue) {
      1 => const Color(0xFFFFB3BA), // Coral
      2 => const Color(0xFFFFE4A0), // Peach
      3 => const Color(0xFFFFCC00), // Yellow (Figma default)
      4 => const Color(0xFFB3F5C4), // Sage
      5 => const Color(0xFFB3D9FF), // Sky
      6 => const Color(0xFFD4B3FF), // Lavender
      7 => const Color(0xFFFFC6FF), // Blush
      _ => const Color(0xFFFFCC00), // Default Figma Yellow
    };

    return TactileButton(
      useAppleSpring: true,
      compressionScale: 0.95,
      onTap: onTap,
      onLongPressStart: onLongPressStart != null
          ? (details) => onLongPressStart!(details.globalPosition)
          : null,
      child: Center(
        child: Container(
          width: 150,
          height: 157,
          decoration: const BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Color(0x3F000000),
                blurRadius: 16,
                offset: Offset(0, 0),
                spreadRadius: 0,
              )
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Top Accent Tab Container (y: -2, h: 100, radius: 20)
              Positioned(
                left: 0,
                top: -2,
                child: Container(
                  width: 150,
                  height: 100,
                  decoration: ShapeDecoration(
                    color: accentColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),

              // Header Row (Time & Date)
              Positioned(
                left: 14,
                right: 14,
                top: 7,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Date string + Pin indicator
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (note.isPinned) ...[
                            const Icon(
                              Icons.push_pin_rounded,
                              size: 10,
                              color: Color(0xFF333333),
                            ),
                            const SizedBox(width: 2),
                          ],
                          Flexible(
                            child: Text(
                              dateStr,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: const Color(0xFF333333),
                                fontSize: 8,
                                fontWeight: FontWeight.w400,
                                letterSpacing: -0.43,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),

                    // Time string
                    Text(
                      timeStr,
                      textAlign: TextAlign.right,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF333333),
                        fontSize: 8,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.43,
                      ),
                    ),
                  ],
                ),
              ),

              // White Body Card (y: 24, h: 135, radius: 20)
              Positioned(
                left: 0,
                top: 24,
                child: Container(
                  width: 150,
                  height: 135,
                  decoration: ShapeDecoration(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),

              // Note Title
              Positioned(
                left: 11,
                top: 29,
                child: SizedBox(
                  width: 128,
                  height: 120,
                  child: Text(
                    note.isLocked
                        ? 'Locked Note'
                        : (note.title.isNotEmpty ? note.title : 'Untitled'),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF333333),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                      letterSpacing: -0.43,
                    ),
                  ),
                ),
              ),

              // Animated Selection Checkmark Badge
              if (isSelectionMode)
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF1C1C1E) : Colors.black.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? const Color(0xFF1C1C1E) : Colors.white,
                        width: 1.5,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
