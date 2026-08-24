/// RemoteChange — Represents a single entity change received from remote cloud backend.
class RemoteChange {
  final String entityType;
  final String entityId;
  final String userId;
  final String operation;
  final int remoteVersion;
  final Map<String, dynamic>? payload;
  final DateTime serverTimestamp;

  const RemoteChange({
    required this.entityType,
    required this.entityId,
    required this.userId,
    required this.operation,
    required this.remoteVersion,
    this.payload,
    required this.serverTimestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'entityType': entityType,
      'entityId': entityId,
      'userId': userId,
      'operation': operation,
      'remoteVersion': remoteVersion,
      if (payload != null) 'payload': payload,
      'serverTimestamp': serverTimestamp.toIso8601String(),
    };
  }

  factory RemoteChange.fromMap(Map<String, dynamic> map) {
    return RemoteChange(
      entityType: map['entityType'] as String,
      entityId: map['entityId'] as String,
      userId: map['userId'] as String,
      operation: map['operation'] as String,
      remoteVersion: (map['remoteVersion'] as num).toInt(),
      payload: map['payload'] != null
          ? Map<String, dynamic>.from(map['payload'] as Map)
          : null,
      serverTimestamp: DateTime.parse(map['serverTimestamp'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RemoteChange &&
          runtimeType == other.runtimeType &&
          entityType == other.entityType &&
          entityId == other.entityId &&
          userId == other.userId &&
          operation == other.operation &&
          remoteVersion == other.remoteVersion &&
          serverTimestamp == other.serverTimestamp;

  @override
  int get hashCode =>
      entityType.hashCode ^
      entityId.hashCode ^
      userId.hashCode ^
      operation.hashCode ^
      remoteVersion.hashCode ^
      serverTimestamp.hashCode;

  @override
  String toString() {
    return 'RemoteChange(entityType: $entityType, entityId: $entityId, userId: $userId, operation: $operation, remoteVersion: $remoteVersion)';
  }
}
