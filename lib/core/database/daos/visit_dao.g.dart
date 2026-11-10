// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'visit_dao.dart';

// ignore_for_file: type=lint
mixin _$VisitDaoMixin on DatabaseAccessor<AppDatabase> {
  $LocalVisitsTable get localVisits => attachedDatabase.localVisits;
  VisitDaoManager get managers => VisitDaoManager(this);
}

class VisitDaoManager {
  final _$VisitDaoMixin _db;
  VisitDaoManager(this._db);
  $$LocalVisitsTableTableManager get localVisits =>
      $$LocalVisitsTableTableManager(_db.attachedDatabase, _db.localVisits);
}
