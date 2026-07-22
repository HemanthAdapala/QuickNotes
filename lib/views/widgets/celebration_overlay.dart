import 'dart:math';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CelebrationOverlay
//
// Full-screen particle burst triggered when all tasks for a day are completed.
//
// Shows:
//   • 40 colourful dots exploding from screen centre (ease-out, 1600ms)
//   • A floating "🎉 All tasks done!" badge that fades in/out
//
// Mounted as an OverlayEntry so it renders above the entire widget tree.
// Uses IgnorePointer so the user can still interact with the screen.
// ─────────────────────────────────────────────────────────────────────────────
class CelebrationOverlay extends StatefulWidget {
  final VoidCallback onDone;
  final String message;

  const CelebrationOverlay({
    super.key,
    required this.onDone,
    required this.message,
  });

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;

  // App-palette colours + a couple of extras for vibrancy
  static const List<Color> _palette = [
    Color(0xFF0088FF), // blue
    Color(0xFF34C759), // green
    Color(0xFFFFCC00), // yellow
    Color(0xFFFF383C), // red
    Color(0xFF8B5CF6), // purple
    Color(0xFFFF9500), // orange
    Color(0xFFFF2D55), // pink-red
    Color(0xFF5AC8FA), // sky blue
  ];

  @override
  void initState() {
    super.initState();

    final rng = Random();
    _particles = List.generate(
      50,
      (_) => _Particle(
        angle: rng.nextDouble() * 2 * pi,
        speed: 90.0 + rng.nextDouble() * 240.0,
        color: _palette[rng.nextInt(_palette.length)],
        radius: 3.5 + rng.nextDouble() * 5.5,
        delay: rng.nextDouble() * 0.18,
      ),
    );

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) {
          final t = _controller.value;

          // Badge opacity: fade-in 0–0.15, hold 0.15–0.70, fade-out 0.70–1.0
          final badgeOpacity = t < 0.15
              ? t / 0.15
              : t > 0.70
                  ? (1.0 - t) / 0.30
                  : 1.0;

          return Stack(
            children: [
              // ── Particles ────────────────────────────────────────────────
              CustomPaint(
                painter: _ParticlePainter(_particles, t),
                child: const SizedBox.expand(),
              ),

              // ── "All tasks done!" badge ───────────────────────────────────
              Center(
                child: Opacity(
                  opacity: badgeOpacity.clamp(0.0, 1.0),
                  child: Transform.scale(
                    // Subtle pop-in scale
                    scale: t < 0.12 ? 0.6 + (t / 0.12) * 0.4 : 1.0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 26, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 24,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1C1C1E),
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Particle data ─────────────────────────────────────────────────────────────
class _Particle {
  final double angle;
  final double speed;
  final Color color;
  final double radius;
  final double delay; // 0..1 fraction before this particle starts moving

  const _Particle({
    required this.angle,
    required this.speed,
    required this.color,
    required this.radius,
    required this.delay,
  });
}

// ── Custom painter ────────────────────────────────────────────────────────────
class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress; // 0..1

  const _ParticlePainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    // Burst origin: horizontally centred, ~55% down the screen
    final origin = Offset(size.width * 0.5, size.height * 0.55);

    for (final p in particles) {
      // Local progress after delay
      final raw = (progress - p.delay) / (1.0 - p.delay);
      final t = raw.clamp(0.0, 1.0);
      if (t <= 0) continue;

      // Cubic ease-out so particles decelerate naturally
      final eased = 1.0 - pow(1.0 - t, 3).toDouble();

      // Particles fade out in the final 35% of their life
      final opacity = t < 0.65 ? 1.0 : (1.0 - t) / 0.35;

      // Slight shrink as they travel
      final r = p.radius * (1.0 - t * 0.35);

      final dx = cos(p.angle) * p.speed * eased;
      final dy = sin(p.angle) * p.speed * eased;

      canvas.drawCircle(
        origin + Offset(dx, dy),
        r,
        Paint()
          ..color = p.color.withValues(alpha: opacity.clamp(0.0, 1.0))
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}
