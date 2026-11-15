import 'package:flutter_test/flutter_test.dart';
import 'package:loyalo/core/data/repository_read_state.dart';
import 'package:loyalo/services/loyalty_repository.dart';

import 'support/statistics_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Une session arrêtée ne présente plus les valeurs en cache comme des lectures actives',
    () async {
      final f = await StatisticsFixture.create(empty: true);
      try {
        expect(
          f.repo.statisticsReadState(StatisticsDataSource.visits).status,
          RepositoryReadStatus.ready,
        );
        await f.repo.stopListening();
        for (final source in StatisticsDataSource.values) {
          expect(
            f.repo.statisticsReadState(source).status,
            RepositoryReadStatus.unavailable,
          );
        }
      } finally {
        await f.close();
      }
    },
  );

  test(
    'Le changement de session ne transforme pas un cache de parrainages partiel en total commerçant',
    () async {
      final f = await StatisticsFixture.create(scoped: false);
      try {
        expect(
          f.repo.statisticsReadState(StatisticsDataSource.referrals).status,
          RepositoryReadStatus.ready,
        );
        expect(
          f.repo.rewardedReferralsForRestaurant(StatisticsFixture.shopId),
          1,
        );
        expect(
          f.repo.pendingReferralsForRestaurant(StatisticsFixture.shopId),
          1,
        );
        await f.repo.stopListening();
        final reads = f.firestore.snapshotPaths.length;
        f.repo.startListeningForMerchant(
          StatisticsFixture.shopId,
          ownerUid: StatisticsFixture.ownerId,
        );
        await f.waitFor(
          () =>
              f.repo.statisticsReadState(StatisticsDataSource.visits).status ==
              RepositoryReadStatus.ready,
        );
        expect(
          f.repo.statisticsReadState(StatisticsDataSource.referrals).status,
          RepositoryReadStatus.unavailable,
        );
        expect(
          f.firestore.snapshotPaths.skip(reads),
          isNot(contains('referrals')),
        );
        // Le cache et les calculs historiques ne sont ni effacés ni réécrits.
        expect(
          f.repo.rewardedReferralsForRestaurant(StatisticsFixture.shopId),
          1,
        );
        expect(
          f.repo.pendingReferralsForRestaurant(StatisticsFixture.shopId),
          1,
        );
      } finally {
        await f.close();
      }
    },
  );

  test(
    'Une panne distante conserve les visites confirmées et ne devient pas un zéro connu',
    () async {
      final f = await StatisticsFixture.create();
      try {
        final now = DateTime.now();
        final start = now.subtract(const Duration(days: 90));
        final visits = f.repo.visitsForRestaurantBetween(
          StatisticsFixture.shopId,
          start,
          now,
        );
        final local = await f.database.visitDao.getVisitsByMerchant(
          StatisticsFixture.shopId,
        );
        expect(visits, hasLength(6));
        f.firestore.failed.add('visits');
        await f.repo.retryRestaurants();
        await f.waitFor(
          () =>
              f.repo.statisticsReadState(StatisticsDataSource.visits).status ==
              RepositoryReadStatus.error,
        );
        expect(
          f.repo.statisticsReadState(StatisticsDataSource.visits).error,
          isNotNull,
        );
        expect(
          f.repo
              .visitsForRestaurantBetween(StatisticsFixture.shopId, start, now)
              .map((v) => v.id)
              .toSet(),
          visits.map((v) => v.id).toSet(),
        );
        expect(
          (await f.database.visitDao.getVisitsByMerchant(
            StatisticsFixture.shopId,
          )).length,
          local.length,
        );
        f.firestore.failed.clear();
        await f.repo.retryRestaurants();
        await f.waitFor(
          () =>
              f.repo.statisticsReadState(StatisticsDataSource.visits).status ==
              RepositoryReadStatus.ready,
        );
        expect(
          f.repo.visitsForRestaurantBetween(
            StatisticsFixture.shopId,
            start,
            now,
          ),
          hasLength(6),
        );
      } finally {
        await f.close();
      }
    },
  );
}
