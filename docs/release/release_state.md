# QUICK NOTES RELEASE STATE

## Current Release

- Version Name: 1.1.1
- Version Code: 3
- Flutter Version: 1.1.1+3
- Track: Internal Testing
- Status: PUBLISHED
- Release Date: 2026-10-05
- Release Purpose: Google Sign-In compatibility for Play-distributed build
- Google Play Status: Available to Internal Testers

## Current Known-Good Baseline

- Version: 1.1.1
- Version Code: 3
- Google Sign-In: VERIFIED WORKING ON PLAY-DISTRIBUTED BUILD
- Firebase: VERIFIED
- Play Distribution: VERIFIED

## Latest Build

- Version: 1.1.1
- Version Code: 3
- APK: build/app/outputs/flutter-apk/app-release.apk
- AAB: build/app/outputs/bundle/release/app-release.aab
- Build Date: 2026-10-05
- Build Result: PASS
- Signing Result: PASS
- Firebase Processing: PASS
- Analyzer Result: 0 errors / pre-existing info-lints only
- Test Result: Play-installed build verified

## Next Available Play Version

- Version Name: 1.1.2
- Version Code: 4

## Release Notes

Internal testing release focused on Google Sign-In compatibility
for the Play-distributed build.

Also includes general stability and configuration updates.

## Testing Scope

- [x] Google Sign-In on Google Play installed build
- [x] Firebase configuration
- [x] Release signing
- [x] Android package identity
- [x] AAB installation through Google Play

## Known Issues

- None currently recorded for the release baseline.

## Previous Releases

### Version 1.1.1 (3)

- Track: Internal Testing
- Status: Published
- Purpose: Google Sign-In fix
- Google Sign-In: VERIFIED WORKING
- Firebase: VERIFIED
- AAB: app-release.aab

### Version 1.1.0 (2)

- Track: Internal Testing
- Status: Superseded
- Purpose: Initial internal testing release
- Google Sign-In: FAILED ON PLAY-DISTRIBUTED BUILD
- Resolution: Play App Signing SHA-1 registered in Firebase

## Important Configuration

- Android Package: com.quicknotes.byhmnth
- Firebase Project: quick-notes-7e3c2
- Firebase Android App: com.quicknotes.byhmnth
- Upload Key Alias: quicknotes-upload
- Upload Keystore: android/keystore/quicknotes-upload.jks

## Signing

### Upload Certificate

- SHA-1: F4:58:06:CA:02:78:C8:B2:C0:8D:F1:5F:9B:27:7C:C2:D5:6F:30:C6
- SHA-256: 4B:8F:A2:B2:01:BF:2F:CF:CA:76:AA:B0:89:CE:80:C8:EB:D5:1A:4F:25:1F:8F:7A:A5:10:EB:0D:73:56:F3:BA

### Play App Signing Certificate

- SHA-1: 3E:6F:DB:83:3A:D4:BD:1A:E2:B7:E7:83:19:95:7A:9F:F8:7C:28:51