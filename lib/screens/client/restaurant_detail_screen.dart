import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../../models/check_in_request.dart';
import '../../models/restaurant.dart';
import '../../providers/app_providers.dart';
import '../../services/loyalty_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/exclusive_offer_card.dart';
import '../../widgets/loyalo_ui.dart';
import '../../widgets/restaurant_map.dart';
import '../../widgets/review_section.dart';

class RestaurantDetailScreen extends ConsumerWidget {
  final Restaurant restaurant;

  const RestaurantDetailScreen({super.key, required this.restaurant});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(loyaltyRepositoryProvider);
    final user = ref.watch(currentUserProvider);
    final count = user == null ? 0 : repo.passageCount(user.id, restaurant.id);
    final progress = repo.loyaltyProgressFor(
      userId: user?.id ?? '',
      restaurant: restaurant,
    );
    final visits = user == null
        ? const []
        : repo
              .visitsForUser(user.id)
              .where((v) => v.restaurantId == restaurant.id)
              .toList();
    final rewardDefs = repo
        .rewardDefinitionsFor(restaurant.id)
        .where((r) => r.active)
        .toList();
    final exclusiveOffers = repo.currentExclusiveOffersForRestaurant(
      restaurantId: restaurant.id,
      userId: user?.id ?? '',
    );
    final openingLabel = _openingLabel(restaurant);
    final text = AppTheme.textOf(context);
    final muted = AppTheme.mutedOf(context);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            SizedBox(
              height: 278,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: LoyaloNetworkImage(
                      url: restaurant.coverImageUrl,
                      fallbackIcon: restaurant.icon,
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.4),
                            Colors.black.withValues(alpha: 0.04),
                            Colors.black.withValues(alpha: 0.5),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    left: 14,
                    child: _HeroButton(
                      icon: Icons.arrow_back,
                      onTap: () => Navigator.maybeOf(context)?.maybePop(),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    right: 14,
                    child: _HeroButton(
                      icon: Icons.favorite_border,
                      onTap: () {},
                    ),
                  ),
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 18,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            gradient: AppColors.brandGradient,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            restaurant.cuisine.split(' ').first,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          restaurant.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -18),
              child: LoyaloCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          color: AppColors.orange,
                          size: 17,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${restaurant.rating.toStringAsFixed(1)} (${restaurant.reviewCount} avis)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: text,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          openingLabel,
                          style: const TextStyle(
                            color: AppColors.success,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            restaurant.address?.isNotEmpty == true
                                ? restaurant.address!
                                : '12 Rue de la Paix, 75002 Paris',
                            style: TextStyle(fontSize: 12, color: muted),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.directions_walk, color: muted, size: 15),
                        const SizedBox(width: 4),
                        Text(
                          restaurant.distanceKm < 1
                              ? '${(restaurant.distanceKm * 1000).round()} m'
                              : '${restaurant.distanceKm.toStringAsFixed(1)} km',
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Text(
              'À propos',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              restaurant.description.isNotEmpty
                  ? restaurant.description
                  : '${restaurant.cuisine} traditionnelle dans une ambiance chaleureuse. Profitez du programme fidélité Loyalo et débloquez ${restaurant.rewardLabel.toLowerCase()}.',
              style: TextStyle(fontSize: 13, color: muted, height: 1.55),
            ),
            if (restaurant.galleryUrls.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'Photos',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 112,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: restaurant.galleryUrls.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    return LoyaloNetworkImage(
                      url: restaurant.galleryUrls[index],
                      fallbackIcon: restaurant.icon,
                      width: 132,
                      height: 112,
                      borderRadius: BorderRadius.circular(18),
                    );
                  },
                ),
              ),
            ],
            if (restaurant.phone.isNotEmpty ||
                restaurant.email.isNotEmpty ||
                restaurant.website.isNotEmpty) ...[
              const SizedBox(height: 14),
              _ContactInfo(restaurant: restaurant),
            ],
            const SizedBox(height: 22),
            if (user != null) ...[
              _CheckInPanel(restaurant: restaurant),
              const SizedBox(height: 14),
              LoyaloGradientButton(
                label: 'Y aller',
                icon: Icons.near_me_outlined,
                onPressed: () {},
              ),
              const SizedBox(height: 24),
              _LoyaltyProgramPanel(progress: progress),
            ],
            const SizedBox(height: 24),
            const Text(
              'Localisation',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            RestaurantMap(restaurant: restaurant),
            if (exclusiveOffers.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Offres exclusives',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              ...exclusiveOffers.map(
                (offer) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ExclusiveOfferCard(
                    offer: offer,
                    restaurant: restaurant,
                    currentVisits: count,
                  ),
                ),
              ),
            ],
            if (rewardDefs.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Récompenses proposées',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              ...rewardDefs.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: LoyaloCard(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const LoyaloIconBadge(
                          icon: Icons.card_giftcard,
                          color: AppColors.orange,
                          size: 40,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            r.label,
                            style: TextStyle(
                              color: text,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Text(
                          '${r.thresholdVisits} visites',
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            if (user != null) ...[
              const SizedBox(height: 24),
              const Text(
                'Mes visites ici',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              if (visits.isEmpty)
                Text(
                  'Aucune visite pour le moment.',
                  style: TextStyle(color: muted, fontSize: 13),
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
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('dd/MM/yyyy à HH:mm').format(v.timestamp),
                          style: TextStyle(fontSize: 13, color: text),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
            if (user != null)
              ReviewSection(
                restaurantId: restaurant.id,
                restaurantName: restaurant.name,
                userId: user.id,
                userName: user.name,
              ),
          ],
        ),
      ),
    );
  }
}

