import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Abstract representation of network connectivity status.
enum ConnectivityStatus {
  offline,
  online,
  unknown,
}

/// ConnectivitySource — Platform-independent contract for querying and observing network status.
abstract class ConnectivitySource {
  Future<ConnectivityStatus> checkConnectivity();
  Stream<ConnectivityStatus> get onConnectivityChanged;
}

/// PlatformConnectivitySource — Concrete platform implementation backed by connectivity_plus.
class PlatformConnectivitySource implements ConnectivitySource {
  final Connectivity _connectivity;

  PlatformConnectivitySource({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  ConnectivityStatus _mapResultsToStatus(List<ConnectivityResult> results) {
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      return ConnectivityStatus.offline;
    }
    final hasOnlineType = results.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet ||
        r == ConnectivityResult.vpn ||
        r == ConnectivityResult.bluetooth);

    return hasOnlineType
        ? ConnectivityStatus.online
        : ConnectivityStatus.unknown;
  }

  @override
  Future<ConnectivityStatus> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return _mapResultsToStatus(results);
    } catch (_) {
      return ConnectivityStatus.unknown;
    }
  }

  @override
  Stream<ConnectivityStatus> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged
        .map(_mapResultsToStatus)
        .handleError((_) => ConnectivityStatus.unknown);
  }
}
