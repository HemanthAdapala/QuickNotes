import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/models/folder.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/models/task_item.dart';
import 'package:quick_notes/models/task_status.dart';
import 'package:quick_notes/models/repeat_rule.dart';
import 'package:quick_notes/models/reminder_mode.dart';
import 'package:quick_notes/models/user_profile.dart';
import 'package:quick_notes/services/backup/backup_format.dart';
import 'package:quick_notes/services/backup/backup_integrity.dart';
import 'package:quick_notes/services/backup/backup_manifest.dart';
import 'package:quick_notes/services/backup/backup_serializer.dart';

void main() {
  group('Phase 1.9.1 — Backup Format & Serializer Tests', () {
    final now = DateTime.utc(2026, 8, 14, 14, 0, 0);

    test('1. BackupFormat constants and format version rules', () {
      expect(BackupFormat.formatVersion, equals(1));
      expect(BackupFormat.databaseSchemaVersion, equals(18));
      expect(BackupFormat.defaultAppVersion, equals('1.1.0+2'));
      expect(BackupFormat.isSupportedFormatVersion(1), isTrue);
      expect(BackupFormat.isSupportedFormatVersion(2), isFalse);
    });

    test('2. BackupManifest self-checksum rule is deterministic and avoids circularity', () {
      final identity = BackupManifestIdentity(
        provider: 'google',
        providerUserIdHash: BackupIntegrity.sha256String('112233445566778899'),
        email: 'alex@example.com',
      );

      final counts = BackupContentCounts(
        folders: 2,
        notes: 5,
        tasks: 3,
        attachments: 1,
      );

      final manifest = BackupManifest(
        backupId: 'bkp_test_12345',
        createdAt: now,
        identity: identity,
        contents: counts,
        checksums: {
          'data/notes.json': 'sha256_dummy_notes',
          'data/folders.json': 'sha256_dummy_folders',
          'data/tasks.json': 'sha256_dummy_tasks',
        },
      );

      final checksum1 = manifest.computeManifestChecksum();
      final checksum2 = manifest.computeManifestChecksum();

      expect(checksum1.length, equals(64));
      expect(checksum1, equals(checksum2));

      // Self-checksum rule check: altering an existing checksum changes manifest checksum
      final manifestModified = BackupManifest(
        backupId: 'bkp_test_12345',
        createdAt: now,
        identity: identity,
        contents: counts,
        checksums: {
          'data/notes.json': 'sha256_altered_notes',
          'data/folders.json': 'sha256_dummy_folders',
          'data/tasks.json': 'sha256_dummy_tasks',
        },
      );
      expect(manifestModified.computeManifestChecksum(), isNot(equals(checksum1)));
    });

    test('3. Folder serialization is deterministic and preserves folder metadata', () {
      final folderA = Folder(
        id: 'f_002',
        name: 'Personal',
        colorHex: '#FF5733',
        createdAt: now,
        version: 2,
        lastSyncedVersion: 1,
      );
      final folderB = Folder(
        id: 'f_001',
        name: 'Work',
        colorHex: '#3357FF',
        createdAt: now,
        version: 1,
      );

      // Order in list shouldn't matter; serializer sorts by ID ascending
      final json1 = BackupSerializer.serializeFolders([folderA, folderB]);
      final json2 = BackupSerializer.serializeFolders([folderB, folderA]);

      expect(json1, equals(json2));

      final deserialized = BackupSerializer.deserializeFolder(BackupSerializer.serializeFolder(folderA));
      expect(deserialized.id, equals('f_002'));
      expect(deserialized.name, equals('Personal'));
      expect(deserialized.colorHex, equals('#FF5733'));
      expect(deserialized.version, equals(2));
      expect(deserialized.lastSyncedVersion, equals(1));
    });

    test('4. Note serialization normalizes attachment paths into relative attachment:// URIs', () {
      final note = Note(
        id: 'n_100',
        title: 'Meeting Notes',
        content: 'Check out this diagram: ![Diagram](file:///var/mobile/Containers/app_flutter/images/img_99.png)',
        tags: const ['work', 'important'],
        attachments: const [
          {
            'id': 'att_1',
            'name': 'img_99.png',
            'path': '/data/user/0/com.example.quick_notes/app_flutter/images/img_99.png',
            'type': 'image',
          }
        ],
        createdAt: now,
        updatedAt: now,
        colorValue: 0xFF00FF00,
        folderId: 'f_001',
        paperGuideType: 'grid',
        paperGuideVisible: true,
      );

      final map = BackupSerializer.serializeNote(note);

      // Content markdown image URI normalized to attachment://
      expect(map['content'], contains('![Diagram](attachment://img_99.png)'));

      // Attachments list path normalized to attachment://
      final normalizedAtts = map['attachments'] as List;
      expect(normalizedAtts.first['path'], equals('attachment://img_99.png'));

      // Verify deserialization round-trip
      final deserialized = BackupSerializer.deserializeNote(map);
      expect(deserialized.id, equals('n_100'));
      expect(deserialized.title, equals('Meeting Notes'));
      expect(deserialized.folderId, equals('f_001'));
      expect(deserialized.paperGuideType, equals('grid'));
      expect(deserialized.paperGuideVisible, isTrue);
    });

    test('5. TaskItem serialization excludes system notificationId and preserves task fields', () {
      final task = TaskItem(
        id: 't_500',
        title: 'Submit Expense Report',
        description: 'Monthly receipts',
        dueDate: now.add(const Duration(days: 1)),
        priority: 'High',
        status: TaskStatus.waiting,
        notificationId: 9999, // SYSTEM DEVICE SPECIFIC NOTIFICATION ID
        reminderEnabled: true,
        reminderMode: ReminderMode.alarm,
        reminderTime: now.add(const Duration(hours: 5)),
        repeatRule: RepeatRule.weekly,
        completedDates: const ['2026-08-01', '2026-08-08'],
        createdAt: now,
        updatedAt: now,
      );

      final map = BackupSerializer.serializeTask(task);

      // Verify notificationId is EXCLUDED from backup payload!
      expect(map.containsKey('notificationId'), isFalse);
      expect(map['title'], equals('Submit Expense Report'));
      expect(map['priority'], equals('High'));
      expect(map['status'], equals('waiting'));
      expect(map['repeatRule'], equals('weekly'));

      // Deserialization assigns default notificationId 0 cleanly
      final deserialized = BackupSerializer.deserializeTask(map);
      expect(deserialized.id, equals('t_500'));
      expect(deserialized.notificationId, equals(0));
      expect(deserialized.completedDates, equals(['2026-08-01', '2026-08-08']));
    });

    test('6. UserProfile serialization excludes credentials and secure storage secrets', () {
      final profile = UserProfile(
        userId: 'usr_local_test_99',
        displayName: 'Test User',
        email: 'user@quicknotes.app',
        avatarId: 'andre',
        photoUrl: 'https://example.com/photo.jpg',
        usesGooglePhoto: false,
        profileVersion: 1,
        createdAt: DateTime.parse('2026-08-01T00:00:00Z'),
        updatedAt: DateTime.parse('2026-08-01T00:00:00Z'),
      );

      final map = BackupSerializer.serializeUserProfile(profile);

      expect(map['displayName'], equals('Test User'));
      expect(map['email'], equals('user@quicknotes.app'));
      expect(map['avatarId'], equals('andre'));
      expect(map.containsKey('password'), isFalse);
      expect(map.containsKey('accessToken'), isFalse);
      expect(map.containsKey('idToken'), isFalse);
    });

    test('7. BackupIntegrity SHA-256 calculation is accurate and deterministic', () {
      const sampleText = 'QuickNotes Backup Integrity Verification';
      final hash1 = BackupIntegrity.sha256String(sampleText);
      final hash2 = BackupIntegrity.sha256String(sampleText);

      expect(hash1.length, equals(64));
      expect(hash1, equals(hash2));

      final hashDiff = BackupIntegrity.sha256String('QuickNotes Backup Integrity Verification!');
      expect(hash1, isNot(equals(hashDiff)));
    });

    test('8. normalizeAttachmentUri preserves web URLs, data URIs, and assets without prepending attachment:// scheme', () {
      const webUrl = 'https://picsum.photos/200/400';
      const httpUrl = 'http://example.com/images/400';
      const dataUri = 'data:image/png;base64,iVBORw0KGgo=';
      const assetPath = 'assets/icons/logo.png';
      const localPath = '/data/user/0/com.example.app/app_flutter/photo.jpg';

      expect(BackupSerializer.normalizeAttachmentUri(webUrl), equals(webUrl));
      expect(BackupSerializer.normalizeAttachmentUri(httpUrl), equals(httpUrl));
      expect(BackupSerializer.normalizeAttachmentUri(dataUri), equals(dataUri));
      expect(BackupSerializer.normalizeAttachmentUri(assetPath), equals(assetPath));
      expect(BackupSerializer.normalizeAttachmentUri(localPath), equals('attachment://photo.jpg'));
    });
  });
}
