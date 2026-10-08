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
    final surface = AppTheme.surfaceOf(context);
    final text = AppTheme.textOf(context);
    final muted = AppTheme.mutedOf(context);
    final border = AppTheme.borderOf(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border.withValues(alpha: 0.65)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: AppTheme.isDark(context) ? 0.16 : 0.05,
            ),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.card_giftcard, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reward.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: text,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reward.restaurantName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  used ? 'Utilisée' : 'Valable jusqu\'au $dateLabel',
                  style: TextStyle(fontSize: 11, color: muted),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
              child: const Text(
                'Utiliser',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}
