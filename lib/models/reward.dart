import 'package:cloud_firestore/cloud_firestore.dart';

enum RewardStatus { available, used }

class RewardItem {
  final String id;
  final String userId;
  final String restaurantName;
  final String label;
  final DateTime expiresAt;
  final RewardStatus status;

  const RewardItem({
    required this.id,
    required this.userId,
    required this.restaurantName,
    required this.label,
    required this.expiresAt,
    required this.status,
  });

  RewardItem copyWith({RewardStatus? status}) {
    return RewardItem(
      id: id,
      userId: userId,
      restaurantName: restaurantName,
      label: label,
      expiresAt: expiresAt,
      status: status ?? this.status,
    );
  }

  factory RewardItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final exp = data['expiresAt'];
    return RewardItem(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      restaurantName: data['restaurantName'] as String? ?? '',
      label: data['label'] as String? ?? '',
      expiresAt: exp is Timestamp ? exp.toDate() : DateTime.now(),
      status: (data['status'] as String? ?? 'available') == 'used' ? RewardStatus.used : RewardStatus.available,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'restaurantName': restaurantName,
      'label': label,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'status': status == RewardStatus.used ? 'used' : 'available',
    };
  }
}
