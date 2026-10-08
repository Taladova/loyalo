import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/restaurant.dart';
import '../../models/wishlist_place.dart';
import '../../providers/app_providers.dart';
import '../../services/loyalty_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/loyalo_ui.dart';
import 'discover_restaurant_screen.dart';
import 'restaurant_detail_screen.dart';

class RestaurantListScreen extends ConsumerStatefulWidget {
  const RestaurantListScreen({super.key});

  @override
  ConsumerState<RestaurantListScreen> createState() =>
      _RestaurantListScreenState();
}

class _RestaurantListScreenState extends ConsumerState<RestaurantListScreen> {
  final _searchController = TextEditingController();
  String _debouncedQuery = '';
  String? _category;
  RestaurantPrimaryFilter _filter = RestaurantPrimaryFilter.all;
  Timer? _debounce;
  Position? _position;
  bool _loadingLocation = false;
  bool _locationDenied = false;
  static const _filters = [
    (RestaurantPrimaryFilter.all, 'Tous'),
    (RestaurantPrimaryFilter.nearby, 'À proximité'),
    (RestaurantPrimaryFilter.favorites, 'Favoris'),
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _debouncedQuery = value);
    });
  }

  Future<void> _enableLocationIfNeeded() async {
    if (_position != null || _loadingLocation || _locationDenied) return;
    setState(() => _loadingLocation = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final position = await Geolocator.getCurrentPosition();
        if (!mounted) return;
        setState(() {
          _position = position;
          _locationDenied = false;
        });
      } else if (mounted) {
        setState(() => _locationDenied = true);
      }
    } catch (_) {
      if (mounted) setState(() => _locationDenied = true);
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(loyaltyRepositoryProvider);
    final user = ref.watch(currentUserProvider)!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Commerces Loyalo'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const DiscoverRestaurantScreen(),
              ),
            ),
            icon: const Icon(Icons.add_location_alt_outlined),
            tooltip: 'Découvrir un restaurant',
          ),
        ],
      ),
      body: Column(
        children: [
          _WishlistSection(userId: user.id),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Nom, ville, adresse...',
                prefixIcon: Icon(Icons.search, size: 20),
              ),
              onChanged: _onQueryChanged,
            ),
          ),
          SizedBox(
            height: 36,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final (filter, label) = _filters[i];
                final selected = filter == _filter;
                return ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      _filter = filter;
                    });
                    if (filter == RestaurantPrimaryFilter.nearby) {
                      _enableLocationIfNeeded();
                    }
                  },
                  selectedColor: AppColors.teal,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppTheme.textOf(context),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: AppTheme.surfaceOf(context),
                  side: BorderSide(color: AppTheme.borderOf(context)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: kRestaurantCategories.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final category = i == 0 ? null : kRestaurantCategories[i - 1];
                final selected = category == _category;
                return ChoiceChip(
                  label: Text(category ?? 'Toutes catégories'),
                  selected: selected,
                  onSelected: (_) => setState(() => _category = category),
                  selectedColor: AppColors.purple,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppTheme.textOf(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: AppTheme.surfaceOf(context),
                  side: BorderSide(color: AppTheme.borderOf(context)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              },
            ),
          ),
          if (_filter == RestaurantPrimaryFilter.nearby &&
              (_loadingLocation || _locationDenied))
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Row(
                children: [
                  if (_loadingLocation) ...[
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Recherche de votre position...',
                      style: TextStyle(
                        color: AppTheme.mutedOf(context),
                        fontSize: 12,
                      ),
                    ),
                  ] else
                    Expanded(
                      child: Text(
                        'Localisation refusée : la recherche par nom, ville et catégorie reste disponible.',
                        style: TextStyle(
                          color: AppTheme.mutedOf(context),
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('wishlist')
                  .where('userId', isEqualTo: user.id)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const _SearchMessage(
                    icon: Icons.error_outline,
                    title: 'Recherche indisponible.',
                    subtitle: 'Réessayez dans quelques instants.',
                  );
                }

                final favoriteIds = (snapshot.data?.docs ?? [])
                    .map(WishlistPlace.fromFirestore)
                    .where((place) => place.restaurantId?.isNotEmpty == true)
                    .map((place) => place.restaurantId!)
                    .toSet();
                final results = repo.searchRestaurants(
                  query: _debouncedQuery,
                  category: _category,
                  filter: _filter,
                  favoriteRestaurantIds: favoriteIds,
                  userLatitude: _position?.latitude,
                  userLongitude: _position?.longitude,
                );

                if (repo.restaurants.isEmpty && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (results.isEmpty) {
                  return const _SearchMessage(
                    icon: Icons.search_off_outlined,
                    title: 'Aucun commerce trouvé.',
                    subtitle: 'Essayez une autre recherche ou catégorie.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: results.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final result = results[i];
                    final r = result.restaurant;
                    final count = repo.passageCount(user.id, r.id);
                    return _RestaurantTile(
                      restaurant: r,
                      passageCount: count,
                      distanceLabel: LoyaltyRepository.formatDistance(
                        result.distanceMeters,
                        r.distanceKm,
                      ),
                      favorite: result.favorite,
                      userId: user.id,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WishlistSection extends StatelessWidget {
  final String userId;

  const _WishlistSection({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('wishlist')
          .where('userId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        final places =
            (snapshot.data?.docs ?? [])
                .map(WishlistPlace.fromFirestore)
                .where((place) => place.restaurantId == null)
                .toList()
              ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
        if (places.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 0, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Envie d\'y aller',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 132,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: places.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, i) => _WishlistCard(place: places[i]),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );
  }
}

class _WishlistCard extends StatelessWidget {
  final WishlistPlace place;

  const _WishlistCard({required this.place});

  void _remove(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Retirer de ma liste'),
        content: Text(
          'Retirer "${place.name}" de votre liste "Envie d\'y aller" ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              FirebaseFirestore.instance
                  .collection('wishlist')
                  .doc(place.id)
                  .delete();
            },
            child: const Text(
              'Retirer',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite, color: AppColors.orange, size: 15),
              const Spacer(),
              InkWell(
                onTap: () => _remove(context),
                child: const Icon(
                  Icons.close,
                  size: 15,
                  color: AppColors.textGray,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LoyaloNetworkImage(
            url: place.imageUrl,
            fallbackIcon: Icons.storefront_outlined,
            width: double.infinity,
            height: 36,
            borderRadius: BorderRadius.circular(10),
          ),
          const SizedBox(height: 6),
          Text(
            place.name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            place.address,
            style: const TextStyle(fontSize: 10.5, color: AppColors.textGray),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _RestaurantTile extends StatelessWidget {
  final Restaurant restaurant;
  final int passageCount;
  final String distanceLabel;
  final bool favorite;
  final String userId;

  const _RestaurantTile({
    required this.restaurant,
    required this.passageCount,
    required this.distanceLabel,
    required this.favorite,
    required this.userId,
  });

  Future<void> _toggleFavorite() async {
    final ref = FirebaseFirestore.instance
        .collection('wishlist')
        .doc('partner_${userId}_${restaurant.id}');
    if (favorite) {
      await ref.delete();
    } else {
      await ref.set(
        WishlistPlace(
          id: ref.id,
          userId: userId,
          restaurantId: restaurant.id,
          source: 'loyalo',
          name: restaurant.name,
          address: restaurant.address ?? restaurant.city,
          latitude: restaurant.latitude,
          longitude: restaurant.longitude,
          imageUrl: restaurant.logoUrl ?? restaurant.coverImageUrl,
          addedAt: DateTime.now(),
        ).toMap(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTheme.textOf(context);
    final muted = AppTheme.mutedOf(context);
    final surface = AppTheme.surfaceOf(context);
    final border = AppTheme.borderOf(context);

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RestaurantDetailScreen(restaurant: restaurant),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: AppTheme.isDark(context) ? 0.16 : 0.05,
              ),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            LoyaloNetworkImage(
              url: restaurant.coverImageUrl ?? restaurant.logoUrl,
              fallbackIcon: restaurant.icon,
              width: 76,
              height: 76,
              borderRadius: BorderRadius.circular(18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant.name,
                    style: TextStyle(fontWeight: FontWeight.w800, color: text),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.star, color: AppColors.orange, size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${restaurant.rating.toStringAsFixed(1)} · ${restaurant.category}',
                          style: TextStyle(fontSize: 11.5, color: muted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '$distanceLabel · $passageCount/${restaurant.rewardThreshold} visites',
                        style: TextStyle(fontSize: 11.5, color: muted),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.teal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Partenaire Loyalo',
                          style: TextStyle(
                            color: AppColors.teal,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _toggleFavorite,
              icon: Icon(
                favorite ? Icons.favorite : Icons.favorite_border,
                color: favorite ? AppColors.orange : AppColors.textGray,
              ),
              tooltip: favorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SearchMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LoyaloIconBadge(icon: icon, color: AppColors.purple, size: 58),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textOf(context),
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.mutedOf(context),
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
