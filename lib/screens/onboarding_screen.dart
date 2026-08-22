import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import 'welcome_screen.dart';

class OnboardingPageData {
  final IconData icon;
  final String title;
  final String description;

  const OnboardingPageData({required this.icon, required this.title, required this.description});
}

const _clientPages = [
  OnboardingPageData(
    icon: Icons.storefront_outlined,
    title: 'Découvrez vos commerces préférés',
    description: 'Retrouvez les restaurants et commerces partenaires autour de vous, et suivez votre progression '
        'vers votre prochaine récompense.',
  ),
  OnboardingPageData(
    icon: Icons.pin_outlined,
    title: 'Un code, à chaque visite',
    description: 'Présentez votre code personnel à 6 chiffres au commerçant — il se renouvelle régulièrement pour '
        'éviter toute fraude.',
  ),
  OnboardingPageData(
    icon: Icons.card_giftcard,
    title: 'Débloquez des récompenses',
    description: 'Cumulez vos visites et recevez automatiquement vos récompenses fidélité, sans carte en papier.',
  ),
];

/// Onboarding client (3 écrans), affiché une seule fois au tout premier
/// lancement. Fine enveloppe autour de [OnboardingFlow], le composant
/// générique réutilisé côté commerçant.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingFlow(
      pages: _clientPages,
      prefsKey: 'onboarding_seen',
      destination: WelcomeScreen(),
    );
  }
}

/// Composant générique d'introduction en plusieurs écrans, réutilisable
/// pour n'importe quel parcours (client, commerçant...) : mémorise dans
/// [prefsKey] qu'il a déjà été vu, pour ne jamais le réafficher ensuite.
class OnboardingFlow extends StatefulWidget {
  final List<OnboardingPageData> pages;
  final String prefsKey;
  final Widget destination;

  const OnboardingFlow({super.key, required this.pages, required this.prefsKey, required this.destination});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _pageController = PageController();
  int _index = 0;

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(widget.prefsKey, true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => widget.destination));
  }

  void _next() {
    if (_index == widget.pages.length - 1) {
      _finish();
      return;
    }
    _pageController.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == widget.pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 12, top: 4),
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('Passer', style: TextStyle(color: AppColors.textGray)),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final page = widget.pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 108,
                          height: 108,
                          decoration: const BoxDecoration(gradient: AppColors.brandGradient, shape: BoxShape.circle),
                          child: Icon(page.icon, color: Colors.white, size: 48),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textDark),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          page.description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14, color: AppColors.textGray, height: 1.5),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _index ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _index ? AppColors.purple : AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
              child: ElevatedButton(
                onPressed: _next,
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                child: Text(isLast ? 'Commencer' : 'Suivant'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
