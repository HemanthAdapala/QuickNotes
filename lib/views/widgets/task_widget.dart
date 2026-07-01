import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'tactile_button.dart';

class TaskWidget extends StatefulWidget {
  final VoidCallback? onComplete;
  final VoidCallback? onEdit;
  final int totalTasks;
  final double blurSigma;

  const TaskWidget({
    super.key,
    this.onComplete,
    this.onEdit,
    this.totalTasks = 4,
    this.blurSigma = 4.0,
  });

  @override
  State<TaskWidget> createState() => _TaskWidgetState();
}

class _TaskWidgetState extends State<TaskWidget> with TickerProviderStateMixin {
  // Slider Drag State
  double _dragX = 5.0; // Starts with a 5px margin
  final double _minDrag = 5.0;
  final double _maxDrag = 211.0; // Slide all the way to the absolute edge
  int _lastHapticCheckpoint = 0;

  // Animation Controllers
  late AnimationController _resetController;
  late AnimationController _successController;
  late Animation<double> _successScaleAnimation;
  late Animation<double> _particleAnimation;

  // Particle List
  final List<_Particle> _particles = [];

  @override
  void initState() {
    super.initState();

    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
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
  }

  @override
  void dispose() {
    _resetController.dispose();
    _successController.dispose();
    super.dispose();
  }

  double get _dragProgress => ((_dragX - _minDrag) / (_maxDrag - _minDrag)).clamp(0.0, 1.0);

  void _handleDragStart(DragStartDetails details) {
    if (_resetController.isAnimating || _successController.isAnimating) return;
    setState(() {
      _lastHapticCheckpoint = 0;
    });
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_resetController.isAnimating || _successController.isAnimating) return;

    setState(() {
      _dragX = (_dragX + details.delta.dx).clamp(_minDrag, _maxDrag);
    });

    // Notched Haptic Acceleration tick calculation
    final progress = _dragProgress;
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

