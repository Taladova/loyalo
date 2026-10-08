import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../welcome_screen.dart';
import 'client_statistics_screen.dart';
import 'referral_screen.dart';
import 'rewards_screen.dart';
import 'settings_screen.dart';

class ClientProfileScreen extends ConsumerWidget {
  const ClientProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider)!;
    final repo = ref.watch(loyaltyRepositoryProvider);
    final surface = AppTheme.surfaceOf(context);
    final border = AppTheme.borderOf(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.purple,
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    user.email.isEmpty ? 'Aucun email renseigné' : user.email,
                    style: const TextStyle(
                      color: AppColors.textGray,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Stat(label: 'Points', value: '${repo.totalPoints(user.id)}'),
                _Stat(
                  label: 'Restaurants',
                  value: '${repo.restaurants.length}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _ProfileTile(
            icon: Icons.card_giftcard,
            label: 'Mes récompenses',
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const RewardsScreen())),
          ),
          _ProfileTile(
            icon: Icons.people_alt_outlined,
            label: 'Parrainage',
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ReferralScreen())),
          ),
          _ProfileTile(
            icon: Icons.query_stats,
            label: 'Mes statistiques',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ClientStatisticsScreen()),
            ),
          ),
          _ProfileTile(
            icon: Icons.settings_outlined,
            label: 'Paramètres',
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          _ProfileTile(
            icon: Icons.logout,
            label: 'Déconnexion',
            color: AppColors.danger,
            onTap: () async {
              // Coupe d'abord les écouteurs Firestore : une fois déconnecté,
              // les règles de sécurité les rejetteraient en boucle. On ne
              // vide pas currentUserProvider ici : l'écran actuel le lit
              // encore pendant l'animation de sortie, et la prochaine
              // connexion le réécrit de toute façon avant d'y revenir.
              repo.stopListening();
              await AuthService().signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                (route) => false,
              );
            },
          ),
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
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.purple,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textGray),
        ),
      ],
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: AppTheme.surfaceOf(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.borderOf(context)),
      ),
      child: ListTile(
        leading: Icon(icon, color: color ?? AppTheme.textOf(context)),
        title: Text(
          label,
          style: TextStyle(
            color: color ?? AppTheme.textOf(context),
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textGray),
        onTap: onTap,
      ),
    );
  }
}
