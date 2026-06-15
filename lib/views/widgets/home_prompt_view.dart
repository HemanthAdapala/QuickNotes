import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class HomePromptView extends StatelessWidget {
  final DateTime date;
  final bool interactive;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;

  const HomePromptView({
    super.key,
    required this.date,
    this.interactive = false,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('MMM d').format(date);
    final formattedDay = DateFormat('EEEE').format(date);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 90.0), // push down to upper third center
          
          // Date Headers
          Text(
            formattedDay,
            style: GoogleFonts.playfairDisplay(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF222222),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6.0),
          Row(
            children: [
              Text(
                formattedDate.toUpperCase(),
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF8E8E93),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: 8.0),
              Text(
                "•",
                style: TextStyle(
                  fontSize: 12,
                  color: const Color(0xFF8E8E93).withOpacity(0.5),
                ),
              ),
              const SizedBox(width: 8.0),
              Text(
                "TODAY",
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFFFA322),
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20.0),
          
          // Entry Row
          GestureDetector(
            onTap: interactive ? null : onTap,
            behavior: HitTestBehavior.opaque,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bullet dot
                Container(
                  margin: const EdgeInsets.only(top: 8.0, left: 0),
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD9D9D9),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 25.0),
                
                // Prompt text field or static placeholder
                Expanded(
                  child: interactive
                      ? TextField(
                          controller: controller,
                          focusNode: focusNode,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          style: GoogleFonts.inter(
                            fontSize: 20.0,
                            color: const Color(0xFF333333),
                          ),
                          decoration: InputDecoration(
                            hintText: "what happened today?",
                            hintStyle: GoogleFonts.inter(
                              fontSize: 20.0,
                              color: const Color(0xFF333333).withOpacity(0.3),
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            filled: false,
                          ),
                          onChanged: onChanged,
                        )
                      : Padding(
                          padding: const EdgeInsets.only(top: 0.0),
                          child: Text(
                            "what happened today?",
                            style: GoogleFonts.inter(
                              fontSize: 20.0,
                              color: const Color(0xFF333333).withOpacity(0.3),
                              height: 1.4,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
