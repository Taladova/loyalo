import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/pending_action_payload.dart';
import '../../../core/database/tables/local_check_ins.dart';
import '../../../core/database/tables/local_visits.dart';
import '../../../core/database/tables/pending_actions.dart';
import 'check_in_remote_data_source.dart';

class CheckInSyncService {
  static const staleClaimDuration = Duration(minutes: 5);

  CheckInSyncService({
    required AppDatabase database,
    required CheckInRemoteDataSource remoteDataSource,
    DateTime Function()? clock,
  }) : _database = database,
       _remote = remoteDataSource,
       _clock = clock ?? DateTime.now;

  final AppDatabase _database;
  final CheckInRemoteDataSource _remote;
  final DateTime Function() _clock;

  Future<void> retryPendingActions({required String ownerScopeId}) async {
    final now = _clock().toUtc();
    final stale = await _database.pendingActionDao.recoverStaleSyncingActions(
      ownerScopeId: ownerScopeId,
      staleBefore: now.subtract(staleClaimDuration),
      updatedAt: now,
    );
    for (final action in stale.where(
      (item) =>
          item.actionType == PendingActionType.approveCheckIn ||
          item.actionType == PendingActionType.rejectCheckIn,
    )) {
      await _database.checkInDao.updateSyncStatus(
        action.entityId,
        LocalCheckInSyncStatus.pending,
        now,
      );
      final payload = PendingActionPayload.decode(action.payload);
      final visitId = payload['visitId'];
      if (visitId is String) {
        await _database.visitDao.markSyncStatus(
          visitId,
          LocalVisitSyncStatus.pending,
          now,
        );
      }
    }
    final actions = await _database.pendingActionDao.getSyncableActions(
      ownerScopeId,
    );
    for (final action in actions.where(
      (item) =>
          item.actionType == PendingActionType.approveCheckIn ||
          item.actionType == PendingActionType.rejectCheckIn,
    )) {
      try {
        await syncAction(action.operationId, ownerScopeId: ownerScopeId);
      } catch (_) {}
    }
  }

  Future<void> syncAction(
    String operationId, {
    required String ownerScopeId,
  }) async {
    final action = await _database.pendingActionDao.getActionByOperationId(
      operationId,
    );
    if (action == null ||
        action.ownerScopeId != ownerScopeId ||
        action.status == PendingActionStatus.synced ||
        action.status == PendingActionStatus.blocked ||
        (action.actionType != PendingActionType.approveCheckIn &&
            action.actionType != PendingActionType.rejectCheckIn)) {
      return;
    }
    final claimed = await _database.pendingActionDao.claimAction(
      operationId: operationId,
      ownerScopeId: ownerScopeId,
      updatedAt: _clock().toUtc(),
    );
    if (!claimed) return;
    final payload = PendingActionPayload.decode(action.payload);
    final visitId = payload['visitId'] as String?;
    await _database.checkInDao.updateSyncStatus(
      action.entityId,
      LocalCheckInSyncStatus.syncing,
      _clock().toUtc(),
    );
    if (visitId != null) {
      await _database.visitDao.markSyncStatus(
        visitId,
        LocalVisitSyncStatus.syncing,
        _clock().toUtc(),
      );
    }
    try {
      if (action.actionType == PendingActionType.approveCheckIn) {
        if (visitId == null) {
          throw const CheckInConflictException('local-visit-id-missing');
        }
        final canonicalVisitId = await _remote.approve(payload);
        await _database.reconcileApprovedCheckInAtomically(
          operationId: operationId,
          checkInId: action.entityId,
          provisionalVisitId: visitId,
          canonicalVisitId: canonicalVisitId,
          now: _clock().toUtc(),
        );
      } else {
        await _remote.reject(payload);
        await _database.transaction(() async {
          await _database.checkInDao.updateSyncStatus(
            action.entityId,
            LocalCheckInSyncStatus.synced,
            _clock().toUtc(),
          );
          await _database.pendingActionDao.markSynced(
            operationId,
            _clock().toUtc(),
          );
        });
      }
      debugPrint('[SYNC] check-in synced');
    } catch (error) {
      final permanent =
          error is CheckInConflictException ||
          (error is CheckInRemoteException && !error.isTemporary) ||
          error is FormatException ||
          error is TypeError ||
          (error is FirebaseException &&
              const {
                'permission-denied',
                'invalid-argument',
              }.contains(error.code));
      await _database.transaction(() async {
        if (error is CheckInRemoteException &&
            error.reason == 'check-in-expired') {
          await _database.checkInDao.updateBusinessStatus(
            action.entityId,
            LocalCheckInBusinessStatus.expired,
            _clock().toUtc(),
          );
        }
        await _database.checkInDao.updateSyncStatus(
          action.entityId,
          LocalCheckInSyncStatus.failed,
          _clock().toUtc(),
        );
        if (visitId != null) {
          await _database.visitDao.markSyncStatus(
            visitId,
            LocalVisitSyncStatus.failed,
            _clock().toUtc(),
          );
        }
        if (permanent) {
          await _database.pendingActionDao.markBlocked(
            operationId,
            error: error.toString(),
            updatedAt: _clock().toUtc(),
          );
        } else {
          await _database.pendingActionDao.markFailed(
            operationId,
            error: error.toString(),
            updatedAt: _clock().toUtc(),
          );
        }
      });
      rethrow;
    }
  }
}
