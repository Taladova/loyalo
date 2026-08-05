import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:loyalo/screens/welcome_screen.dart';

// LoyaloApp démarre maintenant sur AuthGateScreen (pour retrouver une
// session déjà connectée), qui touche Firebase dès sa construction — donc
// pas testable en environnement `flutter test` pur. On teste directement
// WelcomeScreen, qui elle ne dépend de rien côté Firebase.
// La logique métier (anti-fraude, récompenses) est testée séparément dans
// loyalty_repository_test.dart avec un Firestore simulé.
void main() {
  testWidgets('Affiche l\'écran d\'accueil avec le choix du rôle', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: WelcomeScreen()),
    ));

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Je suis un client'), findsOneWidget);
    expect(find.text('Je suis commerçant'), findsOneWidget);
    expect(find.text('Connexion'), findsOneWidget);
  });
}
