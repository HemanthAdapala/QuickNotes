# NotesRepository Changelog

---

## v1.5.0

### Date
2026-08-14

### Author
Anti Gravity

### Type
- Feature
- Refactor
- Architecture
- Testing

---

### Summary

Refactored `NotesRepository` (`lib/repositories/notes_repository.dart`) and `NotesProvider` (`lib/providers/notes_provider.dart`) to implement Phase 1.5 Data Mutation & Repository Consistency. Eliminated 100% of direct `DatabaseService` bypasses inside `NotesProvider` and views, expanded the `NotesRepository` contract to handle all note and habit mutations, enforced active user ownership checks, and guaranteed `updatedAt: DateTime.now()` timestamp updates on every mutation.

---

### Detailed Changes

- **Repository Contract Expansion**:
  - Expanded `NotesRepository` interface and `SqliteNotesRepository` implementation to include `getNoteById`, `queryNotesSummaryPaged`, `queryHabits`, `searchNotes`, `togglePin`, `toggleFavorite`, `toggleArchive`.
- **Database Bypass Elimination**:
  - Removed direct `_dbService` access from `NotesProvider` and `ExportImportScreen`. Routed all persistence through `NotesRepository`.
- **Active User Ownership Resolution**:
  - Added `_resolveActiveUserId()` checks on all read/write paths in `SqliteNotesRepository`.
- **Timestamp Mutation Consistency**:
  - Enforced `updatedAt: DateTime.now()` on every user mutation (`togglePin`, `toggleFavorite`, `toggleArchive`, `updateNote`, `trashNote`, `restoreNote`, `toggleHabitCompletion`).
- **Phase 1.4 Tombstone Semantics**:
  - Maintained `isDeleted`, `deletedAt`, `trashedByFolderId` soft-delete cascade and restoration logic.
- **Dedicated Test Suite**:
  - Created 18-scenario test suite in `test/services/data_mutation_consistency_test.dart`.

---

### Why was this change made?

Direct database calls inside providers bypassed repository security, failed to enforce user ownership, and caused inconsistent `updatedAt` timestamps. Normalizing all mutations through `NotesRepository` provides a single clean architecture for Phase 1.6 Sync Engine integration.

---

### Architecture Impact

- **Layer Boundaries**: UI / Provider -> Domain Repository -> DatabaseService -> SQLite.
- **Data Integrity**: 100% of note persistence operations pass through `NotesRepository`.

---

### Files Created

- `test/services/data_mutation_consistency_test.dart`

---

### Files Modified

- `lib/repositories/notes_repository.dart`
- `lib/providers/notes_provider.dart`
- `lib/views/screens/export_import_screen.dart`

---

### Dependencies Added

None.

---

### Breaking Changes

None. `NotesProvider` public method API contracts remain intact while internal persistence delegates to `NotesRepository`.

---

### Migration Notes

All callers pass through `NotesRepository` or `NotesProvider`. Direct `DatabaseService` query calls for notes are prohibited.

---

### Future Improvements

- Phase 1.6: Attach entity revision counters and write to `sync_outbox`.

---

### Known Issues

None.

---

### Testing Status

- **Manual Tests**: Verified note pinning, archiving, favoriting, export, and habit toggles.
- **Automated Tests**: 18/18 dedicated Phase 1.5 tests passed; 151/151 full suite passed.
- **Pending Tests**: None.
- **Known Edge Cases**: None.

---

### Final Result

`NotesRepository` serves as the authoritative, secure, timestamp-consistent gateway for all note data.
