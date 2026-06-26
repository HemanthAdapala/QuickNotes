---
name: flutter-glassmorphism-ui
description: Create or convert Flutter UI components into native glassmorphism/frosted-glass interfaces. Use when Codex is asked to make any Flutter widget, toolbar, navigation bar, pill, card, modal, bottom sheet, container, or full screen match a Figma glass style with blur, translucency, refraction/depth feel, Apple-style soft shadows, rounded corners, inner highlights/shadows, Material 3 polish, or when the user says to use the previous GlassMorphism technique.
---

# Flutter Glassmorphism UI

## Core Rule

Recreate the glass container natively in Flutter. Do not export the whole UI/container as a single SVG or image. Preserve existing icons, SVGs, button logic, controllers, gestures, and app architecture unless the user explicitly asks to change them.

Use this skill mostly as a wrapper/composition technique: keep the interactive child UI intact, then place it inside a reusable glass surface.

## Workflow

1. Inspect the current Flutter files, Figma exports, and assets first.
2. Identify the visual shell dimensions, border radius, shadow direction, opacity, blur strength, and inner highlight/shadow cues from the mockup or SVG.
3. Keep the original icons as assets. If icons are SVGs, use `flutter_svg` and `SvgPicture.asset`; do not redraw, reinterpret, replace, or inline them.
4. Build a reusable widget with `const` constructor, typed public parameters, and a `child` slot when the existing UI behavior already exists.
5. Implement glass effects with native Flutter primitives:
   - `ClipRRect` or shaped clip for rounded corners.
   - `BackdropFilter` with `ImageFilter.blur`.
   - Semi-transparent `Container`/`DecoratedBox` surface.
   - `BoxShadow` for soft Apple-style outer shadows.
   - `Border.all` for translucent rim highlights.
   - `CustomPainter` only for inner highlights, inner shadows, refraction rims, or nontrivial native visual overlays.
6. Integrate with Material 3 patterns: transparent `Material` + `InkWell`/`IconButton` for interactive children, `ColorScheme` where possible, semantic labels for buttons/icons, and no hard-coded behavior surprises.
7. Add the needed `pubspec.yaml` asset/dependency snippet if working outside the full app.
8. Verify by running `dart format` and `flutter analyze` when Flutter is available.

## Flutter Pattern

Use this structure for most glass wrappers:

```dart
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(30)),
    this.padding = EdgeInsets.zero,
    this.blurSigma = 18,
  });

  final Widget child;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 24,
            spreadRadius: -6,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.35),
            blurRadius: 18,
            spreadRadius: -10,
            offset: const Offset(-6, -8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: CustomPaint(
            foregroundPainter: _GlassRimPainter(borderRadius: borderRadius),
            child: Container(
              width: width,
              height: height,
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                color: scheme.surface.withValues(alpha: 0.01),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.36),
                  width: 0.8,
                ),
                gradient: LinearGradient(
                  begin: const Alignment(-0.45, -0.8),
                  end: const Alignment(0.45, 0.8),
                  colors: [
                    Colors.white.withValues(alpha: 0.72),
                    Colors.white.withValues(alpha: 0.34),
                    scheme.surfaceTint.withValues(alpha: 0.08),
                    Colors.black.withValues(alpha: 0.035),
                  ],
                  stops: const [0, 0.42, 0.78, 1],
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
```

For projects on older Flutter versions, replace `withValues(alpha: x)` with `withOpacity(x)`.

## Effect Mapping

When a Figma glass effect lists values such as `Refraction`, `Depth`, `Dispersion`, `Frost`, `Splay`, and `Light`, approximate them natively:

- Refraction: translucent rim strokes, subtle inner `CustomPainter` highlight lines, and a directional gradient.
- Depth: darker lower inner stroke, layered outer shadows, and tiny black gradient at the far edge.
- Dispersion: very subtle colored `surfaceTint` or accent tint at low opacity; avoid rainbow or visible color fringing unless present in the design.
- Frost: `BackdropFilter` blur plus white translucent fill. For small pills, start with `sigmaX/Y` 14-20. For larger sheets/cards, start around 20-30.
- Splay: if 0, keep shadows centered/subtle and do not spread highlights outward aggressively.
- Light direction: map the Figma light angle into `LinearGradient.begin/end` and highlight shadow offsets. For a light around `-45` and strength `80`, use a top-left highlight and bottom-right depth.

## Practical Defaults

Use these as starting points, then tune against the mockup:

- Pill height 56-64: radius = height / 2.
- Modal/card radius: 20-32.
- Surface fill: `surface.withValues(alpha: 0.01)` to `0.16`.
- White frost layer: `0.24` to `0.46`.
- Border highlight: white `0.28` to `0.42`, width `0.6` to `1.0`.
- Outer black shadow: opacity `0.08` to `0.16`, blur `18` to `32`, y offset `8` to `18`.
- Inner depth stroke: black `0.10` to `0.22`, width `1.4` to `2.4`.

## Integration Rules

- Prefer a `child` slot for glass containers so existing `PageView`, rows, icons, format actions, and state stay untouched.
- For toolbar/pill controls, keep stable dimensions to prevent layout shift.
- For SVG icons, use a helper like:

```dart
SvgPicture.asset(
  assetPath,
  width: size,
  height: size,
  colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
)
```

- Do not replace app-specific active-state logic. Wrap it or pass colors through.
- Do not put visible explanatory text in app UI.
- Avoid nested visual cards. A glass pill/card can frame controls, but page sections should remain clean.
- If the glass is placed over a plain background, add or preserve enough background contrast; blur only reads as glass when there is content/color behind it.

## Deliverables

When implementing for the user, usually provide:

- A reusable widget file, e.g. `glass_surface.dart`, `rich_text_formatting_pill.dart`, or `app_bottom_navigation_bar.dart`.
- Asset path constants if the component references SVGs.
- A short usage snippet showing how to wrap the existing UI.
- Any required `pubspec.yaml` dependency and asset entries.
- A note about verification results, especially if Flutter tooling was unavailable.
