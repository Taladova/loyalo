import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/wishlist_place.dart';
import '../../providers/app_providers.dart';
import '../../services/places_search_service.dart';
import '../../theme/app_theme.dart';

/// Recherche de vrais restaurants (via OpenStreetMap) à ajouter à sa liste
/// personnelle "Envie d'y aller" — distincte des restaurants partenaires
/// Loyalo, où seuls les visites/récompenses fonctionnent.
class DiscoverRestaurantScreen extends ConsumerStatefulWidget {
  const DiscoverRestaurantScreen({super.key});

  @override
  ConsumerState<DiscoverRestaurantScreen> createState() => _DiscoverRestaurantScreenState();
}

class _DiscoverRestaurantScreenState extends ConsumerState<DiscoverRestaurantScreen> {
  final _searchService = PlacesSearchService();
  final _controller = TextEditingController();
  Timer? _debounce;
  List<PlaceResult> _results = [];
  bool _loading = false;
  String? _error;
  final Set<String> _adding = {};

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => _search(query));
  }

  Future<void> _search(String query) async {
    if (query.trim().length < 3) {
      setState(() {
        _results = [];
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await _searchService.search(query);
      if (!mounted) return;
      setState(() => _results = results);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Recherche indisponible, réessayez.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add(PlaceResult place) async {
    setState(() => _adding.add(place.name + place.address));
    final user = ref.read(currentUserProvider)!;
    final wishlistPlace = WishlistPlace(
      id: '',
      userId: user.id,
      name: place.name,
      address: place.address,
      latitude: place.latitude,
      longitude: place.longitude,
      addedAt: DateTime.now(),
    );
    await FirebaseFirestore.instance.collection('wishlist').add(wishlistPlace.toMap());
    if (!mounted) return;
    setState(() => _adding.remove(place.name + place.address));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${place.name} ajouté à votre liste')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Découvrir un restaurant')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Nom d\'un restaurant, café...',
                prefixIcon: Icon(Icons.search, size: 20),
              ),
              onChanged: _onChanged,
            ),
          ),
          if (!_loading && _controller.text.trim().isNotEmpty && _controller.text.trim().length < 3)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Continuez à taper (3 caractères minimum)',
                    style: TextStyle(fontSize: 12, color: AppColors.textGray)),
              ),
            ),
          if (_loading) const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              itemCount: _results.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final place = _results[i];
                final key = place.name + place.address;
                return Container(
                  padding: const EdgeInsets.all(12),
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
                          gradient: AppColors.brandGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.storefront_outlined, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(place.name, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(place.address,
                                style: const TextStyle(fontSize: 11.5, color: AppColors.textGray),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _adding.contains(key)
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.2),
                            )
                          : IconButton(
                              onPressed: () => _add(place),
                              icon: const Icon(Icons.add_circle, color: AppColors.purple),
                              tooltip: 'Ajouter à ma liste',
                            ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
