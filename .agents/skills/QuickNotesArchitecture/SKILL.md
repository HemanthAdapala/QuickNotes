---
name: QuickNotes Architecture
description: Authoritative architectural guidelines and invariants for the QuickNotes project. Use whenever creating or modifying state management, database schema/migrations, repository methods, navigation flows, backup/restore logic, session handling, premium feature gates, synchronization boundaries, editor architecture, or native widget adapters in QuickNotes.
risk: safe
source: local
---

# QuickNotes Architectural Guidelines & Invariants

This skill is the authoritative architectural governance guide for QuickNotes. When implementation details differ, the active source code is the ground truth. Always extend rather than rewrite established systems.

---

## 1. Core Architectural Principles & Change Policy

- **Authoritative Baseline:** QuickNotes is a local-first Flutter application using Provider, SQLite repositories, imperative Navigator 1.0, and a custom Single Document Editor.
- **No Unilateral Migrations:** Never replace or migrate established architectures (e.g., Provider → Riverpod/Bloc, Navigator → go_router, custom editor → flutter_quill/super_editor, SQLite → alternative ORMs) without explicit user authorization. Architectural decisions must not be changed merely for novelty or file complexity.

---

## 2. State Management (Provider & ChangeNotifier)

- **Root Composition:** All global state lives in `MultiProvider` in `lib/main.dart`.
- **Established Responsibilities:**
  - `NotesProvider`: Notes state, active folder/tag filtering, search results, note CRUD dispatches.
  - `TasksProvider`: Task state, status/recurrence toggles, filtering, delegates to `TaskEngine`.
  - `SettingsProvider`: Reactive `ThemeMode`, haptics toggles, and user preferences.
  - `PremiumEntitlementManager`: Authoritative entitlement state (cached in secure storage).
- **Access Patterns:** Use `context.read<T>()` / `listen: false` inside event callbacks. Use `context.watch<T>()`, `context.select(...)`, or `Consumer<T>` with strict rebuild boundaries in UI trees. Do not create parallel state managers.

---

## 3. Data Access, Repositories & User Isolation

- **RULE:** UI widgets and providers must **NEVER** execute raw SQLite queries or access `DatabaseService.instance.database` directly.
- **Repository Boundary:** All persistent queries and mutations must route through established repositories (`NotesRepository`, `FoldersRepository`, `TasksRepository`, `OutboxRepository`).
- **User Ownership Isolation:** Every user-scoped database query and mutation **must** resolve and enforce `SessionManager().activeUserId`. If unauthenticated, throw `OwnershipException`.

---

## 4. Database Schema & Migration Invariants

- **Current Version:** SQLite schema version **18** in `lib/services/database_service.dart`.
- **Migration Protocol:**
  - Never modify `_onCreate` alone for existing table changes.
  - Increment the database version constant.
  - Add sequential, idempotent upgrade statements inside `DatabaseService._onUpgrade`.
  - Update entity models (`toMap`/`fromMap`, `toJson`/`fromJson`) and `BackupSerializer`.
  - Consider sync outbox impacts for newly added persistent columns.

---

## 5. Outbox & Local Mutation Tracking

- **Atomic Local Mutations:** Standard local CRUD operations must atomically execute:
  `entity mutation + entity version increment + sync_outbox record` inside an SQLite transaction.
- **Restore / Sync Suppression:** During `.qnb` restore operations (`RestoreEngine`) or remote pull syncing, outbox generation is explicitly suppressed. Do not generate outbox mutations during restore.

---

## 6. Navigation & Routing (Navigator 1.0)

- **Routing Model:** Imperative navigation using Flutter's native Navigator.
- **Page Transitions:** Standard transitions use `buildPageRoute<T>(Widget page)` (wrapping `QuickNotesPageRoute`), which enforces `QuickNotesMotion` Apple-style curves (`340ms` forward / `260ms` reverse) and respects `disableAnimations`.
- **DO NOT:** Introduce `go_router`, `auto_route`, or `MaterialApp.router` unless explicitly instructed.

---

## 7. Backup & Restore Contract (.qnb)

- **Container Format:** Custom `.qnb` ZIP archive requiring `manifest.json`, deterministic sorted JSON, normalized `attachment://filename` URIs, and SHA-256 integrity verification.
- **Data Exclusion Boundary:** Strictly **NEVER** serialize runtime secrets into backups:
  - Exclude: OAuth tokens, refresh tokens, passwords, vault keys, premium entitlement caches, `notificationId` (reset to 0 on restore), and `sync_outbox` rows.
- **Restore Safety Pipeline (`RestoreEngine`):**
  1. Untrusted `.qnb` validated via `BackupValidator` before mutation.
  2. Identity isolation enforced (rejects mismatched authenticated accounts).
  3. Pre-restore safety snapshot captured to allow non-recursive rollback on failure.
  4. Multi-table replace runs inside a single transaction with zero outbox events generated.

---

## 8. Authentication & Session Management

- **Storage Separation:**
  - `SharedPreferences`: Non-sensitive launch flags (`has_completed_onboarding`, `session_type`, `active_user_id`).
  - `FlutterSecureStorage`: Sensitive secrets (`auth_access_token`, `auth_id_token`, entitlement cache).
- **Session Authority:** `SessionManager` is the single source of truth for session state (`offline` or `google`).
- **Offline-First:** QuickNotes must remain fully functional offline without network or Google authentication.

---

## 9. Cloud Sync & Google Drive Boundary

- **Drive Integration:** Cloud backup uses `BackupStorageAdapter` via `GoogleDriveBackupService` with least-privilege `drive.file` scope.
- **Network Transport:** Uses `dart:io` `HttpClient` with streaming upload/download. Do not introduce `package:http`.
- **Delta Sync:** Preserve `SyncEngine`, `PullSyncEngine`, `SyncConflictResolver`, and `RemoteChangeApplier`. Do not build parallel synchronization engines.

---

## 10. Premium & Entitlement Architecture

- **Authoritative State:** Managed by `PremiumEntitlementManager` and exposed via `ProxyProvider` as `FeatureAccess`.
- **Checking Access:** Query `context.read<FeatureAccess>().canAccess(PremiumFeature.featureName)`.
- **DO NOT:** Inspect billing state in UI, create ad-hoc `isPremium` flags, store entitlements in SQLite user tables, or serialize entitlements into `.qnb` backups.

---

## 11. Single Document Editor & Native Widgets

- **Editor Policy:** `NoteEditorScreen` and `RichTextController` are foundational: **EXTEND, DO NOT REWRITE**. Do not replace with third-party editor packages. Reuse established in-editor search, auto-scroll, paper guides, and drag overlay subsystems.
- **Widget Platform Privacy:** `WidgetDataAdapter` publishes snapshots for iOS App Groups (`group.com.quicknotes.app`) and Android widgets. Must unconditionally exclude locked vault notes (`isLocked`) and soft-deleted notes/tasks.

---

## 12. Non-Goals & Skill Boundaries

This skill governs architectural invariants only. Do **NOT** duplicate:
- **Liquid Glass details:** Governed exclusively by `QuickNotesLiquidGlass` (layer stack, `TactileButton`, `BottomBarGlassSurface`, spring physics, S0 drop shadows).
- **UI sheet/layout templates:** Governed exclusively by `Quick Notes UI Consistency` (White Rounded Sheet, `showBlurredBottomSheet`, header bars, typography).
- **Generic Flutter tutorials:** Consult official Flutter/Dart skills or Flutter documentation.
