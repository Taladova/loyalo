import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../services/analytics_service.dart';
import '../../services/auth_service.dart';
import '../../services/remember_me_service.dart';
import '../../widgets/loyalo_auth_ui.dart';
import '../client/client_root_screen.dart';
import 'client_signup_screen.dart';

class ClientLoginScreen extends ConsumerStatefulWidget {
  const ClientLoginScreen({super.key});

  @override
  ConsumerState<ClientLoginScreen> createState() => _ClientLoginScreenState();
}

class _ClientLoginScreenState extends ConsumerState<ClientLoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  final _authService = AuthService();
  final _rememberMeService = RememberMeService();

  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  bool _loading = false;
  bool _rememberMe = true;
  bool _obscurePassword = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween(
      begin: const Offset(0, 0.025),
      end: Offset.zero,
    ).animate(_fadeAnimation);
    _prefill();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _prefill() async {
    final (_, email, password) = await _rememberMeService.loadClient();
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
    return LoyaloAuthLayout(
      title: 'Connexion client',
      description:
          'Accédez à votre compte Loyalo et profitez de vos avantages.',
      formKey: _formKey,
      emailKey: const Key('client-login-email'),
      passwordKey: const Key('client-login-password'),
      emailController: _emailController,
      passwordController: _passwordController,
      passwordFocusNode: _passwordFocusNode,
      obscurePassword: _obscurePassword,
      rememberMe: _rememberMe,
      loading: _loading,
      error: _error,
      validateEmail: _validateEmail,
      validatePassword: _validatePassword,
      onTogglePassword: () =>
          setState(() => _obscurePassword = !_obscurePassword),
      onRememberMeChanged: _loading
          ? null
          : (value) => setState(() => _rememberMe = value ?? true),
      onForgotPassword: _loading ? null : _forgotPassword,
      onLogin: _loading ? null : _login,
      onCreateAccount: _loading
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ClientSignupScreen()),
            ),
      onBack: _loading ? null : () => Navigator.of(context).maybePop(),
      fadeAnimation: _fadeAnimation,
      slideAnimation: _slideAnimation,
    );
  }
}
