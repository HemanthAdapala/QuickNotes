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

  PixelAlignedSearchRoute({required this.builder})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 220),
          opaque: false,
          barrierDismissible: false,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
}
