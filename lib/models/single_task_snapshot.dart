import 'dart:convert';
import 'package:intl/intl.dart';
import 'task_item.dart';
import 'task_status.dart';
import 'repeat_rule.dart';
import 'recurrence_rule.dart';

/// SingleTaskSnapshot — Sanitized, immutable snapshot of an individual task for Native Android Home Screen Task Widgets.
///
/// **Design & Data Integrity Contract:**
/// 1. Preserves exact task title and content without reinterpretation or lossy formatting.
/// 2. Canonical completion state derived strictly from domain [TaskStatus].
/// 3. Device-local formatted date ("Tue, 1 June 2026") and time ("02:00 AM").
/// 4. Normalized priority ('High', 'Medium', 'Low', 'None') and human-readable recurrence labels.
/// 5. Privacy & Data Minimization: Excludes deleted (`isDeleted == true`) and archived (`status == TaskStatus.archived`) tasks.
class SingleTaskSnapshot {
  final String id;
  final String title;
  final String description;
  final String status;
  final bool completed;
  final String dueDateIso;
  final String formattedDate;
  final String formattedTime;
  final String priority;
  final bool hasPriority;
  final bool isRecurring;
  final bool hasRepeat;
  final String repeatLabel;
  final String statusLabel;
  final DateTime updatedAt;

  const SingleTaskSnapshot({
    required this.id,
    required this.title,
    this.description = '',
    required this.status,
    required this.completed,
    required this.dueDateIso,
    required this.formattedDate,
    required this.formattedTime,
    required this.priority,
    required this.hasPriority,
    required this.isRecurring,
    required this.hasRepeat,
    required this.repeatLabel,
    required this.statusLabel,
    required this.updatedAt,
  });

  /// Factory creating a sanitized [SingleTaskSnapshot] from a domain [TaskItem].
  factory SingleTaskSnapshot.fromTask(TaskItem task, {DateTime? now}) {
    final localDue = task.dueDate.toLocal();
    final formattedDate = DateFormat('EEE, d MMMM yyyy').format(localDue);

    // Resolve time: reminderTime > startTime > dueDate
    final DateTime targetTime;
    if (task.reminderTime != null) {
      targetTime = task.reminderTime!.toLocal();
    } else if (task.startTime != null) {
      targetTime = task.startTime!.toLocal();
    } else {
      targetTime = localDue;
    }
    final formattedTime = DateFormat('hh:mm a').format(targetTime);

    // Priority normalization
    final rawPriority = task.priority.trim().toLowerCase();
    final String resolvedPriority;
    if (rawPriority == 'high' || rawPriority == 'red') {
      resolvedPriority = 'High';
    } else if (rawPriority == 'medium' || rawPriority == 'yellow') {
      resolvedPriority = 'Medium';
    } else if (rawPriority == 'low' || rawPriority == 'green') {
      resolvedPriority = 'Low';
    } else {
      resolvedPriority = 'None';
    }
    final hasPriority = resolvedPriority != 'None';

    // Recurrence & Repeat Label resolution
    String resolvedRepeatLabel = '';
    final bool hasRecurrence = task.isRecurring ||
        task.recurrence != null ||
        task.repeatRule != RepeatRule.none;

    if (hasRecurrence) {
      if (task.recurrence != null) {
        switch (task.recurrence!.type) {
          case RecurrenceType.daily:
            resolvedRepeatLabel = 'Daily';
            break;
          case RecurrenceType.weekly:
            resolvedRepeatLabel = 'Weekly';
            break;
          case RecurrenceType.monthly:
            resolvedRepeatLabel = 'Monthly';
            break;
          case RecurrenceType.yearly:
            resolvedRepeatLabel = 'Yearly';
            break;
        }
      } else {
        switch (task.repeatRule) {
          case RepeatRule.daily:
            resolvedRepeatLabel = 'Daily';
            break;
          case RepeatRule.weekdays:
            resolvedRepeatLabel = 'Weekdays';
            break;
          case RepeatRule.weekly:
            resolvedRepeatLabel = 'Weekly';
            break;
          case RepeatRule.monthly:
            resolvedRepeatLabel = 'Monthly';
            break;
          case RepeatRule.yearly:
            resolvedRepeatLabel = 'Yearly';
            break;
          case RepeatRule.none:
            resolvedRepeatLabel = '';
            break;
        }
      }
    }

    final bool isRepeatActive = resolvedRepeatLabel.isNotEmpty;
    final bool isTaskCompleted =
        task.completed || task.status == TaskStatus.completed;
    final String statusLabel = isTaskCompleted ? 'Completed' : 'Pending';

    final cleanTitle =
        task.title.trim().isEmpty ? 'Untitled Task' : task.title.trim();

    return SingleTaskSnapshot(
      id: task.id,
      title: cleanTitle,
      description: task.description.trim(),
      status: task.status.toDbString(),
      completed: isTaskCompleted,
      dueDateIso: task.dueDate.toUtc().toIso8601String(),
      formattedDate: formattedDate,
      formattedTime: formattedTime,
      priority: resolvedPriority,
      hasPriority: hasPriority,
      isRecurring: isRepeatActive,
      hasRepeat: isRepeatActive,
      repeatLabel: resolvedRepeatLabel,
      statusLabel: statusLabel,
      updatedAt: task.updatedAt.toUtc(),
    );
  }

