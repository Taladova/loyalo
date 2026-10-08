import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../legal_content.dart';
import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../legal_screen.dart';
import '../welcome_screen.dart';
import 'merchant_establishment_screen.dart';

class MerchantSettingsScreen extends ConsumerStatefulWidget {
  const MerchantSettingsScreen({super.key});

  @override
  ConsumerState<MerchantSettingsScreen> createState() =>
      _MerchantSettingsScreenState();
}

class _MerchantSettingsScreenState
    extends ConsumerState<MerchantSettingsScreen> {
  bool _notifCheckIns = true;
  bool _notifImportant = true;

  void _showInfoDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
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
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
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
            child: const Text(
              'Supprimer',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final restaurantId = ref.watch(currentMerchantRestaurantIdProvider)!;
    final restaurant = ref
        .watch(loyaltyRepositoryProvider)
        .restaurantById(restaurantId);
    final uid = AuthService().currentUser?.uid ?? '';

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
                title: const Text('Mon établissement'),
                subtitle: const Text('Modifier ma fiche publique'),
                trailing: Text(
                  restaurant.name,
                  style: const TextStyle(color: AppColors.textGray),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MerchantEstablishmentScreen(),
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('Email'),
                trailing: Text(
                  AuthService().currentUser?.email ?? '',
                  style: const TextStyle(color: AppColors.textGray),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionLabel('Notifications'),
          _SettingsCard(
            children: [
              SwitchListTile(
                title: const Text('Check-ins'),
                subtitle: const Text('Clients en attente de validation'),
                value: _notifCheckIns,
                activeThumbColor: AppColors.purple,
                onChanged: (value) {
                  setState(() => _notifCheckIns = value);
                  ref
                      .read(loyaltyRepositoryProvider)
                      .updateNotificationPreference(
                        userId: uid,
                        key: 'merchantCheckIns',
                        enabled: value,
                      );
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Activité importante'),
                value: _notifImportant,
                activeThumbColor: AppColors.purple,
                onChanged: (value) {
                  setState(() => _notifImportant = value);
                  ref
                      .read(loyaltyRepositoryProvider)
                      .updateNotificationPreference(
                        userId: uid,
                        key: 'important',
                        enabled: value,
                      );
                },
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
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppColors.textGray,
                ),
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
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppColors.textGray,
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const LegalScreen(
                      title: 'Politique de confidentialité',
                      content: kPrivacyPolicyText,
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Conditions d\'utilisation'),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppColors.textGray,
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const LegalScreen(
                      title: 'Conditions d\'utilisation',
                      content: kTermsOfServiceText,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SettingsCard(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.danger,
                ),
                title: const Text(
                  'Supprimer mon compte',
                  style: TextStyle(color: AppColors.danger),
                ),
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
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textGray,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final surface = AppTheme.surfaceOf(context);
    final border = AppTheme.borderOf(context);
    return Material(
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}
