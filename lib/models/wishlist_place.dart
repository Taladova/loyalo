import 'package:cloud_firestore/cloud_firestore.dart';

/// Un lieu réel (trouvé via la recherche) que le client a mis de côté avec
/// l'idée d'y aller un jour — indépendant du programme de fidélité : ce
/// n'est pas forcément un restaurant partenaire Loyalo.
class WishlistPlace {
  final String id;
  final String userId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String? imageUrl;
  final String? restaurantId;
  final String source;
  final DateTime addedAt;

  const WishlistPlace({
    required this.id,
    required this.userId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.imageUrl,
    this.restaurantId,
    this.source = 'external',
    required this.addedAt,
  });

  factory WishlistPlace.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    final added = data['addedAt'];
    return WishlistPlace(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      address: data['address'] as String? ?? '',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
      imageUrl: data['imageUrl'] as String?,
      restaurantId: data['restaurantId'] as String?,
      source: data['source'] as String? ?? 'external',
      addedAt: added is Timestamp ? added.toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      if (imageUrl != null && imageUrl!.isNotEmpty) 'imageUrl': imageUrl,
      if (restaurantId != null && restaurantId!.isNotEmpty)
        'restaurantId': restaurantId,
      'source': source,
      'addedAt': FieldValue.serverTimestamp(),
    };
  }
}
