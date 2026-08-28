import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
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
import 'backup_format.dart';
import 'backup_integrity.dart';
import 'backup_manifest.dart';
import 'backup_result.dart';
import 'backup_serializer.dart';
import 'backup_validator.dart';
import 'zip_encoder.dart';

/// BackupEngine — Orchestrator for local .qnb backup creation and packaging.
///
/// Workflow:
/// 1. Resolves active user session identity.
/// 2. Reads active user folders, notes, and tasks via repositories.
/// 3. Normalizes rich text content & collects local image attachments.
/// 4. Fails cleanly if any referenced local attachment is missing.
/// 5. Computes cryptographic SHA-256 digests and constructs BackupManifest.
/// 6. Encodes container via pure-Dart ZipEncoder.
/// 7. Writes to temporary file `.qnb.tmp`.
/// 8. Executes independent post-creation BackupValidator check.
/// 9. Atomically renames temporary file to final `.qnb` backup file.
class BackupEngine {
  final FoldersRepository _foldersRepo;
  final NotesRepository _notesRepo;
  final TasksRepository _tasksRepo;
  final SessionManager _sessionManager;
  final DatabaseService _dbService;

  BackupEngine({
    FoldersRepository? foldersRepo,
    NotesRepository? notesRepo,
    TasksRepository? tasksRepo,
    SessionManager? sessionManager,
    DatabaseService? dbService,
  })  : _foldersRepo = foldersRepo ?? SqliteFoldersRepository(),
        _notesRepo = notesRepo ?? SqliteNotesRepository(),
        _tasksRepo = tasksRepo ?? SqliteTasksRepository(),
        _sessionManager = sessionManager ?? SessionManager(),
        _dbService = dbService ?? DatabaseService.instance;

