import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      begin: const Offset(0, 0.035),
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
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _WelcomeColors.navy,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const _AtmosphericBackground(),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 720;
                  final veryCompact = constraints.maxHeight < 560;
                  final horizontalPadding = constraints.maxWidth < 360
                      ? 18.0
                      : 26.0;
                  final topPadding = compact ? 10.0 : 16.0;
                  const bottomPadding = 12.0;
                  final content = SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      topPadding,
                      horizontalPadding,
                      bottomPadding,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: 560,
                          minHeight: math.max(
                            0,
                            constraints.maxHeight - topPadding - bottomPadding,
                          ),
                        ),
                        child: _WelcomeContent(
                          compact: compact,
                          veryCompact: veryCompact,
                          onClientTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ClientLoginScreen(),
                            ),
                          ),
                          onMerchantTap: () => _openMerchantSpace(context),
                        ),
                      ),
                    ),
                  );

                  if (reduceMotion) return content;
                  return FadeTransition(
                    opacity: _fade,
                    child: SlideTransition(position: _slide, child: content),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeContent extends StatelessWidget {
  const _WelcomeContent({
    required this.compact,
    required this.veryCompact,
    required this.onClientTap,
    required this.onMerchantTap,
  });

  final bool compact;
  final bool veryCompact;
  final VoidCallback onClientTap;
  final VoidCallback onMerchantTap;

  @override
  Widget build(BuildContext context) {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final logoWidth = veryCompact ? 240.0 : (compact ? 260.0 : 310.0);
    final heroHeight = veryCompact ? 112.0 : (compact ? 132.0 : 170.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Semantics(
          image: true,
          label: 'Loyalo, la fidélité qui récompense',
          child: ExcludeSemantics(
            child: Image.asset(
              'assets/images/logo_loyalo_v3_light.png',
              width: logoWidth,
              height: veryCompact ? 76 : (compact ? 82 : 98),
              fit: BoxFit.contain,
              cacheWidth: (logoWidth * pixelRatio).ceil(),
            ),
          ),
        ),
        SizedBox(height: compact ? 4 : 8),
        ExcludeSemantics(
          child: SizedBox(
            height: heroHeight,
            width: double.infinity,
            child: Image.asset(
              'assets/images/welcome/welcome_hero.png',
              fit: BoxFit.contain,
              cacheHeight: (heroHeight * pixelRatio).ceil(),
            ),
          ),
        ),
        SizedBox(height: compact ? 8 : 14),
        const _BenefitsRow(),
        SizedBox(height: compact ? 18 : 28),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ProfileButton(
              label: 'Je suis un client',
              icon: Icons.person_outline_rounded,
              onTap: onClientTap,
              filled: true,
            ),
            const SizedBox(height: 12),
            _ProfileButton(
              label: 'Je suis commerçant',
              icon: Icons.storefront_rounded,
              onTap: onMerchantTap,
              filled: false,
            ),
          ],
        ),
        if (!compact) ...[
          const SizedBox(height: 20),
          const ExcludeSemantics(
            child: Opacity(opacity: 0.4, child: _TownDecoration()),
          ),
        ],
      ],
    );
  }
}

class _BenefitsRow extends StatelessWidget {
  const _BenefitsRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _BenefitItem(
            icon: Icons.storefront_rounded,
            iconColors: [Color(0xFFFF72E4), Color(0xFF8B5CF6)],
            label: 'Découvrez les commerces',
          ),
        ),
        _BenefitDivider(),
        Expanded(
          child: _BenefitItem(
            icon: Icons.monetization_on_rounded,
            iconColors: [Color(0xFFFFD34E), Color(0xFFFF8A00)],
            label: 'Cumulez des points',
          ),
        ),
        _BenefitDivider(),
        Expanded(
          child: _BenefitItem(
            icon: Icons.card_giftcard_rounded,
            iconColors: [Color(0xFFE879F9), Color(0xFF8B5CF6)],
            label: 'Profitez de récompenses',
          ),
        ),
      ],
    );
  }
}

class _BenefitDivider extends StatelessWidget {
  const _BenefitDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 8,
      height: 56,
      child: VerticalDivider(
        width: 8,
        thickness: 1,
        indent: 4,
        endIndent: 4,
        color: Color(0x38FFFFFF),
      ),
    );
  }
}

class _BenefitItem extends StatelessWidget {
  const _BenefitItem({
    required this.icon,
    required this.iconColors,
    required this.label,
  });

  final IconData icon;
  final List<Color> iconColors;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: iconColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 7),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            height: 1.14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ProfileButton extends StatelessWidget {
  const _ProfileButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.filled,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  static const _gradient = LinearGradient(
    colors: [Color(0xFF15E5D1), Color(0xFF168CFF), Color(0xFFB112F4)],
  );

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(28);
    final content = Material(
      color: filled ? Colors.transparent : _WelcomeColors.navy,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: filled ? Colors.white : _WelcomeColors.teal,
                  size: 26,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: _gradient,
          borderRadius: radius,
          boxShadow: filled
              ? [
                  BoxShadow(
                    color: const Color(0xFF00D9FF).withValues(alpha: 0.27),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: EdgeInsets.all(filled ? 0 : 1.6),
          child: content,
        ),
      ),
    );
  }
}

class _AtmosphericBackground extends StatelessWidget {
  const _AtmosphericBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: _WelcomeColors.navy),
          Positioned(
            top: -180,
            right: -150,
            child: _Glow(
              color: _WelcomeColors.teal.withValues(alpha: 0.34),
              size: 360,
            ),
          ),
          Positioned(
            top: -210,
            left: -175,
            child: _Glow(
              color: _WelcomeColors.purple.withValues(alpha: 0.32),
              size: 360,
            ),
          ),
          Positioned(
            bottom: -210,
            right: -170,
            child: _Glow(
              color: _WelcomeColors.purple.withValues(alpha: 0.30),
              size: 390,
            ),
          ),
          Positioned(
            bottom: -260,
            left: -180,
            child: _Glow(
              color: _WelcomeColors.blue.withValues(alpha: 0.28),
              size: 430,
            ),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
          stops: const [0, 1],
        ),
      ),
    );
  }
}

class _TownDecoration extends StatelessWidget {
  const _TownDecoration();

  @override
  Widget build(BuildContext context) {
    const height = 90.0;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Image.asset(
        'assets/images/welcome/welcome_city.png',
        fit: BoxFit.contain,
        cacheHeight: (height * MediaQuery.devicePixelRatioOf(context)).ceil(),
      ),
    );
  }
}

abstract final class _WelcomeColors {
  static const navy = Color(0xFF000B27);
  static const teal = Color(0xFF18E0D2);
  static const blue = Color(0xFF168CFF);
  static const purple = Color(0xFF9E19F5);
}
