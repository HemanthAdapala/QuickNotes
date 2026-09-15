import 'package:flutter/material.dart';

/// A foundational architectural primitive representing the primary white sheet 
/// of a screen in the QuickNotes app.
///
/// This enforces the global rule for primary screen surfaces:
/// - White background
/// - Top-left radius: 32px
/// - Top-right radius: 32px
/// - Bottom-left/right: 0px (flush)
class PrimaryScreenSurface extends StatelessWidget {
  final Widget child;
  final Color? color;

  const PrimaryScreenSurface({
    super.key,
    required this.child,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ??
        (Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF121212)
            : Colors.white);

    return Container(
      decoration: BoxDecoration(
        color: effectiveColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
