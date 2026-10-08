import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_actions/quick_actions.dart';

import 'providers/app_providers.dart';
import 'screens/auth_gate_screen.dart';
import 'screens/client/my_code_screen.dart';
import 'services/analytics_service.dart';
import 'theme/app_theme.dart';

final loyaloNavigatorKey = GlobalKey<NavigatorState>();

class LoyaloApp extends ConsumerStatefulWidget {
  const LoyaloApp({super.key});

  @override
  ConsumerState<LoyaloApp> createState() => _LoyaloAppState();
}

class _LoyaloAppState extends ConsumerState<LoyaloApp> {
  final _quickActions = QuickActions();

  @override
  void initState() {
    super.initState();
    // Raccourci "Mon code" accessible par appui long sur l'icône de l'app
    // (équivalent léger d'une carte de fidélité dans le portefeuille, sans
    // dépendre d'un compte développeur payant). N'existe que sur mobile :
    // aucune implémentation web pour ce plugin.
    if (!kIsWeb) {
      _quickActions.initialize((type) {
        if (type == 'show_code') _openMyCode();
      });
      _quickActions.setShortcutItems(const [
        ShortcutItem(
          type: 'show_code',
          localizedTitle: 'Mon code',
          icon: 'ic_shortcut_code',
        ),
      ]);
    }
  }

  Future<void> _openMyCode() async {
    // Au lancement à froid, la session Firebase est encore en train de se
    // résoudre dans AuthGateScreen : on patiente un peu avant d'abandonner.
    for (var i = 0; i < 10; i++) {
      if (ref.read(currentUserProvider) != null) {
        loyaloNavigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const MyCodeScreen()),
        );
        return;
      }
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: loyaloNavigatorKey,
      title: 'Loyalo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      navigatorObservers: [AnalyticsService.observer],
      // Sur navigateur desktop, l'app s'étire sur toute la largeur de la
      // fenêtre (boutons énormes, mise en page qui n'a plus de sens) : on
      // recadre le contenu à la largeur d'un téléphone, comme dans une
      // vitrine d'app, dès que l'écran est plus large qu'un mobile.
      builder: (context, child) => _MobileFrame(child: child),
      home: const AuthGateScreen(),
    );
  }
}

class _MobileFrame extends StatelessWidget {
  final Widget? child;

  const _MobileFrame({required this.child});

  static const _phoneWidth = 428.0;
  static const _breakpoint = 700.0;

  @override
  Widget build(BuildContext context) {
    final content = child ?? const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= _breakpoint) return content;

        final frameHeight = math.min(constraints.maxHeight - 48, 926.0);

        return Container(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.black
              : AppColors.navy,
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Positioned(left: -140, top: -160, child: _glow(AppColors.teal)),
              Positioned(
                right: -140,
                bottom: -160,
                child: _glow(AppColors.purple),
              ),
              SizedBox(
                width: _phoneWidth,
                height: frameHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 60,
                        spreadRadius: -6,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: content,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _glow(Color color) {
    return Container(
      width: 340,
      height: 340,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}
