import 'dart:convert';
import 'task_status.dart';
import 'repeat_rule.dart';
import 'recurrence_rule.dart';
import 'reminder_mode.dart';

class TaskItem {
  final String id;
  final String? userId;
  final String title;
  final String description;
  final String? folderId;
  final String? categoryId;
  final DateTime dueDate;
  final DateTime? startTime;
  final DateTime? endTime;
  final String priority; // 'High', 'Medium', 'Low', 'None'
  final TaskStatus status; // Authoritative state
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final bool reminderEnabled;
  final ReminderMode reminderMode;
  final DateTime? reminderTime;
  final int notificationId;
  final RepeatRule repeatRule;
  final bool isRecurring;
  final RecurrenceRule? recurrence;
  final String? recurringSeriesId;
  final String timezone;
  final List<String> completedDates;
  final bool isDeleted;
  final DateTime? deletedAt;
  final int version;
  final int lastSyncedVersion;

  TaskItem({
    required this.id,
    this.userId,
    required this.title,
    this.description = '',
    this.folderId,
    this.categoryId,
    required this.dueDate,
    this.startTime,
    this.endTime,
    required this.priority,
    TaskStatus? status,
    bool? completed,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.completedAt,
    bool? reminderEnabled,
    ReminderMode? reminderMode,
    this.reminderTime,
    int? notificationId,
    RepeatRule? repeatRule,
    bool? isRecurring,
    this.recurrence,
    this.recurringSeriesId,
    String? timezone,
    this.completedDates = const [],
    this.isDeleted = false,
    this.deletedAt,
    this.version = 1,
    this.lastSyncedVersion = 0,
  })  : status = status ??
            ((completed ?? false) ? TaskStatus.completed : TaskStatus.waiting),
        createdAt = (createdAt ?? DateTime.now()).toUtc(),
        updatedAt = (updatedAt ?? DateTime.now()).toUtc(),
        reminderMode = reminderMode ??
            ((reminderEnabled == false ||
                    (reminderTime == null && reminderEnabled == null))
                ? ReminderMode.off
                : ReminderMode.alarm),
        reminderEnabled = (reminderMode ??
                ((reminderEnabled == false ||
                        (reminderTime == null && reminderEnabled == null))
                    ? ReminderMode.off
                    : ReminderMode.alarm)) !=
            ReminderMode.off,
        notificationId = notificationId ?? 0,
        repeatRule = repeatRule ??
            (recurrence != null
                ? RepeatRuleExtension.fromDbString(recurrence.type.toDbString())
                : RepeatRule.none),
        isRecurring = isRecurring ?? (recurrence != null),
        timezone = timezone ?? DateTime.now().timeZoneName;

  /// Single authoritative completion property derived strictly from status
  bool get completed => status == TaskStatus.completed;

