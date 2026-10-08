import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/exclusive_offer.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/loyalo_ui.dart';

class OffersManagementScreen extends ConsumerWidget {
  const OffersManagementScreen({super.key});

  void _createOffer(
    BuildContext pageContext,
    WidgetRef ref,
    String restaurantId,
  ) {
    _openOfferDialog(pageContext, ref, restaurantId);
  }

  void _editOffer(
    BuildContext pageContext,
    WidgetRef ref,
    String restaurantId,
    ExclusiveOffer offer,
  ) {
    _openOfferDialog(pageContext, ref, restaurantId, offer: offer);
  }

  void _openOfferDialog(
    BuildContext pageContext,
    WidgetRef ref,
    String restaurantId, {
    ExclusiveOffer? offer,
  }) {
    final titleController = TextEditingController(text: offer?.title ?? '');
    final descriptionController = TextEditingController(
      text: offer?.description ?? '',
    );
    final minVisitsController = TextEditingController(
      text: (offer?.minVisitsRequired ?? 0).toString(),
    );
    var startsAt = offer?.startsAt ?? DateTime.now();
    var endsAt = offer?.endsAt ?? DateTime.now().add(const Duration(days: 7));
    var active = offer?.active ?? true;
    var newCustomersOnly = offer?.newCustomersOnly ?? false;
    var saving = false;
    final editing = offer != null;

    showDialog(
      context: pageContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          final canSubmit =
              titleController.text.trim().isNotEmpty &&
              !endsAt.isBefore(startsAt);
          final surface = AppTheme.surfaceOf(context);
          final muted = AppTheme.mutedOf(context);
          Future<void> pickDate(bool start) async {
            final picked = await showDatePicker(
              context: context,
              initialDate: start ? startsAt : endsAt,
              firstDate: DateTime(2024),
              lastDate: DateTime(2035),
            );
            if (picked == null) return;
            setState(() {
              if (start) {
                startsAt = picked;
                if (endsAt.isBefore(startsAt)) endsAt = startsAt;
              } else {
                endsAt = picked;
              }
            });
          }

          return Dialog(
            backgroundColor: surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const LoyaloIconBadge(
                    icon: Icons.local_fire_department,
                    color: AppColors.orange,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    editing
                        ? 'Modifier l’offre exclusive'
                        : 'Créer une offre exclusive',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Publiez une offre temporaire visible par les clients Loyalo éligibles.',
                    style: TextStyle(fontSize: 12.5, color: muted, height: 1.4),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Titre de l\'offre',
                      hintText: 'Ex : Dessert offert ce soir',
                      prefixIcon: Icon(Icons.local_offer_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: descriptionController,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Ex : Offre réservée aux membres Loyalo',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => pickDate(true),
                          icon: const Icon(Icons.event_outlined, size: 18),
                          label: Text(
                            'Début ${DateFormat('dd/MM').format(startsAt)}',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => pickDate(false),
                          icon: const Icon(Icons.event_available, size: 18),
                          label: Text(
                            'Fin ${DateFormat('dd/MM').format(endsAt)}',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: minVisitsController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Visites min.',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: active,
                          onChanged: (value) => setState(() => active = value),
                          title: const Text(
                            'Active',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: newCustomersOnly,
                    onChanged: (value) =>
                        setState(() => newCustomersOnly = value ?? false),
                    title: const Text('Nouveaux clients uniquement'),
                    subtitle: const Text(
                      'Accessible seulement si le client n’a encore aucune visite validée.',
                    ),
                  ),
                  if (endsAt.isBefore(startsAt))
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'La date de fin doit être après la date de début.',
                        style: TextStyle(color: AppColors.orange),
                      ),
                    ),
                  const SizedBox(height: 26),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (editing)
                        TextButton(
                          onPressed: saving
                              ? null
                              : () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (confirmContext) => AlertDialog(
                                      title: const Text('Supprimer l’offre ?'),
                                      content: const Text(
                                        'Cette offre ne sera plus visible côté client.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(
                                            confirmContext,
                                            false,
                                          ),
                                          child: const Text('Annuler'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(
                                            confirmContext,
                                            true,
                                          ),
                                          child: const Text('Supprimer'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed != true) return;
                                  await ref
                                      .read(loyaltyRepositoryProvider)
                                      .deleteExclusiveOffer(
                                        offerId: offer.id,
                                        restaurantId: restaurantId,
                                      );
                                  if (!dialogContext.mounted ||
                                      !pageContext.mounted) {
                                    return;
                                  }
                                  Navigator.pop(dialogContext);
                                  ScaffoldMessenger.of(
                                    pageContext,
                                  ).showSnackBar(
                                    const SnackBar(
                                      content: Text('Offre supprimée.'),
                                    ),
                                  );
                                },
                          child: const Text('Supprimer'),
                        ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Annuler'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: !canSubmit || saving
                            ? null
                            : () async {
                                final minVisits =
                                    int.tryParse(minVisitsController.text) ?? 0;
                                setState(() => saving = true);
                                try {
                                  final repo = ref.read(
                                    loyaltyRepositoryProvider,
                                  );
                                  if (editing) {
                                    await repo.updateExclusiveOffer(
                                      offerId: offer.id,
                                      restaurantId: restaurantId,
                                      title: titleController.text.trim(),
                                      description: descriptionController.text
                                          .trim(),
                                      startsAt: startsAt,
                                      endsAt: endsAt,
                                      active: active,
                                      minVisitsRequired: minVisits.clamp(
                                        0,
                                        999,
                                      ),
                                      newCustomersOnly: newCustomersOnly,
                                    );
                                  } else {
                                    await repo.createExclusiveOffer(
                                      restaurantId: restaurantId,
                                      title: titleController.text.trim(),
                                      description: descriptionController.text
                                          .trim(),
                                      startsAt: startsAt,
                                      endsAt: endsAt,
                                      active: active,
                                      minVisitsRequired: minVisits.clamp(
                                        0,
                                        999,
                                      ),
                                      newCustomersOnly: newCustomersOnly,
                                    );
                                  }
                                  if (!dialogContext.mounted ||
                                      !pageContext.mounted) {
                                    return;
                                  }
                                  Navigator.pop(dialogContext);
                                  ScaffoldMessenger.of(
                                    pageContext,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        editing
                                            ? 'Offre exclusive modifiée.'
                                            : 'Offre exclusive publiée.',
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  setState(() => saving = false);
                                  if (!pageContext.mounted) return;
                                  ScaffoldMessenger.of(
                                    pageContext,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Impossible de publier l\'offre : $e',
                                      ),
                                    ),
                                  );
                                }
                              },
                        child: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(editing ? 'Enregistrer' : 'Publier'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(loyaltyRepositoryProvider);
    final restaurantId = ref.watch(currentMerchantRestaurantIdProvider)!;
    final offers = repo.exclusiveOffersForRestaurant(restaurantId);

    return Scaffold(
      appBar: AppBar(title: const Text('Offres exclusives')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createOffer(context, ref, restaurantId),
        backgroundColor: AppColors.purple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Créer une offre'),
      ),
      body: offers.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aucune offre exclusive pour le moment.\nCréez une offre temporaire pour vos clients Loyalo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textGray),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
              itemCount: offers.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final offer = offers[i];
                return _MerchantOfferTile(
                  offer: offer,
                  onToggle: () => repo.toggleExclusiveOffer(offer.id),
                  onEdit: () => _editOffer(context, ref, restaurantId, offer),
                );
              },
            ),
    );
  }
}

class _MerchantOfferTile extends StatelessWidget {
  final ExclusiveOffer offer;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  const _MerchantOfferTile({
    required this.offer,
    required this.onToggle,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final expired = now.isAfter(offer.endsAt);
    final dateLabel = DateFormat('dd/MM/yyyy').format(offer.endsAt);

    return LoyaloCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LoyaloIconBadge(
            icon: Icons.local_fire_department,
            color: expired ? AppColors.textGray : AppColors.orange,
            size: 44,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  offer.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: AppColors.textDark,
                  ),
                ),
                if (offer.description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    offer.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.35,
                      color: AppColors.textGray,
                    ),
                  ),
                ],
                const SizedBox(height: 7),
                Text(
                  '${offer.minVisitsRequired} visites min. · Fin le $dateLabel',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textGray,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Modifier',
              ),
              Switch(
                value: offer.active && !expired,
                activeThumbColor: AppColors.purple,
                onChanged: expired ? null : (_) => onToggle(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
