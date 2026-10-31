import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/models/note.dart';

void main() {
  group('Note Model Unit Tests', () {
    final now = DateTime.now();

    test('1. Default constructor initializes expected defaults', () {
      final note = Note(
        id: 'note_default_1',
        title: 'Default Note Title',
        content: 'Default Note Content',
        tags: const [],
        attachments: const [],
        createdAt: now,
        updatedAt: now,
        colorValue: 0,
      );

      expect(note.id, equals('note_default_1'));
      expect(note.userId, isNull);
      expect(note.title, equals('Default Note Title'));
      expect(note.content, equals('Default Note Content'));
      expect(note.isPinned, isFalse);
      expect(note.isFavorite, isFalse);
      expect(note.isArchived, isFalse);
      expect(note.category, equals('Uncategorized'));
      expect(note.noteType, equals('text'));
      expect(note.isLocked, isFalse);
      expect(note.reminderTime, isNull);
      expect(note.isDeleted, isFalse);
      expect(note.deletedAt, isNull);
      expect(note.trashedByFolderId, isNull);
      expect(note.folderId, isNull);
      expect(note.isHabit, isFalse);
      expect(note.habitRecurrence, equals('none'));
      expect(note.habitStreak, equals(0));
      expect(note.habitLastCompleted, isNull);
      expect(note.paperGuideType, equals('lines_extra_tight'));
      expect(note.paperGuideVisible, isFalse);
      expect(note.paperGuideHeight, equals(1.05));
      expect(note.paperGuideOpacity, equals(0.15));
      expect(note.paperGuideColor, equals(0));
      expect(note.version, equals(1));
      expect(note.lastSyncedVersion, equals(0));
      expect(note.previewText, equals('Default Note Content'));
    });

    group('2. Preview Text Generation (_generatePreviewText)', () {
      test('Strips markdown styling, HTML tags, and transforms list prefixes',
          () {
        const rawContent = '''
# Heading 1
**Bold text** and *italic text* with ==highlight== and ~~strikethrough~~
- [ ] Task 1 unchecked
- [x] Task 2 completed
- Bullet item 1
1. First item
2. Second item
---
![Alt image](https://example.com/image.png)
<p>HTML paragraph</p>
[Click here](https://flutter.dev)
''';

        final note = Note(
          id: 'note_preview_1',
          title: 'Markdown Note',
          content: rawContent,
          tags: const [],
          attachments: const [],
          createdAt: now,
          updatedAt: now,
          colorValue: 0,
        );

        final preview = note.previewText;
        expect(preview.contains('# Heading 1'), isTrue);
        expect(preview.contains('**'), isFalse);
        expect(preview.contains('~~'), isFalse);
        expect(preview.contains('=='), isFalse);
        expect(preview.contains('☐ Task 1 unchecked'), isTrue);
        expect(preview.contains('☑ Task 2 completed'), isTrue);
        expect(preview.contains('• Bullet item 1'), isTrue);
        expect(preview.contains('1. First item'), isTrue);
        expect(preview.contains('2. Second item'), isTrue);
        expect(preview.contains('---'), isFalse);
        expect(preview.contains('https://example.com/image.png'), isFalse);
        expect(preview.contains('<p>'), isFalse);
        expect(preview.contains('Click here'), isTrue);
      });

      test('Handles emojis, Unicode, and special characters cleanly', () {
        const unicodeContent = '''
🚀 Exploring Mars & Beyond
- [ ] 🌟 Check telescope alignment
- [x] 🛰️ Calibrate antenna (433MHz ± 5kHz)
日本語テキストと絵文字 🌸
''';

        final note = Note(
          id: 'note_unicode_1',
          title: 'Unicode Note',
          content: unicodeContent,
          tags: const ['unicode', 'space'],
          attachments: const [],
          createdAt: now,
          updatedAt: now,
          colorValue: 0,
        );

        expect(note.previewText.contains('🚀 Exploring Mars & Beyond'), isTrue);
        expect(note.previewText.contains('☐ 🌟 Check telescope alignment'),
            isTrue);
        expect(note.previewText.contains('☑ 🛰️ Calibrate antenna'), isTrue);
        expect(note.previewText.contains('日本語テキストと絵文字 🌸'), isTrue);
      });

      test('Handles 10,000+ character high-volume content without crashing',
          () {
        final buffer = StringBuffer();
        for (int i = 0; i < 500; i++) {
          buffer.writeln(
              '- [ ] Checklist task number $i with detailed note text');
        }
        final hugeContent = buffer.toString();
        expect(hugeContent.length, greaterThan(10000));

        final note = Note(
          id: 'note_huge_1',
          title: 'Huge Note',
          content: hugeContent,
          tags: const [],
          attachments: const [],
          createdAt: now,
          updatedAt: now,
          colorValue: 0,
        );

        expect(note.previewText.isNotEmpty, isTrue);
        expect(note.previewText.contains('☐ Checklist task number 0'), isTrue);
        expect(
            note.previewText.contains('☐ Checklist task number 499'), isTrue);
      });
    });

    group('3. Serialization and Deserialization (toMap / fromMap)', () {
      test('Serializes to map and deserializes back with 100% field parity',
          () {
        final reminder = DateTime.now().add(const Duration(days: 1));
        final deletedAt = DateTime.now().subtract(const Duration(minutes: 5));
        final habitCompleted =
            DateTime.now().subtract(const Duration(hours: 2));

        final original = Note(
          id: 'full_note_123',
          userId: 'usr_canonical_999',
          title: 'Comprehensive Serialization Note',
          content: 'Content with detailed markdown lines',
          isPinned: true,
          isFavorite: true,
          isArchived: true,
          category: 'Work',
          noteType: 'checklist',
          tags: const ['architecture', 'qa', 'sqlite'],
          attachments: const [
            {'type': 'image', 'path': 'attachment://doc.png', 'size': 1024}
          ],
          isLocked: true,
          reminderTime: reminder,
          createdAt: now,
          updatedAt: now,
          colorValue: 4,
          isDeleted: true,
          deletedAt: deletedAt,
          trashedByFolderId: 'folder_parent_1',
          folderId: 'folder_work_2',
          isHabit: true,
          habitRecurrence: 'daily',
          habitStreak: 12,
          habitLastCompleted: habitCompleted,
          paperGuideType: 'grid_medium',
          paperGuideVisible: true,
          paperGuideHeight: 1.25,
          paperGuideOpacity: 0.35,
          paperGuideColor: 0xFF223344,
          version: 7,
          lastSyncedVersion: 5,
        );

        final map = original.toMap();
        final restored = Note.fromMap(map);

        expect(restored.id, equals(original.id));
        expect(restored.userId, equals(original.userId));
        expect(restored.title, equals(original.title));
        expect(restored.content, equals(original.content));
        expect(restored.isPinned, equals(original.isPinned));
        expect(restored.isFavorite, equals(original.isFavorite));
        expect(restored.isArchived, equals(original.isArchived));
        expect(restored.category, equals(original.category));
        expect(restored.noteType, equals(original.noteType));
        expect(restored.tags, equals(original.tags));
        expect(restored.attachments.length, equals(1));
        expect(
            restored.attachments.first['path'], equals('attachment://doc.png'));
        expect(restored.isLocked, equals(original.isLocked));
        expect(restored.reminderTime?.toIso8601String(),
            equals(reminder.toIso8601String()));
        expect(restored.createdAt.toIso8601String(),
            equals(now.toIso8601String()));
        expect(restored.updatedAt.toIso8601String(),
            equals(now.toIso8601String()));
        expect(restored.colorValue, equals(4));
        expect(restored.isDeleted, isTrue);
        expect(restored.deletedAt?.toIso8601String(),
            equals(deletedAt.toIso8601String()));
        expect(restored.trashedByFolderId, equals('folder_parent_1'));
        expect(restored.folderId, equals('folder_work_2'));
        expect(restored.isHabit, isTrue);
        expect(restored.habitRecurrence, equals('daily'));
        expect(restored.habitStreak, equals(12));
        expect(restored.habitLastCompleted?.toIso8601String(),
            equals(habitCompleted.toIso8601String()));
        expect(restored.paperGuideType, equals('grid_medium'));
        expect(restored.paperGuideVisible, isTrue);
        expect(restored.paperGuideHeight, equals(1.25));
        expect(restored.paperGuideOpacity, equals(0.35));
        expect(restored.paperGuideColor, equals(0xFF223344));
        expect(restored.version, equals(7));
        expect(restored.lastSyncedVersion, equals(5));
      });

      test(
          'fromMap gracefully recovers from corrupt JSON strings and missing nullable keys',
          () {
        final corruptMap = <String, dynamic>{
          'id': 'corrupt_note_1',
          'title': 'Corrupt Test',
          'content': null, // Missing content
          'tags': 'NOT_A_JSON_STRING', // Corrupted tags
          'attachments': '{invalid_json: 123}', // Corrupted attachments
          'paperSettings': 'NOT_JSON', // Corrupted paper settings
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
          'colorValue': 0,
          'isPinned': 0,
        };

        final note = Note.fromMap(corruptMap);

        expect(note.id, equals('corrupt_note_1'));
        expect(note.title, equals('Corrupt Test'));
        expect(note.content, equals('')); // Gracefully recovered empty string
        expect(note.tags, isEmpty); // Gracefully recovered empty list
        expect(note.attachments, isEmpty); // Gracefully recovered empty list
        expect(note.paperGuideType,
            equals('lines_extra_tight')); // Default preserved
        expect(note.paperGuideVisible, isFalse);
        expect(note.paperGuideHeight, equals(1.05));
        expect(note.isFavorite, isFalse);
        expect(note.isArchived, isFalse);
        expect(note.category, equals('Uncategorized'));
      });
    });

    group('4. copyWith Immature and Field Clearance Behavior', () {
      test('copyWith preserves unchanged values and applies overrides', () {
        final base = Note(
          id: 'base_id',
          title: 'Base Title',
          content: 'Base Content',
          tags: const ['tag1'],
          attachments: const [],
          createdAt: now,
          updatedAt: now,
          colorValue: 1,
          folderId: 'folder_abc',
          reminderTime: now.add(const Duration(hours: 1)),
        );

        final updated = base.copyWith(
          title: 'Updated Title',
          colorValue: 5,
        );

        expect(updated.id, equals('base_id'));
        expect(updated.title, equals('Updated Title'));
        expect(updated.content, equals('Base Content'));
        expect(updated.colorValue, equals(5));
        expect(updated.folderId, equals('folder_abc'));
        expect(updated.reminderTime, isNotNull);
      });

      test('copyWith properly clears nullable fields with clear flags', () {
        final base = Note(
          id: 'clear_test_id',
          title: 'Clear Test',
          content: 'Content',
          tags: const [],
          attachments: const [],
          createdAt: now,
          updatedAt: now,
          colorValue: 0,
          folderId: 'folder_to_clear',
          reminderTime: now.add(const Duration(days: 2)),
          deletedAt: now,
          trashedByFolderId: 'trashed_folder',
          habitLastCompleted: now,
        );

        final cleared = base.copyWith(
          clearFolder: true,
          clearReminder: true,
          clearDeletedAt: true,
          clearTrashedByFolderId: true,
          clearHabitLastCompleted: true,
        );

        expect(cleared.folderId, isNull);
        expect(cleared.reminderTime, isNull);
        expect(cleared.deletedAt, isNull);
        expect(cleared.trashedByFolderId, isNull);
        expect(cleared.habitLastCompleted, isNull);
      });
    });

    group('5. Serialization Robustness & Defect Verification', () {
      test(
          'DEFECT-002 REMEDIATED: Note.fromMap safely deserializes null and missing isPinned and colorValue without TypeError',
          () {
        // Case A: null isPinned and null colorValue
        final mapWithNulls = <String, dynamic>{
          'id': 'defect_002_note',
          'title': 'Defect 002 Title',
          'content': 'Defect 002 Content',
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
          'colorValue': null,
          'isPinned': null,
        };

        final noteA = Note.fromMap(mapWithNulls);
        expect(noteA.isPinned, isFalse);
        expect(noteA.colorValue, equals(0));

        // Case B: missing keys for isPinned and colorValue
        final mapMissingKeys = <String, dynamic>{
          'id': 'missing_keys_note',
          'title': 'Missing Keys Title',
          'content': 'Missing Keys Content',
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        };

        final noteB = Note.fromMap(mapMissingKeys);
        expect(noteB.isPinned, isFalse);
        expect(noteB.colorValue, equals(0));

        // Case C: valid values are preserved accurately
        final mapWithValidValues = <String, dynamic>{
          'id': 'valid_note',
          'title': 'Valid Title',
          'content': 'Valid Content',
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
          'colorValue': 5,
          'isPinned': 1,
        };

        final noteC = Note.fromMap(mapWithValidValues);
        expect(noteC.isPinned, isTrue);
        expect(noteC.colorValue, equals(5));

        // Case D: boolean isPinned supported cleanly
        final mapWithBoolPinned = <String, dynamic>{
          'id': 'bool_note',
          'title': 'Bool Title',
          'content': 'Bool Content',
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
          'isPinned': true,
        };

        final noteD = Note.fromMap(mapWithBoolPinned);
        expect(noteD.isPinned, isTrue);
      });
    });
  });
}
