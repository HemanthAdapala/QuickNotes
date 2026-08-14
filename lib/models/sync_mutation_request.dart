/// SyncMutationRequest — Represents an outbox mutation crossing the network boundary.
///
/// Encapsulates local mutation metadata for transport to a remote server.
/// Preserves immutable [operationId] for retry idempotency across network calls.
class SyncMutationRequest {
  final String operationId;
  final String entityType;
  final String entityId;
  final String operation;
  final int localVersion;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  const SyncMutationRequest({
    required this.operationId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.localVersion,
    required this.payload,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'operationId': operationId,
      'entityType': entityType,
      'entityId': entityId,
      'operation': operation,
      'localVersion': localVersion,
      'payload': payload,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SyncMutationRequest.fromMap(Map<String, dynamic> map) {
    return SyncMutationRequest(
      operationId: map['operationId'] as String,
      entityType: map['entityType'] as String,
      entityId: map['entityId'] as String,
      operation: map['operation'] as String,
      localVersion: (map['localVersion'] as num).toInt(),
      payload: Map<String, dynamic>.from(map['payload'] as Map),
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncMutationRequest &&
          runtimeType == other.runtimeType &&
          operationId == other.operationId &&
          entityType == other.entityType &&
          entityId == other.entityId &&
          operation == other.operation &&
          localVersion == other.localVersion &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      operationId.hashCode ^
      entityType.hashCode ^
      entityId.hashCode ^
      operation.hashCode ^
      localVersion.hashCode ^
      createdAt.hashCode;

  @override
  String toString() {
    return 'SyncMutationRequest(operationId: $operationId, entityType: $entityType, entityId: $entityId, operation: $operation, localVersion: $localVersion)';
  }
}
