import 'dart:convert';
import 'package:intl/intl.dart';
import 'note.dart';

/// NoteWidgetLine — Semantic representation of an individual line inside a note for Native Android Home Screen Note Widgets.
///
/// **Supported Semantic Types:**
/// - `text`: Normal continuous text / paragraphs (marker: `""`)
/// - `bullet`: Bulleted item (marker: `"•"`)
/// - `numbered`: Numbered item (marker: `"1."`, `"2."`, etc.)
/// - `checklist`: Checklist item (marker: `"☐"` if unchecked, `"☑"` if checked)
class NoteWidgetLine {
  final String type; // 'text', 'bullet', 'numbered', 'checklist'
  final String text;
  final String marker; // "", "•", "1.", "☐", "☑"
  final bool checked;

  const NoteWidgetLine({
    required this.type,
    required this.text,
    this.marker = '',
    this.checked = false,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'text': text,
        'marker': marker,
        'checked': checked,
      };

  factory NoteWidgetLine.fromJson(Map<String, dynamic> json) => NoteWidgetLine(
        type: json['type'] as String? ?? 'text',
        text: json['text'] as String? ?? '',
        marker: json['marker'] as String? ?? '',
        checked: json['checked'] as bool? ?? false,
      );

  /// Display string combining marker and text for widget presentation.
  String get displayLine {
    if (marker.isEmpty) return text;
    return '$marker $text';
  }
}

/// Backwards compatibility alias
typedef SingleNoteContentLine = NoteWidgetLine;

/// ChecklistItemSnapshot — Represents an individual item in a checklist note.
class ChecklistItemSnapshot {
  final String text;
  final bool checked;

  const ChecklistItemSnapshot({
    required this.text,
    this.checked = false,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'checked': checked,
      };

  factory ChecklistItemSnapshot.fromJson(Map<String, dynamic> json) =>
      ChecklistItemSnapshot(
        text: json['text'] as String? ?? '',
        checked: json['checked'] as bool? ?? false,
      );
}

/// SingleNoteSnapshot — Sanitized snapshot of an individual note for Native Android Home Screen Note Widgets.
///
/// **Phase W6 Contract:**
/// 1. Preserves exact note content semantics: Plain text, bullets, numbered lists, checklists, and mixed content.
/// 2. Zero artificial checklist conversion: Normal text never receives checkboxes or bullets.
/// 3. Continuous text preserves natural paragraph boundaries and wraps naturally in Android TextView.
/// 4. Privacy & Data Minimization: Excludes locked (`isLocked == true`), deleted (`isDeleted == true`), and archived (`isArchived == true`) notes.
class SingleNoteSnapshot {
  final String id;
  final String title;
  final String content;
  final List<NoteWidgetLine> semanticLines;
  final List<ChecklistItemSnapshot> checklistItems;
  final List<String> previewLines;
  final List<NoteWidgetLine> contentLines;
  final String noteType; // 'text' or 'checklist'
  final DateTime updatedAt;
  final String formattedDate;
  final String formattedTime;

  const SingleNoteSnapshot({
    required this.id,
    required this.title,
    required this.content,
    required this.semanticLines,
    required this.checklistItems,
    required this.previewLines,
    required this.contentLines,
    required this.noteType,
    required this.updatedAt,
    required this.formattedDate,
    required this.formattedTime,
  });

  /// Factory creating a sanitized [SingleNoteSnapshot] from a domain [Note] preserving semantic fidelity.
  factory SingleNoteSnapshot.fromNote(Note note, {DateTime? now}) {
    final localUpdated = note.updatedAt.toLocal();
    final formattedDate = DateFormat('EEE, d MMMM yyyy').format(localUpdated);
    final formattedTime = DateFormat('hh:mm a').format(localUpdated);

    final rawContent = note.content;
    final isChecklistNote = note.noteType == 'checklist';

    // 1. Sanitize text for continuous body rendering
    var sanitizedBody = rawContent;
    sanitizedBody = sanitizedBody.replaceAll(RegExp(r'!\[.*?\]\((.*?)\)'), '');
    sanitizedBody = sanitizedBody.replaceAll(RegExp(r'<[^>]*>'), '');
    sanitizedBody = sanitizedBody.replaceAllMapped(RegExp(r'\[(.*?)\]\((.*?)\)'), (match) {
      return match.group(1) ?? '';
    });
    sanitizedBody = sanitizedBody.replaceAll(RegExp(r'\*\*|__|\*|_|~~|=='), '');
    sanitizedBody = sanitizedBody.replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '');
    sanitizedBody = sanitizedBody.trim();

