import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/exclusive_offer.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/loyalo_auth_ui.dart';
import '../../widgets/loyalo_page_header.dart';
import '../../widgets/loyalo_ui.dart';

class OffersManagementScreen extends ConsumerWidget {
  const OffersManagementScreen({super.key});

  Future<void> _openOfferDialog(
    BuildContext context,
    String restaurantId, {
    ExclusiveOffer? offer,
  }) async {
    final message = await showDialog<String>(
      context: context,
      builder: (_) =>
          _OfferEditorDialog(restaurantId: restaurantId, offer: offer),
    );
    if (message == null || !context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(loyaltyRepositoryProvider);
    final restaurantId = ref.watch(currentMerchantRestaurantIdProvider)!;
    final offers = repo.exclusiveOffersForRestaurant(restaurantId);
    void create() => _openOfferDialog(context, restaurantId);

    return LoyaloAuthScaffold(
      onBack: () => Navigator.of(context).maybePop(),
      showBackButton: false,
      headerBuilder: (context, compact, veryCompact) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: LoyaloPageHeader(
          title: 'Offres exclusives',
          showBackButton: Navigator.of(context).canPop(),
          onBack: () => Navigator.of(context).maybePop(),
        ),
      ),
      contentBuilder: (context, compact) => offers.isEmpty
          ? LoyaloAuthSurface(
              compact: compact,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 4),
                  ExcludeSemantics(
                    child: Image.asset(
                      'assets/images/merchant/exclusive_offers_icon.png',
                      width: 80,
                      height: 80,
                      fit: BoxFit.contain,
                      cacheWidth: (80 * MediaQuery.devicePixelRatioOf(context))
                          .ceil(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Aucune offre exclusive pour le moment.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: LoyaloAuthColors.textPrimary,
                      fontSize: 20,
                      height: 1.3,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Créez une offre temporaire pour vos clients Loyalo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: LoyaloAuthColors.textSecondary,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  LoyaloAuthPrimaryButton(
                    key: const Key('offers-create'),
                    label: '+ Créer une offre',
                    onPressed: create,
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LoyaloAuthPrimaryButton(
                  key: const Key('offers-create'),
                  label: '+ Créer une offre',
                  onPressed: create,
                ),
                const SizedBox(height: 14),
                for (final offer in offers)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _MerchantOfferTile(
                      key: ValueKey('offer-${offer.id}'),
                      offer: offer,
                      onToggle: () async {
                        try {
                          await repo.toggleExclusiveOffer(offer.id);
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Impossible de modifier l’offre : $e',
                              ),
                            ),
                          );
                        }
                      },
                      onEdit: () =>
                          _openOfferDialog(context, restaurantId, offer: offer),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Le dialogue conserve les appels et les règles du formulaire existant.
/// Les contrôleurs appartiennent à sa route et sont libérés à sa fermeture.
class _OfferEditorDialog extends ConsumerStatefulWidget {
  const _OfferEditorDialog({required this.restaurantId, this.offer});

  final String restaurantId;
  final ExclusiveOffer? offer;

  @override
  ConsumerState<_OfferEditorDialog> createState() => _OfferEditorDialogState();
}

class _OfferEditorDialogState extends ConsumerState<_OfferEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _minVisitsController;
  final _titleFocus = FocusNode();
  late DateTime _startsAt;
  late DateTime _endsAt;
  late bool _active;
  late bool _newCustomersOnly;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.offer != null;
  bool get _canSubmit =>
      _titleController.text.trim().isNotEmpty && !_endsAt.isBefore(_startsAt);

  @override
  void initState() {
    super.initState();
    final offer = widget.offer;
    _titleController = TextEditingController(text: offer?.title ?? '');
    _descriptionController = TextEditingController(
      text: offer?.description ?? '',
    );
    _minVisitsController = TextEditingController(
      text: (offer?.minVisitsRequired ?? 0).toString(),
    );
    _startsAt = offer?.startsAt ?? DateTime.now();
    _endsAt = offer?.endsAt ?? DateTime.now().add(const Duration(days: 7));
    _active = offer?.active ?? true;
    _newCustomersOnly = offer?.newCustomersOnly ?? false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _titleFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _titleFocus.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _minVisitsController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool start) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _startsAt : _endsAt,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _startsAt = picked;
        if (_endsAt.isBefore(_startsAt)) _endsAt = _startsAt;
      } else {
        _endsAt = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_canSubmit || _saving) return;
    final minVisits = int.tryParse(_minVisitsController.text) ?? 0;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(loyaltyRepositoryProvider);
      if (_editing) {
        await repo.updateExclusiveOffer(
          offerId: widget.offer!.id,
          restaurantId: widget.restaurantId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          startsAt: _startsAt,
          endsAt: _endsAt,
          active: _active,
          minVisitsRequired: minVisits.clamp(0, 999),
          newCustomersOnly: _newCustomersOnly,
        );
      } else {
        await repo.createExclusiveOffer(
          restaurantId: widget.restaurantId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          startsAt: _startsAt,
          endsAt: _endsAt,
          active: _active,
          minVisitsRequired: minVisits.clamp(0, 999),
          newCustomersOnly: _newCustomersOnly,
        );
      }
      if (!mounted) return;
      Navigator.pop(
        context,
        _editing ? 'Offre exclusive modifiée.' : 'Offre exclusive publiée.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Impossible de publier l\'offre : $e';
      });
    }
  }

