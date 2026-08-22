import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/restaurant.dart';
import '../../models/wishlist_place.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';
import 'discover_restaurant_screen.dart';
import 'restaurant_detail_screen.dart';

class RestaurantListScreen extends ConsumerStatefulWidget {
  const RestaurantListScreen({super.key});

  @override
  ConsumerState<RestaurantListScreen> createState() => _RestaurantListScreenState();
}

class _RestaurantListScreenState extends ConsumerState<RestaurantListScreen> {
  String _query = '';
  int _filterIndex = 0;
  static const _filters = ['Tous', 'À proximité', 'Nouveautés'];

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(loyaltyRepositoryProvider);
    final user = ref.watch(currentUserProvider)!;

    var restaurants = repo.restaurants.where((r) => r.name.toLowerCase().contains(_query.toLowerCase())).toList();
    if (_filterIndex == 1) {
      restaurants = restaurants.where((r) => r.distanceKm <= 1.5).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurants'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DiscoverRestaurantScreen()),
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
              decoration: const InputDecoration(
                hintText: 'Rechercher un commerce',
                prefixIcon: Icon(Icons.search, size: 20),
              ),
              onChanged: (v) => setState(() => _query = v),
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
                final selected = i == _filterIndex;
                return ChoiceChip(
                  label: Text(_filters[i]),
                  selected: selected,
                  onSelected: (_) => setState(() => _filterIndex = i),
                  selectedColor: AppColors.teal,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppColors.textDark,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: restaurants.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final r = restaurants[i];
                final count = repo.passageCount(user.id, r.id);
                return _RestaurantTile(restaurant: r, passageCount: count);
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
        final places = (snapshot.data?.docs ?? []).map(WishlistPlace.fromFirestore).toList()
          ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
        if (places.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 0, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Envie d\'y aller', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              SizedBox(
                height: 96,
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
        content: Text('Retirer "${place.name}" de votre liste "Envie d\'y aller" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              FirebaseFirestore.instance.collection('wishlist').doc(place.id).delete();
            },
            child: const Text('Retirer', style: TextStyle(color: AppColors.danger)),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
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
                child: const Icon(Icons.close, size: 15, color: AppColors.textGray),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(place.name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(place.address,
              style: const TextStyle(fontSize: 10.5, color: AppColors.textGray),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _RestaurantTile extends StatelessWidget {
  final Restaurant restaurant;
  final int passageCount;

  const _RestaurantTile({required this.restaurant, required this.passageCount});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => RestaurantDetailScreen(restaurant: restaurant)),
      ),
      child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(restaurant.icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(restaurant.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('${restaurant.cuisine} · ${restaurant.distanceKm} km',
                    style: const TextStyle(fontSize: 12, color: AppColors.textGray)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.lavender.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$passageCount/${restaurant.rewardThreshold}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.purple)),
          ),
        ],
      ),
      ),
    );
  }
}
