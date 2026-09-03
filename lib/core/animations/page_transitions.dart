import 'package:flutter/material.dart';
import 'animation_constants.dart';

Route<T> buildPageRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: kDurationPage,
    reverseTransitionDuration: kDurationPage,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final slideTween = Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).chain(CurveTween(curve: kCurvePage));

      final fadeTween = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).chain(CurveTween(curve: kCurvePage));

      return SlideTransition(
        position: animation.drive(slideTween),
        child: FadeTransition(
          opacity: animation.drive(fadeTween),
          child: child,
        ),
      );
    },
  );
}

Route<T> buildFadePageRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: const Duration(milliseconds: 600),
    reverseTransitionDuration: const Duration(milliseconds: 600),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOut,
        ),
        child: child,
      );
    },
  );
}

/// Phase P1-D: Note opening screen transition.
///
/// Refined 340ms forward / 260ms reverse entry transition combining
/// subtle scale (0.98 -> 1.00) and smooth opacity (0.0 -> 1.0) with
/// Apple-style emphasized ease, creating the feel of entering a physical document.
Route<T> buildNoteOpeningPageRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: const Duration(milliseconds: 340),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final reduceMotion = MediaQuery.of(context).disableAnimations;
      if (reduceMotion) {
        return child;
      }

      final isForward = animation.status != AnimationStatus.reverse;
      final curve = isForward
          ? const Cubic(0.20, 0.0, 0.0, 1.0)
          : Curves.easeInCubic;

      final fadeAnim = CurvedAnimation(parent: animation, curve: curve);
      final scaleAnim = Tween<double>(begin: 0.98, end: 1.0).animate(
        CurvedAnimation(parent: animation, curve: curve),
      );

      return FadeTransition(
        opacity: fadeAnim,
        child: ScaleTransition(
          scale: scaleAnim,
          child: child,
        ),
      );
    },
  );
}

