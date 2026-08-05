import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/stat_pill.dart';
import '../welcome_screen.dart';
import 'activity_history_screen.dart';

class MerchantDashboardScreen extends ConsumerWidget {
  const MerchantDashboardScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    ref.read(loyaltyRepositoryProvider).stopListening();
    await AuthService().signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(loyaltyRepositoryProvider);
    final restaurantId = ref.watch(currentMerchantRestaurantIdProvider)!;
    final restaurant = repo.restaurantById(restaurantId);
    final activity = repo.recentActivityForRestaurant(restaurantId, limit: 6);

    return Scaffold(
      appBar: AppBar(
        title: Text('Bonjour 👋\n${restaurant.name}', style: const TextStyle(height: 1.3, fontSize: 15)),
        actions: [
          IconButton(
            onPressed: () => _logout(context, ref),
            icon: const Icon(Icons.logout),
            tooltip: 'Déconnexion',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Aujourd\'hui', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TodayCard(
                  color: AppColors.teal,
                  value: '${repo.visitsToday(restaurantId)}',
                  label: 'Visites validées',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TodayCard(
                  color: AppColors.purple,
                  value: '${repo.newClientsToday(restaurantId)}',
                  label: 'Nouveaux clients',
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text('Statistiques', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const Text('7 derniers jours', style: TextStyle(fontSize: 12, color: AppColors.textGray)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: StatPill(label: 'Visites', value: '156', trend: '+12%')),
              const SizedBox(width: 10),
              Expanded(child: StatPill(label: 'Clients', value: '89', trend: '+8%')),
              const SizedBox(width: 10),
              Expanded(child: StatPill(label: 'Récompenses', value: '23', trend: '+15%')),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Activité récente', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ActivityHistoryScreen()),
                ),
                child: const Text('Voir tout'),
              ),
            ],
          ),
          if (activity.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Aucune activité pour le moment.', style: TextStyle(color: AppColors.textGray)),
            )
          else
            ...activity.map((v) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
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
                        child: Icon(Icons.check, color: AppColors.success, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Visite validée — ${repo.nameForClient(v.userId)}',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            Text(DateFormat('dd/MM à HH:mm').format(v.timestamp),
                                style: const TextStyle(fontSize: 11, color: AppColors.textGray)),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  final Color color;
  final String value;
  final String label;

  const _TodayCard({required this.color, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}
