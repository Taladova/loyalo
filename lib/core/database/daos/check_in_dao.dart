import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/local_check_ins.dart';

part 'check_in_dao.g.dart';

@DriftAccessor(tables: [LocalCheckIns])
class CheckInDao extends DatabaseAccessor<AppDatabase> with _$CheckInDaoMixin {
  CheckInDao(super.attachedDatabase);

  Future<int> upsertCheckIn(LocalCheckInsCompanion value) =>
      into(localCheckIns).insertOnConflictUpdate(value);

  Future<LocalCheckIn?> getCheckInById(String id) => (select(
    localCheckIns,
  )..where((row) => row.checkInId.equals(id))).getSingleOrNull();

  Future<List<LocalCheckIn>> getCheckInsForMerchant(
    String merchantId,
    String ownerUid,
  ) =>
      (select(localCheckIns)
            ..where(
              (row) =>
                  row.merchantId.equals(merchantId) &
                  row.ownerUid.equals(ownerUid),
            )
            ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]))
          .get();

  Stream<List<LocalCheckIn>> watchPendingCheckInsForMerchant(
    String merchantId,
    String ownerUid,
  ) =>
      (select(localCheckIns)
            ..where(
              (row) =>
                  row.merchantId.equals(merchantId) &
                  row.ownerUid.equals(ownerUid) &
                  row.businessStatus.equals(
                    LocalCheckInBusinessStatus.pending.name,
                  ),
            )
            ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]))
          .watch();

  Stream<List<LocalCheckIn>> watchMerchantValidationQueue(
    String merchantId,
    String ownerUid,
  ) =>
      (select(localCheckIns)
            ..where(
              (row) =>
                  row.merchantId.equals(merchantId) &
                  row.ownerUid.equals(ownerUid) &
                  (row.businessStatus.equals(
                        LocalCheckInBusinessStatus.pending.name,
                      ) |
                      row.syncStatus.equals(
                        LocalCheckInSyncStatus.pending.name,
                      ) |
                      row.syncStatus.equals(
                        LocalCheckInSyncStatus.syncing.name,
                      ) |
                      row.syncStatus.equals(
                        LocalCheckInSyncStatus.failed.name,
                      )),
            )
            ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)]))
          .watch();

  Future<void> updateBusinessStatus(
    String id,
    LocalCheckInBusinessStatus status,
    DateTime updatedAt, {
    String? visitId,
  }) => (update(localCheckIns)..where((row) => row.checkInId.equals(id))).write(
    LocalCheckInsCompanion(
      businessStatus: Value(status),
      updatedAt: Value(updatedAt),
      visitId: visitId == null ? const Value.absent() : Value(visitId),
    ),
  );

  Future<void> updateSyncStatus(
    String id,
    LocalCheckInSyncStatus status,
    DateTime updatedAt,
  ) => (update(localCheckIns)..where((row) => row.checkInId.equals(id))).write(
    LocalCheckInsCompanion(
      syncStatus: Value(status),
      updatedAt: Value(updatedAt),
    ),
  );
}
