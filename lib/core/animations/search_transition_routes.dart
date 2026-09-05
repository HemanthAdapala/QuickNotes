import 'package:flutter/material.dart';
import '../motion/motion_constants.dart';

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
    this.normalTransitionDuration = QuickNotesMotion.kMotionPage,
    this.normalReverseTransitionDuration = QuickNotesMotion.kMotionPageReverse,
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
              curve: QuickNotesMotion.kMotionEaseOutCubic,
              reverseCurve: QuickNotesMotion.kMotionEaseInCubic,
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
