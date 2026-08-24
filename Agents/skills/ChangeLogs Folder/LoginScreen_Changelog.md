# LoginScreen Changelog

---

## v1.1.0

### Date
2026-08-05

### Author
Anti Gravity

### Type
- Bug Fix
- Architecture

---

### Summary

Resolved Google Sign-In failure caused by missing Firebase OAuth configuration. Registered the Android app in Firebase Console with package name `com.quicknotes.app` and debug SHA-1 fingerprint, enabled Google Sign-In in Firebase Authentication, and configured the OAuth consent screen in Google Cloud Console. Simultaneously renamed the Android application ID and all related identifiers from the legacy `com.example.gravity_notes` to the correct `com.quicknotes.app`, fixed the app label from `gravity_notes` to `Quick Notes`, and updated the home screen widget label and deep link URI scheme. Google Sign-In is now fully operational — users can authenticate and are navigated directly to `HomeScreen` upon successful sign-in.

---

### Detailed Changes

- Registered Android app in Firebase Console with `applicationId = com.quicknotes.app` and debug SHA-1 fingerprint `A4:C8:AD:47:C8:AC:59:D1:6A:C1:16:17:71:52:38:2B:01:F1:72:FB`.
- Enabled Google Sign-In provider in Firebase Console → Authentication → Sign-in method.
- Configured OAuth consent screen in Google Cloud Console (App name: `Quick Notes`, user type: External).
- Added `google-services.json` to `android/app/` — correctly containing `package_name: com.quicknotes.app`.
- Added `com.google.gms.google-services` plugin `v4.4.2` to `android/settings.gradle.kts` (root plugins block).
- Applied `com.google.gms.google-services` plugin in `android/app/build.gradle.kts` (app plugins block).
- Renamed `namespace` and `applicationId` from `com.example.gravity_notes` → `com.quicknotes.app` in `android/app/build.gradle.kts`.
- Fixed `android:label` from `gravity_notes` → `Quick Notes` in `AndroidManifest.xml` (app now shows correct name on device).
- Updated `AndroidManifest.xml` widget receiver class path to `com.quicknotes.app.QuickCaptureWidget`.
- Updated `MainActivity.kt` and `QuickCaptureWidget.kt` package declarations to `com.quicknotes.app`.
- Relocated both Kotlin source files from `kotlin/com/example/gravity_notes/` to `kotlin/com/quicknotes/app/`.
- Updated deep link URI scheme in `QuickCaptureWidget.kt` from `gravitynotes://` → `quicknotes://`.
- Fixed widget title label in `widget_layout.xml` from `Gravity Notes` → `Quick Notes`.
- Temporarily exposed raw exception in `AuthenticationService` catch block for debugging; restored clean user-facing message after confirmation.
- Ran `flutter clean` + `flutter run` to ensure full Gradle rebuild with new package name.

---

### Why was this change made?

The `google_sign_in` package requires a valid `google-services.json` matched to the Android application ID, a registered OAuth client with the debug SHA-1 fingerprint, and an active Google Sign-In provider in Firebase. None of these were configured. Additionally, the Android application ID and all native identifiers carried the legacy `com.example.gravity_notes` placeholder name from an earlier project, which was renamed to `com.quicknotes.app` to match the app's production identity before Firebase registration.

---

### Architecture Impact

- **Authentication**: Google OAuth is now fully operational end-to-end. `AuthenticationService.signInWithGoogle()` returns `AuthResult.success` with `CurrentUser`, `accessToken`, and `idToken`.
- **Navigation**: Successful Google Sign-In navigates to `HomeScreen` via `LoginController` → `LoginScreen`.
- **Android**: Application ID changed from `com.example.gravity_notes` to `com.quicknotes.app` — this is a permanent identifier change.

---

### Files Created

- `android/app/google-services.json`

---

### Files Modified

