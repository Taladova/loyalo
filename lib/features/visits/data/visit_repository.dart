import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/pending_action_payload.dart';
import '../../../core/database/tables/local_visits.dart';
import '../../../core/database/tables/pending_actions.dart';
import '../../../core/network/network_monitor.dart';
import '../../../core/sync/sync_engine.dart';
import '../../checkins/data/check_in_sync_service.dart';
import '../../../models/restaurant.dart';
import '../../../models/visit.dart';
import 'visit_mapper.dart';
import 'visit_remote_data_source.dart';
import 'visit_sync_service.dart';

class VisitCreationResult {
  final Visit? visit;
  final bool alreadyExists;
  final bool synced;

  const VisitCreationResult({
    this.visit,
    required this.alreadyExists,
    this.synced = false,
  });
}

class VisitRepository {
  VisitRepository(
    FirebaseFirestore firestore, {
    required AppDatabase database,
    VisitRemoteDataSource? remoteDataSource,
    VisitSyncService? syncService,
    NetworkMonitor? networkMonitor,
    CheckInSyncService? checkInSyncService,
    DateTime Function()? clock,
  }) : _database = database,
       _firestore = firestore,
       _clock = clock ?? DateTime.now,
       _checkInSyncService = checkInSyncService,
       _remoteDataSource =
           remoteDataSource ?? FirestoreVisitRemoteDataSource(firestore) {
    _syncService =
        syncService ??
        VisitSyncService(
          database: database,
          remoteDataSource: _remoteDataSource,
          clock: _clock,
        );
    if (networkMonitor != null) {
      _syncEngine = SyncEngine(
        networkMonitor: networkMonitor,
        visitSyncService: _syncService,
        checkInSyncService: checkInSyncService,
      );
    }
  }

  final AppDatabase _database;
  final FirebaseFirestore _firestore;
  final VisitRemoteDataSource _remoteDataSource;
  final DateTime Function() _clock;
  late final VisitSyncService _syncService;
  final CheckInSyncService? _checkInSyncService;
  SyncEngine? _syncEngine;
  List<Visit> _visits = [];
  final Map<String, LocalVisitSyncStatus> _syncStatusByVisitId = {};

  List<Visit> get visits => List.unmodifiable(_visits);

  Stream<List<Visit>> watchVisits({String? userId, String? restaurantId}) {
    late StreamController<List<Visit>> controller;
    StreamSubscription<List<LocalVisit>>? localSubscription;
    StreamSubscription<List<Visit>>? remoteSubscription;

    controller = StreamController<List<Visit>>(
      onListen: () {
        localSubscription =
            _localStream(userId: userId, restaurantId: restaurantId).listen((
              localVisits,
            ) {
              _syncStatusByVisitId
                ..clear()
                ..addEntries(
                  localVisits.map(
                    (visit) => MapEntry(visit.visitId, visit.syncStatus),
                  ),
                );
              _visits = localVisits.map(VisitMapper.fromLocal).toList();
              controller.add(visits);
            }, onError: controller.addError);

        remoteSubscription = _remoteDataSource
            .watchVisits(userId: userId, restaurantId: restaurantId)
            .listen(
              (remoteVisits) async => _reconcile(remoteVisits),
              onError: (_) {},
            );
      },
      onCancel: () async {
        await localSubscription?.cancel();
        await remoteSubscription?.cancel();
      },
    );
    return controller.stream;
  }

  Future<void> refreshVisitsFromRemote({
    String? userId,
    String? restaurantId,
  }) async {
    final remoteVisits = await _remoteDataSource.fetchVisits(
      userId: userId,
      restaurantId: restaurantId,
    );
    await _reconcile(remoteVisits);
    final local = await _readLocal(userId: userId, restaurantId: restaurantId);
    _syncStatusByVisitId
      ..clear()
      ..addEntries(
        local.map((visit) => MapEntry(visit.visitId, visit.syncStatus)),
      );
    _visits = local.map(VisitMapper.fromLocal).toList();
  }

  Future<void> startAutomaticSync(String ownerScopeId) async {
    await _syncEngine?.start(ownerScopeId: ownerScopeId);
  }

  Future<void> stopAutomaticSync() async {
    await _syncEngine?.stop();
  }

  Future<void> retryPendingVisits({required String ownerScopeId}) {
    final engine = _syncEngine;
    if (engine != null && engine.ownerScopeId == ownerScopeId) {
      return engine.synchronize();
    }
    return _retryWithoutEngine(ownerScopeId);
  }

  Future<void> _retryWithoutEngine(String ownerScopeId) async {
    await _syncService.retryPendingActions(ownerScopeId: ownerScopeId);
    await _checkInSyncService?.retryPendingActions(ownerScopeId: ownerScopeId);
  }

