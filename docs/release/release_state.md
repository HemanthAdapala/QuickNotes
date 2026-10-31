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

- Version: 1.1.4
- Version Code: 6
- Flutter Version: 1.1.4+6
- Track: Internal Testing
- Status: PREPARED LOCALLY (Ready for Play Console Internal Testing upload)
- AAB: build/app/outputs/bundle/release/app-release.aab
- File Size: 99,963,411 bytes (~95.3 MB)
- SHA-256: 1E596796DDADB0E6E9CF835BA82450A7B059691AECEEB45D116BE34593A02AC4
- Build Date: 2026-10-27
- Source Branch: feature/production-data-architecture
- Source Revision: 30cc03a (working tree contains uncommitted feature & task reminder fixes)
- Build Command: flutter build appbundle --release
- Build Result: PASS (Exit code 0, 235.3s)
- Signing Result: PASS (Signed with quicknotes-upload keystore, Verified via keytool)
- Analyzer Result: PASS (0 errors, 0 warnings across all modified services and providers)
- Purpose: Internal-Testing Build containing comprehensive Task Reminder reliability overhaul and collision-free notification partitioning
- Remaining Blockers / Pending Validation: Physical-device testing on Samsung Galaxy S23 Ultra; Play Console upload pending manual submission

## Next Available Play Version

- Version Name: 1.1.5
- Version Code: 7

## Release Notes (Version 1.1.4 / Code 6)

Internal testing release containing comprehensive Task Reminder reliability overhaul:
- Day 2 & recurring recurrence delivery: Next occurrence calculation and auto-scheduling integrated into TaskEngine, TasksProvider, and NotificationActionHandler.
- Partitioned, collision-free notification IDs: Segregated notification ID space (`NotificationIdManager`) preventing task, occurrence, and note reminder ID collisions.
- Due date anchor preservation: Recurring task due date anchors preserved accurately across occurrences without drift.
- Notification action handler: Reliable background action completion ('Mark Done') and auto-advancement for recurring reminders.
- Reboot alarm recovery: Native Android boot receiver and app resume reconciliation ensuring active future reminders persist across device restarts.

## Release Notes (Version 1.1.3 / Code 5)

Internal testing release containing hardened Premium Billing lifecycle & entitlement management:
- Single-dismissal navigation guard preventing double dismissals and black screen on purchase/restore.
- Robust ownership reconciliation recovering active entitlements without wiping local cache on store disconnects/timeouts.
- Proper handling of code 7 (ITEM_ALREADY_OWNED) through verifier & entitlement persistence without raw bypass.
- Offline and temporary outage entitlement caching protection for lifetime purchases.
- Idempotent lifecycle observer registration and teardown on app resume.

## Release Notes (Version 1.1.2 / Code 4)

Internal testing release focused on Google Play Premium Billing verification:
- Fixed restore purchases indefinite loading via bounded timeout, sequence tracking, and concurrency protection.
- Added explicit pending payment approval state and informative user messaging.
- Verified one-time non-consumable product integration for 'quicknotes_premium_lifetime'.

## Testing Scope

- [x] Google Sign-In on Google Play installed build
- [x] Firebase configuration
- [x] Release signing
- [x] Android package identity
- [x] AAB installation through Google Play (Baseline 1.1.1)
- [ ] Physical-device testing for Premium purchase & restore (Version 1.1.3 pending)
- [ ] Physical-device testing for Task Reminders on Samsung Galaxy S23 Ultra (Version 1.1.4 pending)

## Known Issues

- None currently recorded for the release baseline.

## Previous Releases

### Version 1.1.3 (5)

- Track: Internal Testing
- Status: Superseded by 1.1.4 (6)
- Purpose: Premium Billing lifecycle & entitlement management hardening
- AAB: app-release.aab

### Version 1.1.2 (4)

- Track: Internal Testing
- Status: Superseded by 1.1.3 (5)
- Purpose: Premium Purchase Hardening (Restore timeout & pending purchase state handling)
- AAB: app-release.aab

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

## Premium Billing Verification Architecture & Entitlement Policy

### 1. Purchase Verifier Scope & Limitations (`DefaultPurchaseVerifier`)
- **What it checks (Client-Side Structural Validation):**
  1. Product ID strictly equals `quicknotes_premium_lifetime`.
  2. Transaction status strictly equals `PurchaseStatus.purchased` or `PurchaseStatus.restored`.
  3. Platform store source matches the runtime OS (`StoreSource.google` on Android, `StoreSource.apple` on iOS).
  4. Populates transaction metadata (`transactionReference`, `originalPurchaseDate`, `verifiedAt`).
- **What it does NOT verify:**
  1. Does **not** perform RSA cryptographic signature verification of the purchase token against Google Play's public key.
  2. Does **not** perform server-side receipt validation via the Google Play Developer API (`purchases.products.get`).
  3. Does **not** connect to a trusted remote backend or Google Play Real-Time Developer Notifications (RTDN).
- **Critical Distinction:**
  Checking product ID, status flags, and token presence confirms the Flutter `in_app_purchase` plugin received a syntactically valid transaction from the on-device billing client. It is **not** equivalent to authenticating that the purchase was verified by Google's backend.
- **Backend Requirement:**
  True cryptographic verification requires a secure server backend holding Google Cloud service account credentials to query Google Play Developer APIs directly. No backend capability is currently implemented or claimed.

### 2. Cached Entitlement & Revocation Policy
- **Successful Verified Ownership Check:**
  A valid `PurchaseDetails` object (from direct purchase or restore) is verified by `DefaultPurchaseVerifier`. The resulting `PremiumEntitlement.active` is immediately written to `FlutterSecureStorage` by `PremiumEntitlementManager.updateEntitlement()`. `FeatureAccess` and all reactive listeners unlock Premium features.
- **Empty Restore Result / Restore Timeout:**
  If Google Play returns no purchases or the restore operation reaches its 5-second timeout, `InAppPurchaseProvider` sets status to `PurchaseActionStatus.error` with a truthful message ("Unable to confirm previous purchases from the store..."). **Crucially, the existing cached entitlement in `FlutterSecureStorage` is NOT wiped.**
- **Billing Service Unavailable / Network Failure:**
  If Google Play Billing is disconnected, offline, or experiencing network errors, previously verified and cached entitlements remain 100% active. Offline users never lose their purchased lifetime capabilities.
- **Play Store Account Mismatch:**
  Because Google Play Billing operates at the Android OS / Google Play Store account level while Quick Notes uses device-wide `FlutterSecureStorage`, switching Google Play Store accounts does not automatically revoke a previously verified on-device entitlement. If an un-entitled Play Store account taps Restore, the timeout triggers an error message but preserves the existing local cache.
- **Refunded or Revoked Purchases:**
  In this client-only architecture, Google Play does not push revocation events to the app without a backend server and RTDN webhook. If a purchase is refunded by Google Play, the purchase is simply omitted from future `queryPurchasesAsync()` calls. Because an empty restore response cannot be distinguished from a transient network glitch or store account mismatch, the client does not speculate and retains the cached entitlement until local app data is cleared or reinstalled. A secure backend with server-side entitlement revocation is recommended for the future roadmap if refund enforcement is required.

### 3. Device-Wide vs. User-Account Model
- Quick Notes stores the entitlement globally in `FlutterSecureStorage` under `premium_cached_entitlement`.
- The entitlement is device-scoped. If User A purchases Premium on the device and User B logs in (or the user switches between Google Sign-In and offline mode), the device retains the lifetime unlock. This is standard behavior for mobile lifetime non-consumable purchases.