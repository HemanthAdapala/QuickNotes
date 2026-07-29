enum RepeatRule {
  none,
  daily,
  weekdays,
  weekly,
  monthly,
  yearly,
}

extension RepeatRuleExtension on RepeatRule {
  String toDbString() => name;

  static RepeatRule fromDbString(String? value) {
    if (value == null || value.isEmpty) return RepeatRule.none;
    return RepeatRule.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => RepeatRule.none,
    );
  }
}
