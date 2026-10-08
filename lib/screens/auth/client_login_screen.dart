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
import 'client_signup_screen.dart';

class ClientLoginScreen extends ConsumerStatefulWidget {
  const ClientLoginScreen({super.key});

  @override
  ConsumerState<ClientLoginScreen> createState() => _ClientLoginScreenState();
}

class _ClientLoginScreenState extends ConsumerState<ClientLoginScreen> {
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
    final (_, email, password) = await _rememberMeService.loadClient();
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
      final firebaseUser = await _authService.signIn(
        email: email,
        password: password,
      );
      final repo = ref.read(loyaltyRepositoryProvider);
      final appUser = await repo.loadOrCreateClientProfile(
        uid: firebaseUser.uid,
        name: '',
        email: email,
      );
      repo.startListeningForClient(firebaseUser.uid);
      ref.read(currentUserProvider.notifier).state = appUser;
      AnalyticsService.logClientLogin();
      if (_rememberMe) {
        await _rememberMeService.saveClient(
          name: appUser.name,
          email: email,
          password: password,
        );
      } else {
        await _rememberMeService.clearClient();
      }
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

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage(
        'Mot de passe oublié',
        'Renseignez votre email ci-dessus puis réessayez.',
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
                'Connexion cliente',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 28),
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
                    : const Text('Se connecter'),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ClientSignupScreen()),
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
