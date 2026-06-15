import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:quick_notes/providers/notes_provider.dart';

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

    String greeting;
    final hour = date.hour;
    if (hour >= 5 && hour < 12) {
      greeting = "Good Morning";
    } else if (hour >= 12 && hour < 17) {
      greeting = "Good Afternoon";
    } else {
      greeting = "Good Evening";
    }

    final notesProvider = Provider.of<NotesProvider>(context);
    final todayNotes = notesProvider.allActiveNotes.where((n) {
      final created = n.createdAt;
      return created.year == date.year &&
             created.month == date.month &&
             created.day == date.day;
    }).toList();

    final count = todayNotes.length;
    final String countText;
    if (count == 0) {
      countText = "No notes yet";
    } else if (count == 1) {
      countText = "1 entry today";
    } else {
      countText = "$count notes today";
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 90.0), // push down to upper third center
          
          // Contextual Greeting
          Text(
            greeting,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF8E8E93),
            ),
          ),
          const SizedBox(height: 4.0),
          
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
          const SizedBox(height: 6.0),
          Text(
            countText,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF8E8E93),
            ),
          ),
          const SizedBox(height: 20.0),
          
          // Entry Row
          GestureDetector(
            onTap: interactive ? null : onTap,
            behavior: HitTestBehavior.opaque,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!interactive) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 3.0),
                    child: _BlinkingCaret(
                      height: 22.0,
                      color: const Color(0xFFFFA322),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                ],
                
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
                            hintText: "Start writing...",
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
                      : Text(
                          "Start writing...",
                          style: GoogleFonts.inter(
                            fontSize: 20.0,
                            color: const Color(0xFF333333).withOpacity(0.3),
                            height: 1.4,
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

class _BlinkingCaret extends StatefulWidget {
  final double height;
  final Color color;

  const _BlinkingCaret({
    required this.height,
    required this.color,
  });

  @override
  State<_BlinkingCaret> createState() => _BlinkingCaretState();
}

class _BlinkingCaretState extends State<_BlinkingCaret>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final showCaret = Platform.environment.containsKey('FLUTTER_TEST') || _controller.value > 0.5;
        return Opacity(
          opacity: showCaret ? 1.0 : 0.0,
          child: child,
        );
      },
      child: Container(
        width: 2.0,
        height: widget.height,
        color: widget.color,
      ),
    );
  }
}
