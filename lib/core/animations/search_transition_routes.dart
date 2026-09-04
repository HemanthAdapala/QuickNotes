import 'package:flutter/material.dart';

/// Pixel-perfect Search Screen route transition with zero header icon displacement.
Route<T> buildSearchTransitionRoute<T>({
  required WidgetBuilder builder,
  Offset? tapPosition,
}) {
  return PixelAlignedSearchRoute<T>(builder: builder);
}

class PixelAlignedSearchRoute<T> extends PageRouteBuilder<T> {
  final WidgetBuilder builder;
  final Duration normalTransitionDuration;
  final Duration normalReverseTransitionDuration;

  PixelAlignedSearchRoute({
    required this.builder,
    this.normalTransitionDuration = const Duration(milliseconds: 300),
    this.normalReverseTransitionDuration = const Duration(milliseconds: 220),
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: normalTransitionDuration,
          reverseTransitionDuration: normalReverseTransitionDuration,
          opaque: false,
          barrierDismissible: false,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
              return child;
            }

            final curvedAnim = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            return FadeTransition(
              opacity: curvedAnim,
              child: child,
            );
          },
        );

  @override
  Duration get transitionDuration {
    final ctx = navigator?.context;
    if (ctx != null && (MediaQuery.maybeDisableAnimationsOf(ctx) ?? false)) {
      return Duration.zero;
    }
    return normalTransitionDuration;
  }

  @override
  Duration get reverseTransitionDuration {
    final ctx = navigator?.context;
    if (ctx != null && (MediaQuery.maybeDisableAnimationsOf(ctx) ?? false)) {
      return Duration.zero;
    }
    return normalReverseTransitionDuration;
  }
}