    // 2. Parse semantic lines preserving exact list & paragraph types
    final List<NoteWidgetLine> parsedLines = [];
    final List<ChecklistItemSnapshot> parsedChecklist = [];
    final List<String> extractedPreviewStrings = [];

    final rawLines = rawContent.split('\n');

    for (final rawLine in rawLines) {
      var line = rawLine.trim();
      if (line.isEmpty) continue;
      if (line == '---' || line == '***' || line == '___') continue;
      if (RegExp(r'^!\[(.*?)\]\((.*?)\)$').hasMatch(line)) continue;

      // Clean Markdown headers, inline images, HTML tags, formatting tokens
      line = line.replaceAll(RegExp(r'^#{1,6}\s*'), '');
      line = line.replaceAll(RegExp(r'!\[.*?\]\((.*?)\)'), '');
      line = line.replaceAll(RegExp(r'<[^>]*>'), '');
      line = line.replaceAllMapped(RegExp(r'\[(.*?)\]\((.*?)\)'), (match) => match.group(1) ?? '');
      line = line.replaceAll(RegExp(r'\*\*|__|\*|_|~~|=='), '').trim();

      if (line.isEmpty) continue;

      // Parse Semantic Content Type
      if (line.startsWith('- [ ] ') || line.startsWith('[ ] ') || line.startsWith('☐ ')) {
        final cleanText = line.startsWith('- [ ] ')
            ? line.substring(6).trim()
            : (line.startsWith('[ ] ') ? line.substring(4).trim() : line.substring(2).trim());
        final item = NoteWidgetLine(
          type: 'checklist',
          text: cleanText,
          marker: '☐',
          checked: false,
        );
        parsedLines.add(item);
        parsedChecklist.add(ChecklistItemSnapshot(text: cleanText, checked: false));
        extractedPreviewStrings.add(item.displayLine);
      } else if (line.startsWith('- [x] ') ||
          line.startsWith('- [X] ') ||
          line.startsWith('[x] ') ||
          line.startsWith('[X] ') ||
          line.startsWith('☑ ')) {
        final cleanText = (line.startsWith('- [x] ') || line.startsWith('- [X] '))
            ? line.substring(6).trim()
            : (line.startsWith('[x] ') || line.startsWith('[X] ')
                ? line.substring(4).trim()
                : line.substring(2).trim());
        final item = NoteWidgetLine(
          type: 'checklist',
          text: cleanText,
          marker: '☑',
          checked: true,
        );
        parsedLines.add(item);
        parsedChecklist.add(ChecklistItemSnapshot(text: cleanText, checked: true));
        extractedPreviewStrings.add(item.displayLine);
      } else if (isChecklistNote) {
        // In a checklist note, unmarked items default to unchecked checklist items
        final item = NoteWidgetLine(
          type: 'checklist',
          text: line,
          marker: '☐',
          checked: false,
        );
        parsedLines.add(item);
        parsedChecklist.add(ChecklistItemSnapshot(text: line, checked: false));
        extractedPreviewStrings.add(item.displayLine);
      } else if (RegExp(r'^(\d+)\.\s*(.*)$').hasMatch(line)) {
        final match = RegExp(r'^(\d+)\.\s*(.*)$').firstMatch(line)!;
        final numPrefix = '${match.group(1)}.';
        final cleanText = match.group(2)?.trim() ?? '';
        final item = NoteWidgetLine(
          type: 'numbered',
          text: cleanText,
          marker: numPrefix,
        );
        parsedLines.add(item);
        extractedPreviewStrings.add(item.displayLine);
      } else if (line.startsWith('- ') || line.startsWith('* ') || line.startsWith('• ') || line.startsWith('+ ')) {
        final cleanText = line.startsWith('• ')
            ? line.substring(2).trim()
            : line.substring(2).trim();
        final item = NoteWidgetLine(
          type: 'bullet',
          text: cleanText,
          marker: '•',
        );
        parsedLines.add(item);
        extractedPreviewStrings.add(item.displayLine);
      } else {
        // Plain text / paragraph: ZERO artificial checkboxes or bullets
        final item = NoteWidgetLine(
          type: 'text',
          text: line,
          marker: '',
        );
        parsedLines.add(item);
        extractedPreviewStrings.add(line);
      }

      if (parsedLines.length >= 10) break;
    }

