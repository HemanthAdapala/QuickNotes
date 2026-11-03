# PremiumEntitlement — Changelog

---

## Version

BUG-001 (Phase 1B)

---

## Date

2026-10-24

---

## Author

Anti Gravity (Pair Programming Assistant)

---

## Type

- Security
- Architecture
- Backend Integration
- Cryptography

---

## Summary

Implemented BUG-001 Phase 1B: Premium Purchase Revocation & Entitlement Security following the owner-approved Option A policy contract (Offline-Tolerant Seven-Day Signed Ed25519 JWS Lease).

This delivers an end-to-end, zero-trust backend purchase verification and retry ledger architecture (Cloudflare Workers + D1) coupled with pure Dart RFC 8032 Ed25519 cryptographic lease verification, rollback/reboot safety uncertainty detection, and resilient offline gating in Flutter.

---

## Detailed Changes

### Backend (`backend/`)
- **D1 Schema & Migrations (`backend/migrations/0001_initial_schema.sql`):**
  - Created authoritative `purchases` table keyed by SHA-256 token hash (`token_hash`).
  - Added strict CHECK constraints: `status IN ('ACTIVE', 'REVOKED')`, `acknowledgement_state IN ('PENDING', 'ACKNOWLEDGED', 'UNSPECIFIED', 'NOT_APPLICABLE')`.
  - Added nullable `purchase_time_ms` (preventing fabricated purchase timestamps).
  - Encrypted purchase tokens stored with versioned AES-256-GCM only while acknowledgement/reconciliation is pending.
  - Partial queue index `idx_purchases_ack_queue` covering eligible pending acknowledgement rows.
- **Authoritative Google Play Integration (`backend/src/google-play.ts`):**
  - Authoritative REST query against Google Play Developer API v3 `purchases.productsv2` and `purchases.products.acknowledge`.
  - Strict validation of package name `com.quicknotes.byhmnth` and SKU `quicknotes_premium_lifetime`.
  - Fail-closed handling for `PURCHASED`, `PENDING`, `CANCELLED`, and `UNSPECIFIED` states.
- **Concurrency & Tombstone Ledger (`backend/src/db.ts`):**
  - Implemented CAS state transitions with `state_version` increments.
  - Cancellation tombstone insertion (`status = 'REVOKED'`, `acknowledgement_state = 'NOT_APPLICABLE'`) with token purging upon authoritative cancellation.
  - Anti-resurrection guarantee: committed `REVOKED` rows cannot be overwritten or resurrected by stale `PURCHASED` requests.
- **Crypto Core (`backend/src/crypto.ts`):**
  - WebCrypto SubtleCrypto SHA-256 hashing.
  - AES-256-GCM versioned encryption/decryption with key rotation support.
  - Ed25519 compact JWS signing (`alg: EdDSA`, `typ: JWT`).
- **Acknowledgement Queue & Cron (`backend/src/cron.ts`):**
  - Bounded 5-minute row claiming mechanism (`ack_claim_expires_at`).
  - Urgency-clamped exponential backoff (clamped to 15m for missing timestamps or true purchase age > 48h).
  - Explicit metric reporting for queue depth, authoritative purchase age, observation age, and repeated failures.
- **Worker Entrypoint (`backend/src/index.ts`):**
  - `POST /verify-purchase` handler with pre-issuance check.
  - Scheduled cron handler for acknowledgement retry processing.

### Flutter Client (`lib/premium/`)
- **Pure Dart RFC 8032 Ed25519 Engine (`lib/premium/crypto/ed25519.dart`):**
  - Zero external binary/FFI dependencies.
  - Edwards25519 projective arithmetic, point compression, and constant-time scalar operations.
  - Fully verified against official RFC 8032 test vectors.
- **Configuration & Key Pinning (`lib/premium/premium_config.dart`):**
  - Configurable `issuerUrl` (`PREMIUM_ISSUER_URL`).
  - Pinned Ed25519 public keys (`trustedPublicKeys`) supporting planned and emergency key rotation.
  - Exact 7-day (604,800s) lease lifetime, 60s clock skew tolerance, and 15m clock rollback limit.
- **JWS Lease Model & Strict Verifier (`lib/premium/jws_lease.dart`, `lib/premium/jws_lease_verifier.dart`):**
  - Strict validation of `alg == 'EdDSA'`, `typ == 'JWT'`, pinned `kid`, `iss`, `aud`, `sub`, `entitlement == 'premium'`, `status == 'ACTIVE'`, and temporal validity.
