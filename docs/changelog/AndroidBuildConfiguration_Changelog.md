# AndroidBuildConfiguration — Changelog

---

## Version

v1.1.0

---

## Date

2026-10-06

---

## Author

Anti Gravity

---

## Type

- Architecture
- Breaking Change

---

## Summary

Completed the Android package rename from `com.quicknotes.app` to `com.quicknotes.byhmnth`. All Kotlin widget/activity files have been moved to the new package directory. The `AndroidManifest.xml`, `build.gradle.kts`, and `google-services.json` have been updated to reflect the production package identity. This aligns the build configuration with the published Play Store identity (`com.quicknotes.byhmnth`) established during the v1.1.1 internal testing release.

---

## Detailed Changes

- Deleted `android/app/src/main/kotlin/com/quicknotes/app/` directory and all its files:
  - `MainActivity.kt`
  - `MidnightWidgetUpdateReceiver.kt`
  - `MultiTaskWidget.kt`
  - `NoteWidgetConfigureActivity.kt`
  - `QuickCaptureWidget.kt`
  - `SingleNoteWidget.kt`
  - `SingleTaskLongWidget.kt`
  - `SingleTaskWidget.kt`
  - `TaskWidgetConfigureActivity.kt`
  - `TaskWidgetDateHelper.kt`
- Created `android/app/src/main/kotlin/com/quicknotes/byhmnth/` with identical files, updated package declarations.
- Updated `AndroidManifest.xml`: replaced all `com.quicknotes.app.*` receiver/activity references with `com.quicknotes.byhmnth.*`. Added missing widget receivers: `SingleNoteWidget`, `SingleTaskWidget`, `SingleTaskLongWidget`, `MultiTaskWidget`, `MidnightWidgetUpdateReceiver`, `NoteWidgetConfigureActivity`, `TaskWidgetConfigureActivity`.
- Updated `android/app/build.gradle.kts`: `applicationId = "com.quicknotes.byhmnth"`, updated namespace.
- Updated `android/app/google-services.json`: firebase app `package_name` set to `com.quicknotes.byhmnth`.
- Added/updated `android/app/src/main/res/xml/single_note_widget_info.xml`, `single_task_widget_info.xml`, `single_task_long_widget_info.xml` for widget metadata.
- Deleted `flutter_02.png` (unused asset from old project scaffolding).

---

## Why was this change made?

The original package ID `com.quicknotes.app` was a placeholder used during initial development. The Play Store identity was established as `com.quicknotes.byhmnth` (matching the developer's handle). All Kotlin code and build configuration must match the Play Store identity for signed releases to be accepted by Google Play. This change was required to unblock the v1.1.1 internal testing release.

---

## Architecture Impact

- **Authentication**: Firebase `google-services.json` now references `com.quicknotes.byhmnth`. SHA-1 fingerprints remain unchanged.
- **Build**: `applicationId` in `build.gradle.kts` updated — any local debug builds will produce APKs with the new package ID. Old debug APKs will conflict and must be uninstalled before installing new ones.
- **Android Widgets**: All widget receivers in the manifest now correctly reference the `byhmnth` package, enabling widget registration on device.

---

## Files Created

- `android/app/src/main/kotlin/com/quicknotes/byhmnth/MainActivity.kt`
- `android/app/src/main/kotlin/com/quicknotes/byhmnth/MidnightWidgetUpdateReceiver.kt`
- `android/app/src/main/kotlin/com/quicknotes/byhmnth/MultiTaskWidget.kt`
- `android/app/src/main/kotlin/com/quicknotes/byhmnth/NoteWidgetConfigureActivity.kt`
- `android/app/src/main/kotlin/com/quicknotes/byhmnth/QuickCaptureWidget.kt`
- `android/app/src/main/kotlin/com/quicknotes/byhmnth/SingleNoteWidget.kt`
- `android/app/src/main/kotlin/com/quicknotes/byhmnth/SingleTaskLongWidget.kt`
- `android/app/src/main/kotlin/com/quicknotes/byhmnth/SingleTaskWidget.kt`
- `android/app/src/main/kotlin/com/quicknotes/byhmnth/TaskWidgetConfigureActivity.kt`
- `android/app/src/main/kotlin/com/quicknotes/byhmnth/TaskWidgetDateHelper.kt`
- `android/app/src/main/res/xml/single_note_widget_info.xml`
- `android/app/src/main/res/xml/single_task_widget_info.xml`
- `android/app/src/main/res/xml/single_task_long_widget_info.xml`

---

## Files Modified

- `android/app/build.gradle.kts`
- `android/app/google-services.json`
- `android/app/src/main/AndroidManifest.xml`

---

## Files Deleted

- `android/app/src/main/kotlin/com/quicknotes/app/MainActivity.kt`
- `android/app/src/main/kotlin/com/quicknotes/app/MidnightWidgetUpdateReceiver.kt`
- `android/app/src/main/kotlin/com/quicknotes/app/MultiTaskWidget.kt`
- `android/app/src/main/kotlin/com/quicknotes/app/NoteWidgetConfigureActivity.kt`
- `android/app/src/main/kotlin/com/quicknotes/app/QuickCaptureWidget.kt`
- `android/app/src/main/kotlin/com/quicknotes/app/SingleNoteWidget.kt`
- `android/app/src/main/kotlin/com/quicknotes/app/SingleTaskLongWidget.kt`
- `android/app/src/main/kotlin/com/quicknotes/app/SingleTaskWidget.kt`
- `android/app/src/main/kotlin/com/quicknotes/app/TaskWidgetConfigureActivity.kt`
- `android/app/src/main/kotlin/com/quicknotes/app/TaskWidgetDateHelper.kt`
- `flutter_02.png`

---

## Dependencies Added

None.

---

## Breaking Changes

- **Package rename is a breaking change for device installs.** Any device with the old `com.quicknotes.app` APK installed must uninstall it before installing a new build with `com.quicknotes.byhmnth`.
- Old debug APKs are incompatible with new signing identity.

---

## Migration Notes

For local development: run `flutter clean` after pulling this branch, then `flutter pub get` and `flutter run`. If a device has the old package installed, uninstall first:
```
adb uninstall com.quicknotes.app
```

---

## Future Improvements

None. Package rename is a one-time permanent change.

---

## Known Issues

None.

---

## Testing Status

**Manual Tests**: v1.1.1 AAB installed successfully via Google Play internal testing. Google Sign-In verified working.
**Automated Tests**: No automated Android instrumentation tests at this version.
**Pending Tests**: None.
**Known Edge Cases**: None.

---

## Final Result

The Android build configuration is fully aligned with the production package identity `com.quicknotes.byhmnth`. All widget receivers, Firebase configuration, and Gradle build files are consistent. The app is successfully published as v1.1.1 on the internal testing track.