  Stream<List<LocalVisit>> _localStream({
    String? userId,
    String? restaurantId,
  }) {
    if (userId != null) {
      return _database.visitDao.watchVisitsByCustomer(userId);
    }
    if (restaurantId != null) {
      return _database.visitDao.watchVisitsByMerchant(restaurantId);
    }
    return _database.visitDao.watchAllVisits();
  }

  Future<List<LocalVisit>> _readLocal({String? userId, String? restaurantId}) {
    if (userId != null) {
      return _database.visitDao.getVisitsByCustomer(userId);
    }
    if (restaurantId != null) {
      return _database.visitDao.getVisitsByMerchant(restaurantId);
    }
    return _database.visitDao.getAllVisits();
  }

  Future<void> _reconcile(List<Visit> remoteVisits) async {
    await _database.transaction(() async {
      for (final remoteVisit in remoteVisits) {
        final local = await _database.visitDao.getVisitById(remoteVisit.id);
        await _database.visitDao.upsertVisit(
          VisitMapper.toLocal(
            remoteVisit,
            syncStatus: LocalVisitSyncStatus.synced,
            createdAt: local?.createdAt,
            updatedAt: _clock(),
          ),
        );
        _syncStatusByVisitId[remoteVisit.id] = LocalVisitSyncStatus.synced;
      }
    });
  }

  List<Visit> visitsForUser(String userId) =>
      _visits.where((visit) => visit.userId == userId).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  bool isVisitConfirmed(String visitId) =>
      _syncStatusByVisitId[visitId] == LocalVisitSyncStatus.synced;

  LocalVisitSyncStatus? syncStatusForVisit(String visitId) =>
      _syncStatusByVisitId[visitId];

  List<Visit> confirmedVisitsForUser(String userId) => visitsForUser(
    userId,
  ).where((visit) => isVisitConfirmed(visit.id)).toList();

  Iterable<Visit> get _confirmedVisits =>
      _visits.where((visit) => isVisitConfirmed(visit.id));

  int passageCount(String userId, String restaurantId) => _confirmedVisits
      .where(
        (visit) => visit.userId == userId && visit.restaurantId == restaurantId,
      )
      .length;

  bool hasVisitedToday(String userId, String restaurantId) {
    final now = _clock();
    return _visits.any(
      (visit) =>
          visit.userId == userId &&
          visit.restaurantId == restaurantId &&
          visit.isSameDay(now),
    );
  }

  Visit? lastVisitFor(String userId, String restaurantId) {
    final matching =
        _visits
            .where(
              (visit) =>
                  visit.userId == userId && visit.restaurantId == restaurantId,
            )
            .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return matching.isEmpty ? null : matching.first;
  }

  bool canRegisterVisit(String userId, Restaurant restaurant, DateTime now) {
    switch (restaurant.validationPolicy) {
      case VisitValidationPolicy.oncePerDay:
        return !hasVisitedToday(userId, restaurant.id);
      case VisitValidationPolicy.onceEveryXHours:
        final lastVisit = lastVisitFor(userId, restaurant.id);
        if (lastVisit == null) return true;
        final minimumGap = Duration(
          hours: restaurant.minimumHoursBetweenVisits,
        );
        return !lastVisit.timestamp.add(minimumGap).isAfter(now);
      case VisitValidationPolicy.perTransaction:
        return true;
    }
  }

  Future<VisitCreationResult> createVisit({
    required String userId,
    required String restaurantId,
    required String ownerScopeId,
    required DateTime timestamp,
    required bool preventSameDayDuplicate,
  }) async {
    final reference = _firestore.collection('visits').doc();
    final visitId = preventSameDayDuplicate
        ? '${restaurantId}_${userId}_${timestamp.year}-${timestamp.month}-${timestamp.day}'
        : reference.id;
    if (await _database.visitDao.visitExists(visitId)) {
      return const VisitCreationResult(visit: null, alreadyExists: true);
    }

    final visit = Visit(
      id: visitId,
      userId: userId,
      restaurantId: restaurantId,
      timestamp: timestamp,
    );
    final operationId = 'createVisit:$visitId';
    final now = _clock();
    try {
      await _database.insertVisitWithPendingAction(
        visit: VisitMapper.toLocal(
          visit,
          syncStatus: LocalVisitSyncStatus.pending,
          createdAt: now,
          updatedAt: now,
        ),
        action: PendingActionsCompanion.insert(
          operationId: operationId,
          ownerScopeId: Value(ownerScopeId),
          actionType: PendingActionType.createVisit,
          entityType: 'visit',
          entityId: visitId,
          payload: PendingActionPayload.encode(
            VisitMapper.toPendingPayload(visit),
          ),
          createdAt: now,
          updatedAt: now,
        ),
      );
    } catch (_) {
      if (await _database.visitDao.visitExists(visitId)) {
        return const VisitCreationResult(visit: null, alreadyExists: true);
      }
      rethrow;
    }

    _visits = [visit, ..._visits.where((item) => item.id != visit.id)];
    _syncStatusByVisitId[visit.id] = LocalVisitSyncStatus.pending;
    var synced = false;
    try {
      final engine = _syncEngine;
      if (engine != null && engine.ownerScopeId == ownerScopeId) {
        await engine.synchronize();
      } else {
        await _syncService.syncAction(operationId, ownerScopeId: ownerScopeId);
      }
      final action = await _database.pendingActionDao.getActionByOperationId(
        operationId,
      );
      synced = action?.status == PendingActionStatus.synced;
      if (synced) {
        _syncStatusByVisitId[visit.id] = LocalVisitSyncStatus.synced;
      }
    } catch (_) {
      // The visit and queue entry remain available for a later retry.
    }
    return VisitCreationResult(
      visit: visit,
      alreadyExists: false,
      synced: synced,
    );
  }

