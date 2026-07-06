import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_bottom_navigation_bar.dart'; // Import BottomBarGlassSurface
import 'tactile_button.dart';

class AppHeaderBar extends StatelessWidget {
  final Widget? leftChild;
  final VoidCallback? onLeftTap;
  final double leftWidth;
  final String leftHeroTag;

  final Widget? rightChild;
  final double rightWidth;
  final String rightHeroTag;

  final String? title;
  final Widget? titleWidget;
  final Color? titleColor;

  const AppHeaderBar({
    super.key,
    this.leftChild,
    this.onLeftTap,
    this.leftWidth = 44.0,
    this.leftHeroTag = 'hero_profile_header',
    this.rightChild,
    this.rightWidth = 44.0,
    this.rightHeroTag = 'hero_more_options',
    this.title,
    this.titleWidget,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44.0,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Left Button (Hero-wrapped Glass Surface)
          if (leftChild != null)
            Positioned(
              left: 0,
              top: 0,
              width: leftWidth,
              height: 44.0,
              child: Hero(
                tag: leftHeroTag,
                child: BottomBarGlassSurface(
                  width: leftWidth,
                  height: 44.0,
                  borderRadius: BorderRadius.circular(22.0),
                  child: TactileButton(
                    useAppleSpring: true,
                    compressionScale: 0.7,
                    settleDuration: const Duration(milliseconds: 1000),
                    onTap: onLeftTap ?? () {},
                    child: Center(child: leftChild),
                  ),
                ),
              ),
            ),

          // Center Title Slot (widget takes precedence)
          if (titleWidget != null)
            Positioned.fill(
              child: Center(
                child: Material(
                  type: MaterialType.transparency,
                  child: titleWidget!,
                ),
              ),
            )
          else if (title != null)
            Positioned.fill(
              child: Center(
                child: Material(
                  type: MaterialType.transparency,
                  child: Text(
                    title!,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: titleColor ?? const Color(0xFF1C1C1E),
                    ),
                  ),
                ),
              ),
            ),

          // Right Button/Pill (Hero-wrapped Glass Surface with dynamic width morphing)
          if (rightChild != null)
            Positioned(
              right: 0,
              top: 0,
              width: rightWidth,
              height: 44.0,
              child: Hero(
                tag: rightHeroTag,
                child: BottomBarGlassSurface(
                  width: rightWidth,
                  height: 44.0,
                  borderRadius: BorderRadius.circular(22.0),
                  child: rightChild!,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
