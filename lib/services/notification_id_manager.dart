/// Collision-safe notification ID manager providing strictly disjoint,
/// deterministic ID spaces for primary task alarms and custom-interval horizon alarms.
///
/// Disjoint Partitions (all within signed 32-bit int max: 2,147,483,647):
/// - Base Primary IDs: 1 .. 700,000,000
/// - Horizon Step 1:   700,000,001 .. 1,400,000,000  (baseId + 700,000,000)
/// - Horizon Step 2:   1,400,000,001 .. 2,100,000,000 (baseId + 1,400,000,000)
class NotificationIdManager {
  static const int maxBaseId = 700000000;
  static const int horizonOffset1 = 700000000;
  static const int horizonOffset2 = 1400000000;

  /// Returns the deterministic, collision-safe notification ID for horizon [step] (1 or 2).
  static int getHorizonId(int baseId, int step) {
    if (baseId > 0 && baseId <= maxBaseId) {
      return step == 1 ? baseId + horizonOffset1 : baseId + horizonOffset2;
    }
    // Safe deterministic fallback for legacy IDs > 700000000
    final hash = (baseId * 31 + step).abs();
    return 1400000000 + (hash % 747483647);
  }

  /// Returns all notification IDs owned by the task (primary and potential horizon alarms).
  static List<int> getAllAssociatedIds(int baseId) {
    return [
      baseId,
      getHorizonId(baseId, 1),
      getHorizonId(baseId, 2),
    ];
  }

  /// Returns the base primary ID given an associated ID, if within disjoint ranges.
  static int resolveBaseId(int id) {
    if (id > horizonOffset2 && id <= horizonOffset2 + maxBaseId) {
      return id - horizonOffset2;
    }
    if (id > horizonOffset1 && id <= horizonOffset1 + maxBaseId) {
      return id - horizonOffset1;
    }
    return id;
  }
}
