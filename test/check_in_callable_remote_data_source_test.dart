import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loyalo/core/database/app_database.dart';
import 'package:loyalo/core/database/pending_action_payload.dart';
import 'package:loyalo/core/database/tables/local_check_ins.dart';
import 'package:loyalo/core/database/tables/local_visits.dart';
import 'package:loyalo/core/database/tables/pending_actions.dart';
import 'package:loyalo/features/checkins/data/check_in_remote_data_source.dart';
import 'package:loyalo/features/checkins/data/check_in_sync_service.dart';
import 'package:loyalo/models/check_in_request.dart';

void main() {
  group('CallableApproveCheckInRemoteDataSource', () {
    late _CompatibilityRemote compatibility;
    late _FakeSecureGateway gateway;
    late CallableApproveCheckInRemoteDataSource remote;

    setUp(() {
      compatibility = _CompatibilityRemote();
      gateway = _FakeSecureGateway();
      remote = CallableApproveCheckInRemoteDataSource(
        compatibilityDataSource: compatibility,
        secureGateway: gateway,
      );
    });

    test('appelle la callable avec checkInId et operationId exacts', () async {
      await remote.approve(_payload());

      expect(gateway.checkInIds, ['checkin-1']);
      expect(gateway.operationIds, ['approveCheckIn:checkin-1']);
      expect(compatibility.approveCalls, 0);
    });

    test('conserve le même operationId pendant les retries', () async {
      await remote.approve(_payload());
      await remote.approve(_payload());

      expect(gateway.operationIds, [
        'approveCheckIn:checkin-1',
        'approveCheckIn:checkin-1',
      ]);
    });

    test('accepte success approved cohérent', () async {
      await expectLater(remote.approve(_payload()), completes);
    });

    test('accepte alreadyProcessed uniquement avec les mêmes IDs', () async {
      gateway.result = _result(alreadyProcessed: true);
      await expectLater(remote.approve(_payload()), completes);
    });

    test(
      'retourne le visitId serveur même s’il diffère du provisoire',
      () async {
        gateway.result = _result(visitId: 'server-different-visit');

        expect(await remote.approve(_payload()), 'server-different-visit');
      },
    );

    test(
      'ne fait aucun fallback Firestore après une erreur callable',
      () async {
        gateway.error = const CheckInRemoteException(
          code: 'unavailable',
          message: 'offline',
        );

        await expectLater(
          remote.approve(_payload()),
          throwsA(isA<CheckInRemoteException>()),
        );
        expect(compatibility.approveCalls, 0);
      },
    );

    test('préserve reject sur le mode de compatibilité', () async {
      await remote.reject({'operationId': 'rejectCheckIn:checkin-1'});
      expect(compatibility.rejectCalls, 1);
      expect(gateway.calls, 0);
    });

    test('sélectionne explicitement le mode désactivé ou activé', () {
      expect(
        selectCheckInRemoteDataSource(
          secureApprovalEnabled: false,
          compatibilityDataSource: compatibility,
          secureGateway: gateway,
        ),
        same(compatibility),
      );
      expect(
        selectCheckInRemoteDataSource(
          secureApprovalEnabled: true,
          compatibilityDataSource: compatibility,
          secureGateway: gateway,
        ),
        isA<CallableApproveCheckInRemoteDataSource>(),
      );
      expect(secureApproveCheckInEnabled, isFalse);
      expect(secureRejectCheckInEnabled, isFalse);
    });
  });

  group('Callable secure rejection', () {
    late _CompatibilityRemote compatibility;
    late _FakeSecureRejectionGateway gateway;
    late CheckInRemoteDataSource remote;

    setUp(() {
      compatibility = _CompatibilityRemote();
      gateway = _FakeSecureRejectionGateway();
      remote = selectCheckInRemoteDataSource(
        secureApprovalEnabled: false,
        secureRejectionEnabled: true,
        compatibilityDataSource: compatibility,
        secureRejectionGateway: gateway,
      );
    });

    test('envoie uniquement les identifiants déterministes', () async {
      await remote.reject(_rejectPayload());

      expect(gateway.checkInIds, ['checkin-1']);
      expect(gateway.operationIds, ['rejectCheckIn:checkin-1']);
      expect(compatibility.rejectCalls, 0);
    });

    test('accepte un replay idempotent cohérent', () async {
      gateway.result = _rejectionResult(alreadyProcessed: true);
      await expectLater(remote.reject(_rejectPayload()), completes);
    });

    test('ne fait aucun fallback après une erreur callable', () async {
      gateway.error = const CheckInRemoteException(
        code: 'unavailable',
        message: 'offline',
      );

      await expectLater(
        remote.reject(_rejectPayload()),
        throwsA(isA<CheckInRemoteException>()),
      );
      expect(compatibility.rejectCalls, 0);
    });

    test('flag désactivé conserve le refus Firestore historique', () async {
      final compatibilityOnly = selectCheckInRemoteDataSource(
        secureApprovalEnabled: false,
        secureRejectionEnabled: false,
        compatibilityDataSource: compatibility,
        secureRejectionGateway: gateway,
      );

      await compatibilityOnly.reject(_rejectPayload());
      expect(compatibility.rejectCalls, 1);
      expect(gateway.calls, 0);
    });
  });

  group('CheckInSyncService avec callable', () {
    final now = DateTime.utc(2026, 10, 28, 14);
    late AppDatabase database;
    late _FakeSecureGateway gateway;
    late _CompatibilityRemote compatibility;
    late CheckInSyncService service;

    setUp(() async {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      gateway = _FakeSecureGateway();
      compatibility = _CompatibilityRemote();
      service = CheckInSyncService(
        database: database,
        remoteDataSource: CallableApproveCheckInRemoteDataSource(
          compatibilityDataSource: compatibility,
          secureGateway: gateway,
        ),
        clock: () => now,
      );
      await _seedPendingApproval(database, now);
    });

    tearDown(() => database.close());

    test('confirmation serveur marque les trois états synced', () async {
      await service.syncAction(
        'approveCheckIn:checkin-1',
        ownerScopeId: 'restaurant-a',
      );

      expect(
        (await database.checkInDao.getCheckInById('checkin-1'))?.syncStatus,
        LocalCheckInSyncStatus.synced,
      );
      expect(
        (await database.visitDao.getVisitById(_visitId))?.syncStatus,
        LocalVisitSyncStatus.synced,
      );
      expect((await _action(database))?.status, PendingActionStatus.synced);
      expect(await database.visitDao.getAllVisits(), hasLength(1));
      expect(compatibility.approveCalls, 0);
    });

    test(
      'un visitId serveur d’un autre jour remplace atomiquement le provisoire',
      () async {
        const canonicalVisitId = 'restaurant-a_customer-1_2026-10-29';
        gateway.result = _result(visitId: canonicalVisitId);
        final provisionalBefore = await database.visitDao.getVisitById(
          _visitId,
        );

        await service.syncAction(
          'approveCheckIn:checkin-1',
          ownerScopeId: 'restaurant-a',
        );

        final canonical = await database.visitDao.getVisitById(
          canonicalVisitId,
        );
        final checkIn = await database.checkInDao.getCheckInById('checkin-1');
        final action = await _action(database);
        expect(await database.visitDao.getVisitById(_visitId), isNull);
        expect(canonical, isNotNull);
        expect(canonical?.visitedAt, provisionalBefore?.visitedAt);
        expect(canonical?.createdAt, provisionalBefore?.createdAt);
        expect(canonical?.syncStatus, LocalVisitSyncStatus.synced);
        expect(checkIn?.visitId, canonicalVisitId);
        expect(checkIn?.syncStatus, LocalCheckInSyncStatus.synced);
        expect(action?.status, PendingActionStatus.synced);
        expect(
          PendingActionPayload.decode(action!.payload)['visitId'],
          canonicalVisitId,
        );
        expect(await database.visitDao.getAllVisits(), hasLength(1));
      },
    );

    test(
      'une Visit canonique déjà hydratée est fusionnée sans doublon',
      () async {
        const canonicalVisitId = 'restaurant-a_customer-1_2026-10-29';
        gateway.result = _result(visitId: canonicalVisitId);
        final hydratedAt = now.subtract(const Duration(minutes: 2));
        await database.visitDao.insertVisit(
          LocalVisitsCompanion.insert(
            visitId: canonicalVisitId,
            merchantId: 'restaurant-a',
            customerId: 'customer-1',
            visitedAt: hydratedAt,
            syncStatus: const Value(LocalVisitSyncStatus.synced),
            createdAt: hydratedAt,
            updatedAt: hydratedAt,
          ),
        );

        await service.syncAction(
          'approveCheckIn:checkin-1',
          ownerScopeId: 'restaurant-a',
        );

        final visits = await database.visitDao.getAllVisits();
        expect(visits, hasLength(1));
        expect(visits.single.visitId, canonicalVisitId);
        expect(visits.single.visitedAt.toUtc(), hydratedAt.toUtc());
      },
    );

    test(
      'un échec local après succès serveur reste retryable et se réconcilie',
      () async {
        const canonicalVisitId = 'restaurant-a_customer-1_2026-10-29';
        gateway.result = _result(visitId: canonicalVisitId);
        await database.visitDao.insertVisit(
          LocalVisitsCompanion.insert(
            visitId: canonicalVisitId,
            merchantId: 'restaurant-other',
            customerId: 'customer-other',
            visitedAt: now,
            syncStatus: const Value(LocalVisitSyncStatus.synced),
            createdAt: now,
            updatedAt: now,
          ),
        );

        await expectLater(
          service.syncAction(
            'approveCheckIn:checkin-1',
            ownerScopeId: 'restaurant-a',
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'canonical-visit-identity-conflict',
            ),
          ),
        );

        expect(await database.visitDao.getVisitById(_visitId), isNotNull);
        expect(
          (await database.checkInDao.getCheckInById('checkin-1'))?.visitId,
          _visitId,
        );
        expect((await _action(database))?.status, PendingActionStatus.failed);

        await database.visitDao.deleteVisit(canonicalVisitId);
        gateway.result = _result(
          visitId: canonicalVisitId,
          alreadyProcessed: true,
        );
        await service.retryPendingActions(ownerScopeId: 'restaurant-a');

        expect(gateway.calls, 2);
        expect(await database.visitDao.getVisitById(_visitId), isNull);
        expect(
          await database.visitDao.getVisitById(canonicalVisitId),
          isNotNull,
        );
        expect((await _action(database))?.status, PendingActionStatus.synced);
      },
    );

    test('timeout conserve une action retryable', () async {
      gateway.error = TimeoutException('lost response');

      await expectLater(
        service.syncAction(
          'approveCheckIn:checkin-1',
          ownerScopeId: 'restaurant-a',
        ),
        throwsA(isA<TimeoutException>()),
      );
      expect((await _action(database))?.status, PendingActionStatus.failed);
    });

    test('unavailable conserve une action retryable', () async {
      gateway.error = const CheckInRemoteException(
        code: 'unavailable',
        message: 'temporarily unavailable',
      );

      await expectLater(
        service.syncAction(
          'approveCheckIn:checkin-1',
          ownerScopeId: 'restaurant-a',
        ),
        throwsA(isA<CheckInRemoteException>()),
      );
      expect((await _action(database))?.status, PendingActionStatus.failed);
    });

    test('expiration serveur bloque et expire le CheckIn local', () async {
      gateway.error = const CheckInRemoteException(
        code: 'failed-precondition',
        reason: 'check-in-expired',
        message: 'expired',
      );

      await expectLater(
        service.syncAction(
          'approveCheckIn:checkin-1',
          ownerScopeId: 'restaurant-a',
        ),
        throwsA(isA<CheckInRemoteException>()),
      );
      final checkIn = await database.checkInDao.getCheckInById('checkin-1');
      expect(checkIn?.businessStatus, LocalCheckInBusinessStatus.expired);
      expect(checkIn?.syncStatus, LocalCheckInSyncStatus.failed);
      expect(
        (await database.visitDao.getVisitById(_visitId))?.syncStatus,
        LocalVisitSyncStatus.failed,
      );
      expect((await _action(database))?.status, PendingActionStatus.blocked);
      expect(
        (await _action(database))?.lastError,
        contains('check-in-expired'),
      );
    });

    test('permission-denied devient un conflit permanent', () async {
      gateway.error = const CheckInRemoteException(
        code: 'permission-denied',
        message: 'forbidden',
      );

      await expectLater(
        service.syncAction(
          'approveCheckIn:checkin-1',
          ownerScopeId: 'restaurant-a',
        ),
        throwsA(isA<CheckInRemoteException>()),
      );
      expect((await _action(database))?.status, PendingActionStatus.blocked);
    });

    test('session expirée reste retryable après reconnexion', () async {
      gateway.error = const CheckInRemoteException(
        code: 'unauthenticated',
        message: 'sign in again',
      );

      await expectLater(
        service.syncAction(
          'approveCheckIn:checkin-1',
          ownerScopeId: 'restaurant-a',
        ),
        throwsA(isA<CheckInRemoteException>()),
      );
      expect((await _action(database))?.status, PendingActionStatus.failed);

      gateway.error = null;
      await service.retryPendingActions(ownerScopeId: 'restaurant-a');
      expect((await _action(database))?.status, PendingActionStatus.synced);
    });

    test('une action syncing stale est reprise après redémarrage', () async {
      await database.pendingActionDao.markSyncing(
        'approveCheckIn:checkin-1',
        now.subtract(const Duration(minutes: 6)),
      );

      await service.retryPendingActions(ownerScopeId: 'restaurant-a');

      expect(gateway.calls, 1);
      expect((await _action(database))?.status, PendingActionStatus.synced);
    });

    test('Merchant B ne peut pas envoyer une action de Merchant A', () async {
      await service.retryPendingActions(ownerScopeId: 'restaurant-b');

      expect(gateway.calls, 0);
      expect((await _action(database))?.status, PendingActionStatus.pending);
    });
  });

  group('CheckInSyncService avec refus callable', () {
    final now = DateTime.utc(2026, 10, 28, 14);
    late AppDatabase database;
    late _CompatibilityRemote compatibility;
    late _FakeSecureRejectionGateway gateway;
    late CheckInSyncService service;

    setUp(() async {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      compatibility = _CompatibilityRemote();
      gateway = _FakeSecureRejectionGateway();
      gateway.result = _rejectionResult(checkInId: 'checkin-reject');
      service = CheckInSyncService(
        database: database,
        remoteDataSource: selectCheckInRemoteDataSource(
          secureApprovalEnabled: false,
          secureRejectionEnabled: true,
          compatibilityDataSource: compatibility,
          secureRejectionGateway: gateway,
        ),
        clock: () => now,
      );
      await _seedPendingRejection(database, now);
    });

    tearDown(() => database.close());

    test('confirme le refus sans créer de visite', () async {
      await service.syncAction(
        'rejectCheckIn:checkin-reject',
        ownerScopeId: 'restaurant-a',
      );

      final checkIn = await database.checkInDao.getCheckInById(
        'checkin-reject',
      );
      final action = await database.pendingActionDao.getActionByOperationId(
        'rejectCheckIn:checkin-reject',
      );
      expect(checkIn?.businessStatus, LocalCheckInBusinessStatus.rejected);
      expect(checkIn?.syncStatus, LocalCheckInSyncStatus.synced);
      expect(action?.status, PendingActionStatus.synced);
      expect(await database.visitDao.getAllVisits(), isEmpty);
      expect(compatibility.rejectCalls, 0);
    });

    test('erreur réseau reste retryable puis se synchronise', () async {
      gateway.error = const CheckInRemoteException(
        code: 'unavailable',
        message: 'offline',
      );
      await expectLater(
        service.syncAction(
          'rejectCheckIn:checkin-reject',
          ownerScopeId: 'restaurant-a',
        ),
        throwsA(isA<CheckInRemoteException>()),
      );
      gateway.error = null;

      await service.retryPendingActions(ownerScopeId: 'restaurant-a');
      final action = await database.pendingActionDao.getActionByOperationId(
        'rejectCheckIn:checkin-reject',
      );
      expect(action?.status, PendingActionStatus.synced);
      expect(gateway.calls, 2);
    });

    test('conflit avec une approbation distante bloque le retry', () async {
      gateway.error = const CheckInRemoteException(
        code: 'failed-precondition',
        reason: 'check-in-approved',
        message: 'already approved',
      );

      await expectLater(
        service.syncAction(
          'rejectCheckIn:checkin-reject',
          ownerScopeId: 'restaurant-a',
        ),
        throwsA(isA<CheckInRemoteException>()),
      );
      final action = await database.pendingActionDao.getActionByOperationId(
        'rejectCheckIn:checkin-reject',
      );
      expect(action?.status, PendingActionStatus.blocked);
      expect(await database.visitDao.getAllVisits(), isEmpty);
    });
  });
}

