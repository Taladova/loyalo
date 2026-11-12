import 'dart:async';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:loyalo/models/app_user.dart';
import 'package:loyalo/providers/app_providers.dart';
import 'package:loyalo/screens/client/my_code_screen.dart';
import 'package:loyalo/screens/client/my_qr_code_screen.dart';
import 'package:loyalo/screens/merchant/client_search_screen.dart';
import 'package:loyalo/screens/merchant/merchant_root_screen.dart';
import 'package:loyalo/screens/merchant/validate_visit_screen.dart';
import 'package:loyalo/services/loyalty_repository.dart';
import 'package:loyalo/theme/app_theme.dart';
import 'package:loyalo/widgets/loyalo_logo.dart';
import 'package:loyalo/widgets/loyalo_merchant_dashboard_ui.dart';
import 'package:loyalo/widgets/loyalo_ui.dart';
import 'package:loyalo/widgets/loyalo_visit_validation_ui.dart';

import 'support/merchant_dashboard_fixture.dart';
import 'support/visit_validation_fixture.dart';

void visitTest(
  String name,
  Future<void> Function(WidgetTester, VisitValidationUiRepository) body,
) {
  testWidgets(name, (tester) async {
    final repo = VisitValidationUiRepository();
    try {
      await body(tester, repo);
    } finally {
      await tester.runAsync(repo.stopListening);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.runAsync(repo.database.close);
    }
  });
}

