import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/reward.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/exclusive_offer_card.dart';
import '../../widgets/loyalo_ui.dart';
import '../../widgets/reward_card.dart';
import '../../widgets/reward_unlocked_dialog.dart';
import '../../widgets/section_header.dart';
import '../notifications_screen.dart';
import 'client_visit_history_screen.dart';
import 'referral_screen.dart';
import 'rewards_screen.dart';

class ClientDashboardScreen extends ConsumerStatefulWidget {
  const ClientDashboardScreen({super.key});

  @override
  ConsumerState<ClientDashboardScreen> createState() =>
      _ClientDashboardScreenState();
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
      showRewardUnlockedDialog(
        context,
        rewardLabel: newest.label,
        restaurantName: newest.restaurantName,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(loyaltyRepositoryProvider);
    final user = ref.watch(currentUserProvider)!;
    final points = repo.totalPoints(user.id);

    final restaurants = repo.restaurants;
    if (restaurants.isEmpty && repo.restaurantsLoading) {
      return const Scaffold(
        body: SafeArea(
          child: Center(
            child: CircularProgressIndicator(color: AppColors.purple),
          ),
        ),
      );
    }
    if (restaurants.isEmpty) {
      final hasError = repo.restaurantsLoadError != null;
      return Scaffold(
        appBar: AppBar(title: const Text('Accueil')),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasError
                        ? Icons.cloud_off_outlined
                        : Icons.storefront_outlined,
                    size: 52,
                    color: AppTheme.mutedOf(context),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    hasError
                        ? 'Impossible de charger les établissements'
                        : 'Aucun établissement disponible',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textOf(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasError
                        ? 'Vérifiez votre connexion et les règles Firebase, puis relancez l’application.'
                        : 'Les établissements actifs apparaîtront ici dès leur publication.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.mutedOf(context)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    var closest = restaurants.first;
    var bestRatio = -1.0;
    for (final r in restaurants) {
      final progress = repo.loyaltyProgressFor(userId: user.id, restaurant: r);
      final ratio = progress.enabled ? progress.ratio : -1.0;
      if (ratio > bestRatio) {
        bestRatio = ratio;
        closest = r;
      }
    }
    final closestProgress = repo.loyaltyProgressFor(
      userId: user.id,
      restaurant: closest,
    );

    final rewards = repo
        .rewardsForUser(user.id)
        .where((r) => r.status == RewardStatus.available)
        .toList();
    final exclusiveOffers = repo.currentExclusiveOffersForUser(user.id);
    final visits = repo.visitsForUser(user.id).take(3).toList();
    final text = AppTheme.textOf(context);
    final muted = AppTheme.mutedOf(context);
    final surface = AppTheme.surfaceOf(context);
    final border = AppTheme.borderOf(context);
    _checkForNewRewards(rewards);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accueil'),
        actions: [
          _NotificationAction(
            count: repo.unreadNotificationsForUser(user.id),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Bonjour 👋',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: text,
              ),
            ),
            const SizedBox(height: 2),
            Text('Ravi de vous revoir !', style: TextStyle(color: muted)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.purple.withValues(alpha: 0.2),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mes points',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$points',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text(
                          'Pts disponibles',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.card_giftcard,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            LoyaloCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Prochaine récompense',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: text,
                          ),
                        ),
                      ),
                      LoyaloIconBadge(icon: Icons.card_giftcard, size: 38),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (!closestProgress.enabled)
                    Text(
                      'Ce commerce n’a pas encore activé son programme.',
                      style: TextStyle(color: muted, fontSize: 12),
                    )
                  else ...[
                    Text(
                      closestProgress.current == 0
                          ? 'Validez votre 1ère visite pour commencer'
                          : '${closestProgress.remaining} ${closestProgress.unitLabel} restantes',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: closestProgress.ratio,
                        minHeight: 7,
                        backgroundColor: AppColors.lightGray.withValues(
                          alpha: 0.45,
                        ),
                        color: AppColors.teal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      closest.rewardLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: text,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            SectionHeader(
              title: 'Offres à ne pas manquer 🔥',
              onSeeAll: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const RewardsScreen())),
            ),
            const SizedBox(height: 12),
            if (exclusiveOffers.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border),
                ),
                child: Text(
                  'Aucune offre exclusive active pour le moment.',
                  style: TextStyle(color: muted, fontSize: 13),
                ),
              )
            else
              ...exclusiveOffers
                  .take(3)
                  .map(
                    (offer) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ExclusiveOfferCard(
                        offer: offer,
                        restaurant: repo.restaurantByIdOrNull(
                          offer.restaurantId,
                        ),
                        currentVisits: repo.passageCount(
                          user.id,
                          offer.restaurantId,
                        ),
                        compact: true,
                      ),
                    ),
                  ),
            const SizedBox(height: 12),
            SectionHeader(
              title: 'Mes récompenses',
              onSeeAll: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const RewardsScreen())),
            ),
            const SizedBox(height: 12),
            if (rewards.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border),
                ),
                child: Text(
                  'Validez des visites pour débloquer vos premières récompenses.',
                  style: TextStyle(color: muted, fontSize: 13),
                ),
              )
            else
              ...rewards
                  .take(2)
                  .map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: RewardCard(reward: r),
                    ),
                  ),
            const SizedBox(height: 12),
            LoyaloCard(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.group_add_outlined,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Invitez vos amis 🎁',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: text,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Gagnez des points après leur première visite.',
                          style: TextStyle(fontSize: 11.5, color: muted),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ReferralScreen()),
                    ),
                    child: const Text('Inviter'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SectionHeader(title: 'Vos commerces favoris'),
            const SizedBox(height: 12),
            SizedBox(
              height: 104,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: restaurants.take(4).length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final restaurant = restaurants[i];
                  return SizedBox(
                    width: 82,
                    child: Column(
                      children: [
                        LoyaloMerchantAvatar(
                          imageUrl:
                              restaurant.logoUrl ?? restaurant.coverImageUrl,
                          icon: restaurant.icon,
                          size: 60,
                        ),
                        const SizedBox(height: 7),
                        Text(
                          restaurant.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          restaurant.cuisine.split(' ').first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 10.5, color: muted),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            SectionHeader(
              title: 'Historique des visites',
              onSeeAll: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ClientVisitHistoryScreen(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            LoyaloCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: visits.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        'Aucune visite pour le moment.',
                        style: TextStyle(color: muted, fontSize: 13),
                      ),
                    )
                  : Column(
                      children: visits.map((visit) {
                        final restaurant = repo.restaurantByIdOrNull(
                          visit.restaurantId,
                        );
                        return ListTile(
                          leading: LoyaloMerchantAvatar(
                            imageUrl:
                                restaurant?.logoUrl ??
                                restaurant?.coverImageUrl,
                            icon: restaurant?.icon ?? Icons.storefront_outlined,
                            size: 42,
                          ),
                          title: Text(
                            restaurant?.name ?? 'Commerce',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: text,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            DateFormat('dd/MM/yyyy').format(visit.timestamp),
                            style: TextStyle(color: muted, fontSize: 11),
                          ),
                          trailing: Text(
                            '+${restaurant?.pointsPerVisit ?? 0} pts',
                            style: const TextStyle(
                              color: AppColors.teal,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationAction extends StatelessWidget {
  final int count;
  final VoidCallback onPressed;

  const _NotificationAction({required this.count, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: const Icon(Icons.notifications_none),
          tooltip: 'Notifications',
        ),
        if (count > 0)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(999),
              ),
              constraints: const BoxConstraints(minWidth: 17),
              child: Text(
                count > 9 ? '9+' : '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
