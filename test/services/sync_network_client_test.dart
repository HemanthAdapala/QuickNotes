import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:quick_notes/models/sync_mutation_request.dart';
import 'package:quick_notes/models/sync_mutation_ack.dart';
import 'package:quick_notes/models/sync_pull_request.dart';
import 'package:quick_notes/models/remote_change.dart';
import 'package:quick_notes/models/sync_pull_response.dart';
import 'package:quick_notes/services/sync_network_client.dart';

/// Fake implementation of SyncNetworkClient for contract testing.
class FakeSyncNetworkClient implements SyncNetworkClient {
  bool pushCalled = false;
  bool pullCalled = false;
  String? lastAuthToken;

  @override
  Future<SyncPushResult> pushMutations({
    required String userId,
    required String authToken,
    required List<SyncMutationRequest> mutations,
  }) async {
    pushCalled = true;
    lastAuthToken = authToken;
    final acks = mutations.map((m) {
      return SyncMutationAck(
        operationId: m.operationId,
        entityType: m.entityType,
        entityId: m.entityId,
        localVersion: m.localVersion,
        status: SyncAckStatus.acknowledged,
        remoteVersion: m.localVersion + 1,
      );
    }).toList();
    return SyncPushResult(acknowledgements: acks);
  }

  @override
  Future<SyncPullResponse> pullChanges({
    required String userId,
    required String authToken,
    required SyncPullRequest request,
  }) async {
    pullCalled = true;
    lastAuthToken = authToken;
    return SyncPullResponse(
      changes: [
        RemoteChange(
          entityType: 'note',
          entityId: 'note_123',
          userId: userId,
          operation: 'update',
          remoteVersion: 10,
          payload: {'title': 'Remote Title'},
          serverTimestamp: DateTime.parse('2026-08-14T12:00:00.000Z'),
        ),
      ],
      nextCursor: 'cursor_page_2',
      hasMore: true,
    );
  }
}

