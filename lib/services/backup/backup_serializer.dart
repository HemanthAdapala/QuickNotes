import 'dart:convert';
import 'package:path/path.dart' as p;
import '../../models/note.dart';
import '../../models/folder.dart';
import '../../models/task_item.dart';
import '../../models/task_status.dart';
import '../../models/repeat_rule.dart';
import '../../models/recurrence_rule.dart';
import '../../models/reminder_mode.dart';
import '../../models/user_profile.dart';
import 'backup_format.dart';
import 'backup_integrity.dart';

/// BackupSerializer — Pure, deterministic data serialization layer for Quick Notes Backup Format V1.
///
/// Principles:
/// - Deterministic key ordering and sorting by stable entity IDs.
/// - Attachment reference normalization (converts absolute device paths into `attachment://...`).
/// - Strict exclusion of runtime/device secrets (tokens, notification IDs, sync outbox rows).
class BackupSerializer {
  BackupSerializer._();

  // ── Attachment Normalization ──────────────────────────────────────────────

  /// Normalizes an absolute device path or URI into a portable `attachment://filename` reference.
  static String normalizeAttachmentUri(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return input;
    if (trimmed.startsWith(BackupFormat.attachmentSchemePrefix)) {
      return input;
    }

    final lower = trimmed.toLowerCase();
    if (lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('data:') ||
        lower.startsWith('assets/') ||
        lower.startsWith('blob:')) {
      return input;
    }

    var cleanPath = trimmed;
    if (cleanPath.startsWith('file://')) {
      cleanPath = Uri.parse(cleanPath).path;
    }

    final filename = p.basename(cleanPath);
    if (filename.isEmpty || filename == '.') return input;
    return '${BackupFormat.attachmentSchemePrefix}$filename';
  }

  /// Normalizes inline markdown image URIs inside Note text content.
  /// Converts `![caption](file:///path/to/img.png)` to `![caption](attachment://img.png)`.
  static String normalizeContentMarkdown(String content) {
    if (content.isEmpty) return content;
    final imageReg = RegExp(r'!\[(.*?)\]\((.*?)\)');
    return content.replaceAllMapped(imageReg, (match) {
      final caption = match.group(1) ?? '';
      final uri = match.group(2) ?? '';
      final normalizedUri = normalizeAttachmentUri(uri);
      return '![$caption]($normalizedUri)';
    });
  }

  /// Denormalizes a portable `attachment://filename` reference back to a local device URI.
  static String denormalizeAttachmentUri(String input, String targetDir) {
    if (!input.startsWith(BackupFormat.attachmentSchemePrefix)) return input;
    final filename = input.substring(BackupFormat.attachmentSchemePrefix.length);
    final fullPath = p.join(targetDir, filename);
    return Uri.file(fullPath).toString();
  }

  // ── Folder Serialization ──────────────────────────────────────────────────

  static Map<String, dynamic> serializeFolder(Folder folder) {
    final map = <String, dynamic>{
      'colorHex': folder.colorHex,
      'createdAt': folder.createdAt.toUtc().toIso8601String(),
      'deletedAt': folder.deletedAt?.toUtc().toIso8601String(),
      'id': folder.id,
      'isDeleted': folder.isDeleted,
      'lastSyncedVersion': folder.lastSyncedVersion,
      'name': folder.name,
      'parentId': folder.parentId,
      'sticker': folder.sticker,
      'trashedByFolderId': folder.trashedByFolderId,
      'updatedAt': folder.updatedAt.toUtc().toIso8601String(),
      'userId': folder.userId,
      'version': folder.version,
    };
    return BackupIntegrity.canonicalizeJson(map);
  }

  static String serializeFolders(List<Folder> folders) {
    final sorted = List<Folder>.from(folders)..sort((a, b) => a.id.compareTo(b.id));
    final list = sorted.map((f) => serializeFolder(f)).toList();
    return BackupIntegrity.encodeDeterministicJson(list);
  }

  static Folder deserializeFolder(Map<String, dynamic> map) {
    final created = DateTime.parse(map['createdAt'] as String);
    return Folder(
      id: map['id'] as String,
      userId: map['userId'] as String?,
      name: map['name'] as String,
      parentId: map['parentId'] as String?,
      createdAt: created,
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt'] as String) : created,
      colorHex: map['colorHex'] as String?,
      sticker: map['sticker'] as String?,
      isDeleted: map['isDeleted'] == true || map['isDeleted'] == 1,
      deletedAt: map['deletedAt'] != null ? DateTime.parse(map['deletedAt'] as String) : null,
      trashedByFolderId: map['trashedByFolderId'] as String?,
      version: (map['version'] as num?)?.toInt() ?? 1,
      lastSyncedVersion: (map['lastSyncedVersion'] as num?)?.toInt() ?? 0,
    );
  }

  // ── Note Serialization ────────────────────────────────────────────────────

