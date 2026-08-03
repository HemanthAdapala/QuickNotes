import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DeleteTaskConfirmationDialog
//
// Reusable, Pixel-Perfect Delete Task Confirmation Dialog following Figma specs:
// - Outer Dimensions: 303px × 296px card (3-button recurring layout)
// - Border Radius: 30px
// - Shadow: Color(0x3F000000), blurRadius: 16
// - Button 1: "Delete Forever" (Pill Color: 0x33787878, Text Color: 0xFFFF383C)
// - Button 2: "Delete Today" (Pill Color: 0x33787878, Text Color: 0xFF0088FF)
// - Button 3: "Cancel" (Pill Color: 0x33787878, Text Color: 0xFF333333)
// ─────────────────────────────────────────────────────────────────────────────

class DeleteTaskConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final bool isRecurring;

  const DeleteTaskConfirmationDialog({
    super.key,
    this.title = 'Delete Task',
    this.message = 'Are you sure you want to delete\nthis task? This action cannot be\nundone',
    this.isRecurring = true,
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
          height: isRecurring ? 296 : 223,
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
              // Title & Subtitle Message Content Area
              Padding(
                padding: const EdgeInsets.only(top: 18.0, left: 16.0, right: 16.0),
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

              // Action Buttons List
              Padding(
                padding: const EdgeInsets.only(bottom: 18.0, left: 14.0, right: 14.0),
                child: isRecurring
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 1. Delete Forever Button
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop('forever'),
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              width: 275,
                              height: 40,
                              decoration: ShapeDecoration(
                                color: const Color(0x33787878),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'Delete Forever',
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
                          const SizedBox(height: 10),

                          // 2. Delete Today Button
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop('today'),
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              width: 275,
                              height: 40,
                              decoration: ShapeDecoration(
                                color: const Color(0x33787878),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'Delete Today',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF0088FF),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // 3. Cancel Button
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(null),
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              width: 275,
                              height: 40,
                              decoration: ShapeDecoration(
                                color: const Color(0x33787878),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'Cancel',
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
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Cancel Button
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(null),
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
                                  'Cancel',
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
                            onTap: () => Navigator.of(context).pop('forever'),
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
                                  'Delete',
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

/// Helper function to show pixel-perfect Delete Task popup dialog app-wide
Future<String?> showDeleteTaskDialog(
  BuildContext context, {
  String title = 'Delete Task',
  String message = 'Are you sure you want to delete\nthis task? This action cannot be\nundone',
  bool isRecurring = true,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.40),
    builder: (ctx) => DeleteTaskConfirmationDialog(
      title: title,
      message: message,
      isRecurring: isRecurring,
    ),
  );
}
