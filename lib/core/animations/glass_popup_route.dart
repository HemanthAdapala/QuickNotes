import 'dart:ui';
import 'package:flutter/material.dart';
import '../../views/widgets/app_bottom_navigation_bar.dart';

/// A custom transparent PageRoute that smoothly morphs a single liquid glass container
/// from the 3-dots circular button (44x44, radius 22) into the MoreOptions Popup card
/// (192x100, radius 20) while fading in the exact OverlayScreen backdrop (black @ 20% opacity).
class GlassPopupPageRoute<T> extends PageRouteBuilder<T> {
  final Rect anchorBounds;
  final Rect targetBounds;
  final Widget popupChild;

  GlassPopupPageRoute({
    required this.anchorBounds,
    required this.targetBounds,
    required this.popupChild,
  }) : super(
          opaque: false,
          barrierDismissible: true,
          barrierColor: Colors.transparent,
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          pageBuilder: (context, animation, secondaryAnimation) => popupChild,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final t = animation.value;
            final curvedT = Curves.easeOutCubic.transform(t);

            // Continuous shape, size, position, and border-radius transformation
            final currentRect = Rect.lerp(anchorBounds, targetBounds, curvedT)!;
            final currentRadius = lerpDouble(22.0, 20.0, curvedT)!;

            // Fading 3-dots vs popup menu contents
            final dotsOpacity = (1.0 - curvedT * 2.5).clamp(0.0, 1.0);
            final menuOpacity = (curvedT * 2.0 - 0.6).clamp(0.0, 1.0);

            return Stack(
              children: [
                // 1. Fullscreen Dimming Backdrop Overlay using exact OverlayScreen.txt value (black @ 0.20 opacity)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.20 * curvedT),
                    ),
                  ),
                ),

                // 2. Single Continuous Morphing Liquid Glass Container (Top-Right Anchored)
                Positioned.fromRect(
                  rect: currentRect,
                  child: BottomBarGlassSurface(
                    width: currentRect.width,
                    height: currentRect.height,
                    borderRadius: BorderRadius.circular(currentRadius),
                    useFrost: true,
                    child: Stack(
                      children: [
                        // Morphing 3-dots icon (Fades out during expansion)
                        if (dotsOpacity > 0)
                          Opacity(
                            opacity: dotsOpacity,
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(width: 5, height: 5, decoration: const BoxDecoration(color: Color(0xFF1C1C1E), shape: BoxShape.circle)),
                                  const SizedBox(width: 4),
                                  Container(width: 5, height: 5, decoration: const BoxDecoration(color: Color(0xFF1C1C1E), shape: BoxShape.circle)),
                                  const SizedBox(width: 4),
                                  Container(width: 5, height: 5, decoration: const BoxDecoration(color: Color(0xFF1C1C1E), shape: BoxShape.circle)),
                                ],
                              ),
                            ),
                          ),

                        // Popup Menu Content (Fades in during expansion)
                        if (menuOpacity > 0)
                          Opacity(
                            opacity: menuOpacity,
                            child: OverflowBox(
                              minWidth: targetBounds.width,
                              maxWidth: targetBounds.width,
                              minHeight: targetBounds.height,
                              maxHeight: targetBounds.height,
                              alignment: Alignment.topRight,
                              child: child,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
}
