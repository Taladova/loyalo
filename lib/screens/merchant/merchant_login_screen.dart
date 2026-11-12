import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../services/analytics_service.dart';
import '../../services/auth_service.dart';
import '../../services/remember_me_service.dart';
import '../../widgets/loyalo_auth_ui.dart';
import 'merchant_establishment_screen.dart';
import 'merchant_root_screen.dart';
import 'merchant_signup_screen.dart';

class MerchantLoginScreen extends ConsumerStatefulWidget {
  const MerchantLoginScreen({super.key});

  @override
  ConsumerState<MerchantLoginScreen> createState() =>
      _MerchantLoginScreenState();
}

class _MerchantLoginScreenState extends ConsumerState<MerchantLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  final _authService = AuthService();
  final _rememberMeService = RememberMeService();
  bool _loading = false;
  bool _rememberMe = true;
  bool _obscurePassword = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _prefill() async {
    final (email, password) = await _rememberMeService.loadMerchant();
    if (!mounted) return;
    setState(() {
      _emailController.text = email;
      _passwordController.text = password;
    });
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Renseignez votre adresse email.';
    final valid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
    return valid ? null : 'Saisissez une adresse email valide.';
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Renseignez votre mot de passe.';
    return null;
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(
        () => _error = 'Merci de renseigner votre email et votre mot de passe.',
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = await _authService.signIn(email: email, password: password);
      final repo = ref.read(loyaltyRepositoryProvider);
      final restaurantId = await repo.restaurantIdForMerchant(user.uid);
      if (restaurantId == null) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) =>
                const MerchantEstablishmentScreen(requireSetup: true),
          ),
        );
        return;
      }
      await repo.stopListening();
      repo.startListeningForMerchant(restaurantId, ownerUid: user.uid);
      ref.read(currentMerchantRestaurantIdProvider.notifier).state =
          restaurantId;
      AnalyticsService.logMerchantLogin();
      if (_rememberMe) {
        await _rememberMeService.saveMerchant(email: email, password: password);
      } else {
        await _rememberMeService.clearMerchant();
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MerchantRootScreen()),
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _error = AuthService.readableError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage(
        'Mot de passe oublié',
        'Renseignez votre email professionnel ci-dessus puis réessayez.',
      );
      return;
    }
    try {
      await _authService.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      _showMessage(
        'Email envoyé',
        'Un lien de réinitialisation a été envoyé à $email.',
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showMessage('Mot de passe oublié', AuthService.readableError(e));
    }
  }

  void _showMessage(String title, String message) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LoyaloAuthLayout(
      title: 'Connexion commerçant',
      description:
          'Accédez à votre espace professionnel Loyalo et fidélisez vos clients.',
      titleFontSize: 24,
      createAccountIcon: Icons.add_business_outlined,
      formKey: _formKey,
      emailKey: const Key('merchant-login-email'),
      passwordKey: const Key('merchant-login-password'),
      emailController: _emailController,
      passwordController: _passwordController,
      passwordFocusNode: _passwordFocusNode,
      obscurePassword: _obscurePassword,
      rememberMe: _rememberMe,
      loading: _loading,
      error: _error,
      validateEmail: _validateEmail,
      validatePassword: _validatePassword,
      onTogglePassword: _loading
          ? null
          : () => setState(() => _obscurePassword = !_obscurePassword),
      onRememberMeChanged: _loading
          ? null
          : (value) => setState(() => _rememberMe = value ?? true),
      onForgotPassword: _loading ? null : _forgotPassword,
      onLogin: _loading ? null : _login,
      onCreateAccount: _loading
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MerchantSignupScreen()),
            ),
      onBack: _loading ? null : () => Navigator.of(context).maybePop(),
    );
  }
}
