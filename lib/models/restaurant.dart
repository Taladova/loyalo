import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

const Map<String, IconData> kRestaurantIcons = {
  'restaurant': Icons.restaurant,
  'sushi': Icons.set_meal,
  'cafe': Icons.local_cafe,
  'pizza': Icons.local_pizza,
  'store': Icons.storefront,
  'bakery': Icons.bakery_dining,
  'beauty': Icons.spa,
  'shop': Icons.shopping_bag_outlined,
  'sport': Icons.fitness_center,
  'garage': Icons.build_outlined,
};

const List<String> kRestaurantCategories = [
  'Restaurant',
  'Café',
  'Boulangerie',
  'Coiffure',
  'Beauté',
  'Boutique',
  'Sport',
  'Garage',
  'Autre',
];

enum VisitValidationPolicy { oncePerDay, onceEveryXHours, perTransaction }

extension VisitValidationPolicyX on VisitValidationPolicy {
  String get firestoreValue {
    switch (this) {
      case VisitValidationPolicy.oncePerDay:
        return 'oncePerDay';
      case VisitValidationPolicy.onceEveryXHours:
        return 'onceEveryXHours';
      case VisitValidationPolicy.perTransaction:
        return 'perTransaction';
    }
  }

  static VisitValidationPolicy fromFirestore(String? value) {
    switch (value) {
      case 'onceEveryXHours':
        return VisitValidationPolicy.onceEveryXHours;
      case 'perTransaction':
        return VisitValidationPolicy.perTransaction;
      case 'oncePerDay':
      default:
        return VisitValidationPolicy.oncePerDay;
    }
  }
}

enum RestaurantStatus { draft, pendingReview, active, suspended }

enum LoyaltyProgramType { visits, points }

extension LoyaltyProgramTypeX on LoyaltyProgramType {
  String get firestoreValue {
    switch (this) {
      case LoyaltyProgramType.visits:
        return 'visits';
      case LoyaltyProgramType.points:
        return 'points';
    }
  }

  static LoyaltyProgramType fromFirestore(String? value) {
    switch (value) {
      case 'points':
        return LoyaltyProgramType.points;
      case 'visits':
      default:
        return LoyaltyProgramType.visits;
    }
  }
}

extension RestaurantStatusX on RestaurantStatus {
  String get firestoreValue {
    switch (this) {
      case RestaurantStatus.draft:
        return 'draft';
      case RestaurantStatus.pendingReview:
        return 'pendingReview';
      case RestaurantStatus.active:
        return 'active';
      case RestaurantStatus.suspended:
        return 'suspended';
    }
  }

  static RestaurantStatus fromFirestore(String? value) {
    switch (value) {
      case 'draft':
        return RestaurantStatus.draft;
      case 'pendingReview':
        return RestaurantStatus.pendingReview;
      case 'suspended':
        return RestaurantStatus.suspended;
      case 'active':
      default:
        return RestaurantStatus.active;
    }
  }
}

class OpeningHours {
  final bool open;
  final String opensAt;
  final String closesAt;

  const OpeningHours({
    required this.open,
    required this.opensAt,
    required this.closesAt,
  });

  factory OpeningHours.fromMap(Map<String, dynamic>? data) {
    return OpeningHours(
      open: data?['open'] as bool? ?? false,
      opensAt: data?['opensAt'] as String? ?? '09:00',
      closesAt: data?['closesAt'] as String? ?? '18:00',
    );
  }

  Map<String, dynamic> toMap() {
    return {'open': open, 'opensAt': opensAt, 'closesAt': closesAt};
  }
}

const Map<String, OpeningHours> kDefaultOpeningHours = {
  'monday': OpeningHours(open: true, opensAt: '09:00', closesAt: '18:00'),
  'tuesday': OpeningHours(open: true, opensAt: '09:00', closesAt: '18:00'),
  'wednesday': OpeningHours(open: true, opensAt: '09:00', closesAt: '18:00'),
  'thursday': OpeningHours(open: true, opensAt: '09:00', closesAt: '18:00'),
  'friday': OpeningHours(open: true, opensAt: '09:00', closesAt: '18:00'),
  'saturday': OpeningHours(open: true, opensAt: '10:00', closesAt: '18:00'),
  'sunday': OpeningHours(open: false, opensAt: '10:00', closesAt: '18:00'),
};

String iconKeyFor(IconData icon) {
  return kRestaurantIcons.entries
      .firstWhere(
        (e) => e.value == icon,
        orElse: () => const MapEntry('store', Icons.storefront),
      )
      .key;
}

