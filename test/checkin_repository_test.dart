import 'dart:async';

import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loyalo/core/database/app_database.dart';
import 'package:loyalo/features/checkins/data/check_in_remote_data_source.dart';
import 'package:loyalo/features/checkins/data/checkin_repository.dart';
import 'package:loyalo/models/check_in_request.dart';
import 'package:loyalo/services/loyalty_repository.dart';

void main() {
  group('CheckInRepository', () {
    late FakeFirebaseFirestore firestore;
    late CheckInRepository repository;
    late AppDatabase database;
    var now = DateTime(2026, 8, 24, 12);

    setUp(() {
      now = DateTime(2026, 8, 24, 12);
      firestore = FakeFirebaseFirestore();
      database = AppDatabase.forTesting(NativeDatabase.memory());
      repository = CheckInRepository(
        firestore,
        database: database,
        clock: () => now,
      );
    });

    tearDown(() => database.close());

    Future<CheckInRequest> createPending({
      required String userId,
      required String restaurantId,
      Duration lifetime = const Duration(minutes: 10),
    }) {
      return repository.createPendingCheckIn(
        userId: userId,
        restaurantId: restaurantId,
        requestedAt: now,
        expiresAt: now.add(lifetime),
        distanceMeters: 25,
      );
    }

    Future<void> refreshCache({
      String? customerId,
      String? restaurantId,
    }) async {
      await repository
          .watchCheckIns(customerId: customerId, restaurantId: restaurantId)
          .first;
    }

    test('crée une demande pending', () async {
      final request = await createPending(
        userId: 'client-a',
        restaurantId: 'merchant-a',
      );
      final snapshot = await firestore
          .collection('checkIns')
          .doc(request.id)
          .get();

      expect(request.status, CheckInStatus.pending);
      expect(snapshot.exists, isTrue);
      expect(snapshot.data()!['status'], 'pending');
      expect(snapshot.data()!['customerId'], 'client-a');
      expect(snapshot.data()!['restaurantId'], 'merchant-a');
      expect(snapshot.data()!['requestedAt'], isNotNull);
      expect(snapshot.data()!['expiresAt'], isNotNull);
      expect(snapshot.data()!['distanceMeters'], 25);
    });

    test('associe la demande au restaurant, pas au uid propriétaire', () async {
      final request = await createPending(
        userId: 'client-a',
        restaurantId: 'restaurant-a',
      );
      final received = repository.watchCheckIns(
        restaurantId: 'restaurant-a',
        ownerUid: 'merchant-owner-a',
      );

      final pending = await received.firstWhere(
        (items) => items.any((item) => item.id == request.id),
      );
      final local = await database.checkInDao.getCheckInById(request.id);

      expect(pending.single.restaurantId, 'restaurant-a');
      expect(local?.merchantId, 'restaurant-a');
      expect(local?.ownerUid, 'merchant-owner-a');
    });

    test('actualise automatiquement les demandes du bon restaurant', () async {
      final updates = repository.watchCheckIns(
        restaurantId: 'restaurant-a',
        ownerUid: 'owner-a',
      );
      final received = updates.firstWhere(
        (items) => items.any((item) => item.customerId == 'client-new'),
      );

      await createPending(userId: 'client-new', restaurantId: 'restaurant-a');

      expect((await received).single.customerId, 'client-new');
    });

    test('transmet une erreur du listener Firestore', () async {
      final failingRepository = CheckInRepository(
        firestore,
        database: database,
        remoteDataSource: const _FailingCheckInRemote(),
      );
      final error = Completer<Object>();
      final subscription = failingRepository
          .watchCheckIns(restaurantId: 'restaurant-a', ownerUid: 'owner-a')
          .listen((_) {}, onError: (Object value) => error.complete(value));

      expect(await error.future, isA<StateError>());
      await subscription.cancel();
    });

    test('expose l’erreur Firestore à Loyalo Express', () async {
      final failingCheckIns = CheckInRepository(
        firestore,
        database: database,
        remoteDataSource: const _FailingCheckInRemote(),
      );
      final loyalty = LoyaltyRepository(
        firestore: firestore,
        database: database,
        checkInRepository: failingCheckIns,
      );

      loyalty.startListeningForMerchant('restaurant-a', ownerUid: 'owner-a');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(loyalty.checkInsLoadError, isA<StateError>());
      await loyalty.stopListening();
      loyalty.dispose();
    });

    test('récupère les demandes pending', () async {
      await createPending(userId: 'client-a', restaurantId: 'merchant-a');
      await refreshCache(restaurantId: 'merchant-a');

      expect(
        repository.pendingCheckInsForRestaurant('merchant-a'),
        hasLength(1),
      );
    });

    test('sépare les demandes de deux commerces', () async {
      await createPending(userId: 'client-a', restaurantId: 'merchant-a');
      await createPending(userId: 'client-b', restaurantId: 'merchant-b');

      final merchantA = await repository
          .watchPendingCheckInsForRestaurant('merchant-a')
          .first;

      expect(merchantA, hasLength(1));
      expect(merchantA.single.restaurantId, 'merchant-a');
    });

    test(
      'le listener commerçant ne retourne que les demandes actives',
      () async {
        final approved = await createPending(
          userId: 'client-approved',
          restaurantId: 'merchant-a',
        );
        await firestore.collection('checkIns').doc(approved.id).update({
          'status': CheckInStatus.approved.firestoreValue,
        });
        await createPending(
          userId: 'client-expired',
          restaurantId: 'merchant-a',
          lifetime: const Duration(minutes: -1),
        );
        final active = await createPending(
          userId: 'client-active',
          restaurantId: 'merchant-a',
        );

        final hydration = repository
            .watchCheckIns(restaurantId: 'merchant-a')
            .listen((_) {});
        await Future<void>.delayed(const Duration(milliseconds: 10));
        final pending = await repository
            .watchPendingCheckInsForRestaurant('merchant-a')
            .first;
        await hydration.cancel();

        expect(pending, hasLength(1));
        expect(pending.single.id, active.id);
      },
    );

    test('sépare les demandes de deux clients', () async {
      await createPending(userId: 'client-a', restaurantId: 'merchant-a');
      await createPending(userId: 'client-b', restaurantId: 'merchant-a');

      await refreshCache(customerId: 'client-a');

      expect(repository.checkIns, hasLength(1));
      expect(repository.checkIns.single.customerId, 'client-a');
    });

    test('rejette une demande pending', () async {
      final request = await createPending(
        userId: 'client-a',
        restaurantId: 'merchant-a',
      );

      await repository.rejectPendingCheckIn(
        checkInId: request.id,
        merchantId: 'owner-a',
      );

      final rejected = await repository.getCheckIn(request.id);
      expect(rejected?.status, CheckInStatus.rejected);
      expect(rejected?.rejectedBy, 'owner-a');
      expect(rejected?.rejectedAt, now);
    });

    test('retrouve un check-in actif existant', () async {
      final request = await createPending(
        userId: 'client-a',
        restaurantId: 'merchant-a',
      );
      await createPending(userId: 'client-a', restaurantId: 'merchant-b');
      final approved = await createPending(
        userId: 'client-a',
        restaurantId: 'merchant-a',
      );
      await firestore.collection('checkIns').doc(approved.id).update({
        'status': CheckInStatus.approved.firestoreValue,
      });

      final existing = await repository.activeCheckInFromFirestore(
        userId: 'client-a',
        restaurantId: 'merchant-a',
      );

      expect(existing?.id, request.id);
    });

    test('expire une demande arrivée à échéance', () async {
      final request = await createPending(
        userId: 'client-a',
        restaurantId: 'merchant-a',
        lifetime: const Duration(minutes: 1),
      );
      await refreshCache();
      now = now.add(const Duration(minutes: 2));

      await repository.expirePendingCheckIns();

      final expired = await repository.getCheckIn(request.id);
      expect(expired?.status, CheckInStatus.expired);
    });

    test('gère l’absence de check-in', () async {
      await refreshCache();

      expect(repository.checkIns, isEmpty);
      expect(repository.pendingCheckInsForRestaurant('merchant-a'), isEmpty);
      expect(
        await repository.activeCheckInFromFirestore(
          userId: 'client-a',
          restaurantId: 'merchant-a',
        ),
        isNull,
      );
      expect(await repository.getCheckIn('missing'), isNull);
    });

    test('gère plusieurs check-ins et leur ordre', () async {
      await createPending(userId: 'client-a', restaurantId: 'merchant-a');
      now = now.add(const Duration(minutes: 1));
      final latest = await createPending(
        userId: 'client-b',
        restaurantId: 'merchant-a',
      );
      await refreshCache(restaurantId: 'merchant-a');

      final pending = repository.pendingCheckInsForRestaurant('merchant-a');
      expect(pending, hasLength(2));
      expect(pending.first.id, latest.id);
      expect(repository.pendingCheckInsCount('merchant-a'), 2);
    });
  });
}

class _FailingCheckInRemote implements CheckInRemoteDataSource {
  const _FailingCheckInRemote();

  @override
  Stream<List<CheckInRequest>> watchForMerchant(String merchantId) =>
      Stream.error(StateError('permission-denied'));

  @override
  Future<String> approve(Map<String, Object?> payload) async =>
      payload['visitId']! as String;

  @override
  Future<void> reject(Map<String, Object?> payload) async {}
}
