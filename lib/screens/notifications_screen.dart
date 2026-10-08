import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/loyalo_notification.dart';
import '../providers/app_providers.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'client/client_visit_history_screen.dart';
import 'client/referral_screen.dart';
import 'client/rewards_screen.dart';
import 'merchant/validate_visit_screen.dart';

class NotificationsScreen extends ConsumerWidget {
  final bool merchant;
  final String? restaurantId;

  const NotificationsScreen({
    super.key,
    this.merchant = false,
    this.restaurantId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(loyaltyRepositoryProvider);
    final user = ref.watch(currentUserProvider);
    final uid = AuthService().currentUser?.uid ?? user?.id ?? '';
    final items = merchant && restaurantId != null
        ? repo.notificationsForMerchant(restaurantId!)
        : repo.notificationsForUser(uid);
    final text = AppTheme.textOf(context);
    final muted = AppTheme.mutedOf(context);
    final surface = AppTheme.surfaceOf(context);
    final border = AppTheme.borderOf(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Aucune notification pour le moment.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final notification = items[index];
                return InkWell(
                  onTap: () async {
                    await repo.markNotificationRead(
                      notificationId: notification.id,
                      userId: uid,
                    );
                    if (!context.mounted) return;
                    _openTarget(context, notification);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: notification.isRead
                            ? border
                            : AppColors.purple.withValues(alpha: 0.55),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: _colorFor(
                            notification.type,
                          ).withValues(alpha: 0.14),
                          child: Icon(
                            _iconFor(notification.type),
                            color: _colorFor(notification.type),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notification.title,
                                style: TextStyle(
                                  color: text,
                                  fontWeight: notification.isRead
                                      ? FontWeight.w600
                                      : FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                notification.body,
                                style: TextStyle(
                                  color: muted,
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                DateFormat(
                                  'dd/MM/yyyy à HH:mm',
                                ).format(notification.createdAt),
                                style: TextStyle(color: muted, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                              color: AppColors.purple,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _openTarget(BuildContext context, LoyaloNotification notification) {
    switch (notification.type) {
      case LoyaloNotificationType.rewardUnlocked:
      case LoyaloNotificationType.newOffer:
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const RewardsScreen()));
        break;
      case LoyaloNotificationType.referralRewarded:
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ReferralScreen()));
        break;
      case LoyaloNotificationType.visitValidated:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ClientVisitHistoryScreen()),
        );
        break;
      case LoyaloNotificationType.checkInPending:
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ValidateVisitScreen()));
        break;
      case LoyaloNotificationType.unknown:
        break;
    }
  }

  IconData _iconFor(LoyaloNotificationType type) {
    switch (type) {
      case LoyaloNotificationType.visitValidated:
        return Icons.check_circle_outline;
      case LoyaloNotificationType.rewardUnlocked:
        return Icons.card_giftcard;
      case LoyaloNotificationType.referralRewarded:
        return Icons.group_add_outlined;
      case LoyaloNotificationType.newOffer:
        return Icons.local_fire_department_outlined;
      case LoyaloNotificationType.checkInPending:
        return Icons.qr_code_scanner;
      case LoyaloNotificationType.unknown:
        return Icons.notifications_none;
    }
  }

  Color _colorFor(LoyaloNotificationType type) {
    switch (type) {
      case LoyaloNotificationType.visitValidated:
      case LoyaloNotificationType.checkInPending:
        return AppColors.teal;
      case LoyaloNotificationType.rewardUnlocked:
      case LoyaloNotificationType.newOffer:
        return AppColors.purple;
      case LoyaloNotificationType.referralRewarded:
        return AppColors.success;
      case LoyaloNotificationType.unknown:
        return AppColors.textGray;
    }
  }
}
