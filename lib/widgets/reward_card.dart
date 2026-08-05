import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/reward.dart';
import '../theme/app_theme.dart';

class RewardCard extends StatelessWidget {
  final RewardItem reward;
  final VoidCallback? onUse;

  const RewardCard({super.key, required this.reward, this.onUse});

  @override
  Widget build(BuildContext context) {
    final used = reward.status == RewardStatus.used;
    final dateLabel = DateFormat('dd/MM/yyyy').format(reward.expiresAt);

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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.card_giftcard, color: AppColors.orange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reward.label,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
                const SizedBox(height: 2),
                Text(reward.restaurantName, style: const TextStyle(fontSize: 12, color: AppColors.textGray)),
                const SizedBox(height: 2),
                Text(
                  used ? 'Utilisée' : 'Valable jusqu\'au $dateLabel',
                  style: TextStyle(fontSize: 11, color: used ? AppColors.textGray : AppColors.textGray),
                ),
              ],
            ),
          ),
          if (!used && onUse != null)
            TextButton(
              onPressed: onUse,
              style: TextButton.styleFrom(
                backgroundColor: AppColors.purple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              child: const Text('Utiliser', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}
