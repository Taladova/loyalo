import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/loyalo_page_header.dart';
import '../../providers/app_providers.dart';
import '../../services/analytics_service.dart';
import '../../services/loyalty_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/loyalo_auth_ui.dart';
import '../../widgets/loyalo_visit_validation_ui.dart';
import 'client_search_screen.dart';

class ValidateVisitScreen extends ConsumerStatefulWidget {
  const ValidateVisitScreen({super.key});

  @override
  ConsumerState<ValidateVisitScreen> createState() =>
      _ValidateVisitScreenState();
}

class _ValidateVisitScreenState extends ConsumerState<ValidateVisitScreen> {
  // Le scanner ne devient initial qu'après activation du service sécurisé.
  LoyaloVisitMethod _method = LoyaloVisitMethod.code;
  bool _openingSearch = false;
  final _methodPaneKey = GlobalKey();
  String _digits = '';
  bool _validating = false;

  void _tapDigit(String d) {
    if (_digits.length >= 6) return;
    setState(() => _digits += d);
  }

  void _backspace() {
    if (_digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  Future<void> _validate() async {
    if (_validating) return;
    setState(() => _validating = true);
    try {
      final repo = ref.read(loyaltyRepositoryProvider);
      final restaurantId = ref.read(currentMerchantRestaurantIdProvider)!;
      final userId = await repo.resolveUserIdFromCode(_digits);
      if (!mounted) return;
      if (userId == null) {
        _showDialog(
          'Code introuvable',
          'Aucun client ne correspond à ce code aujourd\'hui.',
          AppColors.danger,
        );
        return;
      }
      final result = await repo.registerVisit(
        userId: userId,
        restaurantId: restaurantId,
      );
      if (!mounted) return;
      _showResult(repo, result);
      setState(() => _digits = '');
    } catch (_) {
      if (mounted) {
        _showDialog(
          'Validation indisponible',
          'Impossible de valider la visite pour le moment. Vérifiez votre connexion puis réessayez.',
          AppColors.danger,
        );
      }
    } finally {
      if (mounted) setState(() => _validating = false);
    }
  }

  void _showResult(LoyaltyRepository repo, VisitResult result) {
    switch (result.outcome) {
      case VisitOutcome.alreadyValidatedToday:
        _showDialog(
          'Déjà validé',
          'Ce client a déjà été validé aujourd\'hui pour ce restaurant.',
          AppColors.orange,
        );
        break;
      case VisitOutcome.rewardUnlocked:
        AnalyticsService.logVisitRegistered(restaurantId: result.restaurant.id);
        AnalyticsService.logRewardUnlocked(
          restaurantId: result.restaurant.id,
          rewardLabel: result.restaurant.rewardLabel,
        );
        _showDialog(
          'Récompense débloquée !',
          '${result.passageCount}/${result.restaurant.rewardThreshold} passages.\n'
              'Le client remporte : ${result.restaurant.rewardLabel}.',
          AppColors.success,
        );
        break;
      case VisitOutcome.validated:
        AnalyticsService.logVisitRegistered(restaurantId: result.restaurant.id);
        _showDialog(
          'Visite validée',
          '${result.passageCount}/${result.restaurant.rewardThreshold} passages pour ${result.restaurant.name}.',
          AppColors.teal,
        );
    }
  }

  void _showDialog(String title, String message, Color color) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectMethod(LoyaloVisitMethod method) async {
    if (_validating || _openingSearch) return;
    if (method != LoyaloVisitMethod.search) {
      setState(() => _method = method);
      if (MediaQuery.textScalerOf(context).scale(16) > 23) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
          final pane = _methodPaneKey.currentContext;
          if (pane == null) return;
          Scrollable.ensureVisible(
            pane,
            alignment: 0,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
          );
        });
      }
      return;
    }
    final previous = _method;
    setState(() {
      _method = method;
      _openingSearch = true;
    });
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ClientSearchScreen()),
      );
    } finally {
      if (mounted) {
        setState(() {
          _method = previous;
          _openingSearch = false;
        });
      }
    }
  }

  Future<void> _pasteCode() async {
    if (_validating) return;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (!mounted || _validating) return;
      final value = (data?.text ?? '').replaceAll(RegExp(r'\s'), '');
      if (!RegExp(r'^[0-9]{6}$').hasMatch(value)) {
        _showDialog(
          'Code invalide',
          'Copiez un code composé de 6 chiffres.',
          AppColors.danger,
        );
        return;
      }
      setState(() => _digits = value);
    } catch (_) {
      if (mounted) {
        _showDialog(
          'Collage indisponible',
          'Saisissez le code avec le clavier numérique.',
          AppColors.danger,
        );
      }
    }
  }

  KeyEventResult _handleCodeKey(FocusNode node, KeyEvent event) {
    if (_validating || (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
      return KeyEventResult.ignored;
    }
    final character = event.character;
    if (character != null && RegExp(r'^[0-9]$').hasMatch(character)) {
      _tapDigit(character);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      _backspace();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) => LoyaloAuthScaffold(
    onBack: () => Navigator.of(context).maybePop(),
    showBackButton: false,
    headerBuilder: (context, compact, veryCompact) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: LoyaloPageHeader(
        title: 'Valider une visite',
        showBackButton: Navigator.of(context).canPop(),
        onBack: () => Navigator.of(context).maybePop(),
      ),
    ),
    contentBuilder: (context, compact) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LoyaloVisitMethodSelector(
          selected: _method,
          enabled: !_validating && !_openingSearch,
          onSelected: _selectMethod,
        ),
        const SizedBox(height: 12),
        KeyedSubtree(
          key: _methodPaneKey,
          child: _method == LoyaloVisitMethod.scanner
              ? LoyaloVisitQrUnavailable(
                  client: false,
                  onCode: () => _selectMethod(LoyaloVisitMethod.code),
                  onSearch: () => _selectMethod(LoyaloVisitMethod.search),
                )
              : Focus(
                  onKeyEvent: _handleCodeKey,
                  child: LoyaloVisitCodePane(
                    digits: _digits,
                    loading: _validating,
                    onDigit: _tapDigit,
                    onBackspace: _backspace,
                    onPaste: _pasteCode,
                    onValidate: _digits.length == 6 && !_validating
                        ? _validate
                        : null,
                  ),
                ),
        ),
      ],
    ),
  );
}
