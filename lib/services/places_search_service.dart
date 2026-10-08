import 'dart:convert';

import 'package:http/http.dart' as http;

class PlaceResult {
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String? imageUrl;

  const PlaceResult({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.imageUrl,
  });
}

/// Recherche de vrais lieux via Nominatim (OpenStreetMap) — gratuit, sans
/// clé API, cohérent avec la carte déjà utilisée dans l'app
/// ([RestaurantMap]). Un en-tête `User-Agent` explicite est requis par la
/// politique d'usage de Nominatim.
class PlacesSearchService {
  static const _endpoint = 'https://nominatim.openstreetmap.org/search';

  Future<List<PlaceResult>> search(
    String query, {
    double? nearLat,
    double? nearLng,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final params = {
      'q': trimmed,
      'format': 'jsonv2',
      'addressdetails': '1',
      'limit': '8',
    };
    if (nearLat != null && nearLng != null) {
      // Cadre de recherche large autour de la position, pour prioriser les
      // résultats proches sans exclure le reste.
      params['viewbox'] =
          '${nearLng - 0.3},${nearLat + 0.3},${nearLng + 0.3},${nearLat - 0.3}';
      params['bounded'] = '0';
    }

    final uri = Uri.parse(_endpoint).replace(queryParameters: params);
    final response = await http.get(
      uri,
      headers: {'User-Agent': 'LoyaloApp/1.0 (contact@taladova.com)'},
    );

    if (response.statusCode != 200) return [];

    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded.map((raw) {
      final item = raw as Map<String, dynamic>;
      return PlaceResult(
        name: (item['name'] as String?)?.isNotEmpty == true
            ? item['name'] as String
            : (item['display_name'] as String? ?? '').split(',').first,
        address: item['display_name'] as String? ?? '',
        latitude: double.tryParse(item['lat'] as String? ?? '') ?? 0,
        longitude: double.tryParse(item['lon'] as String? ?? '') ?? 0,
      );
    }).toList();
  }
}