- `android/settings.gradle.kts`
- `android/app/build.gradle.kts`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/kotlin/com/quicknotes/app/MainActivity.kt` *(moved from `com/example/gravity_notes/`)*
- `android/app/src/main/kotlin/com/quicknotes/app/QuickCaptureWidget.kt` *(moved from `com/example/gravity_notes/`)*
- `android/app/src/main/res/layout/widget_layout.xml`
- `lib/services/authentication_service.dart`

---

### Dependencies Added

None.

---

### Breaking Changes

- **Android application ID changed**: `com.example.gravity_notes` → `com.quicknotes.app`. Any previously installed debug builds are treated as a different app by Android. Existing debug installs must be uninstalled before installing the new build.

---

### Migration Notes

For production release builds, add the release SHA-1 fingerprint (from the release keystore) to Firebase Console → Project Settings → Android app → Add fingerprint, then re-download `google-services.json`.

---

### Future Improvements

- Add release keystore SHA-1 to Firebase for production builds.
- Apple Sign-In (future).
- Token refresh on expiry.

---

### Known Issues

None.

---

### Testing Status

- **Manual Tests**:
  - Tapped "Continue with Google" → native account picker appeared → selected account → navigated directly to `HomeScreen` ✅.
  - Received Google account data sharing confirmation email from Quick Notes ✅.
  - Tapped "Continue with Google" and cancelled picker → stayed on `LoginScreen` ✅.
- **Automated Tests**:
  - `flutter analyze lib/services/authentication_service.dart` → **0 issues found**.
- **Pending Tests**: None.
- **Known Edge Cases**: None.

---

### Final Result

Google Sign-In is fully operational. Users can authenticate via Google OAuth and are navigated to `HomeScreen` upon success. The app is correctly identified as `com.quicknotes.app` and shows `Quick Notes` as its name across all Android surfaces.

---

## v1.0.0


### Date
2026-08-04

### Author
Anti Gravity

### Type
- Feature
- UI
- Architecture
- Refactor
- Authentication

---

### Summary

Implemented `LoginScreen` adhering to production architecture, `UserRepository` single source of truth, storage separation, and exact Figma widget specifications. Features standard `AppHeaderBar` with `assets/icons/angle_left.svg` back button navigating back to `WelcomeScreen`, centered brand title "Quick Notes", and the `SignInOptions` widget with "Continue with google" (using native `google_sign_in` package, single line layout, and OAuth error feedback) and "Continue Offline" (using `LocalProfileService`).

---

### Detailed Changes

- Created `LoginScreen` (`lib/views/screens/login_screen.dart`).
- Integrated `AppHeaderBar` with standardized back button: `SvgPicture.asset('assets/icons/angle_left.svg', width: 22, height: 22, colorFilter: ColorFilter.mode(Color(0xFF333333), BlendMode.srcIn))` with `leftWidth: 44.0`, top offset `24.0`, and horizontal margins `30.0` (matching `folder_notes_screen.dart`).
- Rendered centered brand header "Quick Notes" (`GoogleFonts.inter` 48pt w700 letterSpacing -0.21).
- Built `_SignInOptions` widget to exact Figma snippet specs:
  - **Continue with google** pill: 244x42px, white fill, 16px blur drop shadow, 16x16 `DesignCode/Welcome Screens/google.png` icon, single line centered text layout (`maxLines: 1`, `softWrap: false`, 14pt Inter Bold `#333333`).
  - **or** divider text (14pt Inter Bold `#333333`).
  - **Continue Offline** pill: 244x42px, white fill, 16px blur drop shadow, 14pt Inter Regular `#FF383C` Accents-Red.
- Created `LoginController` (`lib/controllers/login_controller.dart`) managing UI states (`idle`, `authenticatingGoogle`, `initializingOffline`, `error`).
- Integrated native `GoogleSignIn` in `AuthenticationService` (`lib/services/authentication_service.dart`):
  - Account picker cancellation $\rightarrow$ stays on `LoginScreen`.
  - Unconfigured OAuth exception $\rightarrow$ returns structured failure, displays floating SnackBar error feedback, and stays on `LoginScreen`.
