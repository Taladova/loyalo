import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../services/analytics_service.dart';
import '../../services/auth_service.dart';
import 'merchant_root_screen.dart';
import 'merchant_signup_view.dart';
import 'rewards_management_screen.dart';

class MerchantSignupScreen extends ConsumerStatefulWidget {
  const MerchantSignupScreen({super.key});

  @override
  ConsumerState<MerchantSignupScreen> createState() =>
      _MerchantSignupScreenState();
}

class _MerchantSignupScreenState extends ConsumerState<MerchantSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _restaurantController = TextEditingController();
  final _cuisineController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _restaurantController.dispose();
    _cuisineController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) => value == null || value.trim().isEmpty
      ? 'Renseignez le nom du commerce.'
      : null;
  String? _validateEmail(String? value) => value == null || value.trim().isEmpty
      ? 'Renseignez votre adresse email.'
      : null;
  String? _validatePassword(String? value) =>
      value == null || value.isEmpty ? 'Renseignez votre mot de passe.' : null;

  Future<void> _createAccount() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final name = _restaurantController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await _authService.signUpOrSignIn(
        email: email,
        password: password,
      );
      if (!mounted) return;
      final repo = ref.read(loyaltyRepositoryProvider);
      await repo.stopListening();
      final restaurant = await repo.loadOrCreateMerchantDraft(
        ownerId: user.uid,
        name: name,
        cuisine: _cuisineController.text.trim().isEmpty
            ? 'Restaurant'
            : _cuisineController.text.trim(),
        email: email,
      );
      if (!mounted) return;
      repo.startListeningForMerchant(restaurant.id, ownerUid: user.uid);
      ref.read(currentMerchantRestaurantIdProvider.notifier).state =
          restaurant.id;
      AnalyticsService.logMerchantSignUp();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => restaurant.needsLoyaltySetup
              ? const RewardsManagementScreen(completeOnboarding: true)
              : const MerchantRootScreen(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = AuthService.readableError(e));
    } on StateError catch (e) {
      if (mounted) setState(() => _error = e.message.toString());
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Impossible de finaliser votre inscription. Réessayez pour reprendre la création de votre espace.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => LoyaloMerchantSignupView(
    formKey: _formKey,
    nameController: _restaurantController,
    activityController: _cuisineController,
    emailController: _emailController,
    passwordController: _passwordController,
    validateName: _validateName,
    validateEmail: _validateEmail,
    validatePassword: _validatePassword,
    obscurePassword: _obscurePassword,
    loading: _loading,
    error: _error,
    onTogglePassword: () =>
        setState(() => _obscurePassword = !_obscurePassword),
    onSubmit: _createAccount,
    onBack: () => Navigator.of(context).maybePop(),
  );
}