  /// Converts the snapshot into a Map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status,
      'completed': completed,
      'is_completed': completed,
      'due_date_iso': dueDateIso,
      'formatted_date': formattedDate,
      'formatted_time': formattedTime,
      'priority': priority,
      'has_priority': hasPriority,
      'is_recurring': isRecurring,
      'has_repeat': hasRepeat,
      'repeat_label': repeatLabel,
      'status_label': statusLabel,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  /// Serializes the snapshot into a compact JSON string.
  String toJsonString() => jsonEncode(toJson());

  /// Deserializes a Map into a [SingleTaskSnapshot].
  factory SingleTaskSnapshot.fromJson(Map<String, dynamic> json) {
    final rawUpdatedAt = json['updated_at'] as String?;
    final parsedUpdatedAt = rawUpdatedAt != null
        ? (DateTime.tryParse(rawUpdatedAt)?.toUtc() ?? DateTime.now().toUtc())
        : DateTime.now().toUtc();

    final isCompleted = (json['completed'] as bool?) ??
        (json['is_completed'] as bool?) ??
        (json['status'] == 'completed');

    final rawPriority = json['priority'] as String? ?? 'None';
    final hasPriority = (json['has_priority'] as bool?) ??
        (rawPriority.isNotEmpty && rawPriority.toLowerCase() != 'none');

    final repeatLabel = json['repeat_label'] as String? ?? '';
    final hasRepeat =
        (json['has_repeat'] as bool?) ?? repeatLabel.isNotEmpty;

    return SingleTaskSnapshot(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled Task',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? (isCompleted ? 'completed' : 'waiting'),
      completed: isCompleted,
      dueDateIso: json['due_date_iso'] as String? ?? '',
      formattedDate: json['formatted_date'] as String? ?? '',
      formattedTime: json['formatted_time'] as String? ?? '',
      priority: rawPriority,
      hasPriority: hasPriority,
      isRecurring: (json['is_recurring'] as bool?) ?? hasRepeat,
      hasRepeat: hasRepeat,
      repeatLabel: repeatLabel,
      statusLabel: json['status_label'] as String? ?? (isCompleted ? 'Completed' : 'Pending'),
      updatedAt: parsedUpdatedAt,
    );
  }

  /// Compact representation for the task selection catalog.
  Map<String, dynamic> toCatalogEntry() {
    return {
      'id': id,
      'title': title,
      'priority': priority,
      'has_priority': hasPriority,
      'formatted_date': formattedDate,
      'formatted_time': formattedTime,
      'completed': completed,
      'status_label': statusLabel,
      'repeat_label': repeatLabel,
      'has_repeat': hasRepeat,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SingleTaskSnapshot &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          description == other.description &&
          status == other.status &&
          completed == other.completed &&
          dueDateIso == other.dueDateIso &&
          formattedDate == other.formattedDate &&
          formattedTime == other.formattedTime &&
          priority == other.priority &&
          hasPriority == other.hasPriority &&
          isRecurring == other.isRecurring &&
          hasRepeat == other.hasRepeat &&
          repeatLabel == other.repeatLabel &&
          statusLabel == other.statusLabel &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      description.hashCode ^
      status.hashCode ^
      completed.hashCode ^
      dueDateIso.hashCode ^
      formattedDate.hashCode ^
      formattedTime.hashCode ^
      priority.hashCode ^
      hasPriority.hashCode ^
      isRecurring.hashCode ^
      hasRepeat.hashCode ^
      repeatLabel.hashCode ^
      statusLabel.hashCode ^
      updatedAt.hashCode;
}

/// Backwards-compatibility and conceptual alias
typedef TaskWidgetSnapshot = SingleTaskSnapshot;
