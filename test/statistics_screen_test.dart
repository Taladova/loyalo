import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loyalo/core/data/repository_read_state.dart';
import 'package:loyalo/providers/app_providers.dart';
import 'package:loyalo/screens/merchant/merchant_root_screen.dart';
import 'package:loyalo/screens/merchant/statistics_screen.dart';
import 'package:loyalo/services/loyalty_repository.dart';
import 'package:loyalo/widgets/loyalo_auth_ui.dart';
import 'package:loyalo/widgets/loyalo_merchant_dashboard_ui.dart';
import 'package:loyalo/widgets/loyalo_statistics_ui.dart';

import 'support/merchant_dashboard_fixture.dart';
import 'support/statistics_fixture.dart';

final fixtures = <StatisticsFixture>[];
void statisticsTest(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    try {
      await body(tester);
    } finally {
      await tester.runAsync(() async {
        for (final f in fixtures) {
          f.firestore.release();
          await f.repo.stopListening();
        }
      });
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        for (final f in fixtures) {
          await f.database.close();
        }
      });
      fixtures.clear();
    }
  });
}

Future<StatisticsFixture> fixture(
  WidgetTester tester, {
  bool empty = false,
  bool scoped = true,
  Set<String> failed = const {},
  Set<String> held = const {},
}) async {
  final f = (await tester.runAsync(
    () => StatisticsFixture.create(
      empty: empty,
      scoped: scoped,
      failed: failed,
      held: held,
    ),
  ))!;
  fixtures.add(f);
  return f;
}

