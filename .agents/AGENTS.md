# Workspace Guidelines - QuickNotes Design & Motion System

This document establishes the project-level design tokens and behavioral rules for any AI agent or developer adding, modifying, or styling glassmorphism or animated components in QuickNotes.

---

## 1. Glassmorphism Design System (Liquid Glass)
Whenever building or modifying any glass-like surface or widget (e.g. `GlassSurface`, `RichTextFormattingPillContainer`):
* **Do NOT use default/frosty glass settings**. Always default to the approved **Liquid Glass** values:
  * **Blur Sigma**: `4.5` (`ImageFilter.blur(sigmaX: 4.5, sigmaY: 4.5)`)
  * **Frost Opacity**: `0.0` (Do not add a white frosty color tint overlay)
  * **Outline/Border Width**: `0.8`
  * **Outline/Border Opacity**: `0.30` (30% white opacity gradient/border)
  * **Bevel & 3D Depth Style**: `0.0` (Do not draw nested inner 3D highlights or embossed borders; keep it flat and clean)
* **Shadow Style (S0)**: Always apply the three-layer frosted glow drop shadow system:
  ```dart
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.10),
      blurRadius: 24,
      spreadRadius: -6,
      offset: const Offset(0, 16),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8,
      spreadRadius: -2,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.white.withValues(alpha: 0.42),
      blurRadius: 22,
      spreadRadius: -10,
      offset: const Offset(-8, -10),
    ),
  ]
  ```

---

## 2. Motion & Settle Physics (Apple Pressable)
Whenever implementing tactile click interactions or scale animations (e.g., buttons, tab items, cards):
* **Scale Compression**: Tap-down must immediately scale down the item to **`0.7`** (strong tactile compression).
* **Spring Settle Release**: Tap-up/cancel must settle back to scale `1.0` over a duration of **`1000ms`** using **`Curves.elasticOut`** curve.
* **Haptics**: Always play a selection haptic feedback tick (`HapticFeedback.selectionClick()`) immediately upon tap-down.
* **Morph Transitions**: All dimensional morphing sequences (like formatting bar size change) must expand or shrink over **`1000ms`** using **`Curves.elasticOut`**.
