import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../models/folder.dart';
import '../../models/note.dart';
import '../../models/task_item.dart';
import '../../repositories/folders_repository.dart';
import '../../repositories/notes_repository.dart';
import '../../repositories/tasks_repository.dart';
import '../../repositories/user_identity_repository.dart';
import '../database_service.dart';
import '../session_manager.dart';
import 'backup_engine.dart';
import 'backup_format.dart';
import 'backup_integrity.dart';
import 'backup_manifest.dart';
import 'backup_serializer.dart';
import 'backup_validation_result.dart';
import 'backup_validator.dart';
import 'restore_result.dart';
import 'zip_decoder.dart';

/// RestoreEngine — Hardened orchestrator for multi-resource atomic restore operations.
///
/// Multi-Resource Safety Pipeline: PREPARE -> COMMIT -> VERIFY -> FINALIZE
///
/// Invariants:
/// 1. UNTRUSTED INPUT: Incoming .qnb file validated via BackupValidator before any mutation.
/// 2. STRICT SCHEMA POLICY: Only databaseSchemaVersion == 18 supported. Older/newer rejected.
/// 3. IDENTITY ISOLATION: Restoring across different authenticated identities is strictly BLOCKED.
/// 4. PRE-RESTORE SAFETY SNAPSHOT: Full local .qnb safety snapshot captured before commit phase.
/// 5. ATTACHMENT STAGING & ROLLBACK: Attachments staged first; previous attachments preserved in rollback workspace.
/// 6. SQLITE TRANSACTION: Multi-table replace executed inside database transaction with ZERO sync_outbox events.
/// 7. INTERNAL NON-RECURSIVE ROLLBACK: Explicit _rollbackRestore helper prevents recursive restore loops.
class RestoreEngine {
  final DatabaseService _dbService;
  final SessionManager _sessionManager;
  final BackupEngine _backupEngine;

  RestoreEngine({
    DatabaseService? dbService,
    SessionManager? sessionManager,
    BackupEngine? backupEngine,
  })  : _dbService = dbService ?? DatabaseService.instance,
        _sessionManager = sessionManager ?? SessionManager(),
        _backupEngine = backupEngine ?? BackupEngine(
          dbService: dbService,
          sessionManager: sessionManager,
        );

