import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/motion/motion_constants.dart';

/// Modal popup route for the rich blurred bottom sheet.
/// Uses asymmetric timing ([QuickNotesMotion.kMotionSheetPresent] forward, [QuickNotesMotion.kMotionSheetDismiss] reverse)
/// with ease-out cubic entrance and ease-in cubic exit, while keeping foreground slide,
/// backdrop dimming, and blur filter synchronized.
class BlurredBottomSheetRoute<T> extends PopupRoute<T> {
  final Widget child;

  BlurredBottomSheetRoute({
    required this.child,
    super.settings,
  });

  @override
  Color? get barrierColor => const Color(0xFF333333).withValues(alpha: 0.20);

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  Duration get transitionDuration {
    final ctx = navigator?.context;
    if (ctx != null && (MediaQuery.maybeDisableAnimationsOf(ctx) ?? false)) {
      return Duration.zero;
    }
    return QuickNotesMotion.kMotionSheetPresent;
  }

  @override
  Duration get reverseTransitionDuration {
    final ctx = navigator?.context;
    if (ctx != null && (MediaQuery.maybeDisableAnimationsOf(ctx) ?? false)) {
      return Duration.zero;
    }
    return QuickNotesMotion.kMotionSheetDismiss;
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        color: Colors.transparent,
        child: child,
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return child;
    }
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: QuickNotesMotion.kMotionEaseOutCubic,
      reverseCurve: QuickNotesMotion.kMotionEaseInCubic,
    );
    return AnimatedBuilder(
      animation: curvedAnimation,
      builder: (context, child) {
        final blurSigma = 5.0 * curvedAnimation.value;
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: blurSigma,
            sigmaY: blurSigma,
          ),
          child: child,
        );
      },
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(curvedAnimation),
        child: child,
      ),
    );
  }
}

Future<T?> showBlurredBottomSheet<T>({
  required BuildContext context,
  required Widget child,
}) {
  return Navigator.of(context).push<T>(
    BlurredBottomSheetRoute<T>(child: child),
  );
}
