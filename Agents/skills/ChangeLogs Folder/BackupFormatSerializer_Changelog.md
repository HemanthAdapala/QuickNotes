# BackupFormat & Data Serializer Changelog

---

## v1.9.1

### Date
2026-08-14

### Author
Anti Gravity

### Type
- Feature
- Data Contract
- Serialization
- Testing

---

### Architectural Purpose

Implemented Phase 1.9.1 Backup Manifest, Format V1 & Data Serializer layer. Establishes deterministic entity serialization, format versioning rules, manifest metadata models, relative attachment URI normalization, strict sensitive data exclusion, and self-checksum canonicalization.

---

### Files Created & Modified

- **Files Created**:
  - `lib/services/backup/backup_format.dart` (Format V1 constants, schema v18, app version, layout constants)
  - `lib/services/backup/backup_integrity.dart` (SHA-256 calculation & deterministic JSON canonicalizer)
  - `lib/services/backup/backup_manifest.dart` (Manifest model, identity metadata, content counts, self-checksum computation)
  - `lib/services/backup/backup_serializer.dart` (Folder, Note, TaskItem, UserProfile serializer & attachment path normalizer)
  - `test/services/backup_serializer_test.dart` (7-scenario unit test suite)
  - `Agents/skills/ChangeLogs Folder/BackupFormatSerializer_Changelog.md`

---

### Key Technical Specifications

1. **Independent Three-Tier Versioning**:
   - `formatVersion = 1`
   - `databaseSchemaVersion = 18`
   - `appVersion = "1.1.0+2"`
2. **Manifest Self-Checksum Rule**:
   - Computes SHA-256 over canonicalized JSON representation excluding the `checksums.manifest` key to eliminate circular checksum dependency.
3. **Deterministic Serialization**:
   - All maps canonicalized with keys sorted alphabetically.
   - All collection lists sorted by entity `id` ascending.
   - ISO-8601 UTC date string formatting.
4. **Relative Attachment Normalization**:
   - Converts absolute device URIs (`file:///data/.../img.png` or `C:\...\img.png`) into portable `attachment://img.png` references in markdown text (`Note.content`) and attachment metadata maps (`Note.attachments`).
5. **Strict Data Exclusions**:
   - Excludes OAuth credentials, access/refresh tokens, client secrets, FlutterSecureStorage contents, device session state, system notification IDs (`TaskItem.notificationId`), sync outbox rows (`sync_outbox`), sync cursors, search history, and transient UI states.

---

### Testing & Analysis Results

- **Phase 1.9.1 Dedicated Test Suite**: Passed 7/7 tests cleanly.
- **Full Workspace Test Suite**: Passed 214/214 tests (100% GREEN).
- **Static Analysis (`flutter analyze`)**: Zero analyzer errors in all new files.

---

### Explicit Scope Exclusions (Phase 1.9.1 Boundary)

- **No `.qnb` or ZIP Archive Creation on Disk**: Reserved for Phase 1.9.3 Backup Engine.
- **No Database Schema Migrations**: Database remains Schema Version 18.
- **No Restore Logic**: Reserved for Phase 1.9.4 Restore Engine.
- **No Google Drive Integration**: Reserved for Phase 1.9.5 Cloud Transport.
- **No UI Modifications**: Reserved for Phase 1.9.6.