const _visitId = 'restaurant-a_customer-1_2026-10-28';

Map<String, Object?> _payload() => {
  'operationId': 'approveCheckIn:checkin-1',
  'checkInId': 'checkin-1',
  'visitId': _visitId,
  'ownerUid': 'owner-a',
  'merchantId': 'restaurant-a',
  'customerId': 'customer-1',
  'pointsAwarded': 999,
};

Map<String, Object?> _rejectPayload() => {
  'operationId': 'rejectCheckIn:checkin-1',
  'checkInId': 'checkin-1',
  'ownerUid': 'owner-a',
  'merchantId': 'restaurant-a',
  'actedAt': DateTime.utc(2026, 10, 28, 14).toIso8601String(),
};

SecureApprovalResult _result({
  String visitId = _visitId,
  bool alreadyProcessed = false,
}) => SecureApprovalResult(
  success: true,
  status: 'approved',
  checkInId: 'checkin-1',
  operationId: 'approveCheckIn:checkin-1',
  visitId: visitId,
  alreadyProcessed: alreadyProcessed,
);

SecureRejectionResult _rejectionResult({
  String checkInId = 'checkin-1',
  bool alreadyProcessed = false,
}) => SecureRejectionResult(
  success: true,
  status: 'rejected',
  checkInId: checkInId,
  operationId: 'rejectCheckIn:$checkInId',
  alreadyProcessed: alreadyProcessed,
);

