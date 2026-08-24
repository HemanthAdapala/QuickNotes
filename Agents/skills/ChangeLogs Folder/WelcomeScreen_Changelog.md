# WelcomeScreen Changelog

---

## v1.2.0

### Date
2026-08-04

### Author
Anti Gravity

### Type
- Feature
- UI
- Animation
- Refactor
- Architecture

---

### Summary

Transformed `WelcomeScreen` into a fluid, animated luxury onboarding landing experience. Implemented screen-edge responsive card positioning for 4 floating cards with step-by-step verified ambient glow overlays. Added physics-driven staggered entrance physics (`_entranceController`), perpetual floating micro-motion (`_floatController`), and a glassmorphic Start button with specular border lighting. Integrated card offscreen exit physics (`_entranceController.reverse()`), `SessionManager().setOnboardingCompleted()`, and smooth page transition navigation to `LoginScreen`.

---

### Detailed Changes

- Implemented responsive screen-edge positioning for 4 floating onboarding cards:
  1. **Top-Left**: Grey Folder popup (`Folder popup.png`) with Soft Coral Ambient Glow (`Color(0x1CFFAAA6)`).
  2. **Top-Right**: Yellow Task Card widget (`Welcome Screen Task Widget 01.png` — *"Things to do today"*) with Soft Blue Glow (`Color(0x250088FF)`).
  3. **Middle-Left**: Yellow Note Card widget (`Welcome screen Note Widget 02.png` — *"Camera Equipment"*) with Soft Amber Glow (`Color(0x22FFCC00)`).
  4. **Bottom-Right**: Blue Note Card widget (`Welcome screen Note Widget 01.png` — *"Client Meeting Tomorrow"*) with Subtle Yellow Glow (`Color(0x22FFCC00)`).
- Built liquid glassmorphic "Start" button (`BackdropFilter` `sigmaX: 14.0`, fill opacity `0.35`, 1.2px specular gradient border) with animated pulsing chevron arrow.
- Implemented card entrance physics (`_entranceController`, 1400ms duration with `CurvedAnimation` `Curves.easeOutBack`).
- Added continuous floating micro-motion (`_floatController`, 3000ms duration with sine wave offset).
- Added card offscreen exit animation: tapping **Start** reverses `_entranceController` to slide and fade cards offscreen (left cards exit offscreen left, right cards exit offscreen right).
- Integrated `SessionManager().setOnboardingCompleted()` and stored `has_completed_onboarding = 'true'` in `SharedPreferences` and `FlutterSecureStorage`.
- Configured smooth page route transition to `LoginScreen`.

---

### Why was this change made?

To create a luxury onboarding experience, adhere to fluid modern design aesthetics, calibrate ambient glows around floating cards, and manage smooth exit physics prior to authentication.

---

### Architecture Impact

- **Navigation**: Navigates to `LoginScreen` upon completing onboarding.
- **Session Management**: Writes onboarding completion flag (`hasCompletedOnboarding = true`) via `SessionManager`.
- **Animation**: Manages 3 controller animation loops (`_entranceController`, `_floatController`, `_arrowController`) with proper lifecycle cleanup.

---

### Files Created

- `.agents/skills/ChangeLogs Folder/WelcomeScreen_Changelog.md`

---

### Files Modified

- `lib/views/screens/welcome_screen.dart`

---

### Dependencies Added

None.

---

### Breaking Changes

None.

---

### Migration Notes

None.

---

### Future Improvements

- Interactive card tilt gestures on user drag.
- Dark mode ambient glow intensity scaling.

---

### Known Issues

None.

---

## v1.3.0

### Date
2026-08-19

### Author
Anti Gravity

### Type
- UI
- Glassmorphism
- Component Alignment

---

### Summary
Restored the dedicated glassmorphic **Start** button featuring the project's signature dual-layer liquid glass architecture (Layer 1: `#54999999` translucent backing fill + 4-tier drop shadows; Layer 2: frosted glass surface with 4-tier inner depth shadows and specular white border) with `TactileButton` spring physics and animated pulsing chevron arrow.

---

### Detailed Changes
- Fixed card image asset paths to point accurately to the registered `DesignCode/Welcome Screens/` directory (`Folder popup.png`, `Welcome Screen Task Widget 01.png`, `Welcome screen Note Widget 02.png`, `Welcome screen Note Widget 01.png`, and `Calender.png`), restoring the 4 floating ambient-glow cards and tilted physics.
- Dedicated pure frosted glass Start button (`width: 140, height: 50, borderRadius: 25`):
  - Removed the `#54999999` backing fill layer as requested.
  - Retained `ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0)`, `0.8px` white specular border (`#FFFFFF` @ 65%), and 4-tier inset depth shadows (`GlassmorphismPresets.innerShadows`) with outer ambient drop shadows.
- Integrated `TactileButton` (`compressionScale: 0.7`, `settleDuration: 1000ms`, `useAppleSpring: true`) with medium haptic feedback on tap.
- Re-enabled continuous pulsing arrow micro-animation (`_arrowPulse`).
- Reverses entrance animation on tap and routes seamlessly into `LoginScreen`.

---

### Why was this change made?
To eliminate the dark grey backing tint and present a clean, luminous pure frosted glass capsule on the Welcome screen.

---

### Testing Status

- **Automated Tests**:
  - `flutter analyze lib/views/screens/welcome_screen.dart` $\rightarrow$ **0 issues found**.
  - `flutter test test/widget_test.dart test/views/splash_screen_recovery_navigation_test.dart` $\rightarrow$ **100% green**.


### Testing Status

- **Manual Tests**:
  - Verified individual card placement and matching ambient glows for all 4 cards.
  - Verified glassmorphic Start button press animations and haptics.
  - Verified card exit animation (cards slide and fade offscreen) on tapping Start.
- **Automated Tests**:
  - `flutter analyze lib/views/screens/welcome_screen.dart` $\rightarrow$ **0 issues found**.
- **Pending Tests**: None.
- **Known Edge Cases**: None.

---

### Final Result

A state-of-the-art onboarding screen featuring floating ambient-glow cards, fluid entrance and exit physics, and seamless integration with `SessionManager` and `LoginScreen`.

---

## v1.4.0

### Date
2026-08-20

### Author
Anti Gravity

### Type
- UI
- Glassmorphism
- Component Alignment

---

### Summary

Updated the glassmorphic button in `WelcomeScreen` (`lib/views/screens/welcome_screen.dart`) to use `BottomBarGlassSurface` with `width: 220, height: 56, borderRadius: BorderRadius.circular(30)` wrapped in `TactileButton`, matching the exact liquid glass aesthetics and 30px corner curvature tested on `TestWelcomeScreen`.

---

### Detailed Changes

- **Button Refinement**: Replaced previous capsule button with `BottomBarGlassSurface` (`width: 220, height: 56, borderRadius: BorderRadius.circular(30)`).
- **Tactile Integration**: Wrapped `BottomBarGlassSurface` in `TactileButton(useAppleSpring: true, compressionScale: 0.7, settleDuration: 1000ms)` so the whole glass surface compresses seamlessly on tap.

---

### Files Modified

- `lib/views/screens/welcome_screen.dart`
- `Agents/skills/ChangeLogs Folder/WelcomeScreen_Changelog.md`

---

### Testing Status

- Static analysis: `flutter analyze lib/views/screens/welcome_screen.dart` passed (0 issues).
- Automated tests: `flutter test test/views/test_welcome_screen_test.dart` passed.
