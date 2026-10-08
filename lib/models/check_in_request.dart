import 'package:cloud_firestore/cloud_firestore.dart';

enum CheckInStatus { pending, approved, rejected, expired, cancelled }

extension CheckInStatusX on CheckInStatus {
  String get firestoreValue {
    switch (this) {
      case CheckInStatus.pending:
        return 'pending';
      case CheckInStatus.approved:
        return 'approved';
      case CheckInStatus.rejected:
        return 'rejected';
      case CheckInStatus.expired:
        return 'expired';
      case CheckInStatus.cancelled:
        return 'cancelled';
    }
  }

  static CheckInStatus fromFirestore(String? value) {
    switch (value) {
      case 'approved':
        return CheckInStatus.approved;
      case 'rejected':
        return CheckInStatus.rejected;
      case 'expired':
        return CheckInStatus.expired;
      case 'cancelled':
        return CheckInStatus.cancelled;
      case 'pending':
      default:
        return CheckInStatus.pending;
    }
  }
}

class CheckInRequest {
  final String id;
  final String customerId;
  final String restaurantId;
  final DateTime requestedAt;
  final DateTime expiresAt;
  final CheckInStatus status;
  final double? customerLatitude;
  final double? customerLongitude;
  final double? distanceMeters;
  final DateTime? validatedAt;
  final String? validatedBy;
  final DateTime? rejectedAt;
  final String? rejectedBy;
  final DateTime? cancelledAt;
  final int? pointsAwarded;
  final String? visitId;

  const CheckInRequest({
    required this.id,
    required this.customerId,
    required this.restaurantId,
    required this.requestedAt,
    required this.expiresAt,
    required this.status,
    this.customerLatitude,
    this.customerLongitude,
    this.distanceMeters,
    this.validatedAt,
    this.validatedBy,
    this.rejectedAt,
    this.rejectedBy,
    this.cancelledAt,
    this.pointsAwarded,
    this.visitId,
  });

  bool get isPending => status == CheckInStatus.pending;

  bool isExpired(DateTime now) => !expiresAt.isAfter(now);

  factory CheckInRequest.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    final requestedAt = data['requestedAt'];
    final expiresAt = data['expiresAt'];
    final validatedAt = data['validatedAt'];
    final rejectedAt = data['rejectedAt'];
    final cancelledAt = data['cancelledAt'];
    return CheckInRequest(
      id: doc.id,
      customerId: data['customerId'] as String? ?? '',
      restaurantId: data['restaurantId'] as String? ?? '',
      requestedAt: requestedAt is Timestamp
          ? requestedAt.toDate()
          : DateTime.now(),
      expiresAt: expiresAt is Timestamp ? expiresAt.toDate() : DateTime.now(),
      status: CheckInStatusX.fromFirestore(data['status'] as String?),
      customerLatitude: (data['customerLatitude'] as num?)?.toDouble(),
      customerLongitude: (data['customerLongitude'] as num?)?.toDouble(),
      distanceMeters: (data['distanceMeters'] as num?)?.toDouble(),
      validatedAt: validatedAt is Timestamp ? validatedAt.toDate() : null,
      validatedBy: data['validatedBy'] as String?,
      rejectedAt: rejectedAt is Timestamp ? rejectedAt.toDate() : null,
      rejectedBy: data['rejectedBy'] as String?,
      cancelledAt: cancelledAt is Timestamp ? cancelledAt.toDate() : null,
      pointsAwarded: (data['pointsAwarded'] as num?)?.toInt(),
      visitId: data['visitId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'restaurantId': restaurantId,
      'requestedAt': Timestamp.fromDate(requestedAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'status': status.firestoreValue,
      if (customerLatitude != null) 'customerLatitude': customerLatitude,
      if (customerLongitude != null) 'customerLongitude': customerLongitude,
      if (distanceMeters != null) 'distanceMeters': distanceMeters,
      if (validatedAt != null) 'validatedAt': Timestamp.fromDate(validatedAt!),
      if (validatedBy != null) 'validatedBy': validatedBy,
      if (rejectedAt != null) 'rejectedAt': Timestamp.fromDate(rejectedAt!),
      if (rejectedBy != null) 'rejectedBy': rejectedBy,
      if (cancelledAt != null) 'cancelledAt': Timestamp.fromDate(cancelledAt!),
      if (pointsAwarded != null) 'pointsAwarded': pointsAwarded,
      if (visitId != null) 'visitId': visitId,
    };
  }
}
