import 'package:flutter/material.dart';
import '../motion/motion_constants.dart';

/// Minimal shared foundation route for Quick Notes standard transitions.
///
/// Encapsulates authoritative [QuickNotesMotion] page durations, Apple-style easing,
/// and immediate non-animated presentation when [MediaQueryData.disableAnimations] is active.
class QuickNotesPageRoute<T> extends PageRouteBuilder<T> {
  final Duration normalTransitionDuration;
  final Duration normalReverseTransitionDuration;

  QuickNotesPageRoute({
    required super.pageBuilder,
    super.transitionsBuilder,
    this.normalTransitionDuration = QuickNotesMotion.kMotionPage,
    this.normalReverseTransitionDuration = QuickNotesMotion.kMotionPageReverse,
    super.opaque,
    super.barrierDismissible,
    super.barrierColor,
    super.barrierLabel,
    super.maintainState,
    super.fullscreenDialog,
    super.allowSnapshotting,
    super.settings,
  }) : super(
          transitionDuration: normalTransitionDuration,
          reverseTransitionDuration: normalReverseTransitionDuration,
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

/// Standard hierarchical page transition route for Quick Notes.
///
/// Consumes authoritative 340ms forward / 260ms reverse durations with Apple-style
/// easing, smooth horizontal slide and opacity entrance.
Route<T> buildPageRoute<T>(Widget page) {
  return QuickNotesPageRoute<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    normalTransitionDuration: QuickNotesMotion.kMotionPage,
    normalReverseTransitionDuration: QuickNotesMotion.kMotionPageReverse,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
        return child;
      }

      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: QuickNotesMotion.kMotionAppleEase,
        reverseCurve: Curves.easeInCubic,
      );

      final slideTween = Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      );

      final fadeTween = Tween<double>(
        begin: 0.0,
        end: 1.0,
      );

      return SlideTransition(
        position: slideTween.animate(curvedAnimation),
        child: FadeTransition(
          opacity: fadeTween.animate(curvedAnimation),
          child: child,
        ),
      );
    },
  );
}

/// Optional fade-based route transition.
/// Note: Preserved for API stability; audited as currently unreferenced in production views.
Route<T> buildFadePageRoute<T>(Widget page) {
  return QuickNotesPageRoute<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    normalTransitionDuration: const Duration(milliseconds: 600),
    normalReverseTransitionDuration: const Duration(milliseconds: 600),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
        return child;
      }
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

/// Note opening screen transition.
///
/// Refined 340ms forward / 260ms reverse entry transition combining
/// subtle scale (0.98 -> 1.00) and smooth opacity (0.0 -> 1.0) with
/// Apple-style emphasized ease, creating the feel of entering a physical document.
///
/// Consumes authoritative [QuickNotesMotion.kMotionPage], [QuickNotesMotion.kMotionPageReverse],
/// and [QuickNotesMotion.kMotionAppleEase] tokens.
Route<T> buildNoteOpeningPageRoute<T>(Widget page) {
  return QuickNotesPageRoute<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    normalTransitionDuration: QuickNotesMotion.kMotionPage,
    normalReverseTransitionDuration: QuickNotesMotion.kMotionPageReverse,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
        return child;
      }

      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: QuickNotesMotion.kMotionAppleEase,
        reverseCurve: Curves.easeInCubic,
      );

      final scaleAnim = Tween<double>(begin: 0.98, end: 1.0).animate(curvedAnimation);

      return FadeTransition(
        opacity: curvedAnimation,
        child: ScaleTransition(
          scale: scaleAnim,
          child: child,
        ),
      );
    },
  );
}

