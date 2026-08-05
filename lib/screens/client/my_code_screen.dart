import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';

class MyCodeScreen extends ConsumerWidget {
  final VoidCallback? onBack;

  const MyCodeScreen({super.key, this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider)!;
    final repo = ref.watch(loyaltyRepositoryProvider);
    final code = repo.dailyCodeFor(user.id);

    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: onBack ?? () => Navigator.maybeOf(context)?.maybePop(),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
              ),
              const Spacer(),
              const Text('Ma carte Loyalo',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text(
                'Montrez ce code au commerçant\npour valider votre visite',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 26),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.teal, width: 1.4),
                  borderRadius: BorderRadius.circular(18),
                  color: Colors.white.withValues(alpha: 0.03),
                ),
                child: Text(
                  code.split('').join(' '),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Code personnel', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const Text('Valable aujourd\'hui', style: TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: 0.62,
                  minHeight: 4,
                  backgroundColor: Colors.white12,
                  color: AppColors.teal,
                ),
              ),
              const SizedBox(height: 8),
              const Text('Le code change chaque jour pour plus de sécurité.',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Comment ça marche ?'),
                    content: const Text(
                      'Montrez ce code au comptoir. Le commerçant le saisit dans son espace pro pour '
                      'valider votre visite. Il change chaque jour et ne peut être utilisé qu\'une '
                      'seule fois par jour et par restaurant.',
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Compris')),
                    ],
                  ),
                ),
                icon: const Icon(Icons.help_outline, color: Colors.white60, size: 18),
                label: const Text('Comment ça marche ?', style: TextStyle(color: Colors.white60)),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
