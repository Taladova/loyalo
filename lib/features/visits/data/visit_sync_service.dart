import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/pending_action_payload.dart';
import '../../../core/database/tables/local_visits.dart';
import '../../../core/database/tables/pending_actions.dart';
import 'visit_mapper.dart';
import 'visit_remote_data_source.dart';

class VisitSyncService {
  static const staleClaimDuration = Duration(minutes: 5);

  VisitSyncService({
    required AppDatabase database,
    required VisitRemoteDataSource remoteDataSource,
    DateTime Function()? clock,
  }) : _database = database,
       _remoteDataSource = remoteDataSource,
       _clock = clock ?? DateTime.now;

  final AppDatabase _database;
  final VisitRemoteDataSource _remoteDataSource;
  final DateTime Function() _clock;

  Future<void> syncAction(
    String operationId, {
    required String ownerScopeId,
  }) async {
    final action = await _database.pendingActionDao.getActionByOperationId(
      operationId,
    );
    if (action == null ||
        action.actionType != PendingActionType.createVisit ||
        action.ownerScopeId != ownerScopeId ||
        action.status == PendingActionStatus.synced ||
        action.status == PendingActionStatus.blocked) {
      return;
    }

    final claimed = await _database.pendingActionDao.claimAction(
      operationId: operationId,
      ownerScopeId: ownerScopeId,
      updatedAt: _clock(),
    );
    if (!claimed) return;
    debugPrint('[SYNC] visit operation claimed');
    await _database.visitDao.markSyncStatus(
      action.entityId,
      LocalVisitSyncStatus.syncing,
      _clock(),
    );
    try {
      final payload = PendingActionPayload.decode(action.payload);
      final visit = VisitMapper.fromPendingPayload(payload);
      await _remoteDataSource.upsertVisit(visit);
      await _database.transaction(() async {
        await _database.visitDao.markSyncStatus(
          visit.id,
          LocalVisitSyncStatus.synced,
          _clock(),
        );
        await _database.pendingActionDao.markSynced(operationId, _clock());
      });
      debugPrint('[SYNC] visit synced');
    } catch (error) {
      final permanent = _isPermanent(error);
      await _database.transaction(() async {
        await _database.visitDao.markSyncStatus(
          action.entityId,
          LocalVisitSyncStatus.failed,
          _clock(),
        );
        if (permanent) {
          await _database.pendingActionDao.markBlocked(
            operationId,
            error: error.toString(),
            updatedAt: _clock(),
          );
        } else {
          await _database.pendingActionDao.markFailed(
            operationId,
            error: error.toString(),
            updatedAt: _clock(),
          );
        }
      });
      final failed = await _database.pendingActionDao.getActionByOperationId(
        operationId,
      );
      debugPrint('[SYNC] visit failed retry=${failed?.retryCount ?? 0}');
      rethrow;
    }
  }

  Future<void> retryPendingActions({required String ownerScopeId}) async {
    final now = _clock();
    final stale = await _database.pendingActionDao.recoverStaleSyncingActions(
      ownerScopeId: ownerScopeId,
      staleBefore: now.subtract(staleClaimDuration),
      updatedAt: now,
    );
    for (final action in stale) {
      if (action.actionType != PendingActionType.createVisit) continue;
      await _database.visitDao.markSyncStatus(
        action.entityId,
        LocalVisitSyncStatus.pending,
        now,
      );
      debugPrint('[SYNC] stale operation recovered');
    }

    final actions = await _database.pendingActionDao.getSyncableActions(
      ownerScopeId,
    );
    debugPrint('[SYNC] pending visits found: ${actions.length}');
    for (final action in actions) {
      if (action.actionType != PendingActionType.createVisit) continue;
      try {
        await syncAction(action.operationId, ownerScopeId: ownerScopeId);
      } catch (_) {
        // One failed operation must not prevent later actions from retrying.
      }
    }
  }

  bool _isPermanent(Object error) {
    if (error is FormatException || error is TypeError) return true;
    if (error is FirebaseException) {
      return const {
        'permission-denied',
        'invalid-argument',
        'failed-precondition',
        'unauthenticated',
      }.contains(error.code);
    }
    return false;
  }
}
