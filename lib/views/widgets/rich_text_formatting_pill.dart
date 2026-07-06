import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'app_bottom_navigation_bar.dart';

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
    // These properties are ignored since we use BottomBarGlassSurface now
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
    final radius = borderRadius ?? BorderRadius.circular(isExpanded ? 24 : height / 2);

    return Padding(
      padding: margin,
      child: BottomBarGlassSurface(
        width: width,
        height: height,
        borderRadius: radius,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 420),
          curve: const Cubic(0.16, 1.0, 0.3, 1.0),
          width: width,
          height: height,
          padding: isExpanded ? padding : EdgeInsets.zero,
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
