import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../../models/task_item.dart';
import 'tactile_button.dart';

class TaskWidget extends StatefulWidget {
  final ValueChanged<String>? onComplete;
  final ValueChanged<TaskItem>? onEdit;
  final List<TaskItem> tasks;
  final double width;

  const TaskWidget({
    super.key,
    required this.tasks,
    this.onComplete,
    this.onEdit,
    this.width = 322.0,
  });

  @override
  State<TaskWidget> createState() => _TaskWidgetState();
}

class _TaskWidgetState extends State<TaskWidget> with TickerProviderStateMixin {
  // Slider Drag State
  double _dragX = 5.0; // Starts with a 5px margin
  final double _minDrag = 5.0;
  int _lastHapticCheckpoint = 0;
  bool _isDraggingSlider = false;

  // Swipe Dismiss State
  double _swipeX = 0.0;
  double _swipeY = 0.0;
  bool _isAnimatingSwipe = false;

  // Animation Controllers
  late AnimationController _resetController;
  late AnimationController _cardResetController;
  late AnimationController _cycleController;
  late AnimationController _successController;
  late AnimationController _entranceController;
  late List<Animation<double>> _cardEntranceAnimations;
  late Animation<double> _successScaleAnimation;
  late Animation<double> _particleAnimation;

  // Particle List
  final List<_Particle> _particles = [];
  late List<TaskItem> _currentTasksList;

