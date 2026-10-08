import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/reward.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/exclusive_offer_card.dart';
import '../../widgets/reward_card.dart';

class RewardsScreen extends ConsumerStatefulWidget {
  const RewardsScreen({super.key});

  @override
  ConsumerState<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends ConsumerState<RewardsScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(loyaltyRepositoryProvider);
    final user = ref.watch(currentUserProvider)!;
    final all = repo.rewardsForUser(user.id);
    final allOffers = repo.currentExclusiveOffersForUser(user.id);
    final recentLimit = DateTime.now().subtract(const Duration(days: 7));
    final offers = switch (_tabIndex) {
      0 => allOffers,
      2 =>
        allOffers
            .where((offer) => !offer.startsAt.isBefore(recentLimit))
            .toList(),
      _ => [],
    };
    final shown = switch (_tabIndex) {
      0 =>
        all.where((reward) => reward.status == RewardStatus.available).toList(),
      1 => all.where((reward) => reward.status == RewardStatus.used).toList(),
      _ => <RewardItem>[],
    };
    final emptyMessage = switch (_tabIndex) {
      0 => 'Aucune offre ou récompense disponible pour le moment.',
      1 => 'Aucune offre utilisée pour le moment.',
      _ => 'Aucune nouveauté cette semaine.',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offres exclusives'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(Icons.search, size: 22),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                _Tab(
                  label: 'Toutes',
                  selected: _tabIndex == 0,
                  onTap: () => setState(() => _tabIndex = 0),
                ),
                const SizedBox(width: 10),
                _Tab(
                  label: 'Utilisées',
                  selected: _tabIndex == 1,
                  onTap: () => setState(() => _tabIndex = 1),
                ),
                const SizedBox(width: 10),
                _Tab(
                  label: 'Nouveautés',
                  selected: _tabIndex == 2,
                  onTap: () => setState(() => _tabIndex = 2),
                ),
              ],
            ),
          ),
          Expanded(
            child: offers.isEmpty && shown.isEmpty
                ? Center(
                    child: Text(
                      emptyMessage,
                      style: const TextStyle(color: AppColors.textGray),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: offers.length + shown.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      if (i < offers.length) {
                        final offer = offers[i];
                        return ExclusiveOfferCard(
                          offer: offer,
                          restaurant: repo.restaurantByIdOrNull(
                            offer.restaurantId,
                          ),
                          currentVisits: repo.passageCount(
                            user.id,
                            offer.restaurantId,
                          ),
                        );
                      }
                      final rewardIndex = i - offers.length;
                      final r = shown[rewardIndex];
                      return RewardCard(reward: r, onUse: null);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surface = AppTheme.surfaceOf(context);
    final text = AppTheme.textOf(context);
    final border = AppTheme.borderOf(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.teal : surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.teal : border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : text,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
