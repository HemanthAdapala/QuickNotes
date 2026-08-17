# GoogleDriveBackupService Changelog

---

## v1.9.5.2

### Date
2026-08-14

### Author
Anti Gravity

### Type
- Concrete Cloud Transport Implementation
- Google Drive REST API Integration
- Ephemeral OAuth Token Management
- Testing

---

### Architectural Purpose

Implemented Phase 1.9.5.2 Google Drive REST Transport (`GoogleDriveBackupService`), conforming to the `BackupStorageAdapter` contract. Manages user-visible `Google Drive/Quick Notes/Backups/` folder structure, multipart streaming uploads, streaming downloads to `.tmp` files with SHA-256 validation, identity isolation filtering, and bounded exponential backoff retries.

---

### Key Technical Specifications

1. **OAuth Scope & Privacy**:
   - Scope restricted to `https://www.googleapis.com/auth/drive.file` (Option A — User-Visible Folder).
   - Zero credential or OAuth token persistence (ephemeral in-memory handling only).
2. **Folder Discovery & Creation**:
   - Queries for folder `Quick Notes` -> creates if missing.
   - Queries for subfolder `Backups` -> creates if missing.
   - Prevents duplicate folder creation across upload sessions.
3. **Multipart Streaming Upload & Custom Properties**:
   - Encodes multipart body with custom `appProperties` (`backupId`, `databaseSchemaVersion`, `formatVersion`, `createdAt`, `sha256Checksum`, `noteCount`, `folderCount`, `taskCount`, `attachmentCount`, `providerUserIdHash`).
4. **Streaming Download & Checksum Verification**:
   - Downloads remote `.qnb` to `destinationLocalFile.path + '.tmp'`.
   - Verifies SHA-256 byte digest against metadata `sha256Checksum` before atomic rename.
5. **Identity Isolation Filtering**:
   - `listBackups()` queries remote files and filters out any backups belonging to other user identities (`providerUserIdHash`).
6. **Bounded Retries & Silent Auth Refresh**:
   - Bounded retries for 5xx/429 status codes (1s, 2s, 4s backoff).
   - Single silent token refresh on 401 Unauthorized using `GoogleSignIn.signInSilently()`.

---

### Files Created & Modified

- **Files Created**:
  - `lib/services/backup/google_drive_backup_service.dart` (Concrete Google Drive REST transport implementing `BackupStorageAdapter`)
  - `test/services/google_drive_backup_service_test.dart` (Unit test suite for transport and models)
  - `Agents/skills/ChangeLogs Folder/GoogleDriveBackupService_Changelog.md`
- **Files Modified**:
  - `lib/services/authentication_service.dart` (Added `https://www.googleapis.com/auth/drive.file` to GoogleSignIn scopes)

---

### Testing & Analysis Results

- **Dedicated Google Drive Transport Test Suite**: Passed 4/4 tests cleanly.
- **Full Workspace Test Suite**: Passed 247/247 tests (100% GREEN).
- **Static Analysis (`flutter analyze`)**: Zero errors in Phase 1.9.5.2 code.
- **Dependencies Added**: 0.
- **Database Schema**: Version 18 (Unchanged).
