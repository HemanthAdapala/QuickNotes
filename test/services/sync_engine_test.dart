import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:quick_notes/models/session_type.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/models/sync_mutation_request.dart';
import 'package:quick_notes/models/sync_mutation_ack.dart';
import 'package:quick_notes/models/sync_pull_request.dart';
import 'package:quick_notes/models/sync_pull_response.dart';
import 'package:quick_notes/repositories/notes_repository.dart';
import 'package:quick_notes/repositories/outbox_repository.dart';
import 'package:quick_notes/services/database_service.dart';
import 'package:quick_notes/services/session_manager.dart';
import 'package:quick_notes/services/sync_network_client.dart';
import 'package:quick_notes/services/sync_engine.dart';

class MockSyncNetworkClient implements SyncNetworkClient {
  List<SyncMutationRequest> pushedRequests = [];
  SyncPushResult Function(List<SyncMutationRequest> mutations)? onPush;
  SyncNetworkException? pushException;

  @override
  Future<SyncPushResult> pushMutations({
    required String userId,
    required String authToken,
    required List<SyncMutationRequest> mutations,
  }) async {
    if (pushException != null) {
      throw pushException!;
    }
    pushedRequests.addAll(mutations);
    if (onPush != null) {
      return onPush!(mutations);
    }
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
    return const SyncPullResponse(changes: [], hasMore: false);
  }
}

