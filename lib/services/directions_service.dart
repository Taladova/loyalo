import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/restaurant.dart';

typedef DirectionsUriLauncher = Future<bool> Function(Uri uri);

class DirectionsService {
  static const _fallbackLatitude = 48.8656;
  static const _fallbackLongitude = 2.3212;

  final DirectionsUriLauncher _launch;

  DirectionsService({DirectionsUriLauncher? launcher})
    : _launch = launcher ?? _launchExternally;

  static Future<bool> _launchExternally(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String? destinationFor(Restaurant restaurant) {
    if (_hasValidCoordinates(restaurant)) {
      return '${restaurant.latitude},${restaurant.longitude}';
    }

    final address = restaurant.address?.trim();
    if (address == null || address.isEmpty) return null;
    return '${restaurant.name}, $address';
  }

  List<Uri> candidateUris(
    Restaurant restaurant, {
    required TargetPlatform platform,
  }) {
    final destination = destinationFor(restaurant);
    if (destination == null) return const [];

    final webUri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': destination,
    });

    return switch (platform) {
      TargetPlatform.iOS => [
        Uri(
          scheme: 'comgooglemaps',
          queryParameters: {'daddr': destination, 'directionsmode': 'driving'},
        ),
        Uri.https('maps.apple.com', '/', {'daddr': destination, 'dirflg': 'd'}),
        webUri,
      ],
      TargetPlatform.android => [
        Uri(scheme: 'google.navigation', queryParameters: {'q': destination}),
        Uri(scheme: 'geo', path: '0,0', queryParameters: {'q': destination}),
        webUri,
      ],
      _ => [webUri],
    };
  }

  Future<bool> openDirections(
    Restaurant restaurant, {
    required TargetPlatform platform,
  }) async {
    for (final uri in candidateUris(restaurant, platform: platform)) {
      try {
        if (await _launch(uri)) return true;
      } catch (_) {
        // Continue avec la solution cartographique suivante.
      }
    }
    return false;
  }

  bool _hasValidCoordinates(Restaurant restaurant) {
    final latitude = restaurant.latitude;
    final longitude = restaurant.longitude;
    if (!latitude.isFinite || !longitude.isFinite) return false;
    if (latitude < -90 || latitude > 90) return false;
    if (longitude < -180 || longitude > 180) return false;
    if (latitude == 0 && longitude == 0) return false;

    // Le modèle historique injecte cette position parisienne en l'absence de
    // coordonnées. Elle ne doit jamais devenir une destination d'itinéraire.
    return latitude != _fallbackLatitude || longitude != _fallbackLongitude;
  }
}
