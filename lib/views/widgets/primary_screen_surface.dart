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

  const PrimaryScreenSurface({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