    return SingleNoteSnapshot(
      id: note.id,
      title: note.title.trim().isEmpty ? 'Untitled Note' : note.title.trim(),
      content: sanitizedBody,
      semanticLines: List.unmodifiable(parsedLines),
      checklistItems: List.unmodifiable(parsedChecklist),
      previewLines: List.unmodifiable(extractedPreviewStrings),
      contentLines: List.unmodifiable(parsedLines),
      noteType: note.noteType,
      updatedAt: note.updatedAt.toUtc(),
      formattedDate: formattedDate,
      formattedTime: formattedTime,
    );
  }

  /// Converts the snapshot into a Map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'semantic_lines': semanticLines.map((l) => l.toJson()).toList(),
      'checklist_items': checklistItems.map((c) => c.toJson()).toList(),
      'preview_lines': previewLines,
      'content_lines': semanticLines.map((l) => l.toJson()).toList(),
      'note_type': noteType,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'formatted_date': formattedDate,
      'formatted_time': formattedTime,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  /// Deserializes a Map into a [SingleNoteSnapshot].
  factory SingleNoteSnapshot.fromJson(Map<String, dynamic> json) {
    final rawUpdatedAt = json['updated_at'] as String?;
    final parsedUpdatedAt = rawUpdatedAt != null
        ? (DateTime.tryParse(rawUpdatedAt)?.toUtc() ?? DateTime.now().toUtc())
        : DateTime.now().toUtc();

    final rawLines = json['preview_lines'];
    final List<String> lines = [];
    if (rawLines is List) {
      for (final item in rawLines) {
        if (item != null) lines.add(item.toString());
      }
    }

    final rawSemanticLines = json['semantic_lines'] ?? json['content_lines'];
    final List<NoteWidgetLine> parsedSemanticLines = [];
    if (rawSemanticLines is List) {
      for (final item in rawSemanticLines) {
        if (item is Map<String, dynamic>) {
          parsedSemanticLines.add(NoteWidgetLine.fromJson(item));
        } else if (item is Map) {
          parsedSemanticLines.add(NoteWidgetLine.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    final rawChecklist = json['checklist_items'];
    final List<ChecklistItemSnapshot> parsedChecklist = [];
    if (rawChecklist is List) {
      for (final item in rawChecklist) {
        if (item is Map<String, dynamic>) {
          parsedChecklist.add(ChecklistItemSnapshot.fromJson(item));
        } else if (item is Map) {
          parsedChecklist.add(ChecklistItemSnapshot.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    final rawContent = json['content'] as String? ?? (lines.isNotEmpty ? lines.join('\n') : '');

    return SingleNoteSnapshot(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled Note',
      content: rawContent,
      semanticLines: parsedSemanticLines,
      checklistItems: parsedChecklist,
      previewLines: lines,
      contentLines: parsedSemanticLines,
      noteType: json['note_type'] as String? ?? 'text',
      updatedAt: parsedUpdatedAt,
      formattedDate: json['formatted_date'] as String? ?? '',
      formattedTime: json['formatted_time'] as String? ?? '',
    );
  }

  /// Compact representation for the note selection catalog.
  Map<String, dynamic> toCatalogEntry() {
    final snippet = previewLines.isNotEmpty
        ? previewLines.first
        : (content.isNotEmpty ? content.split('\n').first : '');
    return {
      'id': id,
      'title': title,
      'preview': snippet,
      'note_type': noteType,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'formatted_date': formattedDate,
      'formatted_time': formattedTime,
    };
  }
}
