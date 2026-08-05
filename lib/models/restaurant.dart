import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

const Map<String, IconData> kRestaurantIcons = {
  'restaurant': Icons.restaurant,
  'sushi': Icons.set_meal,
  'cafe': Icons.local_cafe,
  'pizza': Icons.local_pizza,
  'store': Icons.storefront,
};

String iconKeyFor(IconData icon) {
  return kRestaurantIcons.entries.firstWhere((e) => e.value == icon, orElse: () => const MapEntry('store', Icons.storefront)).key;
}

class Restaurant {
  final String id;
  final String name;
  final String cuisine;
  final double distanceKm;
  final int rewardThreshold;
  final String rewardLabel;
  final int pointsPerVisit;
  final IconData icon;
  final double latitude;
  final double longitude;

  const Restaurant({
    required this.id,
    required this.name,
    required this.cuisine,
    required this.distanceKm,
    required this.rewardThreshold,
    required this.rewardLabel,
    required this.icon,
    this.pointsPerVisit = 350,
    // Paris (place de la Concorde) par défaut : garantit que chaque
    // restaurant a une position affichable sur la carte même si le
    // commerçant n'a pas encore renseigné son adresse exacte.
    this.latitude = 48.8656,
    this.longitude = 2.3212,
  });

  factory Restaurant.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Restaurant(
      id: doc.id,
      name: data['name'] as String? ?? '',
      cuisine: data['cuisine'] as String? ?? '',
      distanceKm: (data['distanceKm'] as num?)?.toDouble() ?? 0,
      rewardThreshold: data['rewardThreshold'] as int? ?? 10,
      rewardLabel: data['rewardLabel'] as String? ?? '',
      pointsPerVisit: data['pointsPerVisit'] as int? ?? 350,
      icon: kRestaurantIcons[data['iconKey'] as String? ?? 'store'] ?? Icons.storefront,
      latitude: (data['latitude'] as num?)?.toDouble() ?? 48.8656,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 2.3212,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'cuisine': cuisine,
      'distanceKm': distanceKm,
      'rewardThreshold': rewardThreshold,
      'rewardLabel': rewardLabel,
      'pointsPerVisit': pointsPerVisit,
      'iconKey': iconKeyFor(icon),
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
