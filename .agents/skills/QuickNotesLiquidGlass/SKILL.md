---
name: QuickNotesLiquidGlass
description: Complete Liquid Glass implementation reference for QuickNotes. Use whenever asked to create any Liquid Glass button, pill, circle, card, or container in QuickNotes. Provides exact imports, layer stack, parameters, and ready-to-use code templates for every shape variant. Guarantees 100% visual accuracy to the project established glass system.
risk: safe
source: local
---

# QuickNotes Liquid Glass — Implementation Skill

This skill is the single source of truth for implementing Liquid Glass components in QuickNotes.

**Never guess or invent values. Every pixel comes from this document.**

---

## 1. What "Liquid Glass" Means in QuickNotes

A Liquid Glass component is always composed of exactly **two layers**:

```
TactileButton                  <- Interaction + Apple spring animation
 - BottomBarGlassSurface       <- The glass visual surface
     - child                   <- Your content (icon, text, etc.)
```

- `TactileButton` handles all touch interaction, haptics, and spring animation.
- `BottomBarGlassSurface` handles the entire visual glass effect.
- These two classes are **always used together** for any tappable Liquid Glass element.

---

## 2. Required Imports

Every file that uses Liquid Glass must have these imports:

```dart
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/app_bottom_navigation_bar.dart'; // provides BottomBarGlassSurface
import '../widgets/tactile_button.dart';             // provides TactileButton
```

Adjust the relative path (`../`) based on the file location in the project.

---

## 3. TactileButton — Exact Behavior

### Parameters and defaults:

| Parameter | Type | Default | Description |
|---|---|---|---|
| `child` | `Widget` | required | The glass surface to animate |
| `onTap` | `VoidCallback` | required | Action to execute on tap |
| `onLongPressStart` | `GestureLongPressStartCallback?` | null | Optional long-press action |
| `compressionScale` | `double` | **0.7** | Scale target on press-down |
| `pressDuration` | `Duration` | **80ms** | Time to compress to 0.7 |
| `settleDuration` | `Duration` | **1000ms** | Time to spring back to 1.0 |
| `useAppleSpring` | `bool` | **true** | Use elasticOut spring on release |
| `playSelectionHaptic` | `bool` | **true** | Fire HapticFeedback.selectionClick() on press-down |

### Animation sequence on tap:
1. **Press-down**: fires `HapticFeedback.selectionClick()`, scales to **0.7** over **80ms** with `Curves.easeIn`
2. **Release**: springs from 0.7 to 1.0 over **1000ms** with `Curves.elasticOut`
3. **Cancel**: same spring back as release (no action fired)

### Always use:
```dart
TactileButton(
  useAppleSpring: true,
  onTap: () { /* your action */ },
  child: BottomBarGlassSurface(...),
)
```

---

## 4. BottomBarGlassSurface — Exact Layer Stack

### Parameters:

| Parameter | Type | Required | Description |
|---|---|---|---|
| `width` | `double` | YES | Exact pixel width |
| `height` | `double` | YES | Exact pixel height |
| `borderRadius` | `BorderRadius` | YES | Shape of the glass surface |
| `child` | `Widget` | YES | Content inside the glass |
| `useFrost` | `bool` | NO (default: false) | Frosted variant (more opaque) |

### Layer stack (outside to inside):

```
DecoratedBox                    <- Outer S0 shadow system
 - ClipRRect(borderRadius)      <- Clips to shape
     - RepaintBoundary          <- Performance isolation
         - BackdropFilter       <- blur sigmaX=3.0 sigmaY=3.0 (the actual glass blur)
             - CustomPaint      <- Border painter (flat style noop)
                 - SizedBox     <- Enforces width x height
                     - DecoratedBox  <- Inner decoration
                         - fillColor: Colors.transparent
                         - innerShadows (4-layer inset stack)
                         - border: white 0.45 opacity, 0.8px wide
                         - gradient: white top-fade (4 stops)
                         - child
```

### Exact token values (from GlassmorphismPresets):

**Blur:**
```dart
ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0)
```

**Outer Drop Shadows S0 (4-layer stack):**
```dart
BoxShadow(offset: Offset(1.25, 0),  blurRadius: 0,  spreadRadius: -0.75, color: Color(0xFFD0D0D0))
BoxShadow(offset: Offset(-1.25, 0), blurRadius: 0,  spreadRadius: -0.75, color: Color(0xFFD0D0D0))
BoxShadow(offset: Offset(0, 0),     blurRadius: 0,  spreadRadius: 0.5,   color: Color(0xFFCCCCCC))
BoxShadow(offset: Offset(0, 8),     blurRadius: 15, spreadRadius: 0,     color: Color(0x05000000))
```

**Inner Shadows (4-layer inset stack):**
```dart
BoxShadow(offset: Offset(0, 1.25),  blurRadius: 0.25, spreadRadius: 0,   color: Color(0xFF282828), inset: true)
BoxShadow(offset: Offset(0, -1.25), blurRadius: 0.25, spreadRadius: 0,   color: Color(0xFF282828), inset: true)
BoxShadow(offset: Offset(0, 40),    blurRadius: 10,   spreadRadius: -40, color: Color(0xFF282828), inset: true)
BoxShadow(offset: Offset(0, -40),   blurRadius: 10,   spreadRadius: -40, color: Color(0xFF282828), inset: true)
```

