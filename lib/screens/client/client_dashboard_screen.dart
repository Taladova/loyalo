import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/reward.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/reward_card.dart';
import '../../widgets/reward_unlocked_dialog.dart';
import '../../widgets/section_header.dart';
import 'rewards_screen.dart';

class ClientDashboardScreen extends ConsumerStatefulWidget {
  const ClientDashboardScreen({super.key});

  @override
  ConsumerState<ClientDashboardScreen> createState() => _ClientDashboardScreenState();
}

class _ClientDashboardScreenState extends ConsumerState<ClientDashboardScreen> {
  Set<String>? _knownRewardIds;

  void _checkForNewRewards(List<RewardItem> availableRewards) {
    final ids = availableRewards.map((r) => r.id).toSet();
    final known = _knownRewardIds;
    if (known == null) {
      // Premier chargement : on mémorise l'état actuel sans rien célébrer,
      // sinon toutes les récompenses déjà là s'afficheraient d'un coup.
      _knownRewardIds = ids;
      return;
    }
    final newIds = ids.difference(known);
    _knownRewardIds = ids;
    if (newIds.isEmpty) return;
    final newest = availableRewards.firstWhere((r) => r.id == newIds.first);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showRewardUnlockedDialog(context, rewardLabel: newest.label, restaurantName: newest.restaurantName);
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(loyaltyRepositoryProvider);
    final user = ref.watch(currentUserProvider)!;
    final points = repo.totalPoints(user.id);

    final restaurants = repo.restaurants;
    var closest = restaurants.first;
    var bestRatio = -1.0;
    for (final r in restaurants) {
      final count = repo.passageCount(user.id, r.id);
      final ratio = (count % r.rewardThreshold) / r.rewardThreshold;
      if (ratio > bestRatio) {
        bestRatio = ratio;
        closest = r;
      }
    }
    final currentCount = repo.passageCount(user.id, closest.id) % closest.rewardThreshold;
    final remaining = closest.rewardThreshold - currentCount;

    final rewards = repo.rewardsForUser(user.id).where((r) => r.status == RewardStatus.available).toList();
    _checkForNewRewards(rewards);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Bonjour 👋', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            const SizedBox(height: 2),
            const Text('Bienvenue chez Loyalo', style: TextStyle(color: AppColors.textGray)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Mes points', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.card_giftcard, color: Colors.white, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('$points', style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700)),
                  const Text('Points disponibles', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 18),
                  Text('Prochain palier — ${closest.name}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('$currentCount visites sur ${closest.rewardThreshold}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  Text(
                    remaining == closest.rewardThreshold
                        ? 'Validez votre 1ère visite pour commencer !'
                        : 'Encore $remaining visites pour gagner "${closest.rewardLabel}"',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: currentCount / closest.rewardThreshold,
                      minHeight: 7,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SectionHeader(
              title: 'Mes récompenses',
              onSeeAll: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RewardsScreen()),
              ),
            ),
            const SizedBox(height: 12),
            if (rewards.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Text(
                  'Validez des visites pour débloquer vos premières récompenses.',
                  style: TextStyle(color: AppColors.textGray, fontSize: 13),
                ),
              )
            else
              ...rewards.take(2).map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: RewardCard(reward: r),
                  )),
          ],
        ),
      ),
    );
  }
}
