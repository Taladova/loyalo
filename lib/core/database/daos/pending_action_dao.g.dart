// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_action_dao.dart';

// ignore_for_file: type=lint
mixin _$PendingActionDaoMixin on DatabaseAccessor<AppDatabase> {
  $PendingActionsTable get pendingActions => attachedDatabase.pendingActions;
  PendingActionDaoManager get managers => PendingActionDaoManager(this);
}

class PendingActionDaoManager {
  final _$PendingActionDaoMixin _db;
  PendingActionDaoManager(this._db);
  $$PendingActionsTableTableManager get pendingActions =>
      $$PendingActionsTableTableManager(
        _db.attachedDatabase,
        _db.pendingActions,
      );
}