void main() {
  group('Phase 1.7.2 — Sync Network Contract & Transport Boundary Tests', () {
    test('1. SyncMutationRequest construction and serialization', () {
      final now = DateTime.parse('2026-08-14T12:00:00.000Z');
      const opId = 'op_12345_uuid';
      const entityId = 'note_999';

      final request = SyncMutationRequest(
        operationId: opId,
        entityType: 'note',
        entityId: entityId,
        operation: 'update',
        localVersion: 5,
        payload: {'title': 'Updated Title', 'content': 'Test Content'},
        createdAt: now,
      );

      final map = request.toMap();
      expect(map['operationId'], equals(opId));
      expect(map['entityType'], equals('note'));
      expect(map['entityId'], equals(entityId));
      expect(map['operation'], equals('update'));
      expect(map['localVersion'], equals(5));
      expect(map['payload'], equals({'title': 'Updated Title', 'content': 'Test Content'}));
      expect(map['createdAt'], equals('2026-08-14T12:00:00.000Z'));

      final restored = SyncMutationRequest.fromMap(map);
      expect(restored, equals(request));
      expect(restored.operationId, equals(opId));
      expect(restored.localVersion, equals(5));
    });

    test('2. SyncMutationAck acknowledged & stale status parsing', () {
      final ackObj = SyncMutationAck(
        operationId: 'op_abc',
        entityType: 'folder',
        entityId: 'folder_777',
        localVersion: 3,
        status: SyncAckStatus.acknowledged,
        remoteVersion: 4,
      );

      final mapAck = ackObj.toMap();
      expect(mapAck['status'], equals('acknowledged'));

      final restoredAck = SyncMutationAck.fromMap(mapAck);
      expect(restoredAck.status, equals(SyncAckStatus.acknowledged));
      expect(restoredAck.remoteVersion, equals(4));

      final staleAck = SyncMutationAck(
        operationId: 'op_def',
        entityType: 'task',
        entityId: 'task_888',
        localVersion: 2,
        status: SyncAckStatus.stale,
        remoteVersion: null,
      );

      final mapStale = staleAck.toMap();
      expect(mapStale['status'], equals('stale'));

      final restoredStale = SyncMutationAck.fromMap(mapStale);
      expect(restoredStale.status, equals(SyncAckStatus.stale));
      expect(restoredStale.remoteVersion, null);
    });

    test('3. Invalid SyncAckStatus throws FormatException', () {
      expect(
        () => SyncAckStatusExtension.fromValue('invalid_status'),
        throwsA(isA<FormatException>()),
      );
    });

    test('4. SyncPullRequest construction, serialization & validation', () {
      final reqNullCursor = SyncPullRequest(limit: 25);
      final mapNull = reqNullCursor.toMap();
      expect(mapNull.containsKey('cursor'), isFalse);
      expect(mapNull['limit'], equals(25));

      final restoredNull = SyncPullRequest.fromMap(mapNull);
      expect(restoredNull.cursor, isNull);
      expect(restoredNull.limit, equals(25));

      final reqCursor = SyncPullRequest(cursor: 'token_abc', limit: 100);
      final mapCursor = reqCursor.toMap();
      expect(mapCursor['cursor'], equals('token_abc'));
      expect(mapCursor['limit'], equals(100));

      expect(() => SyncPullRequest(limit: 0), throwsA(isA<ArgumentError>()));
      expect(() => SyncPullRequest(limit: -5), throwsA(isA<ArgumentError>()));
    });

    test('5. RemoteChange construction and serialization', () {
      final now = DateTime.parse('2026-08-14T12:00:00.000Z');
      final change = RemoteChange(
        entityType: 'note',
        entityId: 'note_555',
        userId: 'usr_canonical_123',
        operation: 'create',
        remoteVersion: 1,
        payload: {'title': 'New Note'},
        serverTimestamp: now,
      );

      final map = change.toMap();
      expect(map['entityType'], equals('note'));
      expect(map['remoteVersion'], equals(1));

      final restored = RemoteChange.fromMap(map);
      expect(restored, equals(change));
      expect(restored.remoteVersion, equals(1));
    });

    test('6. RemoteChange supports null payload for deletions', () {
      final now = DateTime.parse('2026-08-14T12:00:00.000Z');
      final delChange = RemoteChange(
        entityType: 'task',
        entityId: 'task_333',
        userId: 'usr_canonical_123',
        operation: 'delete',
        remoteVersion: 7,
        payload: null,
        serverTimestamp: now,
      );

      final map = delChange.toMap();
      expect(map.containsKey('payload'), isFalse);

      final restored = RemoteChange.fromMap(map);
      expect(restored.payload, isNull);
      expect(restored.operation, equals('delete'));
    });

    test('7. SyncPullResponse serialization', () {
      final now = DateTime.parse('2026-08-14T12:00:00.000Z');
      final response = SyncPullResponse(
        changes: [
          RemoteChange(
            entityType: 'note',
            entityId: 'n1',
            userId: 'usr_1',
            operation: 'update',
            remoteVersion: 2,
            payload: {'title': 'Title'},
            serverTimestamp: now,
          ),
        ],
        nextCursor: 'next_page_token',
        hasMore: true,
      );

      final map = response.toMap();
      expect(map['hasMore'], isTrue);
      expect(map['nextCursor'], equals('next_page_token'));

      final restored = SyncPullResponse.fromMap(map);
      expect(restored.hasMore, isTrue);
      expect(restored.nextCursor, equals('next_page_token'));
      expect(restored.changes.length, equals(1));
    });

    test('8. SyncNetworkErrorType categories representation', () {
      expect(SyncNetworkErrorType.values, containsAll([
        SyncNetworkErrorType.authenticationFailure,
        SyncNetworkErrorType.transientFailure,
        SyncNetworkErrorType.permanentRejection,
        SyncNetworkErrorType.malformedResponse,
      ]));

      const ex = SyncNetworkException(
        type: SyncNetworkErrorType.authenticationFailure,
        message: 'Invalid authorization token',
      );

      expect(ex.type, equals(SyncNetworkErrorType.authenticationFailure));
      expect(ex.toString(), contains('authenticationFailure'));
    });

    test('9. FakeSyncNetworkClient pushMutations and pullChanges contract verification', () async {
      final client = FakeSyncNetworkClient();
      const testToken = 'bearer_secret_id_token_123';
      const userId = 'usr_canonical_999';

      final request = SyncMutationRequest(
        operationId: const Uuid().v4(),
        entityType: 'note',
        entityId: 'note_111',
        operation: 'create',
        localVersion: 1,
        payload: {'title': 'Push Test'},
        createdAt: DateTime.now(),
      );

      final pushResult = await client.pushMutations(
        userId: userId,
        authToken: testToken,
        mutations: [request],
      );

      expect(client.pushCalled, isTrue);
      expect(client.lastAuthToken, equals(testToken));
      expect(pushResult.acknowledgements.length, equals(1));
      expect(pushResult.acknowledgements.first.operationId, equals(request.operationId));

      final pullResult = await client.pullChanges(
        userId: userId,
        authToken: testToken,
        request: SyncPullRequest(limit: 50),
      );

      expect(client.pullCalled, isTrue);
      expect(pullResult.changes.length, equals(1));
      expect(pullResult.hasMore, isTrue);
    });

    test('10. Security verification: Token is excluded from request serializations', () {
      final request = SyncMutationRequest(
        operationId: 'op_sec_test',
        entityType: 'note',
        entityId: 'n_sec',
        operation: 'update',
        localVersion: 1,
        payload: {'title': 'Security Test'},
        createdAt: DateTime.now(),
      );

      final map = request.toMap();
      expect(map.containsKey('authToken'), isFalse);
      expect(map.containsKey('bearer'), isFalse);
      expect(map.containsKey('idToken'), isFalse);
    });
  });
}
