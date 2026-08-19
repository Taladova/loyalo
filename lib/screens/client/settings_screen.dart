import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../legal_content.dart';
import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';
import '../../theme/app_theme.dart';
import '../legal_screen.dart';
import '../welcome_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notifVisits = true;
  bool _notifRewards = true;
  bool _notifOffers = false;

  final _biometricService = BiometricService();
  bool _biometricSupported = false;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricState();
  }

  Future<void> _loadBiometricState() async {
    final supported = await _biometricService.isDeviceSupported();
    final enabled = await _biometricService.isEnabled();
    if (!mounted) return;
    setState(() {
      _biometricSupported = supported;
      _biometricEnabled = enabled;
    });
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      final confirmed = await _biometricService.authenticate();
      if (!confirmed) return;
    }
    await _biometricService.setEnabled(value);
    if (!mounted) return;
    setState(() => _biometricEnabled = value);
  }

  void _showInfoDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
      ),
    );
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer mon compte'),
        content: const Text(
          'Votre profil et votre accès seront définitivement supprimés. Voulez-vous vraiment continuer ?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final uid = ref.read(currentUserProvider)!.id;
              final repo = ref.read(loyaltyRepositoryProvider);
              try {
                await repo.deleteClientProfile(uid);
                await AuthService().deleteAccount();
                repo.stopListening();
                if (!mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                  (route) => false,
                );
              } on FirebaseAuthException catch (e) {
                if (!mounted) return;
                final message = e.code == 'requires-recent-login'
                    ? 'Pour votre sécurité, reconnectez-vous puis réessayez de supprimer votre compte.'
                    : AuthService.readableError(e);
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Suppression impossible'),
                    content: Text(message),
                    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                  ),
                );
              }
            },
            child: const Text('Supprimer', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider)!;

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SectionLabel('Notifications'),
          _SettingsCard(
            children: [
              SwitchListTile(
                title: const Text('Rappels de visite'),
                subtitle: const Text('Un rappel si vous n\'avez pas visité un restaurant depuis longtemps'),
                value: _notifVisits,
                activeThumbColor: AppColors.purple,
                onChanged: (v) => setState(() => _notifVisits = v),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Récompenses débloquées'),
                value: _notifRewards,
                activeThumbColor: AppColors.purple,
                onChanged: (v) => setState(() => _notifRewards = v),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Offres du jour'),
                value: _notifOffers,
                activeThumbColor: AppColors.purple,
                onChanged: (v) => setState(() => _notifOffers = v),
              ),
            ],
          ),
          if (_biometricSupported) ...[
            const SizedBox(height: 20),
            _SectionLabel('Sécurité'),
            _SettingsCard(
              children: [
                SwitchListTile(
                  title: const Text('Déverrouillage Face ID / empreinte'),
                  subtitle: const Text('Confirmez votre identité avant d\'accéder à l\'app'),
                  value: _biometricEnabled,
                  activeThumbColor: AppColors.purple,
                  onChanged: _toggleBiometric,
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          _SectionLabel('Compte'),
          _SettingsCard(
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Nom'),
                trailing: Text(user.name, style: const TextStyle(color: AppColors.textGray)),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('Email'),
                trailing: Text(user.email.isEmpty ? 'Non renseigné' : user.email,
                    style: const TextStyle(color: AppColors.textGray)),
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
                  'Aide & support',
                  'Pour toute question sur votre compte ou une récompense, contactez le restaurant partenaire '
                      'directement, ou écrivez-nous à contact@taladova.com.',
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
                onTap: _confirmDeleteAccount,
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
