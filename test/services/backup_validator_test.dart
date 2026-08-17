import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/models/folder.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/models/task_item.dart';
import 'package:quick_notes/models/task_status.dart';
import 'package:quick_notes/services/backup/backup_format.dart';
import 'package:quick_notes/services/backup/backup_integrity.dart';
import 'package:quick_notes/services/backup/backup_manifest.dart';
import 'package:quick_notes/services/backup/backup_serializer.dart';
import 'package:quick_notes/services/backup/backup_validation_result.dart';
import 'package:quick_notes/services/backup/backup_validator.dart';

void main() {
  group('Phase 1.9.2 — Backup Validation Engine Tests', () {
    final now = DateTime.utc(2026, 8, 14, 14, 0, 0);

    BackupArchiveInput createValidArchiveInput({
      List<Folder>? folders,
      List<Note>? notes,
      List<TaskItem>? tasks,
      Map<String, List<int>>? extraFiles,
      String provider = 'google',
      String providerUserId = '112233445566778899',
      int databaseSchemaVersion = 18,
      int formatVersion = 1,
    }) {
      final validFolder = Folder(id: 'f_work', name: 'Work', createdAt: now);
      final validNote = Note(
        id: 'n_1',
        title: 'Title',
        content: 'Content with ![Image](attachment://sample.png)',
        attachments: const [
          {'id': 'att_1', 'path': 'attachment://sample.png'}
        ],
        tags: const [],
        folderId: 'f_work',
        createdAt: now,
        updatedAt: now,
        colorValue: 0xFFFFFFFF,
      );
      final validTask = TaskItem(
        id: 't_1',
        title: 'Task 1',
        dueDate: now,
        priority: 'None',
        status: TaskStatus.waiting,
        folderId: 'f_work',
        createdAt: now,
        updatedAt: now,
      );

      final fList = folders ?? [validFolder];
      final nList = notes ?? [validNote];
      final tList = tasks ?? [validTask];

      final sampleImageBytes = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

      final foldersJson = BackupSerializer.serializeFolders(fList);
      final notesJson = BackupSerializer.serializeNotes(nList);
      final tasksJson = BackupSerializer.serializeTasks(tList);

      final checksumsMap = <String, String>{
        BackupFormat.notesDataFileName: BackupIntegrity.sha256String(notesJson),
        BackupFormat.foldersDataFileName: BackupIntegrity.sha256String(foldersJson),
        BackupFormat.tasksDataFileName: BackupIntegrity.sha256String(tasksJson),
        'attachments/sample.png': BackupIntegrity.sha256Bytes(sampleImageBytes),
      };

      final manifestObj = BackupManifest(
        formatVersion: formatVersion,
        backupId: 'bkp_valid_001',
        createdAt: now,
        databaseSchemaVersion: databaseSchemaVersion,
        identity: BackupManifestIdentity(
          provider: provider,
          providerUserIdHash: BackupIntegrity.sha256String(providerUserId),
          email: 'user@example.com',
        ),
        contents: BackupContentCounts(
          folders: fList.length,
          notes: nList.length,
          tasks: tList.length,
          attachments: 1,
        ),
        checksums: checksumsMap,
      );

      final manifestSelfChecksum = manifestObj.computeManifestChecksum();
      checksumsMap['manifest'] = manifestSelfChecksum;

      final finalManifestObj = BackupManifest(
        formatVersion: formatVersion,
        backupId: manifestObj.backupId,
        createdAt: manifestObj.createdAt,
        databaseSchemaVersion: manifestObj.databaseSchemaVersion,
        identity: manifestObj.identity,
        contents: manifestObj.contents,
        checksums: checksumsMap,
      );

      final entries = <String, List<int>>{
        BackupFormat.manifestFileName: utf8.encode(finalManifestObj.toJsonString()),
        BackupFormat.foldersDataFileName: utf8.encode(foldersJson),
        BackupFormat.notesDataFileName: utf8.encode(notesJson),
        BackupFormat.tasksDataFileName: utf8.encode(tasksJson),
        'attachments/sample.png': sampleImageBytes,
      };

      if (extraFiles != null) {
        entries.addAll(extraFiles);
      }

      return BackupArchiveInput(entries);
    }

    test('1. Valid archive passes full 8-stage validation cleanly', () async {
      final input = createValidArchiveInput();
      final expectedHash = BackupIntegrity.sha256String('112233445566778899');

      final result = await BackupValidator.validate(
        archiveInput: input,
        expectedProviderUserIdHash: expectedHash,
      );

      expect(result.isValid, isTrue);
      expect(result.errors.isEmpty, isTrue);
      expect(result.formatVersion, equals(1));
      expect(result.databaseSchemaVersion, equals(18));
      expect(result.identityStatus, equals(BackupIdentityStatus.match));
      expect(result.schemaStatus, equals(BackupSchemaStatus.exactMatch));
    });

    test('2. Path traversal attempt in archive entry is rejected immediately', () async {
      final input = createValidArchiveInput(
        extraFiles: {
          '../secret.txt': utf8.encode('hacked'),
        },
      );

      final result = await BackupValidator.validate(archiveInput: input);

      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.type == BackupValidationErrorType.unsafeArchive), isTrue);
    });

    test('3. Executable file payload in archive is rejected', () async {
      final input = createValidArchiveInput(
        extraFiles: {
          'attachments/malware.exe': [0x00, 0x01, 0x02],
        },
      );

      final result = await BackupValidator.validate(archiveInput: input);

      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.type == BackupValidationErrorType.unsafeArchive), isTrue);
    });

    test('4. Missing required payload file fails validation', () async {
      final valid = createValidArchiveInput();
      valid.entries.remove(BackupFormat.notesDataFileName);

      final result = await BackupValidator.validate(archiveInput: valid);

      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.type == BackupValidationErrorType.missingRequiredFile), isTrue);
    });

    test('5. Unsupported formatVersion (> 1) fails validation', () async {
      final input = createValidArchiveInput(formatVersion: 2);

      final result = await BackupValidator.validate(archiveInput: input);

      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.type == BackupValidationErrorType.unsupportedFormatVersion), isTrue);
    });

    test('6. Unsupported database schema version (> 18) fails validation', () async {
      final input = createValidArchiveInput(databaseSchemaVersion: 99);

      final result = await BackupValidator.validate(archiveInput: input);

      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.type == BackupValidationErrorType.unsupportedSchemaVersion), isTrue);
    });

    test('7. Older database schema version (< 18) is rejected as unsupported', () async {
      final input = createValidArchiveInput(databaseSchemaVersion: 16);

      final result = await BackupValidator.validate(archiveInput: input);

      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.type == BackupValidationErrorType.unsupportedSchemaVersion), isTrue);
    });

    test('8. SHA-256 data payload corruption is detected and rejected', () async {
      final valid = createValidArchiveInput();
      // Corrupt notes JSON content bytes
      valid.entries[BackupFormat.notesDataFileName] = utf8.encode('{"corrupted": true}');

      final result = await BackupValidator.validate(archiveInput: valid);

      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.type == BackupValidationErrorType.checksumMismatch), isTrue);
    });

    test('9. Identity mismatch fails validation when expecting specific Google user', () async {
      final input = createValidArchiveInput(providerUserId: '112233445566778899');
      final wrongHash = BackupIntegrity.sha256String('998877665544332211');

      final result = await BackupValidator.validate(
        archiveInput: input,
        expectedProviderUserIdHash: wrongHash,
      );

      expect(result.isValid, isFalse);
      expect(result.identityStatus, equals(BackupIdentityStatus.mismatch));
      expect(result.errors.any((e) => e.type == BackupValidationErrorType.identityMismatch), isTrue);
    });

    test('10. Dangling attachment reference (missing image asset) fails validation', () async {
      final valid = createValidArchiveInput();
      // Remove attachment asset file
      valid.entries.remove('attachments/sample.png');

      final result = await BackupValidator.validate(archiveInput: valid);

      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.type == BackupValidationErrorType.invalidAttachmentReference), isTrue);
    });

    test('11. Dangling folder relationship fails validation', () async {
      final danglingNote = Note(
        id: 'n_orphan',
        title: 'Orphan Note',
        content: 'Content',
        tags: const [],
        attachments: const [],
        folderId: 'f_NON_EXISTENT', // References missing folder!
        createdAt: now,
        updatedAt: now,
        colorValue: 0xFFFFFFFF,
      );

      final input = createValidArchiveInput(notes: [danglingNote]);

      final result = await BackupValidator.validate(archiveInput: input);

      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.type == BackupValidationErrorType.invalidRelationship), isTrue);
    });

    test('12. Manifest content count mismatch fails validation', () async {
      final valid = createValidArchiveInput();
      final manifestJsonStr = valid.getFileString(BackupFormat.manifestFileName)!;
      final manifestMap = jsonDecode(manifestJsonStr) as Map<String, dynamic>;

      // Alter declared note count in manifest
      final contentsMap = Map<String, dynamic>.from(manifestMap['contents'] as Map);
      contentsMap['notes'] = 99; // Actual note count is 1
      manifestMap['contents'] = contentsMap;

      // Update manifest self-checksum
      final manifestObj = BackupManifest.fromMap(manifestMap);
      final checksumsMap = Map<String, String>.from(manifestObj.checksums);
      checksumsMap['manifest'] = manifestObj.computeManifestChecksum();
      final updatedManifest = BackupManifest(
        backupId: manifestObj.backupId,
        createdAt: manifestObj.createdAt,
        databaseSchemaVersion: manifestObj.databaseSchemaVersion,
        identity: manifestObj.identity,
        contents: manifestObj.contents,
        checksums: checksumsMap,
      );

      valid.entries[BackupFormat.manifestFileName] = utf8.encode(updatedManifest.toJsonString());

      final result = await BackupValidator.validate(archiveInput: valid);

      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.type == BackupValidationErrorType.contentCountMismatch), isTrue);
    });
  });
}