- **Authoritative Remote Verifier (`lib/premium/remote_purchase_verifier.dart`):**
  - Implements `PurchaseVerifier`.
  - Dispatches purchase verification to backend, validates 7-day JWS lease, and updates `PremiumEntitlementManager`.
  - Authoritatively revokes entitlement on HTTP 403 `REVOKED`.
  - Fails safe on network errors / 5xx without erroneously revoking valid offline leases.
  - Falls back to `DefaultPurchaseVerifier` when backend is unconfigured.
- **Manager & State Gating Hardening (`lib/premium/premium_entitlement_manager.dart`, `lib/premium/in_app_purchase_provider.dart`):**
  - Hydrates JWS lease from secure storage cache.
  - Tracks in-session monotonic elapsed time via `Stopwatch`.
  - Detects clock rollback and flags `requiresReverification`.
  - Enforces online re-verification on reboot if lease validity cannot be established safely.
  - Preserves device-wide entitlement across session profile changes.
  - App-resume and initialization trigger reconciliation if lease is expired or requires re-verification.
  - Guaranteed non-destructive: revocation never touches or deletes user notes, folders, tasks, or attachments.

---

## Version

BUG-001 (Phase 1B Security Remediation)

---

## Date

2026-10-24

---

## Author

Anti Gravity (Pair Programming Assistant)

---

## Type

- Security
- Bug Fix
- Architecture

---

## Summary

Remediated verified audit findings from the BUG-001 Phase 1B Independent Security & Integration Audit. Fixed WebCrypto RSA algorithm identifier for Google Play service account authentication, restricted revocation to authentic authoritative 403 payloads, enforced strict fail-closed behavior for unconfigured backends in release builds, and enforced the exact 7-day maximum signed lease duration with temporal consistency checks.

---

## Detailed Changes

### Finding 1: WebCrypto RSA Algorithm Typo Fixed (`backend/src/google-play.ts`)
- Corrected algorithm identifier from `RSASSA-PKKCS1-v1_5` to standard `RSASSA-PKCS1-v1_5` with SHA-256 in `getGoogleAccessToken`.
- Added test in `backend/test/backend_test.ts` verifying real WebCrypto RSA keypair import, signing, verification, and explicit rejection of the typo.

### Finding 2: Authoritative Revocation Gating (`lib/premium/remote_purchase_verifier.dart`)
- Updated HTTP 403 handling to only invalidate entitlements if the JSON body explicitly confirms authoritative revocation (`status == 'REVOKED'` and `reason == 'GOOGLE_PLAY_CANCELLED'`).
- Generic HTTP 403 responses, WAF blocks, HTML error pages, and unexpected error payloads are treated as non-authoritative errors and will never revoke active entitlements.
- Added comprehensive unit tests in `test/premium/remote_purchase_verifier_test.dart`.

### Finding 3: Fail-Closed Unconfigured Backend (`lib/premium/remote_purchase_verifier.dart`, `lib/premium/premium_entitlement_manager.dart`)
- Enforced `_requireLease = true` unconditionally in `kReleaseMode` within `PremiumEntitlementManager`.
- Isolated legacy client-only verification fallback: in release mode, fallback is strictly forbidden; if the backend is unconfigured, verification fails closed and returns `null`.
- Confirmed non-destructive operation: neither verification rejection nor revocation deletes or modifies user notes, folders, tasks, or attachments.

### Finding 4: Enforce 7-Day Maximum Signed Lease Lifetime (`lib/premium/jws_lease_verifier.dart`)
- Validated that `(exp - iat) <= 604800` (exact 7 days) and that `exp > iat`, `nbf <= exp`, and `iat, nbf, exp > 0`.
- Added boundary tests in `test/premium/jws_lease_verifier_test.dart` for valid 7-day leases, 1-second overlong leases, 10-year overlong leases, reversed temporal claims, and clock skew boundaries.

---

## Verification & Testing Results

- **Backend Tests:** 21/21 passed (`npx -y tsx --test backend/test/*.ts`, duration: 337ms).
- **Flutter Premium Tests:** 155/155 passed (`flutter test test/premium/`, duration: 15s).
- **Static Analysis:** 0 errors, 0 warnings (`dart analyze lib/premium/ test/premium/`).
- **Git & Working Tree Integrity:** Confirmed 0 unrelated files modified, 0 production keys provisioned, 0 commits, 0 pushes.

