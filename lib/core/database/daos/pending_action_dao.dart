import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/pending_actions.dart';

part 'pending_action_dao.g.dart';

@DriftAccessor(tables: [PendingActions])
class PendingActionDao extends DatabaseAccessor<AppDatabase>
    with _$PendingActionDaoMixin {
  PendingActionDao(super.attachedDatabase);

  Future<int> insertPendingAction(PendingActionsCompanion action) =>
      into(pendingActions).insert(action);

  Future<List<PendingAction>> getPendingActions() =>
      (select(pendingActions)
            ..where(
              (action) =>
                  action.status.equals(PendingActionStatus.pending.name),
            )
            ..orderBy([(action) => OrderingTerm.asc(action.createdAt)]))
          .get();

  Future<List<PendingAction>> getSyncableActions(String ownerScopeId) =>
      (select(pendingActions)
            ..where(
              (action) =>
                  action.ownerScopeId.equals(ownerScopeId) &
                  (action.status.equals(PendingActionStatus.pending.name) |
                      action.status.equals(PendingActionStatus.failed.name)),
            )
            ..orderBy([(action) => OrderingTerm.asc(action.createdAt)]))
          .get();

  Future<bool> claimAction({
    required String operationId,
    required String ownerScopeId,
    required DateTime updatedAt,
  }) async {
    final changed =
        await (update(pendingActions)..where(
              (action) =>
                  action.operationId.equals(operationId) &
                  action.ownerScopeId.equals(ownerScopeId) &
                  (action.status.equals(PendingActionStatus.pending.name) |
                      action.status.equals(PendingActionStatus.failed.name)),
            ))
            .write(
              PendingActionsCompanion(
                status: const Value(PendingActionStatus.syncing),
                updatedAt: Value(updatedAt),
              ),
            );
    return changed == 1;
  }

  Future<List<PendingAction>> recoverStaleSyncingActions({
    required String ownerScopeId,
    required DateTime staleBefore,
    required DateTime updatedAt,
  }) async {
    final stale =
        await (select(pendingActions)..where(
              (action) =>
                  action.ownerScopeId.equals(ownerScopeId) &
                  action.status.equals(PendingActionStatus.syncing.name) &
                  action.updatedAt.isSmallerThanValue(staleBefore),
            ))
            .get();
    for (final action in stale) {
      await (update(
        pendingActions,
      )..where((row) => row.operationId.equals(action.operationId))).write(
        PendingActionsCompanion(
          status: const Value(PendingActionStatus.pending),
          updatedAt: Value(updatedAt),
          lastError: const Value('Recovered stale synchronization'),
        ),
      );
    }
    return stale;
  }

  Future<PendingAction?> getActionByOperationId(String operationId) =>
      (select(pendingActions)
            ..where((action) => action.operationId.equals(operationId)))
          .getSingleOrNull();

  Future<void> markSyncing(String operationId, DateTime updatedAt) =>
      _updateStatus(
        operationId,
        PendingActionStatus.syncing,
        updatedAt: updatedAt,
      );

  Future<void> markSynced(String operationId, DateTime updatedAt) =>
      _updateStatus(
        operationId,
        PendingActionStatus.synced,
        updatedAt: updatedAt,
        clearError: true,
      );

  Future<void> markFailed(
    String operationId, {
    required String error,
    required DateTime updatedAt,
  }) async {
    final current = await getActionByOperationId(operationId);
    if (current == null) return;
    await (update(
      pendingActions,
    )..where((action) => action.operationId.equals(operationId))).write(
      PendingActionsCompanion(
        status: const Value(PendingActionStatus.failed),
        retryCount: Value(current.retryCount + 1),
        lastError: Value(error),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  Future<void> markBlocked(
    String operationId, {
    required String error,
    required DateTime updatedAt,
  }) async {
    final current = await getActionByOperationId(operationId);
    if (current == null) return;
    await (update(
      pendingActions,
    )..where((action) => action.operationId.equals(operationId))).write(
      PendingActionsCompanion(
        status: const Value(PendingActionStatus.blocked),
        retryCount: Value(current.retryCount + 1),
        lastError: Value(error),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  Future<int> deleteCompletedAction(String operationId) =>
      (delete(pendingActions)..where(
            (action) =>
                action.operationId.equals(operationId) &
                action.status.equals(PendingActionStatus.synced.name),
          ))
          .go();

  Stream<List<PendingAction>> watchPendingActions() =>
      (select(pendingActions)
            ..where(
              (action) =>
                  action.status.equals(PendingActionStatus.pending.name),
            )
            ..orderBy([(action) => OrderingTerm.asc(action.createdAt)]))
          .watch();

  Future<void> _updateStatus(
    String operationId,
    PendingActionStatus status, {
    required DateTime updatedAt,
    bool clearError = false,
  }) {
    return (update(
      pendingActions,
    )..where((action) => action.operationId.equals(operationId))).write(
      PendingActionsCompanion(
        status: Value(status),
        updatedAt: Value(updatedAt),
        lastError: clearError ? const Value(null) : const Value.absent(),
      ),
    );
  }
}
