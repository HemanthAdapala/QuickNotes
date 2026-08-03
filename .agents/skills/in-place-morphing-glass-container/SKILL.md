---
name: in-place-morphing-glass-container
description: Implement and maintain fluid in-place morphing glass containers, expanding popups, and liquid glass headers in Flutter. Use when building morphing popups, expanding action pills, or liquid glass floating menus.
---

# In-Place Morphing Glass Container Pattern

This skill documents the production architecture, layout math, animation curves, and content cross-fade synchronization for creating in-place morphing liquid glass containers in Flutter.

## Core Architectural Principle

Rather than opening a detached dialog, standard `PopupMenuButton`, or bottom sheet, the interactive element morphs **in-place** from its collapsed state (e.g. 44×44 circular button) to its expanded state (e.g. 192×100 rounded glass card).

```
┌────────────────────────────────────────────────────────┐
│ COLLAPSED STATE (e.g. 3-Dots Action Button)            │
│ Width: 44.0, Height: 44.0, Radius: 22.0 (Circle)       │
└────────────────────────────────────────────────────────┘
                           │
                           ▼ [isExpanded = true]
                           │ Morphing (500ms, Curves.easeOutCubic)
                           ▼
┌────────────────────────────────────────────────────────┐
│ EXPANDED STATE (Morphing Glass Menu Card)              │
│ Width: 192.0, Height: 100.0, Radius: 20.0              │
│                                                        │
│  [Icon 1]   Action Option 1                            │
│  [Icon 2]   Action Option 2                            │
└────────────────────────────────────────────────────────┘
```

---

## 4-Tier Component Architecture

### 1. Outer Container Morphing (`AnimatedContainer`)
- Controls `width`, `height`, and `borderRadius` transition.
- **Collapsed Dimensions**: `44.0 × 44.0`, `borderRadius: 22.0` (Circle).
- **Expanded Dimensions**: `expandedWidth × expandedHeight`, `borderRadius: 20.0`.
- **Curves & Duration**:
  - Expansion: `Duration(milliseconds: 500)`, `curve: Curves.easeOutCubic`.
  - Shrinking: `Duration(milliseconds: 415)`, `curve: Curves.easeInCubic`.

### 2. Glass Visual Surface (`BottomBarGlassSurface`)
- Provides liquid glass visuals: `BackdropFilter` (blur), translucent tint, and subtle `0.20px` border stroke.
- Radius matches the container's animated border radius.

### 3. Content Cross-Fade & Entrance (`AnimatedOpacity` + `AnimatedSlide`)
- **Collapsed Icon**: Fades out over `200ms` (`opacity: isExpanded ? 0.0 : 1.0`).
- **Expanded Content**: Fades in over `420ms` (`opacity: isExpanded ? 1.0 : 0.0`) and slides up from `Offset(0, 0.08)` to `Offset.zero` using `Curves.easeOutCubic`.
- **Layout Protection (`OverflowBox`)**: Wrapped in `OverflowBox(minWidth: width, maxWidth: width)` so text items do not warp or reflow while container dimensions morph.

### 4. Backdrop Overlay (`AnimatedOpacity`)
- Fullscreen backdrop (`Colors.black.withValues(alpha: 0.20)`) fades in over `500ms`.
- Tapping anywhere outside sets `isExpanded = false`, seamlessly reversing the morph back to the collapsed button (`415ms`).

---

## Reference Implementation

```dart
class MorphingGlassHeaderAction extends StatelessWidget {
  final bool isExpanded;
  final double collapsedWidth;
  final double expandedWidth;
  final double expandedHeight;
  final Widget collapsedChild;
  final Widget expandedChild;

  const MorphingGlassHeaderAction({
    super.key,
    required this.isExpanded,
    this.collapsedWidth = 44.0,
    required this.expandedWidth,
    required this.expandedHeight,
    required this.collapsedChild,
    required this.expandedChild,
  });

  @override
  Widget build(BuildContext context) {
    final double targetWidth = isExpanded ? expandedWidth : collapsedWidth;
    final double targetHeight = isExpanded ? expandedHeight : 44.0;
    final double targetRadius = isExpanded ? 20.0 : 22.0;

    return AnimatedContainer(
      duration: Duration(milliseconds: isExpanded ? 500 : 415),
      curve: isExpanded ? Curves.easeOutCubic : Curves.easeInCubic,
      width: targetWidth,
      height: targetHeight,
      child: BottomBarGlassSurface(
        width: targetWidth,
        height: targetHeight,
        borderRadius: BorderRadius.circular(targetRadius),
        useFrost: true,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(targetRadius),
          child: Stack(
            children: [
              // Collapsed Icon
              AnimatedOpacity(
                duration: Duration(milliseconds: isExpanded ? 200 : 250),
                curve: Curves.easeOut,
                opacity: isExpanded ? 0.0 : 1.0,
                child: IgnorePointer(
                  ignoring: isExpanded,
                  child: collapsedChild,
                ),
              ),

              // Expanded Menu Card
              AnimatedOpacity(
                duration: Duration(milliseconds: isExpanded ? 420 : 200),
                curve: Curves.easeOutCubic,
                opacity: isExpanded ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !isExpanded,
                  child: AnimatedSlide(
                    duration: Duration(milliseconds: isExpanded ? 420 : 200),
                    curve: Curves.easeOutCubic,
                    offset: isExpanded ? Offset.zero : const Offset(0, 0.08),
                    child: OverflowBox(
                      minWidth: expandedWidth,
                      maxWidth: expandedWidth,
                      minHeight: expandedHeight,
                      maxHeight: expandedHeight,
                      child: expandedChild,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

---

## Best Practices Checklist

- [x] Use `OverflowBox` around `expandedChild` to prevent text reflow during sizing animation.
- [x] Use `IgnorePointer` on hidden states to prevent accidental touches.
- [x] Asymmetric curves: `Curves.easeOutCubic` for expansion, `Curves.easeInCubic` for shrinking.
- [x] Ensure backdrop tap dismisses the popup cleanly (`_isMoreOptionsOpen = false`).
