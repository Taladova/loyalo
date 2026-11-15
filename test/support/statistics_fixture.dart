// Données et pannes strictement locales. Les calculs du repository restent réels.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:loyalo/core/database/app_database.dart';
import 'package:loyalo/core/network/network_monitor.dart';
import 'package:loyalo/models/check_in_request.dart';
import 'package:loyalo/models/exclusive_offer.dart';
import 'package:loyalo/models/restaurant.dart';
import 'package:loyalo/models/reward.dart';
import 'package:loyalo/models/visit.dart';
import 'package:loyalo/services/loyalty_repository.dart';

class StatisticsFirestore extends FakeFirebaseFirestore {
  final failed = <String>{};
  final gates = <String, Completer<void>>{};
  final snapshotPaths = <String>[];
  final filters = <({String path, Object field, Object? value})>[];

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(super.collection(path), this, path);

  void release() {
    for (final gate in gates.values) {
      if (!gate.isCompleted) gate.complete();
    }
  }
}

// Doubles du SDK limités à l'observation des lectures et aux pannes contrôlées.
// ignore: subtype_of_sealed_class
class _Query implements Query<Map<String, dynamic>> {
  _Query(this.delegate, this.owner, this.path);
  final Query<Map<String, dynamic>> delegate;
  final StatisticsFirestore owner;
  final String path;
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) async* {
    owner.snapshotPaths.add(path);
    await owner.gates[path]?.future;
    if (owner.failed.contains(path)) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Erreur de lecture locale de test',
      );
    }
    yield* delegate.snapshots(
      includeMetadataChanges: includeMetadataChanges,
      source: source,
    );
  }

  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) {
    owner.filters.add((path: path, field: field, value: isEqualTo));
    return _Query(
      delegate.where(
        field,
        isEqualTo: isEqualTo,
        isNotEqualTo: isNotEqualTo,
        isLessThan: isLessThan,
        isLessThanOrEqualTo: isLessThanOrEqualTo,
        isGreaterThan: isGreaterThan,
        isGreaterThanOrEqualTo: isGreaterThanOrEqualTo,
        arrayContains: arrayContains,
        arrayContainsAny: arrayContainsAny,
        whereIn: whereIn,
        whereNotIn: whereNotIn,
        isNull: isNull,
      ),
      owner,
      path,
    );
  }

  @override
  Query<Map<String, dynamic>> orderBy(
    Object field, {
    bool descending = false,
  }) => _Query(delegate.orderBy(field, descending: descending), owner, path);
  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) =>
      delegate.get(options);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _Collection extends _Query
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(
    CollectionReference<Map<String, dynamic>> super.delegate,
    super.owner,
    super.path,
  );
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      (delegate as CollectionReference<Map<String, dynamic>>).doc(path);
  @override
  String get id => (delegate as CollectionReference<Map<String, dynamic>>).id;
}

class _Offline implements NetworkMonitor {
  @override
  Future<bool> get isNetworkAvailable async => false;
  @override
  Stream<bool> get onAvailabilityChanged => const Stream.empty();
}

class StatisticsUiRepository extends LoyaltyRepository {
  StatisticsUiRepository(this.firestore, this.database)
    : super(
        firestore: firestore,
        database: database,
        networkMonitor: _Offline(),
      );
  final StatisticsFirestore firestore;
  final AppDatabase database;
  bool? forceRestaurantLoading;
  Object? forceRestaurantError;
  int retries = 0;
  @override
  bool get restaurantsLoading =>
      forceRestaurantLoading ?? super.restaurantsLoading;
  @override
  Object? get restaurantsLoadError =>
      forceRestaurantError ?? super.restaurantsLoadError;
  @override
  Future<void> retryRestaurants() {
    retries++;
    return super.retryRestaurants();
  }
}

class StatisticsFixture {
  StatisticsFixture._(this.firestore, this.database, this.repo);
  final StatisticsFirestore firestore;
  final AppDatabase database;
  final StatisticsUiRepository repo;
  static const shopId = 'statistics-shop';
  static const ownerId = 'merchant-one';