class _FakeSecureGateway implements SecureCheckInApprovalGateway {
  SecureApprovalResult result = _result();
  Object? error;
  int calls = 0;
  final List<String> checkInIds = [];
  final List<String> operationIds = [];

  @override
  Future<SecureApprovalResult> approve({
    required String checkInId,
    required String operationId,
  }) async {
    calls++;
    checkInIds.add(checkInId);
    operationIds.add(operationId);
    if (error case final value?) throw value;
    return result;
  }
}

class _FakeSecureRejectionGateway implements SecureCheckInRejectionGateway {
  SecureRejectionResult result = _rejectionResult();
  Object? error;
  int calls = 0;
  final List<String> checkInIds = [];
  final List<String> operationIds = [];

  @override
  Future<SecureRejectionResult> reject({
    required String checkInId,
    required String operationId,
  }) async {
    calls++;
    checkInIds.add(checkInId);
    operationIds.add(operationId);
    if (error case final value?) throw value;
    return result;
  }
}

class _CompatibilityRemote implements CheckInRemoteDataSource {
  int approveCalls = 0;
  int rejectCalls = 0;

  @override
  Future<String> approve(Map<String, Object?> payload) async {
    approveCalls++;
    return payload['visitId']! as String;
  }

  @override
  Future<void> reject(Map<String, Object?> payload) async {
    rejectCalls++;
  }