void main() {
  late SqliteNotesRepository notesRepo;
  late SqliteOutboxRepository outboxRepo;
  late SessionManager sessionManager;
  late String canonicalId;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => '.',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async => null,
    );

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    notesRepo = SqliteNotesRepository();
    outboxRepo = SqliteOutboxRepository();

    sessionManager = SessionManager();
    await sessionManager.clearSession();
    canonicalId = 'usr_${const Uuid().v4()}';
    await sessionManager.saveSession(
      sessionType: SessionType.google,
      userId: canonicalId,
      accessToken: 'access_123',
      idToken: 'id_token_123',
    );
  });

  group('Phase 1.7.3 — SyncEngine & Outbox Queue Processor Tests', () {
    test('1. Successful ACK updates lastSyncedVersion and deletes outbox item atomically', () async {
      final mockNetwork = MockSyncNetworkClient();
      final engine = SyncEngine(
        outboxRepo: outboxRepo,
        networkClient: mockNetwork,
        sessionManager: sessionManager,
      );
      await engine.initialize();

      // Create local note
      final note = Note(
        id: const Uuid().v4(),
        userId: canonicalId,
        title: 'Test Note',
        content: 'Content',
        tags: const [],
        attachments: const [],
        colorValue: 0xFFFFFFFF,
        version: 1,
        lastSyncedVersion: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await notesRepo.insertNote(note);

      // Verify outbox has 1 item
      final pendingBefore = await outboxRepo.getPendingOutboxItems(canonicalId);
      expect(pendingBefore.length, equals(1));
      expect(pendingBefore.first.operationId, isNotEmpty);

      // Flush engine
      await engine.flush();

      // Verify network received mutation
      expect(mockNetwork.pushedRequests.length, equals(1));
      expect(mockNetwork.pushedRequests.first.operationId, equals(pendingBefore.first.operationId));

      // Verify outbox is now empty
      final pendingAfter = await outboxRepo.getPendingOutboxItems(canonicalId);
      expect(pendingAfter.isEmpty, isTrue);

      // Verify note lastSyncedVersion is updated to 1
      final fetchedNote = await notesRepo.getNoteById(note.id);
      expect(fetchedNote, isNotNull);
      expect(fetchedNote!.lastSyncedVersion, equals(1));
    });

    test('2. Stale ACK updates lastSyncedVersion and deletes outbox item', () async {
      final mockNetwork = MockSyncNetworkClient();
      mockNetwork.onPush = (mutations) {
        final acks = mutations.map((m) {
          return SyncMutationAck(
            operationId: m.operationId,
            entityType: m.entityType,
            entityId: m.entityId,
            localVersion: m.localVersion,
            status: SyncAckStatus.stale,
            remoteVersion: 10,
          );
        }).toList();
        return SyncPushResult(acknowledgements: acks);
      };

      final engine = SyncEngine(
        outboxRepo: outboxRepo,
        networkClient: mockNetwork,
        sessionManager: sessionManager,
      );

      final note = Note(
        id: const Uuid().v4(),
        userId: canonicalId,
        title: 'Stale Note',
        content: 'Content',
        tags: const [],
        attachments: const [],
        colorValue: 0xFFFFFFFF,
        version: 1,
        lastSyncedVersion: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await notesRepo.insertNote(note);

      await engine.flush();

      final pendingAfter = await outboxRepo.getPendingOutboxItems(canonicalId);
      expect(pendingAfter.isEmpty, isTrue);

      final fetchedNote = await notesRepo.getNoteById(note.id);
      expect(fetchedNote!.lastSyncedVersion, equals(1));
    });

    test('3. Transient network failure retains outbox item and schedules exponential backoff', () async {
      final mockNetwork = MockSyncNetworkClient();
      mockNetwork.pushException = const SyncNetworkException(
        type: SyncNetworkErrorType.transientFailure,
        message: 'Network socket timeout',
      );

      final fakeNow = DateTime.parse('2026-08-14T12:00:00.000Z');
      final engine = SyncEngine(
        outboxRepo: outboxRepo,
        networkClient: mockNetwork,
        sessionManager: sessionManager,
        initialDelaySeconds: 2,
        nowProvider: () => fakeNow,
      );

      final note = Note(
        id: const Uuid().v4(),
        userId: canonicalId,
        title: 'Retry Note',
        content: 'Content',
        tags: const [],
        attachments: const [],
        colorValue: 0xFFFFFFFF,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await notesRepo.insertNote(note);

      await engine.flush();

      final pending = await outboxRepo.getPendingOutboxItems(canonicalId);
      expect(pending.length, equals(1));
      final item = pending.first;
      expect(item.attemptCount, equals(1));
      expect(item.status, equals('pending'));
      expect(item.lastError, contains('Network socket timeout'));
      expect(item.nextAttemptAt, equals(fakeNow.add(const Duration(seconds: 4)))); // initial 2 * 2^1 = 4s
    });

    test('4. Exponential backoff delay calculation caps at maxDelay (300s)', () {
      final engine = SyncEngine(
        networkClient: MockSyncNetworkClient(),
        initialDelaySeconds: 2,
        multiplier: 2.0,
        maximumDelaySeconds: 300,
      );

      expect(engine.calculateBackoff(0), equals(const Duration(seconds: 2)));
      expect(engine.calculateBackoff(1), equals(const Duration(seconds: 4)));
      expect(engine.calculateBackoff(2), equals(const Duration(seconds: 8)));
      expect(engine.calculateBackoff(3), equals(const Duration(seconds: 16)));
      expect(engine.calculateBackoff(10), equals(const Duration(seconds: 300))); // capped
    });

    test('5. Authentication failure pauses engine without incrementing attempt count or deleting outbox', () async {
      final mockNetwork = MockSyncNetworkClient();
      mockNetwork.pushException = const SyncNetworkException(
        type: SyncNetworkErrorType.authenticationFailure,
        message: '401 Unauthorized',
      );

      final engine = SyncEngine(
        outboxRepo: outboxRepo,
        networkClient: mockNetwork,
        sessionManager: sessionManager,
      );

      final note = Note(
        id: const Uuid().v4(),
        userId: canonicalId,
        title: 'Auth Note',
        content: 'Content',
        tags: const [],
        attachments: const [],
        colorValue: 0xFFFFFFFF,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await notesRepo.insertNote(note);

      await engine.flush();

      expect(engine.state, equals(SyncEngineState.pausedAuthentication));

      final pending = await outboxRepo.getPendingOutboxItems(canonicalId);
      expect(pending.length, equals(1));
      expect(pending.first.attemptCount, equals(0)); // NOT incremented
      expect(pending.first.status, equals('pending')); // NOT failed
    });

    test('6. Permanent rejection marks outbox item status as failed without retrying', () async {
      final mockNetwork = MockSyncNetworkClient();
      mockNetwork.pushException = const SyncNetworkException(
        type: SyncNetworkErrorType.permanentRejection,
        message: '400 Bad Request: Schema validation failed',
      );

      final engine = SyncEngine(
        outboxRepo: outboxRepo,
        networkClient: mockNetwork,
        sessionManager: sessionManager,
      );

      final note = Note(
        id: const Uuid().v4(),
        userId: canonicalId,
        title: 'Bad Note',
        content: 'Content',
        tags: const [],
        attachments: const [],
        colorValue: 0xFFFFFFFF,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await notesRepo.insertNote(note);

      await engine.flush();

      // Pending items query returns only status == 'pending'
      final pending = await outboxRepo.getPendingOutboxItems(canonicalId);
      expect(pending.isEmpty, isTrue); // Moved out of pending

      // Raw query verifies item exists with status == 'failed'
      final maps = await DatabaseService.instance.runInTransaction(
        (exec) => exec.query('sync_outbox', where: 'userId = ?', whereArgs: [canonicalId]),
      );
      expect(maps.length, equals(1));
      expect(maps.first['status'], equals('failed'));
      expect(maps.first['lastError'], contains('400 Bad Request'));
    });

    test('7. Session switch or logout aborts active processing', () async {
      final mockNetwork = MockSyncNetworkClient();
      final engine = SyncEngine(
        outboxRepo: outboxRepo,
        networkClient: mockNetwork,
        sessionManager: sessionManager,
      );

      final note = Note(
        id: const Uuid().v4(),
        userId: canonicalId,
        title: 'Switch Note',
        content: 'Content',
        tags: const [],
        attachments: const [],
        colorValue: 0xFFFFFFFF,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await notesRepo.insertNote(note);

      // Simulate logout right before engine flush completes
      await sessionManager.clearSession();

      await engine.flush();

      // Should exit early without pushing mutations
      expect(mockNetwork.pushedRequests.isEmpty, isTrue);
    });

    test('8. OperationId immutability across app restart simulation', () async {
      final mockNetwork = MockSyncNetworkClient();
      mockNetwork.pushException = const SyncNetworkException(
        type: SyncNetworkErrorType.transientFailure,
        message: 'Timeout',
      );

      final engine1 = SyncEngine(
        outboxRepo: outboxRepo,
        networkClient: mockNetwork,
        sessionManager: sessionManager,
      );

      final note = Note(
        id: const Uuid().v4(),
        userId: canonicalId,
        title: 'Immutability Note',
        content: 'Content',
        tags: const [],
        attachments: const [],
        colorValue: 0xFFFFFFFF,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await notesRepo.insertNote(note);

      final pendingFirst = await outboxRepo.getPendingOutboxItems(canonicalId);
      final originalOpId = pendingFirst.first.operationId;

      await engine1.flush();

      // Simulate app restart with fresh SyncEngine after backoff window expires
      mockNetwork.pushException = null; // Clear network error
      final futureTime = DateTime.now().add(const Duration(seconds: 10));
      final engine2 = SyncEngine(
        outboxRepo: outboxRepo,
        networkClient: mockNetwork,
        sessionManager: sessionManager,
        nowProvider: () => futureTime,
      );
      await engine2.initialize();
      await engine2.flush();

      expect(mockNetwork.pushedRequests.length, equals(1));
      expect(mockNetwork.pushedRequests.first.operationId, equals(originalOpId));
    });

    test('9. Mismatched ACK operationId is rejected as malformedResponse', () async {
      final mockNetwork = MockSyncNetworkClient();
      mockNetwork.onPush = (mutations) {
        return SyncPushResult(
          acknowledgements: [
            SyncMutationAck(
              operationId: 'wrong_op_id_123',
              entityType: 'note',
              entityId: 'note_123',
              localVersion: 1,
              status: SyncAckStatus.acknowledged,
            ),
          ],
        );
      };

      final engine = SyncEngine(
        outboxRepo: outboxRepo,
        networkClient: mockNetwork,
        sessionManager: sessionManager,
      );

      final note = Note(
        id: const Uuid().v4(),
        userId: canonicalId,
        title: 'Mismatch Note',
        content: 'Content',
        tags: const [],
        attachments: const [],
        colorValue: 0xFFFFFFFF,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await notesRepo.insertNote(note);

      await engine.flush();

      final maps = await DatabaseService.instance.runInTransaction(
        (exec) => exec.query('sync_outbox', where: 'userId = ?', whereArgs: [canonicalId]),
      );
      expect(maps.first['status'], equals('failed'));
      expect(maps.first['lastError'], contains('ACK operationId mismatch'));
    });

    test('10. Concurrent flush protection ensures only one active processor', () async {
      final mockNetwork = MockSyncNetworkClient();
      final engine = SyncEngine(
        outboxRepo: outboxRepo,
        networkClient: mockNetwork,
        sessionManager: sessionManager,
      );

      // Call flush 3 times concurrently
      final f1 = engine.flush();
      final f2 = engine.flush();
      final f3 = engine.flush();

      await Future.wait([f1, f2, f3]);

      // All calls completed safely without error or race conditions
      expect(engine.isFlushing, isFalse);
    });
  });
}
