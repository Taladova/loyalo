import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/restaurant.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/restaurant_map.dart';
import '../../widgets/review_section.dart';

class RestaurantDetailScreen extends ConsumerWidget {
  final Restaurant restaurant;

  const RestaurantDetailScreen({super.key, required this.restaurant});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(loyaltyRepositoryProvider);
    final user = ref.watch(currentUserProvider)!;
    final count = repo.passageCount(user.id, restaurant.id);
    final currentCount = count % restaurant.rewardThreshold;
    final remaining = restaurant.rewardThreshold - currentCount;
    final visits = repo.visitsForUser(user.id).where((v) => v.restaurantId == restaurant.id).toList();
    final rewardDefs = repo.rewardDefinitionsFor(restaurant.id).where((r) => r.active).toList();

    return Scaffold(
      appBar: AppBar(title: Text(restaurant.name)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(16)),
                child: Icon(restaurant.icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(restaurant.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    Text('${restaurant.cuisine} · ${restaurant.distanceKm} km',
                        style: const TextStyle(fontSize: 12.5, color: AppColors.textGray)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$currentCount visites sur ${restaurant.rewardThreshold}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  remaining == restaurant.rewardThreshold
                      ? 'Validez votre 1ère visite pour commencer !'
                      : 'Encore $remaining visites pour gagner "${restaurant.rewardLabel}"',
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: currentCount / restaurant.rewardThreshold,
                    minHeight: 7,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Localisation', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          RestaurantMap(restaurant: restaurant),
          if (rewardDefs.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text('Récompenses proposées', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...rewardDefs.map((r) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.card_giftcard, color: AppColors.orange, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text(r.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                      Text('${r.thresholdVisits} visites', style: const TextStyle(fontSize: 12, color: AppColors.textGray)),
                    ],
                  ),
                )),
          ],
          const SizedBox(height: 24),
          const Text('Mes visites ici', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (visits.isEmpty)
            const Text('Aucune visite pour le moment.', style: TextStyle(color: AppColors.textGray, fontSize: 13))
          else
            ...visits.map((v) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: AppColors.success, size: 18),
                      const SizedBox(width: 8),
                      Text(DateFormat('dd/MM/yyyy à HH:mm').format(v.timestamp),
                          style: const TextStyle(fontSize: 13, color: AppColors.textDark)),
                    ],
                  ),
                )),
          const SizedBox(height: 24),
          ReviewSection(
            restaurantId: restaurant.id,
            restaurantName: restaurant.name,
            userId: user.id,
            userName: user.name,
          ),
        ],
      ),
    );
  }
}
