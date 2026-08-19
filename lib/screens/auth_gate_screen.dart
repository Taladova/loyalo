import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/app_providers.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../theme/app_theme.dart';
import '../widgets/loyalo_logo.dart';
import 'client/client_root_screen.dart';
import 'merchant/merchant_root_screen.dart';
import 'onboarding_screen.dart';
import 'welcome_screen.dart';

/// Premier écran affiché au lancement de l'app. Firebase Auth garde la
/// session active d'un lancement à l'autre : si un compte est déjà
/// connecté, on saute directement au bon espace (client ou commerçant)
/// sans redemander les identifiants.
class AuthGateScreen extends ConsumerStatefulWidget {
  const AuthGateScreen({super.key});

  @override
  ConsumerState<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends ConsumerState<AuthGateScreen> {
  // `timeout()` n'annule pas l'opération d'origine, il arrête juste de
  // l'attendre : si celle-ci finit quand même par répondre après coup
  // (juste lente, pas bloquée), elle appellerait _goTo une seconde fois
  // pendant que la navigation de secours est déjà en cours, ce qui fait
  // planter le Navigator. Ce verrou garantit une seule navigation.
  bool _navigated = false;
  bool _needsUnlock = false;

  @override
  void initState() {
    super.initState();
    // Attend la fin de la toute première frame avant de naviguer : le
    // Navigator est encore verrouillé pendant le montage initial de
    // l'arbre de widgets, donc pousser une route depuis initState()
    // directement fait planter l'app au démarrage.
    WidgetsBinding.instance.addPostFrameCallback((_) => _resume());
  }

  Future<void> _resume() async {
    try {
      final firebaseUser = AuthService().currentUser;
      // Le verrou biométrique ne concerne qu'une session déjà active : pas
      // besoin de Face ID pour arriver sur l'écran de connexion classique.
      if (firebaseUser != null && await BiometricService().isEnabled()) {
        final unlocked = await BiometricService().authenticate();
        if (!unlocked) {
          if (mounted) setState(() => _needsUnlock = true);
          return;
        }
      }
      await _tryResume().timeout(const Duration(seconds: 15));
    } catch (e, st) {
      // Ne jamais rester bloqué sur le splash, quelle que soit la cause
      // (réseau, permissions, session invalide, timeout...).
      debugPrint('AuthGateScreen: échec de la reprise de session -> $e\n$st');
      try {
        ref.read(loyaltyRepositoryProvider).stopListening();
        await AuthService().signOut();
      } catch (_) {
        // best effort
      }
      _goTo(const WelcomeScreen());
    }
  }

  Future<void> _retryUnlock() async {
    setState(() => _needsUnlock = false);
    await _resume();
  }

  Future<void> _tryResume() async {
    final firebaseUser = AuthService().currentUser;
    if (firebaseUser == null) {
      await _goToStart();
      return;
    }

    final repo = ref.read(loyaltyRepositoryProvider);
    repo.startListening();

    final restaurantId = await repo.restaurantIdForMerchant(firebaseUser.uid);
    if (restaurantId != null) {
      ref.read(currentMerchantRestaurantIdProvider.notifier).state = restaurantId;
      _goTo(const MerchantRootScreen());
      return;
    }

    final appUser = await repo.loadOrCreateClientProfile(
      uid: firebaseUser.uid,
      name: firebaseUser.displayName ?? '',
      email: firebaseUser.email ?? '',
    );
    ref.read(currentUserProvider.notifier).state = appUser;
    _goTo(const ClientRootScreen());
  }

  void _goTo(Widget screen) {
    if (!mounted || _navigated) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => screen));
  }

  /// Aucune session active : direction l'accueil classique, sauf au tout
  /// premier lancement de l'app, où on montre d'abord l'onboarding.
  Future<void> _goToStart() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('onboarding_seen') ?? false;
    _goTo(seen ? const WelcomeScreen() : const OnboardingScreen());
  }

  @override
  Widget build(BuildContext context) {
    if (_needsUnlock) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const LoyaloWordmark(markSize: 84, showTagline: false),
              const SizedBox(height: 28),
              const Icon(Icons.fingerprint, size: 56, color: AppColors.purple),
              const SizedBox(height: 12),
              const Text('Déverrouillez pour continuer', style: TextStyle(fontSize: 14, color: AppColors.textGray)),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _retryUnlock, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }

    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LoyaloWordmark(markSize: 84, showTagline: false),
            SizedBox(height: 28),
            CircularProgressIndicator(color: AppColors.purple),
          ],
        ),
      ),
    );
  }
}