  static Map<String, dynamic> serializeNote(Note note) {
    final normalizedContent = normalizeContentMarkdown(note.content);

    final normalizedAttachments = note.attachments.map((att) {
      final copy = Map<String, dynamic>.from(att);
      if (copy.containsKey('path') && copy['path'] != null) {
        copy['path'] = normalizeAttachmentUri(copy['path'].toString());
      }
      if (copy.containsKey('url') && copy['url'] != null) {
        copy['url'] = normalizeAttachmentUri(copy['url'].toString());
      }
      return copy;
    }).toList();

    final map = <String, dynamic>{
      'attachments': normalizedAttachments,
      'category': note.category,
      'colorValue': note.colorValue,
      'content': normalizedContent,
      'createdAt': note.createdAt.toUtc().toIso8601String(),
      'deletedAt': note.deletedAt?.toUtc().toIso8601String(),
      'folderId': note.folderId,
      'habitLastCompleted': note.habitLastCompleted?.toUtc().toIso8601String(),
      'habitRecurrence': note.habitRecurrence,
      'habitStreak': note.habitStreak,
      'id': note.id,
      'isArchived': note.isArchived,
      'isDeleted': note.isDeleted,
      'isFavorite': note.isFavorite,
      'isHabit': note.isHabit,
      'isLocked': note.isLocked,
      'isPinned': note.isPinned,
      'lastSyncedVersion': note.lastSyncedVersion,
      'noteType': note.noteType,
      'paperGuideColor': note.paperGuideColor,
      'paperGuideHeight': note.paperGuideHeight,
      'paperGuideOpacity': note.paperGuideOpacity,
      'paperGuideType': note.paperGuideType,
      'paperGuideVisible': note.paperGuideVisible,
      'previewText': note.previewText,
      'reminderTime': note.reminderTime?.toUtc().toIso8601String(),
      'tags': List<String>.from(note.tags)..sort(),
      'title': note.title,
      'trashedByFolderId': note.trashedByFolderId,
      'updatedAt': note.updatedAt.toUtc().toIso8601String(),
      'userId': note.userId,
      'version': note.version,
    };
    return BackupIntegrity.canonicalizeJson(map);
  }

  static String serializeNotes(List<Note> notes) {
    final sorted = List<Note>.from(notes)..sort((a, b) => a.id.compareTo(b.id));
    final list = sorted.map((n) => serializeNote(n)).toList();
    return BackupIntegrity.encodeDeterministicJson(list);
  }

  static Note deserializeNote(Map<String, dynamic> map) {
    final created = DateTime.parse(map['createdAt'] as String);

    final rawTags = map['tags'];
    final List<String> tags = rawTags is List ? rawTags.map((e) => e.toString()).toList() : [];

    final rawAttachments = map['attachments'];
    final List<Map<String, dynamic>> attachments = rawAttachments is List
        ? rawAttachments.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : [];

    return Note(
      id: map['id'] as String,
      userId: map['userId'] as String?,
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      isPinned: map['isPinned'] == true || map['isPinned'] == 1,
      isFavorite: map['isFavorite'] == true || map['isFavorite'] == 1,
      isArchived: map['isArchived'] == true || map['isArchived'] == 1,
      category: map['category'] as String? ?? 'Uncategorized',
      noteType: map['noteType'] as String? ?? 'text',
      tags: tags,
      attachments: attachments,
      isLocked: map['isLocked'] == true || map['isLocked'] == 1,
      reminderTime: map['reminderTime'] != null ? DateTime.parse(map['reminderTime'] as String) : null,
      createdAt: created,
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt'] as String) : created,
      colorValue: (map['colorValue'] as num?)?.toInt() ?? 0xFFFFFFFF,
      isDeleted: map['isDeleted'] == true || map['isDeleted'] == 1,
      deletedAt: map['deletedAt'] != null ? DateTime.parse(map['deletedAt'] as String) : null,
      trashedByFolderId: map['trashedByFolderId'] as String?,
      folderId: map['folderId'] as String?,
      isHabit: map['isHabit'] == true || map['isHabit'] == 1,
      habitRecurrence: map['habitRecurrence'] as String? ?? 'none',
      habitStreak: (map['habitStreak'] as num?)?.toInt() ?? 0,
      habitLastCompleted: map['habitLastCompleted'] != null ? DateTime.parse(map['habitLastCompleted'] as String) : null,
      previewText: map['previewText'] as String?,
      paperGuideType: map['paperGuideType'] as String? ?? 'lines_extra_tight',
      paperGuideVisible: map['paperGuideVisible'] == true || map['paperGuideVisible'] == 1,
      paperGuideHeight: (map['paperGuideHeight'] as num?)?.toDouble() ?? 1.05,
      paperGuideOpacity: (map['paperGuideOpacity'] as num?)?.toDouble() ?? 0.15,
      paperGuideColor: (map['paperGuideColor'] as num?)?.toInt() ?? 0,
      version: (map['version'] as num?)?.toInt() ?? 1,
      lastSyncedVersion: (map['lastSyncedVersion'] as num?)?.toInt() ?? 0,
    );
  }

  // ── Task Serialization ────────────────────────────────────────────────────

