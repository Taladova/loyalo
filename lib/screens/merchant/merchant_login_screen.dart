import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../services/analytics_service.dart';
import '../../services/auth_service.dart';
import '../../services/remember_me_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/loyalo_logo.dart';
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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _rememberMeService = RememberMeService();
  bool _loading = false;
  bool _rememberMe = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  Future<void> _prefill() async {
    final (email, password) = await _rememberMeService.loadMerchant();
    if (!mounted) return;
    setState(() {
      _emailController.text = email;
      _passwordController.text = password;
    });
  }

  Future<void> _login() async {
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
      repo.startListeningForMerchant(restaurantId);
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
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: LoyaloWordmark(markSize: 84, showTagline: false),
              ),
              const SizedBox(height: 12),
              const Text(
                'Connexion commerçant',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Mot de passe'),
                obscureText: true,
                onSubmitted: (_) => _login(),
              ),
              CheckboxListTile(
                value: _rememberMe,
                onChanged: (v) => setState(() => _rememberMe = v ?? true),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: AppColors.teal,
                title: const Text(
                  'Se souvenir de moi',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _forgotPassword,
                  child: const Text(
                    'Mot de passe oublié ?',
                    style: TextStyle(color: AppColors.textGray),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 12.5,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _loading ? null : _login,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Se connecter'),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MerchantSignupScreen(),
                  ),
                ),
                child: const Text('Créer un compte'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
