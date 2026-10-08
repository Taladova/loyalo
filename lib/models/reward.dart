import 'package:cloud_firestore/cloud_firestore.dart';

enum RewardStatus { available, used }

class RewardItem {
  final String id;
  final String userId;
  final String restaurantName;
  final String? restaurantId;
  final String label;
  final DateTime expiresAt;
  final RewardStatus status;
  final int? cycle;
  final DateTime? redeemedAt;
  final String? redeemedBy;

  const RewardItem({
    required this.id,
    required this.userId,
    required this.restaurantName,
    this.restaurantId,
    required this.label,
    required this.expiresAt,
    required this.status,
    this.cycle,
    this.redeemedAt,
    this.redeemedBy,
  });

  RewardItem copyWith({
    RewardStatus? status,
    DateTime? redeemedAt,
    String? redeemedBy,
  }) {
    return RewardItem(
      id: id,
      userId: userId,
      restaurantName: restaurantName,
      restaurantId: restaurantId,
      label: label,
      expiresAt: expiresAt,
      status: status ?? this.status,
      cycle: cycle,
      redeemedAt: redeemedAt ?? this.redeemedAt,
      redeemedBy: redeemedBy ?? this.redeemedBy,
    );
  }

  factory RewardItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final exp = data['expiresAt'];
    final redeemedAt = data['redeemedAt'];
    return RewardItem(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      restaurantName: data['restaurantName'] as String? ?? '',
      restaurantId: data['restaurantId'] as String?,
      label: data['label'] as String? ?? '',
      expiresAt: exp is Timestamp ? exp.toDate() : DateTime.now(),
      status: (data['status'] as String? ?? 'available') == 'used'
          ? RewardStatus.used
          : RewardStatus.available,
      cycle: (data['cycle'] as num?)?.toInt(),
      redeemedAt: redeemedAt is Timestamp ? redeemedAt.toDate() : null,
      redeemedBy: data['redeemedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'restaurantName': restaurantName,
      if (restaurantId != null) 'restaurantId': restaurantId,
      'label': label,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'status': status == RewardStatus.used ? 'used' : 'available',
      if (cycle != null) 'cycle': cycle,
      if (redeemedAt != null) 'redeemedAt': Timestamp.fromDate(redeemedAt!),
      if (redeemedBy != null) 'redeemedBy': redeemedBy,
    };
  }
}