class Restaurant {
  final String id;
  final String name;
  final String cuisine;
  final String category;
  final String description;
  final String phone;
  final String email;
  final String website;
  final double distanceKm;
  final int rewardThreshold;
  final String rewardLabel;
  final String rewardDescription;
  final int pointsPerVisit;
  final bool loyaltyProgramEnabled;
  final LoyaltyProgramType loyaltyProgramType;
  final IconData icon;
  final double latitude;
  final double longitude;
  final String? logoUrl;
  final String? coverImageUrl;
  final List<String> galleryUrls;
  final String? address;
  final String postalCode;
  final String city;
  final String country;
  final double rating;
  final int reviewCount;
  final bool active;
  final double validationRadiusMeters;
  final bool requireLocationForCheckIn;
  final VisitValidationPolicy validationPolicy;
  final int minimumHoursBetweenVisits;
  final String? ownerId;
  final RestaurantStatus status;
  final Map<String, OpeningHours> openingHours;

  const Restaurant({
    required this.id,
    required this.name,
    required this.cuisine,
    this.category = 'Restaurant',
    this.description = '',
    this.phone = '',
    this.email = '',
    this.website = '',
    required this.distanceKm,
    required this.rewardThreshold,
    required this.rewardLabel,
    this.rewardDescription = '',
    required this.icon,
    this.pointsPerVisit = 350,
    this.loyaltyProgramEnabled = true,
    this.loyaltyProgramType = LoyaltyProgramType.visits,
    // Paris (place de la Concorde) par défaut : garantit que chaque
    // restaurant a une position affichable sur la carte même si le
    // commerçant n'a pas encore renseigné son adresse exacte.
    this.latitude = 48.8656,
    this.longitude = 2.3212,
    this.logoUrl,
    this.coverImageUrl,
    this.galleryUrls = const [],
    this.address,
    this.postalCode = '',
    this.city = '',
    this.country = 'France',
    this.rating = 4.8,
    this.reviewCount = 230,
    this.active = true,
    this.validationRadiusMeters = 75,
    this.requireLocationForCheckIn = false,
    this.validationPolicy = VisitValidationPolicy.oncePerDay,
    this.minimumHoursBetweenVisits = 4,
    this.ownerId,
    this.status = RestaurantStatus.active,
    this.openingHours = kDefaultOpeningHours,
  });