  /// Executes a multi-resource atomic restore of a validated local .qnb backup file.
  Future<RestoreResult> restoreFromBackup({
    required String backupFilePath,
    Directory? customDocumentsDir,
    bool forceOfflineOverride = false,
  }) async {
    final activeUserId = _sessionManager.activeUserId;
    if (activeUserId == null || activeUserId.isEmpty) {
      return RestoreResult.failure(
        error: const RestoreError(
          type: RestoreErrorType.identityMismatch,
          message: 'No active canonical user session exists for restore',
        ),
      );
    }

    final backupFile = File(backupFilePath);
    if (!backupFile.existsSync()) {
      return RestoreResult.failure(
        error: RestoreError(
          type: RestoreErrorType.invalidBackup,
          message: 'Specified backup file does not exist on disk',
          target: backupFilePath,
        ),
      );
    }

    Directory? tempWorkspace;
    Directory? attachmentRollbackWorkspace;
    String? safetySnapshotPath;
    String? previousSyncCursor;

    try {
      // ── STAGE 1: PREPARE & VALIDATE (Touchless Gate) ────────────────────
      final zipBytes = backupFile.readAsBytesSync();
      final archiveInput = BackupArchiveInput.fromZipBytes(zipBytes);

      String? expectedProviderUserIdHash = BackupIntegrity.sha256String(activeUserId);
      final db = await _dbService.database;

      final identityMaps = await db.query(
        'user_identities',
        where: 'userId = ?',
        whereArgs: [activeUserId],
        limit: 1,
      );

      if (identityMaps.isNotEmpty) {
        final pUserId = identityMaps.first['providerUserId'] as String? ?? '';
        expectedProviderUserIdHash = BackupIntegrity.sha256String(pUserId);
      }

      // Gate 1: BackupValidator Check (Strict Schema v18 & Format v1 Check)
      final validationResult = await BackupValidator.validate(
        archiveInput: archiveInput,
        expectedProviderUserIdHash: expectedProviderUserIdHash,
      );

      if (!validationResult.isValid) {
        return RestoreResult.failure(
          error: RestoreError(
            type: RestoreErrorType.validationFailed,
            message: 'Backup file failed pre-restore validation: ${validationResult.errors.first.message}',
            target: validationResult.errors.first.targetPath,
          ),
          validationResult: validationResult,
        );
      }

      // Gate 2: Identity Isolation Guard
      if (validationResult.identityStatus == BackupIdentityStatus.mismatch && !forceOfflineOverride) {
        return RestoreResult.failure(
          error: const RestoreError(
            type: RestoreErrorType.identityMismatch,
            message: 'Identity isolation guard blocked restore: Backup identity does not match current authenticated user',
          ),
          validationResult: validationResult,
        );
      }

      // Gate 3: Create Isolated Restore Workspace & Stage JSON Payloads
      final docsDir = customDocumentsDir ?? await getApplicationDocumentsDirectory();
      tempWorkspace = Directory(p.join(docsDir.path, 'restore_workspace_${const Uuid().v4()}'));
      tempWorkspace.createSync(recursive: true);

      final manifest = validationResult.manifest!;
      final foldersJson = archiveInput.getFileString(BackupFormat.foldersDataFileName)!;
      final notesJson = archiveInput.getFileString(BackupFormat.notesDataFileName)!;
      final tasksJson = archiveInput.getFileString(BackupFormat.tasksDataFileName)!;

      final rawFoldersList = jsonDecode(foldersJson) as List;
      final rawNotesList = jsonDecode(notesJson) as List;
      final rawTasksList = jsonDecode(tasksJson) as List;

      final restoredFolders = rawFoldersList.map((e) => BackupSerializer.deserializeFolder(Map<String, dynamic>.from(e as Map))).toList();
      final restoredNotes = rawNotesList.map((e) => BackupSerializer.deserializeNote(Map<String, dynamic>.from(e as Map))).toList();
      final restoredTasks = rawTasksList.map((e) => BackupSerializer.deserializeTask(Map<String, dynamic>.from(e as Map))).toList();

      final sortedFolders = _topologicalSortFolders(restoredFolders);

      // Gate 4: Create Pre-Restore Safety Snapshot
      final snapshotResult = await _backupEngine.createBackup(
        customDocumentsDir: docsDir,
        customBackupDir: Directory(p.join(docsDir.path, 'backups')),
      );

      if (!snapshotResult.success) {
        _cleanupDirectory(tempWorkspace);
        return RestoreResult.failure(
          error: RestoreError(
            type: RestoreErrorType.safetySnapshotFailed,
            message: 'Pre-restore safety snapshot creation failed: ${snapshotResult.error}',
          ),
          validationResult: validationResult,
        );
      }
      safetySnapshotPath = snapshotResult.filePath;

      // Stage Original Attachment Files into Rollback Location
      attachmentRollbackWorkspace = Directory(p.join(docsDir.path, 'attachments_backup_${const Uuid().v4()}'));
      attachmentRollbackWorkspace.createSync(recursive: true);
      _preserveCurrentAttachments(docsDir: docsDir, rollbackDir: attachmentRollbackWorkspace);

      // ── STAGE 2: STAGE NEW ATTACHMENTS (Before SQLite Commit) ───────────
      final attachmentFiles = archiveInput.entries.keys
          .where((k) => k.startsWith('${BackupFormat.attachmentsDirectory}/') && k.length > BackupFormat.attachmentsDirectory.length + 1)
          .toList();

      try {
        for (final attPath in attachmentFiles) {
          final filename = attPath.substring(BackupFormat.attachmentsDirectory.length + 1);
          final bytes = archiveInput.getFileBytes(attPath)!;

          final targetCandidates = [
            File(p.join(docsDir.path, filename)),
            File(p.join(docsDir.path, 'images', filename)),
          ];

          for (final target in targetCandidates) {
            if (!target.parent.existsSync()) {
              target.parent.createSync(recursive: true);
            }
            target.writeAsBytesSync(bytes, flush: true);
          }
        }
      } catch (attError) {
        _restorePreservedAttachments(docsDir: docsDir, rollbackDir: attachmentRollbackWorkspace);
        _cleanupDirectory(tempWorkspace);
        _cleanupDirectory(attachmentRollbackWorkspace);

        return RestoreResult.failure(
          error: RestoreError(
            type: RestoreErrorType.attachmentRestoreFailed,
            message: 'Attachment file staging failed: ${attError.toString()}',
          ),
          validationResult: validationResult,
          safetySnapshotPath: safetySnapshotPath,
        );
      }

      // ── STAGE 3: COMMIT SQLITE TRANSACTION ──────────────────────────────
      // Capture current sync cursor for potential rollback
      try {
        final prefs = await SharedPreferences.getInstance();
        previousSyncCursor = prefs.getString('sync_cursor_$activeUserId');
      } catch (_) {}

      try {
        await db.transaction((txn) async {
          // Scoped purge of active user's existing records
          await txn.delete('tasks', where: 'userId = ?', whereArgs: [activeUserId]);
          await txn.delete('notes', where: 'userId = ?', whereArgs: [activeUserId]);
          await txn.delete('folders', where: 'userId = ?', whereArgs: [activeUserId]);

          // Insert Restored Folders (Parent-first)
          for (final folder in sortedFolders) {
            final map = folder.toMap();
            map['userId'] = activeUserId;
            await txn.insert('folders', map, conflictAlgorithm: ConflictAlgorithm.replace);
          }

          // Insert Restored Notes
          for (final note in restoredNotes) {
            final map = note.toMap();
            map['userId'] = activeUserId;
            await txn.insert('notes', map, conflictAlgorithm: ConflictAlgorithm.replace);
          }

          // Insert Restored Tasks
          for (final task in restoredTasks) {
            final map = task.toMap();
            map['userId'] = activeUserId;
            await txn.insert('tasks', map, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        });
      } catch (dbError) {
        // SQLite automatically rolled back its transaction. Now rollback attachments & cursor
        _restorePreservedAttachments(docsDir: docsDir, rollbackDir: attachmentRollbackWorkspace);
        _cleanupDirectory(tempWorkspace);
        _cleanupDirectory(attachmentRollbackWorkspace);

        return RestoreResult.failure(
          error: RestoreError(
            type: RestoreErrorType.databaseRestoreFailed,
            message: 'SQLite database transaction failed: ${dbError.toString()}',
          ),
          validationResult: validationResult,
          safetySnapshotPath: safetySnapshotPath,
        );
      }

      // Reset Sync Cursor on Commit Success
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('sync_cursor_$activeUserId');
      } catch (_) {}

      // ── STAGE 4: POST-COMMIT VERIFICATION ───────────────────────────────
      final postFolders = await db.query('folders', where: 'userId = ?', whereArgs: [activeUserId]);
      final postNotes = await db.query('notes', where: 'userId = ?', whereArgs: [activeUserId]);
      final postTasks = await db.query('tasks', where: 'userId = ?', whereArgs: [activeUserId]);

      if (postFolders.length != restoredFolders.length ||
          postNotes.length != restoredNotes.length ||
          postTasks.length != restoredTasks.length) {

        // Verification Failed: Execute explicit non-recursive internal rollback!
        await _rollbackRestore(
          db: db,
          activeUserId: activeUserId,
          safetySnapshotPath: safetySnapshotPath!,
          docsDir: docsDir,
          rollbackDir: attachmentRollbackWorkspace,
          previousSyncCursor: previousSyncCursor,
        );

        _cleanupDirectory(tempWorkspace);
        _cleanupDirectory(attachmentRollbackWorkspace);

        return RestoreResult.failure(
          error: const RestoreError(
            type: RestoreErrorType.verificationFailed,
            message: 'Post-restore verification count check failed; database and attachments rolled back to safety snapshot',
          ),
          validationResult: validationResult,
          safetySnapshotPath: safetySnapshotPath,
        );
      }

      // ── STAGE 5: FINALIZE ────────────────────────────────────────────────
      _cleanupDirectory(tempWorkspace);
      _cleanupDirectory(attachmentRollbackWorkspace);

      return RestoreResult.success(
        backupId: manifest.backupId,
        restoredAt: DateTime.now().toUtc(),
        folderCount: restoredFolders.length,
        noteCount: restoredNotes.length,
        taskCount: restoredTasks.length,
        attachmentCount: attachmentFiles.length,
        identityStatus: validationResult.identityStatus,
        validationResult: validationResult,
        safetySnapshotPath: safetySnapshotPath ?? '',
      );
    } catch (e) {
      if (attachmentRollbackWorkspace != null && customDocumentsDir != null) {
        _restorePreservedAttachments(docsDir: customDocumentsDir, rollbackDir: attachmentRollbackWorkspace);
      }
      _cleanupDirectory(tempWorkspace);
      _cleanupDirectory(attachmentRollbackWorkspace);

      return RestoreResult.failure(
        error: RestoreError(
          type: RestoreErrorType.databaseRestoreFailed,
          message: 'RestoreEngine execution error: ${e.toString()}',
        ),
        safetySnapshotPath: safetySnapshotPath,
      );
    }
  }

  /// Internal explicit non-recursive rollback helper. Re-establishes pre-restore safety snapshot state.
  static Future<void> _rollbackRestore({
    required Database db,
    required String activeUserId,
    required String safetySnapshotPath,
    required Directory docsDir,
    required Directory rollbackDir,
    required String? previousSyncCursor,
  }) async {
    // 1. Restore Attachment Files from Rollback Directory
    _restorePreservedAttachments(docsDir: docsDir, rollbackDir: rollbackDir);

    // 2. Restore SQLite Records from Safety Snapshot Zip File
    final snapshotFile = File(safetySnapshotPath);
    if (snapshotFile.existsSync()) {
      try {
        final zipBytes = snapshotFile.readAsBytesSync();
        final input = BackupArchiveInput.fromZipBytes(zipBytes);

        final fJson = input.getFileString(BackupFormat.foldersDataFileName)!;
        final nJson = input.getFileString(BackupFormat.notesDataFileName)!;
        final tJson = input.getFileString(BackupFormat.tasksDataFileName)!;

        final snapFolders = (jsonDecode(fJson) as List).map((e) => BackupSerializer.deserializeFolder(Map<String, dynamic>.from(e as Map))).toList();
        final snapNotes = (jsonDecode(nJson) as List).map((e) => BackupSerializer.deserializeNote(Map<String, dynamic>.from(e as Map))).toList();
        final snapTasks = (jsonDecode(tJson) as List).map((e) => BackupSerializer.deserializeTask(Map<String, dynamic>.from(e as Map))).toList();

        final sortedFolders = _topologicalSortFolders(snapFolders);

        await db.transaction((txn) async {
          await txn.delete('tasks', where: 'userId = ?', whereArgs: [activeUserId]);
          await txn.delete('notes', where: 'userId = ?', whereArgs: [activeUserId]);
          await txn.delete('folders', where: 'userId = ?', whereArgs: [activeUserId]);

          for (final f in sortedFolders) {
            final map = f.toMap();
            map['userId'] = activeUserId;
            await txn.insert('folders', map, conflictAlgorithm: ConflictAlgorithm.replace);
          }
          for (final n in snapNotes) {
            final map = n.toMap();
            map['userId'] = activeUserId;
            await txn.insert('notes', map, conflictAlgorithm: ConflictAlgorithm.replace);
          }
          for (final t in snapTasks) {
            final map = t.toMap();
            map['userId'] = activeUserId;
            await txn.insert('tasks', map, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        });
      } catch (_) {}
    }

    // 3. Restore Previous Sync Cursor
    try {
      final prefs = await SharedPreferences.getInstance();
      if (previousSyncCursor != null) {
        await prefs.setString('sync_cursor_$activeUserId', previousSyncCursor);
      }
    } catch (_) {}
  }

  static void _preserveCurrentAttachments({
    required Directory docsDir,
    required Directory rollbackDir,
  }) {
    final imagesDir = Directory(p.join(docsDir.path, 'images'));
    final sources = <File>[];

    if (imagesDir.existsSync()) {
      sources.addAll(imagesDir.listSync().whereType<File>());
    }
    if (docsDir.existsSync()) {
      sources.addAll(docsDir.listSync().whereType<File>().where((f) => p.extension(f.path).isNotEmpty && !f.path.endsWith('.db')));
    }

    for (final file in sources) {
      try {
        final filename = p.basename(file.path);
        file.copySync(p.join(rollbackDir.path, filename));
      } catch (_) {}
    }
  }

  static void _restorePreservedAttachments({
    required Directory docsDir,
    required Directory rollbackDir,
  }) {
    if (!rollbackDir.existsSync()) return;

    final preservedFiles = rollbackDir.listSync().whereType<File>();
    for (final file in preservedFiles) {
      try {
        final filename = p.basename(file.path);
        final targetImages = File(p.join(docsDir.path, 'images', filename));
        final targetDocs = File(p.join(docsDir.path, filename));

        if (!targetImages.parent.existsSync()) {
          targetImages.parent.createSync(recursive: true);
        }
        file.copySync(targetImages.path);
        file.copySync(targetDocs.path);
      } catch (_) {}
    }
  }

  static List<Folder> _topologicalSortFolders(List<Folder> folders) {
    final result = <Folder>[];
    final addedIds = <String>{};
    final map = {for (final f in folders) f.id: f};

    void visit(Folder f) {
      if (addedIds.contains(f.id)) return;
      final parentId = f.parentId;
      if (parentId != null && parentId.isNotEmpty && map.containsKey(parentId)) {
        visit(map[parentId]!);
      }
      addedIds.add(f.id);
      result.add(f);
    }

    for (final f in folders) {
      visit(f);
    }
    return result;
  }

  static void _cleanupDirectory(Directory? dir) {
    if (dir != null && dir.existsSync()) {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }
}
