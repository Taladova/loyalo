import 'package:cloud_firestore/cloud_firestore.dart';

enum ReferralStatus { pending, completed, rewarded, cancelled }

extension ReferralStatusX on ReferralStatus {
  String get firestoreValue {
    switch (this) {
      case ReferralStatus.pending:
        return 'pending';
      case ReferralStatus.completed:
        return 'completed';
      case ReferralStatus.rewarded:
        return 'rewarded';
      case ReferralStatus.cancelled:
        return 'cancelled';
    }
  }

  static ReferralStatus fromFirestore(String? value) {
    switch (value) {
      case 'completed':
        return ReferralStatus.completed;
      case 'rewarded':
      case 'joined':
        return ReferralStatus.rewarded;
      case 'cancelled':
        return ReferralStatus.cancelled;
      case 'pending':
      default:
        return ReferralStatus.pending;
    }
  }
}

/// Filleul réel : créé quand un nouveau client renseigne le code d'un parrain.
/// Il reste en attente jusqu'à une première visite validée dans un commerce.
class ReferredFriend {
  final String id;
  final String referrerId;
  final String referredUserId;
  final String? restaurantId;
  final String name;
  final ReferralStatus status;
  final int pointsEarned;
  final DateTime invitedAt;
  final DateTime? completedAt;
  final DateTime? rewardedAt;

  const ReferredFriend({
    required this.id,
    required this.referrerId,
    required this.referredUserId,
    this.restaurantId,
    required this.name,
    required this.status,
    required this.pointsEarned,
    required this.invitedAt,
    this.completedAt,
    this.rewardedAt,
  });

  factory ReferredFriend.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    final invited = data['invitedAt'];
    final completed = data['completedAt'];
    final rewarded = data['rewardedAt'];
    return ReferredFriend(
      id: doc.id,
      referrerId: data['referrerId'] as String? ?? '',
      referredUserId: data['referredUserId'] as String? ?? '',
      restaurantId: data['restaurantId'] as String?,
      name: data['name'] as String? ?? '',
      status: ReferralStatusX.fromFirestore(data['status'] as String?),
      pointsEarned: (data['pointsEarned'] as num?)?.toInt() ?? 0,
      invitedAt: invited is Timestamp ? invited.toDate() : DateTime.now(),
      completedAt: completed is Timestamp ? completed.toDate() : null,
      rewardedAt: rewarded is Timestamp ? rewarded.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'referrerId': referrerId,
      'referredUserId': referredUserId,
      if (restaurantId != null) 'restaurantId': restaurantId,
      'name': name,
      'status': status.firestoreValue,
      'pointsEarned': pointsEarned,
      'invitedAt': FieldValue.serverTimestamp(),
      if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
      if (rewardedAt != null) 'rewardedAt': Timestamp.fromDate(rewardedAt!),
    };
  }
}
