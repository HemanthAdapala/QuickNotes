import 'dart:ui';
import 'package:flutter/material.dart' hide BoxDecoration, BoxShadow;
import 'package:flutter_inset_shadow/flutter_inset_shadow.dart';
import '../../themes/glassmorphism_presets.dart';

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.padding = EdgeInsets.zero,
    this.blurSigma,
    this.frostOpacity,
    this.customShadows,
    this.customBlurSigma,
    this.customFrostOpacity,
    this.customDepthOpacity,
    this.customTintColor,
    this.customOutlineOpacity,
    this.customOutlineWidth,
    this.customBevelIntensity,
  });

  final Widget child;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final double? blurSigma;
  final double? frostOpacity;
  final List<BoxShadow>? customShadows;
  final double? customBlurSigma;
  final double? customFrostOpacity;
  final double? customDepthOpacity;
  final Color? customTintColor;
  final double? customOutlineOpacity;
  final double? customOutlineWidth;
  final double? customBevelIntensity;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final activeBlur = customBlurSigma ?? blurSigma ?? GlassmorphismPresets.blurSigma;
    final activeFrost = customFrostOpacity ?? frostOpacity ?? GlassmorphismPresets.frostOpacity;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: customShadows ?? GlassmorphismPresets.shadows,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: activeBlur,
            sigmaY: activeBlur,
          ),
          child: CustomPaint(
            foregroundPainter: _GlassRimPainter(
              borderRadius: borderRadius,
              depthOpacity: customDepthOpacity ?? GlassmorphismPresets.depthOpacity,
              bevelIntensity: customBevelIntensity ?? GlassmorphismPresets.bevelIntensity,
              lightDirection: Alignment.topCenter,
            ),
            child: Container(
              width: width,
              height: height,
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                color: customTintColor ?? GlassmorphismPresets.fillColor,
                boxShadow: GlassmorphismPresets.innerShadows,
                border: Border.all(
                  color: Colors.white.withValues(
                    alpha: customOutlineOpacity ?? GlassmorphismPresets.outlineOpacity,
                  ),
                  width: customOutlineWidth ?? GlassmorphismPresets.outlineWidth,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.72),
                    Colors.white.withValues(
                      alpha: activeFrost,
                    ),
                    customTintColor?.withValues(alpha: 0.12) ?? scheme.surfaceTint.withValues(alpha: 0.08),
                    Colors.black.withValues(alpha: 0.035),
                  ],
                  stops: const [0, 0.42, 0.78, 1],
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassRimPainter extends CustomPainter {
  const _GlassRimPainter({
    required this.borderRadius,
    required this.depthOpacity,
    required this.bevelIntensity,
    required this.lightDirection,
  });

  final BorderRadius borderRadius;
  final double depthOpacity;
  final double bevelIntensity;
  final Alignment lightDirection;

  @override
  void paint(Canvas canvas, Size size) {
    if (bevelIntensity <= 0.0) return;
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect).deflate(0.8);

    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..shader = LinearGradient(
        begin: lightDirection,
        end: Alignment(-lightDirection.x, -lightDirection.y),
        colors: [
          const Color(0xE6FFFFFF).withValues(alpha: 0.9 * bevelIntensity),
          const Color(0x55FFFFFF).withValues(alpha: 0.33 * bevelIntensity),
          const Color(0x33000000).withValues(alpha: 0.2 * bevelIntensity),
        ],
        stops: const [0, 0.62, 1],
      ).createShader(rect);

    final innerDepthPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.38 * bevelIntensity),
          Colors.transparent,
          Colors.black.withValues(alpha: depthOpacity * bevelIntensity),
        ],
        stops: const [0, 0.48, 1],
      ).createShader(rect);

    final refractionPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.white.withValues(alpha: 0.38 * bevelIntensity),
          Colors.white.withValues(alpha: 0.08 * bevelIntensity),
          Colors.white.withValues(alpha: 0.30 * bevelIntensity),
        ],
      ).createShader(rect);

    canvas
      ..drawRRect(rrect, rimPaint)
      ..drawRRect(rrect.deflate(1.4), innerDepthPaint)
      ..drawRRect(rrect.deflate(3.2), refractionPaint);
  }

  @override
  bool shouldRepaint(_GlassRimPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.depthOpacity != depthOpacity ||
        oldDelegate.bevelIntensity != bevelIntensity ||
        oldDelegate.lightDirection != lightDirection;
  }
}