  static Map<String, dynamic> serializeTask(TaskItem task) {
    final map = <String, dynamic>{
      'categoryId': task.categoryId,
      'completedAt': task.completedAt?.toUtc().toIso8601String(),
      'completedDates': List<String>.from(task.completedDates)..sort(),
      'createdAt': task.createdAt.toUtc().toIso8601String(),
      'deletedAt': task.deletedAt?.toUtc().toIso8601String(),
      'description': task.description,
      'dueDate': task.dueDate.toUtc().toIso8601String(),
      'endTime': task.endTime?.toUtc().toIso8601String(),
      'folderId': task.folderId,
      'id': task.id,
      'isDeleted': task.isDeleted,
      'isRecurring': task.isRecurring,
      'lastSyncedVersion': task.lastSyncedVersion,

      // EXCLUDED: notificationId is system/runtime specific and NOT serialized into backup!

      'priority': task.priority,
      'recurrence': task.recurrence?.toMap(),
      'recurringSeriesId': task.recurringSeriesId,
      'reminderEnabled': task.reminderEnabled,
      'reminderMode': task.reminderMode.toDbString(),
      'reminderTime': task.reminderTime?.toUtc().toIso8601String(),
      'repeatRule': task.repeatRule.toDbString(),
      'startTime': task.startTime?.toUtc().toIso8601String(),
      'status': task.status.toDbString(),
      'timezone': task.timezone,
      'title': task.title,
      'updatedAt': task.updatedAt.toUtc().toIso8601String(),
      'userId': task.userId,
      'version': task.version,
    };
    return BackupIntegrity.canonicalizeJson(map);
  }

  static String serializeTasks(List<TaskItem> tasks) {
    final sorted = List<TaskItem>.from(tasks)..sort((a, b) => a.id.compareTo(b.id));
    final list = sorted.map((t) => serializeTask(t)).toList();
    return BackupIntegrity.encodeDeterministicJson(list);
  }

  static TaskItem deserializeTask(Map<String, dynamic> map) {
    final created = DateTime.parse(map['createdAt'] as String);
    final due = DateTime.parse(map['dueDate'] as String);

    final rawCompletedDates = map['completedDates'];
    final List<String> completedDates = rawCompletedDates is List
        ? rawCompletedDates.map((e) => e.toString()).toList()
        : [];

    return TaskItem(
      id: map['id'] as String,
      userId: map['userId'] as String?,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      folderId: map['folderId'] as String?,
      categoryId: map['categoryId'] as String?,
      dueDate: due,
      startTime: map['startTime'] != null ? DateTime.parse(map['startTime'] as String) : null,
      endTime: map['endTime'] != null ? DateTime.parse(map['endTime'] as String) : null,
      priority: map['priority'] as String? ?? 'None',
      status: TaskStatusExtension.fromDbString(map['status'] as String? ?? 'waiting'),
      createdAt: created,
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt'] as String) : created,
      completedAt: map['completedAt'] != null ? DateTime.parse(map['completedAt'] as String) : null,
      reminderEnabled: map['reminderEnabled'] == true || map['reminderEnabled'] == 1,
      reminderMode: ReminderModeExtension.fromDbString(map['reminderMode'] as String? ?? 'off'),
      reminderTime: map['reminderTime'] != null ? DateTime.parse(map['reminderTime'] as String) : null,
      notificationId: 0, // Reset to 0 default on restore
      repeatRule: RepeatRuleExtension.fromDbString(map['repeatRule'] as String? ?? 'none'),
      isRecurring: map['isRecurring'] == true || map['isRecurring'] == 1,
      recurrence: map['recurrence'] != null
          ? RecurrenceRule.fromMap(Map<String, dynamic>.from(map['recurrence'] as Map))
          : null,
      recurringSeriesId: map['recurringSeriesId'] as String?,
      timezone: map['timezone'] as String? ?? 'UTC',
      completedDates: completedDates,
      isDeleted: map['isDeleted'] == true || map['isDeleted'] == 1,
      deletedAt: map['deletedAt'] != null ? DateTime.parse(map['deletedAt'] as String) : null,
      version: (map['version'] as num?)?.toInt() ?? 1,
      lastSyncedVersion: (map['lastSyncedVersion'] as num?)?.toInt() ?? 0,
    );
  }

  // ── User Profile Serialization ────────────────────────────────────────────

  static Map<String, dynamic> serializeUserProfile(UserProfile profile) {
    // Strictly EXCLUDES OAuth credentials, tokens, secrets, or secure storage values!
    final map = <String, dynamic>{
      'avatarId': profile.avatarId,
      'createdAt': profile.createdAt.toUtc().toIso8601String(),
      'displayName': profile.displayName,
      'email': profile.email,
      'photoUrl': profile.photoUrl,
      'profileVersion': profile.profileVersion,
      'updatedAt': profile.updatedAt.toUtc().toIso8601String(),
      'usesGooglePhoto': profile.usesGooglePhoto,
    };
    return BackupIntegrity.canonicalizeJson(map);
  }
}
