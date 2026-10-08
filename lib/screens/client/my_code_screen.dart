import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/loyalo_logo.dart';
import '../../widgets/loyalo_ui.dart';

class MyCodeScreen extends ConsumerWidget {
  final VoidCallback? onBack;

  const MyCodeScreen({super.key, this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider)!;
    final repo = ref.watch(loyaltyRepositoryProvider);
    final code = repo.dailyCodeFor(user.id);
    final points = repo.totalPoints(user.id);
    final visits = repo.visitsForUser(user.id).take(4).toList();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Ma carte Loyalo',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed:
                      onBack ?? () => Navigator.maybeOf(context)?.maybePop(),
                  icon: Icon(onBack == null ? Icons.close : Icons.arrow_back),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.navy.withValues(alpha: 0.2),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -42,
                    top: -54,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.blue.withValues(alpha: 0.28),
                            AppColors.blue.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const LoyaloWordmark(markSize: 48, showTagline: false),
                      const SizedBox(height: 26),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Nom',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                                Text(
                                  user.name.isEmpty
                                      ? 'Client Loyalo'
                                      : user.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Points',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                                Text(
                                  '$points',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: QrImageView(
                              data: code,
                              size: 92,
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            LoyaloCard(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              child: Column(
                children: [
                  const Text(
                    'Code personnel du jour',
                    style: TextStyle(color: AppColors.textGray, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    code.split('').join(' '),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textOf(context),
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Valable aujourd\'hui',
                    style: TextStyle(color: AppColors.textGray, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Historique des visites',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(onPressed: () {}, child: const Text('Voir tout')),
              ],
            ),
            const SizedBox(height: 10),
            if (visits.isEmpty)
              const LoyaloCard(
                child: Text(
                  'Aucune visite pour le moment.',
                  style: TextStyle(color: AppColors.textGray, fontSize: 13),
                ),
              )
            else
              ...visits.map((visit) {
                final restaurant = repo.restaurants
                    .where((r) => r.id == visit.restaurantId)
                    .firstOrNull;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: LoyaloCard(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        LoyaloIconBadge(
                          icon: restaurant?.icon ?? Icons.storefront_outlined,
                          size: 42,
                          color: AppColors.navy,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                restaurant?.name ?? 'Commerce',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                DateFormat(
                                  'dd/MM/yyyy',
                                ).format(visit.timestamp),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textGray,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '+${restaurant?.pointsPerVisit ?? 0} pts',
                          style: const TextStyle(
                            color: AppColors.teal,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 12),
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
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Compris'),
                    ),
                  ],
                ),
              ),
              icon: const Icon(Icons.help_outline, size: 18),
              label: const Text('Comment ça marche ?'),
            ),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
