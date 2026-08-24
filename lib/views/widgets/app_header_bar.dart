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

  final bool isExpanded;
  final double expandedWidth;
  final double expandedHeight;
  final Widget? expandedChild;
  final Duration expandDuration;
  final Duration shrinkDuration;
  final Curve expandCurve;
  final Curve shrinkCurve;

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
    this.isExpanded = false,
    this.expandedWidth = 192.0,
    this.expandedHeight = 100.0,
    this.expandedChild,
    this.expandDuration = const Duration(milliseconds: 500),
    this.shrinkDuration = const Duration(milliseconds: 415),
    this.expandCurve = Curves.easeOutCubic,
    this.shrinkCurve = Curves.easeInOutCubic,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: isExpanded ? expandedHeight : 44.0,
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

          // Center Title Slot — titleWidget takes precedence.
          // IMPORTANT: Uses Positioned(left/right) instead of Positioned.fill so
          // the center widget occupies only the space *between* the left and right
          // buttons. Positioned.fill would overlap the button zones, causing the
          // BackdropFilter inside BottomBarGlassSurface to produce a gray
          // compositing rectangle across the entire header area.
          if (titleWidget != null)
            Positioned(
              left: leftWidth,
              right: rightWidth,
              top: 0,
              bottom: 0,
              child: Center(child: titleWidget!),
            )
          else if (title != null)
            Positioned.fill(
              child: Center(
                child: Material(
                  type: MaterialType.transparency,
                  child: Text(
                    title!,
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: titleColor ?? const Color(0xFF1C1C1E),
                    ),
                  ),
                ),
              ),
            ),

          // Right Button/Pill (Hero-wrapped Glass Surface with configurable in-place expansion/shrinking)
          if (rightChild != null)
            Positioned(
              right: 0,
              top: 0,
              child: AnimatedContainer(
                duration: isExpanded ? expandDuration : shrinkDuration,
                curve: isExpanded ? expandCurve : shrinkCurve,
                width: isExpanded ? expandedWidth : rightWidth,
                height: isExpanded ? expandedHeight : 44.0,
                child: Hero(
                  tag: rightHeroTag,
                  child: BottomBarGlassSurface(
                    width: isExpanded ? expandedWidth : rightWidth,
                    height: isExpanded ? expandedHeight : 44.0,
                    borderRadius:
                        BorderRadius.circular(isExpanded ? 20.0 : 22.0),
                    useFrost: true,
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(isExpanded ? 20.0 : 22.0),
                      child: Stack(
                        children: [
                          // Collapsed state: 3-dots icon
                          AnimatedOpacity(
                            duration:
                                Duration(milliseconds: isExpanded ? 200 : 250),
                            curve: Curves.easeOut,
                            opacity: isExpanded ? 0.0 : 1.0,
                            child: IgnorePointer(
                              ignoring: isExpanded,
                              child: rightChild!,
                            ),
                          ),

                          // Expanded state: MoreOptionsPopup menu items (staggered fade & subtle slide)
                          if (expandedChild != null)
                            AnimatedOpacity(
                              duration: Duration(
                                  milliseconds: isExpanded ? 420 : 200),
                              curve: Curves.easeOutCubic,
                              opacity: isExpanded ? 1.0 : 0.0,
                              child: IgnorePointer(
                                ignoring: !isExpanded,
                                child: AnimatedSlide(
                                  duration: Duration(
                                      milliseconds: isExpanded ? 420 : 200),
                                  curve: Curves.easeOutCubic,
                                  offset: isExpanded
                                      ? Offset.zero
                                      : const Offset(0, 0.08),
                                  child: OverflowBox(
                                    minWidth: expandedWidth,
                                    maxWidth: expandedWidth,
                                    minHeight: expandedHeight,
                                    maxHeight: expandedHeight,
                                    alignment: Alignment.topRight,
                                    child: expandedChild!,
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
