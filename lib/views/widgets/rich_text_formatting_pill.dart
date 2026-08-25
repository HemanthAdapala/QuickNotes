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

    return BottomBarGlassSurface(
      width: width,
      height: height,
      borderRadius: radius,
      child: SizedBox(
        width: width,
        height: height,
        child: IconTheme.merge(
          data: const IconThemeData(
            color: Color(0xFF333333),
            size: 22,
          ),
          child: DefaultTextStyle.merge(
            style: const TextStyle(
              color: Color(0xFF333333),
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
