import 'dart:ui';

import 'package:flutter/material.dart' hide BoxDecoration, BoxShadow;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_inset_shadow/flutter_inset_shadow.dart';
import '../../themes/glassmorphism_presets.dart';

class RichTextFormattingPillContainer extends StatelessWidget {
  const RichTextFormattingPillContainer({
    super.key,
    required this.child,
    required this.isExpanded,
    this.width = 347,
    this.height = 48,
    this.padding = const EdgeInsets.symmetric(horizontal: 14),
    this.margin = EdgeInsets.zero,
    this.borderRadius,
    this.blurSigma = 18,
    this.frostOpacity = 0.34,
    this.depthOpacity = 0.18,
    this.lightDirection = const Alignment(-0.45, -0.8),
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
  final bool isExpanded;
  final double width;
  final double height;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final BorderRadius? borderRadius;
  final double blurSigma;
  final double frostOpacity;
  final double depthOpacity;
  final Alignment lightDirection;
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
    final colors = Theme.of(context).colorScheme;
    final radius = borderRadius ?? BorderRadius.circular(isExpanded ? 24 : height / 2);

    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: customShadows ?? GlassmorphismPresets.shadows,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: customBlurSigma ?? GlassmorphismPresets.blurSigma,
              sigmaY: customBlurSigma ?? GlassmorphismPresets.blurSigma,
            ),
            child: CustomPaint(
              foregroundPainter: _RichTextPillGlassPainter(
                borderRadius: radius,
                depthOpacity: customDepthOpacity ?? GlassmorphismPresets.depthOpacity,
                bevelIntensity: customBevelIntensity ?? GlassmorphismPresets.bevelIntensity,
                lightDirection: Alignment.topCenter,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 420),
                curve: const Cubic(0.16, 1.0, 0.3, 1.0),
                width: width,
                height: height,
                padding: isExpanded ? padding : EdgeInsets.zero,
                decoration: BoxDecoration(
                  borderRadius: radius,
                  color: customTintColor ?? GlassmorphismPresets.fillColor,
                  boxShadow: customShadows ?? GlassmorphismPresets.innerShadows,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: customOutlineOpacity ?? GlassmorphismPresets.outlineOpacity),
                    width: customOutlineWidth ?? GlassmorphismPresets.outlineWidth,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.72),
                      Colors.white.withValues(alpha: customFrostOpacity ?? GlassmorphismPresets.frostOpacity),
                      customTintColor?.withValues(alpha: 0.12) ?? colors.surfaceTint.withValues(alpha: 0.08),
                      Colors.black.withValues(alpha: 0.035),
                    ],
                    stops: const [0, 0.42, 0.78, 1],
                  ),
                ),
                child: IconTheme.merge(
                  data: const IconThemeData(
                    color: Color(0xFF333333),
                    size: 22,
                  ),
                  child: DefaultTextStyle.merge(
                    style: const TextStyle(
                      color: Color(0xFF333333),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.9, end: 1.0).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey(isExpanded),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RichTextFormattingPillIcon extends StatelessWidget {
  const RichTextFormattingPillIcon({
    super.key,
    required this.assetName,
    this.semanticLabel,
    this.size = 22,
    this.color,
  });

  final String assetName;
  final String? semanticLabel;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? IconTheme.of(context).color;

    return SvgPicture.asset(
      assetName,
      width: size,
      height: size,
      semanticsLabel: semanticLabel,
      colorFilter: iconColor == null
          ? null
          : ColorFilter.mode(iconColor, BlendMode.srcIn),
    );
  }
}

class _RichTextPillGlassPainter extends CustomPainter {
  const _RichTextPillGlassPainter({
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
  bool shouldRepaint(_RichTextPillGlassPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.depthOpacity != depthOpacity ||
        oldDelegate.bevelIntensity != bevelIntensity ||
        oldDelegate.lightDirection != lightDirection;
  }
}
