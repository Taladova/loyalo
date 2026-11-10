import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/local_visits.dart';
import '../../../models/visit.dart';

abstract final class VisitMapper {
  static Visit fromLocal(LocalVisit visit) => Visit(
    id: visit.visitId,
    userId: visit.customerId,
    restaurantId: visit.merchantId,
    timestamp: visit.visitedAt,
  );

  static LocalVisitsCompanion toLocal(
    Visit visit, {
    required LocalVisitSyncStatus syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final now = updatedAt ?? DateTime.now();
    return LocalVisitsCompanion.insert(
      visitId: visit.id,
      merchantId: visit.restaurantId,
      customerId: visit.userId,
      visitedAt: visit.timestamp,
      syncStatus: Value(syncStatus),
      createdAt: createdAt ?? now,
      updatedAt: now,
    );
  }

  static Map<String, Object?> toPendingPayload(Visit visit) => {
    'visitId': visit.id,
    'customerId': visit.userId,
    'merchantId': visit.restaurantId,
    'visitedAt': visit.timestamp.toUtc().toIso8601String(),
  };

  static Visit fromPendingPayload(Map<String, Object?> payload) => Visit(
    id: payload['visitId']! as String,
    userId: payload['customerId']! as String,
    restaurantId: payload['merchantId']! as String,
    timestamp: DateTime.parse(payload['visitedAt']! as String).toLocal(),
  );
}