  /// Creates a complete, portable .qnb local backup file for the currently active user.
  Future<BackupResult> createBackup({
    Directory? customBackupDir,
    Directory? customDocumentsDir,
  }) async {
    final activeUserId = _sessionManager.activeUserId;
    if (activeUserId == null || activeUserId.isEmpty) {
      return BackupResult.failure(
          error: 'No active canonical user session exists for backup');
    }

    try {
      // ── 1. Resolve Identity Metadata ─────────────────────────────────────
      var provider = 'offline';
      var providerUserIdHash = BackupIntegrity.sha256String(activeUserId);
      String? userEmail;

      final db = await _dbService.database;

      final identityMaps = await db.query(
        'user_identities',
        where: 'userId = ?',
        whereArgs: [activeUserId],
        limit: 1,
      );

      if (identityMaps.isNotEmpty) {
        final idMap = identityMaps.first;
        provider = idMap['provider'] as String? ?? 'google';
        final pUserId = idMap['providerUserId'] as String? ?? '';
        providerUserIdHash = BackupIntegrity.sha256String(pUserId);
        userEmail = idMap['email'] as String?;
      }

      final profileMaps = await db.query(
        'user_profiles',
        where: 'userId = ?',
        whereArgs: [activeUserId],
        limit: 1,
      );

      if (profileMaps.isNotEmpty) {
        userEmail ??= profileMaps.first['email'] as String?;
      }

      // ── 2. Collect Entities (Filtered by activeUserId) ───────────────────
      final activeFolders = await _foldersRepo.getFolders();
      final trashFolders = await _foldersRepo.getTrashFolders();
      final allFolders = <Folder>[...activeFolders, ...trashFolders];

      final activeNotes = await _notesRepo.getNotes();
      final trashNotes = await _notesRepo.getTrashNotes();
      final allNotes = <Note>[...activeNotes, ...trashNotes];

      final activeTasks = await _tasksRepo.getTasks();
      final trashTasks = await _tasksRepo.getTrashTasks();
      final allTasks = <TaskItem>[...activeTasks, ...trashTasks];

      // ── 3. Collect Local Attachment Files ───────────────────────────────
      final docsDir =
          customDocumentsDir ?? await getApplicationDocumentsDirectory();
      final attachmentEntries = <String, List<int>>{};
      final missingAttachments = <String>[];

      for (final note in allNotes) {
        final referencedFilenames = <String>{};

        // Parse inline markdown image URIs
        final reg = RegExp(r'!\[(.*?)\]\((.*?)\)');
        for (final match in reg.allMatches(note.content)) {
          final uri = match.group(2) ?? '';
          if (uri.isNotEmpty) {
            final norm = BackupSerializer.normalizeAttachmentUri(uri);
            if (norm.startsWith(BackupFormat.attachmentSchemePrefix)) {
              referencedFilenames.add(
                  norm.substring(BackupFormat.attachmentSchemePrefix.length));
            }
          }
        }

        // Parse note.attachments metadata maps
        for (final attMap in note.attachments) {
          final pathStr =
              attMap['path'] as String? ?? attMap['url'] as String? ?? '';
          if (pathStr.isNotEmpty) {
            final norm = BackupSerializer.normalizeAttachmentUri(pathStr);
            if (norm.startsWith(BackupFormat.attachmentSchemePrefix)) {
              referencedFilenames.add(
                  norm.substring(BackupFormat.attachmentSchemePrefix.length));
            }
          }
        }

        for (final filename in referencedFilenames) {
          final archivePath = '${BackupFormat.attachmentsDirectory}/$filename';
          if (attachmentEntries.containsKey(archivePath)) continue;

          // Search local filesystem in documents directory and images subfolder
          final candidatePaths = [
            p.join(docsDir.path, filename),
            p.join(docsDir.path, 'images', filename),
            p.join(docsDir.path, 'attachments', filename),
          ];

          File? foundFile;
          for (final candidate in candidatePaths) {
            final file = File(candidate);
            if (file.existsSync()) {
              foundFile = file;
              break;
            }
          }

          if (foundFile != null) {
            attachmentEntries[archivePath] = foundFile.readAsBytesSync();
          } else {
            missingAttachments.add(filename);
          }
        }
      }

      // Missing Attachment Policy: Fail cleanly if any attachment is missing
      if (missingAttachments.isNotEmpty) {
        return BackupResult.failure(
          error:
              'Backup failed due to missing local attachment asset(s): ${missingAttachments.join(", ")}',
        );
      }

      // ── 4. Serialize Entities & Compute SHA-256 Checksums ───────────────
      final foldersJson = BackupSerializer.serializeFolders(allFolders);
      final notesJson = BackupSerializer.serializeNotes(allNotes);
      final tasksJson = BackupSerializer.serializeTasks(allTasks);

      final foldersBytes = utf8.encode(foldersJson);
      final notesBytes = utf8.encode(notesJson);
      final tasksBytes = utf8.encode(tasksJson);

      final checksumsMap = <String, String>{
        BackupFormat.foldersDataFileName:
            BackupIntegrity.sha256Bytes(foldersBytes),
        BackupFormat.notesDataFileName: BackupIntegrity.sha256Bytes(notesBytes),
        BackupFormat.tasksDataFileName: BackupIntegrity.sha256Bytes(tasksBytes),
      };

      for (final attPath in attachmentEntries.keys) {
        checksumsMap[attPath] =
            BackupIntegrity.sha256Bytes(attachmentEntries[attPath]!);
      }

      final backupId = 'bkp_${const Uuid().v4()}';
      final nowUtc = DateTime.now().toUtc();

      final manifestObj = BackupManifest(
        formatVersion: BackupFormat.formatVersion,
        backupId: backupId,
        createdAt: nowUtc,
        databaseSchemaVersion: BackupFormat.databaseSchemaVersion,
        appVersion: BackupFormat.defaultAppVersion,
        identity: BackupManifestIdentity(
          provider: provider,
          providerUserIdHash: providerUserIdHash,
          email: userEmail,
        ),
        contents: BackupContentCounts(
          folders: allFolders.length,
          notes: allNotes.length,
          tasks: allTasks.length,
          attachments: attachmentEntries.length,
        ),
        checksums: checksumsMap,
      );

      final manifestChecksum = manifestObj.computeManifestChecksum();
      checksumsMap['manifest'] = manifestChecksum;

      final finalManifest = BackupManifest(
        formatVersion: manifestObj.formatVersion,
        backupId: manifestObj.backupId,
        createdAt: manifestObj.createdAt,
        databaseSchemaVersion: manifestObj.databaseSchemaVersion,
        appVersion: manifestObj.appVersion,
        identity: manifestObj.identity,
        contents: manifestObj.contents,
        checksums: checksumsMap,
      );

      final manifestBytes = utf8.encode(finalManifest.toJsonString());

      // ── 5. Encode ZIP Container ──────────────────────────────────────────
      final zipEntries = <ZipInputEntry>[
        ZipInputEntry(
            name: BackupFormat.manifestFileName, bytes: manifestBytes),
        ZipInputEntry(
            name: BackupFormat.foldersDataFileName, bytes: foldersBytes),
        ZipInputEntry(name: BackupFormat.notesDataFileName, bytes: notesBytes),
        ZipInputEntry(name: BackupFormat.tasksDataFileName, bytes: tasksBytes),
      ];

      for (final attPath in attachmentEntries.keys) {
        zipEntries.add(
            ZipInputEntry(name: attPath, bytes: attachmentEntries[attPath]!));
      }

      final zipBytes = ZipEncoder.encode(zipEntries);

      // ── 6. Write Temporary File ──────────────────────────────────────────
      final backupDir =
          customBackupDir ?? Directory(p.join(docsDir.path, 'backups'));
      if (!backupDir.existsSync()) {
        backupDir.createSync(recursive: true);
      }

      final timestampStr = DateFormat('yyyyMMdd_HHmmss').format(nowUtc);
      final filename =
          'quick_notes_backup_$timestampStr${BackupFormat.fileExtension}';
      final tempFilePath = p.join(backupDir.path, '$filename.tmp');
      final finalFilePath = p.join(backupDir.path, filename);

      final tempFile = File(tempFilePath);
      tempFile.writeAsBytesSync(zipBytes, flush: true);

      // ── 7. Post-Creation Independent Validation ──────────────────────────
      final inputMap = <String, List<int>>{
        BackupFormat.manifestFileName: manifestBytes,
        BackupFormat.foldersDataFileName: foldersBytes,
        BackupFormat.notesDataFileName: notesBytes,
        BackupFormat.tasksDataFileName: tasksBytes,
      };
      inputMap.addAll(attachmentEntries);

      final archiveInput = BackupArchiveInput(inputMap);
      final validationResult = await BackupValidator.validate(
        archiveInput: archiveInput,
        expectedProviderUserIdHash: providerUserIdHash,
      );

      if (!validationResult.isValid) {
        if (tempFile.existsSync()) tempFile.deleteSync();
        return BackupResult.failure(
          error: 'Post-creation validation check failed',
          validationResult: validationResult,
        );
      }

      // ── 8. Atomic Placement ──────────────────────────────────────────────
      tempFile.renameSync(finalFilePath);
      final finalFile = File(finalFilePath);

      return BackupResult.success(
        filePath: finalFilePath,
        backupId: backupId,
        createdAt: nowUtc,
        fileSize: finalFile.lengthSync(),
        noteCount: allNotes.length,
        folderCount: allFolders.length,
        taskCount: allTasks.length,
        attachmentCount: attachmentEntries.length,
        validationResult: validationResult,
      );
    } catch (e) {
      return BackupResult.failure(error: 'BackupEngine error: ${e.toString()}');
    }
  }
}
