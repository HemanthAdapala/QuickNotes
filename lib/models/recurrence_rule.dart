import 'dart:convert';

enum RecurrenceType {
  daily,
  weekly,
  monthly,
  yearly,
}

extension RecurrenceTypeExtension on RecurrenceType {
  String toDbString() => name;

  static RecurrenceType fromDbString(String? value) {
    if (value == null || value.isEmpty) return RecurrenceType.daily;
    return RecurrenceType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => RecurrenceType.daily,
    );
  }

  String toDisplayString() {
    switch (this) {
      case RecurrenceType.daily:
        return 'Every Day';
      case RecurrenceType.weekly:
        return 'Every Week';
      case RecurrenceType.monthly:
        return 'Every Month';
      case RecurrenceType.yearly:
        return 'Every Year';
    }
  }
}

class RecurrenceRule {
  final int version;
  final RecurrenceType type;
  final int interval;
  final DateTime? endDate;
  final int? maxOccurrences;

  const RecurrenceRule({
    this.version = 1,
    required this.type,
    this.interval = 1,
    this.endDate,
    this.maxOccurrences,
  });

  Map<String, dynamic> toMap() {
    return {
      'version': version,
      'type': type.toDbString(),
      'interval': interval,
      'endDate': endDate?.toUtc().toIso8601String(),
      'maxOccurrences': maxOccurrences,
    };
  }

  factory RecurrenceRule.fromMap(Map<String, dynamic> map) {
    final typeVal =
        RecurrenceTypeExtension.fromDbString(map['type'] as String?);
    final rawEndDate = map['endDate'] as String?;
    return RecurrenceRule(
      version: map['version'] as int? ?? 1,
      type: typeVal,
      interval: map['interval'] as int? ?? 1,
      endDate:
          rawEndDate != null ? DateTime.tryParse(rawEndDate)?.toUtc() : null,
      maxOccurrences: map['maxOccurrences'] as int?,
    );
  }

  String jsonEncodePayload() => jsonEncode(toMap());

  static RecurrenceRule? tryDecode(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty || jsonStr.toLowerCase() == 'none') {
      return null;
    }
    try {
      final map = jsonDecode(jsonStr);
      if (map is Map<String, dynamic>) {
        return RecurrenceRule.fromMap(map);
      }
    } catch (_) {}
    return null;
  }

  RecurrenceRule copyWith({
    int? version,
    RecurrenceType? type,
    int? interval,
    DateTime? endDate,
    int? maxOccurrences,
  }) {
    return RecurrenceRule(
      version: version ?? this.version,
      type: type ?? this.type,
      interval: interval ?? this.interval,
      endDate: endDate ?? this.endDate,
      maxOccurrences: maxOccurrences ?? this.maxOccurrences,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecurrenceRule &&
          runtimeType == other.runtimeType &&
          version == other.version &&
          type == other.type &&
          interval == other.interval &&
          endDate == other.endDate &&
          maxOccurrences == other.maxOccurrences;

  @override
  int get hashCode =>
      version.hashCode ^
      type.hashCode ^
      interval.hashCode ^
      endDate.hashCode ^
      maxOccurrences.hashCode;
}
