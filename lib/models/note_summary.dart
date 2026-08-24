import 'dart:convert';
import 'note.dart';

class NoteSummary {
  final String id;
  final String title;
  final String previewText; // first 120 characters of body only
  final int colorValue;
  final String? folderId;
  final String? folderName;
  final String? categoryId;
  final String? categoryName;
  final int? categoryColor;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPinned;
  final bool isFavorite;
  final bool isArchived;
  final bool isDeleted;
  final bool isLocked;
  final bool isHabit;
  final int habitStreak;
  final DateTime? reminderTime;
  final String noteType; // 'text' or 'checklist'
  final String checklistProgress; // e.g. "3/5 done"

  NoteSummary({
    required this.id,
    required this.title,
    required this.previewText,
    required this.colorValue,
    this.folderId,
    this.folderName,
    this.categoryId,
    this.categoryName,
    this.categoryColor,
    required this.createdAt,
    required this.updatedAt,
    required this.isPinned,
    required this.isFavorite,
    required this.isArchived,
    required this.isDeleted,
    required this.isLocked,
    required this.isHabit,
    required this.habitStreak,
    this.reminderTime,
    required this.noteType,
    required this.checklistProgress,
  });

  factory NoteSummary.fromMap(Map<String, dynamic> map,
      {String? folderName, int? categoryColor}) {
    final noteType = 'text';
    final content = map['content'] as String? ?? '';

    String progress = '';
    String previewTextVal = map['previewText'] as String? ?? '';
    if (previewTextVal.isEmpty) {
      previewTextVal = content;
    }

    // truncate preview to first 120 characters
    final cleanPreview = previewTextVal.trim().replaceAll('\n', ' ');
    final preview = cleanPreview.length > 120
        ? '${cleanPreview.substring(0, 120)}...'
        : cleanPreview;

    final cat = map['category'] as String? ?? 'Uncategorized';

    final isPinned = map['isPinned'] == 1 || map['isPinned'] == true;
    final isFavorite = map['isFavorite'] == 1 || map['isFavorite'] == true;
    final isArchived = map['isArchived'] == 1 || map['isArchived'] == true;
    final isDeleted = map['isDeleted'] == 1 || map['isDeleted'] == true;
    final isLocked = map['isLocked'] == 1 || map['isLocked'] == true;
    final isHabit = map['isHabit'] == 1 || map['isHabit'] == true;
    final habitStreak = map['habitStreak'] as int? ?? 0;

    DateTime? reminder;
    if (map['reminderTime'] != null) {
      reminder = DateTime.tryParse(map['reminderTime'] as String);
    }

    return NoteSummary(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      previewText: preview,
      colorValue: map['colorValue'] as int? ?? 0,
      folderId: map['folderId'] as String?,
      folderName: folderName,
      categoryId: cat.toLowerCase(),
      categoryName: cat,
      categoryColor: categoryColor,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      isPinned: isPinned,
      isFavorite: isFavorite,
      isArchived: isArchived,
      isDeleted: isDeleted,
      isLocked: isLocked,
      isHabit: isHabit,
      habitStreak: habitStreak,
      reminderTime: reminder,
      noteType: noteType,
      checklistProgress: progress,
    );
  }

  factory NoteSummary.fromNote(Note note,
      {String? folderName, int? categoryColor}) {
    String progress = '';
    final cleanPreview = note.previewText.trim().replaceAll('\n', ' ');
    final preview = cleanPreview.length > 120
        ? '${cleanPreview.substring(0, 120)}...'
        : cleanPreview;

    return NoteSummary(
      id: note.id,
      title: note.title,
      previewText: preview,
      colorValue: note.colorValue,
      folderId: note.folderId,
      folderName: folderName,
      categoryId: note.category.toLowerCase(),
      categoryName: note.category,
      categoryColor: categoryColor,
      createdAt: note.createdAt,
      updatedAt: note.updatedAt,
      isPinned: note.isPinned,
      isFavorite: note.isFavorite,
      isArchived: note.isArchived,
      isDeleted: note.isDeleted,
      isLocked: note.isLocked,
      isHabit: note.isHabit,
      habitStreak: note.habitStreak,
      reminderTime: note.reminderTime,
      noteType: 'text',
      checklistProgress: progress,
    );
  }
}
