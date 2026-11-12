import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../widgets/loyalo_page_header.dart';
import '../../core/database/tables/local_visits.dart';
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
      appBar: loyaloPageAppBar(
        context,
        title: const Text('Historique des visites'),
      ),
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
                final syncStatus = repo.visitSyncStatus(visit.id);
                final confirmed = syncStatus == LocalVisitSyncStatus.synced;
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
                        confirmed
                            ? '+${restaurant?.pointsPerVisit ?? 0} pts'
                            : syncStatus == LocalVisitSyncStatus.failed
                            ? 'Non confirmée\n0 pt'
                            : 'En attente\nde synchro',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: confirmed ? AppColors.teal : muted,
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
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
