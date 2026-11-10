import 'package:connectivity_plus/connectivity_plus.dart';

abstract interface class NetworkMonitor {
  Future<bool> get isNetworkAvailable;

  Stream<bool> get onAvailabilityChanged;
}

class ConnectivityNetworkMonitor implements NetworkMonitor {
  ConnectivityNetworkMonitor({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> get isNetworkAvailable async =>
      _hasNetwork(await _connectivity.checkConnectivity());

  @override
  Stream<bool> get onAvailabilityChanged =>
      _connectivity.onConnectivityChanged.map(_hasNetwork).distinct();

  bool _hasNetwork(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);
}
