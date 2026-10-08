import 'package:cloud_firestore/cloud_firestore.dart';

enum LoyaloNotificationType {
  visitValidated,
  rewardUnlocked,
  referralRewarded,
  newOffer,
  checkInPending,
  unknown,
}

extension LoyaloNotificationTypeX on LoyaloNotificationType {
  String get firestoreValue {
    switch (this) {
      case LoyaloNotificationType.visitValidated:
        return 'visit_validated';
      case LoyaloNotificationType.rewardUnlocked:
        return 'reward_unlocked';
      case LoyaloNotificationType.referralRewarded:
        return 'referral_rewarded';
      case LoyaloNotificationType.newOffer:
        return 'new_offer';
      case LoyaloNotificationType.checkInPending:
        return 'check_in_requested';
      case LoyaloNotificationType.unknown:
        return 'unknown';
    }
  }

  static LoyaloNotificationType fromFirestore(String? value) {
    switch (value) {
      case 'visit_validated':
        return LoyaloNotificationType.visitValidated;
      case 'reward_unlocked':
        return LoyaloNotificationType.rewardUnlocked;
      case 'referral_rewarded':
        return LoyaloNotificationType.referralRewarded;
      case 'new_offer':
        return LoyaloNotificationType.newOffer;
      case 'check_in_requested':
        return LoyaloNotificationType.checkInPending;
      default:
        return LoyaloNotificationType.unknown;
    }
  }
}

class LoyaloNotification {
  final String id;
  final String userId;
  final String? recipientType;
  final String title;
  final String body;
  final LoyaloNotificationType type;
  final String? restaurantId;
  final String? relatedId;
  final DateTime createdAt;
  final bool isRead;
  final DateTime? readAt;

  const LoyaloNotification({
    required this.id,
    required this.userId,
    this.recipientType,
    required this.title,
    required this.body,
    required this.type,
    this.restaurantId,
    this.relatedId,
    required this.createdAt,
    required this.isRead,
    this.readAt,
  });

  factory LoyaloNotification.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    final created = data['createdAt'];
    final readAt = data['readAt'];
    return LoyaloNotification(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      recipientType: data['recipientType'] as String?,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      type: LoyaloNotificationTypeX.fromFirestore(data['type'] as String?),
      restaurantId: data['restaurantId'] as String?,
      relatedId: data['relatedId'] as String?,
      createdAt: created is Timestamp ? created.toDate() : DateTime.now(),
      isRead: data['isRead'] as bool? ?? data['read'] as bool? ?? false,
      readAt: readAt is Timestamp ? readAt.toDate() : null,
    );
  }
}
