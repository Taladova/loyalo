import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';
import '../../widgets/loyalo_auth_ui.dart';
import '../../widgets/loyalo_settings_ui.dart';
import '../../widgets/loyalo_ui.dart';

class MerchantPasswordScreen extends ConsumerStatefulWidget {
  const MerchantPasswordScreen({super.key, this.auth});
  final AuthService? auth;

  @override
  ConsumerState<MerchantPasswordScreen> createState() =>
      _MerchantPasswordScreenState();
}

class _MerchantPasswordScreenState
    extends ConsumerState<MerchantPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _feedback = GlobalKey();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirmation = TextEditingController();
  late final AuthService _auth;
  final _hidden = [true, true, true];
  bool _busy = false;
  bool _success = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _auth = widget.auth ?? AuthService();
  }

  @override
  void dispose() {
    _current.clear();
    _next.clear();
    _confirmation.clear();
    _current.dispose();
    _next.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _showFeedback() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _feedback.currentContext;
      if (mounted && target != null) {
        unawaited(
          Scrollable.ensureVisible(
            target,
            alignment: 0,
            duration: const Duration(milliseconds: 200),
          ),
        );
      }
    });
  }

  Future<void> _submit() async {
    if (_busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final invalid = _form.currentState!.validateGranularly();
    if (invalid.isNotEmpty) {
      await WidgetsBinding.instance.endOfFrame;
      if (mounted && invalid.first.context.mounted) {
        await Scrollable.ensureVisible(invalid.first.context, alignment: 0.2);
      }
      return;
    }
    if (ref.read(currentMerchantRestaurantIdProvider) == null ||
        _auth.currentUser == null) {
      setState(
        () => _error =
            'Votre session commerçant est indisponible. Reconnectez-vous.',
      );
      _showFeedback();
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _auth.changePassword(
        currentPassword: _current.text,
        newPassword: _next.text,
      );
      _current.clear();
      _next.clear();
      _confirmation.clear();
      if (mounted) setState(() => _success = true);
    } catch (error) {
      _current.clear();
      if (mounted) setState(() => _error = AuthService.accountError(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _showFeedback();
      }
    }
  }

  Widget _password(
    String id,
    String label,
    TextEditingController controller,
    int index,
    String? Function(String?) validator,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Text(
            label,
            style: const TextStyle(
              color: LoyaloAuthColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: label,
          child: TextFormField(
            key: ValueKey('password-$id'),
            controller: controller,
            style: const TextStyle(color: LoyaloAuthColors.textPrimary),
            enabled: !_busy,
            obscureText: _hidden[index],
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.visiblePassword,
            autofillHints: [
              index == 0 ? AutofillHints.password : AutofillHints.newPassword,
            ],
            textInputAction: index == 2
                ? TextInputAction.done
                : TextInputAction.next,
            onFieldSubmitted: index == 2 ? (_) => _submit() : null,
            validator: validator,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 16,
              ),
              suffixIcon: IconButton(
                tooltip: _hidden[index] ? 'Afficher $label' : 'Masquer $label',
                onPressed: _busy
                    ? null
                    : () => setState(() => _hidden[index] = !_hidden[index]),
                icon: Icon(
                  _hidden[index]
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final supported =
        _auth.supportsPasswordAuthentication &&
        ref.watch(currentMerchantRestaurantIdProvider) != null;
    return PopScope(
      canPop: !_busy,
      child: LoyaloSettingsFrame(
        title: 'Modifier mon mot de passe',
        onBack: _busy ? null : () => Navigator.of(context).maybePop(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(key: _feedback),
            if (_error != null) ...[
              LoyaloAuthError(message: _error!),
              const SizedBox(height: 12),
            ],
            if (_success) ...[
              LoyaloCard(
                color: Colors.white,
                child: Semantics(
                  liveRegion: true,
                  child: const Text(
                    'Votre mot de passe a été modifié.',
                    style: TextStyle(
                      color: LoyaloAuthColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              LoyaloAuthPrimaryButton(
                label: 'Retour aux paramètres',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ] else if (!supported)
              LoyaloCard(
                color: Colors.white,
                child: Text(
                  user == null
                      ? 'Votre session a expiré. Reconnectez-vous pour continuer.'
                      : 'Ce compte utilise un autre mode de connexion. La modification par mot de passe n’est pas disponible.',
                  style: const TextStyle(color: LoyaloAuthColors.textPrimary),
                ),
              )
            else
              Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LoyaloCard(
                      color: Colors.white,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Email de connexion',
                            style: TextStyle(
                              color: LoyaloAuthColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user!.email ?? 'Indisponible',
                            style: const TextStyle(
                              color: LoyaloAuthColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Confirmez votre mot de passe actuel pour sécuriser la modification.',
                            style: TextStyle(
                              color: LoyaloAuthColors.textSecondary,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _password(
                            'current',
                            'Mot de passe actuel',
                            _current,
                            0,
                            (value) => value == null || value.isEmpty
                                ? 'Renseignez votre mot de passe actuel.'
                                : null,
                          ),
                          _password(
                            'new',
                            'Nouveau mot de passe',
                            _next,
                            1,
                            (value) => value == null || value.length < 6
                                ? 'Utilisez au moins 6 caractères.'
                                : null,
                          ),
                          _password(
                            'confirm',
                            'Confirmer le nouveau mot de passe',
                            _confirmation,
                            2,
                            (value) =>
                                value != _next.text ||
                                    value == null ||
                                    value.isEmpty
                                ? 'Les mots de passe ne correspondent pas.'
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    LoyaloAuthPrimaryButton(
                      key: const Key('password-save'),
                      label: 'Enregistrer le mot de passe',
                      loading: _busy,
                      onPressed: _busy ? null : _submit,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
