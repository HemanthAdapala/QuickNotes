import 'dart:convert';
import 'task_status.dart';
import 'repeat_rule.dart';
import 'recurrence_rule.dart';

class TaskItem {
  final String id;
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
  final DateTime? reminderTime;
  final int notificationId;
  final RepeatRule repeatRule;
  final bool isRecurring;
  final RecurrenceRule? recurrence;
  final String? recurringSeriesId;
  final String timezone;
  final List<String> completedDates;

  TaskItem({
    required this.id,
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
    this.reminderTime,
    int? notificationId,
    RepeatRule? repeatRule,
    bool? isRecurring,
    this.recurrence,
    this.recurringSeriesId,
    String? timezone,
    this.completedDates = const [],
  })  : status = status ??
            ((completed ?? false) ? TaskStatus.completed : TaskStatus.waiting),
        createdAt = (createdAt ?? DateTime.now()).toUtc(),
        updatedAt = (updatedAt ?? DateTime.now()).toUtc(),
        reminderEnabled = reminderEnabled ?? (reminderTime != null),
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
  bool get isWaiting => status == TaskStatus.waiting || status == TaskStatus.scheduled;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
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
      'reminderTime': reminderTime?.toUtc().toIso8601String(),
      'notificationId': notificationId,
      'repeatRule': repeatRule.toDbString(),
      'isRecurring': isRecurring ? 1 : 0,
      'recurrenceRule': recurrence?.jsonEncodePayload(),
      'recurringSeriesId': recurringSeriesId,
      'timezone': timezone,
      'completedDates': jsonEncode(completedDates),
    };
  }

  factory TaskItem.fromMap(Map<String, dynamic> map) {
    final statusVal = TaskStatusExtension.fromDbString(map['status'] as String?);
    final rawCompleted = (map['completed'] as int? ?? (map['isCompleted'] as int? ?? 0)) == 1;

    // Resolve authoritative status, defaulting from completed boolean if status column was null
    final finalStatus = map['status'] != null
        ? statusVal
        : (rawCompleted ? TaskStatus.completed : TaskStatus.waiting);

    final rawDueDate = DateTime.tryParse(map['dueDate'] as String? ?? '') ?? DateTime.now();
    final rawCreatedAt = DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now();
    final rawUpdatedAt = DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now();

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

    return TaskItem(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      folderId: map['folderId'] as String?,
      categoryId: map['categoryId'] as String?,
      dueDate: rawDueDate.toUtc(),
      startTime: map['startTime'] != null ? DateTime.tryParse(map['startTime'] as String)?.toUtc() : null,
      endTime: map['endTime'] != null ? DateTime.tryParse(map['endTime'] as String)?.toUtc() : null,
      priority: map['priority'] as String? ?? 'None',
      status: finalStatus,
      createdAt: rawCreatedAt.toUtc(),
      updatedAt: rawUpdatedAt.toUtc(),
      completedAt: map['completedAt'] != null ? DateTime.tryParse(map['completedAt'] as String)?.toUtc() : null,
      reminderEnabled: (map['reminderEnabled'] as int? ?? 0) == 1 || map['reminderTime'] != null,
      reminderTime: map['reminderTime'] != null ? DateTime.tryParse(map['reminderTime'] as String)?.toUtc() : null,
      notificationId: map['notificationId'] as int? ?? 0,
      repeatRule: RepeatRuleExtension.fromDbString(map['repeatRule'] as String?),
      isRecurring: rawIsRec,
      recurrence: recRule,
      recurringSeriesId: map['recurringSeriesId'] as String?,
      timezone: map['timezone'] as String? ?? DateTime.now().timeZoneName,
      completedDates: rawCompletedDates,
    );
  }

  TaskItem copyWith({
    String? id,
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
    bool? reminderEnabled,
    DateTime? reminderTime,
    int? notificationId,
    RepeatRule? repeatRule,
    bool? isRecurring,
    RecurrenceRule? recurrence,
    String? recurringSeriesId,
    String? timezone,
    List<String>? completedDates,
  }) {
    // If completed is passed explicitly, map it to status if status is not provided
    TaskStatus? resolvedStatus = status;
    if (resolvedStatus == null && completed != null) {
      resolvedStatus = completed ? TaskStatus.completed : TaskStatus.waiting;
    }

    return TaskItem(
      id: id ?? this.id,
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
      completedAt: completedAt ?? this.completedAt,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
      notificationId: notificationId ?? this.notificationId,
      repeatRule: repeatRule ?? this.repeatRule,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrence: recurrence ?? this.recurrence,
      recurringSeriesId: recurringSeriesId ?? this.recurringSeriesId,
      timezone: timezone ?? this.timezone,
      completedDates: completedDates ?? this.completedDates,
    );
  }
}
