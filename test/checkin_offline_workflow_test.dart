import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loyalo/core/database/app_database.dart';
import 'package:loyalo/core/database/pending_action_payload.dart';
import 'package:loyalo/core/database/tables/local_check_ins.dart';
import 'package:loyalo/core/database/tables/local_visits.dart';
import 'package:loyalo/core/database/tables/pending_actions.dart';
import 'package:loyalo/features/checkins/data/check_in_remote_data_source.dart';
import 'package:loyalo/features/checkins/data/check_in_sync_service.dart';
import 'package:loyalo/features/checkins/data/checkin_repository.dart';
import 'package:loyalo/models/check_in_request.dart';
import 'package:loyalo/models/restaurant.dart';

void main() {
  final now = DateTime.utc(2026, 10, 12, 12);
  late AppDatabase database;
  late _FakeCheckInRemote remote;
  late CheckInRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    remote = _FakeCheckInRemote();
    repository = _repository(database, remote, now);
  });

  tearDown(() async {
    await remote.close();
    await database.close();
  });

  test('1. Firestore pending hydrate SQLite', () async {
    final subscription = repository
        .watchCheckIns(restaurantId: 'restaurant-a', ownerUid: 'owner-a')
        .listen((_) {});
    remote.emit([_request(now)]);
    await _settle();

    final local = await database.checkInDao.getCheckInById('checkin-1');
    expect(local?.businessStatus, LocalCheckInBusinessStatus.pending);
    expect(local?.syncStatus, LocalCheckInSyncStatus.synced);
    await subscription.cancel();
  });

  test('2. CheckIn déjà hydraté reste visible offline', () async {
    await repository.cacheForMerchant(_request(now), 'owner-a');

    final visible = await repository
        .watchCheckIns(restaurantId: 'restaurant-a', ownerUid: 'owner-a')
        .first;

    expect(visible.map((item) => item.id), ['checkin-1']);
  });

  test('2a. Une mise à jour Firestore utilise UPSERT sans doublon', () async {
    final subscription = repository
        .watchCheckIns(restaurantId: 'restaurant-a', ownerUid: 'owner-a')
        .listen((_) {});
    remote.emit([_request(now)]);
    await _settle();
    final updatedExpiry = now.add(const Duration(minutes: 20));
    remote.emit([_request(now, expiresAt: updatedExpiry)]);
    await _settle();

    final rows = await database.checkInDao.getCheckInsForMerchant(
      'restaurant-a',
      'owner-a',
    );
    expect(rows, hasLength(1));
    expect(rows.single.checkInId, 'checkin-1');
    expect(rows.single.expiresAt.toUtc(), updatedExpiry);
    await subscription.cancel();
  });

  test('2b. Une erreur Firestore conserve le cache SQLite', () async {
    await repository.cacheForMerchant(_request(now), 'owner-a');
    final remoteError = Completer<Object>();
    final subscription = repository
        .watchCheckIns(restaurantId: 'restaurant-a', ownerUid: 'owner-a')
        .listen((_) {}, onError: remoteError.complete);
    remote.emitError(StateError('Firestore indisponible'));
    await remoteError.future;

    final rows = await database.checkInDao.getCheckInsForMerchant(
      'restaurant-a',
      'owner-a',
    );
    expect(rows.map((item) => item.checkInId), ['checkin-1']);
    expect(repository.loadError, isA<StateError>());
    await subscription.cancel();
  });

  test('3. Approve offline crée CheckIn, Visit et PendingAction', () async {
    remote.offline = true;
    await repository.cacheForMerchant(_request(now), 'owner-a');

    final result = await repository.approveLocally(
      checkInId: 'checkin-1',
      ownerUid: 'owner-a',
      restaurant: _restaurant(),
      pointsAwarded: 120,
    );

    final checkIn = await database.checkInDao.getCheckInById('checkin-1');
    expect(result.outcome, LocalCheckInMutationOutcome.completed);
    expect(checkIn?.businessStatus, LocalCheckInBusinessStatus.approved);
    expect(checkIn?.syncStatus, LocalCheckInSyncStatus.failed);
    expect(
      await database.visitDao.getVisitById(
        'restaurant-a_customer-1_2026-10-12',
      ),
      isNotNull,
    );
    expect(await _action(database, 'approveCheckIn:checkin-1'), isNotNull);
  });

  test('3b. Approbation offline reste visible comme non finalisée', () async {
    remote.offline = true;
    await repository.cacheForMerchant(_request(now), 'owner-a');

    await repository.approveLocally(
      checkInId: 'checkin-1',
      ownerUid: 'owner-a',
      restaurant: _restaurant(),
      pointsAwarded: 120,
    );

    final queue = await database.checkInDao
        .watchMerchantValidationQueue('restaurant-a', 'owner-a')
        .first;
    expect(queue, hasLength(1));
    expect(queue.single.businessStatus, LocalCheckInBusinessStatus.approved);
    expect(queue.single.syncStatus, LocalCheckInSyncStatus.failed);
    expect(
      (await database.visitDao.getAllVisits()).single.syncStatus,
      isNot(LocalVisitSyncStatus.synced),
    );
  });

  test(
    '3c. Expiration serveur après approbation offline conserve les données',
    () async {
      remote.offline = true;
      await repository.cacheForMerchant(_request(now), 'owner-a');
      await repository.approveLocally(
        checkInId: 'checkin-1',
        ownerUid: 'owner-a',
        restaurant: _restaurant(),
        pointsAwarded: 120,
      );
      remote
        ..offline = false
        ..approveError = const CheckInRemoteException(
          code: 'failed-precondition',
          reason: 'check-in-expired',
          message: 'expired on server',
        );

      await repository.syncService.retryPendingActions(
        ownerScopeId: 'restaurant-a',
      );

      final checkIn = await database.checkInDao.getCheckInById('checkin-1');
      final visits = await database.visitDao.getAllVisits();
      final action = await _action(database, 'approveCheckIn:checkin-1');
      expect(checkIn?.businessStatus, LocalCheckInBusinessStatus.expired);
      expect(checkIn?.syncStatus, LocalCheckInSyncStatus.failed);
      expect(visits, hasLength(1));
      expect(visits.single.syncStatus, LocalVisitSyncStatus.failed);
      expect(action?.status, PendingActionStatus.blocked);
      expect(action?.lastError, contains('check-in-expired'));
    },
  );

  test('4. Approve transaction rollback si action dupliquée', () async {
    await repository.cacheForMerchant(_request(now), 'owner-a');
    await database.pendingActionDao.insertPendingAction(
      _pendingAction('approveCheckIn:checkin-1', now),
    );

    await expectLater(
      repository.approveLocally(
        checkInId: 'checkin-1',
        ownerUid: 'owner-a',
        restaurant: _restaurant(),
        pointsAwarded: 120,
      ),
      throwsA(anything),
    );

    final checkIn = await database.checkInDao.getCheckInById('checkin-1');
    expect(checkIn?.businessStatus, LocalCheckInBusinessStatus.pending);
    expect(await database.visitDao.getAllVisits(), isEmpty);
  });

  test('5. Reject offline persiste une action', () async {
    remote.offline = true;
    await repository.cacheForMerchant(_request(now), 'owner-a');

    final result = await repository.rejectLocally(
      checkInId: 'checkin-1',
      ownerUid: 'owner-a',
      merchantId: 'restaurant-a',
    );

    expect(result.outcome, LocalCheckInMutationOutcome.completed);
    expect(
      (await database.checkInDao.getCheckInById('checkin-1'))?.businessStatus,
      LocalCheckInBusinessStatus.rejected,
    );
    expect(await _action(database, 'rejectCheckIn:checkin-1'), isNotNull);
  });

  test('6. Reject ne crée aucune Visit', () async {
    remote.offline = true;
    await repository.cacheForMerchant(_request(now), 'owner-a');
    await repository.rejectLocally(
      checkInId: 'checkin-1',
      ownerUid: 'owner-a',
      merchantId: 'restaurant-a',
    );

    expect(await database.visitDao.getAllVisits(), isEmpty);
  });

  test('7. CheckIn expiré est refusé offline', () async {
    await repository.cacheForMerchant(
      _request(now, expiresAt: now.subtract(const Duration(seconds: 1))),
      'owner-a',
    );

    final result = await repository.approveLocally(
      checkInId: 'checkin-1',
      ownerUid: 'owner-a',
      restaurant: _restaurant(),
      pointsAwarded: 120,
    );

    expect(result.outcome, LocalCheckInMutationOutcome.expired);
    expect(await database.visitDao.getAllVisits(), isEmpty);
  });

  test('8. Restart offline conserve CheckIn, Visit et action', () async {
    final directory = await Directory.systemTemp.createTemp('loyalo-checkin-');
    final file = File('${directory.path}/offline.sqlite');
    final firstDb = AppDatabase.forTesting(NativeDatabase(file));
    final firstRemote = _FakeCheckInRemote()..offline = true;
    final firstRepo = _repository(firstDb, firstRemote, now);
    await firstRepo.cacheForMerchant(_request(now), 'owner-a');
    await firstRepo.approveLocally(
      checkInId: 'checkin-1',
      ownerUid: 'owner-a',
      restaurant: _restaurant(),
      pointsAwarded: 120,
    );
    await firstRemote.close();
    await firstDb.close();

    final reopened = AppDatabase.forTesting(NativeDatabase(file));
    expect(await reopened.checkInDao.getCheckInById('checkin-1'), isNotNull);
    expect(await reopened.visitDao.getAllVisits(), hasLength(1));
    expect(await _action(reopened, 'approveCheckIn:checkin-1'), isNotNull);
    await reopened.close();
    await directory.delete(recursive: true);
  });

  test('9. Reconnect synchronise approval exactement une fois', () async {
    remote.offline = true;
    await repository.cacheForMerchant(_request(now), 'owner-a');
    await repository.approveLocally(
      checkInId: 'checkin-1',
      ownerUid: 'owner-a',
      restaurant: _restaurant(),
      pointsAwarded: 120,
    );
    remote.offline = false;

    await repository.syncService.retryPendingActions(
      ownerScopeId: 'restaurant-a',
    );

    expect(remote.approveWrites, 1);
    expect(
      (await _action(database, 'approveCheckIn:checkin-1'))?.status,
      PendingActionStatus.synced,
    );
  });

  test('10. Reconnect synchronise reject', () async {
    remote.offline = true;
    await repository.cacheForMerchant(_request(now), 'owner-a');
    await repository.rejectLocally(
      checkInId: 'checkin-1',
      ownerUid: 'owner-a',
      merchantId: 'restaurant-a',
    );
    remote.offline = false;

    await repository.syncService.retryPendingActions(
      ownerScopeId: 'restaurant-a',
    );

    expect(remote.rejectWrites, 1);
    expect(
      (await _action(database, 'rejectCheckIn:checkin-1'))?.status,
      PendingActionStatus.synced,
    );
  });

  test('11. Double tap crée une seule Visit et une opération', () async {
    remote.offline = true;
    await repository.cacheForMerchant(_request(now), 'owner-a');
    final first = await repository.approveLocally(
      checkInId: 'checkin-1',
      ownerUid: 'owner-a',
      restaurant: _restaurant(),
      pointsAwarded: 120,
    );
    final second = await repository.approveLocally(
      checkInId: 'checkin-1',
      ownerUid: 'owner-a',
      restaurant: _restaurant(),
      pointsAwarded: 120,
    );

    expect(first.outcome, LocalCheckInMutationOutcome.completed);
    expect(second.outcome, LocalCheckInMutationOutcome.notPending);
    expect(await database.visitDao.getAllVisits(), hasLength(1));
    expect(await database.pendingActionDao.getPendingActions(), isEmpty);
    expect(
      await database.pendingActionDao.getSyncableActions('restaurant-a'),
      hasLength(1),
    );
  });

  test('12. Lost response retry garde le même visitId', () async {
    remote.loseFirstApproveResponse = true;
    await repository.cacheForMerchant(_request(now), 'owner-a');
    await repository.approveLocally(
      checkInId: 'checkin-1',
      ownerUid: 'owner-a',
      restaurant: _restaurant(),
      pointsAwarded: 120,
    );
    await repository.syncService.retryPendingActions(
      ownerScopeId: 'restaurant-a',
    );

    expect(remote.approveCalls, 2);
    expect(remote.visitIds, {'restaurant-a_customer-1_2026-10-12'});
    expect(remote.approveWrites, 1);
    expect(
      (await database.pendingActionDao.getActionByOperationId(
        'approveCheckIn:checkin-1',
      ))?.operationId,
      'approveCheckIn:checkin-1',
    );
  });

  test('13. Événements réseau concurrents ne doublent pas la Visit', () async {
    remote.offline = true;
    await repository.cacheForMerchant(_request(now), 'owner-a');
    await repository.approveLocally(
      checkInId: 'checkin-1',
      ownerUid: 'owner-a',
      restaurant: _restaurant(),
      pointsAwarded: 120,
    );
    remote.offline = false;

    await Future.wait(
      List.generate(
        4,
        (_) => repository.syncService.retryPendingActions(
          ownerScopeId: 'restaurant-a',
        ),
      ),
    );

    expect(remote.approveWrites, 1);
  });

  test('14. oncePerDay compte une Visit locale pending', () async {
    await _insertVisit(database, now);
    await repository.cacheForMerchant(
      _request(now, id: 'checkin-2'),
      'owner-a',
    );
    final result = await repository.approveLocally(
      checkInId: 'checkin-2',
      ownerUid: 'owner-a',
      restaurant: _restaurant(),
      pointsAwarded: 120,
    );
    expect(result.outcome, LocalCheckInMutationOutcome.tooFrequent);
  });

  test('15. onceEveryXHours compte la dernière Visit locale', () async {
    await _insertVisit(database, now.subtract(const Duration(hours: 2)));
    await repository.cacheForMerchant(
      _request(now, id: 'checkin-2'),
      'owner-a',
    );
    final result = await repository.approveLocally(
      checkInId: 'checkin-2',
      ownerUid: 'owner-a',
      restaurant: _restaurant(policy: VisitValidationPolicy.onceEveryXHours),
      pointsAwarded: 120,
    );
    expect(result.outcome, LocalCheckInMutationOutcome.tooFrequent);
  });

  test('16. perTransaction autorise deux validations', () async {
    remote.offline = true;
    await repository.cacheForMerchant(
      _request(now, id: 'checkin-1'),
      'owner-a',
    );
    await repository.cacheForMerchant(
      _request(now, id: 'checkin-2'),
      'owner-a',
    );
    final restaurant = _restaurant(
      policy: VisitValidationPolicy.perTransaction,
    );
    final one = await repository.approveLocally(
      checkInId: 'checkin-1',
      ownerUid: 'owner-a',
      restaurant: restaurant,
      pointsAwarded: 120,
    );
    final two = await repository.approveLocally(
      checkInId: 'checkin-2',
      ownerUid: 'owner-a',
      restaurant: restaurant,
      pointsAwarded: 120,
    );
    expect([
      one.outcome,
      two.outcome,
    ], everyElement(LocalCheckInMutationOutcome.completed));
    expect(await database.visitDao.getAllVisits(), hasLength(2));
  });

  test('17. Merchant B ne voit ni ne synchronise les données de A', () async {
    remote.offline = true;
    await repository.cacheForMerchant(_request(now), 'owner-a');
    await repository.approveLocally(
      checkInId: 'checkin-1',
      ownerUid: 'owner-a',
      restaurant: _restaurant(),
      pointsAwarded: 120,
    );
    remote.offline = false;

    expect(
      await database.checkInDao.getCheckInsForMerchant(
        'restaurant-a',
        'owner-b',
      ),
      isEmpty,
    );
    await repository.syncService.retryPendingActions(
      ownerScopeId: 'restaurant-b',
    );
    expect(remote.approveWrites, 0);
  });

  test('18. Local approved et remote approved se réconcilient', () async {
    remote.offline = true;
    await repository.cacheForMerchant(_request(now), 'owner-a');
    await repository.approveLocally(
      checkInId: 'checkin-1',
      ownerUid: 'owner-a',
      restaurant: _restaurant(),
      pointsAwarded: 120,
    );
    final subscription = repository
        .watchCheckIns(restaurantId: 'restaurant-a', ownerUid: 'owner-a')
        .listen((_) {});
    remote.emit([
      _request(
        now,
        status: CheckInStatus.approved,
        visitId: 'restaurant-a_customer-1_2026-10-12',
      ),
    ]);
    await _settle();
    expect(
      (await database.checkInDao.getCheckInById('checkin-1'))?.syncStatus,
      LocalCheckInSyncStatus.synced,
    );
    await subscription.cancel();
  });

  test('19. Local approved et remote rejected devient conflit', () async {
    remote.conflict = const CheckInConflictException('remote-rejected');
    await repository.cacheForMerchant(_request(now), 'owner-a');
    await repository.approveLocally(
      checkInId: 'checkin-1',
      ownerUid: 'owner-a',
      restaurant: _restaurant(),
      pointsAwarded: 120,
    );
    expect(
      (await _action(database, 'approveCheckIn:checkin-1'))?.status,
      PendingActionStatus.blocked,
    );
    expect(await database.visitDao.getAllVisits(), hasLength(1));
    expect(remote.approveWrites, 0);
  });

  test('20. Une Reward retry utilise le même identifiant', () async {
    remote.loseFirstApproveResponse = true;
    await repository.cacheForMerchant(_request(now), 'owner-a');
    await repository.approveLocally(
      checkInId: 'checkin-1',
      ownerUid: 'owner-a',
      restaurant: _restaurant(),
      pointsAwarded: 120,
      reward: {
        'id': 'reward-cycle-1',
        'expiresAt': now.add(const Duration(days: 30)).toIso8601String(),
      },
    );
    await repository.syncService.retryPendingActions(
      ownerScopeId: 'restaurant-a',
    );
    expect(remote.rewardIds, {'reward-cycle-1'});
  });

  test('21. Offline ne crée aucune récompense distante avant sync', () async {
    remote.offline = true;
    await repository.cacheForMerchant(_request(now), 'owner-a');

    await repository.approveLocally(
      checkInId: 'checkin-1',
      ownerUid: 'owner-a',
      restaurant: _restaurant(),
      pointsAwarded: 120,
      reward: {
        'id': 'reward-cycle-1',
        'expiresAt': now.add(const Duration(days: 30)).toIso8601String(),
      },
    );

    expect(remote.rewardIds, isEmpty);
    expect(
      (await _action(database, 'approveCheckIn:checkin-1'))?.status,
      PendingActionStatus.failed,
    );
  });
}

