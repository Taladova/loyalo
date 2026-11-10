import 'package:drift/drift.dart';

enum LocalCheckInBusinessStatus {
  pending,
  approved,
  rejected,
  expired,
  cancelled,
}

enum LocalCheckInSyncStatus { pending, syncing, synced, failed }

@TableIndex(
  name: 'idx_local_checkins_merchant_status_created',
  columns: {#merchantId, #businessStatus, #createdAt},
)
@TableIndex(
  name: 'idx_local_checkins_merchant_expires',
  columns: {#merchantId, #expiresAt},
)
@TableIndex(
  name: 'idx_local_checkins_owner_status',
  columns: {#ownerUid, #businessStatus},
)
class LocalCheckIns extends Table {
  TextColumn get checkInId => text()();
  TextColumn get ownerUid => text()();
  TextColumn get merchantId => text()();
  TextColumn get customerId => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get expiresAt => dateTime()();
  TextColumn get businessStatus => textEnum<LocalCheckInBusinessStatus>()();
  TextColumn get syncStatus => textEnum<LocalCheckInSyncStatus>().withDefault(
    const Constant('synced'),
  )();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get visitId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {checkInId};
}