**Border:**
```dart
Border.all(color: Colors.white.withValues(alpha: 0.45), width: 0.8)
// useFrost=true variant: alpha: 0.65
```

**Inner Gradient (useFrost=false — normal mode):**
```dart
LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Colors.white.withValues(alpha: 0.72),           // stop 0.00
    Colors.white.withValues(alpha: 0.0),            // stop 0.42
    scheme.surfaceTint.withValues(alpha: 0.08),     // stop 0.78
    Colors.black.withValues(alpha: 0.035),          // stop 1.00
  ],
  stops: [0, 0.42, 0.78, 1],
)
```

**Fill color:**
```dart
Colors.transparent
```

---

## 5. Shape Rules

| Shape | width | height | borderRadius |
|---|---|---|---|
| Pill button (standard) | any | 56 | BorderRadius.circular(30) |
| Circle / Sphere button | size | size | BorderRadius.circular(size / 2) |
| Rounded rect card | any | any | BorderRadius.circular(20) |
| Nav bar pill | 264 | 50 | BorderRadius.circular(25) |
| Nav bar FAB pill | 50 | 50 | BorderRadius.circular(25) |

**Rule:** For a perfect circle (sphere), width == height and borderRadius = BorderRadius.circular(width / 2).

---

## 6. Typography Rules (text inside glass)

Always use GoogleFonts.inter:

```dart
GoogleFonts.inter(
  color: const Color(0xFF333333),  // Ink — never use pure black
  fontSize: 16,
  fontWeight: FontWeight.w600,
  letterSpacing: -0.3,
)
```

For smaller labels:
```dart
GoogleFonts.inter(
  color: const Color(0xFF333333),
  fontSize: 14,
  fontWeight: FontWeight.w500,
  letterSpacing: -0.2,
)
```

---

## 7. Icon Rules (icon inside glass)

For SVG icons (project standard):
```dart
SvgPicture.asset(
  'assets/icons/your_icon.svg',
  width: iconSize,
  height: iconSize,
  colorFilter: const ColorFilter.mode(Color(0xFF333333), BlendMode.srcIn),
)
```

For Material icons (only if no SVG exists):
```dart
Icon(Icons.your_icon, color: const Color(0xFF333333), size: iconSize)
```

---

## 8. Ready-to-Use Code Templates

### Template A — Standard Pill Button (220x56)
```dart
TactileButton(
  useAppleSpring: true,
  onTap: () { /* action */ },
  child: BottomBarGlassSurface(
    width: 220,
    height: 56,
    borderRadius: BorderRadius.circular(30),
    child: Center(
      child: Text(
        'Button Label',
        style: GoogleFonts.inter(
          color: const Color(0xFF333333),
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
    ),
  ),
)
```

### Template B — Circle / Sphere Button (40x40)
```dart
TactileButton(
  useAppleSpring: true,
  onTap: () { /* action */ },
  child: BottomBarGlassSurface(
    width: 40,
    height: 40,
    borderRadius: BorderRadius.circular(20), // size / 2 = perfect circle
    child: Center(
      child: SvgPicture.asset(
        'assets/icons/your_icon.svg',
        width: 20,
        height: 20,
        colorFilter: const ColorFilter.mode(Color(0xFF333333), BlendMode.srcIn),
      ),
    ),
  ),
)
```

### Template C — Icon + Label Pill
```dart
TactileButton(
  useAppleSpring: true,
  onTap: () { /* action */ },
  child: BottomBarGlassSurface(
    width: 160,
    height: 48,
    borderRadius: BorderRadius.circular(24),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/icons/your_icon.svg',
            width: 18,
            height: 18,
            colorFilter: const ColorFilter.mode(Color(0xFF333333), BlendMode.srcIn),
          ),
          const SizedBox(width: 8),
          Text(
            'Label',
            style: GoogleFonts.inter(
              color: const Color(0xFF333333),
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    ),
  ),
)
```

---

## 9. What NOT to Do

- NEVER use GlassSurface for buttons — use BottomBarGlassSurface
- NEVER use useAppleSpring: false for Liquid Glass buttons
- NEVER use Colors.black for text — always Color(0xFF333333) which is Ink
- NEVER hardcode shadow values — BottomBarGlassSurface handles them internally via GlassmorphismPresets
- NEVER set playSelectionHaptic: false unless there is an explicit reason
- NEVER nest one BottomBarGlassSurface inside another
- NEVER skip TactileButton — every tappable glass surface must have it

---

## 10. File Locations

| Class | File path |
|---|---|
| BottomBarGlassSurface | lib/views/widgets/app_bottom_navigation_bar.dart |
| TactileButton | lib/views/widgets/tactile_button.dart |
| GlassmorphismPresets | lib/themes/glassmorphism_presets.dart |
| MotionPresets | lib/themes/glassmorphism_presets.dart |