  factory Restaurant.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Restaurant(
      id: doc.id,
      name: data['name'] as String? ?? '',
      cuisine: data['cuisine'] as String? ?? '',
      category:
          data['category'] as String? ?? data['cuisine'] as String? ?? 'Autre',
      description: data['description'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      email: data['email'] as String? ?? '',
      website: data['website'] as String? ?? '',
      distanceKm: (data['distanceKm'] as num?)?.toDouble() ?? 0,
      rewardThreshold: data['rewardThreshold'] as int? ?? 10,
      rewardLabel: data['rewardLabel'] as String? ?? '',
      rewardDescription: data['rewardDescription'] as String? ?? '',
      pointsPerVisit: data['pointsPerVisit'] as int? ?? 350,
      loyaltyProgramEnabled: data['loyaltyProgramEnabled'] as bool? ?? true,
      loyaltyProgramType: LoyaltyProgramTypeX.fromFirestore(
        data['loyaltyProgramType'] as String?,
      ),
      icon:
          kRestaurantIcons[data['iconKey'] as String? ?? 'store'] ??
          Icons.storefront,
      latitude: (data['latitude'] as num?)?.toDouble() ?? 48.8656,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 2.3212,
      logoUrl: data['logoUrl'] as String?,
      coverImageUrl: data['coverImageUrl'] as String?,
      galleryUrls:
          (data['galleryUrls'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const [],
      address: data['address'] as String?,
      postalCode: data['postalCode'] as String? ?? '',
      city: data['city'] as String? ?? '',
      country: data['country'] as String? ?? 'France',
      rating: (data['rating'] as num?)?.toDouble() ?? 4.8,
      reviewCount: (data['reviewCount'] as num?)?.toInt() ?? 230,
      active: data['active'] as bool? ?? true,
      validationRadiusMeters:
          (data['validationRadiusMeters'] as num?)?.toDouble() ?? 75,
      requireLocationForCheckIn:
          data['requireLocationForCheckIn'] as bool? ?? false,
      validationPolicy: VisitValidationPolicyX.fromFirestore(
        data['validationPolicy'] as String?,
      ),
      minimumHoursBetweenVisits:
          (data['minimumHoursBetweenVisits'] as num?)?.toInt() ?? 4,
      ownerId: data['ownerId'] as String?,
      status: RestaurantStatusX.fromFirestore(data['status'] as String?),
      openingHours: _openingHoursFromFirestore(data['openingHours']),
    );
  }

  Restaurant copyWith({
    String? name,
    String? cuisine,
    String? category,
    String? description,
    String? phone,
    String? email,
    String? website,
    String? address,
    String? postalCode,
    String? city,
    String? country,
    int? rewardThreshold,
    String? rewardLabel,
    String? rewardDescription,
    int? pointsPerVisit,
    bool? loyaltyProgramEnabled,
    LoyaltyProgramType? loyaltyProgramType,
    double? latitude,
    double? longitude,
    String? logoUrl,
    String? coverImageUrl,
    List<String>? galleryUrls,
    bool? active,
    VisitValidationPolicy? validationPolicy,
    int? minimumHoursBetweenVisits,
    RestaurantStatus? status,
    String? ownerId,
    Map<String, OpeningHours>? openingHours,
  }) {
    return Restaurant(
      id: id,
      name: name ?? this.name,
      cuisine: cuisine ?? this.cuisine,
      category: category ?? this.category,
      description: description ?? this.description,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      distanceKm: distanceKm,
      rewardThreshold: rewardThreshold ?? this.rewardThreshold,
      rewardLabel: rewardLabel ?? this.rewardLabel,
      rewardDescription: rewardDescription ?? this.rewardDescription,
      pointsPerVisit: pointsPerVisit ?? this.pointsPerVisit,
      loyaltyProgramEnabled:
          loyaltyProgramEnabled ?? this.loyaltyProgramEnabled,
      loyaltyProgramType: loyaltyProgramType ?? this.loyaltyProgramType,
      icon: icon,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      logoUrl: logoUrl ?? this.logoUrl,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      galleryUrls: galleryUrls ?? this.galleryUrls,
      address: address ?? this.address,
      postalCode: postalCode ?? this.postalCode,
      city: city ?? this.city,
      country: country ?? this.country,
      rating: rating,
      reviewCount: reviewCount,
      active: active ?? this.active,
      validationRadiusMeters: validationRadiusMeters,
      requireLocationForCheckIn: requireLocationForCheckIn,
      validationPolicy: validationPolicy ?? this.validationPolicy,
      minimumHoursBetweenVisits:
          minimumHoursBetweenVisits ?? this.minimumHoursBetweenVisits,
      ownerId: ownerId ?? this.ownerId,
      status: status ?? this.status,
      openingHours: openingHours ?? this.openingHours,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'cuisine': cuisine,
      'category': category,
      'description': description,
      'phone': phone,
      'email': email,
      'website': website,
      'distanceKm': distanceKm,
      'rewardThreshold': rewardThreshold,
      'rewardLabel': rewardLabel,
      'rewardDescription': rewardDescription,
      'pointsPerVisit': pointsPerVisit,
      'loyaltyProgramEnabled': loyaltyProgramEnabled,
      'loyaltyProgramType': loyaltyProgramType.firestoreValue,
      'iconKey': iconKeyFor(icon),
      'latitude': latitude,
      'longitude': longitude,
      if (logoUrl != null) 'logoUrl': logoUrl,
      if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
      'galleryUrls': galleryUrls,
      if (address != null) 'address': address,
      'postalCode': postalCode,
      'city': city,
      'country': country,
      'rating': rating,
      'reviewCount': reviewCount,
      'active': active,
      'validationRadiusMeters': validationRadiusMeters,
      'requireLocationForCheckIn': requireLocationForCheckIn,
      'validationPolicy': validationPolicy.firestoreValue,
      'minimumHoursBetweenVisits': minimumHoursBetweenVisits,
      if (ownerId != null) 'ownerId': ownerId,
      'status': status.firestoreValue,
      'openingHours': openingHours.map(
        (day, hours) => MapEntry(day, hours.toMap()),
      ),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static Map<String, OpeningHours> _openingHoursFromFirestore(dynamic data) {
    if (data is! Map<String, dynamic>) return kDefaultOpeningHours;
    return {
      for (final day in kDefaultOpeningHours.keys)
        day: OpeningHours.fromMap(data[day] as Map<String, dynamic>?),
    };
  }
}
