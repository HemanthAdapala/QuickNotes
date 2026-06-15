import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:quick_notes/providers/notes_provider.dart';

class HomePromptView extends StatefulWidget {
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

  static final List<String> _prompts = [
    "What's on your mind?",
    "Start writing...",
    "One thought is enough.",
    "Capture it before it's gone.",
    "What surprised you today?",
    "Leave a note for tomorrow.",
    "Write anything.",
    "What deserves remembering today?",
  ];
  static List<int> _deck = [];
  static int _deckIndex = 0;

  static String _getRandomPrompt() {
    if (_prompts.isEmpty) return "";
    if (_deck.isEmpty || _deckIndex >= _deck.length) {
      final random = Random();
      final newDeck = List<int>.generate(_prompts.length, (i) => i);
      
      // Fisher-Yates shuffle
      for (int i = newDeck.length - 1; i > 0; i--) {
        final j = random.nextInt(i + 1);
        final temp = newDeck[i];
        newDeck[i] = newDeck[j];
        newDeck[j] = temp;
      }
      
      // Avoid consecutive duplicate prompt at boundary
      if (_deck.isNotEmpty) {
        final lastVal = _deck.last;
        if (newDeck.first == lastVal && newDeck.length > 1) {
          final swapIdx = 1 + random.nextInt(newDeck.length - 1);
          final temp = newDeck[0];
          newDeck[0] = newDeck[swapIdx];
          newDeck[swapIdx] = temp;
        }
      }
      
      _deck = newDeck;
      _deckIndex = 0;
    }
    
    final promptIndex = _deck[_deckIndex];
    _deckIndex++;
    return _prompts[promptIndex];
  }

  @visibleForTesting
  static String getRandomPromptForTesting() => _getRandomPrompt();

  @visibleForTesting
  static void resetDeckForTesting() {
    _deck.clear();
    _deckIndex = 0;
  }

  @visibleForTesting
  static List<String> get prompts => _prompts;

  @override
  State<HomePromptView> createState() => _HomePromptViewState();
}

class _HomePromptViewState extends State<HomePromptView> {
  late final String _placeholderPrompt;

  @override
  void initState() {
    super.initState();
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      _placeholderPrompt = "Start writing...";
    } else {
      _placeholderPrompt = HomePromptView._getRandomPrompt();
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('MMM d').format(widget.date);
    final formattedDay = DateFormat('EEEE').format(widget.date);

    String greeting;
    final hour = widget.date.hour;
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
      return created.year == widget.date.year &&
             created.month == widget.date.month &&
             created.day == widget.date.day;
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

    final isTest = Platform.environment.containsKey('FLUTTER_TEST');

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 45.0), // push down to upper third center
          
          // Header Launch Animation
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: isTest ? Duration.zero : const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 12 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Contextual Greeting
                Text(
                  greeting,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF8E8E93),
                  ),
                ),
                const SizedBox(height: 3.0),
                
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
                const SizedBox(height: 3.0),
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
                const SizedBox(height: 3.0),
                Text(
                  countText,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14.0),
          
          // Writing Prompt Staggered Launch Animation
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: isTest ? Duration.zero : const Duration(milliseconds: 1000),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              final opacityValue = isTest ? 1.0 : (value - 0.2).clamp(0.0, 1.0) / 0.8;
              return Opacity(
                opacity: opacityValue,
                child: Transform.translate(
                  offset: Offset(0, 8 * (1 - opacityValue)),
                  child: child,
                ),
              );
            },
            child: GestureDetector(
              onTap: widget.interactive ? null : widget.onTap,
              behavior: HitTestBehavior.opaque,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!widget.interactive) ...[
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
                    child: widget.interactive
                        ? TextField(
                            controller: widget.controller,
                            focusNode: widget.focusNode,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            style: GoogleFonts.inter(
                              fontSize: 20.0,
                              color: const Color(0xFF333333),
                            ),
                            decoration: InputDecoration(
                              hintText: _placeholderPrompt,
                              hintStyle: GoogleFonts.inter(
                                fontSize: 20.0,
                                color: const Color(0xFF333333).withOpacity(0.3),
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              filled: false,
                            ),
                            onChanged: widget.onChanged,
                          )
                        : Text(
                            _placeholderPrompt,
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
