import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/local_check_ins.dart';
import '../../../models/check_in_request.dart';

abstract final class CheckInMapper {
  static CheckInRequest fromLocal(LocalCheckIn row) {
    final status = CheckInStatusX.fromFirestore(row.businessStatus.name);
    return CheckInRequest(
      id: row.checkInId,
      customerId: row.customerId,
      restaurantId: row.merchantId,
      requestedAt: row.createdAt.toLocal(),
      expiresAt: row.expiresAt.toLocal(),
      status: status,
      validatedAt: status == CheckInStatus.approved
          ? row.updatedAt.toLocal()
          : null,
      validatedBy: status == CheckInStatus.approved ? row.ownerUid : null,
      rejectedAt: status == CheckInStatus.rejected
          ? row.updatedAt.toLocal()
          : null,
      rejectedBy: status == CheckInStatus.rejected ? row.ownerUid : null,
      visitId: row.visitId,
    );
  }

  static LocalCheckInsCompanion toLocal(
    CheckInRequest request, {
    required String ownerUid,
    required LocalCheckInSyncStatus syncStatus,
    DateTime? updatedAt,
  }) => LocalCheckInsCompanion.insert(
    checkInId: request.id,
    ownerUid: ownerUid,
    merchantId: request.restaurantId,
    customerId: request.customerId,
    createdAt: request.requestedAt.toUtc(),
    expiresAt: request.expiresAt.toUtc(),
    businessStatus: LocalCheckInBusinessStatus.values.byName(
      request.status.firestoreValue,
    ),
    syncStatus: Value(syncStatus),
    updatedAt: (updatedAt ?? DateTime.now()).toUtc(),
    visitId: Value(request.visitId),
  );
}
