import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../services/analytics_service.dart';
import '../../theme/app_theme.dart';

class RewardsManagementScreen extends ConsumerWidget {
  const RewardsManagementScreen({super.key});

  void _createReward(BuildContext context, WidgetRef ref, String restaurantId) {
    final labelController = TextEditingController();
    final thresholdController = TextEditingController(text: '10');
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final canSubmit = labelController.text.trim().isNotEmpty;
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.card_giftcard, color: Colors.white, size: 22),
                  ),
                  const SizedBox(height: 16),
                  const Text('Créer une récompense',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                  const SizedBox(height: 4),
                  const Text(
                    'Définissez la récompense et le nombre de visites nécessaires pour la débloquer.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.textGray, height: 1.4),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: labelController,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Récompense',
                      hintText: 'Ex : Un café offert',
                      prefixIcon: Icon(Icons.card_giftcard_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: thresholdController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Visites requises',
                      prefixIcon: Icon(Icons.repeat, size: 20),
                    ),
                  ),
                  const SizedBox(height: 26),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Annuler'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: !canSubmit
                            ? null
                            : () {
                                final label = labelController.text.trim();
                                final threshold = int.tryParse(thresholdController.text.trim()) ?? 10;
                                ref
                                    .read(loyaltyRepositoryProvider)
                                    .createRewardDefinition(restaurantId, label, threshold);
                                AnalyticsService.logRewardCreated(restaurantId: restaurantId);
                                Navigator.pop(context);
                              },
                        child: const Text('Créer'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
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
        foregroundColor: Colors.white,
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
