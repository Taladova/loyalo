import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import '../widgets/loyalo_logo.dart';
import 'auth/client_login_screen.dart';
import 'merchant/merchant_login_screen.dart';
import 'merchant/merchant_onboarding_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Future<void> _openMerchantSpace(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('merchant_onboarding_seen') ?? false;
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => seen ? const MerchantLoginScreen() : const MerchantOnboardingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 3),
              const LoyaloWordmark(markSize: 108),
              const Spacer(flex: 4),
              ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ClientLoginScreen()),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('Je suis un client'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _openMerchantSpace(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.purple,
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('Je suis commerçant'),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ClientLoginScreen()),
                ),
                child: const Text('Connexion', style: TextStyle(color: AppColors.textGray)),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
