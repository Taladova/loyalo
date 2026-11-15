import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/restaurant.dart';
import '../../models/restaurant_profile_section.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/loyalo_auth_ui.dart';
import '../../widgets/loyalo_establishment_ui.dart';
import '../../widgets/loyalo_ui.dart';
import '../client/restaurant_detail_screen.dart';
import 'merchant_establishment_section_screen.dart';
import 'merchant_establishment_setup_screen.dart';
import 'offers_management_screen.dart';
import 'rewards_management_screen.dart';

class MerchantEstablishmentScreen extends ConsumerStatefulWidget {
  const MerchantEstablishmentScreen({super.key, this.requireSetup = false});
  final bool requireSetup;

  @override
  ConsumerState<MerchantEstablishmentScreen> createState() =>
      _MerchantEstablishmentScreenState();
}

class _MerchantEstablishmentScreenState
    extends ConsumerState<MerchantEstablishmentScreen> {
  bool _retrying = false;
  String? _retryError;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() {
      _retrying = true;
      _retryError = null;
    });
    try {
      await ref.read(loyaltyRepositoryProvider).retryRestaurants();
    } catch (_) {
      if (mounted) {
        setState(() => _retryError = 'Impossible de recharger votre commerce.');
      }
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(loyaltyRepositoryProvider);
    final id = ref.watch(currentMerchantRestaurantIdProvider);
    final restaurant = id == null ? null : repo.restaurantByIdOrNull(id);
    if (widget.requireSetup && id == null) {
      return const MerchantEstablishmentSetupScreen(requireSetup: true);
    }
    if (id == null || restaurant == null) {
      final loading = id != null && repo.restaurantsLoading;
      return LoyaloEstablishmentFrame(
        title: 'Mon établissement',
        onBack: () => Navigator.of(context).maybePop(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EstablishmentMessage(
              loading: loading,
              error: !loading,
              message: id == null
                  ? 'Votre session commerçant est indisponible. Reconnectez-vous.'
                  : loading
                  ? 'Chargement de votre établissement…'
                  : _retryError ??
                        (repo.restaurantsLoadError != null
                            ? 'Impossible de charger votre établissement.'
                            : 'Votre établissement est indisponible pour le moment.'),
            ),
            if (id != null && !loading) ...[
              const SizedBox(height: 12),
              LoyaloAuthPrimaryButton(
                label: 'Réessayer',
                loading: _retrying,
                onPressed: _retrying ? null : _retry,
              ),
            ],
          ],
        ),
      );
    }
    final r = restaurant;
    void activity(Widget screen) => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => screen));
    return LoyaloEstablishmentFrame(
      title: 'Mon établissement',
      onBack: () => Navigator.of(context).maybePop(),
      onPublicProfile: () => activity(RestaurantDetailScreen(restaurant: r)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EstablishmentCard(restaurant: r),
          const SizedBox(height: 12),
          EstablishmentConfiguration(restaurant: r),
          const SizedBox(height: 14),
          if (repo.restaurantsLoadError != null) ...[
            const LoyaloAuthError(
              message:
                  'Actualisation impossible. Les informations déjà chargées restent affichées.',
            ),
            const SizedBox(height: 12),
          ],
          for (final section in RestaurantProfileSection.values) ...[
            LoyaloEstablishmentTile(
              key: ValueKey('establishment-section-${section.name}'),
              title: section.title,
              description: switch (section) {
                RestaurantProfileSection.general =>
                  'Nom, catégorie, description et coordonnées',
                RestaurantProfileSection.address =>
                  'Adresse, code postal, ville et pays',
                RestaurantProfileSection.hours =>
                  'Jours et plage horaire de chaque jour',
                RestaurantProfileSection.photos =>
                  'Logo, photo principale et galerie (${r.galleryUrls.length}/8)',
                RestaurantProfileSection.visibility =>
                  'Statut et conditions de publication',
              },
              icon: switch (section) {
                RestaurantProfileSection.general => Icons.storefront_outlined,
                RestaurantProfileSection.address => Icons.location_on_outlined,
                RestaurantProfileSection.hours => Icons.schedule,
                RestaurantProfileSection.photos => Icons.photo_library_outlined,
                RestaurantProfileSection.visibility =>
                  Icons.verified_user_outlined,
              },
              color: switch (section) {
                RestaurantProfileSection.address => AppColors.blue,
                RestaurantProfileSection.hours => AppColors.orange,
                RestaurantProfileSection.photos => AppColors.teal,
                _ => AppColors.purple,
              },
              onTap: () => activity(
                MerchantEstablishmentSectionScreen(
                  restaurant: r,
                  section: section,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
          Semantics(
            header: true,
            child: const Text(
              'Gérer mon activité',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 12),
          LoyaloEstablishmentTile(
            key: const Key('establishment-loyalty'),
            title: 'Programme de fidélité',
            description: 'Configurer les visites, points et récompenses',
            icon: Icons.card_giftcard_outlined,
            onTap: () => activity(
              RewardsManagementScreen(completeOnboarding: r.needsLoyaltySetup),
            ),
          ),
          const SizedBox(height: 10),
          LoyaloEstablishmentTile(
            key: const Key('establishment-offers'),
            title: 'Offres exclusives',
            description: 'Créer et gérer des offres temporaires',
            icon: Icons.local_offer_outlined,
            color: AppColors.blue,
            onTap: () => activity(const OffersManagementScreen()),
          ),
        ],
      ),
    );
  }
}

class _EstablishmentCard extends StatelessWidget {
  const _EstablishmentCard({required this.restaurant});
  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    final status = EstablishmentStatus.of(r);
    final identity = Row(
      children: [
        LoyaloMerchantAvatar(imageUrl: r.logoUrl, icon: r.icon, size: 54),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                r.category.isEmpty ? r.cuisine : r.category,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              if (r.city.trim().isNotEmpty) ...[
                const SizedBox(height: 5),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        r.city,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        status.label,
        key: const Key('establishment-status'),
        style: TextStyle(
          color: status.color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    return Container(
      key: const Key('establishment-identity'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF153756), Color(0xFF233C96), Color(0xFF7100B9)],
        ),
        border: Border.all(
          color: LoyaloAuthColors.turquoise.withValues(alpha: 0.4),
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 430 &&
              MediaQuery.textScalerOf(context).scale(14) <= 19) {
            return Row(
              children: [
                Expanded(child: identity),
                const SizedBox(width: 12),
                badge,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              identity,
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerRight, child: badge),
            ],
          );
        },
      ),
    );
  }
}
