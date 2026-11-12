import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loyalo/providers/app_providers.dart';
import 'package:loyalo/screens/merchant/client_search_screen.dart';
import 'package:loyalo/screens/merchant/merchant_client_profile_screen.dart';
import 'package:loyalo/widgets/loyalo_auth_ui.dart';
import 'package:loyalo/widgets/loyalo_client_search_ui.dart';

import 'support/client_search_fixture.dart';

class _Observer extends NavigatorObserver {
  Route<dynamic>? latest;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      latest = route;
}

final _fixtures = <ClientSearchFixture>[];

void _testWidgets(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    try {
      await body(tester);
    } finally {
      // Les listeners Drift sont arrêtés avant la destruction du ProviderScope.
      // Leur annulation asynchrone ne doit pas survivre à la zone FakeAsync.
      await tester.runAsync(() async {
        for (final f in _fixtures) {
          await f.repo.stopListening();
        }
      });
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        for (final f in _fixtures) {
          await f.database.close();
        }
      });
      _fixtures.clear();
    }
  });
}

Future<({ClientSearchFixture f, _Observer observer})> _pump(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double scale = 1,
  TargetPlatform platform = TargetPlatform.iOS,
  String? restaurantId = ClientSearchFixture.shopId,
  bool pushed = false,
  ClientSearchFixture? fixture,
  bool settle = true,
}) async {
  final f = fixture ?? (await tester.runAsync(ClientSearchFixture.create))!;
  _fixtures.add(f);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
  addTearDown(tester.view.reset);
  final observer = _Observer();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        loyaltyRepositoryProvider.overrideWith((ref) => f.repo),
        currentMerchantRestaurantIdProvider.overrideWith((ref) => restaurantId),
      ],
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        navigatorObservers: [observer],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: pushed
            ? const Scaffold(body: Center(child: Text('Page précédente')))
            : const ClientSearchScreen(),
      ),
    ),
  );
  if (pushed) {
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const ClientSearchScreen()),
      ),
    );
  }
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
  return (f: f, observer: observer);
}

