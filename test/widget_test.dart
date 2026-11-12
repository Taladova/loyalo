import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:loyalo/screens/welcome_screen.dart';

// LoyaloApp démarre maintenant sur AuthGateScreen (pour retrouver une
// session déjà connectée), qui touche Firebase dès sa construction — donc
// pas testable en environnement `flutter test` pur. On teste directement
// WelcomeScreen, qui elle ne dépend de rien côté Firebase.
// La logique métier (anti-fraude, récompenses) est testée séparément dans
// loyalty_repository_test.dart avec un Firestore simulé.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'merchant_onboarding_seen': true});
  });

  testWidgets('Affiche l\'écran d\'accueil avec le choix du rôle', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: WelcomeScreen())),
    );

    await tester.pumpAndSettle();

    expect(find.byType(Image), findsNWidgets(2));
    expect(find.textContaining('Découvrez'), findsOneWidget);
    expect(find.textContaining('Cumulez'), findsOneWidget);
    expect(find.textContaining('Profitez'), findsOneWidget);
    expect(find.text('Je suis un client'), findsOneWidget);
    expect(find.text('Je suis commerçant'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reste utilisable sur un petit écran avec texte agrandi', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.35)),
            child: WelcomeScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Je suis un client'), findsOneWidget);
    expect(find.text('Je suis commerçant'), findsOneWidget);
    expect(find.byType(Scrollable), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
