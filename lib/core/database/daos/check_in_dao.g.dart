// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'check_in_dao.dart';

// ignore_for_file: type=lint
mixin _$CheckInDaoMixin on DatabaseAccessor<AppDatabase> {
  $LocalCheckInsTable get localCheckIns => attachedDatabase.localCheckIns;
  CheckInDaoManager get managers => CheckInDaoManager(this);
}

class CheckInDaoManager {
  final _$CheckInDaoMixin _db;
  CheckInDaoManager(this._db);
  $$LocalCheckInsTableTableManager get localCheckIns =>
      $$LocalCheckInsTableTableManager(_db.attachedDatabase, _db.localCheckIns);
}
