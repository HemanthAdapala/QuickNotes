import 'dart:convert';

/// Immutable domain model representing the public aggregate snapshot
/// synchronized with OS-level Home Screen Widgets (Android AppWidget & iOS WidgetKit).
///
/// **Data Minimization & Privacy Guarantee:**
/// This payload contains ONLY high-level aggregate statistics and date strings.
/// It MUST NEVER contain note titles, note content, task titles, user IDs, emails,
/// encryption keys, or PIN credentials.
class WidgetSnapshotPayload {
  /// Schema contract version for backwards compatibility.
  final int version;

  /// UTC ISO-8601 timestamp when this snapshot was generated.
  final DateTime updatedAt;

  /// Localized day name for display (e.g. "Friday").
  final String dateDayName;

  /// Localized short date string for display (e.g. "28 Aug").
  final String dateFormatted;

  /// Total count of active, unlocked, pinned notes.
  final int pinnedNotesCount;

  /// Total count of active, uncompleted tasks due today.
  final int pendingTasksCount;

  /// Total count of active, uncompleted tasks whose due date is before today.
  final int overdueTasksCount;

  /// Whether an active user session (offline or authenticated) is present.
  final bool hasActiveSession;

  /// Canonical storage key for HomeWidget shared preferences / user defaults.
  static const String storageKey = 'quicknotes_widget_snapshot';

  const WidgetSnapshotPayload({
    this.version = 1,
    required this.updatedAt,
    required this.dateDayName,
    required this.dateFormatted,
    this.pinnedNotesCount = 0,
    this.pendingTasksCount = 0,
    this.overdueTasksCount = 0,
    this.hasActiveSession = true,
  });

  /// Factory producing a sanitized signed-out / empty state.
  factory WidgetSnapshotPayload.empty({DateTime? now}) {
    final effectiveNow = now ?? DateTime.now();
    return WidgetSnapshotPayload(
      version: 1,
      updatedAt: effectiveNow.toUtc(),
      dateDayName: '',
      dateFormatted: '',
      pinnedNotesCount: 0,
      pendingTasksCount: 0,
      overdueTasksCount: 0,
      hasActiveSession: false,
    );
  }

  /// Converts the payload into a Map conforming to the JSON schema.
  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'date_day_name': dateDayName,
      'date_formatted': dateFormatted,
      'pinned_notes_count': pinnedNotesCount,
      'pending_tasks_count': pendingTasksCount,
      'overdue_tasks_count': overdueTasksCount,
      'has_active_session': hasActiveSession,
    };
  }

  /// Serializes the payload into a compact JSON string.
  String toJsonString() => jsonEncode(toJson());

  /// Deserializes a Map into a [WidgetSnapshotPayload] with resilient fallbacks.
  factory WidgetSnapshotPayload.fromJson(Map<String, dynamic> json) {
    final rawUpdatedAt = json['updated_at'] as String?;
    DateTime parsedUpdatedAt;
    if (rawUpdatedAt != null) {
      parsedUpdatedAt =
          DateTime.tryParse(rawUpdatedAt)?.toUtc() ?? DateTime.now().toUtc();
    } else {
      parsedUpdatedAt = DateTime.now().toUtc();
    }

    return WidgetSnapshotPayload(
      version: json['version'] as int? ?? 1,
      updatedAt: parsedUpdatedAt,
      dateDayName: json['date_day_name'] as String? ?? '',
      dateFormatted: json['date_formatted'] as String? ?? '',
      pinnedNotesCount: json['pinned_notes_count'] as int? ?? 0,
      pendingTasksCount: json['pending_tasks_count'] as int? ?? 0,
      overdueTasksCount: json['overdue_tasks_count'] as int? ?? 0,
      hasActiveSession: json['has_active_session'] as bool? ?? true,
    );
  }

  /// Deserializes a JSON string into a [WidgetSnapshotPayload].
  factory WidgetSnapshotPayload.fromJsonString(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) {
        return WidgetSnapshotPayload.fromJson(decoded);
      } else if (decoded is Map) {
        return WidgetSnapshotPayload.fromJson(
            Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      // Graceful fallback on malformed JSON
    }
    return WidgetSnapshotPayload.empty();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WidgetSnapshotPayload &&
          runtimeType == other.runtimeType &&
          version == other.version &&
          updatedAt == other.updatedAt &&
          dateDayName == other.dateDayName &&
          dateFormatted == other.dateFormatted &&
          pinnedNotesCount == other.pinnedNotesCount &&
          pendingTasksCount == other.pendingTasksCount &&
          overdueTasksCount == other.overdueTasksCount &&
          hasActiveSession == other.hasActiveSession;

  @override
  int get hashCode =>
      version.hashCode ^
      updatedAt.hashCode ^
      dateDayName.hashCode ^
      dateFormatted.hashCode ^
      pinnedNotesCount.hashCode ^
      pendingTasksCount.hashCode ^
      overdueTasksCount.hashCode ^
      hasActiveSession.hashCode;

  @override
  String toString() {
    return 'WidgetSnapshotPayload(version: $version, updatedAt: $updatedAt, '
        'date: $dateDayName $dateFormatted, pinned: $pinnedNotesCount, '
        'pending: $pendingTasksCount, overdue: $overdueTasksCount, '
        'hasActiveSession: $hasActiveSession)';
  }
}
