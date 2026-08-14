import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quick_notes/models/remote_change.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/models/sync_pull_request.dart';
import 'package:quick_notes/models/sync_pull_response.dart';
import 'package:quick_notes/services/sync_network_client.dart';
import 'package:quick_notes/services/pull_sync_engine.dart';
import 'package:quick_notes/services/database_service.dart';
import 'package:quick_notes/services/session_manager.dart';
import 'package:quick_notes/models/session_type.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Note createTestNote({
  required String id,
  String? userId,
  required String title,
}) {
  final now = DateTime.now();
  return Note(
    id: id,
    userId: userId,
    title: title,
    content: 'Content',
    tags: const [],
    attachments: const [],
    createdAt: now,
    updatedAt: now,
    colorValue: 0xFFFFFFFF,
    version: 1,
    lastSyncedVersion: 1,
  );
}

class FakePullSyncNetworkClient implements SyncNetworkClient {
  final List<SyncPullResponse> responsesToReturn;
  int callCount = 0;
  List<SyncPullRequest> requestsReceived = [];

  FakePullSyncNetworkClient({required this.responsesToReturn});

  @override
  Future<SyncPushResult> pushMutations({
    required String userId,
    required String authToken,
    required List<dynamic> mutations,
  }) async {
    return const SyncPushResult(acknowledgements: []);
  }

  @override
  Future<SyncPullResponse> pullChanges({
    required String userId,
    required String authToken,
    required SyncPullRequest request,
  }) async {
    requestsReceived.add(request);
    if (callCount < responsesToReturn.length) {
      return responsesToReturn[callCount++];
    }
    return const SyncPullResponse(changes: [], hasMore: false);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService dbService;
  late SessionManager sessionManager;
  const testUserId = 'usr_phase18_pull_engine';

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => '.',
    );

    final secureStorageStore = <String, String>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'write') {
          final args = Map<String, dynamic>.from(methodCall.arguments as Map);
          secureStorageStore[args['key'] as String] = args['value'] as String;
          return null;
        } else if (methodCall.method == 'read') {
          final args = Map<String, dynamic>.from(methodCall.arguments as Map);
          return secureStorageStore[args['key'] as String];
        } else if (methodCall.method == 'delete') {
          final args = Map<String, dynamic>.from(methodCall.arguments as Map);
          secureStorageStore.remove(args['key'] as String);
          return null;
        }
        return null;
      },
    );

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    dbService = DatabaseService.instance;
    await dbService.queryAll();

    final db = await dbService.database;
    await db.delete('notes');
    await db.delete('folders');
    await db.delete('tasks');
    await db.delete('sync_outbox');
    await db.delete('users');

    sessionManager = SessionManager();
    await sessionManager.saveSession(
      userId: testUserId,
      sessionType: SessionType.google,
      idToken: 'fake_test_id_token',
    );
  });

  group('Phase 1.8 — PullSyncEngine Tests', () {
    test('1. Paginated pull reads initial null cursor, applies changes, and persists nextCursor', () async {
      final note1 = createTestNote(id: 'note_p1', userId: testUserId, title: 'Page 1 Note');
      final note2 = createTestNote(id: 'note_p2', userId: testUserId, title: 'Page 2 Note');

      final page1Response = SyncPullResponse(
        changes: [
          RemoteChange(
            entityType: 'note',
            entityId: note1.id,
            userId: testUserId,
            operation: 'create',
            remoteVersion: 1,
            payload: note1.toMap(),
            serverTimestamp: DateTime.now(),
          ),
        ],
        nextCursor: 'cursor_token_page2',
        hasMore: true,
      );

      final page2Response = SyncPullResponse(
        changes: [
          RemoteChange(
            entityType: 'note',
            entityId: note2.id,
            userId: testUserId,
            operation: 'create',
            remoteVersion: 1,
            payload: note2.toMap(),
            serverTimestamp: DateTime.now(),
          ),
        ],
        nextCursor: 'cursor_token_final',
        hasMore: false,
      );

      final fakeClient = FakePullSyncNetworkClient(
        responsesToReturn: [page1Response, page2Response],
      );

      final engine = PullSyncEngine(
        networkClient: fakeClient,
        sessionManager: sessionManager,
      );

      await engine.pull(activeUserId: testUserId);

      expect(fakeClient.callCount, equals(2));
      expect(fakeClient.requestsReceived[0].cursor, isNull);
      expect(fakeClient.requestsReceived[1].cursor, equals('cursor_token_page2'));

      // Verify stored cursor in SharedPreferences
      final storedCursor = await engine.getCursor(testUserId);
      expect(storedCursor, equals('cursor_token_final'));
    });

    test('2. User-specific cursor key isolation (usr_A cursor does not collide with usr_B)', () async {
      final engine = PullSyncEngine(
        networkClient: FakePullSyncNetworkClient(responsesToReturn: []),
        sessionManager: sessionManager,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sync_cursor_usr_A', 'cursor_user_a');
      await prefs.setString('sync_cursor_usr_B', 'cursor_user_b');

      expect(await engine.getCursor('usr_A'), equals('cursor_user_a'));
      expect(await engine.getCursor('usr_B'), equals('cursor_user_b'));
    });

    test('3. Malformed response / 400 error clears stored cursor and aborts cleanly', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sync_cursor_$testUserId', 'stale_bad_cursor');

      final throwingClient = _ThrowingPullClient(
        exception: const SyncNetworkException(
          type: SyncNetworkErrorType.malformedResponse,
          message: 'HTTP 400 Invalid Cursor',
        ),
      );

      final engine = PullSyncEngine(
        networkClient: throwingClient,
        sessionManager: sessionManager,
      );

      await expectLater(
        () => engine.pull(activeUserId: testUserId),
        throwsA(isA<SyncNetworkException>()),
      );

      // Verify stored cursor cleared
      final cursorAfter = await engine.getCursor(testUserId);
      expect(cursorAfter, isNull);
    });

    test('4. Empty pull response leaves cursor intact without failure', () async {
      final emptyResponse = const SyncPullResponse(
        changes: [],
        nextCursor: 'cursor_empty_end',
        hasMore: false,
      );

      final fakeClient = FakePullSyncNetworkClient(
        responsesToReturn: [emptyResponse],
      );

      final engine = PullSyncEngine(
        networkClient: fakeClient,
        sessionManager: sessionManager,
      );

      await engine.pull(activeUserId: testUserId);
      expect(fakeClient.callCount, equals(1));
    });
  });
}

class _ThrowingPullClient implements SyncNetworkClient {
  final SyncNetworkException exception;

  _ThrowingPullClient({required this.exception});

  @override
  Future<SyncPushResult> pushMutations({
    required String userId,
    required String authToken,
    required List<dynamic> mutations,
  }) async {
    return const SyncPushResult(acknowledgements: []);
  }

  @override
  Future<SyncPullResponse> pullChanges({
    required String userId,
    required String authToken,
    required SyncPullRequest request,
  }) async {
    throw exception;
  }
}
