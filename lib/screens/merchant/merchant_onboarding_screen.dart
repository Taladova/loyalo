import 'package:flutter/material.dart';

import '../onboarding_screen.dart';
import 'merchant_login_screen.dart';

const _merchantPages = [
  OnboardingPageData(
    icon: Icons.storefront_outlined,
    title: 'Créez votre espace commerçant',
    description:
        'Enregistrez votre restaurant en quelques secondes et définissez vos propres règles de '
        'récompense fidélité.',
  ),
  OnboardingPageData(
    icon: Icons.pin_outlined,
    title: 'Validez chaque visite en 2 secondes',
    description:
        'Le client vous montre son code personnel à 6 chiffres, vous le saisissez — la visite est '
        'enregistrée, sans triche possible.',
  ),
  OnboardingPageData(
    icon: Icons.bar_chart,
    title: 'Suivez votre activité en temps réel',
    description:
        'Visites, nouveaux clients, récompenses distribuées : toutes vos statistiques, mises à jour '
        'instantanément.',
  ),
];

/// Onboarding commerçant (3 écrans), affiché une seule fois au premier
/// accès à cet espace — variante de [OnboardingFlow] côté client.
class MerchantOnboardingScreen extends StatelessWidget {
  const MerchantOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingFlow(
      pages: _merchantPages,
      prefsKey: 'merchant_onboarding_seen',
      destination: MerchantLoginScreen(),
    );
  }
}
