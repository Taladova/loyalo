import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import '../widgets/loyalo_ui.dart';
import 'auth/client_login_screen.dart';
import 'merchant/merchant_login_screen.dart';
import 'merchant/merchant_onboarding_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(_fade);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openMerchantSpace(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('merchant_onboarding_seen') ?? false;
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => seen
            ? const MerchantLoginScreen()
            : const MerchantOnboardingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFF071426);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -120,
              right: -120,
              child: _Glow(color: AppColors.teal.withValues(alpha: 0.18)),
            ),
            Positioned(
              bottom: -140,
              left: -120,
              child: _Glow(color: AppColors.purple.withValues(alpha: 0.22)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: Column(
                    children: [
                      const Spacer(flex: 3),
                      Image.asset(
                        'assets/images/logo-app-loyalo-light.png',
                        width: 300,
                        fit: BoxFit.contain,
                      ),
                      const Spacer(flex: 4),
                      LoyaloGradientButton(
                        label: 'Je suis un client',
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ClientLoginScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => _openMerchantSpace(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                          side: BorderSide(
                            color: AppColors.teal.withValues(alpha: 0.9),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text('Je suis commerçant'),
                      ),
                      const Spacer(flex: 2),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final Color color;

  const _Glow({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      height: 260,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}
