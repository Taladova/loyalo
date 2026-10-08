import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/loyalo_ui.dart';

class ClientVisitHistoryScreen extends ConsumerWidget {
  const ClientVisitHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(loyaltyRepositoryProvider);
    final user = ref.watch(currentUserProvider)!;
    final visits = repo.visitsForUser(user.id);
    final text = AppTheme.textOf(context);
    final muted = AppTheme.mutedOf(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Historique des visites')),
      body: visits.isEmpty
          ? Center(
              child: Text(
                'Aucune visite pour le moment.',
                style: TextStyle(color: muted),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: visits.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final visit = visits[index];
                final restaurant = repo.restaurantByIdOrNull(
                  visit.restaurantId,
                );
                return LoyaloCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      LoyaloMerchantAvatar(
                        imageUrl: restaurant?.logoUrl,
                        icon: restaurant?.icon ?? Icons.storefront_outlined,
                        size: 46,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              restaurant?.name ?? 'Commerce',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: text,
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              DateFormat(
                                'dd/MM/yyyy à HH:mm',
                              ).format(visit.timestamp),
                              style: TextStyle(color: muted, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '+${restaurant?.pointsPerVisit ?? 0} pts',
                        style: const TextStyle(
                          color: AppColors.teal,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