  /// Helper getters for status classification
  bool get isMissed => status == TaskStatus.missed;
  bool get isWaiting =>
      status == TaskStatus.waiting || status == TaskStatus.scheduled;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'folderId': folderId,
      'categoryId': categoryId,
      'dueDate': dueDate.toUtc().toIso8601String(),
      'startTime': startTime?.toUtc().toIso8601String(),
      'endTime': endTime?.toUtc().toIso8601String(),
      'priority': priority,
      'status': status.toDbString(),
      'completed': completed ? 1 : 0,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'completedAt': completedAt?.toUtc().toIso8601String(),
      'reminderEnabled': reminderEnabled ? 1 : 0,
      'reminderMode': reminderMode.toDbString(),
      'reminderTime': reminderTime?.toUtc().toIso8601String(),
      'notificationId': notificationId,
      'repeatRule': repeatRule.toDbString(),
      'isRecurring': isRecurring ? 1 : 0,
      'recurrenceRule': recurrence?.jsonEncodePayload(),
      'recurringSeriesId': recurringSeriesId,
      'timezone': timezone,
      'completedDates': jsonEncode(completedDates),
      'isDeleted': isDeleted ? 1 : 0,
      'deletedAt': deletedAt?.toUtc().toIso8601String(),
      'version': version,
      'lastSyncedVersion': lastSyncedVersion,
    };
  }

  factory TaskItem.fromMap(Map<String, dynamic> map) {
    final statusVal =
        TaskStatusExtension.fromDbString(map['status'] as String?);
    final rawCompleted =
        (map['completed'] as int? ?? (map['isCompleted'] as int? ?? 0)) == 1;

    // Resolve authoritative status, defaulting from completed boolean if status column was null
    final finalStatus = map['status'] != null
        ? statusVal
        : (rawCompleted ? TaskStatus.completed : TaskStatus.waiting);

    final rawDueDate =
        DateTime.tryParse(map['dueDate'] as String? ?? '') ?? DateTime.now();
    final rawCreatedAt =
        DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now();
    final rawUpdatedAt =
        DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now();

    final recRule = RecurrenceRule.tryDecode(map['recurrenceRule'] as String?);
    final rawIsRec = (map['isRecurring'] as int? ?? 0) == 1 || recRule != null;

    List<String> rawCompletedDates = const [];
    if (map['completedDates'] != null) {
      try {
        final decoded = jsonDecode(map['completedDates'] as String);
        if (decoded is List) {
          rawCompletedDates = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    final rawRemEnabled = (map['reminderEnabled'] as int? ?? 0) == 1 ||
        map['reminderTime'] != null;
    final rawRemModeStr = map['reminderMode'] as String?;
    final resolvedRemMode = rawRemModeStr != null
        ? ReminderModeExtension.fromDbString(rawRemModeStr)
        : (rawRemEnabled ? ReminderMode.alarm : ReminderMode.off);

    return TaskItem(
      id: map['id'] as String,
      userId: map['userId'] as String?,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      folderId: map['folderId'] as String?,
      categoryId: map['categoryId'] as String?,
      dueDate: rawDueDate.toUtc(),
      startTime: map['startTime'] != null
          ? DateTime.tryParse(map['startTime'] as String)?.toUtc()
          : null,
      endTime: map['endTime'] != null
          ? DateTime.tryParse(map['endTime'] as String)?.toUtc()
          : null,
      priority: map['priority'] as String? ?? 'None',
      status: finalStatus,
      createdAt: rawCreatedAt.toUtc(),
      updatedAt: rawUpdatedAt.toUtc(),
      completedAt: map['completedAt'] != null
          ? DateTime.tryParse(map['completedAt'] as String)?.toUtc()
          : null,
      reminderEnabled: resolvedRemMode != ReminderMode.off,
      reminderMode: resolvedRemMode,
      reminderTime: map['reminderTime'] != null
          ? DateTime.tryParse(map['reminderTime'] as String)?.toUtc()
          : null,
      notificationId: map['notificationId'] as int? ?? 0,
      repeatRule:
          RepeatRuleExtension.fromDbString(map['repeatRule'] as String?),
      isRecurring: rawIsRec,
      recurrence: recRule,
      recurringSeriesId: map['recurringSeriesId'] as String?,
      timezone: map['timezone'] as String? ?? DateTime.now().timeZoneName,
      completedDates: rawCompletedDates,
      isDeleted: map['isDeleted'] == 1 || map['isDeleted'] == true,
      deletedAt: map['deletedAt'] != null
          ? DateTime.tryParse(map['deletedAt'] as String)?.toUtc()
          : null,
      version: (map['version'] ?? 1) as int,
      lastSyncedVersion: (map['lastSyncedVersion'] ?? 0) as int,
    );
  }

  TaskItem copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    String? folderId,
    String? categoryId,
    DateTime? dueDate,
    DateTime? startTime,
    DateTime? endTime,
    String? priority,
    TaskStatus? status,
    bool? completed,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    bool? reminderEnabled,
    ReminderMode? reminderMode,
    DateTime? reminderTime,
    bool clearReminderTime = false,
    int? notificationId,
    RepeatRule? repeatRule,
    bool? isRecurring,
    RecurrenceRule? recurrence,
    bool clearRecurrence = false,
    String? recurringSeriesId,
    String? timezone,
    List<String>? completedDates,
    bool? isDeleted,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    int? version,
    int? lastSyncedVersion,
  }) {
    TaskStatus? resolvedStatus = status;
    if (resolvedStatus == null && completed != null) {
      resolvedStatus = completed ? TaskStatus.completed : TaskStatus.waiting;
    }

    final resolvedRemMode = reminderMode ??
        (reminderEnabled != null
            ? (reminderEnabled
                ? (this.reminderMode != ReminderMode.off
                    ? this.reminderMode
                    : ReminderMode.alarm)
                : ReminderMode.off)
            : this.reminderMode);

    return TaskItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      folderId: folderId ?? this.folderId,
      categoryId: categoryId ?? this.categoryId,
      dueDate: dueDate ?? this.dueDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      priority: priority ?? this.priority,
      status: resolvedStatus ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      reminderEnabled: resolvedRemMode != ReminderMode.off,
      reminderMode: resolvedRemMode,
      reminderTime:
          clearReminderTime ? null : (reminderTime ?? this.reminderTime),
      notificationId: notificationId ?? this.notificationId,
      repeatRule: repeatRule ?? this.repeatRule,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrence: clearRecurrence ? null : (recurrence ?? this.recurrence),
      recurringSeriesId: recurringSeriesId ?? this.recurringSeriesId,
      timezone: timezone ?? this.timezone,
      completedDates: completedDates ?? this.completedDates,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      version: version ?? this.version,
      lastSyncedVersion: lastSyncedVersion ?? this.lastSyncedVersion,
    );
  }
}
