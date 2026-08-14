import 'remote_change.dart';

/// SyncPullResponse — Represents the payload returned from a remote pull query.
class SyncPullResponse {
  final List<RemoteChange> changes;
  final String? nextCursor;
  final bool hasMore;

  const SyncPullResponse({
    required this.changes,
    this.nextCursor,
    required this.hasMore,
  });

  Map<String, dynamic> toMap() {
    return {
      'changes': changes.map((c) => c.toMap()).toList(),
      if (nextCursor != null) 'nextCursor': nextCursor,
      'hasMore': hasMore,
    };
  }

  factory SyncPullResponse.fromMap(Map<String, dynamic> map) {
    final rawChanges = map['changes'] as List? ?? [];
    return SyncPullResponse(
      changes: rawChanges
          .map((c) => RemoteChange.fromMap(Map<String, dynamic>.from(c as Map)))
          .toList(),
      nextCursor: map['nextCursor'] as String?,
      hasMore: map['hasMore'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncPullResponse &&
          runtimeType == other.runtimeType &&
          nextCursor == other.nextCursor &&
          hasMore == other.hasMore;

  @override
  int get hashCode => nextCursor.hashCode ^ hasMore.hashCode;

  @override
  String toString() =>
      'SyncPullResponse(changesCount: ${changes.length}, nextCursor: $nextCursor, hasMore: $hasMore)';
}