  @override
  Stream<List<CheckInRequest>> watchForMerchant(String merchantId) =>
      const Stream.empty();
}

Future<void> _seedPendingApproval(AppDatabase database, DateTime now) async {
  await database.checkInDao.upsertCheckIn(
    LocalCheckInsCompanion.insert(
      checkInId: 'checkin-1',
      ownerUid: 'owner-a',
      merchantId: 'restaurant-a',
      customerId: 'customer-1',
      createdAt: now.subtract(const Duration(minutes: 1)),
      expiresAt: now.add(const Duration(minutes: 9)),
      businessStatus: LocalCheckInBusinessStatus.approved,
      syncStatus: const Value(LocalCheckInSyncStatus.pending),
      updatedAt: now,
      visitId: const Value(_visitId),
    ),
  );
  await database.visitDao.insertVisit(
    LocalVisitsCompanion.insert(
      visitId: _visitId,
      merchantId: 'restaurant-a',
      customerId: 'customer-1',
      visitedAt: now,
      syncStatus: const Value(LocalVisitSyncStatus.pending),
      createdAt: now,
      updatedAt: now,
    ),
  );
  await database.pendingActionDao.insertPendingAction(
    PendingActionsCompanion.insert(
      operationId: 'approveCheckIn:checkin-1',
      ownerScopeId: const Value('restaurant-a'),
      actionType: PendingActionType.approveCheckIn,
      entityType: 'checkIn',
      entityId: 'checkin-1',
      payload: PendingActionPayload.encode(_payload()),
      createdAt: now,
      updatedAt: now,
    ),
  );
}

