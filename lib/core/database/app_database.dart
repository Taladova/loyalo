import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'pending_action_payload.dart';
import 'daos/check_in_dao.dart';
import 'daos/pending_action_dao.dart';
import 'daos/visit_dao.dart';
import 'tables/local_check_ins.dart';
import 'tables/local_visits.dart';
import 'tables/pending_actions.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [LocalVisits, PendingActions, LocalCheckIns],
  daos: [VisitDao, PendingActionDao, CheckInDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'loyalo'));

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(pendingActions, pendingActions.ownerScopeId);
        await migrator.createIndex(idxPendingActionsOwnerStatusCreatedAt);
      }
      if (from < 3) {
        await migrator.createTable(localCheckIns);
        await migrator.createIndex(idxLocalCheckinsMerchantStatusCreated);
        await migrator.createIndex(idxLocalCheckinsMerchantExpires);
        await migrator.createIndex(idxLocalCheckinsOwnerStatus);
      }
    },
  );

  Future<void> insertVisitWithPendingAction({
    required LocalVisitsCompanion visit,
    required PendingActionsCompanion action,
  }) {
    return transaction(() async {
      await visitDao.insertVisit(visit);
      await pendingActionDao.insertPendingAction(action);
    });
  }

  Future<void> approveCheckInAtomically({
    required String checkInId,
    required String ownerUid,
    required String merchantId,
    required DateTime now,
    required LocalVisitsCompanion visit,
    required PendingActionsCompanion action,
  }) => transaction(() async {
    final checkIn = await checkInDao.getCheckInById(checkInId);
    if (checkIn == null ||
        checkIn.ownerUid != ownerUid ||
        checkIn.merchantId != merchantId) {
      throw StateError('check-in-not-found');
    }
    if (checkIn.businessStatus != LocalCheckInBusinessStatus.pending) {
      throw StateError('check-in-not-pending');
    }
    if (!checkIn.expiresAt.isAfter(now.toUtc())) {
      await checkInDao.updateBusinessStatus(
        checkInId,
        LocalCheckInBusinessStatus.expired,
        now.toUtc(),
      );
      throw StateError('check-in-expired');
    }
    await visitDao.insertVisit(visit);
    await pendingActionDao.insertPendingAction(action);
    await checkInDao.updateBusinessStatus(
      checkInId,
      LocalCheckInBusinessStatus.approved,
      now.toUtc(),
      visitId: visit.visitId.value,
    );
    await checkInDao.updateSyncStatus(
      checkInId,
      LocalCheckInSyncStatus.pending,
      now.toUtc(),
    );
  });

  Future<void> rejectCheckInAtomically({
    required String checkInId,
    required String ownerUid,
    required String merchantId,
    required DateTime now,
    required PendingActionsCompanion action,
  }) => transaction(() async {
    final checkIn = await checkInDao.getCheckInById(checkInId);
    if (checkIn == null ||
        checkIn.ownerUid != ownerUid ||
        checkIn.merchantId != merchantId) {
      throw StateError('check-in-not-found');
    }
    if (checkIn.businessStatus != LocalCheckInBusinessStatus.pending) {
      throw StateError('check-in-not-pending');
    }
    if (!checkIn.expiresAt.isAfter(now.toUtc())) {
      await checkInDao.updateBusinessStatus(
        checkInId,
        LocalCheckInBusinessStatus.expired,
        now.toUtc(),
      );
      throw StateError('check-in-expired');
    }
    await pendingActionDao.insertPendingAction(action);
    await checkInDao.updateBusinessStatus(
      checkInId,
      LocalCheckInBusinessStatus.rejected,
      now.toUtc(),
    );
    await checkInDao.updateSyncStatus(
      checkInId,
      LocalCheckInSyncStatus.pending,
      now.toUtc(),
    );
  });

  Future<void> reconcileApprovedCheckInAtomically({
    required String operationId,
    required String checkInId,
    required String provisionalVisitId,
    required String canonicalVisitId,
    required DateTime now,
  }) => transaction(() async {
    if (canonicalVisitId.isEmpty) {
      throw StateError('canonical-visit-id-empty');
    }
    final action = await pendingActionDao.getActionByOperationId(operationId);
    final checkIn = await checkInDao.getCheckInById(checkInId);
    final provisional = await visitDao.getVisitById(provisionalVisitId);
    if (action == null ||
        action.actionType != PendingActionType.approveCheckIn ||
        action.entityId != checkInId ||
        checkIn == null ||
        provisional == null ||
        checkIn.merchantId != provisional.merchantId ||
        checkIn.customerId != provisional.customerId) {
      throw StateError('approval-reconciliation-state-invalid');
    }

    final canonical = canonicalVisitId == provisionalVisitId
        ? provisional
        : await visitDao.getVisitById(canonicalVisitId);
    if (canonical != null &&
        (canonical.merchantId != provisional.merchantId ||
            canonical.customerId != provisional.customerId)) {
      throw StateError('canonical-visit-identity-conflict');
    }

    final preserved = canonical ?? provisional;
    await visitDao.upsertVisit(
      LocalVisitsCompanion.insert(
        visitId: canonicalVisitId,
        merchantId: preserved.merchantId,
        customerId: preserved.customerId,
        visitedAt: preserved.visitedAt,
        syncStatus: const Value(LocalVisitSyncStatus.synced),
        createdAt: canonical == null
            ? provisional.createdAt
            : canonical.createdAt.isBefore(provisional.createdAt)
            ? canonical.createdAt
            : provisional.createdAt,
        updatedAt: now,
      ),
    );
    if (canonicalVisitId != provisionalVisitId) {
      await visitDao.deleteVisit(provisionalVisitId);
    }

    await checkInDao.updateBusinessStatus(
      checkInId,
      LocalCheckInBusinessStatus.approved,
      now,
      visitId: canonicalVisitId,
    );
    await checkInDao.updateSyncStatus(
      checkInId,
      LocalCheckInSyncStatus.synced,
      now,
    );

    final payload = PendingActionPayload.decode(action.payload);
    payload['visitId'] = canonicalVisitId;
    await (update(
      pendingActions,
    )..where((row) => row.operationId.equals(operationId))).write(
      PendingActionsCompanion(
        payload: Value(PendingActionPayload.encode(payload)),
        status: const Value(PendingActionStatus.synced),
        updatedAt: Value(now),
        lastError: const Value(null),
      ),
    );
  });
}