  static Future<StatisticsFixture> create({
    bool empty = false,
    bool scoped = true,
    Set<String> failed = const {},
    Set<String> held = const {},
  }) async {
    final firestore = StatisticsFirestore()..failed.addAll(failed);
    for (final path in held) {
      firestore.gates[path] = Completer<void>();
    }
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = StatisticsUiRepository(firestore, database);
    const shop = Restaurant(
      id: shopId,
      ownerId: ownerId,
      name: 'Atelier du quartier',
      cuisine: 'Café',
      distanceKm: 0,
      rewardThreshold: 10,
      rewardLabel: 'Un café offert',
      pointsPerVisit: 35,
      icon: Icons.storefront_outlined,
    );
    await firestore.collection('restaurants').doc(shopId).set(shop.toMap());
    if (!empty) {
      final now = DateTime.now();
      const days = [1, 4, 12, 20, 40, 70];
      const users = ['a', 'a', 'b', 'c', 'd', 'a'];
      for (var i = 0; i < days.length; i++) {
        final visit = Visit(
          id: 'visit-$i',
          userId: users[i],
          restaurantId: shopId,
          timestamp: now.subtract(Duration(days: days[i])),
        );
        await firestore.collection('visits').doc(visit.id).set(visit.toMap());
      }
      final foreign = Visit(
        id: 'foreign-visit',
        userId: 'foreign',
        restaurantId: 'foreign-shop',
        timestamp: now.subtract(const Duration(days: 1)),
      );
      await firestore.collection('visits').doc(foreign.id).set(foreign.toMap());
      for (final day in [1, 12, 40]) {
        final reward = RewardItem(
          id: 'reward-$day',
          userId: 'a',
          restaurantId: shopId,
          restaurantName: shop.name,
          label: 'Un café offert',
          expiresAt: now
              .subtract(Duration(days: day))
              .add(const Duration(days: 30)),
          status: RewardStatus.available,
        );
        await firestore
            .collection('rewards')
            .doc(reward.id)
            .set(reward.toMap());
      }
      for (final row in [
        (id: 'active', active: true, start: -1, end: 7, shop: shopId),
        (id: 'inactive', active: false, start: -1, end: 7, shop: shopId),
        (id: 'expired', active: true, start: -10, end: -1, shop: shopId),
        (id: 'future', active: true, start: 1, end: 7, shop: shopId),
        (id: 'foreign', active: true, start: -1, end: 7, shop: 'foreign-shop'),
      ]) {
        final offer = ExclusiveOffer(
          id: row.id,
          restaurantId: row.shop,
          title: 'Offre locale de test',
          description: '',
          startsAt: now.add(Duration(days: row.start)),
          endsAt: now.add(Duration(days: row.end)),
          active: row.active,
        );
        await firestore
            .collection('exclusiveOffers')
            .doc(offer.id)
            .set(offer.toMap());
      }
      for (final row in [
        (
          id: 'pending-a',
          status: CheckInStatus.pending,
          shop: shopId,
          hours: 2,
        ),
        (
          id: 'pending-b',
          status: CheckInStatus.pending,
          shop: shopId,
          hours: 2,
        ),
        (
          id: 'approved',
          status: CheckInStatus.approved,
          shop: shopId,
          hours: 2,
        ),
        (id: 'expired', status: CheckInStatus.pending, shop: shopId, hours: -1),
        (
          id: 'foreign',
          status: CheckInStatus.pending,
          shop: 'foreign-shop',
          hours: 2,
        ),
      ]) {
        final checkIn = CheckInRequest(
          id: row.id,
          customerId: row.id,
          restaurantId: row.shop,
          requestedAt: now.subtract(const Duration(minutes: 5)),
          expiresAt: now.add(Duration(hours: row.hours)),
          status: row.status,
        );
        await firestore
            .collection('checkIns')
            .doc(checkIn.id)
            .set(checkIn.toMap());
      }
      for (final row in [
        (id: 'pending', status: 'pending', shop: shopId),
        (id: 'rewarded', status: 'rewarded', shop: shopId),
        (id: 'other', status: 'rewarded', shop: 'foreign-shop'),
      ]) {
        await firestore.collection('referrals').doc(row.id).set({
          'restaurantId': row.shop,
          'referrerId': 'a',
          'referredUserId': row.id,
          'name': 'Client local de test',
          'status': row.status,
          'pointsEarned': 0,
          'invitedAt': Timestamp.fromDate(
            now.subtract(const Duration(days: 2)),
          ),
        });
      }
    }
    final result = StatisticsFixture._(firestore, database, repo);
    if (scoped) {
      repo.startListeningForMerchant(shopId, ownerUid: ownerId);
    } else {
      repo.startListening();
    }
    await result.waitFor(() => !repo.restaurantsLoading);
    const paths = {
      StatisticsDataSource.visits: 'visits',
      StatisticsDataSource.rewards: 'rewards',
      StatisticsDataSource.offers: 'exclusiveOffers',
      StatisticsDataSource.checkIns: 'checkIns',
      StatisticsDataSource.referrals: 'referrals',
    };
    await result.waitFor(
      () => paths.entries
          .where(
            (entry) =>
                !held.contains(entry.value) &&
                (!scoped || entry.key != StatisticsDataSource.referrals),
          )
          .every(
            (entry) => [
              'ready',
              'error',
            ].contains(repo.statisticsReadState(entry.key).status.name),
          ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 25));
    return result;
  }

  Future<void> waitFor(bool Function() condition) async {
    for (var i = 0; i < 300; i++) {
      if (condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    throw StateError('Les lectures locales de test ne sont pas prêtes.');
  }

  Future<void> close() async {
    firestore.release();
    await repo.stopListening();
    repo.dispose();
    await database.close();
  }
}