- Integrated `LocalProfileService` (`lib/services/local_profile_service.dart`) for offline identity generation (`SessionType.offline`).
- Implemented storage separation via `SessionManager`: tokens in `FlutterSecureStorage`, metadata & flags in `SharedPreferences`.
- Saved `CurrentUser` in `UserRepository` as the single source of truth.

---

### Why was this change made?

To provide a production-ready authentication UI that decouples view presentation from Google OAuth and local profile creation, uses standardized back button navigation, and handles cancellation/errors gracefully without freezing or auto-bypassing authentication.

---

### Architecture Impact

- **Navigation**: Header back button returns to `WelcomeScreen`; successful sign-in navigates to `HomeScreen`.
- **Authentication**: `AuthenticationService` handles Google OAuth; `LocalProfileService` handles offline identity.
- **State Management**: `LoginController` notifies `LoginScreen` of state changes.
- **Storage**: `SessionManager` separates tokens (`FlutterSecureStorage`) and preferences (`SharedPreferences`).
- **Domain Model**: `UserRepository` acts as single source of truth for `CurrentUser`.

---

### Files Created

- `lib/views/screens/login_screen.dart`
- `lib/controllers/login_controller.dart`
- `lib/services/authentication_service.dart`
- `lib/services/local_profile_service.dart`
- `lib/repositories/user_repository.dart`
- `lib/models/current_user.dart`
- `lib/models/session_type.dart`
- `lib/services/sync_manager.dart`
- `.agents/skills/ChangeLogs Folder/LoginScreen_Changelog.md`

---

### Files Modified

- `pubspec.yaml` (added `google_sign_in: ^6.2.1`)

---

### Dependencies Added

- `google_sign_in: ^6.2.1`

---

### Breaking Changes

None.

---

### Migration Notes

When configuring Google Sign-In for production builds, add the `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) along with SHA-1 fingerprints. The service falls back safely to SnackBar error messages when unconfigured.

---

### Future Improvements

- Apple Sign In.
- Email / Password authentication.
- Session expiration & token refresh.

---

### Known Issues

None.

---

### Testing Status

- **Manual Tests**:
  - App Header back button: verified smooth navigation back to `WelcomeScreen`.
  - "Continue with google": verified native account picker dialog, cancellation handling, and unconfigured OAuth SnackBar error feedback.
  - "Continue Offline": verified local profile creation (`SessionType.offline`) and transition to `HomeScreen`.
- **Automated Tests**:
  - `flutter analyze lib/views/screens/login_screen.dart lib/controllers/login_controller.dart lib/services/authentication_service.dart` $\rightarrow$ **0 issues found**.
- **Pending Tests**: None.
- **Known Edge Cases**: None.

---

### Final Result

A production-ready `LoginScreen` with clean architectural separation, standardized header back button UI, robust Google OAuth and offline mode integration, and floating error feedback.

---

## Version
v1.0.1

---

## Date
2026-08-24

---

## Author
Anti Gravity

---

## Type
- Bug Fix
- UI

---

## Summary
Replaced AppHeader back button with a circular back button above the Google Login button.

---

## Detailed Changes
- Removed AppHeader from LoginScreen.
- Added Container with a circular back arrow IconButton placed above the "Continue with Google" button.

---

## Why was this change made?
To improve UI consistency and address visual bugs reported by the user.

---

## Architecture Impact
No architectural impact.

---

## Files Modified
- lib/views/screens/login_screen.dart

---

## Breaking Changes
None.

---

## Migration Notes
None.

---

## Known Issues
None.

---

## Testing Status
- Manual Tests: Verified UI renders correctly.
- Automated Tests: flutter analyze passes.

---

## Final Result
Login screen now uses a localized circular back button instead of the global app header.
