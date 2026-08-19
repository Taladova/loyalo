import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../services/analytics_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/loyalo_logo.dart';
import 'merchant_root_screen.dart';

class MerchantSignupScreen extends ConsumerStatefulWidget {
  const MerchantSignupScreen({super.key});

  @override
  ConsumerState<MerchantSignupScreen> createState() => _MerchantSignupScreenState();
}

class _MerchantSignupScreenState extends ConsumerState<MerchantSignupScreen> {
  final _restaurantController = TextEditingController();
  final _cuisineController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _thresholdController = TextEditingController(text: '10');
  final _rewardController = TextEditingController(text: 'Un repas offert');
  final _authService = AuthService();
  bool _loading = false;
  String? _error;

  Future<void> _createAccount() async {
    final name = _restaurantController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Merci de renseigner le nom du restaurant, l\'email et le mot de passe.');
      return;
    }

    final threshold = int.tryParse(_thresholdController.text.trim());
    if (threshold == null || threshold <= 0) {
      setState(() => _error = 'Le palier de récompense doit être un nombre positif.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = await _authService.signUpOrSignIn(email: email, password: password);
      final repo = ref.read(loyaltyRepositoryProvider);
      repo.startListening();

      final restaurantId = await repo.createRestaurant(
        name: name,
        cuisine: _cuisineController.text.trim().isEmpty ? 'Restaurant' : _cuisineController.text.trim(),
        rewardThreshold: threshold,
        rewardLabel: _rewardController.text.trim().isEmpty ? 'Récompense fidélité' : _rewardController.text.trim(),
      );
      await repo.linkMerchantToRestaurant(user.uid, restaurantId);
      ref.read(currentMerchantRestaurantIdProvider.notifier).state = restaurantId;
      AnalyticsService.logMerchantSignUp();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte commerçant')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: LoyaloWordmark(markSize: 64, showTagline: false)),
              const SizedBox(height: 24),
              const Text('Votre restaurant', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 12),
              TextField(
                controller: _restaurantController,
                decoration: const InputDecoration(labelText: 'Nom du restaurant'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _cuisineController,
                decoration: const InputDecoration(labelText: 'Type de cuisine (optionnel)'),
              ),
              const SizedBox(height: 24),
              const Text('Programme de fidélité', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 12),
              TextField(
                controller: _thresholdController,
                decoration: const InputDecoration(labelText: 'Visites requises pour la récompense'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _rewardController,
                decoration: const InputDecoration(labelText: 'Récompense offerte'),
              ),
              const SizedBox(height: 24),
              const Text('Vos identifiants', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 12),
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
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
              ],
              const SizedBox(height: 22),
              ElevatedButton(
                onPressed: _loading ? null : _createAccount,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                      )
                    : const Text('Créer mon espace commerçant'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Votre restaurant est enregistré immédiatement.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppColors.textGray),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