Finder get _field => find.byType(TextField);
Future<void> _enter(WidgetTester tester, String query) async {
  await tester.ensureVisible(_field);
  await tester.enterText(_field, query);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  _testWidgets(
    'État initial fonctionnel sans illustration ni donnée de maquette',
    (tester) async {
      await _pump(tester);
      expect(find.text('Recherchez un client'), findsOneWidget);
      expect(find.byType(LoyaloClientCard), findsNothing);
      expect(find.text('Clients récents'), findsNothing);
      expect(find.text('Voir tout'), findsNothing);
      expect(find.text('Emma Durand'), findsNothing);
      expect(find.text('Lucas Martin'), findsNothing);
      final hero = find.byWidgetPredicate((w) {
        if (w is! Image) return false;
        final provider = w.image is ResizeImage
            ? (w.image as ResizeImage).imageProvider
            : w.image;
        return provider is AssetImage &&
            provider.assetName.endsWith('client_search_illustration.png');
      });
      expect(hero, findsNothing);
      expect(tester.getBottomLeft(_field).dy, lessThan(300));
      expect(tester.takeException(), isNull);
    },
  );

  for (final query in ['MÉLIE', '+3361122', 'client-0@']) {
    _testWidgets(
      'Recherche existante par ${query == 'MÉLIE'
          ? 'nom'
          : query.startsWith('+')
          ? 'téléphone'
          : 'email'}',
      (tester) async {
        final value = await _pump(tester);
        final reads = value.f.firestore.reads.length;
        await _enter(tester, query);
        expect(find.text('Amélie Rivière'), findsOneWidget);
        expect(find.text('Amélie autre commerce'), findsNothing);
        expect(find.text('client-0@local.example'), findsNothing);
        expect(find.text('+33 6 11 22 33 44'), findsNothing);
        expect(value.f.repo.searches.last, query);
        expect(value.f.firestore.reads.length, reads);
        expect(find.text('1 résultat'), findsOneWidget);
      },
    );
  }

  _testWidgets('Effacer restaure l’état initial et garde le champ utilisable', (
    tester,
  ) async {
    await _pump(tester);
    await _enter(tester, 'MÉLIE');
    await tester.tap(find.byTooltip('Effacer la recherche'));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(_field);
    expect(field.controller!.text, isEmpty);
    expect(field.focusNode!.hasFocus, true);
    expect(find.byKey(const Key('client-search-initial')), findsOneWidget);
    expect(find.byType(LoyaloClientCard), findsNothing);
  });

  _testWidgets('Absence de résultat distincte, correction immédiate', (
    tester,
  ) async {
    await _pump(tester);
    await _enter(tester, 'introuvable-123');
    expect(find.text('Aucun client trouvé'), findsOneWidget);
    expect(find.byType(LoyaloClientCard), findsNothing);
    expect(tester.widget<TextField>(_field).enabled, true);
    await _enter(tester, 'Noé');
    expect(find.text('Noé Laurent'), findsOneWidget);
    expect(find.text('Aucun client trouvé'), findsNothing);
  });

  _testWidgets(
    'Un champ vide ou composé d’espaces ne révèle pas automatiquement l’annuaire',
    (tester) async {
      await _pump(tester);
      await _enter(tester, '   ');
      expect(find.byKey(const Key('client-search-initial')), findsOneWidget);
      expect(find.byType(LoyaloClientCard), findsNothing);
    },
  );

  _testWidgets(
    'L’annuaire existant reste accessible sans inventer des clients récents',
    (tester) async {
      final value = await _pump(tester);
      final browse = find.text('Afficher les clients du commerce');
      await tester.ensureVisible(browse);
      await tester.tap(browse);
      await tester.pumpAndSettle();
      expect(find.text('Clients du commerce · 3'), findsOneWidget);
      expect(find.byType(LoyaloClientCard), findsNWidgets(3));
      expect(find.text('Amélie autre commerce'), findsNothing);
      expect(value.f.firestore.reads, isNot(contains('foreign-client')));
    },
  );

  _testWidgets(
    'Chargement réel du cache : champ actif, résultats masqués puis actualisés',
    (tester) async {
      final f = (await tester.runAsync(ClientSearchFixture.create))!;
      f.repo.forceLoading = true;
      await _pump(tester, fixture: f, settle: false);
      expect(find.byKey(const Key('client-search-loading')), findsOneWidget);
      await tester.enterText(_field, 'Noé');
      await tester.pump();
      expect(find.byType(LoyaloClientCard), findsNothing);
      f.repo.forceLoading = null;
      f.repo.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.text('Noé Laurent'), findsOneWidget);
    },
  );

  _testWidgets(
    'Erreur de lecture sans détails privés, puis nouvel essai du service existant',
    (tester) async {
      final f = (await tester.runAsync(ClientSearchFixture.create))!;
      f.repo.forceError = StateError('private backend detail');
      await _pump(tester, fixture: f);
      await _enter(tester, 'MÉLIE');
      expect(find.byKey(const Key('client-search-error')), findsOneWidget);
      expect(find.text('Aucun client trouvé'), findsNothing);
      expect(find.textContaining('private backend'), findsNothing);
      await tester.ensureVisible(find.text('Réessayer'));
      final retry = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Réessayer'),
      );
      await tester.runAsync(() async {
        retry.onPressed!.call();
        await f.repo.retryCompletion;
        await f.waitFor(
          () => !f.repo.merchantClientsLoading && f.repo.directory.length == 3,
        );
      });
      await tester.pumpAndSettle();
      expect(f.repo.retryCount, 1);
      expect(tester.widget<TextField>(_field).controller!.text, 'MÉLIE');
      expect(find.text('Amélie Rivière'), findsOneWidget);
    },
  );

  _testWidgets(
    'Une exception de filtrage remonte comme erreur et reste récupérable',
    (tester) async {
      final f = (await tester.runAsync(ClientSearchFixture.create))!;
      f.repo.searchThrows = true;
      await _pump(tester, fixture: f);
      expect(find.byKey(const Key('client-search-error')), findsOneWidget);
      f.repo.searchThrows = false;
      await tester.ensureVisible(find.text('Réessayer'));
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('client-search-initial')), findsOneWidget);
      expect(f.repo.retryCount, 0);
    },
  );

  _testWidgets('Session absente : aucune lecture de l’annuaire conservé', (
    tester,
  ) async {
    final value = await _pump(tester, restaurantId: null);
    expect(find.byKey(const Key('client-search-session')), findsOneWidget);
    expect(value.f.repo.searches, isEmpty);
    expect(tester.widget<TextField>(_field).enabled, false);
    expect(find.byType(LoyaloClientCard), findsNothing);
  });

  _testWidgets('Le résultat ouvre le profil existant avec le bon identifiant', (
    tester,
  ) async {
    final value = await _pump(tester);
    await _enter(tester, 'Noé');
    final context = tester.element(find.byType(ClientSearchScreen));
    await tester.tap(find.byKey(const Key('client-search-result-client-1')));
    await tester.idle();
    final route = value.observer.latest! as MaterialPageRoute<dynamic>;
    final screen = route.builder(context) as MerchantClientProfileScreen;
    expect(screen.clientId, 'client-1');
  });

  _testWidgets('Retour vers la page existante, absent sur la racine', (
    tester,
  ) async {
    await _pump(tester, pushed: true);
    expect(find.byType(LoyaloAuthBackButton), findsOneWidget);
    await tester.tap(find.byType(LoyaloAuthBackButton));
    await tester.pumpAndSettle();
    expect(find.text('Page précédente'), findsOneWidget);
  });

  _testWidgets(
    'Résultats dynamiques après une actualisation autorisée du cache',
    (tester) async {
      final value = await _pump(tester);
      await _enter(tester, 'Amélie');
      await tester.runAsync(() async {
        await value.f.firestore.collection('users').doc('client-0').update({
          'name': 'Amélie Rivière actualisée',
        });
        await value.f.firestore.collection('visits').doc('refresh-visit').set({
          'restaurantId': ClientSearchFixture.shopId,
          'userId': 'client-0',
          'timestamp': DateTime.now(),
        });
        await value.f.waitFor(
          () =>
              value.f.repo.clientById('client-0')?.name ==
                  'Amélie Rivière actualisée' &&
              !value.f.repo.merchantClientsLoading,
        );
      });
      await tester.pumpAndSettle();
      expect(find.text('Amélie Rivière actualisée'), findsOneWidget);
    },
  );

  _testWidgets(
    'Liste paresseuse : les clients hors écran ne sont pas tous construits',
    (tester) async {
      final f = (await tester.runAsync(
        () => ClientSearchFixture.create(clients: 80),
      ))!;
      await _pump(tester, fixture: f);
      await _enter(tester, 'client-');
      expect(find.byType(LoyaloClientCard).evaluate().length, lessThan(20));
      final reads = f.firestore.reads.length;
      await tester.scrollUntilVisible(
        find.byKey(const Key('client-search-result-client-79')),
        700,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 20,
      );
      await tester.pumpAndSettle();
      expect(find.text('Client local 79'), findsOneWidget);
      expect(f.firestore.reads.length, reads);
    },
  );

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(430, 932),
    const Size(360, 740),
    const Size(412, 915),
  ]) {
    for (final scale in [1.0, 2.5]) {
      _testWidgets(
        'Responsive ${size.width} × ${size.height}, texte ×$scale et clavier',
        (tester) async {
          await _pump(
            tester,
            size: size,
            scale: scale,
            pushed: scale > 1,
            platform: size.width == 360 || size.width == 412
                ? TargetPlatform.android
                : TargetPlatform.iOS,
          );
          expect(tester.takeException(), isNull);
          await _enter(tester, 'MÉLIE');
          tester.view.viewInsets = const FakeViewPadding(bottom: 280);
          await tester.pumpAndSettle();
          final rect = tester.getRect(_field);
          expect(rect.top, greaterThanOrEqualTo(47));
          expect(rect.bottom, lessThanOrEqualTo(size.height - 280));
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(
            find.byKey(const Key('client-search-result-client-0')),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          for (final p in tester.renderObjectList<RenderParagraph>(
            find.descendant(
              of: find.byType(LoyaloClientCard),
              matching: find.byType(RichText),
            ),
          )) {
            expect(p.didExceedMaxLines, false);
          }
        },
      );
    }
  }

  _testWidgets('Sémantique du résultat et commandes tactiles de 48 dp', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, pushed: true);
    await _enter(tester, 'MÉLIE');
    final card = find.byKey(const Key('client-search-result-client-0'));
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    final data = tester
        .getSemantics(
          find.bySemanticsLabel('Consulter le profil de Amélie Rivière'),
        )
        .getSemanticsData();
    expect(data.hasAction(SemanticsAction.tap), true);
    expect(tester.getSize(card).height, greaterThanOrEqualTo(48));
    final clear = tester.getSize(find.byTooltip('Effacer la recherche'));
    expect(clear.width, greaterThanOrEqualTo(48));
    expect(clear.height, greaterThanOrEqualTo(48));
    handle.dispose();
  });
}
