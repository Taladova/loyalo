import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/restaurant.dart';
import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';
import '../../services/loyalty_repository.dart';
import '../../widgets/loyalo_auth_ui.dart';
import '../../widgets/loyalo_program_ui.dart';
import 'merchant_root_screen.dart';

class RewardsManagementScreen extends ConsumerStatefulWidget {
  const RewardsManagementScreen({super.key, this.completeOnboarding = false});

  final bool completeOnboarding;

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
  bool _confirmingChange = false;
  String? _saveError;
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
    _enabled = restaurant.needsLoyaltySetup || restaurant.loyaltyProgramEnabled;
    _type = restaurant.loyaltyProgramType;
    _policy = restaurant.validationPolicy;
    _thresholdController.text = restaurant.rewardThreshold.toString();
    _pointsController.text = restaurant.pointsPerVisit.toString();
    _rewardController.text = restaurant.rewardLabel;
    _descriptionController.text = restaurant.rewardDescription;
    _hoursController.text = restaurant.minimumHoursBetweenVisits.toString();
  }

  Future<void> _save(Restaurant restaurant) async {
    if (_saving || _confirmingChange) return;
    if (!_formKey.currentState!.validate()) return;

    final repo = ref.read(loyaltyRepositoryProvider);
    final nextThreshold = int.parse(_thresholdController.text);
    final hasClients = repo.uniqueClientsForRestaurant(restaurant.id) > 0;
    final importantChange =
        hasClients &&
        (nextThreshold != restaurant.rewardThreshold ||
            _type != restaurant.loyaltyProgramType);

    if (importantChange) {
      bool? confirmed;
      setState(() => _confirmingChange = true);
      try {
        confirmed = await showDialog<bool>(
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
      } finally {
        if (mounted) setState(() => _confirmingChange = false);
      }
      if (confirmed != true || !mounted) return;
    }

    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      if (restaurant.needsLoyaltySetup) {
        await repo.completeMerchantOnboarding(
          restaurantId: restaurant.id,
          ownerId: AuthService().currentUser!.uid,
          type: _type,
          rewardThreshold: nextThreshold,
          pointsPerVisit: int.parse(_pointsController.text),
          rewardLabel: _rewardController.text.trim(),
          rewardDescription: _descriptionController.text.trim(),
          validationPolicy: _policy,
          minimumHoursBetweenVisits: int.tryParse(_hoursController.text) ?? 4,
        );
        if (!mounted) return;
        if (widget.completeOnboarding) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MerchantRootScreen()),
            (route) => false,
          );
          return;
        }
      } else {
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
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Programme de fidélité enregistré.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _saveError = e is StateError
            ? 'Impossible d’enregistrer le programme. ${e.message}'
            : 'Impossible d’enregistrer le programme pour le moment. Réessayez dans quelques instants.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _leave() async {
    final popped = await Navigator.of(context).maybePop();
    if (!popped && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MerchantRootScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(loyaltyRepositoryProvider);
    final restaurantId = ref.watch(currentMerchantRestaurantIdProvider)!;
    final restaurant = repo.restaurantById(restaurantId);
    _fill(restaurant);
    final progress = _previewProgress(restaurant);
    final busy = _saving || _confirmingChange;
    final animationDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);

    Widget section({
      required String key,
      required String title,
      required IconData icon,
      required Widget child,
    }) => LoyaloProgramSection(
      key: Key(key),
      title: title,
      icon: icon,
      child: child,
    );
    void update(String _) => setState(() {});

    return LoyaloAuthScaffold(
      onBack: busy ? null : _leave,
      showBackButton: false,
      headerBuilder: (context, compact, veryCompact) => LoyaloProgramHeader(
        draft: restaurant.needsLoyaltySetup,
        compact: compact,
        veryCompact: veryCompact,
        onBack: busy ? null : _leave,
      ),
      contentBuilder: (context, compact) => LoyaloAuthSurface(
        compact: true,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!restaurant.needsLoyaltySetup) ...[
                Material(
                  color: Colors.transparent,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _enabled,
                    onChanged: busy
                        ? null
                        : (value) => setState(() => _enabled = value),
                    activeThumbColor: LoyaloAuthColors.purple,
                    title: const Text(
                      'Programme actif',
                      style: TextStyle(
                        color: LoyaloAuthColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      _enabled
                          ? 'Les clients voient leur progression fidélité.'
                          : 'La progression ne sera pas affichée côté client.',
                      style: const TextStyle(
                        color: LoyaloAuthColors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],
              section(
                key: 'program-section-type',
                title: 'Type de fidélité',
                icon: Icons.star_outline_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LoyaloSegmentedControl<LoyaltyProgramType>(
                      value: _type,
                      onChanged: busy
                          ? null
                          : (value) => setState(() => _type = value),
                      segments: const [
                        ButtonSegment(
                          value: LoyaltyProgramType.visits,
                          icon: Icon(Icons.repeat_rounded),
                          label: Text('Visites'),
                        ),
                        ButtonSegment(
                          value: LoyaltyProgramType.points,
                          icon: Icon(Icons.toll_outlined),
                          label: Text('Points'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    AnimatedSize(
                      duration: animationDuration,
                      alignment: Alignment.topLeft,
                      child: Text(
                        _type == LoyaltyProgramType.points
                            ? '1 visite = +${_pointsController.text} points. Objectif : ${_thresholdController.text} points pour une récompense.'
                            : 'Ex. : ${_thresholdController.text} visites = 1 récompense',
                        style: const TextStyle(
                          color: LoyaloAuthColors.textSecondary,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              section(
                key: 'program-section-objective',
                title: 'Objectif',
                icon: Icons.my_location_rounded,
                child: Column(
                  children: [
                    LoyaloNumericSelector(
                      fieldKey: const Key('program-threshold'),
                      label: _type == LoyaltyProgramType.points
                          ? 'Points nécessaires'
                          : 'Visites nécessaires',
                      controller: _thresholdController,
                      validator: _positiveNumber,
                      onChanged: update,
                      icon: _type == LoyaltyProgramType.points
                          ? Icons.toll_outlined
                          : Icons.repeat_rounded,
                      enabled: !busy,
                    ),
                    const SizedBox(height: 12),
                    LoyaloNumericSelector(
                      fieldKey: const Key('program-points'),
                      label: 'Points gagnés par visite',
                      controller: _pointsController,
                      validator: _positiveNumber,
                      onChanged: update,
                      icon: Icons.toll_outlined,
                      enabled: !busy,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ces points sont attribués à chaque visite validée.',
                      style: TextStyle(
                        color: LoyaloAuthColors.textSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              section(
                key: 'program-section-reward',
                title: 'Récompense',
                icon: Icons.card_giftcard_rounded,
                child: Column(
                  children: [
                    LoyaloProgramField(
                      label: 'Nom de la récompense',
                      child: LoyaloAuthTextField(
                        key: const Key('program-reward'),
                        controller: _rewardController,
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Récompense obligatoire'
                            : null,
                        hintText: '',
                        prefixIcon: Icons.card_giftcard_outlined,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.next,
                        enabled: !busy,
                        onChanged: update,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LoyaloProgramField(
                      label: 'Description optionnelle',
                      child: LoyaloAuthTextField(
                        key: const Key('program-description'),
                        controller: _descriptionController,
                        validator: (_) => null,
                        hintText: '',
                        prefixIcon: Icons.description_outlined,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        maxLines: 3,
                        maxLength: 140,
                        enabled: !busy,
                        buildCounter:
                            (
                              context, {
                              required currentLength,
                              required isFocused,
                              required maxLength,
                            }) => Text(
                              '$currentLength / $maxLength',
                              key: const Key('program-description-counter'),
                              style: const TextStyle(
                                color: LoyaloAuthColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              section(
                key: 'program-section-validation',
                title: 'Validation des visites',
                icon: Icons.calendar_month_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LoyaloSegmentedControl<VisitValidationPolicy>(
                      value: _policy,
                      onChanged: busy
                          ? null
                          : (value) => setState(() => _policy = value),
                      segments: const [
                        ButtonSegment(
                          value: VisitValidationPolicy.oncePerDay,
                          icon: Icon(Icons.today_outlined),
                          label: Text('Jour'),
                        ),
                        ButtonSegment(
                          value: VisitValidationPolicy.onceEveryXHours,
                          icon: Icon(Icons.schedule_rounded),
                          label: Text('X h'),
                        ),
                        ButtonSegment(
                          value: VisitValidationPolicy.perTransaction,
                          icon: Icon(Icons.receipt_long_outlined),
                          label: Text('Ticket'),
                        ),
                      ],
                    ),
                    AnimatedSize(
                      duration: animationDuration,
                      alignment: Alignment.topCenter,
                      child: _policy == VisitValidationPolicy.onceEveryXHours
                          ? Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: LoyaloNumericSelector(
                                fieldKey: const Key('program-hours'),
                                label: 'Nombre d’heures',
                                controller: _hoursController,
                                validator: _positiveNumber,
                                onChanged: update,
                                icon: Icons.schedule_rounded,
                                enabled: !busy,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              section(
                key: 'program-section-preview',
                title: 'Aperçu client',
                icon: Icons.visibility_outlined,
                child: AnimatedSize(
                  duration: animationDuration,
                  alignment: Alignment.topCenter,
                  child: LoyaloProgramPreview(
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
              ),
              const SizedBox(height: 20),
              if (_saveError != null) ...[
                LoyaloAuthError(message: _saveError!),
                const SizedBox(height: 12),
              ],
              LoyaloAuthPrimaryButton(
                key: const Key('program-save'),
                label: restaurant.needsLoyaltySetup
                    ? 'Activer et publier'
                    : 'Enregistrer',
                loading: _saving,
                onPressed: busy ? null : () => _save(restaurant),
              ),
            ],
          ),
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
