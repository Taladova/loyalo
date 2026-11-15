import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/restaurant.dart';
import '../../models/restaurant_profile_section.dart';
import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';
import '../../services/merchant_image_service.dart';
import '../../widgets/loyalo_auth_ui.dart';
import '../../widgets/loyalo_establishment_ui.dart';
import '../../widgets/loyalo_ui.dart';
import 'rewards_management_screen.dart';

class MerchantEstablishmentSectionScreen extends ConsumerStatefulWidget {
  const MerchantEstablishmentSectionScreen({
    super.key,
    required this.restaurant,
    required this.section,
  });
  final Restaurant restaurant;
  final RestaurantProfileSection section;

  @override
  ConsumerState<MerchantEstablishmentSectionScreen> createState() =>
      _MerchantEstablishmentSectionScreenState();
}

class _MerchantEstablishmentSectionScreenState
    extends ConsumerState<MerchantEstablishmentSectionScreen> {
  final _form = GlobalKey<FormState>();
  final _feedback = GlobalKey();
  final _controllers = <String, TextEditingController>{};
  final _open = <String, bool>{};
  final _staged = <String>{};
  final _possiblyCommitted = <String>{};
  late Restaurant _base;
  late Map<String, dynamic> _baseline;
  late Map<String, dynamic> _expected;
  late String _category;
  String? _logo;
  String? _cover;
  List<String> _gallery = [];
  bool _active = false;
  bool _saving = false;
  bool _picking = false;
  bool _resetting = false;
  bool _allowPop = false;
  bool _asking = false;
  bool _saved = false;
  String? _error;
  MerchantImageService? _images;
  bool get _busy => _saving || _picking;
  bool get _dirty => _edits.isNotEmpty;
  bool get _confirmHours =>
      widget.section == RestaurantProfileSection.hours &&
      !_base.hasSavedOpeningHours;

  @override
  void initState() {
    super.initState();
    for (final key in [
      'name',
      'description',
      'phone',
      'email',
      'website',
      'address',
      'postalCode',
      'city',
      'country',
      for (final day in kDefaultOpeningHours.keys) ...[
        '$day-open',
        '$day-close',
      ],
    ]) {
      _controllers[key] = TextEditingController()..addListener(_edited);
    }
    _fill(widget.restaurant);
  }

  void _edited() {
    if (_resetting || !mounted) return;
    setState(() {
      _saved = false;
      _error = null;
    });
  }

  void _fill(Restaurant restaurant) {
    _resetting = true;
    _base = restaurant;
    final values = restaurantProfileValues(restaurant);
    for (final key in [
      'name',
      'description',
      'phone',
      'email',
      'website',
      'address',
      'postalCode',
      'city',
      'country',
    ]) {
      _controllers[key]!.text = (values[key] as String?) ?? '';
    }
    if (_controllers['email']!.text.isEmpty) {
      _controllers['email']!.text = AuthService().currentUser?.email ?? '';
    }
    _category = kRestaurantCategories.contains(restaurant.category)
        ? restaurant.category
        : kRestaurantCategories.contains(restaurant.cuisine)
        ? restaurant.cuisine
        : 'Autre';
    for (final day in kDefaultOpeningHours.keys) {
      final hours = restaurant.openingHours[day] ?? kDefaultOpeningHours[day]!;
      _open[day] = hours.open;
      _controllers['$day-open']!.text = hours.opensAt;
      _controllers['$day-close']!.text = hours.closesAt;
    }
    _logo = restaurant.logoUrl?.isNotEmpty == true ? restaurant.logoUrl : null;
    _cover = restaurant.coverImageUrl?.isNotEmpty == true
        ? restaurant.coverImageUrl
        : null;
    _gallery = List.of(restaurant.galleryUrls);
    _active = restaurant.active;
    _baseline = _values;
    _expected = values;
    _resetting = false;
  }

  String _text(String key) => _controllers[key]!.text.trim();

  void _showFeedback() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _feedback.currentContext;
      if (mounted && target != null) {
        unawaited(
          Scrollable.ensureVisible(
            target,
            alignment: 0,
            duration: const Duration(milliseconds: 200),
          ),
        );
      }
    });
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() => _error = message);
    _showFeedback();
  }

  String _readableError(Object error) => switch (error) {
    StateError() => error.message.toString(),
    ArgumentError() =>
      error.message?.toString() ?? 'Vérifiez les informations saisies.',
    _ => 'Vérifiez votre connexion et réessayez.',
  };

  Map<String, dynamic> get _values => switch (widget.section) {
    RestaurantProfileSection.general => {
      for (final key in ['name', 'description', 'phone', 'email', 'website'])
        key: _text(key),
      'category': _category,
      'cuisine': _category,
    },
    RestaurantProfileSection.address => {
      for (final key in ['address', 'postalCode', 'city']) key: _text(key),
      'country': _text('country').isEmpty ? 'France' : _text('country'),
    },
    RestaurantProfileSection.hours => {
      for (final day in kDefaultOpeningHours.keys)
        'openingHours.$day': {
          'open': _open[day],
          'opensAt': _text('$day-open'),
          'closesAt': _text('$day-close'),
        },
    },
    RestaurantProfileSection.photos => {
      'logoUrl': _logo,
      'coverImageUrl': _cover,
      'galleryUrls': List.of(_gallery),
    },
    RestaurantProfileSection.visibility => {'active': _active},
  };

  Map<String, dynamic> get _edits => {
    for (final entry in _values.entries)
      if (!profileValueEquals(entry.value, _baseline[entry.key]))
        entry.key: entry.value,
  };

  Map<String, dynamic> get _changes => _confirmHours ? _values : _edits;

  Future<void> _cleanupStaged() async {
    final service = _images;
    if (service == null) return;
    for (final url in _staged.toList()) {
      if (_possiblyCommitted.contains(url)) continue;
      try {
        await service.deleteByUrl(url);
        _staged.remove(url);
      } catch (_) {}
    }
  }

  Future<void> _leave() async {
    if (_busy || _asking) return;
    if (_dirty) {
      _asking = true;
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Modifications non enregistrées'),
          content: const Text(
            'Quitter cette rubrique sans enregistrer vos modifications ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Continuer la modification'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Quitter sans enregistrer'),
            ),
          ],
        ),
      );
      _asking = false;
      if (discard != true || !mounted) return;
    }
    await _cleanupStaged();
    if (!mounted) return;
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _save() async {
    if (_busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final invalid = _form.currentState!.validateGranularly();
    if (invalid.isNotEmpty) {
      await WidgetsBinding.instance.endOfFrame;
      if (mounted && invalid.first.context.mounted) {
        await Scrollable.ensureVisible(
          invalid.first.context,
          alignment: 0.2,
          duration: const Duration(milliseconds: 200),
        );
      }
      return;
    }
    final changes = _changes;
    if (changes.isEmpty) return;
    final uid = AuthService().currentUser?.uid ?? '';
    if (uid.isEmpty ||
        ref.read(currentMerchantRestaurantIdProvider) != _base.id) {
      _fail('Session expirée. Reconnectez-vous.');
      return;
    }
    setState(() {
      _saving = true;
      _saved = false;
      _error = null;
    });
    try {
      final before = _base;
      if (widget.section == RestaurantProfileSection.photos) {
        _possiblyCommitted.addAll(_staged);
      }
      final updated = await ref
          .read(loyaltyRepositoryProvider)
          .updateRestaurantSection(
            restaurantId: _base.id,
            ownerId: uid,
            section: widget.section,
            changes: changes,
            previousValues: {
              for (final key in changes.keys) key: _expected[key],
            },
          );
      if (widget.section == RestaurantProfileSection.photos) {
        final retained = {
          updated.logoUrl,
          updated.coverImageUrl,
          ...updated.galleryUrls,
        };
        _staged.removeAll(retained.whereType<String>());
        _possiblyCommitted.clear();
        final removed = <String>{
          if (changes.containsKey('logoUrl') && before.logoUrl != null)
            before.logoUrl!,
          if (changes.containsKey('coverImageUrl') &&
              before.coverImageUrl != null)
            before.coverImageUrl!,
          if (changes.containsKey('galleryUrls')) ...before.galleryUrls,
        }..removeAll(retained);
        final MerchantImageService service =
            _images ??
            ref.read<MerchantImageService>(merchantImageServiceProvider);
        _images = service;
        for (final url in removed) {
          if (url.isEmpty) continue;
          try {
            await service.deleteByUrl(url);
          } catch (_) {}
        }
        await _cleanupStaged();
      }
      if (!mounted) return;
      setState(() {
        _fill(updated);
        _saved = true;
      });
      _showFeedback();
    } catch (error) {
      _fail('Impossible d’enregistrer : ${_readableError(error)}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pick(MerchantImageSlot slot) async {
    if (_busy) return;
    if (slot == MerchantImageSlot.gallery &&
        _gallery.length >= MerchantImageService.galleryLimit) {
      return;
    }
    final uid = AuthService().currentUser?.uid ?? '';
    if (uid.isEmpty) {
      _fail('Session expirée. Reconnectez-vous.');
      return;
    }
    setState(() {
      _picking = true;
      _error = null;
      _saved = false;
    });
    _showFeedback();
    try {
      final MerchantImageService service =
          _images ??
          ref.read<MerchantImageService>(merchantImageServiceProvider);
      _images = service;
      final upload = await service.pickAndUpload(
        merchantId: uid,
        slot: slot,
        preserveCurrentImage: true,
      );
      if (upload == null) return;
      _staged.add(upload.downloadUrl);
      if (!mounted) {
        await _cleanupStaged();
        return;
      }
      setState(() {
        switch (slot) {
          case MerchantImageSlot.logo:
            _logo = upload.downloadUrl;
          case MerchantImageSlot.cover:
            _cover = upload.downloadUrl;
          case MerchantImageSlot.gallery:
            _gallery = [..._gallery, upload.downloadUrl];
        }
      });
    } on MerchantImageException catch (error) {
      _fail(error.message);
    } catch (error) {
      _fail('Impossible d’ajouter l’image. Réessayez.');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    unawaited(_cleanupStaged());
    super.dispose();
  }

  Widget _field(
    String key,
    String label, {
    TextInputType? keyboard,
    String? Function(String?)? validator,
    int lines = 1,
    int? maxLength,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: label,
          child: TextFormField(
            key: ValueKey('profile-field-$key'),
            controller: _controllers[key],
            enabled: !_busy,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 16,
              ),
            ),
            keyboardType: keyboard,
            validator: validator,
            maxLines: lines,
            maxLength: maxLength,
          ),
        ),
      ],
    ),
  );

  Widget _general() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Le nom est obligatoire. Les coordonnées et la description sont facultatives.',
        style: TextStyle(
          color: LoyaloAuthColors.textSecondary,
          fontSize: 12,
          height: 1.4,
        ),
      ),
      const SizedBox(height: 18),
      _field(
        'name',
        'Nom du commerce',
        validator: (value) =>
            value == null || value.trim().isEmpty ? 'Nom obligatoire' : null,
      ),
      const Text(
        'Catégorie',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: DropdownButtonFormField<String>(
          key: const Key('profile-category'),
          initialValue: _category,
          isExpanded: true,
          itemHeight: null,
          isDense: false,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
          items: kRestaurantCategories
              .map(
                (category) => DropdownMenuItem(
                  value: category,
                  child: Text(category, maxLines: 3),
                ),
              )
              .toList(),
          onChanged: _busy
              ? null
              : (value) {
                  if (value != null) {
                    setState(() {
                      _category = value;
                      _saved = false;
                      _error = null;
                    });
                  }
                },
        ),
      ),
      _field('description', 'Description', lines: 3, maxLength: 280),
      _field('phone', 'Téléphone', keyboard: TextInputType.phone),
      _field(
        'email',
        'Email professionnel',
        keyboard: TextInputType.emailAddress,
        validator: validateEstablishmentEmail,
      ),
      _field(
        'website',
        'Site internet',
        keyboard: TextInputType.url,
        validator: validateEstablishmentWebsite,
      ),
    ],
  );

  Widget _address() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Ces informations sont facultatives. Les coordonnées géographiques existantes sont conservées.',
        style: TextStyle(
          color: LoyaloAuthColors.textSecondary,
          fontSize: 12,
          height: 1.4,
        ),
      ),
      const SizedBox(height: 18),
      _field('address', 'Adresse'),
      _field('postalCode', 'Code postal', keyboard: TextInputType.number),
      _field('city', 'Ville'),
      _field('country', 'Pays'),
    ],
  );

  static const _days = {
    'monday': 'Lundi',
    'tuesday': 'Mardi',
    'wednesday': 'Mercredi',
    'thursday': 'Jeudi',
    'friday': 'Vendredi',
    'saturday': 'Samedi',
    'sunday': 'Dimanche',
  };

  Widget _hours() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Une plage horaire par jour. Format HH:MM.',
        style: TextStyle(color: LoyaloAuthColors.textSecondary, fontSize: 12),
      ),
      if (!_base.hasSavedOpeningHours) ...[
        const SizedBox(height: 8),
        const Text(
          'Les horaires par défaut sont proposés ci-dessous. Enregistrez-les pour les confirmer.',
          style: TextStyle(
            color: LoyaloAuthColors.textSecondary,
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
      for (final entry in _days.entries) ...[
        SwitchListTile(
          key: ValueKey('profile-day-${entry.key}'),
          contentPadding: EdgeInsets.zero,
          title: Text(
            entry.value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(_open[entry.key]! ? 'Ouvert' : 'Fermé'),
          value: _open[entry.key]!,
          onChanged: _busy
              ? null
              : (value) => setState(() {
                  _open[entry.key] = value;
                  _saved = false;
                  _error = null;
                }),
        ),
        if (_open[entry.key]!)
          LayoutBuilder(
            builder: (context, constraints) {
              final paired =
                  constraints.maxWidth >= 300 &&
                  MediaQuery.textScalerOf(context).scale(14) <= 20;
              final width = paired
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              String? validate(String? value) =>
                  RegExp(r'^\d{2}:\d{2}$').hasMatch(value?.trim() ?? '')
                  ? null
                  : 'HH:MM';
              return Wrap(
                spacing: 12,
                children: [
                  SizedBox(
                    width: width,
                    child: _field(
                      '${entry.key}-open',
                      'Ouverture',
                      keyboard: TextInputType.datetime,
                      validator: validate,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _field(
                      '${entry.key}-close',
                      'Fermeture',
                      keyboard: TextInputType.datetime,
                      validator: validate,
                    ),
                  ),
                ],
              );
            },
          ),
        const Divider(),
      ],
    ],
  );

  Widget _photo(MerchantImageSlot slot, String title, String? url) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: slot == MerchantImageSlot.logo ? 72 : 128,
        child: slot == MerchantImageSlot.logo
            ? Align(
                alignment: Alignment.centerLeft,
                child: LoyaloMerchantAvatar(
                  imageUrl: url,
                  icon: _base.icon,
                  size: 72,
                ),
              )
            : LoyaloNetworkImage(url: url, fallbackIcon: _base.icon),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            key: ValueKey('profile-photo-${slot.name}-add'),
            onPressed: _busy ? null : () => _pick(slot),
            icon: const Icon(Icons.upload_outlined),
            label: Text(url == null ? 'Ajouter' : 'Remplacer'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
          ),
          OutlinedButton.icon(
            key: ValueKey('profile-photo-${slot.name}-remove'),
            onPressed: _busy || url == null
                ? null
                : () => setState(() {
                    if (slot == MerchantImageSlot.logo) {
                      _logo = null;
                    } else {
                      _cover = null;
                    }
                    _saved = false;
                    _error = null;
                  }),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Supprimer'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
          ),
        ],
      ),
      const SizedBox(height: 20),
    ],
  );

  Widget _photos() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Les images sélectionnées seront appliquées après « Enregistrer ». Logo et photos sont facultatifs.',
        style: TextStyle(
          color: LoyaloAuthColors.textSecondary,
          fontSize: 12,
          height: 1.4,
        ),
      ),
      const SizedBox(height: 16),
      _photo(MerchantImageSlot.logo, 'Logo', _logo),
      _photo(MerchantImageSlot.cover, 'Photo principale', _cover),
      Text(
        'Galerie (${_gallery.length}/8)',
        key: const Key('profile-gallery-count'),
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 10),
      if (_gallery.isEmpty)
        const Text('Aucune photo de galerie pour le moment.'),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final url in _gallery)
            SizedBox(
              width: 96,
              height: 120,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: LoyaloNetworkImage(
                      url: url,
                      fallbackIcon: _base.icon,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: IconButton.filled(
                      tooltip: 'Retirer la photo ${_gallery.indexOf(url) + 1}',
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _gallery.remove(url);
                              _saved = false;
                              _error = null;
                            }),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      const SizedBox(height: 10),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          key: const Key('profile-gallery-add'),
          onPressed:
              _busy || _gallery.length >= MerchantImageService.galleryLimit
              ? null
              : () => _pick(MerchantImageSlot.gallery),
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(
            _gallery.length >= 8
                ? 'Limite de 8 photos atteinte'
                : 'Ajouter une photo',
          ),
          style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
        ),
      ),
    ],
  );

  Widget _visibility(Restaurant current) {
    final restricted =
        current.needsLoyaltySetup ||
        current.status == RestaurantStatus.pendingReview ||
        current.status == RestaurantStatus.suspended;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Statut actuel : ${EstablishmentStatus.of(current).label}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          key: const Key('profile-active'),
          contentPadding: EdgeInsets.zero,
          value: _active,
          title: const Text('Commerce actif'),
          subtitle: const Text(
            'La modification prendra effet après enregistrement.',
          ),
          onChanged: _busy || restricted
              ? null
              : (value) => setState(() {
                  _active = value;
                  _saved = false;
                  _error = null;
                }),
        ),
        const SizedBox(height: 12),
        Text(
          current.needsLoyaltySetup
              ? 'Configurez votre programme de fidélité avant de publier votre commerce.'
              : current.status == RestaurantStatus.pendingReview
              ? 'Votre commerce est en attente de validation. Son statut est conservé.'
              : current.status == RestaurantStatus.suspended
              ? 'Ce commerce est suspendu. Son activation n’est pas disponible depuis cette rubrique.'
              : 'L’activation est volontaire. Un commerce inactif ne s’affiche pas dans la découverte publique.',
          style: const TextStyle(
            color: LoyaloAuthColors.textSecondary,
            fontSize: 13,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'L’adresse, les horaires et les photos sont des informations facultatives ; ils ne déclenchent pas de publication.',
          style: TextStyle(
            color: LoyaloAuthColors.textSecondary,
            fontSize: 12,
            height: 1.4,
          ),
        ),
        if (current.needsLoyaltySetup) ...[
          const SizedBox(height: 12),
          const Text(
            'La publication de ce brouillon requiert un objectif et des points positifs, un nom de récompense et un délai de validation positif, dans le programme de fidélité.',
            style: TextStyle(
              color: LoyaloAuthColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            key: const Key('profile-configure-loyalty'),
            onPressed: _busy
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const RewardsManagementScreen(
                        completeOnboarding: true,
                      ),
                    ),
                  ),
            child: const Text('Configurer le programme de fidélité'),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final current =
        ref.watch(loyaltyRepositoryProvider).restaurantByIdOrNull(_base.id) ??
        _base;
    return PopScope(
      canPop: _allowPop || (!_dirty && !_busy),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_leave());
      },
      child: LoyaloEstablishmentFrame(
        title: widget.section.title,
        onBack: _busy ? null : _leave,
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(key: _feedback),
              if (_error != null) ...[
                LoyaloAuthError(message: _error!),
                const SizedBox(height: 12),
              ],
              if (_saved) ...[
                const EstablishmentMessage(message: 'Rubrique enregistrée.'),
                const SizedBox(height: 12),
              ],
              if (_picking) ...[
                const EstablishmentMessage(
                  message: 'Chargement de l’image…',
                  loading: true,
                ),
                const SizedBox(height: 12),
              ],
              LoyaloCard(
                color: Colors.white,
                child: switch (widget.section) {
                  RestaurantProfileSection.general => _general(),
                  RestaurantProfileSection.address => _address(),
                  RestaurantProfileSection.hours => _hours(),
                  RestaurantProfileSection.photos => _photos(),
                  RestaurantProfileSection.visibility => _visibility(current),
                },
              ),
              const SizedBox(height: 16),
              LoyaloAuthPrimaryButton(
                key: const Key('profile-save'),
                label: 'Enregistrer',
                onPressed: _busy || (!_dirty && !_confirmHours) ? null : _save,
                loading: _saving,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
