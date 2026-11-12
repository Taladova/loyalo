import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../services/analytics_service.dart';
import '../../services/auth_service.dart';
import '../../services/remember_me_service.dart';
import '../../widgets/loyalo_auth_ui.dart';
import '../client/client_root_screen.dart';

class ClientSignupScreen extends ConsumerStatefulWidget {
  const ClientSignupScreen({super.key});

  @override
  ConsumerState<ClientSignupScreen> createState() => _ClientSignupScreenState();
}

class _ClientSignupScreenState extends ConsumerState<ClientSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _referralCodeController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _referralFocusNode = FocusNode();
  final _authService = AuthService();
  final _rememberMeService = RememberMeService();
  bool _loading = false;
  bool _showReferralField = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _referralCodeController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _referralFocusNode.dispose();
    super.dispose();
  }

  String? _validateName(String? value) =>
      value == null || value.trim().isEmpty ? 'Renseignez votre prénom.' : null;

  String? _validateEmail(String? value) => value == null || value.trim().isEmpty
      ? 'Renseignez votre adresse email.'
      : null;

  String? _validatePassword(String? value) =>
      value == null || value.isEmpty ? 'Renseignez votre mot de passe.' : null;

  Future<void> _createAccount() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(
        () => _error =
            'Merci de renseigner votre prénom, votre email et un mot de passe.',
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final firebaseUser = await _authService.signUpOrSignIn(
        email: email,
        password: password,
      );
      final repo = ref.read(loyaltyRepositoryProvider);
      final appUser = await repo.loadOrCreateClientProfile(
        uid: firebaseUser.uid,
        name: name,
        email: email,
        referredByCode: _referralCodeController.text,
      );
      repo.startListeningForClient(firebaseUser.uid);
      ref.read(currentUserProvider.notifier).state = appUser;
      AnalyticsService.logClientLogin();
      await _rememberMeService.saveClient(
        name: name,
        email: email,
        password: password,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ClientRootScreen()),
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _error = AuthService.readableError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoyaloAuthScaffold(
      illustrationAsset: 'assets/images/signup/client_signup_hero.png',
      onBack: _loading ? null : () => Navigator.of(context).maybePop(),
      contentBuilder: (context, compact) => LoyaloAuthSurface(
        compact: compact,
        child: Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              children: [
                const LoyaloAuthHeading(
                  title: 'Créer un compte client',
                  description:
                      'Créez votre compte et profitez de tous les avantages Loyalo.',
                  titleFontSize: 24,
                ),
                SizedBox(height: compact ? 12 : 16),
                LoyaloAuthTextField(
                  key: const Key('client-signup-name'),
                  controller: _nameController,
                  validator: _validateName,
                  hintText: 'Votre prénom',
                  prefixIcon: Icons.person_outline_rounded,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.givenName],
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _emailFocusNode.requestFocus(),
                  enabled: !_loading,
                ),
                const SizedBox(height: 10),
                LoyaloAuthTextField(
                  key: const Key('client-signup-email'),
                  controller: _emailController,
                  focusNode: _emailFocusNode,
                  validator: _validateEmail,
                  hintText: 'Email',
                  prefixIcon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                  enabled: !_loading,
                ),
                const SizedBox(height: 10),
                LoyaloAuthTextField(
                  key: const Key('client-signup-password'),
                  controller: _passwordController,
                  focusNode: _passwordFocusNode,
                  validator: _validatePassword,
                  hintText: 'Mot de passe',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscurePassword,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _createAccount(),
                  enabled: !_loading,
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? 'Afficher le mot de passe'
                        : 'Masquer le mot de passe',
                    onPressed: _loading
                        ? null
                        : () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                if (!_showReferralField)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _loading
                          ? null
                          : () => setState(() => _showReferralField = true),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerLeft,
                      ),
                      child: const Text(
                        'J’ai un code parrain',
                        style: TextStyle(
                          color: LoyaloAuthColors.purple,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                else
                  LoyaloAuthTextField(
                    key: const Key('client-signup-referral'),
                    controller: _referralCodeController,
                    focusNode: _referralFocusNode,
                    validator: (_) => null,
                    hintText: 'Code parrain (optionnel)',
                    prefixIcon: Icons.redeem_outlined,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _createAccount(),
                    enabled: !_loading,
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 4),
                  LoyaloAuthError(message: _error!),
                ],
                const SizedBox(height: 8),
                LoyaloAuthPrimaryButton(
                  label: 'Créer mon compte',
                  onPressed: _loading ? null : _createAccount,
                  loading: _loading,
                ),
                const SizedBox(height: 14),
                const LoyaloAuthSecurityNote(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
