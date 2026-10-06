# QuickNotesVisualTransition Developer Documentation

`QuickNotesVisualTransition` is the generic, reusable visual motion and morphing primitive for Quick Notes. It provides physics-driven geometric transitions, stretching, content cross-fading, and shape interpolation for any Flutter widget or Quick Notes Liquid Glass surface.

---

## 1. What `QuickNotesVisualTransition` Is

`QuickNotesVisualTransition` is an isolated visual-only motion component. It wraps any target UI element and transitions it smoothly between two visual states:
- **Collapsed** (e.g. compact button, pill, circular icon)
- **Expanded** (e.g. card, menu, toolbar, expanded sheet)

It is powered by the validated Quick Notes motion engine (`HarmonicSpring`, `QuickNotesMorphGeometryController`, and `QuickNotesMorphContentController`), executing spring dynamics across geometry, leading/trailing stretch deformation, and timed content dissolve/crossfade.

---

## 2. What It Owns

`QuickNotesVisualTransition` strictly owns **transient visual animation state**:
1. **Authoritative Clock & Ticker**: Starts a Flutter `Ticker` on transition request and automatically stops when physics settle.
2. **Spring Integration**: Step-by-step integration of the dual-spring system (position spring + trailing stretch spring).
3. **Live Geometry & Interpolation**: Live width, height, position, and corner radius computation.
4. **Content Crossfade & Blur**: Outgoing content scale/opacity fade-out and incoming content fade-in with optional backdrop blur.
5. **Capability Orchestration**: Coordinating visual capabilities and producing an immutable `QuickNotesVisualFrame` on every tick.

---

## 3. What It Does NOT Own

`QuickNotesVisualTransition` does **NOT** own:
- **Application/Business State**: It has no knowledge of notes, tasks, folders, selection mode, or user settings.
- **Semantic State Transitions**: It does not decide *when* a menu opens, closes, or triggers an action.
- **Navigation/Route Management**: It does not pop routes, push screens, or intercept back-button events.
- **Glass Shaders or Render Objects**: It does not render custom GPU shaders or metaballs; it delegates surface rendering to Flutter or `BottomBarGlassSurface`.

---

## 4. How Presets Work

Visual presets formalize the validated configurations discovered and confirmed during the Quick Notes Morph Fidelity Lab research. Presets are immutable value objects defined in `QuickNotesVisualPreset`:

- **`QuickNotesVisualPreset.baseline`** (The Physically Validated Locked Configuration):
  - Geometry Spring: Stiffness 195.0, Damping 19.5 (base damping ratio $\zeta \approx 0.698$).
  - Asymmetric Stretch Dynamics: Stretch factor 0.75, Lead Bounce 0.10, Follow Delay 40ms (0.04s).
  - Content Optics: Blur 8.0 sigma, Content Follow 1.0 (rides moving surface), Content Slide 0.0.
  - Content Timing & Scale: Outgoing fade to 0 by 40% progress (scales to 0.92), Incoming fade in from 30% to 80% progress (scales from 0.90).
- **`QuickNotesVisualPreset.balanced`**:
  - Coupled 4D spring with zero lag and zero stretch (`stretch = 0.0`, `leadBounce = 0.0`, `followDelay = 0ms`) producing straight-line travel.
- **`QuickNotesVisualPreset.anchorLocked`**:
  - Native-inspired anchored lock matching placement alignment with subtle stretch (`stretch = 0.20`, `leadBounce = 0.0`, `followDelay = 0ms`).

### Composable Overrides
You can take any preset and override specific attributes without mutating the canonical preset:

```dart
// Start from baseline, but customize stretch or motion
final customPreset = QuickNotesVisualPreset.baseline
    .withMotion(
      stiffness: 220.0,
      damping: 22.0,
    )
    .withStretch(
      stretch: 0.50,
      leadBounce: 0.05,
    );
```

---

## 5. How Capabilities Work

Capabilities follow a compositional plugin architecture. Instead of creating a monolithic widget with dozens of flags, visual features are encapsulated in `QuickNotesVisualCapability` implementations:

```
QuickNotesVisualTransition
    ├── GeometryCapability   (Live bounds, anchor, dimensions)
    ├── MotionCapability     (Spring stiffness, damping, velocity)
    ├── MorphCapability      (Target retargeting & state direction)
    ├── StretchCapability    (Asymmetric lead/trail stretch)
    ├── ShapeCapability      (BorderRadius interpolation)
    ├── ContentCapability    (Fade, scale, blur cross-fading)
    └── AdaptivityCapability (Future: Responsive/device-aware rules)
```