CheckInRepository _repository(
  AppDatabase db,
  _FakeCheckInRemote remote,
  DateTime now,
) => CheckInRepository(
  FakeFirebaseFirestore(),
  database: db,
  remoteDataSource: remote,
  syncService: CheckInSyncService(
    database: db,
    remoteDataSource: remote,
    clock: () => now,
  ),
  clock: () => now,
);

CheckInRequest _request(
  DateTime now, {
  String id = 'checkin-1',
  DateTime? expiresAt,
  CheckInStatus status = CheckInStatus.pending,
  String? visitId,
}) => CheckInRequest(
  id: id,
  customerId: 'customer-1',
  restaurantId: 'restaurant-a',
  requestedAt: now,
  expiresAt: expiresAt ?? now.add(const Duration(minutes: 10)),
  status: status,
  visitId: visitId,
);

Restaurant _restaurant({
  VisitValidationPolicy policy = VisitValidationPolicy.oncePerDay,
}) => Restaurant(
  id: 'restaurant-a',
  name: 'Restaurant A',
  cuisine: 'Test',
  distanceKm: 1,
  rewardThreshold: 10,
  rewardLabel: 'Reward',
  icon: Icons.restaurant,
  validationPolicy: policy,
  minimumHoursBetweenVisits: 4,
  ownerId: 'owner-a',
);