Future<void> pump(
  WidgetTester tester,
  VisitValidationUiRepository repo, {
  Widget screen = const ValidateVisitScreen(),
  Size size = const Size(390, 844),
  double scale = 1,
  TargetPlatform platform = TargetPlatform.iOS,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        loyaltyRepositoryProvider.overrideWith((ref) => repo),
        currentMerchantRestaurantIdProvider.overrideWith(
          (ref) => VisitValidationUiRepository.shop.id,
        ),
        currentUserProvider.overrideWith(
          (ref) => const AppUser(
            id: 'client-ui-09',
            name: 'Alex',
            email: 'alex@example.org',
            referralCode: 'ALEX09',
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light().copyWith(platform: platform),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get submit => find.byWidgetPredicate(
  (widget) =>
      widget is LoyaloGradientButton && widget.label == 'Valider la visite',
);
Finder method(String name) => find.byKey(ValueKey('visit-method-$name'));
Future<void> enterCode(WidgetTester tester, [String code = '012345']) async {
  for (final digit in code.split('')) {
    final key = find.widgetWithText(TextButton, digit);
    await tester.ensureVisible(key);
    await tester.tap(key);
    await tester.pump();
  }
}

Future<void> reach(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    FirebasePlatform.instance = DashboardTestCore();
    FirebaseAuthPlatform.instance = DashboardTestAuth();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/firebase_analytics'),
          (_) async => null,
        );
  });

  visitTest('trois méthodes, code initial et aucun logo décoratif', (
    tester,
    repo,
  ) async {
    await pump(tester, repo);
    expect(
      tester
          .widget<LoyaloVisitMethodSelector>(
            find.byType(LoyaloVisitMethodSelector),
          )
          .selected,
      LoyaloVisitMethod.code,
    );
    for (final name in ['scanner', 'code', 'search']) {
      expect(method(name), findsOneWidget);
      final size = tester.getSize(method(name));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    expect(find.byType(LoyaloWordmark), findsNothing);
    expect(find.byType(LoyaloDashboardMark), findsNothing);
    expect(repo.codes, isEmpty);
    expect(repo.validations, isEmpty);
    expect(tester.takeException(), isNull);
  });

  visitTest('scanner indisponible sans caméra, jeton ni validation simulée', (
    tester,
    repo,
  ) async {
    await pump(tester, repo);
    await tester.tap(method('scanner'));
    await tester.pumpAndSettle();
    expect(find.text('QR temporaire indisponible'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    expect(repo.codes, isEmpty);
    expect(repo.validations, isEmpty);
    final code = find.widgetWithText(
      LoyaloGradientButton,
      'Utiliser le code à 6 chiffres',
    );
    await reach(tester, code);
    await tester.tap(code);
    await tester.pumpAndSettle();
    expect(find.byType(LoyaloVisitCodePane), findsOneWidget);
  });

  visitTest(
    'code zéro initial, limite de six, effacement et validation existante',
    (tester, repo) async {
      await pump(tester, repo);
      await enterCode(tester, '0123456');
      expect(
        tester
            .widget<LoyaloVisitCodePane>(find.byType(LoyaloVisitCodePane))
            .digits,
        '012345',
      );
      final erase = find.widgetWithText(TextButton, '⌫');
      await tester.tap(erase);
      await tester.pump();
      expect(tester.widget<LoyaloGradientButton>(submit).onPressed, isNull);
      await enterCode(tester, '5');
      await reach(tester, submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(repo.codes, ['012345']);
      expect(repo.validations, [
        (userId: 'client-ui-09', restaurantId: 'visit-shop'),
      ]);
      expect(find.text('Visite validée'), findsOneWidget);
      expect(
        tester
            .widget<LoyaloVisitCodePane>(find.byType(LoyaloVisitCodePane))
            .digits,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  visitTest('double soumission bloquée pendant la réponse existante', (
    tester,
    repo,
  ) async {
    repo.validationGate = Completer<VisitResult>();
    await pump(tester, repo);
    await enterCode(tester);
    final callback = tester.widget<LoyaloGradientButton>(submit).onPressed!;
    callback();
    callback();
    await tester.pump();
    expect(repo.codes, hasLength(1));
    expect(repo.validations, hasLength(1));
    expect(tester.widget<LoyaloGradientButton>(submit).loading, isTrue);
    expect(tester.widget<TextButton>(method('scanner')).onPressed, isNull);
    repo.validationGate!.complete(repo.result());
    await tester.pumpAndSettle();
    expect(find.text('Visite validée'), findsOneWidget);
    expect(repo.validations, hasLength(1));
  });

  visitTest('code introuvable : aucune validation ni perte de la saisie', (
    tester,
    repo,
  ) async {
    repo.resolvedUser = null;
    await pump(tester, repo);
    await enterCode(tester);
    await reach(tester, submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('Code introuvable'), findsOneWidget);
    expect(repo.validations, isEmpty);
    expect(
      tester
          .widget<LoyaloVisitCodePane>(find.byType(LoyaloVisitCodePane))
          .digits,
      '012345',
    );
  });

  for (final stage in ['résolution', 'validation']) {
    visitTest('erreur de $stage : message lisible et nouvel essai possible', (
      tester,
      repo,
    ) async {
      if (stage == 'résolution') {
        repo.resolveError = StateError('private-test-error');
      } else {
        repo.validationError = StateError('private-test-error');
      }
      await pump(tester, repo);
      await enterCode(tester);
      await reach(tester, submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Validation indisponible'), findsOneWidget);
      expect(find.textContaining('private-test-error'), findsNothing);
      expect(tester.widget<LoyaloGradientButton>(submit).loading, isFalse);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      repo.resolveError = null;
      repo.validationError = null;
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Visite validée'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final value in ['01 23 45', 'not-a-code']) {
    visitTest('collage explicite : $value', (tester, repo) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            SystemChannels.platform,
            (call) async =>
                call.method == 'Clipboard.getData' ? {'text': value} : null,
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await pump(tester, repo);
      await tester.tap(find.byTooltip('Coller un code à 6 chiffres'));
      await tester.pumpAndSettle();
      if (value == '01 23 45') {
        expect(
          tester
              .widget<LoyaloVisitCodePane>(find.byType(LoyaloVisitCodePane))
              .digits,
          '012345',
        );
      } else {
        expect(find.text('Code invalide'), findsOneWidget);
        expect(tester.widget<LoyaloGradientButton>(submit).onPressed, isNull);
      }
      expect(repo.codes, isEmpty);
      expect(repo.validations, isEmpty);
    });
  }

  visitTest('recherche existante puis retour avec la saisie conservée', (
    tester,
    repo,
  ) async {
    await pump(tester, repo);
    await enterCode(tester, '012');
    await reach(tester, method('search'));
    await tester.tap(method('search'));
    await tester.pumpAndSettle();
    expect(find.byType(ClientSearchScreen), findsOneWidget);
    expect(find.text('Rechercher un client'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<LoyaloVisitCodePane>(find.byType(LoyaloVisitCodePane))
          .digits,
      '012',
    );
    expect(
      tester
          .widget<LoyaloVisitMethodSelector>(
            find.byType(LoyaloVisitMethodSelector),
          )
          .selected,
      LoyaloVisitMethod.code,
    );
    expect(repo.validations, isEmpty);
  });

  visitTest('clavier physique : chiffres et retour arrière', (
    tester,
    repo,
  ) async {
    await pump(tester, repo);
    Focus.of(tester.element(find.byType(LoyaloVisitCodePane))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.digit0, character: '0');
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1, character: '1');
    await tester.pump();
    expect(
      tester
          .widget<LoyaloVisitCodePane>(find.byType(LoyaloVisitCodePane))
          .digits,
      '01',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(
      tester
          .widget<LoyaloVisitCodePane>(find.byType(LoyaloVisitCodePane))
          .digits,
      '0',
    );
    expect(repo.validations, isEmpty);
  });

  visitTest(
    'fermer la page pendant la résolution ne valide rien après retour',
    (tester, repo) async {
      repo.codeGate = Completer<String?>();
      await pump(
        tester,
        repo,
        screen: const Scaffold(body: Text('Page précédente')),
      );
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(builder: (_) => const ValidateVisitScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await enterCode(tester);
      tester.widget<LoyaloGradientButton>(submit).onPressed!();
      await tester.pump();
      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      repo.codeGate!.complete('client-ui-09');
      await tester.pumpAndSettle();
      expect(find.text('Page précédente'), findsOneWidget);
      expect(repo.validations, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  visitTest('carte vers Mon QR code, retour et code quotidien conservés', (
    tester,
    repo,
  ) async {
    await pump(tester, repo, screen: const MyCodeScreen());
    final daily = repo.dailyCodeFor('client-ui-09').split('').join(' ');
    await reach(tester, find.byKey(const Key('open-my-qr-code')));
    await tester.tap(find.byKey(const Key('open-my-qr-code')));
    await tester.pumpAndSettle();
    expect(find.byType(MyQrCodeScreen), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('QR temporaire indisponible'), findsOneWidget);
    final back = find.widgetWithText(
      LoyaloGradientButton,
      'Voir mon code à 6 chiffres',
    );
    await reach(tester, back);
    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(find.text(daily), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(repo.validations, isEmpty);
    expect(tester.takeException(), isNull);
  });

  visitTest('la validation conserve les six onglets commerçant', (
    tester,
    repo,
  ) async {
    await pump(tester, repo, screen: const MerchantRootScreen());
    final bar = tester.widget<LoyaloMerchantBottomNav>(
      find.byType(LoyaloMerchantBottomNav),
    );
    expect(bar.items.map((e) => e.label), [
      'Accueil',
      'Clients',
      'Valider',
      'Récompenses',
      'Offres',
      'Stats',
    ]);
    bar.onTap(2);
    await tester.pumpAndSettle();
    expect(find.text('Valider une visite'), findsOneWidget);
    expect(find.byType(LoyaloVisitMethodSelector), findsOneWidget);
    expect(find.byType(LoyaloMerchantBottomNav), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in const [
    Size(320, 568),
    Size(390, 844),
    Size(430, 932),
    Size(360, 640),
    Size(412, 915),
  ]) {
    for (final scale in [1.0, 2.5]) {
      for (final client in [false, true]) {
        visitTest('QR non activé $size texte $scale client=$client', (
          tester,
          repo,
        ) async {
          await pump(
            tester,
            repo,
            size: size,
            scale: scale,
            platform: size.width == 360 || size.width == 412
                ? TargetPlatform.android
                : TargetPlatform.iOS,
            screen: client
                ? const MyQrCodeScreen()
                : const ValidateVisitScreen(),
          );
          if (!client) {
            await reach(tester, method('scanner'));
            await tester.tap(method('scanner'));
            await tester.pumpAndSettle();
          }
          expect(find.text('QR temporaire indisponible'), findsOneWidget);
          final notice = tester.getRect(
            find.text('QR temporaire indisponible'),
          );
          expect(notice.top, lessThan(size.height - 34));
          expect(notice.bottom, greaterThan(47));
          final button = find.widgetWithText(
            LoyaloGradientButton,
            client
                ? 'Voir mon code à 6 chiffres'
                : 'Utiliser le code à 6 chiffres',
          );
          await reach(tester, button);
          final rect = tester.getRect(button);
          expect(rect.top, greaterThanOrEqualTo(47));
          expect(rect.bottom, lessThanOrEqualTo(size.height - 34));
          expect(tester.takeException(), isNull);
          expect(repo.validations, isEmpty);
          expect(find.byType(QrImageView), findsNothing);
        });
      }
    }
  }
}
