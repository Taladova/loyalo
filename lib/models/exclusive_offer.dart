import 'package:cloud_firestore/cloud_firestore.dart';

class ExclusiveOffer {
  final String id;
  final String restaurantId;
  final String title;
  final String description;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool active;
  final int minVisitsRequired;
  final bool newCustomersOnly;
  final String? imageUrl;
  final double? distanceKm;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ExclusiveOffer({
    required this.id,
    required this.restaurantId,
    required this.title,
    required this.description,
    required this.startsAt,
    required this.endsAt,
    required this.active,
    this.minVisitsRequired = 0,
    this.newCustomersOnly = false,
    this.imageUrl,
    this.distanceKm,
    this.createdAt,
    this.updatedAt,
  });

  ExclusiveOffer copyWith({
    String? title,
    String? description,
    DateTime? startsAt,
    DateTime? endsAt,
    bool? active,
    int? minVisitsRequired,
    bool? newCustomersOnly,
    String? imageUrl,
    double? distanceKm,
    DateTime? updatedAt,
  }) {
    return ExclusiveOffer(
      id: id,
      restaurantId: restaurantId,
      title: title ?? this.title,
      description: description ?? this.description,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      active: active ?? this.active,
      minVisitsRequired: minVisitsRequired ?? this.minVisitsRequired,
      newCustomersOnly: newCustomersOnly ?? this.newCustomersOnly,
      imageUrl: imageUrl ?? this.imageUrl,
      distanceKm: distanceKm ?? this.distanceKm,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory ExclusiveOffer.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    final starts = data['startsAt'];
    final ends = data['endsAt'];
    final created = data['createdAt'];
    final updated = data['updatedAt'];
    return ExclusiveOffer(
      id: doc.id,
      restaurantId: data['restaurantId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      startsAt: starts is Timestamp ? starts.toDate() : DateTime.now(),
      endsAt: ends is Timestamp
          ? ends.toDate()
          : DateTime.now().add(const Duration(days: 7)),
      active: data['active'] as bool? ?? true,
      minVisitsRequired: (data['minVisitsRequired'] as num?)?.toInt() ?? 0,
      newCustomersOnly: data['newCustomersOnly'] as bool? ?? false,
      imageUrl: data['imageUrl'] as String?,
      distanceKm: (data['distanceKm'] as num?)?.toDouble(),
      createdAt: created is Timestamp ? created.toDate() : null,
      updatedAt: updated is Timestamp ? updated.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'restaurantId': restaurantId,
      'title': title,
      'description': description,
      'startsAt': Timestamp.fromDate(startsAt),
      'endsAt': Timestamp.fromDate(endsAt),
      'active': active,
      'minVisitsRequired': minVisitsRequired,
      'newCustomersOnly': newCustomersOnly,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (distanceKm != null) 'distanceKm': distanceKm,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