PendingActionsCompanion _pendingAction(String id, DateTime now) =>
    PendingActionsCompanion.insert(
      operationId: id,
      ownerScopeId: const Value('restaurant-a'),
      actionType: PendingActionType.approveCheckIn,
      entityType: 'checkIn',
      entityId: 'checkin-1',
      payload: PendingActionPayload.encode({'checkInId': 'checkin-1'}),
      createdAt: now,
      updatedAt: now,
    );

Future<PendingAction?> _action(AppDatabase db, String id) =>
    db.pendingActionDao.getActionByOperationId(id);

Future<void> _insertVisit(AppDatabase db, DateTime at) =>
    db.visitDao.insertVisit(
      LocalVisitsCompanion.insert(
        visitId: 'existing-${at.microsecondsSinceEpoch}',
        merchantId: 'restaurant-a',
        customerId: 'customer-1',
        visitedAt: at,
        syncStatus: const Value(LocalVisitSyncStatus.pending),
        createdAt: at,
        updatedAt: at,
      ),
    );

Future<void> _settle() async {
  await Future<void>.delayed(const Duration(milliseconds: 20));
}

class _FakeCheckInRemote implements CheckInRemoteDataSource {
  final _controller = StreamController<List<CheckInRequest>>.broadcast();
  bool offline = false;
  bool loseFirstApproveResponse = false;
  String? canonicalVisitId;
  CheckInConflictException? conflict;
  Object? approveError;
  int approveCalls = 0;
  int approveWrites = 0;
  int rejectWrites = 0;
  final Set<String> visitIds = {};
  final Set<String> rewardIds = {};
  final Set<String> _approved = {};

  void emit(List<CheckInRequest> items) => _controller.add(items);
  void emitError(Object error) => _controller.addError(error);
  Future<void> close() => _controller.close();

  @override
  Stream<List<CheckInRequest>> watchForMerchant(String merchantId) =>
      _controller.stream;

  @override
  Future<String> approve(Map<String, Object?> payload) async {
    approveCalls++;
    if (offline) throw Exception('offline');
    if (approveError case final value?) throw value;
    if (conflict case final value?) throw value;
    final id = payload['checkInId']! as String;
    final visitId = payload['visitId']! as String;
    visitIds.add(visitId);
    final reward = payload['reward'];
    if (reward is Map && reward['id'] is String) {
      rewardIds.add(reward['id']! as String);
    }
    if (_approved.add(id)) approveWrites++;
    if (loseFirstApproveResponse && approveCalls == 1) {
      throw TimeoutException('lost response');
    }
    return canonicalVisitId ?? visitId;
  }

  @override
  Future<void> reject(Map<String, Object?> payload) async {
    if (offline) throw Exception('offline');
    rejectWrites++;
  }
}
