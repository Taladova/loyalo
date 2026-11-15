import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/restaurant.dart';
import '../theme/app_theme.dart';
import 'loyalo_auth_ui.dart';
import 'loyalo_page_header.dart';
import 'loyalo_ui.dart';

class LoyaloEstablishmentFrame extends StatelessWidget {
  const LoyaloEstablishmentFrame({
    super.key,
    required this.title,
    required this.child,
    required this.onBack,
    this.onPublicProfile,
  });
  final String title;
  final Widget child;
  final VoidCallback? onBack;
  final VoidCallback? onPublicProfile;

  @override
  Widget build(BuildContext context) => LoyaloAuthScaffold(
    showBackButton: false,
    onBack: onBack,
    headerBuilder: (context, compact, veryCompact) => Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LoyaloPageHeader(
            title: title,
            centerTitle: false,
            showBackButton: true,
            onBack: onBack,
          ),
          if (onPublicProfile != null) ...[
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) => Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: math.min(248, constraints.maxWidth),
                  child: OutlinedButton(
                    key: const Key('establishment-public'),
                    onPressed: onPublicProfile,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: LoyaloAuthColors.turquoise),
                      minimumSize: const Size(48, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.open_in_new, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Voir ma fiche publique',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
    contentBuilder: (context, compact) => child,
  );
}

class LoyaloEstablishmentTile extends StatelessWidget {
  const LoyaloEstablishmentTile({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
    this.color = AppColors.purple,
  });
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => LoyaloCard(
    padding: EdgeInsets.zero,
    color: Colors.white,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            ExcludeSemantics(
              child: LoyaloIconBadge(icon: icon, color: color, size: 40),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: LoyaloAuthColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      color: LoyaloAuthColors.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const ExcludeSemantics(
              child: Icon(
                Icons.chevron_right,
                color: LoyaloAuthColors.textPrimary,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class EstablishmentStatus {
  const EstablishmentStatus(this.label, this.color);
  final String label;
  final Color color;

  factory EstablishmentStatus.of(Restaurant r) => switch (r.status) {
    RestaurantStatus.pendingReview => const EstablishmentStatus(
      'En attente',
      Color(0xFF986500),
    ),
    RestaurantStatus.suspended => const EstablishmentStatus(
      'Commerce suspendu',
      Color(0xFFB91C1C),
    ),
    _ =>
      r.active && r.status == RestaurantStatus.active
          ? const EstablishmentStatus('Commerce actif', Color(0xFF007A4C))
          : const EstablishmentStatus('Commerce inactif', Color(0xFF475569)),
  };
}

class EstablishmentConfiguration extends StatelessWidget {
  const EstablishmentConfiguration({super.key, required this.restaurant});
  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    final items = <(String, bool)>[
      (
        'Nom et catégorie',
        r.name.trim().isNotEmpty && r.cuisine.trim().isNotEmpty,
      ),
      (
        'Adresse et ville',
        (r.address?.trim().isNotEmpty ?? false) && r.city.trim().isNotEmpty,
      ),
      ('Horaires enregistrés', r.hasSavedOpeningHours),
      (
        'Au moins une photo',
        (r.logoUrl?.isNotEmpty ?? false) ||
            (r.coverImageUrl?.isNotEmpty ?? false) ||
            r.galleryUrls.isNotEmpty,
      ),
      (
        'Programme de fidélité',
        r.loyaltyProgramEnabled &&
            r.rewardThreshold > 0 &&
            r.pointsPerVisit > 0 &&
            r.rewardLabel.trim().isNotEmpty,
      ),
    ];
    final count = items.where((item) => item.$2).length;
    return LoyaloCard(
      key: const Key('establishment-configuration'),
      color: const Color(0xFFEBFCF7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            children: [
              const Text(
                'Configuration du commerce',
                style: TextStyle(
                  color: LoyaloAuthColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '$count sur 5 renseignés',
                key: const Key('establishment-progress-label'),
                style: const TextStyle(
                  color: LoyaloAuthColors.textPrimary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: count / 5,
            minHeight: 8,
            borderRadius: BorderRadius.circular(12),
            backgroundColor: const Color(0xFFDCE3F0),
            color: const Color(0xFF00AC83),
            semanticsLabel:
                'Configuration du commerce, $count éléments sur 5 renseignés',
          ),
          const SizedBox(height: 12),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    item.$2 ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 18,
                    color: item.$2
                        ? const Color(0xFF00A778)
                        : LoyaloAuthColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.$1,
                      style: const TextStyle(
                        color: LoyaloAuthColors.textPrimary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          const Text(
            'L’adresse, les horaires et les photos sont facultatifs. Ces repères décrivent les informations présentes, pas une autorisation de publication.',
            style: TextStyle(
              color: LoyaloAuthColors.textSecondary,
              fontSize: 11,
              height: 1.4,
            ),
          ),
          if (r.needsLoyaltySetup) ...[
            const SizedBox(height: 8),
            const Text(
              'Pour publier ce brouillon, terminez la configuration du programme de fidélité.',
              style: TextStyle(
                color: LoyaloAuthColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class EstablishmentMessage extends StatelessWidget {
  const EstablishmentMessage({
    super.key,
    required this.message,
    this.loading = false,
    this.error = false,
  });
  final String message;
  final bool loading;
  final bool error;

  @override
  Widget build(BuildContext context) => LoyaloCard(
    color: Colors.white,
    child: Semantics(
      liveRegion: true,
      child: Column(
        children: [
          if (loading)
            const CircularProgressIndicator()
          else
            Icon(
              error ? Icons.error_outline : Icons.check_circle_outline,
              color: error ? AppColors.danger : const Color(0xFF00875F),
            ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: LoyaloAuthColors.textPrimary,
              height: 1.4,
            ),
          ),
        ],
      ),
    ),
  );
}
