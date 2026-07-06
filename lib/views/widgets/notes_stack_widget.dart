import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/note.dart';
import '../../providers/notes_provider.dart';
import 'tactile_button.dart';

class NotesStackWidget extends StatefulWidget {
  final List<Note> notes;
  final ValueChanged<Note> onEdit;
  final double width;

  const NotesStackWidget({
    super.key,
    required this.notes,
    required this.onEdit,
    this.width = 322.0,
  });

  @override
  State<NotesStackWidget> createState() => _NotesStackWidgetState();
}

class _NotesStackWidgetState extends State<NotesStackWidget> with TickerProviderStateMixin {
  // Swipe Dismiss State
  double _swipeX = 0.0;
  double _swipeY = 0.0;
  bool _isAnimatingSwipe = false;

  // Animation Controllers
  late AnimationController _resetController;
  late AnimationController _cycleController;
  late AnimationController _entranceController;
  late List<Animation<double>> _cardEntranceAnimations;
  late List<Note> _currentNotesList;

  @override
  void initState() {
    super.initState();
    _currentNotesList = List.from(widget.notes);

    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _cycleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _cardEntranceAnimations = List.generate(3, (dist) {
      final start = dist * 0.1; // 0.0, 0.1, 0.2 delay
      final end = (start + 0.6).clamp(0.0, 1.0);
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _entranceController,
          curve: Interval(start, end, curve: Curves.easeOutBack),
        ),
      );
    });

    _entranceController.forward();
  }

  @override
  void didUpdateWidget(NotesStackWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync list if items count changes or is updated from parent
    if (widget.notes.length != oldWidget.notes.length) {
      setState(() {
        _currentNotesList = List.from(widget.notes);
      });
    } else {
      // Sync contents while keeping order if same length
      for (int i = 0; i < _currentNotesList.length; i++) {
        final updatedIndex = widget.notes.indexWhere((n) => n.id == _currentNotesList[i].id);
        if (updatedIndex != -1) {
          _currentNotesList[i] = widget.notes[updatedIndex];
        }
      }
    }
  }

  @override
  void dispose() {
    _resetController.dispose();
    _cycleController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_isAnimatingSwipe || _currentNotesList.isEmpty) return;
    setState(() {
      _swipeX += details.delta.dx;
      _swipeY += details.delta.dy;
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_isAnimatingSwipe || _currentNotesList.isEmpty) return;

    final distance = sqrt(_swipeX * _swipeX + _swipeY * _swipeY);
    if (distance > 120.0) {
      _triggerSwipeAway();
    } else {
      _triggerReset();
    }
  }

  void _triggerSwipeAway() {
    _isAnimatingSwipe = true;
    final double targetX = _swipeX.sign * 450.0;
    final double targetY = _swipeY.sign * 250.0;

    final tweenX = Tween<double>(begin: _swipeX, end: targetX);
    final tweenY = Tween<double>(begin: _swipeY, end: targetY);

    void listener() {
      setState(() {
        _swipeX = tweenX.evaluate(_cycleController);
        _swipeY = tweenY.evaluate(_cycleController);
      });
    }

    _cycleController.addListener(listener);

    _cycleController.forward(from: 0.0).then((_) {
      _cycleController.removeListener(listener);
      _cycleController.reset();

      if (mounted && _currentNotesList.isNotEmpty) {
        setState(() {
          // Cycle top note to the back of the deck
          final topNote = _currentNotesList.removeAt(0);
          _currentNotesList.add(topNote);
          _swipeX = 0.0;
          _swipeY = 0.0;
          _isAnimatingSwipe = false;
        });
        HapticFeedback.lightImpact();
      }
    });
  }

  void _triggerReset() {
    _isAnimatingSwipe = true;
    final tweenX = Tween<double>(begin: _swipeX, end: 0.0);
    final tweenY = Tween<double>(begin: _swipeY, end: 0.0);

    void listener() {
      setState(() {
        _swipeX = tweenX.evaluate(_resetController);
        _swipeY = tweenY.evaluate(_resetController);
      });
    }

    _resetController.addListener(listener);

    _resetController.forward(from: 0.0).then((_) {
      _resetController.removeListener(listener);
      _resetController.reset();
      _isAnimatingSwipe = false;
    });
  }

  void _toggleChecklistItem(Note note, int index, List<Map<String, dynamic>> items) async {
    HapticFeedback.selectionClick();
    items[index]['done'] = !(items[index]['done'] ?? false);
    final updatedNote = note.copyWith(content: jsonEncode(items));
    
    // Update local list state instantly
    setState(() {
      final localIdx = _currentNotesList.indexWhere((n) => n.id == note.id);
      if (localIdx != -1) {
        _currentNotesList[localIdx] = updatedNote;
      }
    });

    // Update in database provider
    await Provider.of<NotesProvider>(context, listen: false).updateNote(updatedNote);
  }

  Widget _buildChecklist(Note note, List<Map<String, dynamic>> items) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 4.0, bottom: 64.0), // Spacing for floating edit button
      itemCount: items.length,
      itemBuilder: (context, idx) {
        final item = items[idx];
        final bool done = item['done'] ?? false;
        final String text = item['text'] ?? '';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Interactive checkbox
              GestureDetector(
                onTap: () => _toggleChecklistItem(note, idx, items),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(top: 1.0, right: 10.0, bottom: 4.0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 18.0,
                    height: 18.0,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: done ? const Color(0xFFFFCC00) : const Color(0xFF8E8E93),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(4.0),
                      color: done ? const Color(0xFFFFCC00) : Colors.transparent,
                    ),
                    alignment: Alignment.center,
                    child: done
                        ? const Icon(
                            Icons.check,
                            size: 13.0,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
              ),
              // Checklist item text
              Expanded(
                child: Text(
                  text,
                  style: GoogleFonts.inter(
                    fontSize: 16.0,
                    fontWeight: FontWeight.w400,
                    height: 1.3,
                    color: const Color(0xFF1C1C1E),
                    decoration: done ? TextDecoration.lineThrough : null,
                    decorationColor: const Color(0xFF8E8E93),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBackgroundCard(int index, int totalCards) {
    final double offset = 37.0 * index;
    final int dist = totalCards - 1 - index;
    final double blurSigma = 1.0 + (dist - 1) * 0.1;

    final note = _currentNotesList[totalCards - 1 - index];
    final formattedDate = DateFormat('EEE, d MMMM yyyy').format(note.createdAt);
    final formattedTime = DateFormat('hh:mm a').format(note.createdAt);

    Widget cardContent = Container(
      width: widget.width,
      height: 339.0,
      decoration: BoxDecoration(
        color: const Color(0xFFFFCC00), // Yellow Accent Header background color
        borderRadius: BorderRadius.circular(30.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x28000000), // Subtle black opacity shadow
            blurRadius: 16.0,
            offset: Offset(0, 0),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Header content
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 37.0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formattedDate,
                    style: GoogleFonts.inter(
                      fontSize: 16.0,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF1C1C1E),
                      height: 22.0 / 16.0,
                      letterSpacing: -0.43,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset(
                        "assets/New Icons/fi-rr-time-past.svg",
                        width: 22.0,
                        height: 22.0,
                        colorFilter: const ColorFilter.mode(Color(0xFF1C1C1E), BlendMode.srcIn),
                      ),
                      const SizedBox(width: 6.0),
                      Text(
                        formattedTime,
                        style: GoogleFonts.inter(
                          fontSize: 16.0,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF1C1C1E),
                          height: 22.0 / 16.0,
                          letterSpacing: -0.43,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (blurSigma > 0.0) {
      cardContent = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: cardContent,
      );
    }

    final double scale = 1.0 - dist * 0.03;
    final anim = _cardEntranceAnimations[dist];

    return AnimatedBuilder(
      animation: anim,
      builder: (context, child) {
        final double slideOffset = 60.0 * (1.0 - anim.value);
        return Positioned(
          top: offset + slideOffset,
          left: 0,
          right: 0,
          height: 339.0,
          child: Opacity(
            opacity: anim.value.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: scale,
              child: child,
            ),
          ),
        );
      },
      child: cardContent,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentNotesList.isEmpty) {
      return SizedBox(
        width: widget.width,
        height: 339.0,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30.0),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 16.0,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64.0,
                height: 64.0,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFCC00).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.note_alt_outlined,
                  size: 40.0,
                  color: Color(0xFFFFCC00),
                ),
              ),
              const SizedBox(height: 16.0),
              Text(
                "No Notes Found",
                style: GoogleFonts.inter(
                  fontSize: 22.0,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
              const SizedBox(height: 8.0),
              Text(
                "Create a note to populate this deck.",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14.0,
                  color: const Color(0xFF8E8E93),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final int numCards = _currentNotesList.length.clamp(1, 3);
    const double cardOffset = 37.0;
    final double overallHeight = 339.0 + (numCards - 1) * cardOffset;

    final note = _currentNotesList.first;
    final formattedDate = DateFormat('EEE, d MMMM yyyy').format(note.createdAt);
    final formattedTime = DateFormat('hh:mm a').format(note.createdAt);

    // Parse checklist content if note is a checklist
    List<Map<String, dynamic>> checklistItems = [];
    if (note.noteType == 'checklist') {
      try {
        final decoded = jsonDecode(note.content) as List<dynamic>;
        checklistItems = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {
        checklistItems = [];
      }
    }

    final double rotationAngle = (_swipeX / 400.0) * (pi / 24.0);

    return SizedBox(
      width: widget.width,
      height: overallHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Render background card peaks (from back to front)
          for (int i = 0; i < numCards - 1; i++)
            _buildBackgroundCard(i, numCards),

          // Render interactive front card (shifted down by offsets)
          Positioned(
            top: (numCards - 1) * cardOffset + _swipeY,
            left: _swipeX,
            right: -_swipeX,
            height: 339.0,
            child: AnimatedBuilder(
              animation: _cardEntranceAnimations[0],
              builder: (context, child) {
                final anim = _cardEntranceAnimations[0];
                final double slideOffset = 60.0 * (1.0 - anim.value);
                return Transform.translate(
                  offset: Offset(0, slideOffset),
                  child: Opacity(
                    opacity: anim.value.clamp(0.0, 1.0),
                    child: child,
                  ),
                );
              },
              child: GestureDetector(
                onPanUpdate: _handlePanUpdate,
                onPanEnd: _handlePanEnd,
                child: Hero(
                  tag: 'hero_note_card_${note.id}',
                  child: Material(
                    type: MaterialType.transparency,
                    child: Transform.rotate(
                      angle: rotationAngle,
                child: Container(
                  width: widget.width,
                  height: 339.0,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30.0),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x40000000), // Black 25% opacity
                        blurRadius: 16.0,
                        offset: Offset(0, 0),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30.0),
                    child: Stack(
                      children: [
                        // 1. Yellow Background Header (matches Tasks style)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: 302.0,
                          child: Container(
                            color: const Color(0xFFFFCC00),
                            child: Stack(
                              children: [
                                // Perfectly aligned header date/time
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  height: 37.0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          formattedDate,
                                          style: GoogleFonts.inter(
                                            fontSize: 16.0,
                                            fontWeight: FontWeight.w400,
                                            color: const Color(0xFF1C1C1E),
                                            height: 22.0 / 16.0,
                                            letterSpacing: -0.43,
                                          ),
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SvgPicture.asset(
                                              "assets/New Icons/fi-rr-time-past.svg",
                                              width: 22.0,
                                              height: 22.0,
                                              colorFilter: const ColorFilter.mode(Color(0xFF1C1C1E), BlendMode.srcIn),
                                            ),
                                            const SizedBox(width: 6.0),
                                            Text(
                                              formattedTime,
                                              style: GoogleFonts.inter(
                                                fontSize: 16.0,
                                                fontWeight: FontWeight.w400,
                                                color: const Color(0xFF1C1C1E),
                                                height: 22.0 / 16.0,
                                                letterSpacing: -0.43,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // 2. White Card Content
                        Positioned(
                          top: 37.0,
                          left: 0,
                          width: widget.width,
                          height: 302.0,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.all(Radius.circular(30.0)),
                            ),
                            child: Stack(
                              children: [
                                // Main Content area
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 20.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Note Title: size 32 or 40 depending on length
                                      Text(
                                        note.title.isNotEmpty ? note.title : "Untitled",
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: note.title.length > 15 ? 32.0 : 40.0,
                                          fontWeight: FontWeight.bold,
                                          height: 1.10,
                                          letterSpacing: -0.43,
                                          color: const Color(0xFF1C1C1E),
                                        ),
                                      ),
                                      const SizedBox(height: 12.0),
                                      
                                      // Body section
                                      Expanded(
                                        child: note.noteType == 'checklist'
                                            ? _buildChecklist(note, checklistItems)
                                            : SingleChildScrollView(
                                                physics: const BouncingScrollPhysics(),
                                                padding: const EdgeInsets.only(bottom: 64.0),
                                                child: Text(
                                                  note.previewText.isNotEmpty ? note.previewText : "No additional text",
                                                  style: GoogleFonts.inter(
                                                    fontSize: 16.0,
                                                    color: const Color(0xFF333333),
                                                    height: 1.4,
                                                  ),
                                                ),
                                              ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Floating Edit Button in bottom right
                                Positioned(
                                  bottom: 16.0,
                                  right: 16.0,
                                  child: TactileButton(
                                    onTap: () => widget.onEdit(note),
                                    useAppleSpring: true,
                                    compressionScale: 0.7,
                                    settleDuration: const Duration(milliseconds: 1000),
                                    playSelectionHaptic: true,
                                    child: Container(
                                      width: 50.0,
                                      height: 50.0,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.12),
                                            blurRadius: 10.0,
                                            offset: const Offset(0, 4),
                                          ),
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.04),
                                            blurRadius: 2.0,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      alignment: Alignment.center,
                                      child: SvgPicture.asset(
                                        "assets/icons/bottom_navigation/pencil.svg",
                                        width: 22.0,
                                        height: 22.0,
                                        colorFilter: const ColorFilter.mode(
                                          Color(0xFF1C1C1E),
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
