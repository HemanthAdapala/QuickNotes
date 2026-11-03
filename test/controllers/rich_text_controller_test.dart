import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/views/widgets/rich_text_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RichTextEditingController Unit Tests', () {
    late RichTextEditingController controller;

    setUp(() {
      controller = RichTextEditingController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('1. Initial controller state is empty with canUndo and canRedo false',
        () {
      expect(controller.text, isEmpty);
      expect(controller.styledChars, isEmpty);
      expect(controller.canUndo, isFalse);
      expect(controller.canRedo, isFalse);
    });

    group('2. Markdown Parsing and Generation Round-Trips', () {
      test('Parses plain text and reconstructs markdown identically', () {
        const text = 'Hello QuickNotes Single Document Editor';
        controller.setMarkdown(text);

        expect(controller.text, equals(text));
        expect(controller.styledChars.length, equals(text.length));

        final generated =
            generateMarkdownFromStyledChars(controller.styledChars);
        expect(generated.trim(), equals(text));
      });

      test('Parses and round-trips headings (H1, H2, H3)', () {
        const markdown = '''# Heading One
## Heading Two
### Heading Three''';

        controller.setMarkdown(markdown);
        final generated =
            generateMarkdownFromStyledChars(controller.styledChars);

        expect(generated.contains('# Heading One'), isTrue);
        expect(generated.contains('## Heading Two'), isTrue);
        expect(generated.contains('### Heading Three'), isTrue);
      });

      test(
          'Parses and round-trips inline formatting (Bold, Italic, Strikethrough)',
          () {
        const markdown =
            'This is **bold**, this is *italic*, and ~~strikethrough~~.';
        controller.setMarkdown(markdown);

        final generated =
            generateMarkdownFromStyledChars(controller.styledChars);
        expect(generated.contains('**bold**'), isTrue);
        expect(generated.contains('*italic*'), isTrue);
        expect(generated.contains('~~strikethrough~~'), isTrue);
      });

      test('Parses checklists, bullet lists, and numbered lists', () {
        const markdown = '''- [ ] Open checklist task
- [x] Completed checklist task
- Standard bullet item
1. Numbered item one
2. Numbered item two''';

        controller.setMarkdown(markdown);
        final generated =
            generateMarkdownFromStyledChars(controller.styledChars);

        expect(generated.contains('- [ ] Open checklist task'), isTrue);
        expect(
            generated.contains('- [x] ~~Completed checklist task~~'), isTrue);
        expect(generated.contains('- Standard bullet item'), isTrue);
        expect(generated.contains('Numbered item one'), isTrue);
        expect(generated.contains('Numbered item two'), isTrue);
      });

      test('Preserves image syntax and divider horizontal rules', () {
        const markdown = '''![Diagram](https://example.com/diagram.png)
---
Body text after divider.''';

        controller.setMarkdown(markdown);
        final generated =
            generateMarkdownFromStyledChars(controller.styledChars);

        expect(
            generated.contains('![Diagram](https://example.com/diagram.png)'),
            isTrue);
        expect(generated.contains('---'), isTrue);
        expect(generated.contains('Body text after divider.'), isTrue);
      });

      test('Serializes and round-trips text color using <span color="...">', () {
        controller.setMarkdown('Text with color');
        controller.selection =
            const TextSelection(baseOffset: 10, extentOffset: 15);
        controller.setStyleAttribute('color',
            enable: true, value: const Color(0xFFFF3B30));

        final generated =
            generateMarkdownFromStyledChars(controller.styledChars);
        expect(
            generated, equals('Text with <span color="0xffff3b30">color</span>'));

        final roundTrip = RichTextEditingController(markdown: generated);
        expect(roundTrip.text, equals('Text with color'));
        expect(roundTrip.styledChars[0].style.color, isNull);
        for (int i = 10; i < 15; i++) {
          expect(roundTrip.styledChars[i].style.color,
              equals(const Color(0xFFFF3B30)));
        }
      });

      test('Serializes and round-trips highlight using <span highlight="...">',
          () {
        controller.setMarkdown('Highlighted phrase');
        controller.selection =
            const TextSelection(baseOffset: 12, extentOffset: 18);
        controller.setStyleAttribute('highlight',
            enable: true, value: const Color(0xFFA5D6A7));

        final generated =
            generateMarkdownFromStyledChars(controller.styledChars);
        expect(generated,
            equals('Highlighted <span highlight="0xffa5d6a7">phrase</span>'));

        final roundTrip = RichTextEditingController(markdown: generated);
        expect(roundTrip.text, equals('Highlighted phrase'));
        expect(roundTrip.styledChars[0].style.highlight, isNull);
        for (int i = 12; i < 18; i++) {
          expect(roundTrip.styledChars[i].style.highlight,
              equals(const Color(0xFFA5D6A7)));
        }
      });

      test(
          'Serializes and round-trips combined color and highlight formatting',
          () {
        controller.setMarkdown('Vibrant emphasis');
        controller.selection =
            const TextSelection(baseOffset: 8, extentOffset: 16);
        controller.setStyleAttribute('color',
            enable: true, value: const Color(0xFFFF3B30));
        controller.setStyleAttribute('highlight',
            enable: true, value: const Color(0xFFFFE082));

        final generated =
            generateMarkdownFromStyledChars(controller.styledChars);
        expect(
            generated,
            equals(
                'Vibrant <span color="0xffff3b30" highlight="0xffffe082">emphasis</span>'));

        final roundTrip = RichTextEditingController(markdown: generated);
        expect(roundTrip.text, equals('Vibrant emphasis'));
        for (int i = 8; i < 16; i++) {
          expect(roundTrip.styledChars[i].style.color,
              equals(const Color(0xFFFF3B30)));
          expect(roundTrip.styledChars[i].style.highlight,
              equals(const Color(0xFFFFE082)));
        }
      });

      test(
          'Serializes and round-trips consecutive spans with clean tag boundaries',
          () {
        const input =
            'Normal <span color="0xffff3b30">red</span> then <span highlight="0xff90caf9">blue</span>';
        controller.setMarkdown(input);
        expect(controller.text, equals('Normal red then blue'));

        final generated =
            generateMarkdownFromStyledChars(controller.styledChars);
        expect(generated, equals(input));

        final roundTrip = RichTextEditingController(markdown: generated);
        expect(roundTrip.text, equals('Normal red then blue'));
        expect(roundTrip.styledChars[7].style.color,
            equals(const Color(0xFFFF3B30)));
        expect(roundTrip.styledChars[7].style.highlight, isNull);
        expect(roundTrip.styledChars[18].style.highlight,
            equals(const Color(0xFF90CAF9)));
        expect(roundTrip.styledChars[18].style.color, isNull);
      });
    });

    group('3. In-Place Style Attribute Toggling', () {
      test('Toggling bold on selected substring sets and unsets bold attribute',
          () {
        controller.setMarkdown('Selected word formatting');
        // Select 'word' (index 9 to 13)
        controller.selection =
            const TextSelection(baseOffset: 9, extentOffset: 13);

        // Toggle bold on
        controller.toggleStyleAttribute('bold');

        for (int i = 9; i < 13; i++) {
          expect(controller.styledChars[i].style.bold, isTrue,
              reason: 'Character at $i must be bold');
        }
        // Characters before and after must remain unstyled
        expect(controller.styledChars[0].style.bold, isFalse);
        expect(controller.styledChars[15].style.bold, isFalse);

        // Toggle bold off again
        controller.toggleStyleAttribute('bold');
        for (int i = 9; i < 13; i++) {
          expect(controller.styledChars[i].style.bold, isFalse,
              reason: 'Character at $i must not be bold after toggle');
        }
      });

      test('Toggling italic and underline attributes operates cleanly', () {
        controller.setMarkdown('Multi-style text target');
        controller.selection =
            const TextSelection(baseOffset: 0, extentOffset: 11);

        controller.toggleStyleAttribute('italic');
        expect(controller.styledChars[0].style.italic, isTrue);

        controller.toggleStyleAttribute('underline');
        expect(controller.styledChars[0].style.italic, isTrue);
        expect(controller.styledChars[0].style.underline, isTrue);
      });
    });

    group('4. Checklist Toggle State Transitions', () {
      test('Toggling checkbox index flips state between open and checked', () {
        controller.setMarkdown('- [ ] Buy milk at the store');
        expect(controller.styledChars.first.char,
            equals('\u2610')); // Unchecked box

        // Toggle checkbox at index 0
        controller.toggleChecklistState(0);

        expect(
            controller.styledChars.first.char, equals('\u2611')); // Checked box
        expect(controller.styledChars.first.style.checked, isTrue);

        // Subsequent line characters should now have strikethrough
        expect(controller.styledChars[5].style.strikethrough, isTrue);

        // Toggle back
        controller.toggleChecklistState(0);
        expect(controller.styledChars.first.char,
            equals('\u2610')); // Unchecked box
        expect(controller.styledChars.first.style.checked, isFalse);
        expect(controller.styledChars[5].style.strikethrough, isFalse);
      });
    });

    group('5. Undo and Redo Mechanics', () {
      test(
          'Mutations push to undo stack, undo restores prior state, and redo re-applies',
          () {
        controller.setMarkdown('Initial sentence.');
        expect(controller.text, equals('Initial sentence.'));

        // Apply a style change which saves undo state
        controller.selection =
            const TextSelection(baseOffset: 0, extentOffset: 7);
        controller.toggleStyleAttribute('bold');
        expect(controller.canUndo, isTrue);
        expect(controller.styledChars[0].style.bold, isTrue);

        // Execute Undo
        controller.undo();
        expect(controller.styledChars[0].style.bold, isFalse);
        expect(controller.canRedo, isTrue);

        // Execute Redo
        controller.redo();
        expect(controller.styledChars[0].style.bold, isTrue);
        expect(controller.canRedo, isFalse);
      });
    });

    group('6. Embeds, Dividers, and Block Level Formatting', () {
      test(
          'insertImage embeds object replacement char \uFFFC with image metadata',
          () {
        controller.setMarkdown('Preceding text');
        controller.selection =
            TextSelection.collapsed(offset: controller.text.length);

        controller.insertImage('/local/storage/sample.jpg');

        expect(controller.text.contains('\uFFFC'), isTrue);
        final imgChar =
            controller.styledChars.firstWhere((c) => c.char == '\uFFFC');
        expect(imgChar.style.imageUrl, equals('/local/storage/sample.jpg'));
        expect(imgChar.style.imageWidth, equals(300.0));
      });

      test(
          'insertDivider embeds horizontal divider char \u2014 with isDivider style',
          () {
        controller.setMarkdown('Above section');
        controller.selection =
            TextSelection.collapsed(offset: controller.text.length);

        controller.insertDivider();

        expect(controller.text.contains('\u2014'), isTrue);
        final divChar =
            controller.styledChars.firstWhere((c) => c.char == '\u2014');
        expect(divChar.style.isDivider, isTrue);
      });

      test(
          'toggleChecklistState toggles checkbox char and applies strikethrough to item text',
          () {
        controller.setMarkdown('- [ ] Active task item');
        expect(controller.text.startsWith('\u2610'), isTrue);

        // Toggle state at index 0 (checkbox symbol)
        controller.toggleChecklistState(0);

        expect(controller.styledChars[0].char, equals('\u2611'));
        expect(controller.styledChars[0].style.checked, isTrue);
        // Strikethrough should now be applied to subsequent characters on the line
        expect(controller.styledChars[3].style.strikethrough, isTrue);

        // Toggle back
        controller.toggleChecklistState(0);
        expect(controller.styledChars[0].char, equals('\u2610'));
        expect(controller.styledChars[0].style.checked, isFalse);
        expect(controller.styledChars[3].style.strikethrough, isFalse);
      });

      test(
          'toggleParagraphStyle quote applies quote behavior prefix and listType',
          () {
        controller.setMarkdown('Quoted wisdom statement');
        controller.selection =
            const TextSelection(baseOffset: 0, extentOffset: 10);

        controller.toggleParagraphStyle('quote');

        expect(controller.text.startsWith('›'), isTrue);
        expect(controller.styledChars.first.style.listType, equals('quote'));
      });

      test(
          'toggleParagraphStyle alignment applies target align to paragraph characters',
          () {
        controller.setMarkdown('Centered announcement banner');
        controller.selection =
            const TextSelection(baseOffset: 0, extentOffset: 5);

        controller.toggleParagraphStyle('align-center');

        expect(controller.styledChars[0].style.align, equals(TextAlign.center));
        expect(
            controller.styledChars.last.style.align, equals(TextAlign.center));
      });
    });

    group('7. Edge Cases, Malformed Markdown, and Empty Content', () {
      test('Handles empty and whitespace-only content cleanly', () {
        controller.setMarkdown('');
        expect(controller.text, isEmpty);
        expect(controller.styledChars, isEmpty);

        // setMarkdown trims blank lines into newline tokens
        controller.setMarkdown('   \n\t\n   ');
        expect(controller.text, equals('\n\n'));
        expect(controller.styledChars.length, equals(2));

        // Direct text assignment preserves raw whitespace characters
        controller.text = '   \n\t\n   ';
        expect(controller.text, equals('   \n\t\n   '));
        expect(controller.styledChars.length, equals(9));
      });

      test(
          'Handles unclosed formatting tags and raw characters without crashing',
          () {
        // Unclosed markdown tags should degrade gracefully to plain text
        const unclosedMarkdown =
            '**unclosed bold and *unclosed italic and ~~unclosed strike';
        expect(() => controller.setMarkdown(unclosedMarkdown), returnsNormally);
        expect(controller.text.isNotEmpty, isTrue);

        final generated =
            generateMarkdownFromStyledChars(controller.styledChars);
        expect(generated.isNotEmpty, isTrue);
      });

      test('Handles mixed special unicode and emoji characters safely', () {
        const unicodeText = '🚀 Special 🌟 Symbols & Accents: café, naïve, ñ';
        controller.setMarkdown(unicodeText);

        expect(controller.text, equals(unicodeText));
        final generated =
            generateMarkdownFromStyledChars(controller.styledChars);
        expect(generated.trim(), equals(unicodeText));
      });
    });

    group('8. Cursor, Selection, and Complex Round-Trip Integrity', () {
      test('Preserves text selection bounds during non-destructive operations',
          () {
        controller.setMarkdown('Selection boundary verification text');
        controller.selection =
            const TextSelection(baseOffset: 10, extentOffset: 18);

        // Selection should remain stable
        expect(controller.selection.baseOffset, equals(10));
        expect(controller.selection.extentOffset, equals(18));

        // Toggle bold on selection
        controller.toggleStyleAttribute('bold');
        expect(controller.selection.baseOffset, equals(10));
        expect(controller.selection.extentOffset, equals(18));
      });

      test(
          'Round-trips full multi-paragraph document with mixed formatting headers and lists',
          () {
        const complexDocument = '''# High Level Design
## Subsystem Alpha
> Authoritative invariant statement

- Item 1 with **bold** highlight
- Item 2 with *italic* nuance
- [ ] Action item pending
- [x] ~~Action item completed~~
---
Trailing paragraph with regular text.''';

        controller.setMarkdown(complexDocument);
        final roundTrip =
            generateMarkdownFromStyledChars(controller.styledChars);

        expect(roundTrip.contains('# High Level Design'), isTrue);
        expect(roundTrip.contains('## Subsystem Alpha'), isTrue);
        expect(roundTrip.contains('Authoritative invariant statement'), isTrue);
        expect(roundTrip.contains('**bold**'), isTrue);
        expect(roundTrip.contains('*italic*'), isTrue);
        expect(roundTrip.contains('- [ ] Action item pending'), isTrue);
        expect(roundTrip.contains('- [x] ~~Action item completed~~'), isTrue);
        expect(roundTrip.contains('---'), isTrue);
        expect(roundTrip.contains('Trailing paragraph with regular text.'),
            isTrue);
      });
    });
  });
}
