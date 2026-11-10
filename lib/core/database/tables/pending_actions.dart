import 'package:drift/drift.dart';

enum PendingActionType { createVisit, approveCheckIn, rejectCheckIn }

enum PendingActionStatus { pending, syncing, synced, failed, blocked }

@TableIndex(
  name: 'idx_pending_actions_status_created_at',
  columns: {#status, #createdAt},
)
@TableIndex(
  name: 'idx_pending_actions_entity',
  columns: {#entityType, #entityId},
)
@TableIndex(
  name: 'idx_pending_actions_owner_status_created_at',
  columns: {#ownerScopeId, #status, #createdAt},
)
class PendingActions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get operationId => text().unique()();
  TextColumn get ownerScopeId => text().nullable()();
  TextColumn get actionType => textEnum<PendingActionType>()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get payload => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get status =>
      textEnum<PendingActionStatus>().withDefault(const Constant('pending'))();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
}