  @override
  void initState() {
    super.initState();
    _currentTasksList = List.from(widget.tasks);

    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _cardResetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _cycleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _successScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.3).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
    ]).animate(_successController);

    _particleAnimation = CurvedAnimation(
      parent: _successController,
      curve: Curves.easeOutCubic,
    );

    // Initialize custom success particles radiating outwards
    final random = Random();
    for (int i = 0; i < 18; i++) {
      final angle = (i * 20.0) * pi / 180.0;
      final speed = 80.0 + random.nextDouble() * 100.0;
      _particles.add(_Particle(
        angle: angle,
        speed: speed,
        size: 3.0 + random.nextDouble() * 4.0,
      ));
    }

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
  void didUpdateWidget(covariant TaskWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tasks.length != oldWidget.tasks.length) {
      setState(() {
        _currentTasksList = List.from(widget.tasks);
      });
    } else {
      for (int i = 0; i < _currentTasksList.length; i++) {
        final updatedIndex = widget.tasks.indexWhere((t) => t.id == _currentTasksList[i].id);
        if (updatedIndex != -1) {
          _currentTasksList[i] = widget.tasks[updatedIndex];
        }
      }
    }
  }

  @override
  void dispose() {
    _resetController.dispose();
    _cardResetController.dispose();
    _cycleController.dispose();
    _successController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  double _getDragProgress(double maxDrag) =>
      ((_dragX - _minDrag) / (maxDrag - _minDrag)).clamp(0.0, 1.0);

  void _handleDragStart(DragStartDetails details) {
    if (_resetController.isAnimating || _successController.isAnimating) return;
    setState(() {
      _lastHapticCheckpoint = 0;
    });
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_resetController.isAnimating || _successController.isAnimating) return;

    final double maxDrag = 206.0;
    setState(() {
      _dragX = (_dragX + details.delta.dx).clamp(_minDrag, maxDrag);
    });

    // Notched Haptic Acceleration tick calculation
    final progress = _getDragProgress(maxDrag);
    final int checkpoint = (progress * 10).floor();
    if (checkpoint > _lastHapticCheckpoint) {
      _lastHapticCheckpoint = checkpoint;
      if (progress < 0.35) {
        HapticFeedback.lightImpact();
      } else if (progress < 0.70) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.heavyImpact();
      }
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_resetController.isAnimating || _successController.isAnimating) return;

    final double maxDrag = 206.0;
    final progress = _getDragProgress(maxDrag);
    if (progress >= 0.90) {
      _triggerSuccess(maxDrag);
    } else {
      _triggerReset();
    }
  }

  void _handleDragCancel() {
    if (_resetController.isAnimating || _successController.isAnimating) return;
    _triggerReset();
  }

  void _triggerSuccess(double maxDrag) {
    // Snap to end
    setState(() {
      _dragX = maxDrag;
    });

    HapticFeedback.vibrate();
    _successController.forward(from: 0.0);

    // After success animation, reset back to start with a delay
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) {
        // Reset state first before calling parent callback to avoid showing the next card with a dragged slider!
        setState(() {
          _dragX = _minDrag;
          _lastHapticCheckpoint = 0;
        });
        _successController.reset();

        if (widget.tasks.isNotEmpty) {
          widget.onComplete?.call(widget.tasks.first.id);
        }
      }
    });
  }

  void _triggerReset() {
    final startVal = _dragX;
    final tween = Tween<double>(begin: startVal, end: _minDrag);

    void listener() {
      setState(() {
        _dragX = tween.evaluate(_resetController);
      });
    }

    _resetController.addListener(listener);

    _resetController.forward(from: 0.0).then((_) {
      _resetController.removeListener(listener);
      _resetController.reset();
    });
  }

  // ── Card Swiping Gestures ──────────────────────────────────────────────────
  void _handleCardPanUpdate(DragUpdateDetails details) {
    if (_isAnimatingSwipe || _currentTasksList.isEmpty || _isDraggingSlider) return;
    setState(() {
      _swipeX += details.delta.dx;
      _swipeY += details.delta.dy;
    });
  }

  void _handleCardPanEnd(DragEndDetails details) {
    if (_isAnimatingSwipe || _currentTasksList.isEmpty || _isDraggingSlider) return;

    final distance = sqrt(_swipeX * _swipeX + _swipeY * _swipeY);
    if (distance > 120.0) {
      _triggerSwipeAway();
    } else {
      _triggerCardReset();
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

      if (mounted && _currentTasksList.isNotEmpty) {
        setState(() {
          // Cycle top task to the back of the deck
          final topTask = _currentTasksList.removeAt(0);
          _currentTasksList.add(topTask);
          _swipeX = 0.0;
          _swipeY = 0.0;
          _isAnimatingSwipe = false;
        });
        HapticFeedback.lightImpact();
      }
    });
  }

  void _triggerCardReset() {
    _isAnimatingSwipe = true;
    final tweenX = Tween<double>(begin: _swipeX, end: 0.0);
    final tweenY = Tween<double>(begin: _swipeY, end: 0.0);

    void listener() {
      setState(() {
        _swipeX = tweenX.evaluate(_cardResetController);
        _swipeY = tweenY.evaluate(_cardResetController);
      });
    }

    _cardResetController.addListener(listener);

    _cardResetController.forward(from: 0.0).then((_) {
      _cardResetController.removeListener(listener);
      _cardResetController.reset();
      _isAnimatingSwipe = false;
    });
  }

  Widget _buildBackgroundCard(int index, int totalCards) {
    final double offset = 37.0 * index;
    final int dist = totalCards - 1 - index;
    final double blurSigma = 1.0 + (dist - 1) * 0.1;

    final task = widget.tasks[totalCards - 1 - index];
    final formattedDate = DateFormat('EEE, d MMMM').format(task.dueDate);
    final formattedTime = DateFormat('hh:mm a').format(task.reminderTime ?? task.dueDate);

    Widget cardContent = Container(
      width: 322.0,
      height: 339.0,
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Color(0x3F000000),
            blurRadius: 20.0,
            offset: Offset(0, 0),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Blue Background Header
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              width: 322.0,
              height: 282.0,
              decoration: const ShapeDecoration(
                color: Color(0xFF0088FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30.0),
                    topRight: Radius.circular(30.0),
                  ),
                ),
              ),
            ),
          ),
          // White Card Background
          Positioned(
            left: 0,
            top: 37.0,
            child: Container(
              width: 322.0,
              height: 302.0,
              decoration: const ShapeDecoration(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(30.0)),
                ),
              ),
            ),
          ),
          // Header Date text
          Positioned(
            left: 28.0,
            top: 9.0,
            height: 23.0,
            child: Container(
              alignment: Alignment.centerLeft,
              child: Text(
                formattedDate,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16.0,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          // Header Time text with history clock icon (positioned from right to avoid cut off)
          Positioned(
            right: 28.0,
            top: 9.0,
            height: 23.0,
            child: Container(
              alignment: Alignment.centerRight,
              child: Text.rich(
                TextSpan(
                  children: [
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: SvgPicture.asset(
                        "assets/New Icons/fi-rr-time-past.svg",
                        width: 16.0,
                        height: 16.0,
                        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                      ),
                    ),
                    const WidgetSpan(child: SizedBox(width: 5.0)),
                    TextSpan(
                      text: formattedTime,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16.0,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
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
              child: Center(
                child: SizedBox(
                  width: 322.0,
                  height: 339.0,
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
      child: cardContent,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentTasksList.isEmpty) {
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
                  color: const Color(0xFF0088FF).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.check_circle_outline,
                  size: 40.0,
                  color: Color(0xFF0088FF),
                ),
              ),
              const SizedBox(height: 16.0),
              Text(
                "All Caught Up!",
                style: GoogleFonts.inter(
                  fontSize: 22.0,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
              const SizedBox(height: 8.0),
              Text(
                "No pending tasks in this section.",
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

    final double maxDrag = 206.0;
    final progress = _getDragProgress(maxDrag);
    final double cardScale = 1.0 + (progress * 0.02); // Sensory drag scale lift
    final double cardShadowBlur = 16.0 + (progress * 8.0); // Shadow lift blur (16 to 24)

    final int numCards = _currentTasksList.length.clamp(1, 3);
    const double cardOffset = 37.0;
    final double overallHeight = 339.0 + (numCards - 1) * cardOffset;

    final task = _currentTasksList.first;
    final formattedDate = DateFormat('EEE, d MMMM').format(task.dueDate);
    final formattedTime = DateFormat('hh:mm a').format(task.reminderTime ?? task.dueDate);

    final String priority = task.priority;
    final Color priorityColor;
    if (priority.toLowerCase() == 'high') {
      priorityColor = const Color(0xFFFF383C);
    } else if (priority.toLowerCase() == 'medium') {
      priorityColor = const Color(0xFFFFCC00);
    } else if (priority.toLowerCase() == 'low') {
      priorityColor = const Color(0xFF0088FF);
    } else {
      priorityColor = const Color(0xFF8E8E93);
    }

    final double titleTop = (priority.toLowerCase() == 'none') ? 113.0 : 126.0;

    return SizedBox(
      width: widget.width,
      height: overallHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Render background card peaks (from back to front)
          for (int i = 0; i < numCards - 1; i++)
            _buildBackgroundCard(i, numCards),

          // Render interactive front card (shifted down by offset)
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
                onPanUpdate: _handleCardPanUpdate,
                onPanEnd: _handleCardPanEnd,
                child: Center(
                  child: Transform.rotate(
                    angle: (_swipeX / widget.width) * (pi / 12),
                    child: Transform.scale(
                      scale: cardScale,
                      child: SizedBox(
                        width: 322.0,
                        height: 339.0,
                        child: Container(
                          decoration: const BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x3F000000),
                                blurRadius: 20.0,
                                offset: Offset(0, 0),
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              // Blue Background Header
                              Positioned(
                                left: 0,
                                top: 0,
                                child: Container(
                                  width: 322.0,
                                  height: 282.0,
                                  decoration: const ShapeDecoration(
                                    color: Color(0xFF0088FF),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(30.0),
                                        topRight: Radius.circular(30.0),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // White Card Background
                              Positioned(
                                left: 0,
                                top: 37.0,
                                child: Container(
                                  width: 322.0,
                                  height: 302.0,
                                  decoration: const ShapeDecoration(
                                    color: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.all(Radius.circular(30.0)),
                                    ),
                                  ),
                                ),
                              ),
                              // Header Date text
                              Positioned(
                                left: 28.0,
                                top: 9.0,
                                height: 23.0,
                                child: Container(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    formattedDate,
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ),
                              // Header Time text with history clock icon (positioned from right to avoid cut off)
                              Positioned(
                                right: 28.0,
                                top: 9.0,
                                height: 23.0,
                                child: Container(
                                  alignment: Alignment.centerRight,
                                  child: Text.rich(
                                    TextSpan(
                                      children: [
                                        WidgetSpan(
                                          alignment: PlaceholderAlignment.middle,
                                          child: SvgPicture.asset(
                                            "assets/New Icons/fi-rr-time-past.svg",
                                            width: 16.0,
                                            height: 16.0,
                                            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                          ),
                                        ),
                                        const WidgetSpan(child: SizedBox(width: 5.0)),
                                        TextSpan(
                                          text: formattedTime,
                                          style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontSize: 16.0,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Priority Flag Pill
                              if (priority.toLowerCase() != 'none')
                                Positioned(
                                  left: 18.0,
                                  top: 80.0,
                                  height: 38.0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                    decoration: ShapeDecoration(
                                      color: const Color(0xFFF2F2F7),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(19.0),
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text.rich(
                                      TextSpan(
                                        children: [
                                          WidgetSpan(
                                            alignment: PlaceholderAlignment.middle,
                                            child: SvgPicture.asset(
                                              "assets/New Icons/flag-alt 1.svg",
                                              width: 14.0,
                                              height: 14.0,
                                              colorFilter: ColorFilter.mode(priorityColor, BlendMode.srcIn),
                                            ),
                                          ),
                                          const WidgetSpan(child: SizedBox(width: 6.0)),
                                          TextSpan(
                                            text: priority,
                                            style: GoogleFonts.inter(
                                              color: priorityColor,
                                              fontSize: 15.0,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              // Title Text (constrained width and height)
                              Positioned(
                                left: 18.0,
                                top: titleTop,
                                width: 223.0,
                                height: 150.0,
                                child: Text(
                                  task.title.isNotEmpty ? task.title : 'Untitled Task',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF333333),
                                    fontSize: 40.0,
                                    fontWeight: FontWeight.w600,
                                    height: 1.0,
                                    letterSpacing: -0.43,
                                  ),
                                ),
                              ),
                              // Slider Track Container
                              Positioned(
                                left: 8.0,
                                top: 282.0,
                                width: 251.0,
                                height: 50.0,
                                child: GestureDetector(
                                  onHorizontalDragDown: (_) {
                                    setState(() {
                                      _isDraggingSlider = true;
                                    });
                                  },
                                  onHorizontalDragStart: _handleDragStart,
                                  onHorizontalDragUpdate: _handleDragUpdate,
                                  onHorizontalDragEnd: (details) {
                                    _handleDragEnd(details);
                                    setState(() {
                                      _isDraggingSlider = false;
                                    });
                                  },
                                  onHorizontalDragCancel: () {
                                    _handleDragCancel();
                                    setState(() {
                                      _isDraggingSlider = false;
                                    });
                                  },
                                  child: Container(
                                    width: 251.0,
                                    height: 50.0,
                                    decoration: BoxDecoration(
                                      color: const Color(0x33787878),
                                      borderRadius: BorderRadius.circular(25.0),
                                    ),
                                    child: Stack(
                                      children: [
                                        // Blue Slide Fill
                                        if (progress > 0)
                                          Positioned(
                                            left: 0,
                                            top: 0,
                                            bottom: 0,
                                            width: _dragX + 40.0,
                                            child: Opacity(
                                              opacity: progress.clamp(0.0, 1.0),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  gradient: const LinearGradient(
                                                    colors: [
                                                      Color(0xFF0088FF),
                                                      Color(0xFF66B2FF),
                                                    ],
                                                  ),
                                                  borderRadius: BorderRadius.circular(25.0),
                                                ),
                                              ),
                                            ),
                                          ),
                                        // Text
                                        Center(
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const SizedBox(width: 32.0),
                                              Flexible(
                                                child: Text(
                                                  "Drag to mark done",
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 16.0,
                                                    fontWeight: FontWeight.w600,
                                                    color: progress > 0.5 ? Colors.white : const Color(0xFF333333),
                                                    height: 1.0,
                                                    letterSpacing: -0.43,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 4.0),
                                              SvgPicture.asset(
                                                "assets/New Icons/fi-rr-angle-double-small-right.svg",
                                                width: 14.0,
                                                height: 14.0,
                                                colorFilter: ColorFilter.mode(
                                                  progress > 0.5 ? Colors.white : const Color(0xFF333333),
                                                  BlendMode.srcIn,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Checkmark Circular Button
                                        Positioned(
                                          left: _dragX,
                                          top: 5.0,
                                          width: 40.0,
                                          height: 40.0,
                                          child: ScaleTransition(
                                            scale: _successScaleAnimation,
                                            child: Stack(
                                              clipBehavior: Clip.none,
                                              children: [
                                                Positioned.fill(
                                                  child: CustomPaint(
                                                    painter: _ParticlePainter(
                                                      particles: _particles,
                                                      animVal: _particleAnimation.value,
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  decoration: const BoxDecoration(
                                                    color: Colors.white,
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Color(0x20000000),
                                                        blurRadius: 4.0,
                                                        offset: Offset(0, 2),
                                                      ),
                                                    ],
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: SvgPicture.asset(
                                                    "assets/New Icons/fi-rr-check.svg",
                                                    width: 22.0,
                                                    height: 22.0,
                                                    colorFilter: const ColorFilter.mode(
                                                      Color(0xFF0088FF),
                                                      BlendMode.srcIn,
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
                              // Floating Edit Button
                              Positioned(
                                left: 264.0,
                                top: 282.0,
                                child: TactileButton(
                                  onTap: () => widget.onEdit?.call(task),
                                  useAppleSpring: true,
                                  compressionScale: 0.7,
                                  settleDuration: const Duration(milliseconds: 1000),
                                  child: Container(
                                    width: 50.0,
                                    height: 50.0,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Color(0x3F000000),
                                          blurRadius: 16.0,
                                          offset: Offset(0, 0),
                                          spreadRadius: 0,
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: SvgPicture.asset(
                                      "assets/app_bottom_navigation_bar_Icons/pencil.svg",
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

class _Particle {
  final double angle;
  final double speed;
  final double size;

  _Particle({
    required this.angle,
    required this.speed,
    required this.size,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double animVal;

  _ParticlePainter({
    required this.particles,
    required this.animVal,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (animVal <= 0.0 || animVal >= 1.0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = const Color(0xFF0088FF).withValues(alpha: 1.0 - animVal)
      ..style = PaintingStyle.fill;

    for (final p in particles) {
      final distance = p.speed * animVal;
      final dx = distance * cos(p.angle);
      final dy = distance * sin(p.angle);
      canvas.drawCircle(center + Offset(dx, dy), p.size * (1.0 - animVal), paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.animVal != animVal;
}
