import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';

class ActivityHistoryScreen extends ConsumerWidget {
  const ActivityHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(loyaltyRepositoryProvider);
    final restaurantId = ref.watch(currentMerchantRestaurantIdProvider)!;
    final activity = repo.recentActivityForRestaurant(restaurantId, limit: 500);

    return Scaffold(
      appBar: AppBar(title: const Text('Activité récente')),
      body: activity.isEmpty
          ? const Center(
              child: Text(
                'Aucune activité pour le moment.',
                style: TextStyle(color: AppColors.textGray),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: activity.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final v = activity[i];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.cloud,
                        child: Icon(
                          Icons.check,
                          color: AppColors.success,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Visite validée — ${repo.nameForClient(v.userId)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              DateFormat(
                                'dd/MM/yyyy à HH:mm',
                              ).format(v.timestamp),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textGray,
                              ),
                            ),
                          ],
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
