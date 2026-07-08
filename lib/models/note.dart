import 'dart:convert';

class Note {
  final String id;
  final String title;
  final String content;
  final bool isPinned;
  final bool isFavorite;
  final bool isArchived;
  final String category;
  final String noteType; // 'text' or 'checklist'
  final List<String> tags;
  final List<Map<String, dynamic>> attachments; // List of image/voice attachments metadata
  final bool isLocked;
  final DateTime? reminderTime;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int colorValue;
  final bool isDeleted;
  final String previewText;
  
  // Folder & Habits Expansion
  final String? folderId;
  final bool isHabit;
  final String habitRecurrence; // 'daily', 'weekly', 'none'
  final int habitStreak;
  final DateTime? habitLastCompleted;

  // Paper Guide Layer Settings
  final String paperGuideType;
  final bool paperGuideVisible;
  final double paperGuideHeight;
  final double paperGuideOpacity;
  final int paperGuideColor;

  Note({
    required this.id,
    required this.title,
    required this.content,
    this.isPinned = false,
    this.isFavorite = false,
    this.isArchived = false,
    this.category = 'Uncategorized',
    this.noteType = 'text',
    required this.tags,
    required this.attachments,
    this.isLocked = false,
    this.reminderTime,
    required this.createdAt,
    required this.updatedAt,
    required this.colorValue,
    this.isDeleted = false,
    this.folderId,
    this.isHabit = false,
    this.habitRecurrence = 'none',
    this.habitStreak = 0,
    this.habitLastCompleted,
    String? previewText,
    this.paperGuideType = 'lines_extra_tight',
    this.paperGuideVisible = true,
    this.paperGuideHeight = 1.05,
    this.paperGuideOpacity = 0.15,
    this.paperGuideColor = 0,
  }) : previewText = previewText ?? _generatePreviewText(content, noteType);

  static String _generatePreviewText(String content, String noteType) {
    if (noteType == 'checklist') {
      try {
        final List<dynamic> items = jsonDecode(content) as List<dynamic>;
        final lines = items
            .map((item) => (item['text'] ?? item['title'] ?? "").toString().trim())
            .where((text) => text.isNotEmpty)
            .toList();
        return lines.join('\n');
      } catch (_) {
        return content.trim();
      }
    }

    final lines = content.split('\n');
    final List<String> cleanLines = [];
    int sequentialNumber = 0;

    for (var line in lines) {
      var trimmed = line.trim();
      if (trimmed.isEmpty) {
        sequentialNumber = 0;
        continue;
      }

      // Skip dividers
      if (trimmed == '---' || trimmed == '***' || trimmed == '___') {
        sequentialNumber = 0;
        continue;
      }

      // Skip image block lines
      final imageReg = RegExp(r'^!\[(.*?)\]\((.*?)\)$');
      if (imageReg.hasMatch(trimmed)) {
        sequentialNumber = 0;
        continue;
      }

      final numListRegex = RegExp(r'^(\d+)\.\s(.*)$');

      // Reset numbering if this line is not a numbered list item
      if (!numListRegex.hasMatch(trimmed)) {
        sequentialNumber = 0;
      }

      // Handle checklist, bullet list, and numbered list prefixes
      if (trimmed.startsWith('- [ ] ')) {
        trimmed = '☐ ' + trimmed.substring(6).trim();
      } else if (trimmed.startsWith('- [x] ') || trimmed.startsWith('- [X] ')) {
        trimmed = '☑ ' + trimmed.substring(6).trim();
      } else if (trimmed.startsWith('- ')) {
        trimmed = '• ' + trimmed.substring(2).trim();
      } else if (numListRegex.hasMatch(trimmed)) {
        final match = numListRegex.firstMatch(trimmed)!;
        final content = match.group(2) ?? '';
        sequentialNumber++;
        trimmed = '$sequentialNumber. ' + content.trim();
      }

      // Strip inline image syntax: ![alt](url) -> replace with empty string
      trimmed = trimmed.replaceAll(RegExp(r'!\[.*?\]\((.*?)\)'), '');

      // Strip HTML tags: <p>, <strong>, etc.
      trimmed = trimmed.replaceAll(RegExp(r'<[^>]*>'), '');

      // Strip link syntax: [text](url) -> keep text
      trimmed = trimmed.replaceAllMapped(RegExp(r'\[(.*?)\]\((.*?)\)'), (match) {
        return match.group(1) ?? '';
      });

      // Strip bold/italic/strikethrough/highlight formatting markers: **, *, __, _, ~~, ==
      trimmed = trimmed.replaceAll(RegExp(r'\*\*|__|\*|_|~~|=='), '');

      trimmed = trimmed.trim();
      if (trimmed.isNotEmpty) {
        cleanLines.add(trimmed);
      }
    }

    return cleanLines.join('\n');
  }

