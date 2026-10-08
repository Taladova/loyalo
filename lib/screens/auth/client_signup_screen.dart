import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../services/analytics_service.dart';
import '../../services/auth_service.dart';
import '../../services/remember_me_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/loyalo_logo.dart';
import '../client/client_root_screen.dart';

class ClientSignupScreen extends ConsumerStatefulWidget {
  const ClientSignupScreen({super.key});

  @override
  ConsumerState<ClientSignupScreen> createState() => _ClientSignupScreenState();
}

class _ClientSignupScreenState extends ConsumerState<ClientSignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _referralCodeController = TextEditingController();
  final _authService = AuthService();
  final _rememberMeService = RememberMeService();
  bool _loading = false;
  bool _showReferralField = false;
  String? _error;

  Future<void> _createAccount() async {
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
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: LoyaloWordmark(markSize: 64, showTagline: false),
              ),
              const SizedBox(height: 24),
              const Text(
                'Votre compte est créé et enregistré immédiatement.',
                style: TextStyle(fontSize: 12, color: AppColors.textGray),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Votre prénom'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Mot de passe'),
                obscureText: true,
                onSubmitted: (_) => _createAccount(),
              ),
              const SizedBox(height: 4),
              if (!_showReferralField)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() => _showReferralField = true),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                    ),
                    child: const Text(
                      'J\'ai un code parrain',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ),
                )
              else
                TextField(
                  controller: _referralCodeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Code parrain (optionnel)',
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 12.5,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              ElevatedButton(
                onPressed: _loading ? null : _createAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teal,
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Créer mon compte'),
              ),
              const SizedBox(height: 14),
              const Text(
                'Vos données sont stockées de façon sécurisée.',
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
