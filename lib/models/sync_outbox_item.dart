import 'dart:convert';

/// SyncOutboxItem — Domain model representing an outbox mutation record queued for cloud sync.
class SyncOutboxItem {
  final int? localSequence;
  final String id;
  final String operationId;
  final String userId;
  final String entityType; // 'note', 'folder', 'task'
  final String entityId;
  final String operation; // 'create', 'update', 'delete'
  final String payload; // Full JSON snapshot string
  final int localVersion;
  final DateTime createdAt;
  final int attemptCount;
  final String status; // 'pending', 'in_flight', 'failed', 'synced'
  final DateTime? lastAttemptAt;
  final DateTime? nextAttemptAt;
  final String? lastError;

  SyncOutboxItem({
    this.localSequence,
    required this.id,
    required this.operationId,
    required this.userId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.localVersion,
    required this.createdAt,
    this.attemptCount = 0,
    this.status = 'pending',
    this.lastAttemptAt,
    this.nextAttemptAt,
    this.lastError,
  });

  Map<String, dynamic> toMap() {
    return {
      if (localSequence != null) 'localSequence': localSequence,
      'id': id,
      'operationId': operationId,
      'userId': userId,
      'entityType': entityType,
      'entityId': entityId,
      'operation': operation,
      'payload': payload,
      'localVersion': localVersion,
      'createdAt': createdAt.toIso8601String(),
      'attemptCount': attemptCount,
      'status': status,
      'lastAttemptAt': lastAttemptAt?.toIso8601String(),
      'nextAttemptAt': nextAttemptAt?.toIso8601String(),
      'lastError': lastError,
    };
  }

  factory SyncOutboxItem.fromMap(Map<String, dynamic> map) {
    return SyncOutboxItem(
      localSequence: map['localSequence'] as int?,
      id: map['id'] as String,
      operationId: map['operationId'] as String,
      userId: map['userId'] as String,
      entityType: map['entityType'] as String,
      entityId: map['entityId'] as String,
      operation: map['operation'] as String,
      payload: map['payload'] as String,
      localVersion: map['localVersion'] as int,
      createdAt: DateTime.parse(map['createdAt'] as String),
      attemptCount: map['attemptCount'] as int? ?? 0,
      status: map['status'] as String? ?? 'pending',
      lastAttemptAt: map['lastAttemptAt'] != null
          ? DateTime.parse(map['lastAttemptAt'] as String)
          : null,
      nextAttemptAt: map['nextAttemptAt'] != null
          ? DateTime.parse(map['nextAttemptAt'] as String)
          : null,
      lastError: map['lastError'] as String?,
    );
  }

  Map<String, dynamic> get payloadMap =>
      jsonDecode(payload) as Map<String, dynamic>;

  SyncOutboxItem copyWith({
    int? localSequence,
    String? id,
    String? operationId,
    String? userId,
    String? entityType,
    String? entityId,
    String? operation,
    String? payload,
    int? localVersion,
    DateTime? createdAt,
    int? attemptCount,
    String? status,
    DateTime? lastAttemptAt,
    DateTime? nextAttemptAt,
    String? lastError,
  }) {
    return SyncOutboxItem(
      localSequence: localSequence ?? this.localSequence,
      id: id ?? this.id,
      operationId: operationId ?? this.operationId,
      userId: userId ?? this.userId,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      operation: operation ?? this.operation,
      payload: payload ?? this.payload,
      localVersion: localVersion ?? this.localVersion,
      createdAt: createdAt ?? this.createdAt,
      attemptCount: attemptCount ?? this.attemptCount,
      status: status ?? this.status,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      lastError: lastError ?? this.lastError,
    );
  }
}
