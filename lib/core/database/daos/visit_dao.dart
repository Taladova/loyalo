import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/local_visits.dart';

part 'visit_dao.g.dart';

@DriftAccessor(tables: [LocalVisits])
class VisitDao extends DatabaseAccessor<AppDatabase> with _$VisitDaoMixin {
  VisitDao(super.attachedDatabase);

  Future<int> insertVisit(LocalVisitsCompanion visit) =>
      into(localVisits).insert(visit);

  Future<int> upsertVisit(LocalVisitsCompanion visit) =>
      into(localVisits).insertOnConflictUpdate(visit);

  Future<LocalVisit?> getVisitById(String visitId) => (select(
    localVisits,
  )..where((visit) => visit.visitId.equals(visitId))).getSingleOrNull();

  Future<List<LocalVisit>> getVisitsByCustomer(String customerId) =>
      (select(localVisits)
            ..where((visit) => visit.customerId.equals(customerId))
            ..orderBy([(visit) => OrderingTerm.desc(visit.visitedAt)]))
          .get();

  Future<List<LocalVisit>> getVisitsByMerchant(String merchantId) =>
      (select(localVisits)
            ..where((visit) => visit.merchantId.equals(merchantId))
            ..orderBy([(visit) => OrderingTerm.desc(visit.visitedAt)]))
          .get();

  Future<List<LocalVisit>> getAllVisits() => (select(
    localVisits,
  )..orderBy([(visit) => OrderingTerm.desc(visit.visitedAt)])).get();

  Future<LocalVisit?> getLatestVisit({
    required String customerId,
    String? merchantId,
  }) {
    final query = select(localVisits)
      ..where((visit) => visit.customerId.equals(customerId));
    if (merchantId != null) {
      query.where((visit) => visit.merchantId.equals(merchantId));
    }
    query
      ..orderBy([(visit) => OrderingTerm.desc(visit.visitedAt)])
      ..limit(1);
    return query.getSingleOrNull();
  }

  Future<bool> visitExists(String visitId) async =>
      await getVisitById(visitId) != null;

  Future<int> deleteVisit(String visitId) => (delete(
    localVisits,
  )..where((visit) => visit.visitId.equals(visitId))).go();

  Future<void> markSyncStatus(
    String visitId,
    LocalVisitSyncStatus status,
    DateTime updatedAt,
  ) => (update(localVisits)..where((visit) => visit.visitId.equals(visitId)))
      .write(
        LocalVisitsCompanion(
          syncStatus: Value(status),
          updatedAt: Value(updatedAt),
        ),
      );

  Stream<List<LocalVisit>> watchVisitsByCustomer(String customerId) =>
      (select(localVisits)
            ..where((visit) => visit.customerId.equals(customerId))
            ..orderBy([(visit) => OrderingTerm.desc(visit.visitedAt)]))
          .watch();

  Stream<List<LocalVisit>> watchVisitsByMerchant(String merchantId) =>
      (select(localVisits)
            ..where((visit) => visit.merchantId.equals(merchantId))
            ..orderBy([(visit) => OrderingTerm.desc(visit.visitedAt)]))
          .watch();

  Stream<List<LocalVisit>> watchAllVisits() => (select(
    localVisits,
  )..orderBy([(visit) => OrderingTerm.desc(visit.visitedAt)])).watch();
}
