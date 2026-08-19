import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../legal_content.dart';
import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../legal_screen.dart';
import '../welcome_screen.dart';

class MerchantSettingsScreen extends ConsumerWidget {
  const MerchantSettingsScreen({super.key});

  void _showInfoDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer mon compte'),
        content: const Text(
          'Votre accès commerçant sera définitivement supprimé. Votre restaurant et l\'historique des visites '
          'déjà validées restent visibles pour vos clients. Voulez-vous vraiment continuer ?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final repo = ref.read(loyaltyRepositoryProvider);
              try {
                final uid = AuthService().currentUser!.uid;
                await repo.unlinkMerchant(uid);
                await AuthService().deleteAccount();
                repo.stopListening();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                  (route) => false,
                );
              } on FirebaseAuthException catch (e) {
                if (!context.mounted) return;
                final message = e.code == 'requires-recent-login'
                    ? 'Pour votre sécurité, reconnectez-vous puis réessayez de supprimer votre compte.'
                    : AuthService.readableError(e);
                _showInfoDialog(context, 'Suppression impossible', message);
              }
            },
            child: const Text('Supprimer', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurantId = ref.watch(currentMerchantRestaurantIdProvider)!;
    final restaurant = ref.watch(loyaltyRepositoryProvider).restaurantById(restaurantId);

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SectionLabel('Restaurant'),
          _SettingsCard(
            children: [
              ListTile(
                leading: const Icon(Icons.storefront_outlined),
                title: const Text('Nom'),
                trailing: Text(restaurant.name, style: const TextStyle(color: AppColors.textGray)),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('Email'),
                trailing: Text(AuthService().currentUser?.email ?? '', style: const TextStyle(color: AppColors.textGray)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionLabel('Assistance'),
          _SettingsCard(
            children: [
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('Aide & support'),
                trailing: const Icon(Icons.chevron_right, color: AppColors.textGray),
                onTap: () => _showInfoDialog(
                  context,
                  'Aide & support',
                  'Pour toute question sur votre compte commerçant, écrivez-nous à contact@taladova.com.',
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Politique de confidentialité'),
                trailing: const Icon(Icons.chevron_right, color: AppColors.textGray),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const LegalScreen(title: 'Politique de confidentialité', content: kPrivacyPolicyText),
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Conditions d\'utilisation'),
                trailing: const Icon(Icons.chevron_right, color: AppColors.textGray),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const LegalScreen(title: 'Conditions d\'utilisation', content: kTermsOfServiceText),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SettingsCard(
            children: [
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.danger),
                title: const Text('Supprimer mon compte', style: TextStyle(color: AppColors.danger)),
                onTap: () => _confirmDeleteAccount(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(text.toUpperCase(),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textGray, letterSpacing: 0.5)),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}
