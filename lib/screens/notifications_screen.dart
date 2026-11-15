import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/loyalo_notification.dart';
import '../providers/app_providers.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/loyalo_auth_ui.dart';
import '../widgets/loyalo_secondary_scaffold.dart';
import '../widgets/loyalo_ui.dart';
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
    return LoyaloSecondaryScaffold(
      title: 'Notifications',
      body: items.isEmpty
          ? const _EmptyNotifications()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final notification = items[index];
                final showDate =
                    index == 0 ||
                    !DateUtils.isSameDay(
                      items[index - 1].createdAt.toLocal(),
                      notification.createdAt.toLocal(),
                    );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showDate)
                        Padding(
                          padding: EdgeInsets.only(
                            top: index == 0 ? 0 : 12,
                            bottom: 12,
                            left: 4,
                          ),
                          child: Semantics(
                            header: true,
                            child: Text(
                              DateFormat(
                                'dd/MM/yyyy',
                              ).format(notification.createdAt.toLocal()),
                              style: const TextStyle(
                                color: LoyaloAuthColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      _NotificationCard(
                        key: ValueKey('notification-${notification.id}'),
                        notification: notification,
                        icon: _iconFor(notification.type),
                        color: _colorFor(notification.type),
                        onTap: () async {
                          await repo.markNotificationRead(
                            notificationId: notification.id,
                            userId: uid,
                          );
                          if (!context.mounted) return;
                          _openTarget(context, notification);
                        },
                      ),
                    ],
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

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: LoyaloCard(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ExcludeSemantics(
                    child: LoyaloIconBadge(
                      icon: Icons.notifications_none_rounded,
                      color: LoyaloAuthColors.purple,
                      size: 52,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Semantics(
                    header: true,
                    child: const Text(
                      'Aucune notification',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: LoyaloAuthColors.textPrimary,
                        fontSize: 20,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Vous n’avez aucune notification pour le moment.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: LoyaloAuthColors.textSecondary,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    super.key,
    required this.notification,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final LoyaloNotification notification;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: LoyaloCard(
      color: Colors.white,
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: LoyaloIconBadge(icon: icon, color: color, size: 42),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              color: LoyaloAuthColors.textPrimary,
                              fontSize: 15,
                              height: 1.4,
                              fontWeight: notification.isRead
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                            ),
                          ),
                        ),
                        if (!notification.isRead) ...[
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Semantics(
                              key: ValueKey(
                                'notification-unread-${notification.id}',
                              ),
                              label: 'Non lue',
                              child: const DecoratedBox(
                                decoration: BoxDecoration(
                                  color: LoyaloAuthColors.purple,
                                  shape: BoxShape.circle,
                                ),
                                child: SizedBox(width: 8, height: 8),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.body,
                      style: const TextStyle(
                        color: LoyaloAuthColors.textSecondary,
                        fontSize: 14,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      DateFormat(
                        'dd/MM/yyyy à HH:mm',
                      ).format(notification.createdAt),
                      style: const TextStyle(
                        color: LoyaloAuthColors.textSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
