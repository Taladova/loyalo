import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';

class RewardsManagementScreen extends ConsumerWidget {
  const RewardsManagementScreen({super.key});

  void _createReward(BuildContext context, WidgetRef ref, String restaurantId) {
    final labelController = TextEditingController();
    final thresholdController = TextEditingController(text: '10');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Créer une récompense'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: labelController, decoration: const InputDecoration(labelText: 'Récompense')),
            const SizedBox(height: 10),
            TextField(
              controller: thresholdController,
              decoration: const InputDecoration(labelText: 'Visites requises'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              final label = labelController.text.trim();
              final threshold = int.tryParse(thresholdController.text.trim()) ?? 10;
              if (label.isEmpty) return;
              ref.read(loyaltyRepositoryProvider).createRewardDefinition(restaurantId, label, threshold);
              Navigator.pop(context);
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(loyaltyRepositoryProvider);
    final restaurantId = ref.watch(currentMerchantRestaurantIdProvider)!;
    final rewards = repo.rewardDefinitionsFor(restaurantId);

    return Scaffold(
      appBar: AppBar(title: const Text('Récompenses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createReward(context, ref, restaurantId),
        backgroundColor: AppColors.purple,
        icon: const Icon(Icons.add),
        label: const Text('Créer une récompense'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: rewards.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final r = rewards[i];
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.card_giftcard, color: AppColors.orange, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('${r.thresholdVisits} visites · ${r.activeCount} actives',
                          style: const TextStyle(fontSize: 12, color: AppColors.textGray)),
                    ],
                  ),
                ),
                Switch(
                  value: r.active,
                  activeThumbColor: AppColors.purple,
                  onChanged: (_) => repo.toggleRewardDefinition(r.id),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
