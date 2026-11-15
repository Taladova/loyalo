import 'dart:async';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:loyalo/models/check_in_request.dart';
import 'package:loyalo/providers/app_providers.dart';
import 'package:loyalo/screens/merchant/activity_history_screen.dart';
import 'package:loyalo/screens/merchant/client_search_screen.dart';
import 'package:loyalo/screens/merchant/merchant_dashboard_screen.dart';
import 'package:loyalo/screens/merchant/merchant_establishment_screen.dart';
import 'package:loyalo/screens/merchant/merchant_root_screen.dart';
import 'package:loyalo/screens/merchant/merchant_settings_screen.dart';
import 'package:loyalo/screens/merchant/offers_management_screen.dart';
import 'package:loyalo/screens/merchant/rewards_management_screen.dart';
import 'package:loyalo/screens/merchant/statistics_screen.dart';
import 'package:loyalo/screens/merchant/validate_visit_screen.dart';
import 'package:loyalo/screens/notifications_screen.dart';
import 'package:loyalo/services/loyalty_repository.dart';
import 'package:loyalo/widgets/loyalo_merchant_dashboard_ui.dart';
import 'package:loyalo/widgets/loyalo_auth_ui.dart';
import 'package:loyalo/widgets/main_bottom_nav.dart';
import 'package:loyalo/widgets/loyalo_logo.dart';
import 'package:loyalo/widgets/loyalo_ui.dart';

import 'support/merchant_dashboard_fixture.dart';

class _Observer extends NavigatorObserver {
  Route<dynamic>? latest;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      latest = route;
}

const _navItems = [
  NavItemData(icon: Icons.home_outlined, label: 'Accueil'),
  NavItemData(icon: Icons.people_outline, label: 'Clients'),
  NavItemData(icon: Icons.check_circle_outline, label: 'Valider'),
  NavItemData(icon: Icons.card_giftcard_outlined, label: 'Récompenses'),
  NavItemData(icon: Icons.local_fire_department_outlined, label: 'Offres'),
];

