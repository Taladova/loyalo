import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loyalo/models/restaurant.dart';
import 'package:loyalo/services/directions_service.dart';

void main() {
  Restaurant restaurant({
    double latitude = 48.1127,
    double longitude = -1.6833,
    String? address = '8 place des Lices, 35000 Rennes',
    String name = 'Le Bistrot Rennais',
  }) {
    return Restaurant(
      id: 'restaurant-1',
      name: name,
      cuisine: 'Française',
      distanceKm: 1,
      rewardThreshold: 10,
      rewardLabel: 'Dessert offert',
      icon: Icons.restaurant,
      latitude: latitude,
      longitude: longitude,
      address: address,
    );
  }

  group('DirectionsService', () {
    test('utilise les coordonnées valides en priorité', () {
      final service = DirectionsService();

      expect(service.destinationFor(restaurant()), '48.1127,-1.6833');
    });

    test('utilise la vraie adresse lorsque les coordonnées sont invalides', () {
      final service = DirectionsService();

      expect(
        service.destinationFor(restaurant(latitude: 0, longitude: 0)),
        'Le Bistrot Rennais, 8 place des Lices, 35000 Rennes',
      );
    });

    test('encode correctement espaces accents et apostrophes', () {
      final service = DirectionsService();
      final uri = service
          .candidateUris(
            restaurant(
              latitude: 0,
              longitude: 0,
              name: 'L’Étage',
              address: '3 rue de l’Été, Rennes',
            ),
            platform: TargetPlatform.android,
          )
          .last;

      expect(
        uri.queryParameters['destination'],
        'L’Étage, 3 rue de l’Été, Rennes',
      );
      expect(uri.toString(), isNot(contains(' ')));
      expect(uri.toString(), contains('%C3%89'));
    });

    test('n’utilise aucune adresse fictive sans destination réelle', () {
      final service = DirectionsService();
      final destination = service.destinationFor(
        restaurant(latitude: 48.8656, longitude: 2.3212, address: null),
      );

      expect(destination, isNull);
    });

    test('essaie Google puis le fallback plateforme puis le web', () async {
      final attempted = <Uri>[];
      final service = DirectionsService(
        launcher: (uri) async {
          attempted.add(uri);
          return attempted.length == 3;
        },
      );

      final opened = await service.openDirections(
        restaurant(),
        platform: TargetPlatform.iOS,
      );

      expect(opened, isTrue);
      expect(attempted.map((uri) => uri.scheme), [
        'comgooglemaps',
        'https',
        'https',
      ]);
      expect(attempted[1].host, 'maps.apple.com');
      expect(attempted[2].host, 'www.google.com');
    });
  });
}
