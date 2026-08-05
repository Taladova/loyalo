import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/referral.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';

class ReferralsListScreen extends ConsumerWidget {
  const ReferralsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider)!;
    final repo = ref.watch(loyaltyRepositoryProvider);
    final friends = repo.referralsFor(user.id);
    final joined = friends.where((f) => f.status == ReferralStatus.joined).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Mes filleuls')),
      body: friends.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Vous n\'avez invité personne pour le moment.\nPartagez votre code pour gagner des points !',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textGray),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _Stat(label: 'Invités', value: '${friends.length}'),
                      _Stat(label: 'Ont rejoint', value: '$joined'),
                      _Stat(label: 'Points gagnés', value: '${friends.fold(0, (a, f) => a + f.pointsEarned)}'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ...friends.map((f) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.lavender,
                            child: Text(f.name.isNotEmpty ? f.name[0].toUpperCase() : '?',
                                style: const TextStyle(color: AppColors.purple, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(f.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text('Invité le ${DateFormat('dd/MM/yyyy').format(f.invitedAt)}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textGray)),
                              ],
                            ),
                          ),
                          if (f.status == ReferralStatus.joined)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('+${f.pointsEarned} pts',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success)),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('En attente',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.orange)),
                            ),
                        ],
                      ),
                    )),
              ],
            ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.purple)),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textGray)),
      ],
    );
  }
}
