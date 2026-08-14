/// SyncAckStatus — Outcome status of a push mutation acknowledgement.
enum SyncAckStatus {
  acknowledged,
  stale,
}

extension SyncAckStatusExtension on SyncAckStatus {
  String toValue() {
    switch (this) {
      case SyncAckStatus.acknowledged:
        return 'acknowledged';
      case SyncAckStatus.stale:
        return 'stale';
    }
  }

  static SyncAckStatus fromValue(String? value) {
    switch (value) {
      case 'acknowledged':
        return SyncAckStatus.acknowledged;
      case 'stale':
        return SyncAckStatus.stale;
      default:
        throw FormatException('Invalid SyncAckStatus value: $value');
    }
  }
}

/// SyncMutationAck — Authoritative server acknowledgement of a pushed mutation.
class SyncMutationAck {
  final String operationId;
  final String entityType;
  final String entityId;
  final int localVersion;
  final SyncAckStatus status;
  final int? remoteVersion;

  const SyncMutationAck({
    required this.operationId,
    required this.entityType,
    required this.entityId,
    required this.localVersion,
    required this.status,
    this.remoteVersion,
  });

  Map<String, dynamic> toMap() {
    return {
      'operationId': operationId,
      'entityType': entityType,
      'entityId': entityId,
      'localVersion': localVersion,
      'status': status.toValue(),
      if (remoteVersion != null) 'remoteVersion': remoteVersion,
    };
  }

  factory SyncMutationAck.fromMap(Map<String, dynamic> map) {
    return SyncMutationAck(
      operationId: map['operationId'] as String,
      entityType: map['entityType'] as String,
      entityId: map['entityId'] as String,
      localVersion: (map['localVersion'] as num).toInt(),
      status: SyncAckStatusExtension.fromValue(map['status'] as String?),
      remoteVersion: (map['remoteVersion'] as num?)?.toInt(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncMutationAck &&
          runtimeType == other.runtimeType &&
          operationId == other.operationId &&
          entityType == other.entityType &&
          entityId == other.entityId &&
          localVersion == other.localVersion &&
          status == other.status &&
          remoteVersion == other.remoteVersion;

  @override
  int get hashCode =>
      operationId.hashCode ^
      entityType.hashCode ^
      entityId.hashCode ^
      localVersion.hashCode ^
      status.hashCode ^
      remoteVersion.hashCode;

  @override
  String toString() {
    return 'SyncMutationAck(operationId: $operationId, entityType: $entityType, entityId: $entityId, localVersion: $localVersion, status: ${status.toValue()}, remoteVersion: $remoteVersion)';
  }
}
