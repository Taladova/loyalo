import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../services/analytics_service.dart';
import '../../services/loyalty_repository.dart';
import '../../theme/app_theme.dart';
import 'client_search_screen.dart';

class ValidateVisitScreen extends ConsumerStatefulWidget {
  const ValidateVisitScreen({super.key});

  @override
  ConsumerState<ValidateVisitScreen> createState() => _ValidateVisitScreenState();
}

class _ValidateVisitScreenState extends ConsumerState<ValidateVisitScreen> {
  bool _byCode = true;
  String _digits = '';

  void _tapDigit(String d) {
    if (_digits.length >= 6) return;
    setState(() => _digits += d);
  }

  void _backspace() {
    if (_digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  Future<void> _validate() async {
    final repo = ref.read(loyaltyRepositoryProvider);
    final restaurantId = ref.read(currentMerchantRestaurantIdProvider)!;
    final userId = repo.resolveUserIdFromCode(_digits);

    if (userId == null) {
      _showDialog('Code introuvable', 'Aucun client ne correspond à ce code aujourd\'hui.', AppColors.danger);
      return;
    }

    final result = await repo.registerVisit(userId: userId, restaurantId: restaurantId);
    if (!mounted) return;
    _showResult(repo, result);
    setState(() => _digits = '');
  }

  void _showResult(LoyaltyRepository repo, VisitResult result) {
    switch (result.outcome) {
      case VisitOutcome.alreadyValidatedToday:
        _showDialog('Déjà validé', 'Ce client a déjà été validé aujourd\'hui pour ce restaurant.', AppColors.orange);
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
        title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Valider une visite')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _ModeButton(label: 'Par code', selected: _byCode, onTap: () => setState(() => _byCode = true)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ModeButton(
                    label: 'Par client',
                    selected: !_byCode,
                    onTap: () async {
                      setState(() => _byCode = false);
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ClientSearchScreen()),
                      );
                      if (mounted) setState(() => _byCode = true);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const Text('Demandez le code à 6 chiffres\nà votre client',
                textAlign: TextAlign.center, style: TextStyle(color: AppColors.textGray, fontSize: 13)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (i) {
                final filled = i < _digits.length;
                return Container(
                  width: 40,
                  height: 50,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: filled ? AppColors.purple : AppColors.border, width: filled ? 1.6 : 1),
                  ),
                  child: Text(filled ? _digits[i] : '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                );
              }),
            ),
            const Spacer(),
            _Keypad(onDigit: _tapDigit, onBackspace: _backspace),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _digits.length == 6 ? _validate : null,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: const Text('Valider la visite'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.purple : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.purple : AppColors.border),
        ),
        child: Text(label,
            style: TextStyle(color: selected ? Colors.white : AppColors.textDark, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  const _Keypad({required this.onDigit, required this.onBackspace});

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];
    return Column(
      children: rows
          .map((row) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: row.map((key) {
                    if (key.isEmpty) return const SizedBox(width: 64, height: 52);
                    return SizedBox(
                      width: 64,
                      height: 52,
                      child: TextButton(
                        onPressed: () => key == '⌫' ? onBackspace() : onDigit(key),
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.cloud,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(key, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                      ),
                    );
                  }).toList(),
                ),
              ))
          .toList(),
    );
  }
}