Future<PendingAction?> _action(AppDatabase database) => database
    .pendingActionDao
    .getActionByOperationId('approveCheckIn:checkin-1');

Future<void> _seedPendingRejection(AppDatabase database, DateTime now) async {
  await database.checkInDao.upsertCheckIn(
    LocalCheckInsCompanion.insert(
      checkInId: 'checkin-reject',
      ownerUid: 'owner-a',
      merchantId: 'restaurant-a',
      customerId: 'customer-1',
      createdAt: now.subtract(const Duration(minutes: 1)),
      expiresAt: now.add(const Duration(minutes: 9)),
      businessStatus: LocalCheckInBusinessStatus.rejected,
      syncStatus: const Value(LocalCheckInSyncStatus.pending),
      updatedAt: now,
    ),
  );
  await database.pendingActionDao.insertPendingAction(
    PendingActionsCompanion.insert(
      operationId: 'rejectCheckIn:checkin-reject',
      ownerScopeId: const Value('restaurant-a'),
      actionType: PendingActionType.rejectCheckIn,
      entityType: 'checkIn',
      entityId: 'checkin-reject',
      payload: PendingActionPayload.encode({
        'operationId': 'rejectCheckIn:checkin-reject',
        'checkInId': 'checkin-reject',
        'ownerUid': 'owner-a',
        'merchantId': 'restaurant-a',
        'actedAt': now.toIso8601String(),
      }),
      createdAt: now,
      updatedAt: now,
    ),
  );
}
