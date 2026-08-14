/// SyncPullRequest — Encapsulates parameters for requesting delta updates from remote server.
class SyncPullRequest {
  final String? cursor;
  final int limit;

  SyncPullRequest({
    this.cursor,
    this.limit = 50,
  }) {
    if (limit <= 0) {
      throw ArgumentError('Limit must be greater than 0');
    }
  }

  Map<String, dynamic> toMap() {
    return {
      if (cursor != null) 'cursor': cursor,
      'limit': limit,
    };
  }

  factory SyncPullRequest.fromMap(Map<String, dynamic> map) {
    return SyncPullRequest(
      cursor: map['cursor'] as String?,
      limit: (map['limit'] as num? ?? 50).toInt(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncPullRequest &&
          runtimeType == other.runtimeType &&
          cursor == other.cursor &&
          limit == other.limit;

  @override
  int get hashCode => cursor.hashCode ^ limit.hashCode;

  @override
  String toString() => 'SyncPullRequest(cursor: $cursor, limit: $limit)';
}
