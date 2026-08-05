enum ReferralStatus { pending, joined }

class ReferredFriend {
  final String name;
  final ReferralStatus status;
  final int pointsEarned;
  final DateTime invitedAt;

  const ReferredFriend({
    required this.name,
    required this.status,
    required this.pointsEarned,
    required this.invitedAt,
  });
}
