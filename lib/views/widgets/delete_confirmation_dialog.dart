import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DeleteConfirmationDialog
//
// Reusable, Pixel-Perfect Delete Confirmation Dialog following exact Figma specs:
// - Outer Dimensions: 303px × 187px card
// - Border Radius: 30px
// - Shadow: Color(0x3F000000), blurRadius: 16
// - Cancel Button: 130px × 40px, Color(0x33787878), Radius 30, text "Cancel"
// - Delete Button: 131px × 40px, Color(0xFFFF383C), Radius 30, text "Delete"
// ─────────────────────────────────────────────────────────────────────────────

class DeleteConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String cancelText;
  final String deleteText;

  const DeleteConfirmationDialog({
    super.key,
    this.title = 'Delete Note',
    this.message = 'Are you sure you want to delete\nthis note? This action cannot be\nundone',
    this.cancelText = 'Cancel',
    this.deleteText = 'Delete',
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
      elevation: 0,
      child: Center(
        child: Container(
          width: 303,
          height: 187,
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            shadows: const [
              BoxShadow(
                color: Color(0x3F000000),
                blurRadius: 16,
                offset: Offset(0, 0),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Title & Message Content Area
              Padding(
                padding: const EdgeInsets.only(top: 15.0, left: 16.0, right: 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF333333),
                        fontSize: 20,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF333333),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),

              // Action Buttons Row (Cancel & Delete)
              Padding(
                padding: const EdgeInsets.only(bottom: 15.0, left: 18.0, right: 18.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Cancel Button
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(false),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 125,
                        height: 40,
                        decoration: ShapeDecoration(
                          color: const Color(0x33787878),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            cancelText,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF333333),
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Delete Button
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(true),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 125,
                        height: 40,
                        decoration: ShapeDecoration(
                          color: const Color(0x33787878),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            deleteText,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: const Color(0xFFFF383C),
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper function to display the pixel-perfect Delete Note popup dialog app-wide
Future<bool?> showDeleteNoteDialog(
  BuildContext context, {
  String? title,
  String? message,
  String? cancelText,
  String? deleteText,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.40),
    builder: (ctx) => DeleteConfirmationDialog(
      title: title ?? 'Delete Note',
      message: message ?? 'Are you sure you want to delete\nthis note? This action cannot be\nundone',
      cancelText: cancelText ?? 'Cancel',
      deleteText: deleteText ?? 'Delete',
    ),
  );
}
