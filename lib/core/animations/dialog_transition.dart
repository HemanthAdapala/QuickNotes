import 'package:flutter/material.dart';
import 'animation_constants.dart';

Future<T?> showAnimatedDialog<T>({
  required BuildContext context,
  required Widget child,
  Color? barrierColor,
}) {
  final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: barrierColor ?? const Color(0xFF333333).withValues(alpha: 0.20),
    transitionDuration: reduceMotion ? Duration.zero : kDurationNormal, // 250ms
    pageBuilder: (context, animation, secondaryAnimation) =>
        Center(child: child),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
        return child;
      }

      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: kCurveEnter, // Curves.easeOut
      );

      final scaleTween = Tween<double>(
        begin: 0.9,
        end: 1.0,
      );

      return ScaleTransition(
        scale: scaleTween.animate(curvedAnimation),
        child: FadeTransition(
          opacity: curvedAnimation,
          child: child,
        ),
      );
    },
  );
}
