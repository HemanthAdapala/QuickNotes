import 'dart:math';
import 'package:flutter/material.dart';

enum SearchTransitionType {
  heroGlassMorph,
  spotlightSpring,
  radialExpand,
}

/// Active transition type being tested.
SearchTransitionType activeSearchTransition = SearchTransitionType.heroGlassMorph;

/// Global helper to build the active SearchRoute based on current test setting.
Route<T> buildSearchTransitionRoute<T>({
  required WidgetBuilder builder,
  Offset? tapPosition,
}) {
  switch (activeSearchTransition) {
    case SearchTransitionType.heroGlassMorph:
      return HeroGlassMorphSearchRoute<T>(builder: builder);
    case SearchTransitionType.spotlightSpring:
      return SpotlightSpringSearchRoute<T>(builder: builder);
    case SearchTransitionType.radialExpand:
      return RadialExpandSearchRoute<T>(
        builder: builder,
        tapPosition: tapPosition ?? const Offset(340, 60),
      );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Option 1: Hero Glass Morph & Depth Scale Route
// ─────────────────────────────────────────────────────────────────────────────

class HeroGlassMorphSearchRoute<T> extends PageRouteBuilder<T> {
  final WidgetBuilder builder;

  HeroGlassMorphSearchRoute({required this.builder})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 320),
          opaque: false,
          barrierDismissible: false,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnim = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            // Entering page slide & fade
            final fade = Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnim);
            final slide = Tween<Offset>(
              begin: const Offset(0.0, 0.03),
              end: Offset.zero,
            ).animate(curvedAnim);

            return SlideTransition(
              position: slide,
              child: FadeTransition(
                opacity: fade,
                child: child,
              ),
            );
          },
        );
}

// ─────────────────────────────────────────────────────────────────────────────
// Option 2: iOS Spotlight Spring & Stagger Cascade Route
// ─────────────────────────────────────────────────────────────────────────────

class SpotlightSpringSearchRoute<T> extends PageRouteBuilder<T> {
  final WidgetBuilder builder;

  SpotlightSpringSearchRoute({required this.builder})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionDuration: const Duration(milliseconds: 360),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          opaque: false,
          barrierDismissible: false,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnim = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInQuad,
            );

            final scale = Tween<double>(begin: 0.94, end: 1.0).animate(curvedAnim);
            final fade = Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnim);
            final slide = Tween<Offset>(
              begin: const Offset(0.0, -0.02),
              end: Offset.zero,
            ).animate(curvedAnim);

            return SlideTransition(
              position: slide,
              child: ScaleTransition(
                scale: scale,
                child: FadeTransition(
                  opacity: fade,
                  child: child,
                ),
              ),
            );
          },
        );
}

// ─────────────────────────────────────────────────────────────────────────────
// Option 3: Radial Circular Mask Expansion Route
// ─────────────────────────────────────────────────────────────────────────────

class RadialExpandSearchRoute<T> extends PageRouteBuilder<T> {
  final WidgetBuilder builder;
  final Offset tapPosition;

  RadialExpandSearchRoute({
    required this.builder,
    required this.tapPosition,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionDuration: const Duration(milliseconds: 420),
          reverseTransitionDuration: const Duration(milliseconds: 320),
          opaque: false,
          barrierDismissible: false,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnim = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            return AnimatedBuilder(
              animation: curvedAnim,
              builder: (context, child) {
                final size = MediaQuery.of(context).size;
                final maxRadius = sqrt(size.width * size.width + size.height * size.height);
                final currentRadius = 22.0 + (maxRadius - 22.0) * curvedAnim.value;

                return ClipPath(
                  clipper: _RadialClipper(
                    center: tapPosition,
                    radius: currentRadius,
                  ),
                  child: FadeTransition(
                    opacity: Tween<double>(begin: 0.2, end: 1.0).animate(curvedAnim),
                    child: child!,
                  ),
                );
              },
              child: child,
            );
          },
        );
}

class _RadialClipper extends CustomClipper<Path> {
  final Offset center;
  final double radius;

  _RadialClipper({required this.center, required this.radius});

  @override
  Path getClip(Size size) {
    return Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  @override
  bool shouldReclip(_RadialClipper oldClipper) {
    return oldClipper.radius != radius || oldClipper.center != center;
  }
}
