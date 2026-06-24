// ─────────────────────────────────────────────────────────────────────────────
// search_route.dart
// Full-screen slide-up + fade route used by SearchScreen.
// Entry: Offset(0,1) → Offset.zero with kCurveEnter.
// Exit : reverse at kDurationFast.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'animation_constants.dart';

class SearchRoute<T> extends PageRouteBuilder<T> {
  SearchRoute({required WidgetBuilder builder})
      : super(
          pageBuilder: (ctx, anim, secAnim) => builder(ctx),
          transitionDuration: kDurationNormal,
          reverseTransitionDuration: kDurationFast,
          transitionsBuilder: (ctx, anim, secAnim, child) {
            final curved = CurvedAnimation(
              parent: anim,
              curve: kCurveEnter,
              reverseCurve: kCurveExit,
            );

            final slide = Tween<Offset>(
              begin: const Offset(0.0, 1.0),
              end: Offset.zero,
            ).animate(curved);

            final fade = Tween<double>(begin: 0.0, end: 1.0).animate(curved);

            return SlideTransition(
              position: slide,
              child: FadeTransition(opacity: fade, child: child),
            );
          },
        );
}
