import 'dart:async';
import 'package:flutter/widgets.dart';
import 'connectivity_source.dart';
import 'sync_engine.dart';

/// ConnectivityService — Monitors platform network status and automatically triggers SyncEngine.flush()
/// on offline -> online state transitions or app foreground resume.
///
/// Follows the architecture:
/// "ConnectivityService is the doorbell. SyncEngine is the brain."
class ConnectivityService with WidgetsBindingObserver {
  final ConnectivitySource _source;
  final SyncEngine _syncEngine;

  ConnectivityStatus? _lastStatus;
  StreamSubscription<ConnectivityStatus>? _subscription;
  bool _isInitialized = false;

  ConnectivityStatus? get lastStatus => _lastStatus;
  bool get isInitialized => _isInitialized;

  ConnectivityService({
    ConnectivitySource? source,
    required SyncEngine syncEngine,
  })  : _source = source ?? PlatformConnectivitySource(),
        _syncEngine = syncEngine;

  /// Initializes connectivity monitoring, checks initial state, and registers lifecycle observers.
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isInitialized = true;
    WidgetsBinding.instance.addObserver(this);

    // Initial status query
    _lastStatus = await _source.checkConnectivity();

    // Startup trigger if device launches online
    if (_lastStatus == ConnectivityStatus.online) {
      await _triggerSync('Initial startup online status');
    }

    // Subscribe to platform connectivity stream
    _subscription = _source.onConnectivityChanged.listen(_handleStatusChange);
  }

  void _handleStatusChange(ConnectivityStatus newStatus) {
    if (!_isInitialized) return;

    final prevStatus = _lastStatus;
    _lastStatus = newStatus;

    // Deduplication check
    if (prevStatus == newStatus) return;

    // Transition trigger check: ONLY transition INTO online triggers flush
    if ((prevStatus == ConnectivityStatus.offline ||
            prevStatus == ConnectivityStatus.unknown ||
            prevStatus == null) &&
        newStatus == ConnectivityStatus.online) {
      _triggerSync('Transition into online state ($prevStatus -> $newStatus)');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isInitialized) return;

    if (state == AppLifecycleState.resumed) {
      _handleAppResumed();
    }
  }

  Future<void> _handleAppResumed() async {
    final currentStatus = await _source.checkConnectivity();
    _lastStatus = currentStatus;
    if (currentStatus == ConnectivityStatus.online) {
      await _triggerSync('App resumed to foreground while online');
    }
  }

  Future<void> _triggerSync(String reason) async {
    debugPrint('ConnectivityService trigger: $reason');
    await _syncEngine.flush();
  }

  /// Cancels subscription and removes lifecycle observer safely.
  Future<void> dispose() async {
    if (!_isInitialized) return;
    _isInitialized = false;

    WidgetsBinding.instance.removeObserver(this);
    await _subscription?.cancel();
    _subscription = null;
  }
}