  Future<void> _delete() async {
    if (_saving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l’offre ?'),
        content: const Text('Cette offre ne sera plus visible côté client.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(loyaltyRepositoryProvider)
          .deleteExclusiveOffer(
            offerId: widget.offer!.id,
            restaurantId: widget.restaurantId,
          );
      if (mounted) Navigator.pop(context, 'Offre supprimée.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Impossible de supprimer l’offre : $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          key: const Key('offer-form-scroll'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const LoyaloIconBadge(
                    icon: Icons.local_offer_outlined,
                    size: 40,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        _editing
                            ? 'Modifier l’offre exclusive'
                            : 'Créer une offre exclusive',
                        style: const TextStyle(
                          color: LoyaloAuthColors.textPrimary,
                          fontSize: 21,
                          height: 1.25,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Publiez une offre temporaire visible par les clients Loyalo éligibles.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: LoyaloAuthColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              _OfferField(
                fieldKey: const Key('offer-title'),
                label: 'Titre de l’offre',
                hint: 'Ex : Dessert offert ce soir',
                controller: _titleController,
                focusNode: _titleFocus,
                icon: Icons.local_offer_outlined,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              _OfferField(
                fieldKey: const Key('offer-description'),
                label: 'Description',
                hint: 'Ex : Offre réservée aux membres Loyalo',
                controller: _descriptionController,
                icon: Icons.notes_rounded,
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              const _OfferSectionTitle('Période'),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final start = _OfferDateButton(
                    key: const Key('offer-start'),
                    label: 'Date de début',
                    date: _startsAt,
                    onPressed: () => _pickDate(true),
                  );
                  final end = _OfferDateButton(
                    key: const Key('offer-end'),
                    label: 'Date de fin',
                    date: _endsAt,
                    onPressed: () => _pickDate(false),
                  );
                  if (constraints.maxWidth < 300 ||
                      MediaQuery.textScalerOf(context).scale(16) > 21) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [start, const SizedBox(height: 10), end],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: start),
                      const SizedBox(width: 10),
                      Expanded(child: end),
                    ],
                  );
                },
              ),
              if (_endsAt.isBefore(_startsAt)) ...[
                const SizedBox(height: 10),
                const LoyaloAuthError(
                  message: 'La date de fin doit être après la date de début.',
                ),
              ],
              const SizedBox(height: 20),
              const _OfferSectionTitle('Conditions'),
              const SizedBox(height: 10),
              _OfferField(
                fieldKey: const Key('offer-min-visits'),
                label: 'Nombre minimal de visites',
                hint: '0',
                controller: _minVisitsController,
                icon: Icons.check_circle_outline,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                key: const Key('offer-active'),
                contentPadding: EdgeInsets.zero,
                value: _active,
                activeThumbColor: LoyaloAuthColors.purple,
                onChanged: (value) => setState(() => _active = value),
                title: const Text(
                  'Offre active',
                  style: TextStyle(
                    color: LoyaloAuthColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  _active ? 'Active' : 'Inactive',
                  style: const TextStyle(
                    color: LoyaloAuthColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
              CheckboxListTile(
                key: const Key('offer-new-customers'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: LoyaloAuthColors.purple,
                value: _newCustomersOnly,
                onChanged: (value) =>
                    setState(() => _newCustomersOnly = value ?? false),
                title: const Text(
                  'Nouveaux clients uniquement',
                  style: TextStyle(
                    color: LoyaloAuthColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  'Accessible seulement si le client n’a encore aucune visite validée.',
                  style: TextStyle(
                    color: LoyaloAuthColors.textSecondary,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                LoyaloAuthError(message: _error!),
              ],
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cancel = OutlinedButton(
                    key: const Key('offer-cancel'),
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 56),
                      foregroundColor: LoyaloAuthColors.purple,
                      side: const BorderSide(color: Color(0xFFD5DEED)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    child: const Text('Annuler'),
                  );
                  final submit = LoyaloAuthPrimaryButton(
                    key: const Key('offer-publish'),
                    label: _editing ? 'Enregistrer' : 'Publier',
                    onPressed: !_canSubmit || _saving ? null : _save,
                    loading: _saving,
                  );
                  if (constraints.maxWidth < 280 ||
                      MediaQuery.textScalerOf(context).scale(16) > 21) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [submit, const SizedBox(height: 10), cancel],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: cancel),
                      const SizedBox(width: 12),
                      Expanded(child: submit),
                    ],
                  );
                },
              ),
              if (_editing) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  key: const Key('offer-delete'),
                  onPressed: _saving ? null : _delete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Supprimer'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    minimumSize: const Size(48, 48),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OfferField extends StatelessWidget {
  const _OfferField({
    required this.fieldKey,
    required this.label,
    required this.hint,
    required this.controller,
    required this.icon,
    this.focusNode,
    this.onChanged,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
  });

  final Key fieldKey;
  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData icon;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: LoyaloAuthColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 7),
      Semantics(
        label: label,
        child: LoyaloAuthTextField(
          key: fieldKey,
          controller: controller,
          validator: (_) => null,
          focusNode: focusNode,
          hintText: hint,
          prefixIcon: icon,
          onChanged: onChanged,
          textCapitalization: TextCapitalization.sentences,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
        ),
      ),
    ],
  );
}

class _OfferSectionTitle extends StatelessWidget {
  const _OfferSectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      title,
      style: const TextStyle(
        color: LoyaloAuthColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _OfferDateButton extends StatelessWidget {
  const _OfferDateButton({
    super.key,
    required this.label,
    required this.date,
    required this.onPressed,
  });

  final String label;
  final DateTime date;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      foregroundColor: LoyaloAuthColors.textPrimary,
      side: const BorderSide(color: Color(0xFFD5DEED)),
      padding: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19)),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.event_outlined,
          color: LoyaloAuthColors.purple,
          size: 22,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: LoyaloAuthColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              Text(
                DateFormat('dd/MM/yyyy').format(date),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MerchantOfferTile extends StatelessWidget {
  const _MerchantOfferTile({
    super.key,
    required this.offer,
    required this.onToggle,
    required this.onEdit,
  });

  final ExclusiveOffer offer;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final expired = now.isAfter(offer.endsAt);
    final status = expired
        ? 'Expirée'
        : !offer.active
        ? 'Inactive'
        : now.isBefore(offer.startsAt)
        ? 'À venir'
        : 'Active';
    final statusColor = expired || !offer.active
        ? LoyaloAuthColors.textSecondary
        : now.isBefore(offer.startsAt)
        ? LoyaloAuthColors.purple
        : const Color(0xFF007C73);
    final dateFormat = DateFormat('dd/MM/yyyy');

    return LoyaloCard(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LoyaloIconBadge(icon: Icons.local_offer_outlined, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  offer.title,
                  style: const TextStyle(
                    color: LoyaloAuthColors.textPrimary,
                    fontSize: 17,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                key: ValueKey('offer-edit-${offer.id}'),
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                color: LoyaloAuthColors.purple,
                tooltip: 'Modifier l’offre',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (offer.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              offer.description,
              style: const TextStyle(
                color: LoyaloAuthColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.event_outlined,
                size: 19,
                color: LoyaloAuthColors.purple,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Du ${dateFormat.format(offer.startsAt)} au ${dateFormat.format(offer.endsAt)}',
                  style: const TextStyle(
                    color: LoyaloAuthColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          if (offer.minVisitsRequired > 0 || offer.newCustomersOnly) ...[
            const SizedBox(height: 8),
            if (offer.minVisitsRequired > 0)
              Text(
                '${offer.minVisitsRequired} visite${offer.minVisitsRequired > 1 ? 's' : ''} min.',
                style: const TextStyle(
                  color: LoyaloAuthColors.textPrimary,
                  fontSize: 13,
                ),
              ),
            if (offer.newCustomersOnly)
              const Text(
                'Nouveaux clients uniquement',
                style: TextStyle(
                  color: LoyaloAuthColors.purple,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
          const Divider(height: 20, color: Color(0xFFEBEFF6)),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Offre active',
                  style: TextStyle(
                    color: LoyaloAuthColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
              Switch(
                key: ValueKey('offer-toggle-${offer.id}'),
                value: offer.active && !expired,
                activeThumbColor: LoyaloAuthColors.purple,
                onChanged: expired ? null : (_) => onToggle(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
