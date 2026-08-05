import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/loyalo_logo.dart';
import 'client/client_root_screen.dart';
import 'merchant/merchant_root_screen.dart';
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

  Future<void> _tryResume() async {
    final firebaseUser = AuthService().currentUser;
    if (firebaseUser == null) {
      _goTo(const WelcomeScreen());
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

  @override
  Widget build(BuildContext context) {
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