---

## Version

BUG-001 (Revocation Contract Tightening)

---

## Date

2026-10-24

---

## Author

Anti Gravity (Pair Programming Assistant)

---

## Type

- Security
- Contract Hardening
- Quality Assurance

---

## Summary

Narrowly tightened client-side authoritative revocation in `RemotePurchaseVerifier` (`lib/premium/remote_purchase_verifier.dart`). A response is now recognized as authoritative revocation if and only if both `status == 'REVOKED'` and `reason == 'GOOGLE_PLAY_CANCELLED'`. Missing, null, mismatched, or unexpected reasons are strictly rejected and do not invalidate an active entitlement.

---

## Detailed Changes

### Client Revocation Check (`lib/premium/remote_purchase_verifier.dart`)
- Tightened HTTP 403 evaluation: `status == 'REVOKED' && reason == 'GOOGLE_PLAY_CANCELLED'`.
- Eliminated acceptance of `reason == null` or missing `reason`.

### Regression Test Suite (`test/premium/remote_purchase_verifier_test.dart`)
- Added test 5b: HTTP 403 with `status: 'REVOKED'` and missing `reason` does not revoke active entitlement.
- Added test 5c: HTTP 403 with `status: 'REVOKED'` and `reason: null` does not revoke active entitlement.
- Added test 5d: HTTP 403 with `status: 'REVOKED'` and `reason: 'UNEXPECTED_REASON'` does not revoke active entitlement.
- Verified test 2: HTTP 403 with exact authoritative payload (`status: 'REVOKED'`, `reason: 'GOOGLE_PLAY_CANCELLED'`) successfully revokes entitlement.

---

## Verification & Testing Results

- **Verifier Tests:** 12/12 passed (`flutter test test/premium/remote_purchase_verifier_test.dart`).
- **Premium Test Suite:** 158/158 passed (`flutter test test/premium/`).
- **Static Analysis:** 0 issues found (`dart analyze lib/premium/ test/premium/`).

---

## Version

BUG-001 (Production Readiness & Build Execution)

---

## Date

2026-10-24

---

## Author

Anti Gravity (Pair Programming Assistant)

---

## Type

- Operations
- Build & Verification
- Security
- Quality Assurance

---

## Summary

Completed local production readiness verification, backend build validation, TypeScript strict type-checking, and test suite execution. Confirmed full readiness of Cloudflare Worker bundle, D1 schema migration, and Flutter cryptographic lease and revocation client. Formally documented remaining external infrastructure and live physical-device approval gates.

---

## Detailed Changes

### Backend Build & Tooling (`backend/`)
- Configured production npm scripts: `test` (`tsx --test test/*.ts`), `typecheck` (`tsc --noEmit`), and `build` (`wrangler deploy --dry-run`).
- Resolved TypeScript type annotations for WebCrypto `exportKey` ArrayBuffer assertions in `backend/test/backend_test.ts` and `PurchaseStatus` domain typing in `backend/test/d1_workflow_test.ts`.
- Verified 0 TypeScript compilation errors under `strict: true`.
- Executed `wrangler deploy --dry-run` successfully (34.86 KiB bundle, gzip: 7.38 KiB).
- Added `backend/.gitignore` to protect repository index from node dependencies and build artifacts.

### Infrastructure Specification & Gate Readiness
- Formalized deployment requirements for production Cloudflare Worker routing, D1 database provisioning, and Google Cloud Service Account permissions.
- Verified that all secrets (`GOOGLE_SERVICE_ACCOUNT_JSON`, `TOKEN_ENCRYPTION_KEYRING`, `SIGNING_KEYRING`) remain strictly excluded from source control.

---

## Verification & Testing Results

- **Backend Unit & D1 Tests:** 21/21 passed (`npm test` in `backend/`, duration: 412ms).
- **Backend Type-Checking:** 0 errors (`npm run typecheck` in `backend/`).
- **Backend Worker Bundle:** Passed dry-run compilation (`npm run build` in `backend/`).
- **Flutter Premium Tests:** 158/158 passed (`flutter test test/premium/`, duration: 16s).
- **Static Analysis:** 0 issues found (`dart analyze lib/premium/ test/premium/`).
- **Git Working Tree Integrity:** Confirmed 0 unrelated files modified, 0 commits, 0 pushes.

