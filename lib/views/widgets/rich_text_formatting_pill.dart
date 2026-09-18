import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'app_bottom_navigation_bar.dart'; // Import BottomBarGlassSurface

class RichTextFormattingPillContainer extends StatelessWidget {
  const RichTextFormattingPillContainer({
    super.key,
    required this.child,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  final Widget child;
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(20.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveColor =
        isDark ? const Color(0xFF8E8E93) : const Color(0xFF333333);

    return BottomBarGlassSurface(
      width: width,
      height: height,
      borderRadius: radius,
      child: SizedBox(
        width: width,
        height: height,
        child: IconTheme.merge(
          data: IconThemeData(
            color: inactiveColor,
            size: 22,
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(
              color: inactiveColor,
            ),
            child: child,
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
