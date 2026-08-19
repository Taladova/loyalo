import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/restaurant.dart';
import '../theme/app_theme.dart';

/// Petite carte OpenStreetMap montrant l'emplacement d'un restaurant, avec
/// la position de l'utilisateur si la géolocalisation est autorisée.
class RestaurantMap extends StatefulWidget {
  final Restaurant restaurant;

  const RestaurantMap({super.key, required this.restaurant});

  @override
  State<RestaurantMap> createState() => _RestaurantMapState();
}

class _RestaurantMapState extends State<RestaurantMap> {
  final MapController _mapController = MapController();
  Position? _userPosition;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _locateUser();
  }

  void _zoomBy(double delta) {
    final camera = _mapController.camera;
    _mapController.move(camera.center, (camera.zoom + delta).clamp(3.0, 18.0));
  }

  Future<void> _locateUser() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() => _loading = false);
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() => _loading = false);
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      if (!mounted) return;
      setState(() {
        _userPosition = position;
        _loading = false;
      });
    } catch (_) {
      // Pas de position dispo (permission refusée, service coupé, simulateur
      // sans localisation...) : on affiche simplement la carte sans marqueur
      // utilisateur plutôt que de bloquer l'écran.
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final restaurantPoint = LatLng(widget.restaurant.latitude, widget.restaurant.longitude);
    double? distanceKm;
    if (_userPosition != null) {
      distanceKm = Geolocator.distanceBetween(
            _userPosition!.latitude,
            _userPosition!.longitude,
            widget.restaurant.latitude,
            widget.restaurant.longitude,
          ) /
          1000;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 180,
            decoration: BoxDecoration(border: Border.all(color: AppColors.border)),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(initialCenter: restaurantPoint, initialZoom: 14.5),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.loyalo.app',
                    ),
                    if (_userPosition != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [restaurantPoint, LatLng(_userPosition!.latitude, _userPosition!.longitude)],
                            color: AppColors.purple.withValues(alpha: 0.6),
                            strokeWidth: 3,
                            pattern: const StrokePattern.dotted(),
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: restaurantPoint,
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.location_pin, color: AppColors.purple, size: 40),
                        ),
                        if (_userPosition != null)
                          Marker(
                            point: LatLng(_userPosition!.latitude, _userPosition!.longitude),
                            width: 20,
                            height: 20,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.blue,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.5),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                if (_loading)
                  const Positioned(
                    right: 10,
                    top: 10,
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.purple),
                    ),
                  ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Column(
                    children: [
                      _ZoomButton(icon: Icons.add, onTap: () => _zoomBy(1)),
                      const SizedBox(height: 6),
                      _ZoomButton(icon: Icons.remove, onTap: () => _zoomBy(-1)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          distanceKm != null
              ? 'À ${distanceKm.toStringAsFixed(1)} km de votre position'
              : 'Activez la localisation pour voir votre distance',
          style: const TextStyle(fontSize: 12, color: AppColors.textGray),
        ),
      ],
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ZoomButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16, color: AppColors.textDark),
        ),
      ),
    );
  }
}
