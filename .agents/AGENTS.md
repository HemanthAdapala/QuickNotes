# Workspace Guidelines - QuickNotes Design & Motion System

This document establishes the project-level design tokens and behavioral rules for any AI agent or developer adding, modifying, or styling glassmorphism or animated components in QuickNotes.

---

## 1. Glassmorphism Design System (Liquid Glass)
Whenever building or modifying any glass-like surface or widget (e.g. `GlassSurface`, `RichTextFormattingPillContainer`):
* **Do NOT use default/frosty glass settings**. Always default to the approved **Liquid Glass** values:
  * **Blur Sigma**: `3.0` (`ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0)`)
  * **Frost Opacity**: `0.0` (Do not add a white frosty color tint overlay)
  * **Default Fill Color**: `Colors.transparent` (no fill)
  * **Outline/Border Width**: `0.8`
  * **Outline/Border Opacity**: `0.30` (30% white opacity gradient/border)
  * **Bevel & 3D Depth Style**: `0.20` (Light from above: 0 degrees, 20% opacity)
  * **Depth Opacity**: `0.30` (Depth: 30%)
  * **Inner Shadows**: Always apply the 4-layer inset shadow stack:
    1. `BoxShadow(offset: Offset(0, 1.25), blurRadius: 0.25, spreadRadius: 0, color: Color(0xFF282828), inset: true)`
    2. `BoxShadow(offset: Offset(0, -1.25), blurRadius: 0.25, spreadRadius: 0, color: Color(0xFF282828), inset: true)`
    3. `BoxShadow(offset: Offset(0, 40), blurRadius: 10, spreadRadius: -40, color: Color(0xFF282828), inset: true)`
    4. `BoxShadow(offset: Offset(0, -40), blurRadius: 10, spreadRadius: -40, color: Color(0xFF282828), inset: true)`
* **Shadow Style (S0)**: Always apply the 4-layer high-visibility shadow stack:
  ```dart
  boxShadow: [
    BoxShadow(
      offset: const Offset(1.25, 0),
      blurRadius: 0,
      spreadRadius: -0.75,
      color: const Color(0xFFD0D0D0),
    ),
    BoxShadow(
      offset: const Offset(-1.25, 0),
      blurRadius: 0,
      spreadRadius: -0.75,
      color: const Color(0xFFD0D0D0),
    ),
    BoxShadow(
      offset: const Offset(0, 0),
      blurRadius: 0,
      spreadRadius: 0.5,
      color: const Color(0xFFCCCCCC),
    ),
    BoxShadow(
      offset: const Offset(0, 8),
      blurRadius: 15,
      spreadRadius: 0,
      color: Colors.black.withValues(alpha: 0.02),
    ),
  ]
  ```
* **Bottom Bar Liquid Glass Preset**: Always use `BottomBarGlassSurface` (imported from `app_bottom_navigation_bar.dart`) whenever the user requests to "Apply BottomBarGlassSurface" or "use bottom bar liquid glass preset". This class is pre-configured with the exact gradient, borders, and no-bevel flat style matching the bottom navigation bar.

---

## 2. Motion & Settle Physics (Apple Pressable)
Whenever implementing tactile click interactions or scale animations (e.g., buttons, tab items, cards):
* **Scale Compression**: Tap-down must immediately scale down the item to **`0.7`** (strong tactile compression).
* **Spring Settle Release**: Tap-up/cancel must settle back to scale `1.0` over a duration of **`1000ms`** using **`Curves.elasticOut`** curve.
* **Haptics**: Always play a selection haptic feedback tick (`HapticFeedback.selectionClick()`) immediately upon tap-down.
* **Morph Transitions**: All dimensional morphing sequences (like formatting bar size change) must expand or shrink over **`1000ms`** using **`Curves.elasticOut`**.
