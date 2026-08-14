import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/services/connectivity_source.dart';
import 'package:quick_notes/services/connectivity_service.dart';
import 'package:quick_notes/services/sync_engine.dart';
import 'package:quick_notes/services/sync_network_client.dart';
import 'package:quick_notes/models/sync_mutation_request.dart';
import 'package:quick_notes/models/sync_pull_request.dart';
import 'package:quick_notes/models/sync_pull_response.dart';

class FakeConnectivitySource implements ConnectivitySource {
  final _controller = StreamController<ConnectivityStatus>.broadcast();
  ConnectivityStatus currentStatus;

  FakeConnectivitySource({this.currentStatus = ConnectivityStatus.offline});

  void emit(ConnectivityStatus status) {
    currentStatus = status;
    _controller.add(status);
  }

  @override
  Future<ConnectivityStatus> checkConnectivity() async => currentStatus;

  @override
  Stream<ConnectivityStatus> get onConnectivityChanged => _controller.stream;

  Future<void> close() async {
    await _controller.close();
  }
}

class FakeSyncNetworkClient implements SyncNetworkClient {
  @override
  Future<SyncPushResult> pushMutations({
    required String userId,
    required String authToken,
    required List<SyncMutationRequest> mutations,
  }) async {
    return const SyncPushResult(acknowledgements: []);
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

class TrackingSyncEngine extends SyncEngine {
  int flushCallCount = 0;

  TrackingSyncEngine() : super(networkClient: FakeSyncNetworkClient());

  @override
  Future<void> flush() async {
    flushCallCount++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 1.7.4 — Connectivity Service & Automatic Sync Trigger Tests', () {
    test('1. Initial offline state does not trigger flush', () async {
      final fakeSource = FakeConnectivitySource(currentStatus: ConnectivityStatus.offline);
      final fakeEngine = TrackingSyncEngine();
      final service = ConnectivityService(source: fakeSource, syncEngine: fakeEngine);

      await service.initialize();

      expect(fakeEngine.flushCallCount, equals(0));
      expect(service.lastStatus, equals(ConnectivityStatus.offline));
      await service.dispose();
    });

    test('2. Initial online state triggers exactly one flush', () async {
      final fakeSource = FakeConnectivitySource(currentStatus: ConnectivityStatus.online);
      final fakeEngine = TrackingSyncEngine();
      final service = ConnectivityService(source: fakeSource, syncEngine: fakeEngine);

      await service.initialize();

      expect(fakeEngine.flushCallCount, equals(1));
      expect(service.lastStatus, equals(ConnectivityStatus.online));
      await service.dispose();
    });

    test('3. offline -> online transition triggers flush', () async {
      final fakeSource = FakeConnectivitySource(currentStatus: ConnectivityStatus.offline);
      final fakeEngine = TrackingSyncEngine();
      final service = ConnectivityService(source: fakeSource, syncEngine: fakeEngine);

      await service.initialize();
      expect(fakeEngine.flushCallCount, equals(0));

      fakeSource.emit(ConnectivityStatus.online);
      await pumpEventQueue();

      expect(fakeEngine.flushCallCount, equals(1));
      expect(service.lastStatus, equals(ConnectivityStatus.online));
      await service.dispose();
    });

    test('4. unknown -> online transition triggers flush', () async {
      final fakeSource = FakeConnectivitySource(currentStatus: ConnectivityStatus.unknown);
      final fakeEngine = TrackingSyncEngine();
      final service = ConnectivityService(source: fakeSource, syncEngine: fakeEngine);

      await service.initialize();
      expect(fakeEngine.flushCallCount, equals(0));

      fakeSource.emit(ConnectivityStatus.online);
      await pumpEventQueue();

      expect(fakeEngine.flushCallCount, equals(1));
      await service.dispose();
    });

    test('5. online -> online does NOT trigger another flush (deduplication)', () async {
      final fakeSource = FakeConnectivitySource(currentStatus: ConnectivityStatus.online);
      final fakeEngine = TrackingSyncEngine();
      final service = ConnectivityService(source: fakeSource, syncEngine: fakeEngine);

      await service.initialize();
      expect(fakeEngine.flushCallCount, equals(1));

      fakeSource.emit(ConnectivityStatus.online);
      await pumpEventQueue();

      expect(fakeEngine.flushCallCount, equals(1)); // Remained 1
      await service.dispose();
    });

    test('6. online -> offline does NOT trigger flush', () async {
      final fakeSource = FakeConnectivitySource(currentStatus: ConnectivityStatus.online);
      final fakeEngine = TrackingSyncEngine();
      final service = ConnectivityService(source: fakeSource, syncEngine: fakeEngine);

      await service.initialize();
      expect(fakeEngine.flushCallCount, equals(1));

      fakeSource.emit(ConnectivityStatus.offline);
      await pumpEventQueue();

      expect(fakeEngine.flushCallCount, equals(1)); // Remained 1
      expect(service.lastStatus, equals(ConnectivityStatus.offline));
      await service.dispose();
    });

    test('7. online -> unknown does NOT trigger flush', () async {
      final fakeSource = FakeConnectivitySource(currentStatus: ConnectivityStatus.online);
      final fakeEngine = TrackingSyncEngine();
      final service = ConnectivityService(source: fakeSource, syncEngine: fakeEngine);

      await service.initialize();
      expect(fakeEngine.flushCallCount, equals(1));

      fakeSource.emit(ConnectivityStatus.unknown);
      await pumpEventQueue();

      expect(fakeEngine.flushCallCount, equals(1)); // Remained 1
      await service.dispose();
    });

    test('8. App resume while online triggers flush', () async {
      final fakeSource = FakeConnectivitySource(currentStatus: ConnectivityStatus.online);
      final fakeEngine = TrackingSyncEngine();
      final service = ConnectivityService(source: fakeSource, syncEngine: fakeEngine);

      await service.initialize();
      expect(fakeEngine.flushCallCount, equals(1));

      service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();

      expect(fakeEngine.flushCallCount, equals(2));
      await service.dispose();
    });

    test('9. App resume while offline does NOT trigger flush', () async {
      final fakeSource = FakeConnectivitySource(currentStatus: ConnectivityStatus.offline);
      final fakeEngine = TrackingSyncEngine();
      final service = ConnectivityService(source: fakeSource, syncEngine: fakeEngine);

      await service.initialize();
      expect(fakeEngine.flushCallCount, equals(0));

      service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();

      expect(fakeEngine.flushCallCount, equals(0));
      await service.dispose();
    });

    test('10. Multiple initialize() calls do not create duplicate listeners', () async {
      final fakeSource = FakeConnectivitySource(currentStatus: ConnectivityStatus.offline);
      final fakeEngine = TrackingSyncEngine();
      final service = ConnectivityService(source: fakeSource, syncEngine: fakeEngine);

      await service.initialize();
      await service.initialize(); // Second call

      fakeSource.emit(ConnectivityStatus.online);
      await pumpEventQueue();

      expect(fakeEngine.flushCallCount, equals(1));
      await service.dispose();
    });

    test('11. dispose() stops triggering flush on subsequent events', () async {
      final fakeSource = FakeConnectivitySource(currentStatus: ConnectivityStatus.offline);
      final fakeEngine = TrackingSyncEngine();
      final service = ConnectivityService(source: fakeSource, syncEngine: fakeEngine);

      await service.initialize();
      await service.dispose();

      fakeSource.emit(ConnectivityStatus.online);
      await pumpEventQueue();

      expect(fakeEngine.flushCallCount, equals(0));
    });
  });
}
