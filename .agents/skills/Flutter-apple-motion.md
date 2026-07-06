---
name: flutter-apple-motion
description: Add Apple-like motion design to Flutter apps. Use when Codex is asked to animate Flutter buttons, toggles, cards, icons, bottom sheets, navigation, page transitions, tab movement, morphing surfaces, Dynamic Island-style expansions, Photos/App Store-style shared element transitions, iMessage-like bubbles, VisionOS glass motion, macOS dock hover/bounce, loading states, micro-interactions, or any Flutter UI that should feel polished, native, fluid, springy, responsive, and Apple-inspired.
---

# Flutter Apple Motion

## Core Rule

Make motion feel native, intentional, and physically continuous. Prefer Flutter's built-in animation APIs first. Recommend packages only when they clearly improve quality, authoring speed, or asset-driven motion.

Inspect the existing app before editing. Preserve state management, business logic, routes, assets, icons, and user interaction semantics unless the user asks to redesign them.

## Motion Taste

Apple-like motion usually feels:

- Responsive: touch feedback starts immediately, often within 0-50 ms.
- Continuous: elements transform from one state into the next instead of disappearing and reappearing.
- Settled: springs can overshoot, but they should resolve quickly and quietly.
- Layered: scale, opacity, blur, position, corner radius, and elevation often move together.
- Contextual: transitions explain where the UI came from and where it went.
- Restrained: avoid cartoon bounce unless imitating dock-like hover/bounce or playful messaging.

## Workflow

1. Identify the interaction category: press, toggle, morph, route transition, sheet, shared element, list change, gesture, hover, loading, or micro-interaction.
2. Find the existing Flutter structure and decide whether to wrap it, replace only the visual shell, or create a reusable component.
3. Prefer implicit animations for simple state changes:
   - `AnimatedContainer`, `AnimatedScale`, `AnimatedOpacity`, `AnimatedPositioned`, `AnimatedAlign`, `TweenAnimationBuilder`, `AnimatedSwitcher`.
4. Use explicit animations when multiple properties, gestures, choreography, or interruptions matter:
   - `AnimationController`, `CurvedAnimation`, `TweenSequence`, `AnimatedBuilder`, `GestureDetector`, `DraggableScrollableSheet`, custom `PageRouteBuilder`.
5. Use platform-aware polish:
   - `HapticFeedback.selectionClick/lightImpact/mediumImpact` for meaningful touch moments.
   - `Semantics`, `InkWell`/`GestureDetector` hit targets, and stable layout dimensions.
   - Respect reduced motion with `MediaQuery.disableAnimationsOf(context)` where available, or `MediaQuery.of(context).disableAnimations`.
6. Verify the animation in a running app when possible. Check first frame, interrupted gestures, repeated taps, route back gesture, keyboard overlap, and 60/120 fps performance.

## Package Guidance

Prefer native Flutter animation APIs by default.

Recommend packages when useful:

- `animations`: Material shared-axis, fade-through, open-container patterns when they match the app and save route-transition work.
- `rive`: interactive vector state machines, icon morphs, liquid controls, complex branded motion, gesture-driven art.
- `lottie`: pre-rendered/After Effects-style loading, empty states, celebration, onboarding, or noninteractive illustrations.
- `flutter_animate`: concise chained effects for simple entrance/stagger animations, if the project already accepts the dependency.
- `spring`: optional only if the project wants spring helpers and native APIs become noisy.

Avoid dependencies for basic buttons, toggles, sheets, card expansion, opacity/scale transitions, and simple route motion.

## Apple Reference Mapping

- iOS Control Center toggles: immediate press scale, soft fill/color interpolation, icon scale/opacity, optional haptic tick.
- Dynamic Island morphing: one persistent rounded surface changes size, radius, content opacity, and position; avoid replacing it with unrelated widgets.
- Apple Music bottom sheet: draggable sheet with blurred/translucent background, smooth snap points, content fade/parallax.
- Photos zoom transition: shared element image/card moves continuously with `Hero`, matched border radius, background fade.
- App Store card expansion: card-to-detail route with shared element, rounded corners becoming full screen, content stagger after expansion.
- iMessage bubbles: quick scale-in, slight vertical movement, opacity fade, gentle spring; reactions can pop with scale and haptic.
- VisionOS glass motion: depth, parallax, blur, shadow, and scale; motion should be slow enough to feel spatial.
- macOS dock hover/bounce: pointer proximity scale and lift; bounce only for playful or dock-like controls.

## Reusable Patterns

For implementation snippets and reusable widgets/mixins, read `./flutter-motion-patterns.md` when building code.

Use those snippets as starting points, then adapt names, theming, imports, and architecture to the user's app.

## Timing Defaults

Start here, then tune by feel:

- Press down: 80-110 ms, `Curves.easeOut`.
- Press release: 140-220 ms, `Curves.easeOutCubic` or a subtle spring.
- Toggle: 220-320 ms, `Curves.easeOutCubic`.
- Small icon morph/rotation: 180-260 ms.
- Sheet/card expansion: 360-520 ms, cubic or spring.
- Full route transition: 420-650 ms.
- Staggered child reveal: 30-70 ms between children.
- Dock/hover response: 100-180 ms for scale, 180-260 ms for settle.

Good curve defaults:

```dart
const appleEase = Cubic(0.2, 0.0, 0.0, 1.0);
const appleEaseEmphasized = Cubic(0.16, 1.0, 0.3, 1.0);
const appleEaseInOut = Cubic(0.42, 0.0, 0.18, 1.0);
```

For explicit spring-like motion, use `SpringSimulation` only when gesture velocity or realistic settling matters. Otherwise, prefer cubic curves for predictable UI polish.

## Implementation Rules

- Keep widgets reusable with `const` constructors where possible.
- Keep animation controllers disposed.
- Do not animate expensive layout or blur every frame unless necessary; prefer transforms and opacity.
- Use `RepaintBoundary` around expensive animated/glass/content areas.
- Keep hit targets stable even when visuals scale down.
- Animate visual children, not the gesture detector's tappable area.
- Avoid layout jumps by giving animated surfaces stable constraints, aspect ratios, or `SizedBox` wrappers.
- Preserve existing icons and assets. For SVG icon morphs, recommend Rive only if true path morphing is required; otherwise crossfade/rotate/scale existing SVGs.
- Combine with `$flutter-glassmorphism-ui` when the request involves glass surfaces plus Apple-like motion.

## Deliverables

When implementing for the user, usually provide:

- Reusable animation widgets/mixins/helpers.
- A focused integration patch in the existing Flutter files.
- Package recommendations only when justified.
- A short usage snippet if the output is a reusable component.
- Verification notes from `dart format`, `flutter analyze`, and visual/manual testing when available.
