import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'glass_container.dart';
import 'tactile_button.dart';
import 'app_bottom_navigation_bar.dart';
import '../../themes/glassmorphism_presets.dart';
import '../../core/animations/animation_constants.dart';
import '../../models/note.dart';

// ── Witty messages (Change 5) ─────────────────────────────────────────────────
const List<String> _kWittyMessages = [
  "Your future self will thank you for this.",
  "Great ideas don't remember themselves.",
  "One note today beats ten regrets tomorrow.",
  "Even grocery lists deserve a great app.",
  "Somewhere between shower thoughts and genius.",
  "The best note is the one you actually write.",
  "Your brain called. It wants a backup.",
  "Notes: cheaper than therapy, equally effective.",
];

// ── Illustration palette (from existing note card colors) ─────────────────────
const Color _kSoftPink   = Color(0xFFFFB3BA);
const Color _kSoftYellow = Color(0xFFFFE4A0);
const Color _kSoftBlue   = Color(0xFFB3D9FF);
const Color _kSoftGreen  = Color(0xFFB3F5C4);
const Color _kSoftPurple = Color(0xFFD4B3FF);

// ── Streak helper (Change 2) ──────────────────────────────────────────────────
int _computeStreak(List<Note> notes, DateTime today) {
  final todayDate = DateTime(today.year, today.month, today.day);
  final Set<String> daysWithNotes = {};
  for (final note in notes) {
    final d = note.updatedAt;
    daysWithNotes.add('${d.year}-${d.month}-${d.day}');
  }
  int streak = 0;
  DateTime cursor = todayDate;
  while (true) {
    final key = '${cursor.year}-${cursor.month}-${cursor.day}';
    if (daysWithNotes.contains(key)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    } else {
      break;
    }
  }
  return streak;
}

// ─────────────────────────────────────────────────────────────────────────────
// HomePromptView
// ─────────────────────────────────────────────────────────────────────────────

class HomePromptView extends StatefulWidget {
  final DateTime date;
  final bool interactive;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final ValueChanged<String>? onLastEditedNoteTap;
  final bool isDarkBackground;
  final bool showPrompt;
  final bool showProfileHeader;
  final VoidCallback? onProfileTap;
  final VoidCallback? onMoreOptionsTap;

