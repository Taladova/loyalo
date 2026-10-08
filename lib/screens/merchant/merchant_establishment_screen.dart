import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/restaurant.dart';
import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';
import '../../services/merchant_image_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/loyalo_ui.dart';
import '../client/restaurant_detail_screen.dart';
import 'merchant_root_screen.dart';
import 'offers_management_screen.dart';
import 'rewards_management_screen.dart';

class MerchantEstablishmentScreen extends ConsumerStatefulWidget {
  final bool requireSetup;

  const MerchantEstablishmentScreen({super.key, this.requireSetup = false});

  @override
  ConsumerState<MerchantEstablishmentScreen> createState() =>
      _MerchantEstablishmentScreenState();
}

class _MerchantEstablishmentScreenState
    extends ConsumerState<MerchantEstablishmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _addressController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController(text: 'France');

  String _category = kRestaurantCategories.first;
  bool _active = true;
  bool _saving = false;
  bool _initialized = false;
  String? _uploadingImage;
  Map<String, OpeningHours> _openingHours = Map.of(kDefaultOpeningHours);

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _addressController.dispose();
    _postalCodeController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  void _fill(Restaurant? restaurant) {
    if (_initialized) return;
    _initialized = true;
    final userEmail = AuthService().currentUser?.email ?? '';
    if (restaurant == null) {
      _emailController.text = userEmail;
      return;
    }
    _nameController.text = restaurant.name;
    _category = kRestaurantCategories.contains(restaurant.category)
        ? restaurant.category
        : kRestaurantCategories.contains(restaurant.cuisine)
        ? restaurant.cuisine
        : 'Autre';
    _descriptionController.text = restaurant.description;
    _phoneController.text = restaurant.phone;
    _emailController.text = restaurant.email.isEmpty
        ? userEmail
        : restaurant.email;
    _websiteController.text = restaurant.website;
    _addressController.text = restaurant.address ?? '';
    _postalCodeController.text = restaurant.postalCode;
    _cityController.text = restaurant.city;
    _countryController.text = restaurant.country;
    _active = restaurant.active;
    _openingHours = Map.of(restaurant.openingHours);
  }

  Future<void> _save(Restaurant? existing) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final repo = ref.read(loyaltyRepositoryProvider);
    final uid = AuthService().currentUser!.uid;
    final name = _nameController.text.trim();
    final category = _category;
    final address = _addressController.text.trim();

    try {
      if (existing == null) {
        final restaurantId = await repo.createRestaurant(
          ownerId: uid,
          name: name,
          cuisine: category,
          rewardThreshold: 10,
          rewardLabel: 'Récompense fidélité',
          email: _emailController.text.trim(),
        );
        await repo.linkMerchantToRestaurant(uid, restaurantId);
        final created = Restaurant(
          id: restaurantId,
          ownerId: uid,
          name: name,
          cuisine: category,
          category: category,
          description: _descriptionController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim(),
          website: _websiteController.text.trim(),
          address: address,
          postalCode: _postalCodeController.text.trim(),
          city: _cityController.text.trim(),
          country: _countryController.text.trim().isEmpty
              ? 'France'
              : _countryController.text.trim(),
          distanceKm: 0,
          rewardThreshold: 10,
          rewardLabel: 'Récompense fidélité',
          icon: Icons.storefront,
          active: _active,
          status: _active ? RestaurantStatus.active : RestaurantStatus.draft,
          openingHours: _openingHours,
        );
        await repo.updateRestaurantProfile(restaurant: created, ownerId: uid);
        repo.stopListening();
        repo.startListeningForMerchant(restaurantId);
        ref.read(currentMerchantRestaurantIdProvider.notifier).state =
            restaurantId;
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MerchantRootScreen()),
          (route) => false,
        );
      } else {
        final updated = existing.copyWith(
          name: name,
          cuisine: category,
          category: category,
          description: _descriptionController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim(),
          website: _websiteController.text.trim(),
          address: address,
          postalCode: _postalCodeController.text.trim(),
          city: _cityController.text.trim(),
          country: _countryController.text.trim().isEmpty
              ? 'France'
              : _countryController.text.trim(),
          active: _active,
          status: _active ? RestaurantStatus.active : RestaurantStatus.draft,
          openingHours: _openingHours,
        );
        await repo.updateRestaurantProfile(restaurant: updated, ownerId: uid);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Établissement mis à jour.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Impossible d’enregistrer : $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _replaceImage(
    Restaurant restaurant,
    MerchantImageSlot slot,
  ) async {
    final key = slot.name;
    setState(() => _uploadingImage = key);
    final repo = ref.read(loyaltyRepositoryProvider);
    final imageService = ref.read(merchantImageServiceProvider);
    final uid = AuthService().currentUser!.uid;
    final previousUrl = switch (slot) {
      MerchantImageSlot.logo => restaurant.logoUrl,
      MerchantImageSlot.cover => restaurant.coverImageUrl,
      MerchantImageSlot.gallery => null,
    };

    try {
      final upload = await imageService.pickAndUpload(
        merchantId: uid,
        slot: slot,
      );
      if (upload == null) return;

      if (slot == MerchantImageSlot.logo) {
        await repo.updateRestaurantImages(
          restaurantId: restaurant.id,
          ownerId: uid,
          logoUrl: upload.downloadUrl,
        );
      } else {
        await repo.updateRestaurantImages(
          restaurantId: restaurant.id,
          ownerId: uid,
          coverImageUrl: upload.downloadUrl,
        );
      }

      await _deleteStorageObjectSilently(previousUrl, upload.downloadUrl);
      if (!mounted) return;
      _showSnack(
        slot == MerchantImageSlot.logo
            ? 'Logo mis à jour.'
            : 'Photo de couverture mise à jour.',
      );
    } on MerchantImageException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('Impossible de mettre à jour l’image : $e');
    } finally {
      if (mounted) setState(() => _uploadingImage = null);
    }
  }

  Future<void> _removeImage(
    Restaurant restaurant,
    MerchantImageSlot slot,
  ) async {
    final key = slot.name;
    setState(() => _uploadingImage = key);
    final repo = ref.read(loyaltyRepositoryProvider);
    final uid = AuthService().currentUser!.uid;
    final url = slot == MerchantImageSlot.logo
        ? restaurant.logoUrl
        : restaurant.coverImageUrl;

    try {
      await repo.updateRestaurantImages(
        restaurantId: restaurant.id,
        ownerId: uid,
        clearLogo: slot == MerchantImageSlot.logo,
        clearCover: slot == MerchantImageSlot.cover,
      );
      await _deleteStorageObjectSilently(url, null);
      if (!mounted) return;
      _showSnack(
        slot == MerchantImageSlot.logo
            ? 'Logo supprimé.'
            : 'Photo de couverture supprimée.',
      );
    } catch (e) {
      _showSnack('Impossible de supprimer l’image : $e');
    } finally {
      if (mounted) setState(() => _uploadingImage = null);
    }
  }

  Future<void> _addGalleryImage(Restaurant restaurant) async {
    if (restaurant.galleryUrls.length >= MerchantImageService.galleryLimit) {
      _showSnack(
        'La galerie est limitée à ${MerchantImageService.galleryLimit} images.',
      );
      return;
    }

    setState(() => _uploadingImage = 'gallery');
    final repo = ref.read(loyaltyRepositoryProvider);
    final imageService = ref.read(merchantImageServiceProvider);
    final uid = AuthService().currentUser!.uid;

    try {
      final upload = await imageService.pickAndUpload(
        merchantId: uid,
        slot: MerchantImageSlot.gallery,
      );
      if (upload == null) return;

      await repo.updateRestaurantImages(
        restaurantId: restaurant.id,
        ownerId: uid,
        galleryUrls: [...restaurant.galleryUrls, upload.downloadUrl],
      );
      _showSnack('Photo ajoutée à la galerie.');
    } on MerchantImageException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('Impossible d’ajouter la photo : $e');
    } finally {
      if (mounted) setState(() => _uploadingImage = null);
    }
  }

  Future<void> _removeGalleryImage(Restaurant restaurant, String url) async {
    setState(() => _uploadingImage = url);
    final repo = ref.read(loyaltyRepositoryProvider);
    final uid = AuthService().currentUser!.uid;
    try {
      final nextGallery = restaurant.galleryUrls
          .where((u) => u != url)
          .toList();
      await repo.updateRestaurantImages(
        restaurantId: restaurant.id,
        ownerId: uid,
        galleryUrls: nextGallery,
      );
      await _deleteStorageObjectSilently(url, null);
      _showSnack('Photo supprimée de la galerie.');
    } catch (e) {
      _showSnack('Impossible de supprimer la photo : $e');
    } finally {
      if (mounted) setState(() => _uploadingImage = null);
    }
  }

  Future<void> _deleteStorageObjectSilently(
    String? oldUrl,
    String? newUrl,
  ) async {
    if (oldUrl == null || oldUrl.isEmpty || oldUrl == newUrl) return;
    try {
      await ref.read(merchantImageServiceProvider).deleteByUrl(oldUrl);
    } catch (_) {}
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(loyaltyRepositoryProvider);
    final restaurantId = ref.watch(currentMerchantRestaurantIdProvider);
    final restaurant = restaurantId == null
        ? null
        : repo.restaurantByIdOrNull(restaurantId);
    _fill(restaurant);

    final text = AppTheme.textOf(context);
    final muted = AppTheme.mutedOf(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon établissement'),
        actions: [
          if (restaurant != null)
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      RestaurantDetailScreen(restaurant: restaurant),
                ),
              ),
              child: const Text('Aperçu'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (restaurant == null) ...[
              LoyaloCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Configurez votre établissement',
                      style: TextStyle(
                        color: text,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Cette fiche sera utilisée côté client pour présenter votre commerce.',
                      style: TextStyle(color: muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            _SectionTitle('Informations générales'),
            LoyaloCard(
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom du commerce',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Nom obligatoire'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Catégorie'),
                    items: kRestaurantCategories
                        .map(
                          (category) => DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _category = value ?? _category),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 3,
                    maxLength: 280,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(labelText: 'Téléphone'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email professionnel',
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _websiteController,
                    decoration: const InputDecoration(
                      labelText: 'Site internet',
                    ),
                    keyboardType: TextInputType.url,
                    validator: _validateWebsite,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _SectionTitle('Adresse'),
            LoyaloCard(
              child: Column(
                children: [
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(labelText: 'Adresse'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _postalCodeController,
                          decoration: const InputDecoration(
                            labelText: 'Code postal',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _cityController,
                          decoration: const InputDecoration(labelText: 'Ville'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _countryController,
                    decoration: const InputDecoration(labelText: 'Pays'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _SectionTitle('Horaires'),
            LoyaloCard(
              child: _OpeningHoursEditor(
                hours: _openingHours,
                onChanged: _setOpeningHours,
              ),
            ),
            const SizedBox(height: 18),
            _SectionTitle('Identité visuelle'),
            LoyaloCard(
              child: restaurant == null
                  ? Row(
                      children: [
                        const LoyaloIconBadge(
                          icon: Icons.photo_library_outlined,
                          color: AppColors.purple,
                          size: 52,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Créez d’abord votre établissement, puis vous pourrez ajouter le logo, la couverture et la galerie.',
                            style: TextStyle(color: muted, fontSize: 12.5),
                          ),
                        ),
                      ],
                    )
                  : _VisualIdentityEditor(
                      restaurant: restaurant,
                      uploadingKey: _uploadingImage,
                      onReplaceLogo: () =>
                          _replaceImage(restaurant, MerchantImageSlot.logo),
                      onRemoveLogo: restaurant.logoUrl?.isNotEmpty == true
                          ? () =>
                                _removeImage(restaurant, MerchantImageSlot.logo)
                          : null,
                      onReplaceCover: () =>
                          _replaceImage(restaurant, MerchantImageSlot.cover),
                      onRemoveCover:
                          restaurant.coverImageUrl?.isNotEmpty == true
                          ? () => _removeImage(
                              restaurant,
                              MerchantImageSlot.cover,
                            )
                          : null,
                      onAddGallery: () => _addGalleryImage(restaurant),
                      onRemoveGallery: (url) =>
                          _removeGalleryImage(restaurant, url),
                    ),
            ),
            const SizedBox(height: 18),
            SwitchListTile(
              value: _active,
              onChanged: (value) => setState(() => _active = value),
              title: const Text('Commerce actif'),
              subtitle: const Text(
                'Un commerce inactif ne doit normalement pas apparaître dans la découverte publique.',
              ),
              activeThumbColor: AppColors.purple,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                if (restaurant != null) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RewardsManagementScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.card_giftcard_outlined),
                      label: const Text('Fidélité'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const OffersManagementScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.local_fire_department_outlined),
                      label: const Text('Offres'),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 18),
            LoyaloGradientButton(
              label: restaurant == null
                  ? 'Créer mon établissement'
                  : 'Enregistrer les modifications',
              icon: Icons.save_outlined,
              onPressed: _saving ? null : () => _save(restaurant),
            ),
          ],
        ),
      ),
    );
  }

  void _setOpeningHours(String day, OpeningHours hours) {
    setState(() {
      _openingHours = {..._openingHours, day: hours};
    });
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return null;
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    return valid ? null : 'Email invalide';
  }

  String? _validateWebsite(String? value) {
    final website = value?.trim() ?? '';
    if (website.isEmpty) return null;
    final valid = website.contains('.') && !website.contains(' ');
    return valid ? null : 'Site invalide';
  }
}

class _OpeningHoursEditor extends StatelessWidget {
  final Map<String, OpeningHours> hours;
  final void Function(String day, OpeningHours hours) onChanged;

  const _OpeningHoursEditor({required this.hours, required this.onChanged});

  static const _labels = {
    'monday': 'Lundi',
    'tuesday': 'Mardi',
    'wednesday': 'Mercredi',
    'thursday': 'Jeudi',
    'friday': 'Vendredi',
    'saturday': 'Samedi',
    'sunday': 'Dimanche',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _labels.entries.map((entry) {
        final day = entry.key;
        final current = hours[day] ?? kDefaultOpeningHours[day]!;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              SizedBox(
                width: 78,
                child: Text(
                  entry.value,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Switch(
                value: current.open,
                onChanged: (value) => onChanged(
                  day,
                  OpeningHours(
                    open: value,
                    opensAt: current.opensAt,
                    closesAt: current.closesAt,
                  ),
                ),
                activeThumbColor: AppColors.teal,
              ),
              if (current.open) ...[
                Expanded(
                  child: _TimeField(
                    value: current.opensAt,
                    onChanged: (value) => onChanged(
                      day,
                      OpeningHours(
                        open: current.open,
                        opensAt: value,
                        closesAt: current.closesAt,
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text('-'),
                ),
                Expanded(
                  child: _TimeField(
                    value: current.closesAt,
                    onChanged: (value) => onChanged(
                      day,
                      OpeningHours(
                        open: current.open,
                        opensAt: current.opensAt,
                        closesAt: value,
                      ),
                    ),
                  ),
                ),
              ] else
                Expanded(
                  child: Text(
                    'Fermé',
                    style: TextStyle(color: AppTheme.mutedOf(context)),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _VisualIdentityEditor extends StatelessWidget {
  final Restaurant restaurant;
  final String? uploadingKey;
  final VoidCallback onReplaceLogo;
  final VoidCallback? onRemoveLogo;
  final VoidCallback onReplaceCover;
  final VoidCallback? onRemoveCover;
  final VoidCallback onAddGallery;
  final ValueChanged<String> onRemoveGallery;

  const _VisualIdentityEditor({
    required this.restaurant,
    required this.uploadingKey,
    required this.onReplaceLogo,
    required this.onRemoveLogo,
    required this.onReplaceCover,
    required this.onRemoveCover,
    required this.onAddGallery,
    required this.onRemoveGallery,
  });

  bool get _busy => uploadingKey != null;

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.mutedOf(context);
    final galleryFull =
        restaurant.galleryUrls.length >= MerchantImageService.galleryLimit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ImageManageRow(
          title: 'Logo',
          subtitle: 'Utilisé sur le dashboard et les cartes commerce.',
          imageUrl: restaurant.logoUrl,
          fallbackIcon: restaurant.icon,
          loading: uploadingKey == MerchantImageSlot.logo.name,
          onReplace: _busy ? null : onReplaceLogo,
          onRemove: _busy ? null : onRemoveLogo,
        ),
        const SizedBox(height: 16),
        Text(
          'Photo principale',
          style: TextStyle(
            color: AppTheme.textOf(context),
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 138,
          width: double.infinity,
          child: Stack(
            children: [
              Positioned.fill(
                child: LoyaloNetworkImage(
                  url: restaurant.coverImageUrl,
                  fallbackIcon: Icons.storefront_outlined,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              if (uploadingKey == MerchantImageSlot.cover.name)
                const Positioned.fill(
                  child: _ImageLoadingOverlay(label: 'Upload...'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : onReplaceCover,
                icon: const Icon(Icons.image_outlined),
                label: const Text('Remplacer'),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.outlined(
              onPressed: _busy ? null : onRemoveCover,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Supprimer la couverture',
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                'Galerie',
                style: TextStyle(
                  color: AppTheme.textOf(context),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '${restaurant.galleryUrls.length}/${MerchantImageService.galleryLimit}',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (restaurant.galleryUrls.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceOf(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.borderOf(context)),
            ),
            child: Text(
              'Aucune photo de galerie pour le moment.',
              style: TextStyle(color: muted, fontSize: 12.5),
            ),
          )
        else
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: restaurant.galleryUrls.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final url = restaurant.galleryUrls[index];
                return _GalleryImageTile(
                  url: url,
                  fallbackIcon: restaurant.icon,
                  loading: uploadingKey == url,
                  onRemove: _busy ? null : () => onRemoveGallery(url),
                );
              },
            ),
          ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _busy || galleryFull ? null : onAddGallery,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(galleryFull ? 'Limite atteinte' : 'Ajouter une photo'),
        ),
        if (galleryFull) ...[
          const SizedBox(height: 6),
          Text(
            'Supprimez une photo avant d’en ajouter une autre.',
            style: TextStyle(color: muted, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

class _ImageManageRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? imageUrl;
  final IconData fallbackIcon;
  final bool loading;
  final VoidCallback? onReplace;
  final VoidCallback? onRemove;

  const _ImageManageRow({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.fallbackIcon,
    required this.loading,
    required this.onReplace,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.mutedOf(context);
    return Row(
      children: [
        Stack(
          children: [
            LoyaloMerchantAvatar(
              imageUrl: imageUrl,
              icon: fallbackIcon,
              size: 62,
            ),
            if (loading)
              const Positioned.fill(child: _ImageLoadingOverlay(label: '')),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppTheme.textOf(context),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(subtitle, style: TextStyle(color: muted, fontSize: 12)),
            ],
          ),
        ),
        IconButton.outlined(
          onPressed: onReplace,
          icon: const Icon(Icons.upload_outlined),
          tooltip: 'Remplacer le logo',
        ),
        const SizedBox(width: 6),
        IconButton.outlined(
          onPressed: onRemove,
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Supprimer le logo',
        ),
      ],
    );
  }
}

class _GalleryImageTile extends StatelessWidget {
  final String url;
  final IconData fallbackIcon;
  final bool loading;
  final VoidCallback? onRemove;

  const _GalleryImageTile({
    required this.url,
    required this.fallbackIcon,
    required this.loading,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: Stack(
        children: [
          Positioned.fill(
            child: LoyaloNetworkImage(
              url: url,
              fallbackIcon: fallbackIcon,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.58),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 17),
              ),
            ),
          ),
          if (loading)
            const Positioned.fill(child: _ImageLoadingOverlay(label: '')),
        ],
      ),
    );
  }
}

class _ImageLoadingOverlay extends StatelessWidget {
  final String label;

  const _ImageLoadingOverlay({required this.label});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Colors.white,
              ),
            ),
            if (label.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _TimeField({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value,
      decoration: const InputDecoration(hintText: '09:00'),
      keyboardType: TextInputType.datetime,
      validator: (value) {
        final text = value?.trim() ?? '';
        final valid = RegExp(r'^\d{2}:\d{2}$').hasMatch(text);
        return valid ? null : 'HH:MM';
      },
      onChanged: onChanged,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: TextStyle(
          color: AppTheme.textOf(context),
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