Capabilities receive the authoritative `QuickNotesVisualFrame` on every tick, can contribute to frame evaluation, and can wrap or transform the rendered widget tree.

---

## 6. How to Use with Liquid Glass

To apply the transition to a Quick Notes Liquid Glass surface, use the dedicated `.liquidGlass(...)` factory constructor. This seamlessly injects `BottomBarGlassSurface` with production styling (`sigma: 25.0`, `useFrost: true`, inner specular highlights):

```dart
QuickNotesVisualTransition.liquidGlass(
  state: _isExpanded 
      ? QuickNotesVisualState.expanded 
      : QuickNotesVisualState.collapsed,
  collapsedSize: const Size(44, 44),
  expandedSize: const Size(192, 100),
  collapsedAnchor: Alignment.topRight,
  expandedAnchor: Alignment.topRight,
  preset: QuickNotesVisualPreset.baseline,
  collapsedChild: const Icon(Icons.more_horiz, color: Colors.white),
  expandedChild: const MyMoreOptionsContent(),
  onTapped: () => setState(() => _isExpanded = !_isExpanded),
)
```

---

## 7. How to Use with a Normal Flutter Widget

`QuickNotesVisualTransition` is completely renderer-agnostic. For standard containers, cards, or buttons, use the default constructor. It applies clean geometric clipping and transformation without requiring glass surfaces:

```dart
QuickNotesVisualTransition(
  state: _isExpanded 
      ? QuickNotesVisualState.expanded 
      : QuickNotesVisualState.collapsed,
  collapsedSize: const Size(120, 48),
  expandedSize: const Size(300, 200),
  preset: QuickNotesVisualPreset.balanced,
  collapsedChild: Container(
    color: Colors.blueAccent,
    alignment: Alignment.center,
    child: const Text('Tap to expand', style: TextStyle(color: Colors.white)),
  ),
  expandedChild: Container(
    color: Colors.blueAccent,
    padding: const EdgeInsets.all(16),
    child: const Column(
      children: [
        Text('Expanded Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text('Any ordinary Flutter layout works cleanly here.', style: TextStyle(color: Colors.white70)),
      ],
    ),
  ),
  onTapped: () => setState(() => _isExpanded = !_isExpanded),
)
```

---

## 8. How Future Capabilities (e.g. Adaptivity) Can Be Added

Future visual systems can be plugged in without modifying `QuickNotesVisualTransitionController`, `BottomBarGlassSurface`, or consuming screens.

### Step 1: Implement `QuickNotesVisualCapability`
```dart
class AdaptivityCapability implements QuickNotesVisualCapability {
  final double tabletScaleFactor;
  final bool compactMode;

  const AdaptivityCapability({
    this.tabletScaleFactor = 1.25,
    this.compactMode = false,
  });

  @override
  String get id => 'adaptivity';

  @override
  QuickNotesVisualFrame onFrame(
    QuickNotesVisualFrame frame,
    QuickNotesVisualTransitionController controller,
  ) {
    if (compactMode) {
      // Modify or scale visual frame boundaries adaptively
      return frame.copyWith(
        extra: {'adaptiveScale': tabletScaleFactor},
      );
    }
    return frame;
  }

  @override
  Widget wrapVisualOutput(BuildContext context, Widget child, QuickNotesVisualFrame frame) {
    return Transform.scale(
      scale: (frame.extra['adaptiveScale'] as double?) ?? 1.0,
      child: child,
    );
  }
}
```

### Step 2: Pass into Capabilities List
```dart
QuickNotesVisualTransition(
  state: visualState,
  capabilities: [
    AdaptivityCapability(compactMode: isSmallScreen),
  ],
  ...
)
```
Notice that consuming screens and existing callers are completely unaffected.

---

## 9. How to Avoid Coupling Business State to Visual State

To maintain clean architecture:
1. **Never pass state notifiers, repositories, or BLoCs into `QuickNotesVisualTransition`**: Only pass `QuickNotesVisualState.collapsed` or `QuickNotesVisualState.expanded`.
2. **Handle user intents in callbacks**: When the user taps the transitioning element, fire `onTapped` or a custom callback to let the parent screen update its semantic domain model (e.g. `_isMoreOptionsOpen`).
3. **Avoid screen-specific geometry hacks**: Configure `collapsedSize`, `expandedSize`, and `anchor` based on the visual design contract rather than guessing window dimensions or hardcoding pixel compensations.