Future<void> pump(
  WidgetTester tester,
  StatisticsFixture f, {
  Size size = const Size(390, 844),
  double scale = 1,
  Widget screen = const StatisticsScreen(),
  String? restaurantId = StatisticsFixture.shopId,
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        loyaltyRepositoryProvider.overrideWith((ref) => f.repo),
        currentMerchantRestaurantIdProvider.overrideWith((ref) => restaurantId),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
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
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder card(String id) => find.byKey(Key('stats-$id'));
void value(WidgetTester tester, String id, String expected) {
  expect(
    tester.widget<Text>(find.byKey(ValueKey('stats-value-$id'))).data,
    expected,
  );
}

Future<void> period(WidgetTester tester, String label) async {
  final selector = find.byKey(const Key('statistics-period'));
  await tester.ensureVisible(selector);
  await tester.pumpAndSettle();
  await tester.tap(selector);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

final sources = {
  'visits': StatisticsDataSource.visits,
  'rewards': StatisticsDataSource.rewards,
  'exclusiveOffers': StatisticsDataSource.offers,
  'checkIns': StatisticsDataSource.checkIns,
};
final identifiers = {
  'visits': 'visits',
  'rewards': 'rewards',
  'exclusiveOffers': 'offers',
  'checkIns': 'checkins',
};

void main() {
  setUpAll(() {
    FirebasePlatform.instance = DashboardTestCore();
    FirebaseAuthPlatform.instance = DashboardTestAuth();
  });

  statisticsTest(
    'Huit indicateurs réels, couleurs et tendances conservées, sans logo ni image',
    (tester) async {
      final f = await fixture(tester);
      await pump(tester, f);
      expect(find.text('Statistiques'), findsOneWidget);
      expect(find.text('30 derniers jours'), findsOneWidget);
      expect(find.byType(LoyaloStatisticCard), findsNWidgets(8));
      expect(find.byType(Image), findsNothing);
      expect(find.byType(LoyaloAuthHeader), findsNothing);
      for (final row in [
        ('visits', '4'),
        ('clients', '3'),
        ('rewards', '2'),
        ('points', '140'),
        ('offers', '1'),
        ('checkins', '2'),
      ]) {
        value(tester, row.$1, row.$2);
      }
      value(tester, 'referrals', '—');
      value(tester, 'pending', '—');
      expect(tester.widget<LoyaloStatisticCard>(card('visits')).trend, '+300%');
      expect(
        tester.widget<LoyaloStatisticCard>(card('rewards')).trend,
        '+100%',
      );
      expect(f.firestore.snapshotPaths, isNot(contains('referrals')));
      expect(tester.takeException(), isNull);
    },
  );

  statisticsTest(
    'Les trois périodes gardent les calculs et adaptent la série sans nouvelle requête',
    (tester) async {
      final f = await fixture(tester);
      await pump(tester, f);
      final paths = List<String>.of(f.firestore.snapshotPaths);
      for (final row in [
        ('7 derniers jours', 7, '2', '1', '1', '70'),
        ('90 derniers jours', 90, '6', '4', '3', '210'),
        ('30 derniers jours', 30, '4', '3', '2', '140'),
      ]) {
        await period(tester, row.$1);
        value(tester, 'visits', row.$3);
        value(tester, 'clients', row.$4);
        value(tester, 'rewards', row.$5);
        value(tester, 'points', row.$6);
        value(tester, 'offers', '1');
        value(tester, 'checkins', '2');
        final chart = tester.widget<LineChart>(find.byType(LineChart));
        final spots = chart.data.lineBarsData.single.spots;
        expect(spots, hasLength(row.$2));
        expect(
          spots.fold<double>(0, (sum, spot) => sum + spot.y),
          double.parse(row.$3),
        );
        expect(chart.data.minX, 0);
        expect(chart.data.maxX, row.$2 - 1);
        expect(chart.data.lineBarsData.single.isCurved, false);
        expect(f.firestore.snapshotPaths, paths);
        expect(tester.takeException(), isNull);
      }
    },
  );

  statisticsTest(
    'Lectures réussies et vides : huit vrais zéros, aucun tracé inventé',
    (tester) async {
      final f = await fixture(tester, empty: true, scoped: false);
      await pump(tester, f);
      for (final id in [
        'visits',
        'clients',
        'rewards',
        'points',
        'offers',
        'checkins',
        'referrals',
        'pending',
      ]) {
        value(tester, id, '0');
        expect(
          tester.widget<LoyaloStatisticCard>(card(id)).status,
          LoyaloStatisticStatus.ready,
        );
      }
      expect(find.text('Aucune visite sur cette période'), findsOneWidget);
      expect(
        tester.widget<LineChart>(find.byType(LineChart)).data.lineBarsData,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final path in sources.keys) {
    statisticsTest(
      'Chargement $path : aucun zéro avant la réponse de lecture',
      (tester) async {
        final f = await fixture(tester, empty: true, held: {path});
        await pump(tester, f, settle: false);
        final id = identifiers[path]!;
        expect(
          tester.widget<LoyaloStatisticCard>(card(id)).status,
          LoyaloStatisticStatus.loading,
        );
        expect(find.byKey(ValueKey('stats-value-$id')), findsNothing);
        if (path == 'visits') {
          expect(find.text('Chargement des visites…'), findsOneWidget);
          expect(find.byType(LineChart), findsNothing);
          expect(find.text('Aucune visite sur cette période'), findsNothing);
        }
        f.firestore.release();
        await tester.runAsync(
          () => f.waitFor(
            () =>
                f.repo.statisticsReadState(sources[path]!).status ==
                RepositoryReadStatus.ready,
          ),
        );
        await tester.pumpAndSettle();
        value(tester, id, '0');
        expect(tester.takeException(), isNull);
      },
    );

    statisticsTest(
      'Erreur $path : tiret, pas de faux zéro, puis récupération par Réessayer',
      (tester) async {
        final f = await fixture(tester, empty: true, failed: {path});
        await tester.runAsync(
          () => f.waitFor(
            () =>
                f.repo.statisticsReadState(sources[path]!).status ==
                RepositoryReadStatus.error,
          ),
        );
        await pump(tester, f);
        final id = identifiers[path]!;
        value(tester, id, '—');
        expect(
          tester.widget<LoyaloStatisticCard>(card(id)).status,
          LoyaloStatisticStatus.error,
        );
        expect(find.textContaining('permission-denied'), findsNothing);
        if (path == 'visits') {
          expect(find.byType(LineChart), findsNothing);
          expect(find.text('Aucune visite sur cette période'), findsNothing);
          value(tester, 'clients', '—');
          value(tester, 'points', '—');
        }
        f.firestore.failed.clear();
        final retry = find.widgetWithText(TextButton, 'Réessayer');
        await tester.ensureVisible(retry);
        await tester.runAsync(() async {
          await tester.tap(retry);
          await f.waitFor(
            () =>
                f.repo.statisticsReadState(sources[path]!).status ==
                    RepositoryReadStatus.ready &&
                StatisticsDataSource.values.every(
                  (source) =>
                      f.repo.statisticsReadState(source).status !=
                      RepositoryReadStatus.loading,
                ),
          );
        });
        await tester.pumpAndSettle();
        value(tester, id, '0');
        expect(f.repo.retries, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  statisticsTest(
    'Erreur de visites avec cache : le cache reste intact mais sa valeur est masquée',
    (tester) async {
      final f = await fixture(tester);
      await pump(tester, f);
      value(tester, 'visits', '4');
      f.firestore.failed.add('visits');
      await tester.runAsync(() async {
        await f.repo.retryRestaurants();
        await f.waitFor(
          () =>
              f.repo.statisticsReadState(StatisticsDataSource.visits).status ==
              RepositoryReadStatus.error,
        );
      });
      await tester.pumpAndSettle();
      value(tester, 'visits', '—');
      final now = DateTime.now();
      expect(
        f.repo.visitsForRestaurantBetween(
          StatisticsFixture.shopId,
          now.subtract(const Duration(days: 30)),
          now,
        ),
        hasLength(4),
      );
      expect(find.byType(LineChart), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  statisticsTest(
    'L’isolation du commerce et l’absence de requête parrainages sont conservées',
    (tester) async {
      final f = await fixture(tester);
      await pump(tester, f);
      for (final path in ['visits', 'rewards', 'exclusiveOffers', 'checkIns']) {
        expect(
          f.firestore.filters.any(
            (filter) =>
                filter.path == path &&
                filter.field == 'restaurantId' &&
                filter.value == StatisticsFixture.shopId,
          ),
          true,
        );
      }
      expect(f.firestore.snapshotPaths, isNot(contains('referrals')));
      expect(
        f.repo.statisticsReadState(StatisticsDataSource.referrals).status,
        RepositoryReadStatus.unavailable,
      );
      expect(f.repo.pendingCheckInsCount(StatisticsFixture.shopId), 2);
      expect(tester.takeException(), isNull);
    },
  );

  for (final state in ['chargement', 'erreur', 'session absente']) {
    statisticsTest('État global $state : aucun indicateur remplacé par zéro', (
      tester,
    ) async {
      final f = await fixture(tester, empty: true);
      if (state == 'chargement') f.repo.forceRestaurantLoading = true;
      if (state == 'erreur') {
        f.repo.forceRestaurantError = StateError('Lecture refusée');
      }
      await pump(
        tester,
        f,
        restaurantId: state == 'session absente'
            ? null
            : StatisticsFixture.shopId,
        settle: state != 'chargement',
      );
      expect(find.byType(LoyaloStatisticCard), findsNothing);
      expect(find.byType(LineChart), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  statisticsTest('Statistiques depuis l’en-tête puis retour aux cinq onglets', (
    tester,
  ) async {
    final f = await fixture(tester);
    await pump(tester, f, screen: const MerchantRootScreen());
    final nav = find.byType(LoyaloMerchantBottomNav);
    await tester.tap(find.byTooltip('Statistiques'));
    await tester.pumpAndSettle();
    expect(find.byType(StatisticsScreen), findsOneWidget);
    expect(nav, findsNothing);
    await period(tester, '7 derniers jours');
    expect(find.text('7 derniers jours'), findsOneWidget);
    value(tester, 'visits', '2');
    await tester.ensureVisible(find.byType(LoyaloAuthBackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(LoyaloAuthBackButton));
    await tester.pumpAndSettle();
    expect(tester.widget<LoyaloMerchantBottomNav>(nav).selectedIndex, 0);
    for (final index in [1, 2, 3, 4, 0]) {
      final destination = find.descendant(
        of: nav,
        matching: find.byKey(ValueKey('merchant-nav-item-$index')),
      );
      await tester.tap(destination);
      await tester.pumpAndSettle();
    }
    expect(find.byTooltip('Statistiques'), findsOneWidget);
    expect(find.text('Stats'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final size in const [
    Size(320, 568),
    Size(390, 844),
    Size(430, 932),
    Size(360, 640),
    Size(412, 915),
  ]) {
    for (final scale in [1.0, 2.0]) {
      statisticsTest(
        'Grille, libellés et graphique accessibles — $size texte $scale',
        (tester) async {
          final f = await fixture(tester);
          await pump(tester, f, size: size, scale: scale);
          for (final id in [
            'visits',
            'clients',
            'rewards',
            'points',
            'offers',
            'checkins',
            'referrals',
            'pending',
          ]) {
            await tester.ensureVisible(card(id));
            await tester.pumpAndSettle();
            final rect = tester.getRect(card(id));
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(size.width));
            final label = find.descendant(
              of: card(id),
              matching: find.text(
                tester.widget<LoyaloStatisticCard>(card(id)).label,
              ),
            );
            final text = tester.widget<Text>(label);
            expect(text.overflow, isNot(TextOverflow.ellipsis));
            expect(text.maxLines, isNull);
            expect(tester.takeException(), isNull);
          }
          final chart = find.byType(LoyaloVisitsChart);
          await tester.ensureVisible(chart);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await period(tester, '90 derniers jours');
          expect(
            tester
                .widget<LineChart>(find.byType(LineChart))
                .data
                .lineBarsData
                .single
                .spots,
            hasLength(90),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  statisticsTest('Sémantique des nombres réels et des données indisponibles', (
    tester,
  ) async {
    final f = await fixture(tester);
    final semantics = tester.ensureSemantics();
    try {
      await pump(tester, f);
      expect(find.bySemanticsLabel(RegExp('Visites : 4')), findsOneWidget);
      expect(
        find.bySemanticsLabel('Parrainages : Non disponible'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}
