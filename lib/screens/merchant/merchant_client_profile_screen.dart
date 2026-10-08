import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/reward.dart';
import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';
import '../../services/analytics_service.dart';
import '../../services/loyalty_repository.dart';
import '../../theme/app_theme.dart';

class MerchantClientProfileScreen extends ConsumerWidget {
  final String clientId;

  const MerchantClientProfileScreen({super.key, required this.clientId});

  Future<void> _redeemReward(
    BuildContext context,
    WidgetRef ref,
    RewardItem reward,
  ) async {
    final redeemed = await ref
        .read(loyaltyRepositoryProvider)
        .redeemReward(
          rewardId: reward.id,
          merchantId: AuthService().currentUser!.uid,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          redeemed
              ? 'Récompense utilisée.'
              : 'Impossible d’utiliser cette récompense.',
        ),
      ),
    );
  }

  Future<void> _validate(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(loyaltyRepositoryProvider);
    final restaurantId = ref.read(currentMerchantRestaurantIdProvider)!;
    final result = await repo.registerVisit(
      userId: clientId,
      restaurantId: restaurantId,
    );
    if (!context.mounted) return;

    String title;
    Color color;
    String message;
    switch (result.outcome) {
      case VisitOutcome.alreadyValidatedToday:
        title = 'Déjà validé';
        color = AppColors.orange;
        message =
            'Ce client a déjà été validé aujourd\'hui pour ce restaurant.';
        break;
      case VisitOutcome.rewardUnlocked:
        AnalyticsService.logVisitRegistered(restaurantId: result.restaurant.id);
        AnalyticsService.logRewardUnlocked(
          restaurantId: result.restaurant.id,
          rewardLabel: result.restaurant.rewardLabel,
        );
        title = 'Récompense débloquée !';
        color = AppColors.success;
        message =
            '${result.passageCount}/${result.restaurant.rewardThreshold} passages — '
            '${result.restaurant.rewardLabel}.';
        break;
      case VisitOutcome.validated:
        AnalyticsService.logVisitRegistered(restaurantId: result.restaurant.id);
        title = 'Visite validée';
        color = AppColors.teal;
        message =
            '${result.passageCount}/${result.restaurant.rewardThreshold} passages.';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(loyaltyRepositoryProvider);
    final client = repo.clientById(clientId);
    final restaurantId = ref.watch(currentMerchantRestaurantIdProvider)!;
    final restaurant = repo.restaurantById(restaurantId);
    final progress = repo.loyaltyProgressFor(
      userId: clientId,
      restaurant: restaurant,
    );
    final availableRewards = repo
        .rewardsForUser(clientId)
        .where(
          (reward) =>
              reward.restaurantId == restaurantId &&
              reward.status == RewardStatus.available,
        )
        .toList();
    final visits = repo
        .visitsForUser(clientId)
        .where((v) => v.restaurantId == restaurantId)
        .toList();

    if (client == null) {
      return const Scaffold(body: Center(child: Text('Client introuvable')));
    }

    return Scaffold(
      appBar: AppBar(title: Text(client.name)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Informations',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                _InfoRow(icon: Icons.email_outlined, text: client.email),
                _InfoRow(icon: Icons.phone_outlined, text: client.phone),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Fidélité',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${progress.current}/${progress.threshold}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.purple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress.ratio,
                    minHeight: 8,
                    backgroundColor: AppColors.cloud,
                    color: AppColors.teal,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  progress.enabled
                      ? 'Encore ${progress.remaining} ${progress.unitLabel} pour gagner ${progress.rewardLabel}'
                      : 'Programme désactivé pour ce commerce',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textGray,
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: () => _validate(context, ref),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Valider la visite'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Récompenses disponibles',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          if (availableRewards.isEmpty)
            const Text(
              'Aucune récompense disponible.',
              style: TextStyle(color: AppColors.textGray),
            )
          else
            ...availableRewards.map(
              (reward) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceOf(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.borderOf(context)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.card_giftcard, color: AppColors.orange),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        reward.label,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _redeemReward(context, ref, reward),
                      child: const Text('Utiliser'),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),
          const Text(
            'Historique des visites',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          if (visits.isEmpty)
            const Text(
              'Aucune visite enregistrée.',
              style: TextStyle(color: AppColors.textGray),
            )
          else
            ...visits.map(
              (v) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: AppColors.success,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('dd/MM/yyyy à HH:mm').format(v.timestamp),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textGray),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
