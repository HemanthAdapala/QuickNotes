import 'dart:ui';
import 'package:flutter/material.dart';

void showBlurredBottomSheet({
  required BuildContext context,
  required Widget child,
}) {
  final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: const Color(0xFF333333).withValues(alpha: 0.20),
    transitionDuration:
        reduceMotion ? Duration.zero : const Duration(milliseconds: 350),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: Colors.transparent,
          child: child,
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
        return child;
      }
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 5.0 * animation.value,
          sigmaY: 5.0 * animation.value,
        ),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: child,
        ),
      );
    },
  );
}
