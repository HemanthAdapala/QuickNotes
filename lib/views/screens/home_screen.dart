import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/notes_provider.dart';
import '../widgets/living_writing_experience.dart';
import 'note_editor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _entryController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  // Key for the writing prompt area — used for FAB morph bounds
  final GlobalKey _promptKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeIn = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );

    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
    ));

    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  void _openNewNote() {
    HapticFeedback.lightImpact();

    final RenderBox? box =
        _promptKey.currentContext?.findRenderObject() as RenderBox?;
    Rect sourceBounds;
    if (box != null) {
      final pos = box.localToGlobal(Offset.zero);
      sourceBounds =
          Rect.fromLTWH(pos.dx, pos.dy, box.size.width, box.size.height);
    } else {
      final size = MediaQuery.of(context).size;
      sourceBounds =
          Rect.fromLTWH(size.width / 2 - 28, size.height - 100, 56, 56);
    }

    Navigator.push(
      context,
      FabMorphPageRoute(
        fabBounds: sourceBounds,
        builder: (context) => const NoteEditorScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final now = DateTime.now();
    final dayName = DateFormat('EEEE').format(now);   // "Monday"
    final dateStr = DateFormat('MMM d').format(now);  // "Jun 13"

    // Design tokens
    final Color bgColor = theme.scaffoldBackgroundColor;
    final Color primaryText = isDark
        ? const Color(0xFFF5F3EF)
        : const Color(0xFF1E1B4B);
    final Color secondaryText = isDark
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF9CA3AF);
    final Color todayAccent = const Color(0xFFF97316); // Orange accent
    final Color promptText = isDark
        ? const Color(0xFF6B7280)
        : const Color(0xFFBBBDBF);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: SlideTransition(
            position: _slideUp,
            child: _buildContent(
              context,
              dayName: dayName,
              dateStr: dateStr,
              primaryText: primaryText,
              secondaryText: secondaryText,
              todayAccent: todayAccent,
              promptText: promptText,
              isDark: isDark,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required String dayName,
    required String dateStr,
    required Color primaryText,
    required Color secondaryText,
    required Color todayAccent,
    required Color promptText,
    required bool isDark,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;

        return Stack(
          children: [
            // ── Main scroll area ──
            SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: SizedBox(
                height: h,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Top spacing + settings icon ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 16, 20, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // App wordmark — minimal
                          Text(
                            'QuickNotes',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFF6B7280)
                                  : const Color(0xFFBBBDBF),
                              letterSpacing: 0.3,
                            ),
                          ),
                          // Profile/Search icon
                          _IconButton(
                            icon: Icons.search_rounded,
                            isDark: isDark,
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),

                    // ── Big vertical spacer — pushes date block down ──
                    SizedBox(height: h * 0.28),

                    // ── Date + Day block ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date line: "Jun 13"
                          Text(
                            dateStr,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? const Color(0xFF6B7280)
                                  : const Color(0xFF9CA3AF),
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 2),

                          // Day name: "Monday" — large serif-like bold
                          Text(
                            dayName,
                            style: GoogleFonts.outfit(
                              fontSize: 42,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? const Color(0xFFF5F3EF)
                                  : const Color(0xFF1A1A2E),
                              height: 1.05,
                              letterSpacing: -1.5,
                            ),
                          ),
                          const SizedBox(height: 4),

                          // "Today" in orange
                          Text(
                            'Today',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: todayAccent,
                              letterSpacing: 0.1,
                            ),
                          ),
                          const SizedBox(height: 28),

                          // ── Writing prompt ──
                          _WritingPrompt(
                            key: _promptKey,
                            promptText: promptText,
                            isDark: isDark,
                            onTap: _openNewNote,
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // ── Recent notes teaser (if any) ──
                    _RecentNoteTeaser(isDark: isDark),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Writing Prompt
// ─────────────────────────────────────────────────────────────────────────────

class _WritingPrompt extends StatefulWidget {
  final Color promptText;
  final bool isDark;
  final VoidCallback onTap;

  const _WritingPrompt({
    super.key,
    required this.promptText,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_WritingPrompt> createState() => _WritingPromptState();
}

class _WritingPromptState extends State<_WritingPrompt>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isPressed = false;

  static const List<String> _prompts = [
    'what happened today?',
    'what\'s on your mind?',
    'capture a thought...',
    'start writing...',
    'what are you thinking?',
  ];

  late final String _prompt;

  @override
  void initState() {
    super.initState();
    _prompt = _prompts[DateTime.now().weekday % _prompts.length];
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Breathing bullet
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                final opacity =
                    0.35 + 0.45 * Curves.easeInOut.transform(_pulseController.value);
                return Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.promptText.withAlpha((opacity * 255).round()),
                  ),
                );
              },
            ),
            const SizedBox(width: 12),

            // Prompt text
            Text(
              _prompt,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w400,
                color: widget.promptText,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recent Note Teaser (subtle — shows count or last note title)
// ─────────────────────────────────────────────────────────────────────────────

class _RecentNoteTeaser extends StatelessWidget {
  final bool isDark;

  const _RecentNoteTeaser({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<NotesProvider>(context);
    final notes = provider.notes;
    if (notes.isEmpty) return const SizedBox.shrink();

    final count = notes.length;
    final lastNote = notes.first;
    final lastTitle =
        lastNote.title.isNotEmpty ? lastNote.title : 'Untitled note';

    final subtleColor = isDark
        ? const Color(0xFF374151)
        : const Color(0xFFE5E7EB);
    final subtleText = isDark
        ? const Color(0xFF6B7280)
        : const Color(0xFFB0B3B8);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: subtleColor.withAlpha(isDark ? 60 : 80),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: subtleColor,
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.description_outlined,
              size: 16,
              color: subtleText,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$count note${count != 1 ? 's' : ''} · Last: $lastTitle',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: subtleText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Minimal icon button
// ─────────────────────────────────────────────────────────────────────────────

class _IconButton extends StatefulWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;

  const _IconButton({
    required this.icon,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_IconButton> createState() => _IconButtonState();
}

class _IconButtonState extends State<_IconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: widget.isDark
                ? const Color(0xFF1F2937).withAlpha(120)
                : const Color(0xFFF3F4F6).withAlpha(180),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            widget.icon,
            size: 20,
            color: widget.isDark
                ? const Color(0xFF9CA3AF)
                : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}
