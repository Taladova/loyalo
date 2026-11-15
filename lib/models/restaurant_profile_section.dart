import 'restaurant.dart';

enum RestaurantProfileSection { general, address, hours, photos, visibility }

extension RestaurantProfileSectionX on RestaurantProfileSection {
  String get title => switch (this) {
    RestaurantProfileSection.general => 'Informations générales',
    RestaurantProfileSection.address => 'Adresse et localisation',
    RestaurantProfileSection.hours => 'Horaires d’ouverture',
    RestaurantProfileSection.photos => 'Photos et identité visuelle',
    RestaurantProfileSection.visibility => 'Visibilité du commerce',
  };

  Set<String> get fields => switch (this) {
    RestaurantProfileSection.general => {
      'name',
      'category',
      'cuisine',
      'description',
      'phone',
      'email',
      'website',
    },
    RestaurantProfileSection.address => {
      'address',
      'postalCode',
      'city',
      'country',
    },
    RestaurantProfileSection.hours => {
      for (final day in kDefaultOpeningHours.keys) 'openingHours.$day',
    },
    RestaurantProfileSection.photos => {
      'logoUrl',
      'coverImageUrl',
      'galleryUrls',
    },
    RestaurantProfileSection.visibility => {'active'},
  };
}

Map<String, dynamic> restaurantProfileValues(Restaurant restaurant) {
  final values = restaurant.toMap()..remove('updatedAt');
  return {
    ...values,
    'logoUrl': restaurant.logoUrl?.isNotEmpty == true
        ? restaurant.logoUrl
        : null,
    'coverImageUrl': restaurant.coverImageUrl?.isNotEmpty == true
        ? restaurant.coverImageUrl
        : null,
    for (final entry in restaurant.openingHours.entries)
      'openingHours.${entry.key}': entry.value.toMap(),
  };
}

bool profileValueEquals(Object? a, Object? b) {
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every(
          (key) => b.containsKey(key) && profileValueEquals(a[key], b[key]),
        );
  }
  if (a is List && b is List) {
    return a.length == b.length &&
        List.generate(
          a.length,
          (i) => i,
        ).every((i) => profileValueEquals(a[i], b[i]));
  }
  return a == b;
}

String? validateEstablishmentEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return null;
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
      ? null
      : 'Email invalide';
}

String? validateEstablishmentWebsite(String? value) {
  final website = value?.trim() ?? '';
  if (website.isEmpty) return null;
  return website.contains('.') && !website.contains(' ')
      ? null
      : 'Site invalide';
}