---

## Version

BUG-001 (Deployment Audit Remediation)

---

## Date

2026-10-24

---

## Author

Anti Gravity (Pair Programming Assistant)

---

## Type

- Security
- Quality Assurance
- Architecture
- Documentation

---

## Summary

Remediated all five findings from the BUG-001 Deployment Runbook Security Audit. Added defensive gitignore patterns for secrets across root and backend, implemented D1 restore anti-resurrection and fail-closed regression tests, hardened key generation with length assertions, added zero-exposure keypair verification, documented Cloudflare multi-account preflight validation, and updated operator recovery procedures.

---

## Detailed Changes

### Security & Secret Isolation (`.gitignore`, `backend/.gitignore`)
- Added defensive patterns for `*_keyring.json`, `*service-account*.json`, `*.key`, and `.secrets/` to both root and backend `.gitignore`.
- Verified ignore coverage using `git check-ignore` and confirmed 0 tracked secret files.

### D1 Anti-Resurrection & Restore Security (`backend/test/d1_workflow_test.ts`)
- Added regression test suite verifying that restored stale `ACTIVE` rows in D1 are immediately transitioned to `REVOKED` and tokens purged upon upstream cancellation detection.
- Proved that committed `REVOKED` tombstones cannot be resurrected via CAS updates due to SQL `WHERE status != 'REVOKED'` constraints.
- Verified that CAS version conflicts and Google Play failures fail closed without issuing leases.

