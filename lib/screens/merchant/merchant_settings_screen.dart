import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../legal_content.dart';
import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/loyalo_auth_ui.dart';
import '../../widgets/loyalo_settings_ui.dart';
import '../legal_screen.dart';
import '../welcome_screen.dart';
import 'merchant_password_screen.dart';

class MerchantSettingsScreen extends ConsumerStatefulWidget {
  const MerchantSettingsScreen({super.key, this.auth, this.versionLoader});
  final AuthService? auth;
  final Future<PackageInfo> Function()? versionLoader;

  @override
  ConsumerState<MerchantSettingsScreen> createState() =>
      _MerchantSettingsScreenState();
}

class _MerchantSettingsScreenState
    extends ConsumerState<MerchantSettingsScreen> {
  late final AuthService _auth;
  final _feedback = GlobalKey();
  final _preferenceFeedback = GlobalKey();
  String? _uid;
  Map<String, bool>? _preferences;
  final _pending = <String, bool>{};
  bool _preferencesLoading = true;
  String? _preferencesError;
  PackageInfo? _version;
  bool _versionLoading = true;
  bool _versionError = false;
  bool _accountBusy = false;
  bool _confirming = false;
  String? _accountError;
  int _loadGeneration = 0;

  void _showFeedback(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = key.currentContext;
      if (mounted && target != null) {
        unawaited(
          Scrollable.ensureVisible(
            target,
            alignment: 0.2,
            duration: const Duration(milliseconds: 200),
          ),
        );
      }
    });
  }

  bool get _session =>
      _uid != null &&
      _auth.currentUser?.uid == _uid &&
      ref.read(currentMerchantRestaurantIdProvider) != null;
  bool get _canAct =>
      _session && !_accountBusy && !_confirming && _pending.isEmpty;

  @override
  void initState() {
    super.initState();
    _auth = widget.auth ?? AuthService();
    _uid = _auth.currentUser?.uid;
    _loadPreferences();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    setState(() {
      _versionLoading = true;
      _versionError = false;
    });
    try {
      final info =
          await (widget.versionLoader?.call() ?? PackageInfo.fromPlatform());
      if (mounted) {
        setState(() {
          _version = info;
          _versionLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _versionLoading = false;
          _versionError = true;
        });
      }
    }
  }

  Future<void> _loadPreferences() async {
    final generation = ++_loadGeneration;
    if (!_session) {
      setState(() {
        _preferencesLoading = false;
        _preferencesError = 'Session commerçant indisponible.';
      });
      return;
    }
    setState(() {
      _preferencesLoading = true;
      _preferencesError = null;
    });
    try {
      final values = await ref
          .read(loyaltyRepositoryProvider)
          .loadMerchantNotificationPreferences(_uid!);
      if (mounted && generation == _loadGeneration && _session) {
        setState(() {
          _preferences = values;
          _preferencesLoading = false;
        });
      }
    } catch (_) {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _preferencesLoading = false;
          _preferencesError =
              'Impossible de charger vos préférences de notification.';
        });
        _showFeedback(_preferenceFeedback);
      }
    }
  }

  Future<void> _toggle(String key, bool value) async {
    if (!_session ||
        _preferences == null ||
        _pending.containsKey(key) ||
        _accountBusy) {
      return;
    }
    final uid = _uid!;
    setState(() {
      _pending[key] = value;
      _preferencesError = null;
    });
    try {
      await ref
          .read(loyaltyRepositoryProvider)
          .updateNotificationPreference(userId: uid, key: key, enabled: value);
      if (mounted && _auth.currentUser?.uid == uid) {
        setState(() => _preferences = {..._preferences!, key: value});
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _preferencesError =
              'Impossible d’enregistrer cette préférence. Votre réglage précédent est conservé.',
        );
        _showFeedback(_preferenceFeedback);
      }
    } finally {
      if (mounted) setState(() => _pending.remove(key));
    }
  }

  Future<void> _info(String title, String message) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: Text(title),
      content: SelectableText(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
      ],
    ),
  );

  void _welcome() {
    ref.read(currentMerchantRestaurantIdProvider.notifier).state = null;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const WelcomeScreen()),
      (_) => false,
    );
  }

  Future<void> _logout() async {
    if (!_canAct) return;
    setState(() => _confirming = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Se déconnecter ?'),
        content: const Text(
          'Vous pourrez vous reconnecter à votre espace commerçant.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => _confirming = false);
    if (confirmed != true || !_session) return;
    final repo = ref.read(loyaltyRepositoryProvider);
    final restaurantId = ref.read(currentMerchantRestaurantIdProvider)!;
    setState(() {
      _accountBusy = true;
      _accountError = null;
    });
    try {
      await repo.stopListening();
      await _auth.signOut();
      if (mounted) _welcome();
    } catch (_) {
      if (_auth.currentUser?.uid == _uid) {
        repo.startListeningForMerchant(restaurantId, ownerUid: _uid);
      }
      if (mounted) {
        setState(() => _accountError = 'Déconnexion impossible. Réessayez.');
        _showFeedback(_feedback);
      }
    } finally {
      if (mounted) setState(() => _accountBusy = false);
    }
  }

  Future<void> _delete() async {
    if (!_canAct) return;
    setState(() => _confirming = true);
    final repo = ref.read(loyaltyRepositoryProvider);
    final deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DeleteAccountDialog(
        auth: _auth,
        expectedUid: _uid!,
        onDelete: () async {
          if (!_session) throw FirebaseAuthException(code: 'user-mismatch');
          setState(() {
            _accountBusy = true;
            _accountError = null;
          });
          try {
            await repo.unlinkMerchant(_uid!);
            await _auth.deleteAccount();
            await repo.stopListening();
          } finally {
            if (mounted) setState(() => _accountBusy = false);
          }
        },
      ),
    );
    if (!mounted) return;
    setState(() => _confirming = false);
    if (deleted == true) _welcome();
  }

  Widget _preference(
    String key,
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    final saving = _pending.containsKey(key);
    final loading = _preferencesLoading;
    final known = _preferences != null;
    return LoyaloSettingsItem(
      key: ValueKey('settings-preference-$key'),
      title: title,
      subtitle: saving ? 'Enregistrement…' : subtitle,
      icon: icon,
      color: color,
      trailing: loading || saving
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.3),
            )
          : known
          ? Switch(
              key: ValueKey('settings-switch-$key'),
              value: _pending[key] ?? _preferences![key]!,
              activeThumbColor: Colors.white,
              activeTrackColor: LoyaloAuthColors.purple,
              onChanged: _session && !_accountBusy && !_confirming
                  ? (value) => _toggle(key, value)
                  : null,
            )
          : const Icon(Icons.error_outline, color: AppColors.danger),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(currentMerchantRestaurantIdProvider);
    final user = _auth.currentUser;
    final email = user?.email?.isNotEmpty == true
        ? user!.email!
        : 'Indisponible';
    final version = _version;
    return PopScope(
      canPop: !_accountBusy && _pending.isEmpty,
      child: LoyaloSettingsFrame(
        title: 'Paramètres',
        onBack: _accountBusy || _pending.isNotEmpty
            ? null
            : () => Navigator.of(context).maybePop(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(key: _feedback),
            if (!_session) ...[
              const LoyaloAuthError(
                message:
                    'Votre session commerçant est indisponible. Reconnectez-vous.',
              ),
              const SizedBox(height: 12),
            ],
            if (_accountError != null) ...[
              LoyaloAuthError(message: _accountError!),
              const SizedBox(height: 12),
            ],
            if (_accountBusy) ...[
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 12),
            ],
            LoyaloSettingsSection(
              title: 'Compte et sécurité',
              icon: Icons.person_outline,
              children: [
                LoyaloSettingsItem(
                  key: const Key('settings-email'),
                  title: 'Email de connexion',
                  icon: Icons.email_outlined,
                  color: AppColors.blue,
                  detail: SelectableText(
                    email,
                    style: const TextStyle(
                      color: LoyaloAuthColors.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
                LoyaloSettingsItem(
                  key: const Key('settings-password'),
                  title: 'Modifier mon mot de passe',
                  subtitle: 'Sécurisez votre compte',
                  icon: Icons.lock_outline,
                  color: AppColors.purple,
                  enabled: _canAct,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MerchantPasswordScreen(auth: _auth),
                    ),
                  ),
                ),
                LoyaloSettingsItem(
                  key: const Key('settings-logout'),
                  title: 'Se déconnecter',
                  icon: Icons.logout,
                  color: AppColors.danger,
                  enabled: _canAct,
                  onTap: _logout,
                ),
              ],
            ),
            LoyaloSettingsSection(
              title: 'Notifications',
              icon: Icons.notifications_none,
              children: [
                _preference(
                  'merchantCheckIns',
                  'Check-ins',
                  'Clients en attente de validation',
                  Icons.task_alt,
                  AppColors.teal,
                ),
                _preference(
                  'important',
                  'Activité importante',
                  'Offres, récompenses et autres événements',
                  Icons.notifications_none,
                  AppColors.orange,
                ),
                if (_preferencesError != null)
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LoyaloAuthError(
                          key: _preferenceFeedback,
                          message: _preferencesError!,
                        ),
                        if (_session)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              key: const Key('settings-preferences-retry'),
                              onPressed:
                                  _preferencesLoading || _pending.isNotEmpty
                                  ? null
                                  : _loadPreferences,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Réessayer'),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
            LoyaloSettingsSection(
              title: 'Aide et informations',
              icon: Icons.support_agent,
              children: [
                LoyaloSettingsItem(
                  key: const Key('settings-support'),
                  title: 'Aide & support',
                  icon: Icons.help_outline,
                  color: AppColors.purple,
                  onTap: () => _info(
                    'Aide & support',
                    'Pour toute question sur votre compte commerçant, écrivez-nous à contact@taladova.com.',
                  ),
                ),
                LoyaloSettingsItem(
                  key: const Key('settings-privacy'),
                  title: 'Politique de confidentialité',
                  icon: Icons.privacy_tip_outlined,
                  color: AppColors.blue,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LegalScreen(
                        title: 'Politique de confidentialité',
                        content: kPrivacyPolicyText,
                      ),
                    ),
                  ),
                ),
                LoyaloSettingsItem(
                  key: const Key('settings-terms'),
                  title: 'Conditions d’utilisation',
                  icon: Icons.description_outlined,
                  color: AppColors.purple,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LegalScreen(
                        title: 'Conditions d’utilisation',
                        content: kTermsOfServiceText,
                      ),
                    ),
                  ),
                ),
                LoyaloSettingsItem(
                  key: const Key('settings-version'),
                  title: 'Version de l’application',
                  icon: Icons.info_outline,
                  color: AppColors.blue,
                  subtitle: _versionLoading
                      ? 'Chargement…'
                      : _versionError
                      ? 'Indisponible'
                      : version == null || version.version.isEmpty
                      ? 'Indisponible'
                      : 'v${version.version}${version.buildNumber.isEmpty ? '' : ' (build ${version.buildNumber})'}',
                  trailing: _versionLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.3),
                        )
                      : _versionError
                      ? IconButton(
                          tooltip: 'Réessayer la lecture de la version',
                          onPressed: _loadVersion,
                          icon: const Icon(Icons.refresh),
                        )
                      : null,
                ),
              ],
            ),
            LoyaloSettingsSection(
              title: 'Gestion du compte',
              icon: Icons.delete_outline,
              danger: true,
              children: [
                LoyaloSettingsItem(
                  key: const Key('settings-delete'),
                  title: 'Supprimer mon compte',
                  icon: Icons.delete_outline,
                  color: AppColors.danger,
                  danger: true,
                  enabled: _canAct,
                  onTap: _delete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({
    required this.auth,
    required this.expectedUid,
    required this.onDelete,
  });
  final AuthService auth;
  final String expectedUid;
  final Future<void> Function() onDelete;
  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.clear();
    _password.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await widget.auth.reauthenticateWithPassword(
        password: _password.text,
      );
      _password.clear();
      if (user.uid != widget.expectedUid) {
        throw FirebaseAuthException(code: 'user-mismatch');
      }
      await widget.onDelete();
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      _password.clear();
      if (mounted) setState(() => _error = AuthService.accountError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final supported = widget.auth.supportsPasswordAuthentication;
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        scrollable: true,
        title: const Text('Supprimer mon compte'),
        content: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Votre accès commerçant sera définitivement supprimé. Votre restaurant et l’historique des visites déjà validées restent visibles pour vos clients. Voulez-vous vraiment continuer ?',
                ),
                const SizedBox(height: 16),
                if (supported) ...[
                  const Text(
                    'Confirmez votre identité avec votre mot de passe actuel.',
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    key: const Key('settings-delete-password'),
                    controller: _password,
                    obscureText: true,
                    enabled: !_busy,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe actuel',
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Renseignez votre mot de passe actuel.'
                        : null,
                  ),
                ] else
                  const Text(
                    'Reconnectez-vous avec votre mode de connexion habituel avant de supprimer votre compte.',
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  LoyaloAuthError(message: _error!),
                ],
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            key: const Key('settings-delete-confirm'),
            onPressed: _busy || !supported ? null : _confirm,
            child: const Text(
              'Supprimer',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}
