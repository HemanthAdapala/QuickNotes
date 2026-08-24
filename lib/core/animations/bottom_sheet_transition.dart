import 'dart:ui';
import 'package:flutter/material.dart';
import 'animation_constants.dart';

class AnimatedBottomSheetRoute<T> extends PopupRoute<T> {
  final Widget child;
  final Color? backgroundColor;
  final ShapeBorder? shape;
  final Color? customBarrierColor;

  AnimatedBottomSheetRoute({
    required this.child,
    this.backgroundColor,
    this.shape,
    this.customBarrierColor,
  });

  @override
  Color? get barrierColor =>
      customBarrierColor ?? Colors.black.withValues(alpha: 0.20);

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  Duration get transitionDuration => kDurationNormal; // 250ms

  @override
  Duration get reverseTransitionDuration => kDurationFast; // 150ms

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.9;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Material(
          color: backgroundColor ?? theme.scaffoldBackgroundColor,
          shape: shape ??
              const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
              ),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    final isEntering = animation.status == AnimationStatus.forward ||
        animation.status == AnimationStatus.completed;
    final curve = isEntering ? kCurveEnter : kCurveExit;

    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: curve,
      reverseCurve: curve,
    );

    final slideTween = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: Offset.zero,
    );

    return SlideTransition(
      position: slideTween.animate(curvedAnimation),
      child: FadeTransition(
        opacity: curvedAnimation,
        child: child,
      ),
    );
  }
}

Future<T?> showAnimatedBottomSheet<T>({
  required BuildContext context,
  required Widget child,
  Color? backgroundColor,
  ShapeBorder? shape,
  Color? barrierColor,
}) {
  return Navigator.push<T>(
    context,
    AnimatedBottomSheetRoute<T>(
      child: child,
      backgroundColor: backgroundColor,
      shape: shape,
      customBarrierColor: barrierColor,
    ),
  );
}
