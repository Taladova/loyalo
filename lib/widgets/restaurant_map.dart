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
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _loading = false);
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
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
    final text = AppTheme.textOf(context);
    final muted = AppTheme.mutedOf(context);
    final surface = AppTheme.surfaceOf(context);
    final border = AppTheme.borderOf(context);
    final restaurantPoint = LatLng(
      widget.restaurant.latitude,
      widget.restaurant.longitude,
    );
    double? distanceKm;
    if (_userPosition != null) {
      distanceKm =
          Geolocator.distanceBetween(
            _userPosition!.latitude,
            _userPosition!.longitude,
            widget.restaurant.latitude,
            widget.restaurant.longitude,
          ) /
          1000;
    }
    final hasReliableDistance = distanceKm != null && distanceKm <= 100;
    final distanceLabel = hasReliableDistance
        ? (distanceKm < 1
              ? '${(distanceKm * 1000).round()} m de vous'
              : '${distanceKm.toStringAsFixed(1)} km de vous')
        : _loading
        ? 'Calcul de la distance...'
        : 'Distance indisponible';

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: AppTheme.isDark(context) ? 0.18 : 0.06,
            ),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: SizedBox(
              height: 190,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: restaurantPoint,
                      initialZoom: 14.5,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.loyalo.app',
                      ),
                      if (_userPosition != null && hasReliableDistance)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: [
                                restaurantPoint,
                                LatLng(
                                  _userPosition!.latitude,
                                  _userPosition!.longitude,
                                ),
                              ],
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
                            width: 48,
                            height: 48,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: AppColors.brandGradient,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.purple.withValues(
                                      alpha: 0.26,
                                    ),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.storefront_outlined,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                          if (_userPosition != null && hasReliableDistance)
                            Marker(
                              point: LatLng(
                                _userPosition!.latitude,
                                _userPosition!.longitude,
                              ),
                              width: 22,
                              height: 22,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.blue,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_outlined,
                            color: AppColors.teal,
                            size: 15,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Commerce partenaire',
                            style: TextStyle(
                              color: AppColors.textDark,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_loading)
                    const Positioned(
                      right: 14,
                      top: 14,
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.purple,
                        ),
                      ),
                    ),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Column(
                      children: [
                        _ZoomButton(icon: Icons.add, onTap: () => _zoomBy(1)),
                        const SizedBox(height: 8),
                        _ZoomButton(
                          icon: Icons.remove,
                          onTap: () => _zoomBy(-1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    hasReliableDistance
                        ? Icons.near_me_outlined
                        : Icons.location_off_outlined,
                    color: hasReliableDistance ? AppColors.teal : muted,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.restaurant.address ??
                            'Adresse du commerce partenaire',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: text,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        distanceLabel,
                        style: TextStyle(color: muted, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, size: 19, color: AppColors.textDark),
        ),
      ),
    );
  }
}