  const HomePromptView({
    super.key,
    required this.date,
    this.interactive = false,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onTap,
    this.onLastEditedNoteTap,
    this.isDarkBackground = false,
    this.showPrompt = true,
    this.showProfileHeader = false,
    this.onProfileTap,
    this.onMoreOptionsTap,
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
      for (int i = newDeck.length - 1; i > 0; i--) {
        final j = random.nextInt(i + 1);
        final temp = newDeck[i];
        newDeck[i] = newDeck[j];
        newDeck[j] = temp;
      }
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

    final hour = widget.date.hour;
    final String greeting;
    if (hour >= 5 && hour < 12) {
      greeting = "Good Morning";
    } else if (hour >= 12 && hour < 17) {
      greeting = "Good Afternoon";
    } else {
      greeting = "Good Evening";
    }

    final notesProvider = Provider.of<NotesProvider>(context);
    final allNotes = notesProvider.allActiveNotes;
    final bool hasNotes = allNotes.isNotEmpty;

    final todayNotes = allNotes.where((n) {
      final c = n.createdAt;
      return c.year == widget.date.year &&
          c.month == widget.date.month &&
          c.day == widget.date.day;
    }).toList();

    final int count = todayNotes.length;
    final String countText;
    if (!hasNotes) {
      countText = "No notes yet";
    } else if (count == 0) {
      countText = "";
    } else if (count == 1) {
      countText = "1 entry today";
    } else {
      countText = "$count notes today";
    }

    // ── Change 2: Contextual line ─────────────────────────────────────────
    Widget? contextualLine;
    String? contextualKey;

    if (hasNotes) {
      final int streak = _computeStreak(allNotes, widget.date);
      final bool editedToday = count > 0;

      if (streak >= 3) {
        contextualKey = 'streak_$streak';
        contextualLine = RichText(
          text: TextSpan(
            children: [
              const TextSpan(text: '🔥 '),
              TextSpan(
                text: '$streak',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFFFFA322),
                ),
              ),
              TextSpan(
                text: ' day streak',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF8E8E93),
                ),
              ),
            ],
          ),
        );
      } else if (!editedToday) {
        final sorted = List<Note>.from(allNotes)
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        final lastNote = sorted.first;
        final title = lastNote.title.isEmpty ? 'Untitled' : lastNote.title;
        contextualKey = 'last_${lastNote.id}';
        contextualLine = GestureDetector(
          onTap: () => widget.onLastEditedNoteTap?.call(lastNote.id),
          child: Text(
            'Last edited: $title',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF8E8E93),
              decoration: TextDecoration.underline,
              decorationColor: const Color(0xFF8E8E93).withOpacity(0.4),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }
    }

    final bool isTest = Platform.environment.containsKey('FLUTTER_TEST');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header Section ───────────────────────────────────────────────────
        if (widget.showProfileHeader) ...[
          // Top Row: Avatar + Name (Left), Options (Right)
          Padding(
            padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 0.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TactileButton(
                  onTap: widget.onProfileTap ?? () {},
                  useAppleSpring: true,
                  compressionScale: MotionPresets.compressionScale,
                  settleDuration: MotionPresets.settleDuration,
                  pressDuration: MotionPresets.pressDuration,
                  playSelectionHaptic: true,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40.0,
                        height: 40.0,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE2E2DF),
                          shape: BoxShape.circle,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: SvgPicture.asset(
                          "assets/Profile Icons/maxim_transparent.svg",
                          width: 40.0,
                          height: 40.0,
                        ),
                      ),
                      const SizedBox(width: 10.0),
                      Text(
                        "Hemanth Adapala",
                        style: GoogleFonts.inter(
                          fontSize: 16.0,
                          fontWeight: FontWeight.w500,
                          color: widget.isDarkBackground ? Colors.white : const Color(0xFF1C1C1E),
                        ),
                      ),
                    ],
                  ),
                ),
                TactileButton(
                  onTap: widget.onMoreOptionsTap ?? () {},
                  useAppleSpring: true,
                  compressionScale: MotionPresets.compressionScale,
                  settleDuration: MotionPresets.settleDuration,
                  pressDuration: MotionPresets.pressDuration,
                  playSelectionHaptic: true,
                  child: BottomBarGlassSurface(
                    width: 50.0,
                    height: 50.0,
                    borderRadius: BorderRadius.circular(25.0),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5.0,
                            height: 5.0,
                            decoration: BoxDecoration(
                              color: widget.isDarkBackground ? Colors.white.withOpacity(0.8) : const Color(0xFF1C1C1E).withOpacity(0.8),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4.0),
                          Container(
                            width: 5.0,
                            height: 5.0,
                            decoration: BoxDecoration(
                              color: widget.isDarkBackground ? Colors.white.withOpacity(0.8) : const Color(0xFF1C1C1E).withOpacity(0.8),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4.0),
                          Container(
                            width: 5.0,
                            height: 5.0,
                            decoration: BoxDecoration(
                              color: widget.isDarkBackground ? Colors.white.withOpacity(0.8) : const Color(0xFF1C1C1E).withOpacity(0.8),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24.0),
          // Greeting Text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hi HA,",
                  style: GoogleFonts.inter(
                    fontSize: 36.0,
                    fontWeight: FontWeight.bold,
                    color: widget.isDarkBackground ? Colors.white : const Color(0xFF1C1C1E),
                    height: 1.1,
                  ),
                ),
                Text(
                  greeting.toLowerCase(),
                  style: GoogleFonts.inter(
                    fontSize: 36.0,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF8E8E93),
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24.0),
        ] else ...[
          // Default Date/Greeting Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 45.0),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration:
                      isTest ? Duration.zero : const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) => Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 12 * (1 - value)),
                      child: child,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greeting,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF8E8E93),
                        ),
                      ),
                      const SizedBox(height: 3.0),
                      Text(
                        formattedDay,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: widget.isDarkBackground ? Colors.white : const Color(0xFF222222),
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
                            '•',
                            style: TextStyle(
                              fontSize: 12,
                              color: const Color(0xFF8E8E93).withOpacity(0.5),
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          Text(
                            'TODAY',
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
                      if (countText.isNotEmpty)
                        Text(
                          countText,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF8E8E93),
                          ),
                        ),
                      if (contextualLine != null) ...[
                        const SizedBox(height: 2.0),
                        AnimatedSwitcher(
                          duration: kDurationNormal,
                          switchInCurve: kCurveEnter,
                          switchOutCurve: kCurveExit,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.35),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                parent: animation,
                                curve: kCurveEnter,
                              )),
                              child: child,
                            ),
                          ),
                          child: SizedBox(
                            key: ValueKey(contextualKey),
                            child: contextualLine,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14.0),
              ],
            ),
          ),
        ],

        // ── Body ─────────────────────────────────────────────────────────────
        if (widget.showPrompt) ...[
          // ── Body ─────────────────────────────────────────────────────────────
          if (!hasNotes)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 80.0),
                child: Center(
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: _EmptyStateColumn(
                      onWriteNote: widget.onTap,
                      isDarkBackground: widget.isDarkBackground,
                    ),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      duration: isTest
                          ? Duration.zero
                          : const Duration(milliseconds: 1000),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        final opacity =
                            isTest ? 1.0 : (value - 0.2).clamp(0.0, 1.0) / 0.8;
                        return Opacity(
                          opacity: opacity,
                          child: Transform.translate(
                            offset: Offset(0, 8 * (1 - opacity)),
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
                              const Padding(
                                padding: EdgeInsets.only(top: 3.0),
                                child: _BlinkingCaret(
                                  height: 22.0,
                                  color: Color(0xFFFFA322),
                                ),
                              ),
                              const SizedBox(width: 8.0),
                            ],
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
                                          color: const Color(0xFF333333)
                                              .withOpacity(0.3),
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
                                        color: widget.isDarkBackground
                                            ? Colors.white.withOpacity(0.4)
                                            : const Color(0xFF333333).withOpacity(0.3),
                                        height: 1.4,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 120.0),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Change 1: Empty State Column
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyStateColumn extends StatelessWidget {
  final VoidCallback? onWriteNote;
  final bool isDarkBackground;

  const _EmptyStateColumn({
    this.onWriteNote,
    this.isDarkBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 24),
          const _NoteStackIllustration(),
          const SizedBox(height: 24.0),
          Text(
            'No notes yet',
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isDarkBackground ? Colors.white : const Color(0xFF222222),
            ),
          ),
          const SizedBox(height: 10.0),
          const _WittyMessageRotator(),
          const SizedBox(height: 28.0),
          GestureDetector(
            onTap: onWriteNote,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
              decoration: BoxDecoration(
                color: const Color(0xFFF5A623),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                'Write your first note →',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24.0),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Change 1: Note Stack Illustration
// ─────────────────────────────────────────────────────────────────────────────

class _NoteStackIllustration extends StatefulWidget {
  const _NoteStackIllustration();

  @override
  State<_NoteStackIllustration> createState() => _NoteStackIllustrationState();
}

class _NoteStackIllustrationState extends State<_NoteStackIllustration>
    with SingleTickerProviderStateMixin {
  static const int _shapeCount = 5;
  static const int _staggerMs = 80;
  static const int _shapeMs = 350; // kDurationSlow
  // Total = 350 + 80*(5-1) = 670ms
  static const Duration _totalDuration =
      Duration(milliseconds: _shapeMs + _staggerMs * (_shapeCount - 1));

  late final AnimationController _ctrl;
  late final List<Animation<double>> _shapeAnims;

  @override
  void initState() {
    super.initState();
    final int totalMs = _totalDuration.inMilliseconds;
    _ctrl = AnimationController(vsync: this, duration: _totalDuration);
    _shapeAnims = List.generate(_shapeCount, (i) {
      final int startMs = i * _staggerMs;
      final int endMs = startMs + _shapeMs;
      return CurvedAnimation(
        parent: _ctrl,
        curve: Interval(
          startMs / totalMs,
          endMs / totalMs,
          curve: Curves.easeOut,
        ),
      );
    });
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      _ctrl.forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => SizedBox(
        width: 180,
        height: 180,
        child: CustomPaint(
          painter: _NoteStackPainter(
            shapeProgress:
                _shapeAnims.map((a) => a.value).toList(growable: false),
          ),
        ),
      ),
    );
  }
}

class _ShapeData {
  final double dx, dy, w, h, rotation, radius;
  final Color color;
  final bool isRect;

  const _ShapeData({
    required this.dx,
    required this.dy,
    required this.color,
    required this.isRect,
    this.w = 0,
    this.h = 0,
    this.rotation = 0,
    this.radius = 0,
  });
}

class _NoteStackPainter extends CustomPainter {
  final List<double> shapeProgress;

  static const List<_ShapeData> _shapes = [
    _ShapeData(dx: -22, dy: -20, w: 88, h: 66, rotation: -0.30, color: _kSoftPink,   isRect: true),
    _ShapeData(dx:  18, dy: -28, w: 76, h: 58, rotation:  0.16, color: _kSoftYellow, isRect: true),
    _ShapeData(dx:  26, dy:  16,                radius: 36,       color: _kSoftBlue,   isRect: false),
    _ShapeData(dx: -28, dy:  22, w: 82, h: 62, rotation: -0.10, color: _kSoftGreen,  isRect: true),
    _ShapeData(dx:   8, dy:  32, w: 72, h: 54, rotation:  0.24, color: _kSoftPurple, isRect: true),
  ];

  const _NoteStackPainter({required this.shapeProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    for (int i = 0; i < _shapes.length; i++) {
      final double progress = i < shapeProgress.length ? shapeProgress[i] : 0.0;
      if (progress <= 0) continue;
      final s = _shapes[i];
      final double scale = 0.8 + 0.2 * progress;
      final double opacity = 0.45 * progress;
      final paint = Paint()
        ..color = s.color.withOpacity(opacity)
        ..style = PaintingStyle.fill;
      canvas.save();
      canvas.translate(cx + s.dx, cy + s.dy);
      canvas.scale(scale);
      canvas.rotate(s.rotation);
      if (s.isRect) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: s.w, height: s.h),
            const Radius.circular(14),
          ),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, s.radius, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_NoteStackPainter old) {
    for (int i = 0; i < shapeProgress.length; i++) {
      if (old.shapeProgress[i] != shapeProgress[i]) return true;
    }
    return false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Change 5: Witty Message Rotator
// ─────────────────────────────────────────────────────────────────────────────

class _WittyMessageRotator extends StatefulWidget {
  const _WittyMessageRotator();

  @override
  State<_WittyMessageRotator> createState() => _WittyMessageRotatorState();
}

class _WittyMessageRotatorState extends State<_WittyMessageRotator> {
  int _currentIndex = 0;
  int _prevIndex = -1;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _currentIndex = Random().nextInt(_kWittyMessages.length);
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      _timer = Timer.periodic(const Duration(seconds: 3), (_) => _advance());
    }
  }

  void _advance() {
    if (!mounted) return;
    setState(() {
      _prevIndex = _currentIndex;
      int next;
      do {
        next = Random().nextInt(_kWittyMessages.length);
      } while (next == _prevIndex && _kWittyMessages.length > 1);
      _currentIndex = next;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: AnimatedSwitcher(
        duration: kDurationNormal,
        switchInCurve: kCurveEnter,
        switchOutCurve: kCurveExit,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.5),
              end: Offset.zero,
            ).animate(
                CurvedAnimation(parent: animation, curve: kCurveEnter)),
            child: child,
          ),
        ),
        child: Text(
          _kWittyMessages[_currentIndex],
          key: ValueKey(_currentIndex),
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF8E8E93),
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Blinking Caret (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

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
        final showCaret = Platform.environment.containsKey('FLUTTER_TEST') ||
            _controller.value > 0.5;
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
