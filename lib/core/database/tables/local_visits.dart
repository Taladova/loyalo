import 'package:drift/drift.dart';

enum LocalVisitSyncStatus { pending, syncing, synced, failed }

@TableIndex(
  name: 'idx_local_visits_merchant_visited_at',
  columns: {#merchantId, #visitedAt},
)
@TableIndex(
  name: 'idx_local_visits_customer_visited_at',
  columns: {#customerId, #visitedAt},
)
@TableIndex(name: 'idx_local_visits_sync_status', columns: {#syncStatus})
class LocalVisits extends Table {
  TextColumn get visitId => text()();
  TextColumn get merchantId => text()();
  TextColumn get customerId => text()();
  DateTimeColumn get visitedAt => dateTime()();
  TextColumn get syncStatus =>
      textEnum<LocalVisitSyncStatus>().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {visitId};
}
