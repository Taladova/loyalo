import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/restaurant.dart';
import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';
import '../../services/loyalty_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/loyalo_ui.dart';

class RewardsManagementScreen extends ConsumerStatefulWidget {
  const RewardsManagementScreen({super.key});

  @override
  ConsumerState<RewardsManagementScreen> createState() =>
      _RewardsManagementScreenState();
}

class _RewardsManagementScreenState
    extends ConsumerState<RewardsManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _thresholdController = TextEditingController();
  final _pointsController = TextEditingController();
  final _rewardController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _hoursController = TextEditingController();

  bool _initialized = false;
  bool _saving = false;
  bool _enabled = true;
  LoyaltyProgramType _type = LoyaltyProgramType.visits;
  VisitValidationPolicy _policy = VisitValidationPolicy.oncePerDay;

  @override
  void dispose() {
    _thresholdController.dispose();
    _pointsController.dispose();
    _rewardController.dispose();
    _descriptionController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  void _fill(Restaurant restaurant) {
    if (_initialized) return;
    _initialized = true;
    _enabled = restaurant.loyaltyProgramEnabled;
    _type = restaurant.loyaltyProgramType;
    _policy = restaurant.validationPolicy;
    _thresholdController.text = restaurant.rewardThreshold.toString();
    _pointsController.text = restaurant.pointsPerVisit.toString();
    _rewardController.text = restaurant.rewardLabel;
    _descriptionController.text = restaurant.rewardDescription;
    _hoursController.text = restaurant.minimumHoursBetweenVisits.toString();
  }

  Future<void> _save(Restaurant restaurant) async {
    if (!_formKey.currentState!.validate()) return;

    final repo = ref.read(loyaltyRepositoryProvider);
    final nextThreshold = int.parse(_thresholdController.text);
    final hasClients = repo.uniqueClientsForRestaurant(restaurant.id) > 0;
    final importantChange =
        hasClients &&
        (nextThreshold != restaurant.rewardThreshold ||
            _type != restaurant.loyaltyProgramType);

    if (importantChange) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Modifier le programme ?'),
          content: const Text(
            'Cette modification affectera la progression affichée pour vos clients. Les visites déjà enregistrées seront conservées.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continuer'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _saving = true);
    try {
      await repo.updateLoyaltyProgram(
        restaurantId: restaurant.id,
        ownerId: AuthService().currentUser!.uid,
        enabled: _enabled,
        type: _type,
        rewardThreshold: nextThreshold,
        pointsPerVisit: int.parse(_pointsController.text),
        rewardLabel: _rewardController.text.trim(),
        rewardDescription: _descriptionController.text.trim(),
        validationPolicy: _policy,
        minimumHoursBetweenVisits: int.tryParse(_hoursController.text) ?? 4,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Programme de fidélité enregistré.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Impossible d’enregistrer : $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(loyaltyRepositoryProvider);
    final restaurantId = ref.watch(currentMerchantRestaurantIdProvider)!;
    final restaurant = repo.restaurantById(restaurantId);
    _fill(restaurant);

    final text = AppTheme.textOf(context);
    final muted = AppTheme.mutedOf(context);
    final progress = _previewProgress(restaurant);

    return Scaffold(
      appBar: AppBar(title: const Text('Mon programme')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            LoyaloCard(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
                activeThumbColor: AppColors.purple,
                title: Text(
                  'Programme actif',
                  style: TextStyle(color: text, fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  _enabled
                      ? 'Les clients voient leur progression fidélité.'
                      : 'La progression ne sera pas affichée côté client.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _SectionTitle('Type de fidélité'),
            LoyaloCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<LoyaltyProgramType>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: LoyaltyProgramType.visits,
                          icon: Icon(Icons.repeat),
                          label: Text('Visites'),
                        ),
                        ButtonSegment(
                          value: LoyaltyProgramType.points,
                          icon: Icon(Icons.stars_outlined),
                          label: Text('Points'),
                        ),
                      ],
                      selected: {_type},
                      onSelectionChanged: (selected) =>
                          setState(() => _type = selected.first),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _type == LoyaltyProgramType.points
                        ? 'Ex : +100 pts, 1000 pts = récompense'
                        : 'Ex : 10 visites = 1 récompense',
                    style: TextStyle(
                      color: AppTheme.mutedOf(context),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionTitle('Objectif'),
            LoyaloCard(
              child: Column(
                children: [
                  TextFormField(
                    controller: _thresholdController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: _type == LoyaltyProgramType.points
                          ? 'Points nécessaires'
                          : 'Visites nécessaires',
                      prefixIcon: Icon(
                        _type == LoyaltyProgramType.points
                            ? Icons.stars_outlined
                            : Icons.repeat,
                      ),
                    ),
                    validator: _positiveNumber,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _pointsController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Points gagnés par visite',
                      prefixIcon: Icon(Icons.add_circle_outline),
                    ),
                    validator: _positiveNumber,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionTitle('Récompense'),
            LoyaloCard(
              child: Column(
                children: [
                  TextFormField(
                    controller: _rewardController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Nom de la récompense',
                      hintText: 'Ex : Un café offert',
                      prefixIcon: Icon(Icons.card_giftcard_outlined),
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Récompense obligatoire'
                        : null,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 2,
                    maxLength: 140,
                    decoration: const InputDecoration(
                      labelText: 'Description optionnelle',
                      hintText: 'Ex : Valable sur votre prochaine visite',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionTitle('Validation des visites'),
            LoyaloCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<VisitValidationPolicy>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: VisitValidationPolicy.oncePerDay,
                          icon: Icon(Icons.today_outlined),
                          label: Text('Jour'),
                        ),
                        ButtonSegment(
                          value: VisitValidationPolicy.onceEveryXHours,
                          icon: Icon(Icons.schedule),
                          label: Text('X h'),
                        ),
                        ButtonSegment(
                          value: VisitValidationPolicy.perTransaction,
                          icon: Icon(Icons.receipt_long_outlined),
                          label: Text('Ticket'),
                        ),
                      ],
                      selected: {_policy},
                      onSelectionChanged: (selected) =>
                          setState(() => _policy = selected.first),
                    ),
                  ),
                  if (_policy == VisitValidationPolicy.onceEveryXHours)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TextFormField(
                        controller: _hoursController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Nombre d’heures',
                        ),
                        validator: _positiveNumber,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionTitle('Aperçu client'),
            LoyaloCard(
              child: _ProgramPreview(
                enabled: _enabled,
                type: _type,
                current: progress.current,
                threshold: progress.threshold,
                remaining: progress.remaining,
                pointsPerVisit: int.tryParse(_pointsController.text) ?? 1,
                rewardLabel: _rewardController.text.trim().isEmpty
                    ? restaurant.rewardLabel
                    : _rewardController.text.trim(),
              ),
            ),
            const SizedBox(height: 18),
            LoyaloGradientButton(
              label: _saving ? 'Enregistrement...' : 'Enregistrer',
              icon: Icons.save_outlined,
              onPressed: _saving ? null : () => _save(restaurant),
            ),
          ],
        ),
      ),
    );
  }

  LoyaltyProgress _previewProgress(Restaurant restaurant) {
    final threshold =
        int.tryParse(_thresholdController.text) ?? restaurant.rewardThreshold;
    final points =
        int.tryParse(_pointsController.text) ?? restaurant.pointsPerVisit;
    final previewRestaurant = restaurant.copyWith(
      rewardThreshold: threshold,
      pointsPerVisit: points,
      loyaltyProgramType: _type,
      loyaltyProgramEnabled: _enabled,
      rewardLabel: _rewardController.text.trim().isEmpty
          ? restaurant.rewardLabel
          : _rewardController.text.trim(),
    );
    return ref
        .read(loyaltyRepositoryProvider)
        .loyaltyProgressFor(userId: 'preview', restaurant: previewRestaurant);
  }

  String? _positiveNumber(String? value) {
    final parsed = int.tryParse(value ?? '');
    if (parsed == null || parsed < 1) return 'Nombre obligatoire';
    return null;
  }
}

class _ProgramPreview extends StatelessWidget {
  final bool enabled;
  final LoyaltyProgramType type;
  final int current;
  final int threshold;
  final int remaining;
  final int pointsPerVisit;
  final String rewardLabel;

  const _ProgramPreview({
    required this.enabled,
    required this.type,
    required this.current,
    required this.threshold,
    required this.remaining,
    required this.pointsPerVisit,
    required this.rewardLabel,
  });

  @override
  Widget build(BuildContext context) {
    final text = AppTheme.textOf(context);
    final muted = AppTheme.mutedOf(context);
    final unit = type == LoyaltyProgramType.points ? 'points' : 'visites';
    final intro = type == LoyaltyProgramType.points
        ? '1 visite = +$pointsPerVisit pts'
        : '$threshold visites = 1 récompense';

    if (!enabled) {
      return Text(
        'Ce commerce n’a pas encore activé son programme de fidélité.',
        style: TextStyle(color: muted, fontSize: 13),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Votre programme',
          style: TextStyle(
            color: text,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(intro, style: TextStyle(color: muted, fontSize: 12.5)),
        const SizedBox(height: 12),
        Text(
          '$current / $threshold $unit',
          style: TextStyle(
            color: text,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: current / threshold,
            minHeight: 8,
            backgroundColor: AppColors.lightGray.withValues(alpha: 0.45),
            color: AppColors.teal,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Encore $remaining $unit avant : $rewardLabel',
          style: TextStyle(color: muted, fontSize: 12.5),
        ),
      ],
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
