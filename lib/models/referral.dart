import 'package:cloud_firestore/cloud_firestore.dart';

enum ReferralStatus { pending, joined }

/// Filleul réel : créé automatiquement quand un nouveau client s'inscrit
/// avec le code parrain d'un client existant (voir
/// `LoyaltyRepository.redeemReferralCode`). Le statut est "joined" dès
/// l'inscription — pas d'étape "pending" en pratique, le compte étant créé
/// immédiatement.
class ReferredFriend {
  final String id;
  final String referrerId;
  final String referredUserId;
  final String name;
  final ReferralStatus status;
  final int pointsEarned;
  final DateTime invitedAt;

  const ReferredFriend({
    required this.id,
    required this.referrerId,
    required this.referredUserId,
    required this.name,
    required this.status,
    required this.pointsEarned,
    required this.invitedAt,
  });

  factory ReferredFriend.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final invited = data['invitedAt'];
    return ReferredFriend(
      id: doc.id,
      referrerId: data['referrerId'] as String? ?? '',
      referredUserId: data['referredUserId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      status: (data['status'] as String? ?? 'joined') == 'pending' ? ReferralStatus.pending : ReferralStatus.joined,
      pointsEarned: (data['pointsEarned'] as num?)?.toInt() ?? 0,
      invitedAt: invited is Timestamp ? invited.toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'referrerId': referrerId,
      'referredUserId': referredUserId,
      'name': name,
      'status': status == ReferralStatus.pending ? 'pending' : 'joined',
      'pointsEarned': pointsEarned,
      'invitedAt': FieldValue.serverTimestamp(),
    };
  }
}
