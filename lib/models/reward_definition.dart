import 'package:cloud_firestore/cloud_firestore.dart';

class RewardDefinition {
  final String id;
  final String restaurantId;
  final String label;
  final int thresholdVisits;
  final int activeCount;
  final bool active;

  const RewardDefinition({
    required this.id,
    required this.restaurantId,
    required this.label,
    required this.thresholdVisits,
    required this.activeCount,
    required this.active,
  });

  RewardDefinition copyWith({bool? active}) {
    return RewardDefinition(
      id: id,
      restaurantId: restaurantId,
      label: label,
      thresholdVisits: thresholdVisits,
      activeCount: activeCount,
      active: active ?? this.active,
    );
  }

  factory RewardDefinition.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return RewardDefinition(
      id: doc.id,
      restaurantId: data['restaurantId'] as String? ?? '',
      label: data['label'] as String? ?? '',
      thresholdVisits: data['thresholdVisits'] as int? ?? 10,
      activeCount: data['activeCount'] as int? ?? 0,
      active: data['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'restaurantId': restaurantId,
      'label': label,
      'thresholdVisits': thresholdVisits,
      'activeCount': activeCount,
      'active': active,
    };
  }
}