Future<({DashboardTestRepository repo, _Observer observer})> _pump(
  WidgetTester tester, {
  DashboardTestRepository? repository,
  String? restaurantId = 'shop-one',
  Size size = const Size(390, 844),
  double scale = 1,
  TargetPlatform platform = TargetPlatform.iOS,
  bool root = false,
  bool settle = true,
}) async {
  final repo = repository ?? DashboardTestRepository();
  addTearDown(() async {
    await repo.stopListening();
    await repo.database.close();
  });
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
  addTearDown(tester.view.reset);
  final observer = _Observer();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        loyaltyRepositoryProvider.overrideWith((ref) => repo),
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
        home: root
            ? const MerchantRootScreen()
            : Scaffold(
                body: const MerchantDashboardScreen(),
                bottomNavigationBar: LoyaloMerchantBottomNav(
                  items: _navItems,
                  selectedIndex: 0,
                  onTap: (_) {},
                ),
              ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
  return (repo: repo, observer: observer);
}

Future<void> _reach(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void _expectMetric(WidgetTester tester, String key, String value) {
  final metric = tester.widget<LoyaloMetricCard>(
    find.byKey(Key('dashboard-$key')),
  );
  expect(metric.value, value);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final auth = DashboardTestAuth();
  setUpAll(() {
    FirebasePlatform.instance = DashboardTestCore();
    FirebaseAuthPlatform.instance = auth;
  });
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Loyalo',
      packageName: 'com.loyalo.test',
      version: '17.0.0',
      buildNumber: '17',
      buildSignature: '',
    );
    auth.name = 'Camille';
    auth.signedIn = true;
  });

  testWidgets(
    'Données dynamiques, périmètre commerce et statistiques visibles',
    (tester) async {
      final f = await _pump(tester, root: true);
      expect(find.textContaining('Bonjour'), findsNothing);
      expect(find.byType(LoyaloMerchantBrand), findsNothing);
      expect(find.byType(LoyaloDashboardMark), findsOneWidget);
      expect(find.byTooltip('Déconnexion'), findsNothing);
      expect(find.byTooltip('Statistiques'), findsOneWidget);
      expect(find.byTooltip('Paramètres'), findsOneWidget);
      expect(find.text('Maison du coin'), findsOneWidget);
      expect(find.text('Boulangerie'), findsOneWidget);
      expect(find.text('Liam'), findsNothing);
      expect(find.text('Pizza'), findsNothing);
      final clients = tester.widget<LoyaloClientSummaryCard>(
        find.byType(LoyaloClientSummaryCard),
      );
      expect(
        (
          clients.totalClients,
          clients.activeClients,
          clients.newClientsThisMonth,
        ),
        (12, 7, 3),
      );
      _expectMetric(tester, 'visits', '2');
      _expectMetric(tester, 'new-clients', '1');
      _expectMetric(tester, 'points', '70');
      expect(f.repo.restaurantIds.toSet(), {'shop-one'});
      expect(f.repo.queueOwners.toSet(), {'merchant-one'});
      expect(
        DateTime.now().difference(f.repo.activeSince!).inSeconds,
        closeTo(const Duration(days: 30).inSeconds, 2),
      );
      final navTop = tester.getTopLeft(find.byType(LoyaloMerchantBottomNav)).dy;
      expect(
        tester.getBottomLeft(find.byKey(const Key('dashboard-clients'))).dy,
        lessThan(navTop),
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('dashboard-visits'))).dy,
        lessThan(navTop),
      );
      final hero = find.byWidgetPredicate((w) {
        if (w is! Image) return false;
        final provider = w.image is ResizeImage
            ? (w.image as ResizeImage).imageProvider
            : w.image;
        return provider is AssetImage &&
            provider.assetName.endsWith('merchant_dashboard_hero.png');
      });
      expect(hero, findsNothing);
      expect(find.byKey(const Key('dashboard-establishment')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Les trois périodes mettent à jour visites, clients, points et historique',
    (tester) async {
      final f = await _pump(tester);
      for (final period in [
        ('7 derniers jours', 4, 3, 140),
        ('30 derniers jours', 5, 4, 175),
        ("Aujourd'hui", 2, 1, 70),
      ]) {
        await _reach(tester, find.byKey(const Key('dashboard-period')));
        await tester.tap(find.byKey(const Key('dashboard-period')));
        await tester.pumpAndSettle();
        expect(
          find.byWidgetPredicate((w) => w is PopupMenuItem),
          findsNWidgets(3),
        );
        await tester.tap(find.text(period.$1).last);
        await tester.pumpAndSettle();
        _expectMetric(tester, 'visits', '${period.$2}');
        _expectMetric(tester, 'new-clients', '${period.$3}');
        _expectMetric(tester, 'points', '${period.$4}');
        expect(
          find.byType(LoyaloRecentActivityTile),
          findsNWidgets(period.$2 > 3 ? 3 : period.$2),
        );
      }
      // La comparaison conserve une durée écoulée identique avant le début de
      // la période, et non une nouvelle définition par journées complètes.
      final current = f.repo.queries[f.repo.queries.length - 2];
      final previous = f.repo.queries.last;
      expect(previous.end, current.start);
      expect(
        previous.end.difference(previous.start),
        current.end.difference(current.start),
      );
      expect(f.repo.restaurantIds.toSet(), {'shop-one'});
    },
  );

  testWidgets('Zéros réels et activité vide, sans faux contenu', (
    tester,
  ) async {
    await _pump(tester, repository: DashboardTestRepository()..empty = true);
    for (final key in ['visits', 'new-clients', 'points']) {
      _expectMetric(tester, key, '0');
    }
    expect(
      tester
          .widget<LoyaloClientSummaryCard>(find.byType(LoyaloClientSummaryCard))
          .totalClients,
      0,
    );
    await _reach(tester, find.byKey(const Key('dashboard-empty-activity')));
    expect(find.text('Aucune activité pour le moment.'), findsOneWidget);
    expect(find.byType(LoyaloRecentActivityTile), findsNothing);
    expect(find.text('Aucun client en attente'), findsOneWidget);
    final express = tester.widget<LoyaloExpressCard>(
      find.byType(LoyaloExpressCard),
    );
    expect(express.onViewAll, isNull);
    expect(
      find.descendant(
        of: find.byType(LoyaloExpressCard),
        matching: find.text('Nouveau'),
      ),
      findsNothing,
    );
  });

  testWidgets('Chargement du commerce sans statistiques de remplacement', (
    tester,
  ) async {
    await _pump(
      tester,
      repository: DashboardTestRepository()
        ..hasRestaurant = false
        ..loading = true,
      settle: false,
    );
    expect(find.text('Chargement de votre commerce…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('dashboard-stats')), findsNothing);
  });

  testWidgets('Erreur du commerce et nouvel essai par le service existant', (
    tester,
  ) async {
    final f = await _pump(
      tester,
      repository: DashboardTestRepository()
        ..hasRestaurant = false
        ..loadError = StateError('offline'),
    );
    expect(
      find.text('Impossible de charger votre commerce. Réessayez.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('dashboard-stats')), findsNothing);
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(f.repo.retries, 1);
    _expectMetric(tester, 'points', '70');
  });

  testWidgets('Session absente sans requête ni accès aux données', (
    tester,
  ) async {
    final f = await _pump(tester, restaurantId: null);
    expect(
      find.text('Votre session commerçant est indisponible. Reconnectez-vous.'),
      findsOneWidget,
    );
    expect(f.repo.queries, isEmpty);
    expect(f.repo.queueOwners, isEmpty);
    expect(find.byKey(const Key('dashboard-stats')), findsNothing);
    expect(find.text('Réessayer'), findsNothing);
  });

  testWidgets('Commerce indisponible et identité sans prénom inventé', (
    tester,
  ) async {
    auth.name = null;
    final f = await _pump(tester);
    expect(find.text('Maison du coin'), findsOneWidget);
    expect(find.text('Camille'), findsNothing);
    f.repo.hasRestaurant = false;
    f.repo.notifyListeners();
    await tester.pumpAndSettle();
    expect(
      find.text('Votre commerce est indisponible pour le moment.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('dashboard-stats')), findsNothing);
  });

  testWidgets('Erreur d’actualisation avec données déjà disponibles', (
    tester,
  ) async {
    await _pump(
      tester,
      repository: DashboardTestRepository()..loadError = StateError('offline'),
    );
    expect(
      find.text(
        'Actualisation du commerce impossible. Les données disponibles restent affichées.',
      ),
      findsOneWidget,
    );
    _expectMetric(tester, 'points', '70');
  });

  testWidgets(
    'Le conteneur des cinq onglets protège les pages sans commerce chargé',
    (tester) async {
      final repo = DashboardTestRepository()
        ..hasRestaurant = false
        ..loading = true;
      await _pump(tester, repository: repo, root: true, settle: false);
      expect(find.text('Chargement de votre commerce…'), findsOneWidget);
      expect(find.byType(RewardsManagementScreen), findsNothing);
      expect(
        tester
            .widget<LoyaloMerchantBottomNav>(
              find.byType(LoyaloMerchantBottomNav),
            )
            .enabled,
        false,
      );
      expect(tester.takeException(), isNull);
      repo.loading = false;
      repo.loadError = StateError('offline');
      repo.notifyListeners();
      await tester.pumpAndSettle();
      expect(
        find.text('Impossible de charger votre commerce. Réessayez.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<LoyaloMerchantBottomNav>(
              find.byType(LoyaloMerchantBottomNav),
            )
            .enabled,
        true,
      );
      expect(find.byType(IndexedStack), findsWidgets);
      expect(
        find.byType(RewardsManagementScreen, skipOffstage: false),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Le conteneur garde la session absente hors des écrans métier', (
    tester,
  ) async {
    await _pump(tester, restaurantId: null, root: true);
    expect(find.byType(IndexedStack), findsNothing);
    expect(find.byKey(const Key('dashboard-stats')), findsNothing);
    expect(
      tester
          .widget<LoyaloMerchantBottomNav>(find.byType(LoyaloMerchantBottomNav))
          .enabled,
      false,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Loyalo Express charge puis affiche les données reçues', (
    tester,
  ) async {
    final stream = StreamController<List<CheckInRequest>>();
    addTearDown(stream.close);
    await _pump(
      tester,
      repository: DashboardTestRepository()..queue = stream.stream,
      settle: false,
    );
    expect(find.text('Chargement des arrivées en cours…'), findsOneWidget);
    stream.add([]);
    await tester.pumpAndSettle();
    expect(find.text('Aucun client en attente'), findsOneWidget);
  });

  for (final source in ['stream', 'repository', 'unavailable']) {
    testWidgets('Loyalo Express : état $source sans lien artificiel', (
      tester,
    ) async {
      final repo = DashboardTestRepository();
      if (source == 'stream') {
        repo.queue = Stream.error(StateError('permission-denied'));
      }
      if (source == 'repository') repo.queueError = StateError('offline');
      if (source == 'unavailable') repo.queue = const Stream.empty();
      await _pump(tester, repository: repo);
      final card = tester.widget<LoyaloExpressCard>(
        find.byType(LoyaloExpressCard),
      );
      expect(
        card.message,
        source == 'unavailable'
            ? 'Loyalo Express est indisponible pour le moment.'
            : 'Lecture impossible, réessayez plus tard.',
      );
      expect(card.onViewAll, isNull);
      _expectMetric(tester, 'points', '70');
    });
  }

  testWidgets('Express conserve les arrivées et les états hors ligne/expirés', (
    tester,
  ) async {
    final repo = DashboardTestRepository();
    repo.queue = Stream.value([
      repo.arrival('pending'),
      repo.arrival('expired', status: CheckInStatus.expired),
      repo.arrival('rejected', status: CheckInStatus.rejected),
      repo.arrival('approved', status: CheckInStatus.approved),
      repo.arrival('fifth'),
    ]);
    await _pump(tester, repository: repo);
    expect(find.byType(LoyaloExpressRequestTile), findsNWidgets(4));
    expect(find.text('2 clients attendent votre validation'), findsOneWidget);
    expect(find.text("9/10 · proche d'une récompense"), findsOneWidget);
    expect(find.text('Arrivée expirée · points non attribués'), findsOneWidget);
    expect(find.text('Refus en attente de synchronisation'), findsOneWidget);
    expect(
      find.text('Validation en attente de synchronisation'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<LoyaloExpressRequestTile>(
            find.byKey(const Key('dashboard-request-expired')),
          )
          .canAct,
      false,
    );
  });

  testWidgets(
    'Validation Express : propriétaire, état occupé et résultat réel',
    (tester) async {
      final repo = DashboardTestRepository();
      repo.queue = Stream.value([repo.arrival('arrival-one')]);
      repo.validation = Completer<CheckInValidationResult>();
      await _pump(tester, repository: repo);
      final approve = find.descendant(
        of: find.byType(LoyaloExpressRequestTile),
        matching: find.byType(FilledButton),
      );
      await _reach(tester, approve);
      await tester.tap(approve);
      await tester.pump();
      expect(repo.approvals, [(id: 'arrival-one', owner: 'merchant-one')]);
      expect(tester.widget<FilledButton>(approve).onPressed, isNull);
      repo.validation!.complete(
        const CheckInValidationResult(
          outcome: CheckInValidationOutcome.validated,
          pointsAwarded: 35,
          synced: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Visite validée · +35 pts'), findsOneWidget);
      expect(tester.widget<FilledButton>(approve).onPressed, isNotNull);
    },
  );

  testWidgets(
    'Refus Express : propriétaire et confirmation hors ligne conservés',
    (tester) async {
      final repo = DashboardTestRepository();
      repo.queue = Stream.value([repo.arrival('arrival-one')]);
      await _pump(tester, repository: repo);
      await _reach(tester, find.text('Refuser'));
      await tester.tap(find.text('Refuser'));
      await tester.pumpAndSettle();
      expect(repo.rejections, [(id: 'arrival-one', owner: 'merchant-one')]);
      expect(
        find.text('Refus enregistré. Synchronisation en attente.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('Express bloque la validation lorsque la session expire', (
    tester,
  ) async {
    final repo = DashboardTestRepository();
    repo.queue = Stream.value([repo.arrival('arrival-one')]);
    await _pump(tester, repository: repo);
    auth.signedIn = false;
    final approve = find.descendant(
      of: find.byType(LoyaloExpressRequestTile),
      matching: find.byType(FilledButton),
    );
    await _reach(tester, approve);
    await tester.tap(approve);
    await tester.pumpAndSettle();
    expect(repo.approvals, isEmpty);
    expect(
      find.text('Session expirée. Reconnectez-vous pour continuer.'),
      findsOneWidget,
    );
  });

  final routes = <String, Type>{
    'Voir tout': ActivityHistoryScreen,
    'Notifications': NotificationsScreen,
    'Paramètres': MerchantSettingsScreen,
    'Statistiques': StatisticsScreen,
    'Mon établissement': MerchantEstablishmentScreen,
    'Voir les arrivées': ValidateVisitScreen,
  };
  for (final entry in routes.entries) {
    testWidgets('Destination existante : ${entry.key}', (tester) async {
      final repo = DashboardTestRepository();
      if (entry.key == 'Voir les arrivées') {
        repo.queue = Stream.value([repo.arrival('arrival-one')]);
      }
      final f = await _pump(tester, repository: repo);
      final finder =
          entry.key == 'Notifications' ||
              entry.key == 'Paramètres' ||
              entry.key == 'Statistiques'
          ? find.byTooltip(entry.key)
          : find.text(entry.key);
      await _reach(tester, finder);
      final context = tester.element(find.byType(MerchantDashboardScreen));
      await tester.tap(finder);
      await tester.idle();
      final route = f.observer.latest! as MaterialPageRoute<dynamic>;
      expect(route.builder(context).runtimeType, entry.value);
      // La destination est contrôlée sans amorcer ses propres services.
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'Accueil garde Mon établissement ; Paramètres se concentre sur le compte, retour et période préservés',
    (tester) async {
      await _pump(tester, root: true);
      await tester.tap(find.byKey(const Key('dashboard-period')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('7 derniers jours').last);
      await tester.pumpAndSettle();
      await _reach(tester, find.byKey(const Key('dashboard-establishment')));
      await tester.tap(find.byKey(const Key('dashboard-establishment')));
      await tester.pumpAndSettle();
      expect(find.byType(MerchantEstablishmentScreen), findsOneWidget);
      await _reach(
        tester,
        find.byKey(const Key('establishment-section-general')),
      );
      await tester.tap(find.byKey(const Key('establishment-section-general')));
      await tester.pumpAndSettle();
      final name = find.byWidgetPredicate(
        (w) => w is TextFormField && w.controller?.text == 'Maison du coin',
      );
      expect(name, findsOneWidget);
      await _reach(tester, find.byType(LoyaloAuthBackButton));
      await tester.tap(find.byType(LoyaloAuthBackButton));
      await tester.pumpAndSettle();
      await _reach(tester, find.byType(LoyaloAuthBackButton));
      await tester.tap(find.byType(LoyaloAuthBackButton));
      await tester.pumpAndSettle();
      expect(find.byType(MerchantDashboardScreen), findsOneWidget);
      expect(find.text('7 derniers jours'), findsOneWidget);
      await _reach(tester, find.byTooltip('Paramètres'));
      await tester.tap(find.byTooltip('Paramètres'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MerchantSettingsScreen), findsOneWidget);
      expect(find.text('Restaurant'), findsNothing);
      expect(find.text('Mon établissement'), findsNothing);
      expect(find.text('Compte et sécurité'), findsOneWidget);
      await _reach(tester, find.byType(LoyaloAuthBackButton));
      await tester.tap(find.byType(LoyaloAuthBackButton));
      await tester.pumpAndSettle();
      expect(find.byType(MerchantDashboardScreen), findsOneWidget);
      expect(find.text('7 derniers jours'), findsOneWidget);
      _expectMetric(tester, 'visits', '4');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Les cinq onglets du conteneur conservent leur écran et leur ordre',
    (tester) async {
      await _pump(tester, root: true, size: const Size(430, 932));
      final nav = tester.widget<LoyaloMerchantBottomNav>(
        find.byType(LoyaloMerchantBottomNav),
      );
      expect(nav.items.map((item) => item.label), [
        'Accueil',
        'Clients',
        'Valider',
        'Récompenses',
        'Offres',
      ]);
      final screens = [
        MerchantDashboardScreen,
        ClientSearchScreen,
        ValidateVisitScreen,
        RewardsManagementScreen,
        OffersManagementScreen,
      ];
      final elements = [
        for (final screen in screens)
          tester.element(find.byType(screen, skipOffstage: false).first),
      ];
      for (final i in [0, 1, 2, 3, 4, 2, 1, 0]) {
        await tester.tap(
          find.descendant(
            of: find.byType(LoyaloMerchantBottomNav),
            matching: find.byKey(ValueKey('merchant-nav-item-$i')),
          ),
        );
        await tester.pumpAndSettle();
        final stack = tester.widget<IndexedStack>(
          find.byType(IndexedStack).first,
        );
        expect(stack.index, i);
        expect(stack.children[i].runtimeType, screens[i]);
        expect(
          tester.element(find.byType(screens[i], skipOffstage: false).first),
          same(elements[i]),
        );
        expect(
          tester
              .widget<LoyaloMerchantBottomNav>(
                find.byType(LoyaloMerchantBottomNav),
              )
              .selectedIndex,
          i,
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Statistiques revient à l’accueil et conserve sa période et ses données',
    (tester) async {
      await _pump(tester, root: true);
      await tester.tap(find.byKey(const Key('dashboard-period')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('7 derniers jours').last);
      await tester.pumpAndSettle();
      _expectMetric(tester, 'visits', '4');
      await tester.tap(find.byTooltip('Statistiques'));
      await tester.pumpAndSettle();
      expect(find.byType(StatisticsScreen), findsOneWidget);
      expect(find.byType(LoyaloMerchantBottomNav), findsNothing);
      await tester.tap(find.byType(LoyaloAuthBackButton));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<LoyaloMerchantBottomNav>(
              find.byType(LoyaloMerchantBottomNav),
            )
            .selectedIndex,
        0,
      );
      expect(find.text('7 derniers jours'), findsOneWidget);
      _expectMetric(tester, 'visits', '4');
    },
  );

  for (final size in [
    const Size(320, 568),
    const Size(360, 740),
    const Size(390, 844),
    const Size(412, 915),
    const Size(430, 932),
  ]) {
    for (final scale in [1.0, 2.5]) {
      testWidgets('Responsive ${size.width} × ${size.height}, texte ×$scale', (
        tester,
      ) async {
        auth.name = 'Camille Dominique de la Grande Boulangerie du Quartier';
        final repo = DashboardTestRepository();
        repo.queue = Stream.value([repo.arrival('arrival-one')]);
        await _pump(
          tester,
          repository: repo,
          size: size,
          scale: scale,
          platform: size.width == 360 || size.width == 412
              ? TargetPlatform.android
              : TargetPlatform.iOS,
        );
        final establishment = find.byKey(const Key('dashboard-establishment'));
        await _reach(tester, establishment);
        final establishmentRect = tester.getRect(establishment);
        expect(establishmentRect.left, greaterThanOrEqualTo(0));
        expect(establishmentRect.right, lessThanOrEqualTo(size.width));
        expect(establishmentRect.height, greaterThanOrEqualTo(48));
        expect(find.text('Mon établissement'), findsOneWidget);
        for (final key in [
          'dashboard-clients',
          'dashboard-points',
          'dashboard-express',
          'dashboard-section-activity',
        ]) {
          await _reach(tester, find.byKey(Key(key)));
          expect(tester.takeException(), isNull);
        }
        for (final element in find.byType(RichText).evaluate()) {
          var name = false;
          element.visitAncestorElements((parent) {
            if (parent.widget.key == const Key('dashboard-restaurant-name') ||
                parent.widget.key ==
                    const Key('dashboard-restaurant-category')) {
              name = true;
            }
            return !name;
          });
          if (!name) {
            expect(
              (element.renderObject! as RenderParagraph).didExceedMaxLines,
              false,
            );
          }
        }
        expect(find.text('Actions rapides'), findsNothing);
        expect(find.byType(LoyaloQuickAction), findsNothing);
        final nav = find.byType(LoyaloMerchantBottomNav);
        for (final ink
            in find
                .descendant(of: nav, matching: find.byType(InkWell))
                .evaluate()) {
          final box = ink.renderObject! as RenderBox;
          expect(box.size.width, greaterThanOrEqualTo(48));
          expect(box.size.height, greaterThanOrEqualTo(48));
        }
      });
    }
  }

  testWidgets('Sémantique des commandes et zones tactiles de l’en-tête', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    for (final label in [
      'Notifications, 2 non lues',
      'Paramètres',
      'Statistiques',
      'Mon établissement',
    ]) {
      expect(
        tester
            .getSemantics(find.bySemanticsLabel(label))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        true,
      );
    }
    for (final tooltip in ['Notifications', 'Paramètres', 'Statistiques']) {
      final size = tester.getSize(find.byTooltip(tooltip));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    handle.dispose();
  });

  testWidgets(
    'Filtre compact de 48 dp aligné à droite, trois périodes conservées',
    (tester) async {
      await _pump(tester);
      final period = find.byKey(const Key('dashboard-period'));
      final rect = tester.getRect(period);
      expect(rect.height, 48);
      expect(rect.width, lessThan(260));
      final stats = tester.getRect(find.byKey(const Key('dashboard-stats')));
      expect(rect.right, closeTo(stats.right, 0.1));
      expect(find.text('Vue d’ensemble'), findsOneWidget);
      await tester.tap(period);
      await tester.pumpAndSettle();
      for (final label in [
        "Aujourd'hui",
        '7 derniers jours',
        '30 derniers jours',
      ]) {
        expect(find.text(label), findsWidgets);
      }
    },
  );

  for (final size in [const Size(320, 568), const Size(390, 844)]) {
    for (final name in [
      'Jo',
      'Un très long nom de commerce conservé dans son intégralité',
    ]) {
      testWidgets('En-tête sur deux rangées, nom $name, ${size.width} dp', (
        tester,
      ) async {
        final repo = DashboardTestRepository();
        repo.commerce = repo.commerce.copyWith(name: name);
        await _pump(tester, repository: repo, size: size);
        final nameFinder = find.byKey(const Key('dashboard-restaurant-name'));
        final text = tester.widget<Text>(nameFinder);
        expect(text.data, name);
        expect(text.maxLines, 1);
        expect(text.overflow, TextOverflow.ellipsis);
        expect(repo.commerce.name, name);
        expect(
          tester.renderObject<RenderParagraph>(nameFinder).didExceedMaxLines,
          name != 'Jo',
        );
        final button = find.byKey(const Key('dashboard-establishment'));
        final buttonRect = tester.getRect(button);
        final avatarRect = tester.getRect(find.byType(LoyaloMerchantAvatar));
        expect(buttonRect.center.dy, closeTo(avatarRect.center.dy, 0.1));
        expect(buttonRect.left, greaterThan(tester.getRect(nameFinder).right));
        expect(buttonRect.right, lessThanOrEqualTo(size.width - 12));
        final buttonLabel = tester.widget<Text>(find.text('Mon établissement'));
        expect(buttonLabel.maxLines, 1);
        expect(buttonLabel.softWrap, false);
        final title = find.byKey(const Key('dashboard-merchant-title-fit'));
        final notificationRect = tester.getRect(
          find.byTooltip('Notifications'),
        );
        expect(tester.getRect(title).right, lessThan(notificationRect.left));
        expect(
          tester.getRect(title).center.dy,
          closeTo(notificationRect.center.dy, 0.1),
        );
        final image = tester.widget<Image>(
          find.descendant(
            of: find.byType(LoyaloDashboardMark),
            matching: find.byType(Image),
          ),
        );
        final asset = (image.image as ResizeImage).imageProvider as AssetImage;
        expect(asset.assetName, 'assets/images/app_icon_foreground.png');
        expect(find.textContaining('Bonjour'), findsNothing);
        expect(find.text('Actions rapides'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
