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
  final List<String> excludedDates;

  const RecurrenceRule({
    this.version = 1,
    required this.type,
    this.interval = 1,
    this.endDate,
    this.maxOccurrences,
    this.excludedDates = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'version': version,
      'type': type.toDbString(),
      'interval': interval,
      'endDate': endDate?.toUtc().toIso8601String(),
      'maxOccurrences': maxOccurrences,
      'excludedDates': excludedDates,
    };
  }

  factory RecurrenceRule.fromMap(Map<String, dynamic> map) {
    final typeVal =
        RecurrenceTypeExtension.fromDbString(map['type'] as String?);
    final rawEndDate = map['endDate'] as String?;
    final rawExcluded = map['excludedDates'];
    final List<String> excluded = rawExcluded is List
        ? rawExcluded.map((e) => e.toString()).toList()
        : const [];

    return RecurrenceRule(
      version: map['version'] as int? ?? 1,
      type: typeVal,
      interval: map['interval'] as int? ?? 1,
      endDate:
          rawEndDate != null ? DateTime.tryParse(rawEndDate)?.toUtc() : null,
      maxOccurrences: map['maxOccurrences'] as int?,
      excludedDates: excluded,
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
    List<String>? excludedDates,
  }) {
    return RecurrenceRule(
      version: version ?? this.version,
      type: type ?? this.type,
      interval: interval ?? this.interval,
      endDate: endDate ?? this.endDate,
      maxOccurrences: maxOccurrences ?? this.maxOccurrences,
      excludedDates: excludedDates ?? this.excludedDates,
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
          maxOccurrences == other.maxOccurrences &&
          _areListsEqual(excludedDates, other.excludedDates);

  static bool _areListsEqual(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      version.hashCode ^
      type.hashCode ^
      interval.hashCode ^
      endDate.hashCode ^
      maxOccurrences.hashCode ^
      Object.hashAll(excludedDates);
}
