import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/exclusive_offer.dart';
import '../models/restaurant.dart';
import '../theme/app_theme.dart';
import 'loyalo_ui.dart';

class ExclusiveOfferCard extends StatelessWidget {
  final ExclusiveOffer offer;
  final Restaurant? restaurant;
  final int? currentVisits;
  final bool compact;
  final VoidCallback? onUse;

  const ExclusiveOfferCard({
    super.key,
    required this.offer,
    this.restaurant,
    this.currentVisits,
    this.compact = false,
    this.onUse,
  });

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('dd/MM').format(offer.endsAt);
    final visitsRequired = offer.minVisitsRequired;
    final visits = currentVisits ?? 0;
    final unlocked =
        (currentVisits == null || visits >= visitsRequired) &&
        (!offer.newCustomersOnly || visits == 0);
    final conditionLabel = offer.newCustomersOnly
        ? 'Nouveaux clients uniquement'
        : 'Encore ${visitsRequired - visits} visite${visitsRequired - visits > 1 ? 's' : ''}';
    final surface = AppTheme.surfaceOf(context);
    final text = AppTheme.textOf(context);
    final muted = AppTheme.mutedOf(context);
    final border = AppTheme.borderOf(context);

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 13),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          LoyaloNetworkImage(
            url: offer.imageUrl ?? restaurant?.coverImageUrl,
            fallbackIcon: restaurant?.icon ?? Icons.local_offer_outlined,
            width: compact ? 56 : 74,
            height: compact ? 56 : 74,
            borderRadius: BorderRadius.circular(15),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  offer.title,
                  maxLines: compact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: text,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                if (restaurant != null)
                  Text(
                    restaurant!.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: text,
                    ),
                  ),
                if (!compact && offer.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    offer.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.35,
                      color: muted,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  unlocked ? 'Valable jusqu\'au $dateLabel' : conditionLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: unlocked ? AppColors.purple : muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.place_outlined, size: 12, color: muted),
                      const SizedBox(width: 3),
                      Text(
                        '${(offer.distanceKm ?? restaurant?.distanceKm ?? 0).toStringAsFixed(1)} km',
                        style: TextStyle(fontSize: 10.5, color: muted),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: unlocked ? onUse : null,
              style: TextButton.styleFrom(
                backgroundColor: unlocked ? AppColors.purple : border,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 9,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: Text(
                unlocked ? 'Utiliser' : 'Bloqué',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