    final progress = _dragProgress;
    if (progress >= 0.90) {
      _triggerSuccess();
    } else {
      _triggerReset();
    }
  }

  void _triggerSuccess() {
    // Snap to end
    setState(() {
      _dragX = _maxDrag;
    });

    HapticFeedback.vibrate();
    _successController.forward(from: 0.0);

    // After success animation, reset back to start with a delay
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) {
        widget.onComplete?.call();
        _triggerReset();
      }
    });
  }

  void _triggerReset() {
    final startVal = _dragX;
    final tween = Tween<double>(begin: startVal, end: _minDrag);

    _resetController.addListener(() {
      setState(() {
        _dragX = tween.evaluate(_resetController);
      });
    });

    _resetController.forward(from: 0.0).then((_) {
      _resetController.removeListener(() {});
      _resetController.reset();
    });
  }

  Widget _buildBackgroundCard(int index, int totalCards) {
    final double offset = 10.0 * index;
    final double blurSigma = widget.blurSigma;

    Widget cardContent = Container(
      width: 322.0,
      height: 339.0,
      decoration: BoxDecoration(
        color: const Color(0xFF0088FF),
        borderRadius: BorderRadius.circular(30.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000), // Black 25% opacity
            blurRadius: 16.0,
            offset: Offset(0, 0),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Perfectly vertically aligned header date/time
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 37.0, // center aligned in the visible peak
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Tue, 1 June 2026",
                    style: GoogleFonts.inter(
                      fontSize: 16.0,
                      fontWeight: FontWeight.w400,
                      color: Colors.white,
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
                        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                      ),
                      const SizedBox(width: 6.0),
                      Text(
                        "02:00 AM",
                        style: GoogleFonts.inter(
                          fontSize: 16.0,
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
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

    return Positioned(
      top: offset,
      left: 0,
      right: 0,
      height: 339.0,
      child: cardContent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _dragProgress;
    final double cardScale = 1.0 + (progress * 0.02); // Sensory drag scale lift
    final double cardShadowBlur = 16.0 + (progress * 8.0); // Shadow lift blur (16 to 24)

    final int numCards = widget.totalTasks.clamp(1, 4);
    const double cardOffset = 10.0;
    final double overallHeight = 339.0 + (numCards - 1) * cardOffset;

    return SizedBox(
      width: 322.0,
      height: overallHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Render background card peaks (from back to front)
          for (int i = 0; i < numCards - 1; i++)
            _buildBackgroundCard(i, numCards),

          // Render interactive front card (shifted down by offset)
          Positioned(
            top: (numCards - 1) * cardOffset,
            left: 0,
            right: 0,
            height: 339.0,
            child: Center(
              child: Transform.scale(
                scale: cardScale,
                child: Container(
                  width: 322.0,
                  height: 339.0,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30.0),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x40000000), // Black 25% opacity
                        blurRadius: cardShadowBlur,
                        offset: const Offset(0, 0),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30.0),
                    child: Stack(
                      children: [
                        // 1. Blue Background Header (fills H: 302, corner radius 30)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: 302.0,
                          child: Container(
                            color: const Color(0xFF0088FF),
                            child: Stack(
                              children: [
                                // Perfectly vertical aligned header date/time
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  height: 37.0, // center aligned in the visible peak
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "Tue, 1 June 2026",
                                          style: GoogleFonts.inter(
                                            fontSize: 16.0,
                                            fontWeight: FontWeight.w400,
                                            color: Colors.white,
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
                                              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                            ),
                                            const SizedBox(width: 6.0),
                                            Text(
                                              "02:00 AM",
                                              style: GoogleFonts.inter(
                                                fontSize: 16.0,
                                                fontWeight: FontWeight.w400,
                                                color: Colors.white,
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

                        // 2. White Card (H: 302, corner radius 30, placed 37px below blue card top)
                        Positioned(
                          top: 37.0,
                          left: 0,
                          width: 322.0,
                          height: 302.0,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(30.0),
                                topRight: Radius.circular(30.0),
                                bottomLeft: Radius.circular(30.0),
                                bottomRight: Radius.circular(30.0),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(9.0, 20.0, 9.0, 20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Priority flag pill (FF383C)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF383C).withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(30.0),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SvgPicture.asset(
                                          "assets/New Icons/flag-alt 1.svg",
                                          width: 14.0,
                                          height: 14.0,
                                          colorFilter: const ColorFilter.mode(Color(0xFFFF383C), BlendMode.srcIn),
                                        ),
                                        const SizedBox(width: 4.0),
                                        Text(
                                          "High",
                                          style: GoogleFonts.inter(
                                            fontSize: 16.0,
                                            fontWeight: FontWeight.w400,
                                            color: const Color(0xFFFF383C),
                                            height: 22.0 / 16.0,
                                            letterSpacing: -0.43,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12.0),

                                  // Title Text: Inter, bold, 40-size, line height 22
                                  Expanded(
                                    child: Text(
                                      "Wiring\nDashboard\nAnalytics",
                                      style: GoogleFonts.inter(
                                        fontSize: 40.0,
                                        fontWeight: FontWeight.bold,
                                        height: 1.10,
                                        letterSpacing: -0.43,
                                        color: const Color(0xFF1C1C1E),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16.0),

                                  // Slider row (Drag to mark done & edit button)
                                  Row(
                                    children: [
                                      // Slider background track: width 251, height 50
                                      GestureDetector(
                                        onHorizontalDragStart: _handleDragStart,
                                        onHorizontalDragUpdate: _handleDragUpdate,
                                        onHorizontalDragEnd: _handleDragEnd,
                                        child: Container(
                                          width: 251.0,
                                          height: 50.0,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFCCCCCC).withValues(alpha: 0.35),
                                            borderRadius: BorderRadius.circular(25.0),
                                          ),
                                          child: Stack(
                                            children: [
                                              // Blue Slide Fill (Fades in during drag, aligns right edge to checkmark)
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

                                              // Slider track text: "Drag to mark done"
                                              Center(
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    const SizedBox(width: 32.0), // Spacer for checkmark
                                                    Text(
                                                      "Drag to mark done",
                                                      style: GoogleFonts.inter(
                                                        fontSize: 16.0,
                                                        fontWeight: FontWeight.w600,
                                                        color: progress > 0.5 ? Colors.white : const Color(0xFF777777),
                                                        height: 22.0 / 16.0,
                                                        letterSpacing: -0.43,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4.0),
                                                    SvgPicture.asset(
                                                      "assets/New Icons/fi-rr-angle-double-small-right.svg",
                                                      width: 14.0,
                                                      height: 14.0,
                                                      colorFilter: ColorFilter.mode(
                                                        progress > 0.5 ? Colors.white : const Color(0xFF777777),
                                                        BlendMode.srcIn,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              // Sliding checkmark button: size 40x40
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
                                                      // Particle success layer
                                                      Positioned.fill(
                                                        child: CustomPaint(
                                                          painter: _ParticlePainter(
                                                            particles: _particles,
                                                            animVal: _particleAnimation.value,
                                                          ),
                                                        ),
                                                      ),
                                                      // Actual checkmark circular button
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
                                      const SizedBox(width: 3.0),
                                      // Task Editing button: 50x50, pencil icon
                                      TactileButton(
                                        onTap: widget.onEdit ?? () {},
                                        child: Container(
                                          width: 50.0,
                                          height: 50.0,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF2F2EE),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: const Color(0xFFE2E2DF),
                                              width: 1.0,
                                            ),
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
                                    ],
                                  ),
                                ],
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
