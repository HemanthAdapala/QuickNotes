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
    this.useBottomBarPreset = false,
  });

  const GlassSurface.bottomBar({
    Key? key,
    required Widget child,
    double? width,
    double? height,
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(25)),
  }) : this(
          key: key,
          child: child,
          width: width,
          height: height,
          borderRadius: borderRadius,
          useBottomBarPreset: true,
        );

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
  final bool useBottomBarPreset;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBlur =
        customBlurSigma ?? blurSigma ?? GlassmorphismPresets.blurSigma;
    final activeFrost =
        customFrostOpacity ?? frostOpacity ?? GlassmorphismPresets.frostOpacity;

    final Widget backgroundWidget;
    if (customTintColor != null) {
      // Apple Tinted Glass System:
      // 1. Base Backing (FFFFFF/000000, 94% opacity)
      // 2. Tint Color (Accent Color, 20-92% opacity)
      backgroundWidget = Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              color: (isDark ? Colors.black : Colors.white)
                  .withValues(alpha: 0.94),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              color: customTintColor!.withValues(alpha: isDark ? 0.40 : 0.92),
              backgroundBlendMode: BlendMode.multiply,
            ),
          ),
        ],
      );
    } else {
      backgroundWidget = Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    Colors.black.withValues(alpha: 0.45),
                    Colors.black.withValues(alpha: 0.25),
                    scheme.surfaceTint.withValues(alpha: 0.12),
                    Colors.black.withValues(alpha: 0.50),
                  ]
                : [
                    Colors.white.withValues(alpha: 0.72),
                    Colors.white.withValues(
                      alpha: activeFrost,
                    ),
                    scheme.surfaceTint.withValues(alpha: 0.08),
                    Colors.black.withValues(alpha: 0.035),
                  ],
            stops: const [0, 0.42, 0.78, 1],
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: useBottomBarPreset
            ? GlassmorphismPresets.shadows
            : (customShadows ?? GlassmorphismPresets.shadows),
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: useBottomBarPreset
                ? GlassmorphismPresets.blurSigma
                : activeBlur,
            sigmaY: useBottomBarPreset
                ? GlassmorphismPresets.blurSigma
                : activeBlur,
          ),
          child: CustomPaint(
            foregroundPainter: useBottomBarPreset
                ? _InnerGlassBorderPainter(borderRadius: borderRadius)
                : _GlassRimPainter(
                    borderRadius: borderRadius,
                    depthOpacity:
                        customDepthOpacity ?? GlassmorphismPresets.depthOpacity,
                    bevelIntensity: customBevelIntensity ??
                        GlassmorphismPresets.bevelIntensity,
                    lightDirection: Alignment.topCenter,
                  ),
            child: SizedBox(
              width: width,
              height: height,
              child: Padding(
                padding: padding,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: borderRadius,
                    color: useBottomBarPreset
                        ? GlassmorphismPresets.fillColor
                        : (customTintColor != null
                            ? Colors.transparent
                            : GlassmorphismPresets.fillColor),
                    boxShadow: GlassmorphismPresets.innerShadows,
                    border: Border.all(
                      color: useBottomBarPreset
                          ? Colors.white.withValues(alpha: 0.45)
                          : (customTintColor ?? Colors.white).withValues(
                              alpha: customOutlineOpacity ??
                                  GlassmorphismPresets.outlineOpacity,
                            ),
                      width: useBottomBarPreset
                          ? 0.8
                          : (customOutlineWidth ??
                              GlassmorphismPresets.outlineWidth),
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.passthrough,
                    children: [
                      Positioned.fill(child: backgroundWidget),
                      child,
                    ],
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

class _InnerGlassBorderPainter extends CustomPainter {
  const _InnerGlassBorderPainter({required this.borderRadius});

  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.20),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.4, 0.4, size.width - 0.8, size.height - 0.8),
      borderRadius.topLeft,
    );

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_InnerGlassBorderPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius;
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