  // Convert Note to a Map for database operations (serialize lists to JSON string)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'isPinned': isPinned ? 1 : 0,
      'isFavorite': isFavorite ? 1 : 0,
      'isArchived': isArchived ? 1 : 0,
      'category': category,
      'noteType': noteType,
      'tags': jsonEncode(tags),
      'attachments': jsonEncode(attachments),
      'isLocked': isLocked ? 1 : 0,
      'reminderTime': reminderTime?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'colorValue': colorValue,
      'isDeleted': isDeleted ? 1 : 0,
      'folderId': folderId,
      'isHabit': isHabit ? 1 : 0,
      'habitRecurrence': habitRecurrence,
      'habitStreak': habitStreak,
      'habitLastCompleted': habitLastCompleted?.toIso8601String(),
      'previewText': previewText,
      'paperSettings': jsonEncode({
        'guideType': paperGuideType,
        'guideVisible': paperGuideVisible,
        'lineHeight': paperGuideHeight,
        'opacity': paperGuideOpacity,
        'color': paperGuideColor,
      }),
    };
  }

  // Create a Note object from database records (deserialize JSON strings)
  factory Note.fromMap(Map<String, dynamic> map) {
    // Parse tags safely
    List<String> parsedTags = [];
    if (map['tags'] != null) {
      try {
        final decoded = jsonDecode(map['tags'] as String) as List<dynamic>;
        parsedTags = decoded.map((e) => e.toString()).toList();
      } catch (e) {
        parsedTags = [];
      }
    }

    // Parse attachments safely
    List<Map<String, dynamic>> parsedAttachments = [];
    if (map['attachments'] != null) {
      try {
        final decoded = jsonDecode(map['attachments'] as String) as List<dynamic>;
        parsedAttachments = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (e) {
        parsedAttachments = [];
      }
    }

    String paperGuideType = 'lines_extra_tight';
    bool paperGuideVisible = true;
    double paperGuideHeight = 1.05;
    double paperGuideOpacity = 0.15;
    int paperGuideColor = 0;

    if (map['paperSettings'] != null) {
      try {
        final decoded = jsonDecode(map['paperSettings'] as String) as Map<String, dynamic>;
        paperGuideType = decoded['guideType'] ?? 'lines_extra_tight';
        paperGuideVisible = decoded['guideVisible'] ?? true;
        paperGuideHeight = (decoded['lineHeight'] as num?)?.toDouble() ?? 1.05;
        paperGuideOpacity = (decoded['opacity'] as num?)?.toDouble() ?? 0.15;
        paperGuideColor = decoded['color'] ?? 0;
      } catch (_) {}
    }

    return Note(
      id: map['id'] as String,
      title: map['title'] as String,
      content: (map['content'] ?? "") as String,
      isPinned: (map['isPinned'] as int) == 1,
      isFavorite: (map['isFavorite'] ?? 0) as int == 1,
      isArchived: (map['isArchived'] ?? 0) as int == 1,
      category: (map['category'] ?? 'Uncategorized') as String,
      noteType: (map['noteType'] ?? 'text') as String,
      tags: parsedTags,
      attachments: parsedAttachments,
      isLocked: (map['isLocked'] ?? 0) as int == 1,
      reminderTime: map['reminderTime'] != null ? DateTime.tryParse(map['reminderTime'] as String) : null,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      colorValue: map['colorValue'] as int,
      isDeleted: (map['isDeleted'] ?? 0) as int == 1,
      folderId: map['folderId'] as String?,
      isHabit: ((map['isHabit'] ?? 0) as int) == 1,
      habitRecurrence: (map['habitRecurrence'] ?? 'none') as String,
      habitStreak: (map['habitStreak'] ?? 0) as int,
      habitLastCompleted: map['habitLastCompleted'] != null ? DateTime.tryParse(map['habitLastCompleted'] as String) : null,
      previewText: map['previewText'] as String?,
      paperGuideType: paperGuideType,
      paperGuideVisible: paperGuideVisible,
      paperGuideHeight: paperGuideHeight,
      paperGuideOpacity: paperGuideOpacity,
      paperGuideColor: paperGuideColor,
    );
  }

  // Create a copy of Note with overrides
  Note copyWith({
    String? id,
    String? title,
    String? content,
    bool? isPinned,
    bool? isFavorite,
    bool? isArchived,
    String? category,
    String? noteType,
    List<String>? tags,
    List<Map<String, dynamic>>? attachments,
    bool? isLocked,
    DateTime? reminderTime,
    bool clearReminder = false, // Helper flags to clear fields
    DateTime? createdAt,
    DateTime? updatedAt,
    int? colorValue,
    bool? isDeleted,
    String? folderId,
    bool clearFolder = false,
    bool? isHabit,
    String? habitRecurrence,
    int? habitStreak,
    DateTime? habitLastCompleted,
    bool clearHabitLastCompleted = false,
    String? previewText,
    String? paperGuideType,
    bool? paperGuideVisible,
    double? paperGuideHeight,
    double? paperGuideOpacity,
    int? paperGuideColor,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      isPinned: isPinned ?? this.isPinned,
      isFavorite: isFavorite ?? this.isFavorite,
      isArchived: isArchived ?? this.isArchived,
      category: category ?? this.category,
      noteType: noteType ?? this.noteType,
      tags: tags ?? this.tags,
      attachments: attachments ?? this.attachments,
      isLocked: isLocked ?? this.isLocked,
      reminderTime: clearReminder ? null : (reminderTime ?? this.reminderTime),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      colorValue: colorValue ?? this.colorValue,
      isDeleted: isDeleted ?? this.isDeleted,
      folderId: clearFolder ? null : (folderId ?? this.folderId),
      isHabit: isHabit ?? this.isHabit,
      habitRecurrence: habitRecurrence ?? this.habitRecurrence,
      habitStreak: habitStreak ?? this.habitStreak,
      habitLastCompleted: clearHabitLastCompleted ? null : (habitLastCompleted ?? this.habitLastCompleted),
      previewText: previewText ?? ((content != null || noteType != null) ? null : this.previewText),
      paperGuideType: paperGuideType ?? this.paperGuideType,
      paperGuideVisible: paperGuideVisible ?? this.paperGuideVisible,
      paperGuideHeight: paperGuideHeight ?? this.paperGuideHeight,
      paperGuideOpacity: paperGuideOpacity ?? this.paperGuideOpacity,
      paperGuideColor: paperGuideColor ?? this.paperGuideColor,
    );
  }
}