  List<Visit> recentActivityForRestaurant(
    String restaurantId, {
    int limit = 5,
  }) {
    final matching =
        _confirmedVisits
            .where((visit) => visit.restaurantId == restaurantId)
            .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return matching.take(limit).toList();
  }

  Map<String, int> clientsForRestaurant(String restaurantId) {
    final counts = <String, int>{};
    for (final visit in _confirmedVisits.where(
      (visit) => visit.restaurantId == restaurantId,
    )) {
      counts[visit.userId] = (counts[visit.userId] ?? 0) + 1;
    }
    return counts;
  }

  int visitsToday(String restaurantId) {
    final now = _clock();
    return _confirmedVisits
        .where(
          (visit) => visit.restaurantId == restaurantId && visit.isSameDay(now),
        )
        .length;
  }

  List<Visit> visitsForRestaurantSince(String restaurantId, DateTime since) =>
      _confirmedVisits
          .where(
            (visit) =>
                visit.restaurantId == restaurantId &&
                !visit.timestamp.isBefore(since),
          )
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  List<Visit> visitsForRestaurantBetween(
    String restaurantId,
    DateTime start,
    DateTime end,
  ) =>
      _confirmedVisits
          .where(
            (visit) =>
                visit.restaurantId == restaurantId &&
                !visit.timestamp.isBefore(start) &&
                visit.timestamp.isBefore(end),
          )
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  int uniqueClientsForRestaurant(String restaurantId) => _confirmedVisits
      .where((visit) => visit.restaurantId == restaurantId)
      .map((visit) => visit.userId)
      .toSet()
      .length;

  int activeClientsSince(String restaurantId, DateTime since) =>
      _confirmedVisits
          .where(
            (visit) =>
                visit.restaurantId == restaurantId &&
                !visit.timestamp.isBefore(since),
          )
          .map((visit) => visit.userId)
          .toSet()
          .length;

  bool isFirstVisitForRestaurant(Visit visit) => !_confirmedVisits.any(
    (candidate) =>
        candidate.restaurantId == visit.restaurantId &&
        candidate.userId == visit.userId &&
        candidate.timestamp.isBefore(visit.timestamp),
  );

  int newClientsBetween(String restaurantId, DateTime start, DateTime end) {
    final firstVisitByUser = <String, DateTime>{};
    for (final visit in _confirmedVisits.where(
      (visit) => visit.restaurantId == restaurantId,
    )) {
      final current = firstVisitByUser[visit.userId];
      if (current == null || visit.timestamp.isBefore(current)) {
        firstVisitByUser[visit.userId] = visit.timestamp;
      }
    }
    return firstVisitByUser.values
        .where(
          (firstVisit) =>
              !firstVisit.isBefore(start) && firstVisit.isBefore(end),
        )
        .length;
  }

  int newClientsToday(String restaurantId) {
    final now = _clock();
    return newClientsBetween(
      restaurantId,
      DateTime(now.year, now.month, now.day),
      DateTime(now.year, now.month, now.day + 1),
    );
  }

  int newClientsSince(String restaurantId, DateTime since) {
    final seenBeforePeriod = <String>{};
    final newInPeriod = <String>{};
    final matching =
        _confirmedVisits
            .where((visit) => visit.restaurantId == restaurantId)
            .toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    for (final visit in matching) {
      if (visit.timestamp.isBefore(since)) {
        seenBeforePeriod.add(visit.userId);
      } else if (!seenBeforePeriod.contains(visit.userId)) {
        newInPeriod.add(visit.userId);
      }
    }
    return newInPeriod.length;
  }
}
