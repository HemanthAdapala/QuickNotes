import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/models/single_note_snapshot.dart';

void main() {
  group('SingleNoteSnapshot Phase W6 Comprehensive Semantic Tests', () {
    test('A. Normal Text: plain paragraph remains plain text with empty marker', () {
      const continuousParagraph =
          'This is a very long sentence that keeps going continuously until it reaches the right edge of the editor.';

      final note = Note(
        id: 'note-text',
        title: 'Simple Note',
        content: continuousParagraph,
        tags: [],
        attachments: [],
        createdAt: DateTime(2026, 6, 1, 2, 0),
        updatedAt: DateTime(2026, 6, 1, 2, 0),
        colorValue: 0xFFFFFFFF,
        noteType: 'text',
      );

      final snapshot = SingleNoteSnapshot.fromNote(note);
      expect(snapshot.id, 'note-text');
      expect(snapshot.title, 'Simple Note');
      expect(snapshot.noteType, 'text');
      expect(snapshot.semanticLines.length, 1);
      expect(snapshot.semanticLines[0].type, 'text');
      expect(snapshot.semanticLines[0].marker, '');
      expect(snapshot.semanticLines[0].text, continuousParagraph);
      expect(snapshot.semanticLines[0].displayLine, continuousParagraph);
    });

    test('B. Bulleted List: preserves bullet marker and text', () {
      const bulletContent = '• Buy groceries\n• Edit video\n• Export project';

      final note = Note(
        id: 'note-bullet',
        title: 'Tasks',
        content: bulletContent,
        tags: [],
        attachments: [],
        createdAt: DateTime(2026, 6, 1, 2, 0),
        updatedAt: DateTime(2026, 6, 1, 2, 0),
        colorValue: 0xFFFFFFFF,
        noteType: 'text',
      );

      final snapshot = SingleNoteSnapshot.fromNote(note);
      expect(snapshot.semanticLines.length, 3);
      for (var i = 0; i < 3; i++) {
        expect(snapshot.semanticLines[i].type, 'bullet');
        expect(snapshot.semanticLines[i].marker, '•');
      }
      expect(snapshot.semanticLines[0].text, 'Buy groceries');
      expect(snapshot.semanticLines[1].text, 'Edit video');
      expect(snapshot.semanticLines[2].text, 'Export project');
    });

    test('C. Numbered List: preserves numbering sequence in marker', () {
      const numberedContent = '1. Buy groceries\n2. Edit video\n3. Export project';

      final note = Note(
        id: 'note-num',
        title: 'Workflow',
        content: numberedContent,
        tags: [],
        attachments: [],
        createdAt: DateTime(2026, 6, 1, 2, 0),
        updatedAt: DateTime(2026, 6, 1, 2, 0),
        colorValue: 0xFFFFFFFF,
        noteType: 'text',
      );

      final snapshot = SingleNoteSnapshot.fromNote(note);
      expect(snapshot.semanticLines.length, 3);
      expect(snapshot.semanticLines[0].type, 'numbered');
      expect(snapshot.semanticLines[0].marker, '1.');
      expect(snapshot.semanticLines[0].text, 'Buy groceries');

      expect(snapshot.semanticLines[1].type, 'numbered');
      expect(snapshot.semanticLines[1].marker, '2.');
      expect(snapshot.semanticLines[1].text, 'Edit video');

      expect(snapshot.semanticLines[2].type, 'numbered');
      expect(snapshot.semanticLines[2].marker, '3.');
      expect(snapshot.semanticLines[2].text, 'Export project');
    });

    test('D. Checklist: preserves checked and unchecked states with markers', () {
      const checklistContent = '- [ ] Buy groceries\n- [x] Edit video\n- [ ] Export project';

      final note = Note(
        id: 'note-check',
        title: 'Checklist',
        content: checklistContent,
        tags: [],
        attachments: [],
        createdAt: DateTime(2026, 6, 1, 2, 0),
        updatedAt: DateTime(2026, 6, 1, 2, 0),
        colorValue: 0xFFFFFFFF,
        noteType: 'checklist',
      );

      final snapshot = SingleNoteSnapshot.fromNote(note);
      expect(snapshot.semanticLines.length, 3);

      expect(snapshot.semanticLines[0].type, 'checklist');
      expect(snapshot.semanticLines[0].marker, '☐');
      expect(snapshot.semanticLines[0].text, 'Buy groceries');
      expect(snapshot.semanticLines[0].checked, isFalse);

      expect(snapshot.semanticLines[1].type, 'checklist');
      expect(snapshot.semanticLines[1].marker, '☑');
      expect(snapshot.semanticLines[1].text, 'Edit video');
      expect(snapshot.semanticLines[1].checked, isTrue);

      expect(snapshot.semanticLines[2].type, 'checklist');
      expect(snapshot.semanticLines[2].marker, '☐');
      expect(snapshot.semanticLines[2].text, 'Export project');
      expect(snapshot.semanticLines[2].checked, isFalse);
    });

    test('E. Mixed Content: preserves exact semantic structure across all block types', () {
      const mixedContent = '''
Today's plan

• Record video
• Edit video

Things to remember:

1. Export at 4K
2. Upload final version

- [ ] Backup project
- [x] Send invoice
''';

      final note = Note(
        id: 'note-mixed',
        title: 'Production Plan',
        content: mixedContent,
        tags: [],
        attachments: [],
        createdAt: DateTime(2026, 6, 1, 2, 0),
        updatedAt: DateTime(2026, 6, 1, 2, 0),
        colorValue: 0xFFFFFFFF,
        noteType: 'text',
      );

      final snapshot = SingleNoteSnapshot.fromNote(note);
      expect(snapshot.semanticLines.length, 8);

      // Line 1: Normal text
      expect(snapshot.semanticLines[0].type, 'text');
      expect(snapshot.semanticLines[0].marker, '');
      expect(snapshot.semanticLines[0].text, "Today's plan");

      // Line 2: Bullet
      expect(snapshot.semanticLines[1].type, 'bullet');
      expect(snapshot.semanticLines[1].marker, '•');
      expect(snapshot.semanticLines[1].text, 'Record video');

      // Line 3: Bullet
      expect(snapshot.semanticLines[2].type, 'bullet');
      expect(snapshot.semanticLines[2].marker, '•');
      expect(snapshot.semanticLines[2].text, 'Edit video');

      // Line 4: Normal text
      expect(snapshot.semanticLines[3].type, 'text');
      expect(snapshot.semanticLines[3].marker, '');
      expect(snapshot.semanticLines[3].text, 'Things to remember:');

      // Line 5: Numbered
      expect(snapshot.semanticLines[4].type, 'numbered');
      expect(snapshot.semanticLines[4].marker, '1.');
      expect(snapshot.semanticLines[4].text, 'Export at 4K');

      // Line 6: Numbered
      expect(snapshot.semanticLines[5].type, 'numbered');
      expect(snapshot.semanticLines[5].marker, '2.');
      expect(snapshot.semanticLines[5].text, 'Upload final version');

      // Line 7: Checklist unchecked
      expect(snapshot.semanticLines[6].type, 'checklist');
      expect(snapshot.semanticLines[6].marker, '☐');
      expect(snapshot.semanticLines[6].text, 'Backup project');
      expect(snapshot.semanticLines[6].checked, isFalse);

      // Line 8: Checklist checked
      expect(snapshot.semanticLines[7].type, 'checklist');
      expect(snapshot.semanticLines[7].marker, '☑');
      expect(snapshot.semanticLines[7].text, 'Send invoice');
      expect(snapshot.semanticLines[7].checked, isTrue);
    });

    test('F. Serialization: roundtrips semantic lines cleanly', () {
      final note = Note(
        id: 'note-serialize',
        title: 'Serialization Test',
        content: '• Item 1\n1. Item 2\n- [ ] Item 3',
        tags: [],
        attachments: [],
        createdAt: DateTime(2026, 6, 1, 2, 0),
        updatedAt: DateTime(2026, 6, 1, 2, 0),
        colorValue: 0xFFFFFFFF,
        noteType: 'text',
      );

      final snapshot = SingleNoteSnapshot.fromNote(note);
      final json = snapshot.toJson();
      final deserialized = SingleNoteSnapshot.fromJson(json);

      expect(deserialized.id, snapshot.id);
      expect(deserialized.title, snapshot.title);
      expect(deserialized.semanticLines.length, 3);

      expect(deserialized.semanticLines[0].type, 'bullet');
      expect(deserialized.semanticLines[0].marker, '•');
      expect(deserialized.semanticLines[0].text, 'Item 1');

      expect(deserialized.semanticLines[1].type, 'numbered');
      expect(deserialized.semanticLines[1].marker, '1.');
      expect(deserialized.semanticLines[1].text, 'Item 2');

      expect(deserialized.semanticLines[2].type, 'checklist');
      expect(deserialized.semanticLines[2].marker, '☐');
      expect(deserialized.semanticLines[2].text, 'Item 3');
      expect(deserialized.semanticLines[2].checked, isFalse);
    });
  });
}
