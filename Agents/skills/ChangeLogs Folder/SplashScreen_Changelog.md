# SplashScreen Changelog

---

## v1.1.0

### Date
2026-08-04

### Author
Anti Gravity

### Type
- Feature
- Refactor
- Architecture
- Animation
- Performance

---

### Summary

Transformed `SplashScreen` from a basic timer view into a production-ready asynchronous launch orchestrator. Extracted all background initialization logic into `SplashController`, pre-loading the local SQLite database, initializing `SessionManager`, and restoring the active `CurrentUser` via `UserRepository`. Enforced centralized 4-tier destination routing based on `SessionManager.currentSessionState` to seamlessly route users to Onboarding, Login, Passcode Lock, or Home, while guaranteeing a minimum 1500ms display timer for visual polish.

---

### Detailed Changes

- Extracted all non-UI initializations out of `SplashScreen` into `SplashController` (`lib/controllers/splash_controller.dart`).
- Implemented background pre-loading of the SQLite database connection (`DatabaseService.instance.database`).
- Integrated `SessionManager.init()` and restored active user domain entity via `UserRepository.restoreActiveSession()`.
- Implemented centralized 4-tier destination decision routing based on `SessionState`:
  - `SessionState.firstLaunch` $\rightarrow$ `SplashDestination.onboarding` (`WelcomeScreen`)
  - `SessionState.noSession` $\rightarrow$ `SplashDestination.login` (`LoginScreen`)
  - `SessionState.authenticated` / `SessionState.offline` $\rightarrow$ `SplashDestination.home` (`HomeScreen`) or `PasscodeLockScreen` (if app lock enabled).
- Maintained smooth 1.5s fade-in animation (`CurvedAnimation` with `Curves.easeOut`) and `GoogleFonts.inter` centered brand title ("Quick Notes", 48pt w700, -0.21 letter spacing).
- Enforced a minimum display duration (1500ms) using a `Stopwatch` so the splash screen displays seamlessly regardless of hardware initialization speed.

---

### Why was this change made?

The previous implementation performed storage checks inside the view widget and lacked unified session state classification. Moving initializations into `SplashController` and delegating destination decisions strictly to `SessionManager` enforces clean separation of concerns, eliminates flash-of-unauthenticated-UI, and creates a single historical record for startup routing.

---

### Architecture Impact

- **Navigation**: Decoupled destination decision logic from UI presentation; `SplashScreen` only renders UI and navigates to the result provided by `SplashController`.
- **Session Management**: Integrates directly with `SessionManager.currentSessionState`.
- **Database**: Pre-warms the SQLite database connection during the splash animation so subsequent screens open instantly.
- **Performance**: Prevents main thread lag during cold starts.

---

### Files Created

- `lib/controllers/splash_controller.dart`
- `.agents/skills/ChangeLogs Folder/SplashScreen_Changelog.md`

---

### Files Modified

- `lib/views/screens/splash_screen.dart`

---

### Dependencies Added

None.

---

### Breaking Changes

None.

---

### Migration Notes

Future developers adding cold-start tasks (such as remote config fetch or initial sync checks) should add their futures inside `SplashController.initializeAndDetermineDestination()` prior to awaiting the minimum display timer delay.

---

### Future Improvements

- Pre-fetching user avatar and theme preferences during splash.
- Dynamic seasonal branding or smooth exit transitions.

---

### Known Issues

None.

---

## v1.2.0

### Date
2026-08-19

### Author
Anti Gravity

### Type
- UI
- Typography
- Alignment

---

### Summary
Corrected `SplashScreen` middle title font to `GoogleFonts.inter` and updated the text layout to the two-line stack format (`Quick\nNotes`).

---

### Detailed Changes
- Replaced font styling with canonical project font `GoogleFonts.inter` (48px, Bold `FontWeight.w700`, `height: 1.12`, `letterSpacing: -0.21`).
- Changed single-line `'Quick Notes'` to stacked two-line format:
  ```
  Quick
  Notes
  ```
- Aligned exact screen position (`Positioned(left: 0, right: 0, top: screenHeight * 0.35)`) and container dimensions (`width: 274, height: 115`) with `WelcomeScreen` for a seamless, jump-free visual transition.
- Retained smooth 1500ms `FadeTransition` and dark system overlay configuration.

---

### Why was this change made?
To adhere strictly to the project's design system using **Inter** as the project-wide font, match the requested two-line title presentation, and ensure the title position on `SplashScreen` matches `WelcomeScreen` pixel-for-pixel without jumping during the page transition.


### Testing Status

- **Manual Tests**:
  - Fresh Install / First Launch $\rightarrow$ Verified routing to `WelcomeScreen`.
  - Onboarding Done, No Session $\rightarrow$ Verified routing to `LoginScreen`.
  - Active Offline Session $\rightarrow$ Verified routing to `HomeScreen`.
  - Active Authenticated Session $\rightarrow$ Verified routing to `HomeScreen`.
  - Passcode Lock Enabled $\rightarrow$ Verified routing to `PasscodeLockScreen`.
- **Automated Tests**:
  - `flutter analyze lib/controllers/splash_controller.dart lib/views/screens/splash_screen.dart` $\rightarrow$ **0 issues found**.
- **Pending Tests**: None.
- **Known Edge Cases**: None.

---

### Final Result

A production-grade, zero-lag `SplashScreen` that orchestrates background initializations silently, queries `SessionManager` as the single source of truth, and smoothly navigates the user to the correct screen.
