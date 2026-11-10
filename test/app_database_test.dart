import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loyalo/core/database/app_database.dart';
import 'package:loyalo/core/database/pending_action_payload.dart';
import 'package:loyalo/core/database/tables/local_visits.dart';
import 'package:loyalo/core/database/tables/pending_actions.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  group('VisitDao', () {
    test('inserts and reads a visit', () async {
      await database.visitDao.insertVisit(_visit('visit-1'));

      final visit = await database.visitDao.getVisitById('visit-1');

      expect(visit, isNotNull);
      expect(visit!.merchantId, 'merchant-1');
      expect(visit.customerId, 'customer-1');
      expect(visit.syncStatus, LocalVisitSyncStatus.pending);
    });

    test('returns only visits for the requested customer', () async {
      await database.visitDao.insertVisit(_visit('visit-1'));
      await database.visitDao.insertVisit(
        _visit('visit-2', customerId: 'customer-2'),
      );

      final visits = await database.visitDao.getVisitsByCustomer('customer-1');

      expect(visits.map((visit) => visit.visitId), ['visit-1']);
    });

    test('returns only visits for the requested merchant', () async {
      await database.visitDao.insertVisit(_visit('visit-1'));
      await database.visitDao.insertVisit(
        _visit('visit-2', merchantId: 'merchant-2'),
      );

      final visits = await database.visitDao.getVisitsByMerchant('merchant-2');

      expect(visits.map((visit) => visit.visitId), ['visit-2']);
    });

    test('returns the latest customer visit', () async {
      await database.visitDao.insertVisit(
        _visit('visit-old', visitedAt: DateTime.utc(2026, 1, 1)),
      );
      await database.visitDao.insertVisit(
        _visit('visit-new', visitedAt: DateTime.utc(2026, 1, 2)),
      );

      final visit = await database.visitDao.getLatestVisit(
        customerId: 'customer-1',
      );

      expect(visit?.visitId, 'visit-new');
    });

    test('rejects a duplicate visit id and preserves the first row', () async {
      await database.visitDao.insertVisit(_visit('visit-1'));

      await expectLater(
        database.visitDao.insertVisit(
          _visit('visit-1', merchantId: 'merchant-2'),
        ),
        throwsA(anything),
      );

      final visit = await database.visitDao.getVisitById('visit-1');
      expect(visit?.merchantId, 'merchant-1');
    });
  });

  group('PendingActionDao', () {
    test('inserts an action and preserves its JSON payload', () async {
      await database.pendingActionDao.insertPendingAction(_action('op-1'));

      final action = await database.pendingActionDao.getActionByOperationId(
        'op-1',
      );

      expect(action, isNotNull);
      expect(action!.status, PendingActionStatus.pending);
      expect(PendingActionPayload.decode(action.payload), {
        'visitId': 'visit-1',
      });
    });

    test('rejects a duplicate operation id', () async {
      await database.pendingActionDao.insertPendingAction(_action('op-1'));

      await expectLater(
        database.pendingActionDao.insertPendingAction(_action('op-1')),
        throwsA(anything),
      );
    });

    test('marks an action failed and increments its retry count', () async {
      await database.pendingActionDao.insertPendingAction(_action('op-1'));

      await database.pendingActionDao.markFailed(
        'op-1',
        error: 'network unavailable',
        updatedAt: DateTime.utc(2026, 1, 2),
      );

      final action = await database.pendingActionDao.getActionByOperationId(
        'op-1',
      );
      expect(action?.status, PendingActionStatus.failed);
      expect(action?.retryCount, 1);
      expect(action?.lastError, 'network unavailable');
    });

    test('marks an action synced and clears its previous error', () async {
      await database.pendingActionDao.insertPendingAction(_action('op-1'));
      await database.pendingActionDao.markFailed(
        'op-1',
        error: 'temporary error',
        updatedAt: DateTime.utc(2026, 1, 2),
      );

      await database.pendingActionDao.markSynced(
        'op-1',
        DateTime.utc(2026, 1, 3),
      );

      final action = await database.pendingActionDao.getActionByOperationId(
        'op-1',
      );
      expect(action?.status, PendingActionStatus.synced);
      expect(action?.lastError, isNull);
    });

    test('returns pending actions in chronological order', () async {
      await database.pendingActionDao.insertPendingAction(
        _action('op-later', createdAt: DateTime.utc(2026, 1, 2)),
      );
      await database.pendingActionDao.insertPendingAction(
        _action('op-first', createdAt: DateTime.utc(2026, 1, 1)),
      );

      final actions = await database.pendingActionDao.getPendingActions();

      expect(actions.map((action) => action.operationId), [
        'op-first',
        'op-later',
      ]);
    });
  });

  group('AppDatabase transaction', () {
    test('inserts a visit and its pending action atomically', () async {
      await database.insertVisitWithPendingAction(
        visit: _visit('visit-1'),
        action: _action('op-1'),
      );

      expect(await database.visitDao.visitExists('visit-1'), isTrue);
      expect(
        await database.pendingActionDao.getActionByOperationId('op-1'),
        isNotNull,
      );
    });

    test('rolls back the visit when pending action insertion fails', () async {
      await database.pendingActionDao.insertPendingAction(_action('op-1'));

      await expectLater(
        database.insertVisitWithPendingAction(
          visit: _visit('visit-rollback'),
          action: _action('op-1'),
        ),
        throwsA(anything),
      );

      expect(await database.visitDao.visitExists('visit-rollback'), isFalse);
    });
  });
}

LocalVisitsCompanion _visit(
  String visitId, {
  String merchantId = 'merchant-1',
  String customerId = 'customer-1',
  DateTime? visitedAt,
}) {
  final timestamp = visitedAt ?? DateTime.utc(2026, 1, 1, 12);
  return LocalVisitsCompanion.insert(
    visitId: visitId,
    merchantId: merchantId,
    customerId: customerId,
    visitedAt: timestamp,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

PendingActionsCompanion _action(String operationId, {DateTime? createdAt}) {
  final timestamp = createdAt ?? DateTime.utc(2026, 1, 1, 12);
  return PendingActionsCompanion.insert(
    operationId: operationId,
    actionType: PendingActionType.createVisit,
    entityType: 'visit',
    entityId: 'visit-1',
    payload: PendingActionPayload.encode({'visitId': 'visit-1'}),
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}