String _openingLabel(Restaurant restaurant) {
  const dayKeys = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];
  final now = DateTime.now();
  final key = dayKeys[now.weekday - 1];
  final hours = restaurant.openingHours[key];
  if (hours == null || !hours.open) return 'Fermé aujourd’hui';
  return 'Ouvert jusqu’à ${hours.closesAt}';
}

class _ContactInfo extends StatelessWidget {
  final Restaurant restaurant;

  const _ContactInfo({required this.restaurant});

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.mutedOf(context);
    final rows = <Widget>[
      if (restaurant.phone.isNotEmpty)
        _ContactRow(icon: Icons.phone_outlined, text: restaurant.phone),
      if (restaurant.email.isNotEmpty)
        _ContactRow(icon: Icons.email_outlined, text: restaurant.email),
      if (restaurant.website.isNotEmpty)
        _ContactRow(icon: Icons.language, text: restaurant.website),
    ];
    return Column(
      children: rows
          .map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: DefaultTextStyle(
                style: TextStyle(color: muted, fontSize: 12.5),
                child: row,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ContactRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppTheme.mutedOf(context)),
        const SizedBox(width: 7),
        Expanded(child: Text(text, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

class _LoyaltyProgramPanel extends StatelessWidget {
  final LoyaltyProgress progress;

  const _LoyaltyProgramPanel({required this.progress});

  @override
  Widget build(BuildContext context) {
    final text = AppTheme.textOf(context);
    final muted = AppTheme.mutedOf(context);
    final restaurant = progress.restaurant;
    final intro = restaurant.loyaltyProgramType == LoyaltyProgramType.points
        ? '1 visite = +${restaurant.pointsPerVisit} pts'
        : '${progress.threshold} visites = 1 récompense';

    return LoyaloCard(
      padding: const EdgeInsets.all(18),
      child: progress.enabled
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Programme fidélité',
                  style: TextStyle(
                    color: text,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(intro, style: TextStyle(color: muted, fontSize: 12.5)),
                const SizedBox(height: 12),
                Text(
                  '${progress.current} / ${progress.threshold} ${progress.unitLabel}',
                  style: TextStyle(
                    color: text,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  progress.current == 0
                      ? 'Validez votre 1ère visite pour commencer !'
                      : 'Encore ${progress.remaining} ${progress.unitLabel} pour gagner "${progress.rewardLabel}"',
                  style: TextStyle(color: muted, fontSize: 12.5),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress.ratio,
                    minHeight: 7,
                    backgroundColor: AppColors.lightGray.withValues(
                      alpha: 0.45,
                    ),
                    color: AppColors.teal,
                  ),
                ),
                if (restaurant.rewardDescription.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    restaurant.rewardDescription,
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ],
            )
          : Text(
              'Ce commerce n’a pas encore activé son programme de fidélité.',
              style: TextStyle(color: muted, fontSize: 13),
            ),
    );
  }
}

class _CheckInPanel extends ConsumerStatefulWidget {
  final Restaurant restaurant;

  const _CheckInPanel({required this.restaurant});

  @override
  ConsumerState<_CheckInPanel> createState() => _CheckInPanelState();
}

class _CheckInPanelState extends ConsumerState<_CheckInPanel> {
  bool _loading = false;
  bool _cancelling = false;

  Future<void> _signalArrival() async {
    setState(() => _loading = true);
    final user = ref.read(currentUserProvider)!;
    final repo = ref.read(loyaltyRepositoryProvider);
    double? latitude;
    double? longitude;
    double? distanceMeters;

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final position = await Geolocator.getCurrentPosition();
        latitude = position.latitude;
        longitude = position.longitude;
        distanceMeters = Geolocator.distanceBetween(
          latitude,
          longitude,
          widget.restaurant.latitude,
          widget.restaurant.longitude,
        );
      }
    } catch (_) {
      // La localisation améliore la vérification, mais le code commerçant
      // reste la méthode de secours si l'appareil la refuse ou échoue.
    }

    try {
      final result = await repo.createCheckIn(
        userId: user.id,
        restaurantId: widget.restaurant.id,
        customerLatitude: latitude,
        customerLongitude: longitude,
        distanceMeters: distanceMeters,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      _showArrivalFeedback(result.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showArrivalFeedback(
        'Impossible de signaler votre arrivée. Vérifiez la connexion et les règles Firestore.',
      );
    }
  }

  void _showArrivalFeedback(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _cancelArrival(CheckInRequest request) async {
    setState(() => _cancelling = true);
    final user = ref.read(currentUserProvider)!;
    try {
      await ref
          .read(loyaltyRepositoryProvider)
          .cancelCheckIn(checkInId: request.id, userId: user.id);
      if (!mounted) return;
      _showArrivalFeedback('Votre demande a été annulée.');
    } catch (_) {
      if (!mounted) return;
      _showArrivalFeedback('Impossible d’annuler la demande pour le moment.');
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(loyaltyRepositoryProvider);
    final user = ref.watch(currentUserProvider)!;
    final active = repo.activeCheckInForUserAndRestaurant(
      userId: user.id,
      restaurantId: widget.restaurant.id,
    );
    final text = AppTheme.textOf(context);
    final muted = AppTheme.mutedOf(context);

    if (active != null) {
      final expiresIn = active.expiresAt.difference(DateTime.now()).inMinutes;
      return LoyaloCard(
        child: Row(
          children: [
            const LoyaloIconBadge(
              icon: Icons.hourglass_top,
              color: AppColors.orange,
              size: 48,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Validation en attente',
                    style: TextStyle(
                      color: text,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Arrivée signalée à ${DateFormat('HH:mm').format(active.requestedAt)} · expire dans ${expiresIn.clamp(0, 10)} min',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _cancelling ? null : () => _cancelArrival(active),
              child: Text(_cancelling ? '...' : 'Annuler'),
            ),
          ],
        ),
      );
    }

    return LoyaloCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const LoyaloIconBadge(
                icon: Icons.location_on_outlined,
                color: AppColors.teal,
                size: 48,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vous êtes sur place ?',
                      style: TextStyle(
                        color: text,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Signalez votre arrivée. Votre fidélité sera mise à jour après validation.',
                      style: TextStyle(
                        color: muted,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LoyaloGradientButton(
            label: _loading ? 'Signalement...' : 'Je suis ici',
            icon: Icons.check_circle_outline,
            onPressed: _loading ? null : _signalArrival,
          ),
        ],
      ),
    );
  }
}

class _HeroButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeroButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.28),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
