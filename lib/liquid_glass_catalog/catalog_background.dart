import 'package:flutter/material.dart';

/// Single, fixed test background used across the entire Liquid Glass catalog
/// and all individual component experiments.
///
/// Uses the reference wallpaper asset to provide a consistent, realistic test surface
/// to inspect glass blur, refraction, depth, and edge treatment.
class CatalogBackground extends StatelessWidget {
  final Widget child;

  const CatalogBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/catalog/liquid_glass_catalog_bg.jpg',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: const Color(0xFF0F172A),
          ),
        ),
        child,
      ],
    );
  }
}
