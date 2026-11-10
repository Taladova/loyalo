import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../features/visits/data/visit_sync_service.dart';
import '../../features/checkins/data/check_in_sync_service.dart';
import '../network/network_monitor.dart';

enum SyncEngineState { idle, syncing, error }

class SyncEngine with WidgetsBindingObserver {
  SyncEngine({
    required NetworkMonitor networkMonitor,
    required VisitSyncService visitSyncService,
    CheckInSyncService? checkInSyncService,
  }) : _networkMonitor = networkMonitor,
       _visitSyncService = visitSyncService,
       _checkInSyncService = checkInSyncService;

  final NetworkMonitor _networkMonitor;
  final VisitSyncService _visitSyncService;
  final CheckInSyncService? _checkInSyncService;
  final ValueNotifier<SyncEngineState> state = ValueNotifier(
    SyncEngineState.idle,
  );

  StreamSubscription<bool>? _networkSubscription;
  Future<void>? _activeSync;
  String? _ownerScopeId;
  bool? _networkWasAvailable;
  bool _syncRequested = false;
  bool _started = false;

  String? get ownerScopeId => _ownerScopeId;

  Future<void> start({required String ownerScopeId}) async {
    if (_started && _ownerScopeId == ownerScopeId) {
      await synchronize();
      return;
    }
    await stop();
    _started = true;
    _ownerScopeId = ownerScopeId;
    debugPrint('[SYNC] engine started');
    WidgetsBinding.instance.addObserver(this);
    _networkSubscription = _networkMonitor.onAvailabilityChanged.listen(
      _handleNetworkChange,
    );
    _networkWasAvailable = await _networkMonitor.isNetworkAvailable;
    if (_networkWasAvailable == true) await synchronize();
  }

  Future<void> stop() async {
    if (_started) WidgetsBinding.instance.removeObserver(this);
    _started = false;
    _networkWasAvailable = null;
    _syncRequested = false;
    await _networkSubscription?.cancel();
    _networkSubscription = null;
    await _activeSync;
    _activeSync = null;
    _ownerScopeId = null;
  }

  Future<void> dispose() async {
    await stop();
    state.dispose();
  }

  void _handleNetworkChange(bool available) {
    final restored = available && _networkWasAvailable == false;
    _networkWasAvailable = available;
    if (restored) unawaited(synchronize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(onAppResumed());
  }

  Future<void> onAppResumed() async {
    if (!_started || !await _networkMonitor.isNetworkAvailable) return;
    await synchronize();
  }

  Future<void> synchronize() {
    if (!_started || _ownerScopeId == null) return Future.value();
    final running = _activeSync;
    if (running != null) {
      _syncRequested = true;
      return running;
    }

    final future = _runSyncLoop();
    _activeSync = future;
    return future.whenComplete(() {
      if (identical(_activeSync, future)) _activeSync = null;
    });
  }

  Future<void> _runSyncLoop() async {
    state.value = SyncEngineState.syncing;
    try {
      do {
        _syncRequested = false;
        final owner = _ownerScopeId;
        if (!_started || owner == null) break;
        await _visitSyncService.retryPendingActions(ownerScopeId: owner);
        await _checkInSyncService?.retryPendingActions(ownerScopeId: owner);
      } while (_syncRequested);
      state.value = SyncEngineState.idle;
    } catch (_) {
      state.value = SyncEngineState.error;
    }
  }
}
