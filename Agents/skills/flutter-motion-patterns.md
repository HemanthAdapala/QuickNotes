# Flutter Motion Patterns

Use these snippets as adaptable starting points. Rename classes and tune values to match the app.

Snippets may require these imports depending on the pattern:

```dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
```

For older Flutter versions, replace `withValues(alpha: x)` with `withOpacity(x)`.

## Pressable Scale Button

Use for Apple-like immediate button feedback while keeping the hit target stable.

```dart
class ApplePressable extends StatefulWidget {
  const ApplePressable({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = 0.96,
    this.duration = const Duration(milliseconds: 120),
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final Duration duration;
  final BorderRadius borderRadius;

  @override
  State<ApplePressable> createState() => _ApplePressableState();
}

class _ApplePressableState extends State<ApplePressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              widget.onTap?.call();
            },
      child: AnimatedScale(
        scale: _pressed && !reduceMotion ? widget.scale : 1,
        duration: reduceMotion ? Duration.zero : widget.duration,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
```

## Morphing Rounded Surface

Use for Dynamic Island-like surface expansion, control pills, selected toolbars, compact-to-expanded states.

```dart
class AppleMorphingSurface extends StatelessWidget {
  const AppleMorphingSurface({
    super.key,
    required this.expanded,
    required this.compactChild,
    required this.expandedChild,
    this.compactSize = const Size(126, 44),
    this.expandedSize = const Size(340, 128),
  });

  final bool expanded;
  final Widget compactChild;
  final Widget expandedChild;
  final Size compactSize;
  final Size expandedSize;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final size = expanded ? expandedSize : compactSize;

    return AnimatedContainer(
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 420),
      curve: const Cubic(0.16, 1.0, 0.3, 1.0),
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(expanded ? 34 : 22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: expanded ? 28 : 14,
            offset: Offset(0, expanded ? 18 : 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedSwitcher(
        duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: KeyedSubtree(
          key: ValueKey(expanded),
          child: expanded ? expandedChild : compactChild,
        ),
      ),
    );
  }
}
```

## Bottom Sheet Motion

Use `showModalBottomSheet` for simple sheets. Use `DraggableScrollableSheet` for Apple Music-like snap and drag.

```dart
Future<T?> showAppleSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.62,
        minChildSize: 0.28,
        maxChildSize: 0.94,
        snap: true,
        snapSizes: const [0.62, 0.94],
        builder: (context, controller) {
          return RepaintBoundary(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                child: PrimaryScrollController(
                  controller: controller,
                  child: builder(context),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
```

Use the default modal-sheet controller unless the surrounding widget can own and dispose a custom `AnimationController`.

## Hero Card Expansion

Use for Photos/App Store-style card-to-detail transitions.

```dart
Hero(
  tag: 'note-card-$id',
  flightShuttleBuilder: (
    flightContext,
    animation,
    direction,
    fromContext,
    toContext,
  ) {
    final fromHero = fromContext.widget as Hero;
    final toHero = toContext.widget as Hero;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(animation.value);

        return Transform.scale(
          scale: lerpDouble(0.98, 1.0, t)!,
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        child: direction == HeroFlightDirection.push
            ? toHero.child
            : fromHero.child,
      ),
    );
  },
  child: card,
)
```

Keep the source and destination card shapes visually compatible: same image aspect ratio, matched border radius, and stable hero tag.

## Route Fade Scale

Use for custom modal/detail presentation.

```dart
Route<T> appleFadeScaleRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 460),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: const Cubic(0.16, 1.0, 0.3, 1.0),
        reverseCurve: Curves.easeInCubic,
      );

      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}
```

## Animated Toggle

Use for Control Center-like controls.

```dart
class AppleToggle extends StatelessWidget {
  const AppleToggle({
    super.key,
    required this.value,
    required this.onChanged,
    required this.icon,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ApplePressable(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: value ? scheme.primary : scheme.surfaceContainerHighest,
          boxShadow: [
            BoxShadow(
              color: (value ? scheme.primary : Colors.black)
                  .withValues(alpha: value ? 0.24 : 0.10),
              blurRadius: value ? 18 : 10,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          scale: value ? 1.08 : 1,
          child: Icon(
            icon,
            color: value ? scheme.onPrimary : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
```

## iMessage Bubble Entrance

```dart
class BubbleEntrance extends StatelessWidget {
  const BubbleEntrance({
    super.key,
    required this.child,
    this.incoming = false,
  });

  final Widget child;
  final bool incoming;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: const Cubic(0.16, 1.0, 0.3, 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(incoming ? -10 * (1 - value) : 10 * (1 - value), 8 * (1 - value)),
            child: Transform.scale(
              alignment: incoming ? Alignment.bottomLeft : Alignment.bottomRight,
              scale: 0.94 + (0.06 * value),
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}
```

## macOS Dock Hover

Use on desktop/web Flutter where pointer hover matters.

```dart
class DockHoverItem extends StatefulWidget {
  const DockHoverItem({
    super.key,
    required this.child,
    this.onTap,
  });

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<DockHoverItem> createState() => _DockHoverItemState();
}

class _DockHoverItemState extends State<DockHoverItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedSlide(
          offset: _hovered ? const Offset(0, -0.08) : Offset.zero,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: AnimatedScale(
            scale: _hovered ? 1.18 : 1,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
```

## Staggered Reveal

Use for list/card contents after a route or surface expansion.

```dart
class StaggeredReveal extends StatelessWidget {
  const StaggeredReveal({
    super.key,
    required this.children,
    this.interval = const Duration(milliseconds: 45),
  });

  final List<Widget> children;
  final Duration interval;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < children.length; i++)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 260 + interval.inMilliseconds * i),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 10 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: children[i],
          ),
      ],
    );
  }
}
```

## Performance Checklist

- Animate `Transform`, `Opacity`, and paint-only values where possible.
- Avoid rebuilding large subtrees in every animation tick; put static content in `child` of `AnimatedBuilder`.
- Add `RepaintBoundary` around expensive animated cards, glass, lists, and images.
- Decode/precache large images before shared-element transitions.
- Keep blur and backdrop effects stable when possible; animating blur is expensive.
- Test rapid repeated taps and interrupted gestures.