### Operator Runbook Hardening (`docs/release/BUG-001_DEPLOYMENT_RUNBOOK.md`)
- Updated key generation script with strict length assertions (32 bytes raw public key, 48 bytes PKCS#8 DER private key, 32 bytes AES-256 key) and restrictive permissions (`0o600`).
- Added zero-exposure key verification script matching local keyrings to pinned Flutter public keys.
- Clarified `/health` endpoint as an edge liveness probe only, mandating live purchase validation for functional verification.
- Documented explicit Cloudflare Account ID preflight validation and D1 database restore security invariants.

---

## Verification & Testing Results

- **Backend Tests:** 24/24 passed (`npm test` in `backend/`, duration: 295ms).
- **Backend Type-Checking:** 0 errors (`npm run typecheck` in `backend/`).
- **Worker Build:** Passed dry-run compilation (`npm run build` in `backend/`).
- **Flutter Premium Tests:** 158/158 passed (`flutter test test/premium/`).
- **Static Analysis:** 0 issues found (`dart analyze lib/premium/ test/premium/`).
- **Git Ignore Verification:** `git check-ignore -v` confirmed 100% ignore coverage on secret files.

---

## Version

BUG-001 (Final Pre-Production Security Remediation)

---

## Date

2026-10-24

---

## Author

Anti Gravity (Pair Programming Assistant)

---

## Type

- Security
- Integration Testing
- Secrets Hardening
- Documentation & Runbook

---

## Summary

Remediated all findings from the Independent Adversarial Security Audit. Corrected Windows secret-file protection by adding native PowerShell `icacls` DACL enforcement outside the repository, made local key-file creation atomic with exclusive writes and clean failure recovery, implemented fail-closed transport error handling in `fetchProductPurchaseV2`, strictly enforced CAS persistence validation on pre-issuance cancellation checks, clarified physical D1 snapshot restore boundaries, and added end-to-end Worker HTTP integration tests covering all critical failure and revocation paths.

---

## Detailed Changes

### Backend Worker Pipeline & Upstream Transport (`backend/src/`)
- **Transport Error Handling (`backend/src/google-play.ts`):** Wrapped upstream HTTP calls in `fetchProductPurchaseV2` and `acknowledgePurchase` in try-catch to return HTTP 502 with error details on network timeouts, aborted requests, or DNS resolution failures, ensuring fail-closed behavior without unhandled worker crashes.
- **Pre-Check Persistence Enforcement (`backend/src/index.ts`):** Added strict `commitSuccess` check to pre-issuance defense-in-depth cancellation recheck. If CAS cancellation persistence fails or encounters a conflict, the worker returns HTTP 500 (`Failed to persist cancellation state`) and strictly emits no lease.

### Worker HTTP Integration Test Suite (`backend/test/verify_purchase_integration_test.ts`)
- Added comprehensive integration test suite exercising the actual production `worker.fetch` request pipeline:
  - **Test A (D1 Persistence Failure):** Verified that a database failure/CAS mismatch when committing purchase state returns HTTP 500 and issues no lease.
  - **Test B (Upstream Transport Failure / Timeout):** Verified that an aborted Google Play request fails closed with HTTP 502 (`UPSTREAM_LOOKUP_FAILED`) and issues no lease.
  - **Test C1 (Pre-Check Cancellation Detection):** Verified that rapid cancellation detected during the pre-issuance re-check records a terminal `REVOKED` tombstone in D1, purges the encrypted token, returns HTTP 403 `{"status":"REVOKED","reason":"GOOGLE_PLAY_CANCELLED"}`, and issues no lease.
  - **Test C2 (Pre-Check Persistence Failure):** Verified that a failed cancellation write during pre-check returns HTTP 500 and prevents lease issuance.
  - **Test D (Happy Path Integration):** Verified that valid purchase transactions issue a signed 7-day compact Ed25519 JWS lease.

### Windows Secret Protection & Atomic Key Generation (`docs/release/BUG-001_DEPLOYMENT_RUNBOOK.md`)
- **Windows NTFS DACL Enforcement:** Documented that Node.js POSIX flags (`0o600`, `0o700`) only toggle DOS readonly attributes on Windows NTFS without establishing DACLs. Added PowerShell instructions using `icacls` to store keys outside the repository (`$HOME\.quicknotes_secrets`), strip inheritance, remove unprivileged groups, grant exclusive Full Control to the operator account, and verify the resulting ACL.
- **Atomic Keyfile Generation:** Hardened key generation scripts to generate keys in memory first, validate lengths, check for existing destination files, write to unique temporary files with exclusive creation (`flag: 'wx'`), atomically rename to final paths, and clean up temporary artifacts on failure.
- **D1 Snapshot Restore Architectural Boundaries:** Explicitly documented the distinction between application-level invariants (SQL `status != 'REVOKED'`), live upstream gating (no lease solely from D1), and physical SQLite snapshot restores (which physically overwrite table data and delete tombstones). Reaffirmed fail-closed behavior (HTTP 502) during post-restore upstream outages.

---

## Verification & Testing Results

- **Backend Integration & Unit Tests:** 29/29 passed (`npm test` in `backend/`, duration: 815ms, with Test D fully verifying Ed25519 cryptographic signatures, claims, and negative tampered/corrupted assertions).
- **Backend Type-Checking:** 0 errors (`npm run typecheck` in `backend/`).
- **Worker Build:** Dry-run compilation passed cleanly (`npm run build` in `backend/`).
- **Flutter Premium Tests:** 158/158 passed (`flutter test test/premium/`).
- **Static Analysis:** 0 issues found (`dart analyze lib/premium/ test/premium/`).

---

## Version

BUG-001 (Final Pre-Staging Verification Gate Closure)

---

## Date

2026-10-26

---

## Author

Anti Gravity (Pair Programming Assistant)

---

## Type

- Security Hardening
- Integration Testing
- Documentation & Runbook Correction

---

## Summary

Closed the two outstanding verification findings from the Final Pre-Staging Verification Gate:
1. **Windows NTFS ACL Sequence Correction (`docs/release/BUG-001_DEPLOYMENT_RUNBOOK.md`):** Replaced defective `/inheritance:d` + selective remove with empirical `/inheritance:r` to atomically strip all inherited ACEs (including machine-specific groups like `MSI\CodexSandboxUsers`), added robust operator identity resolution via `[System.Security.Principal.WindowsIdentity]::GetCurrent().Name`, added container/object inheritance (`(OI)(CI)F`), and added automated assertion verification.
2. **Cryptographic JWS & Claims Verification in Test D (`backend/test/verify_purchase_integration_test.ts`):** Strengthened the Worker HTTP happy-path integration test to cryptographically verify the signed Ed25519 lease against the test public key, strictly asserted all required claims (`iss`, `aud`, `sub`, `entitlement`, `product_id`, `status`, `iat`, `nbf`, `exp`, `jti`), verified exact 604,800-second (7-day) lease duration, and added negative test assertions proving tampered payloads, corrupted signatures, and malformed tokens fail verification.





